#!/usr/bin/env bash
# Testes das proteções do projeto ([R-REGRESSAO], [R-VERIFICAR]): pre-commit,
# scripts/verificar.sh e hooks do Claude Code.
#
# Roda numa cópia descartável, só com os arquivos de proteção e com uma lista
# de caminhos protegidos própria do teste: testa o mecanismo, não a lista do
# projeto. Chamado pelo scripts/verificar.sh; também roda sozinho.
set -uo pipefail

RAIZ="$(git rev-parse --show-toplevel)" || exit 1
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
REPO="$TMP/repo"

for arquivo in scripts/verificar.sh .githooks/pre-commit .claude/hooks/guarda.py .claude/hooks/sessao.sh; do
    mkdir -p "$REPO/$(dirname "$arquivo")"
    cp "$RAIZ/$arquivo" "$REPO/$arquivo"
done
cat > "$REPO/.caminhos-protegidos" << 'EOF'
segredo .env
segredo auth.json
segredo credentials/*
dado    *.xlsx
EOF

cd "$REPO" || exit 1
git init -q -b main
git config user.email teste@exemplo.invalid
git config user.name teste
git config core.hooksPath .githooks
export DENTRO_DO_TESTE=1   # o verificar.sh da cópia não chama estes testes de novo
git add .caminhos-protegidos scripts .githooks .claude
git commit -q -m base > /dev/null 2>&1 || { echo "✗ commit base falhou" >&2; exit 1; }

total=0
falhas=0
confere() {
    local descricao="$1" esperado="$2" obtido="$3"
    total=$((total + 1))
    if [[ "$esperado" != "$obtido" ]]; then
        echo "✗ $descricao: esperado '$esperado', obtido '$obtido'" >&2
        falhas=$((falhas + 1))
    fi
}

# "sim" se a saída do comando contém o texto. Guarda a saída antes de procurar:
# com pipefail, "cmd | grep -q" daria falso negativo quando o grep fecha o pipe cedo.
contem() {
    local texto="$1" saida
    shift
    saida="$("$@" 2>&1)"
    [[ "$saida" == *"$texto"* ]] && echo sim || echo não
}

# Commit com o que estiver no stage; desfaz o stage e os arquivos novos depois.
tentar_commit() {
    local resultado=bloqueia
    if "$@" git commit -q -m teste > "$TMP/saida" 2>&1; then
        resultado=passa
    fi
    git reset -q
    git clean -fdq
    echo "$resultado"
}

token_falso() {
    # Gerado na hora: um token literal neste arquivo seria achado pelo próprio gitleaks.
    printf 'ghp_%s' "$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 36)"
}

# --- Finais de linha (.gitattributes) ------------------------------------
# Script com CRLF quebra no bash: no Windows o git converteria sem o .gitattributes.
for script in scripts/verificar.sh .githooks/pre-commit .claude/hooks/guarda.py .claude/hooks/sessao.sh tests/testar_protecoes.sh; do
    confere "eol=lf em $script" lf "$(git -C "$RAIZ" check-attr eol -- "$script" | awk '{print $NF}')"
done

# --- pre-commit e verificar.sh --staged -----------------------------------
echo ok > nota.txt && git add nota.txt
confere "commit de arquivo comum" passa "$(tentar_commit env)"

echo X=1 > .env && git add -f .env
confere "segredo .env (forçado com -f)" bloqueia "$(tentar_commit env)"

mkdir -p sub && echo '{}' > sub/auth.json && git add sub/auth.json
confere "segredo pelo nome em subpasta" bloqueia "$(tentar_commit env)"

mkdir -p credentials && echo k > credentials/chave && git add credentials/chave
confere "segredo por pasta (credentials/*)" bloqueia "$(tentar_commit env)"

echo p > planilha.xlsx && git add planilha.xlsx
confere "dado sem autorização" bloqueia "$(tentar_commit env)"

echo p > planilha.xlsx && git add planilha.xlsx
confere "dado com PERMITIR_DADOS=1" passa "$(tentar_commit env PERMITIR_DADOS=1)"

head -c 28673 /dev/zero | tr '\0' 'a' > AGENTS.md && git add AGENTS.md
confere "AGENTS.md acima de 28 KB" bloqueia "$(tentar_commit env)"

head -c 20481 /dev/zero | tr '\0' 'a' > CONTEXT.md && git add CONTEXT.md
confere "CONTEXT.md acima de 20 KB" bloqueia "$(tentar_commit env)"

# --- gitleaks: ausente, antigo e atual ------------------------------------
path_sem_gitleaks="$(
    IFS=:
    for dir in $PATH; do
        [[ -x "$dir/gitleaks" ]] || printf '%s:' "$dir"
    done
)"
mkdir -p "$TMP/antigo"
printf '#!/bin/sh\necho 8.16.0\n' > "$TMP/antigo/gitleaks"
chmod +x "$TMP/antigo/gitleaks"

token_falso > vaza.py && git add vaza.py
confere "sem gitleaks: token passa" passa "$(tentar_commit env PATH="$path_sem_gitleaks")"
confere "sem gitleaks: avisa" sim "$(grep -q 'gitleaks não instalado' "$TMP/saida" && echo sim || echo não)"

token_falso > vaza.py && git add vaza.py
confere "gitleaks 8.16: token passa" passa "$(tentar_commit env PATH="$TMP/antigo:$path_sem_gitleaks")"
confere "gitleaks 8.16: avisa versão antiga" sim "$(grep -q 'é antigo' "$TMP/saida" && echo sim || echo não)"

gitleaks_versao="$(gitleaks version 2> /dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
if [[ -n "$gitleaks_versao" && "$(printf '%s\n' 8.19.0 "$gitleaks_versao" | sort -V | head -1)" == "8.19.0" ]]; then
    token_falso > vaza.py && git add vaza.py
    confere "gitleaks $gitleaks_versao: token no stage" bloqueia "$(tentar_commit env)"

    token_falso > vaza.py && git add vaza.py && git commit -q --no-verify -m vazou
    resultado=bloqueia
    scripts/verificar.sh > /dev/null 2>&1 && resultado=passa
    confere "gitleaks $gitleaks_versao: token no histórico (--no-verify)" bloqueia "$resultado"
    git reset -q --hard HEAD~1
else
    echo "⚠ testes com gitleaks real pulados: gitleaks ≥ 8.19 não instalado ([R-SETUP])." >&2
fi

# --- Hook PreToolUse do Claude (guarda.py) --------------------------------
export CLAUDE_PROJECT_DIR="$REPO"
rascunho="$(python3 -c 'import tempfile; print(tempfile.gettempdir())')/claude-teste/rascunho.txt"

hook() {
    local saida codigo
    saida="$(python3 .claude/hooks/guarda.py 2>&1)"
    codigo=$?
    if (( codigo == 2 )); then
        echo bloqueia
    elif [[ "$saida" == *'"ask"'* ]]; then
        echo pergunta
    else
        echo libera
    fi
}
arquivo() {
    python3 -c 'import json, sys; print(json.dumps({"tool_name": sys.argv[1], "cwd": sys.argv[2], "tool_input": {"file_path": sys.argv[3]}}))' "$1" "$REPO" "$2" | hook
}
bash_cmd() {
    python3 -c 'import json, sys; print(json.dumps({"tool_name": "Bash", "cwd": sys.argv[1], "tool_input": {"command": sys.argv[2]}}))' "$REPO" "$1" | hook
}

confere "Write dentro do repo" libera "$(arquivo Write "$REPO/docs/x.md")"
confere "Write em ~/.claude/plans" bloqueia "$(arquivo Write "$HOME/.claude/plans/p.md")"
confere "Write na memória do Claude" bloqueia "$(arquivo Write "$HOME/.claude/projects/p/memory/m.md")"
confere "Write fora do repo (relativo)" bloqueia "$(arquivo Write ../fora.md)"
confere "Write no rascunho do agente" libera "$(arquivo Write "$rascunho")"
confere "Read de segredo" bloqueia "$(arquivo Read "$REPO/.env")"
confere "Read de segredo em subpasta" bloqueia "$(arquivo Read sub/auth.json)"
confere "Read de dado" libera "$(arquivo Read planilha.xlsx)"
confere "Edit em .githooks/pre-commit" pergunta "$(arquivo Edit "$REPO/.githooks/pre-commit")"
confere "Edit em .caminhos-protegidos" pergunta "$(arquivo Edit .caminhos-protegidos)"

confere "git add -A" bloqueia "$(bash_cmd 'git add -A')"
confere "git add ." bloqueia "$(bash_cmd 'git add . && git status')"
confere "git add --all" bloqueia "$(bash_cmd 'git add --all')"
confere "git add de arquivos" libera "$(bash_cmd 'git add docs/x.md ./AGENTS.md')"
confere "git commit -am" bloqueia "$(bash_cmd 'git commit -am "msg"')"
confere "git commit -n" bloqueia "$(bash_cmd 'git commit -n -m msg')"
confere "--no-verify" bloqueia "$(bash_cmd 'git push --no-verify origin main')"
confere "commit normal e --amend" libera "$(bash_cmd 'git commit -m "feat(x): adiciona" && git commit --amend --no-edit')"
confere "cat de segredo" bloqueia "$(bash_cmd 'cat .env')"
confere "grep em segredo" bloqueia "$(bash_cmd 'grep token ./sub/auth.json')"
confere "redirecionar para fora do repo" bloqueia "$(bash_cmd 'echo oi > ~/nota.md')"
confere "tee para fora do repo" bloqueia "$(bash_cmd 'ls | tee /var/tmp/x.txt')"
confere "redirecionar para /dev/null" libera "$(bash_cmd 'ls > /dev/null 2>&1')"
confere "rm -rf" pergunta "$(bash_cmd 'rm -rf build')"
confere "rm -fr" pergunta "$(bash_cmd 'rm -fr build')"
confere "rm simples" libera "$(bash_cmd 'rm docs/x.md')"
confere "git push --force" pergunta "$(bash_cmd 'git push --force origin main')"
confere "git push por URL" libera "$(bash_cmd 'git push https://github.com/u/r.git main')"
confere "apagar branch remota" pergunta "$(bash_cmd 'git push origin :velha')"
confere "git reset --hard" pergunta "$(bash_cmd 'git reset --hard HEAD~1')"
confere "mexer no core.hooksPath" pergunta "$(bash_cmd 'git config --unset core.hooksPath')"
confere "systemctl restart" pergunta "$(bash_cmd 'sudo systemctl restart nginx')"
confere "git pull --rebase" libera "$(bash_cmd 'git pull --rebase')"

# --- Hook SessionStart do Claude (sessao.sh) ------------------------------
aviso() {
    contem "$1" .claude/hooks/sessao.sh
}
confere "sessão: sem aviso de pre-commit quando instalado" não "$(aviso 'pre-commit NÃO')"
git config --unset core.hooksPath
confere "sessão: avisa pre-commit ausente" sim "$(aviso 'pre-commit NÃO')"
git config core.hooksPath .githooks
confere "sessão: avisa gitleaks ausente" sim "$(PATH="$path_sem_gitleaks" aviso 'gitleaks não está instalado')"

git init -q --bare "$TMP/remoto.git"
git remote add origin "$TMP/remoto.git"
git push -q -u origin main 2> /dev/null
git clone -q -b main "$TMP/remoto.git" "$TMP/outra-maquina"
git -C "$TMP/outra-maquina" -c user.email=o@exemplo.invalid -c user.name=o commit -q --allow-empty -m "de outra máquina"
git -C "$TMP/outra-maquina" push -q origin main 2> /dev/null
confere "sessão: avisa cópia atrás do remoto" sim "$(aviso 'atrás do remoto')"
git pull -q --rebase
confere "sessão: sem aviso depois do pull" não "$(aviso 'atrás do remoto')"

if (( falhas > 0 )); then
    echo "testar_protecoes.sh: $falhas de $total testes falharam." >&2
    exit 1
fi
echo "testar_protecoes.sh: $total testes ok"
