@AGENTS.md

## Só para o Claude Code

- As instruções do projeto estão no `AGENTS.md`, importado acima. Não acrescente regras do projeto aqui — elas valem para todos os agentes e vão no `AGENTS.md` (`[R-NEUTRO]`).
- A memória automática está desligada em `.claude/settings.json` (`autoMemoryEnabled: false`). Não salve nada em `~/.claude/` sobre este projeto, nem quando o usuário pedir para "lembrar" algo: grave no `AGENTS.md`, em `docs/` ou no `CONTEXT.md` (`[R-MEMORIA]`).
- Os hooks de `.claude/hooks/` (usados também pelo Codex, via `.codex/hooks.json`) bloqueiam o que as regras proíbem. Se um hook bloquear uma ação, **não tente contorná-lo**: explique ao usuário o que foi bloqueado e por quê.
- Planos do modo de planejamento vão para `docs/planejamentos/`, nunca para `~/.claude/plans/` (`[R-PASSAGEM]`, `[R-FORA-DO-REPO]`).
