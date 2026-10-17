@./AGENTS.md

## Só para o Gemini CLI

- As instruções do projeto estão no `AGENTS.md`, importado acima. Não acrescente regras do projeto aqui — elas valem para todos os agentes e vão no `AGENTS.md` (`[R-NEUTRO]`).
- **Não use a memória do Gemini neste projeto** (`[R-MEMORIA]`): nada em `~/.gemini/GEMINI.md`, nada na pasta de memória privada do projeto e **nada acrescentado a este `GEMINI.md`**. Quando o usuário pedir para "lembrar" algo, grave no `AGENTS.md`, em `docs/` ou no `CONTEXT.md`.
- Os hooks do Claude Code (`.claude/hooks/`) não protegem o Gemini: a proteção aqui é o pre-commit (`.githooks/`) e o GitHub. Siga as regras de `[R-PROTEGIDOS]` e `[R-DESTRUTIVO]` com atenção redobrada.
