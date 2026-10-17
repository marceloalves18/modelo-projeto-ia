#!/usr/bin/env bash
# Compara este projeto com a versão atual do modelo-projeto-ia. Só lê: não altera
# nenhum arquivo. Como trazer as melhorias: docs/procedimentos/atualizar-do-modelo.md
#
#   scripts/comparar-modelo.sh              resumo: versão e arquivos diferentes
#   scripts/comparar-modelo.sh --detalhes   mostra o diff de cada arquivo
#
# Outro endereço do modelo: MODELO_URL=<url> scripts/comparar-modelo.sh
set -o pipefail

MODELO_URL="${MODELO_URL:-https://github.com/marceloalves18/modelo-projeto-ia.git}"
DETALHES=""
if [[ "${1:-}" == "--detalhes" ]]; then
    DETALHES=1
fi

RAIZ="$(git rev-parse --show-toplevel)" || exit 1
cd "$RAIZ" || exit 1

# Arquivos que vêm do modelo sem mudança por projeto. AGENTS.md e README.md
# misturam modelo e projeto: ficam para revisão à mão (ver procedimento).
ARQUIVOS=(
    .githooks/pre-commit
    scripts/verificar.sh
    scripts/comparar-modelo.sh
    tests/testar_protecoes.sh
    .claude/hooks/guarda.py
    .claude/hooks/sessao.sh
    .claude/settings.json
    .codex/hooks.json
    .github/workflows/verificar.yml
    .gitattributes
    CLAUDE.md
    GEMINI.md
    docs/planejamentos/_modelo.md
    docs/modulos/_modelo.md
)

if ! GIT_TERMINAL_PROMPT=0 git fetch -q --depth 1 "$MODELO_URL" main 2> /dev/null; then
    echo "✗ não foi possível buscar o modelo em $MODELO_URL (rede, proxy ou acesso ao repositório privado: gh auth setup-git)." >&2
    exit 1
fi
MODELO="$(git rev-parse FETCH_HEAD)"

versao() {
    grep -m1 -oE 'v[0-9]+\.[0-9]+ \([0-9-]+\)'
}
versao_projeto="$(versao < AGENTS.md 2> /dev/null)"
versao_modelo="$(git show "$MODELO:AGENTS.md" 2> /dev/null | versao)"
echo "Projeto derivado do modelo ${versao_projeto:-(versão não encontrada no AGENTS.md)}; modelo atual: ${versao_modelo:-?}"

diferentes=0
for arquivo in "${ARQUIVOS[@]}"; do
    no_modelo=1
    git cat-file -e "$MODELO:$arquivo" 2> /dev/null || no_modelo=""
    if [[ -z "$no_modelo" && ! -e "$arquivo" ]]; then
        continue
    elif [[ -z "$no_modelo" ]]; then
        echo "  só no projeto:      $arquivo (não existe no modelo: criado aqui, ou removido de lá)"
    elif [[ ! -e "$arquivo" ]]; then
        echo "  falta no projeto:   $arquivo"
    elif git diff --quiet "$MODELO" -- "$arquivo"; then
        continue
    else
        echo "  diferente:          $arquivo ($(git diff --shortstat "$MODELO" -- "$arquivo" | sed 's/^ *//'))"
        [[ -n "$DETALHES" ]] && git --no-pager diff "$MODELO" -- "$arquivo"
    fi
    diferentes=$((diferentes + 1))
done

if (( diferentes == 0 )); then
    echo "Arquivos de proteção iguais aos do modelo."
else
    echo "$diferentes arquivo(s) diferente(s). No diff, '-' é o modelo e '+' é o projeto. Procedimento: docs/procedimentos/atualizar-do-modelo.md"
fi
echo "Revise à mão no AGENTS.md as seções que vêm do modelo: Portão, Regras universais, Definição de Pronto e Proteções automáticas."
