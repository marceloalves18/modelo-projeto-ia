# <!-- PREENCHER: nome do projeto -->

<!-- PREENCHER: uma ou duas linhas sobre o que o projeto faz. -->

## Antes de começar (obrigatório em cada máquina)

```bash
git clone <url-do-repositório>
cd <pasta>
git config core.hooksPath .githooks    # liga o pre-commit — sem isso você fica sem proteção
cp .env.exemplo .env                   # e preencha os valores (o .env nunca vai para o git)
```

**gitleaks** (obrigatório em cada máquina, `[R-SETUP]` no AGENTS.md): o pre-commit usa para achar segredo dentro dos arquivos; sem ele, só barra pelos nomes de `.caminhos-protegidos`. Precisa da versão **8.19 ou mais nova** — a do `apt` do Ubuntu 24.04 (8.16) não serve. Release oficial, com checksum, sem sudo.

*Linux e macOS* (detecta sistema e arquitetura):

```bash
V=8.30.1
case "$(uname -s)" in Linux) SO=linux ;; Darwin) SO=darwin ;; esac
case "$(uname -m)" in x86_64|amd64) ARQ=x64 ;; arm64|aarch64) ARQ=arm64 ;; esac
ARQUIVO="gitleaks_${V}_${SO}_${ARQ}.tar.gz"
D="$(mktemp -d)" && cd "$D"
curl -fsSLO "https://github.com/gitleaks/gitleaks/releases/download/v$V/$ARQUIVO"
curl -fsSLO "https://github.com/gitleaks/gitleaks/releases/download/v$V/gitleaks_${V}_checksums.txt"
grep " $ARQUIVO\$" "gitleaks_${V}_checksums.txt" > conferir.txt
if command -v sha256sum > /dev/null; then sha256sum -c conferir.txt; else shasum -a 256 -c conferir.txt; fi   # tem que dizer OK/SUCESSO
tar -xzf "$ARQUIVO" gitleaks
mkdir -p ~/.local/bin && install -m 0755 gitleaks ~/.local/bin/gitleaks
cd - && rm -rf "$D"
gitleaks version   # se der "command not found", ponha ~/.local/bin no PATH (no macOS não vem por padrão)
```

*Windows:* baixe `gitleaks_8.30.1_windows_x64.zip` da [página de releases](https://github.com/gitleaks/gitleaks/releases), confira o SHA-256 com o `gitleaks_8.30.1_checksums.txt` (`Get-FileHash` no PowerShell), extraia o `gitleaks.exe` para uma pasta que esteja no PATH e confira com `gitleaks version` no **Git Bash** — é nele que os hooks rodam. Os hooks do Claude precisam também do comando `python3` no PATH.

<!-- PREENCHER: venv, dependências, variáveis de ambiente (ver AGENTS.md § Setup em Novo Ambiente). -->

**Codex:** na primeira sessão no projeto, o Codex pede para revisar e **confiar** nos hooks de `.codex/hooks.json` (e de novo sempre que eles mudarem). Confira que apontam para `.claude/hooks/` e confie — sem isso ele roda sem as proteções.

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
