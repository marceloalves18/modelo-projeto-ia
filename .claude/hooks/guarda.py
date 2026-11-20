#!/usr/bin/env python3
"""Hook PreToolUse do Claude Code e do Codex: garante [R-FORA-DO-REPO], [R-PROTEGIDOS]
e [R-DESTRUTIVO].

Bloqueio: exit 2 com o motivo no stderr (o agente vê o motivo) — igual nos dois.
Confirmação do usuário: JSON com permissionDecision "ask" no Claude. O Codex não
suporta "ask" (marca o hook como falho e deixa passar), então lá vira bloqueio.
Uso: guarda.py (Claude) | guarda.py --codex
Só a biblioteca padrão, para funcionar em qualquer máquina com python3.
"""
import fnmatch
import json
import os
import re
import shlex
import subprocess
import sys
import tempfile

_CODEX = "--codex" in sys.argv[1:]
_RAIZ = ""  # definida em main(): CLAUDE_PROJECT_DIR no Claude, raiz do git no Codex

# Rascunho de sessão do agente (descartável, permitido por [R-FORA-DO-REPO]).
_TEMP_AGENTE = os.path.join(os.path.realpath(tempfile.gettempdir()), "claude-")

# Arquivos que enfraquecem as proteções se alterados: pedem confirmação.
_PROTECOES = (
    ".caminhos-protegidos",
    ".githooks/*",
    ".claude/settings.json",
    ".claude/hooks/*",
    ".codex/hooks.json",
    "scripts/verificar.sh",
)

_GIT = r"\bgit(?:\s+-C\s+\S+)?\s+"
_PROIBIDOS = (
    (
        _GIT + r"add\b[^;&|]*\s(?:-A|--all|\.)(?=\s|$|[;&|])",
        "git add -A/--all/. pode levar segredo ou dado real ao commit: use git add <arquivo> ([R-PROTEGIDOS]).",
    ),
    (
        _GIT + r"commit\b[^;&|]*\s(?:-[a-zA-Z]*a[a-zA-Z]*|--all)(?=\s|$)",
        "git commit -a pula a escolha dos arquivos: use git add <arquivo> ([R-PROTEGIDOS]).",
    ),
    (
        _GIT + r"commit\b[^;&|]*\s(?:-[a-zA-Z]*n[a-zA-Z]*|--no-verify)(?=\s|$)",
        "git commit -n/--no-verify pula o pre-commit ([R-PROTEGIDOS]).",
    ),
    (
        r"--no-verify\b",
        "--no-verify pula os hooks de git ([R-PROTEGIDOS]).",
    ),
)
_DESTRUTIVOS = (
    (r"\brm\s+(?:-[a-zA-Z]*[rR][a-zA-Z]*\s+)*-[a-zA-Z]*[fF]|\brm\s+(?:-[a-zA-Z]*[fF][a-zA-Z]*\s+)*-[a-zA-Z]*[rR]", "rm recursivo forçado"),
    (_GIT + r"push\b[^;&|]*\s(?:-f\b|--force)", "git push --force"),
    (_GIT + r"push\b[^;&|]*\s(?:--delete\b|-d\b|:\S+|\+\S+)", "apagar ou forçar branch remota"),
    (_GIT + r"reset\b[^;&|]*--hard", "git reset --hard"),
    (_GIT + r"clean\b[^;&|]*-[a-zA-Z]*f", "git clean -f"),
    (_GIT + r"branch\b[^;&|]*\s-D\b", "git branch -D"),
    (_GIT + r"config\b[^;&|]*core\.hooksPath", "mudar core.hooksPath"),
    (r"\bsystemctl\s+(?:restart|stop|disable|mask|kill)\b", "parar/reiniciar serviço"),
    (r"\b(?:reboot|shutdown|poweroff|mkfs\S*)\b", "reiniciar/desligar/formatar"),
    (r"\bdd\b[^;&|]*\bof=", "dd gravando em dispositivo"),
    (r"\b(?:DROP|TRUNCATE)\s+(?:TABLE|DATABASE|SCHEMA)\b", "apagar tabela/banco"),
)
_REDIRECAO = re.compile(r"(?:\d?>>?|\btee(?:\s+-a)?)\s*(['\"]?)([^\s'\";&|]+)\1")


# Comandos que executam o texto entre aspas como shell: ali o '>' é redirecionamento de verdade.
_EXECUTA_TEXTO = re.compile(
    r"\b(?:ba|z|da|k|c|fi)?sh\b(?:\s+-\S+)*\s+-\w*c\b|\beval\b|\bssh\b|\bxargs\b|\bsu\s+-c\b|\bwatch\b"
)


def _posicoes_literais(comando):
    """Para cada caractere, se ele é texto literal entre aspas (então um '>' ali não é redirecionamento).

    Aspas simples: tudo dentro é literal. Aspas duplas: literal até achar $( ou crase; dali em diante
    **nada** é literal, até o fim do comando (substituição de comando pode ter aspas, parênteses e case
    dentro, que um analisador simples erraria; na dúvida, examina tudo). As próprias aspas não são
    literais, para "> 'arquivo'" seguir checado. Aspas desbalanceadas: nada é literal.
    """
    literal = [False] * len(comando)
    if _EXECUTA_TEXTO.search(comando):
        return literal  # bash -c "...", eval, ssh...: o texto entre aspas é comando
    estado = None  # None, "'" ou '"'
    i = 0
    while i < len(comando):
        c = comando[i]
        if estado is None:
            if c == "\\":
                i += 2
                continue
            if c in "'\"":
                estado = c
        elif estado == "'":
            if c == "'":
                estado = None
            else:
                literal[i] = True
        elif c == "`" or comando.startswith("$(", i):
            return literal  # daqui em diante é comando: examina tudo
        elif c == '"':
            estado = None
        else:
            literal[i] = True
            if c == "\\" and i + 1 < len(comando):
                literal[i + 1] = True
                i += 2
                continue
        i += 1
    if estado is not None:
        return [False] * len(comando)
    return literal


def _carregar_protegidos():
    caminho = os.path.join(_RAIZ, ".caminhos-protegidos")
    regras = []
    try:
        with open(caminho, encoding="utf-8") as arquivo:
            for linha in arquivo:
                partes = linha.split()
                if len(partes) >= 2 and not partes[0].startswith("#"):
                    regras.append((partes[0], partes[1]))
    except FileNotFoundError:
        pass
    return regras


def _casa(relativo, padrao):
    # Mesma regra do scripts/verificar.sh: com "/" casa o caminho, sem "/" casa o nome.
    if "/" in padrao:
        return fnmatch.fnmatchcase(relativo, padrao)
    return fnmatch.fnmatchcase(os.path.basename(relativo), padrao)


def _bloquear(motivo):
    print(f"Bloqueado pelo hook do projeto: {motivo}", file=sys.stderr)
    sys.exit(2)


def _perguntar(motivo):
    if _CODEX:
        _bloquear(f"{motivo} No Codex o hook não consegue pedir confirmação: mostre o comando ao usuário e deixe que ele o rode.")
    saida = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "ask",
            "permissionDecisionReason": motivo,
        }
    }
    print(json.dumps(saida, ensure_ascii=False))
    sys.exit(0)


def _absoluto(caminho, cwd):
    caminho = os.path.expanduser(caminho)
    return os.path.realpath(os.path.join(cwd, caminho))


def _relativo_ao_repo(absoluto):
    if absoluto == _RAIZ or absoluto.startswith(_RAIZ + os.sep):
        return os.path.relpath(absoluto, _RAIZ)
    return None


def _checar_segredo(relativo, regras):
    # "permitido" vale antes dos outros tipos (ex.: .env.exemplo apesar de "segredo .env.*").
    if any(tipo == "permitido" and _casa(relativo, padrao) for tipo, padrao in regras):
        return
    for tipo, padrao in regras:
        if tipo == "segredo" and _casa(relativo, padrao):
            _bloquear(
                f"'{relativo}' é segredo (padrão '{padrao}' em .caminhos-protegidos): "
                "não pode ser lido, exibido nem alterado por agente ([R-PROTEGIDOS])."
            )


def _checar_arquivo(caminho, cwd, escrita, regras):
    absoluto = _absoluto(caminho, cwd)
    relativo = _relativo_ao_repo(absoluto)
    if relativo is None:
        if escrita and not absoluto.startswith(_TEMP_AGENTE):
            _bloquear(
                f"gravação fora do repositório ({absoluto}): todo artefato vive dentro do repo "
                "([R-FORA-DO-REPO]); memória de agente é proibida ([R-MEMORIA])."
            )
        return
    _checar_segredo(relativo, regras)
    if escrita and any(fnmatch.fnmatchcase(relativo, p) for p in _PROTECOES):
        _perguntar(f"Alterar '{relativo}' muda as proteções do projeto. Confirma?")


def _checar_bash(comando, cwd, regras):
    for padrao, motivo in _PROIBIDOS:
        if re.search(padrao, comando):
            _bloquear(motivo)

    try:
        palavras = shlex.split(comando, posix=True)
    except ValueError:
        palavras = comando.split()
    for palavra in palavras:
        if palavra.startswith("-") or not palavra.strip():
            continue
        relativo = _relativo_ao_repo(_absoluto(palavra, cwd))
        if relativo is not None:
            _checar_segredo(relativo, regras)

    literal = _posicoes_literais(comando)
    for achado in _REDIRECAO.finditer(comando):
        if literal[achado.start()]:  # '>' ou tee dentro de aspas: é texto (mensagem de commit, echo)
            continue
        destino = achado.group(2)
        if destino.startswith("&") or destino == "/dev/null":
            continue
        _checar_arquivo(destino, cwd, True, regras)

    for padrao, descricao in _DESTRUTIVOS:
        if re.search(padrao, comando, re.IGNORECASE if "DROP" in padrao else 0):
            _perguntar(f"Comando destrutivo ({descricao}) — confirme com o usuário ([R-DESTRUTIVO]).")


# Caminhos que um apply_patch do Codex cria, altera, apaga ou para onde move.
_PATCH_ARQUIVO = re.compile(r"^\*\*\* (?:Add File|Update File|Delete File|Move to): (.+?)\s*$", re.MULTILINE)


def _raiz_do_projeto(cwd):
    if os.environ.get("CLAUDE_PROJECT_DIR"):
        return os.path.realpath(os.environ["CLAUDE_PROJECT_DIR"])
    try:
        saida = subprocess.run(
            ["git", "-C", cwd, "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=True,
        )
        return os.path.realpath(saida.stdout.strip())
    except (OSError, subprocess.CalledProcessError):
        return os.path.realpath(cwd)


def main():
    global _RAIZ
    try:
        entrada = json.load(sys.stdin)
    except json.JSONDecodeError:
        return
    ferramenta = entrada.get("tool_name", "")
    parametros = entrada.get("tool_input") or {}
    cwd = entrada.get("cwd") or os.getcwd()
    _RAIZ = _raiz_do_projeto(cwd)
    regras = _carregar_protegidos()

    if ferramenta in ("Write", "Edit", "NotebookEdit"):
        caminho = parametros.get("file_path") or parametros.get("notebook_path")
        if caminho:
            _checar_arquivo(caminho, cwd, True, regras)
    elif ferramenta in ("Read", "Grep"):
        caminho = parametros.get("file_path") or parametros.get("path")
        if caminho:
            _checar_arquivo(caminho, cwd, False, regras)
    elif ferramenta == "Bash":
        _checar_bash(parametros.get("command", ""), cwd, regras)
    elif ferramenta == "apply_patch":
        for caminho in _PATCH_ARQUIVO.findall(parametros.get("command", "")):
            _checar_arquivo(caminho, cwd, True, regras)


if __name__ == "__main__":
    main()
