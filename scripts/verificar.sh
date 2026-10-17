#!/usr/bin/env bash
# Verificação única do projeto ([R-VERIFICAR]).
#
#   scripts/verificar.sh            checagens do repositório + testes
#   scripts/verificar.sh --staged   só as checagens do que está no stage (usado pelo pre-commit)
#
# Commit autorizado de um "dado" ([R-PROTEGIDOS]): PERMITIR_DADOS=1 git commit ...
set -uo pipefail

RAIZ="$(git rev-parse --show-toplevel)" || exit 1
cd "$RAIZ" || exit 1

MODO="completo"
if [[ "${1:-}" == "--staged" ]]; then
    MODO="staged"
fi

LIMITE_AGENTS=28672   # [R-TAMANHO]: o Codex para em 32 KiB somando o AGENTS.md global da pessoa
LIMITE_CONTEXT=20480

falhas=0
falha() {
    echo "✗ $*" >&2
    falhas=$((falhas + 1))
}

# --- .caminhos-protegidos -------------------------------------------------
tipos=()
padroes=()
if [[ -f .caminhos-protegidos ]]; then
    while read -r tipo padrao _; do
        [[ -z "$tipo" || "$tipo" == \#* ]] && continue
        tipos+=("$tipo")
        padroes+=("$padrao")
    done < .caminhos-protegidos
fi

# Padrão com "/" casa o caminho inteiro; sem "/", só o nome do arquivo.
casa() {
    local caminho="$1" padrao="$2"
    if [[ "$padrao" == */* ]]; then
        [[ "$caminho" == $padrao ]]
    else
        [[ "${caminho##*/}" == $padrao ]]
    fi
}

if [[ "$MODO" == "staged" ]]; then
    lista_cmd=(git diff --cached --name-only --diff-filter=ACMR -z)
else
    lista_cmd=(git ls-files -z)
fi

while IFS= read -r -d '' arquivo; do
    for i in "${!padroes[@]}"; do
        casa "$arquivo" "${padroes[$i]}" || continue
        case "${tipos[$i]}" in
            segredo)
                falha "segredo no repositório: $arquivo (padrão '${padroes[$i]}'). Tire do stage/índice: git rm --cached -- '$arquivo'"
                ;;
            dado)
                # No modo completo, dado já versionado foi escolha consciente; só o stage é barrado.
                if [[ "$MODO" == "staged" && "${PERMITIR_DADOS:-}" != "1" ]]; then
                    falha "dado real no stage: $arquivo (padrão '${padroes[$i]}'). Só com ordem explícita do usuário: PERMITIR_DADOS=1 git commit ..."
                fi
                ;;
        esac
        break
    done
done < <("${lista_cmd[@]}")

# --- Tamanho das instruções ([R-TAMANHO]) ---------------------------------
tamanho() {
    if [[ "$MODO" == "staged" ]]; then
        git cat-file -s ":$1" 2>/dev/null || echo 0
    elif [[ -f "$1" ]]; then
        wc -c < "$1"
    else
        echo 0
    fi
}

for par in "AGENTS.md:$LIMITE_AGENTS" "CONTEXT.md:$LIMITE_CONTEXT"; do
    arquivo="${par%%:*}"
    limite="${par##*:}"
    bytes="$(tamanho "$arquivo")"
    if (( bytes > limite )); then
        falha "$arquivo tem $bytes bytes, acima do limite de $limite. Mova detalhes para docs/modulos/ ou docs/planejamentos/ ([R-TAMANHO], [R-DOC])."
    fi
done

# --- Segredo no conteúdo (opcional) ---------------------------------------
if command -v gitleaks > /dev/null 2>&1; then
    if [[ "$MODO" == "staged" ]]; then
        gitleaks git --pre-commit --staged --redact --no-banner \
            || falha "gitleaks encontrou possível segredo no que está no stage."
    else
        # Só o que é versionado (histórico inteiro): arquivo ignorado, como venv/ ou
        # cookie local, não é problema do repositório.
        gitleaks git --redact --no-banner \
            || falha "gitleaks encontrou possível segredo no histórico do repositório."
    fi
elif [[ "$MODO" == "completo" ]]; then
    echo "⚠ gitleaks não instalado: conteúdo dos arquivos não foi varrido em busca de segredos." >&2
fi

# --- Testes do projeto (só no modo completo) ------------------------------
if [[ "$MODO" == "completo" ]]; then
    # PREENCHER: comandos de teste/lint do projeto. Exemplo para Python:
    #   venv/bin/ruff format --check . || falha "formatação"
    #   venv/bin/pytest -q             || falha "testes"
    echo "⚠ nenhum teste configurado em scripts/verificar.sh (seção PREENCHER)." >&2
fi

if (( falhas > 0 )); then
    echo "verificar.sh: $falhas problema(s) — corrija antes de seguir." >&2
    exit 1
fi
echo "verificar.sh: ok ($MODO)"
