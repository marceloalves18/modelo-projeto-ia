#!/usr/bin/env bash
# Hook SessionStart do Claude Code: o que ele imprime vira contexto da sessão.
# Avisa o que [R-SINCRONIA], [R-PASSAGEM], [R-TAMANHO] e o setup exigem antes de começar.
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
git rev-parse --is-inside-work-tree > /dev/null 2>&1 || exit 0

avisos=()

if GIT_TERMINAL_PROMPT=0 timeout 15 git fetch --quiet 2> /dev/null; then
    if git rev-parse '@{u}' > /dev/null 2>&1; then
        atras="$(git rev-list --count 'HEAD..@{u}')"
        if (( atras > 0 )); then
            avisos+=("A cópia local está $atras commit(s) atrás do remoto: rode 'git pull --rebase' ANTES de ler as instruções e começar ([R-SINCRONIA]).")
        fi
    fi
else
    avisos+=("Não foi possível consultar o remoto (git fetch falhou ou passou de 15 s): confirme com o usuário se a cópia está atualizada antes de começar ([R-SINCRONIA]).")
fi

if [[ "$(git config core.hooksPath)" != ".githooks" ]]; then
    avisos+=("O pre-commit NÃO está instalado nesta máquina: peça ao usuário para rodar 'git config core.hooksPath .githooks' (README.md).")
fi

if [[ -n "$(git status --porcelain 2> /dev/null)" ]]; then
    avisos+=("Há alterações não commitadas — podem ser trabalho de outra sessão ou agente. Antes de mexer nelas, veja docs/planejamentos/ (seção Andamento) e o CONTEXT.md ([R-PASSAGEM]).")
fi

for par in "AGENTS.md:28672" "CONTEXT.md:20480"; do
    arquivo="${par%%:*}"
    limite="${par##*:}"
    if [[ -f "$arquivo" ]] && (( $(wc -c < "$arquivo") > limite )); then
        avisos+=("$arquivo passou de $limite bytes: mova detalhes para docs/ antes de acrescentar mais ([R-TAMANHO]).")
    fi
done

if (( ${#avisos[@]} > 0 )); then
    echo "Avisos do projeto no início da sessão:"
    printf -- '- %s\n' "${avisos[@]}"
fi
exit 0
