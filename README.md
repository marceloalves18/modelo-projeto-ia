# <!-- PREENCHER: nome do projeto -->

<!-- PREENCHER: uma ou duas linhas sobre o que o projeto faz. -->

## Antes de começar (obrigatório em cada máquina)

```bash
git clone <url-do-repositório>
cd <pasta>
git config core.hooksPath .githooks    # liga o pre-commit — sem isso você fica sem proteção
```

**gitleaks** (obrigatório em cada máquina, `[R-SETUP]` no AGENTS.md): o pre-commit usa para achar segredo dentro dos arquivos; sem ele, só barra pelos nomes de `.caminhos-protegidos`. Precisa da versão **8.19 ou mais nova** — a do `apt` do Ubuntu 24.04 (8.16) não serve. Instalação da release oficial, sem sudo (Linux x64; outros sistemas: [página de releases](https://github.com/gitleaks/gitleaks/releases)):

```bash
V=8.30.1
D="$(mktemp -d)" && cd "$D"
curl -fsSLO "https://github.com/gitleaks/gitleaks/releases/download/v$V/gitleaks_${V}_linux_x64.tar.gz"
curl -fsSLO "https://github.com/gitleaks/gitleaks/releases/download/v$V/gitleaks_${V}_checksums.txt"
grep linux_x64.tar.gz "gitleaks_${V}_checksums.txt" | sha256sum -c -    # tem que dizer OK/SUCESSO
tar -xzf "gitleaks_${V}_linux_x64.tar.gz" gitleaks
mkdir -p ~/.local/bin && install -m 0755 gitleaks ~/.local/bin/gitleaks
cd - && rm -rf "$D"
gitleaks version
```

<!-- PREENCHER: venv, dependências, variáveis de ambiente (ver AGENTS.md § Setup em Novo Ambiente). -->

## Como se trabalha aqui

O projeto é usado em mais de uma máquina, por mais de uma pessoa e com mais de um agente de IA (Claude Code, Codex, Gemini…). Para isso funcionar:

- **Regras de trabalho:** estão no [`AGENTS.md`](./AGENTS.md) — valem para pessoas e agentes.
- **Sempre `git pull --rebase`** antes de começar e antes de cada push.
- **Pendências entre sessões** ficam no `CONTEXT.md`; **planos em andamento** em `docs/planejamentos/`. Nada fica só na memória de um agente ou numa conversa.
- **Segredos e dados reais** estão listados em [`.caminhos-protegidos`](./.caminhos-protegidos); o pre-commit não deixa commitá-los.
- **Verificação:** `scripts/verificar.sh` — o mesmo comando para todo mundo.

## Trocar de agente no meio de uma tarefa

1. Confira se o plano em `docs/planejamentos/` está com a seção **Andamento** atualizada.
2. Se for trocar também de **máquina**: commit `wip(...)` e `git push`.
3. No agente novo: peça para ler o `AGENTS.md`, o `CONTEXT.md` e o plano, e continuar do **Andamento**.
