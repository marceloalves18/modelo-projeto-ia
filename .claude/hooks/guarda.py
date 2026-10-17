#!/usr/bin/env python3
"""Hook PreToolUse do Claude Code: garante [R-FORA-DO-REPO], [R-PROTEGIDOS] e [R-DESTRUTIVO].

Bloqueio: exit 2 com o motivo no stderr (o Claude vê o motivo).
Confirmação do usuário: JSON com permissionDecision "ask".
Só a biblioteca padrão, para funcionar em qualquer máquina com python3.
"""
import fnmatch
import json
import os
import re
import shlex
import sys
import tempfile

_RAIZ = os.path.realpath(os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd())

# Rascunho de sessão do agente (descartável, permitido por [R-FORA-DO-REPO]).
_TEMP_AGENTE = os.path.join(os.path.realpath(tempfile.gettempdir()), "claude-")

# Arquivos que enfraquecem as proteções se alterados: pedem confirmação.
_PROTECOES = (
    ".caminhos-protegidos",
    ".githooks/*",
    ".claude/settings.json",
    ".claude/hooks/*",
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

    for _, destino in _REDIRECAO.findall(comando):
        if destino.startswith("&") or destino == "/dev/null":
            continue
        _checar_arquivo(destino, cwd, True, regras)

    for padrao, descricao in _DESTRUTIVOS:
        if re.search(padrao, comando, re.IGNORECASE if "DROP" in padrao else 0):
            _perguntar(f"Comando destrutivo ({descricao}) — confirme com o usuário ([R-DESTRUTIVO]).")


def main():
    try:
        entrada = json.load(sys.stdin)
    except json.JSONDecodeError:
        return
    ferramenta = entrada.get("tool_name", "")
    parametros = entrada.get("tool_input") or {}
    cwd = entrada.get("cwd") or _RAIZ
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


if __name__ == "__main__":
    main()
