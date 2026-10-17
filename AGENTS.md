# AGENTS.md

> **Modelo:** v1.0 (2026-10-17), de `modelo-projeto-ia`. **Não apague esta linha**: ela diz de qual versão do modelo o projeto saiu.
>
> **Projeto novo:** preencha as seções marcadas com `<!-- PREENCHER -->` (aqui e no `README.md`) e apague esta linha. O `scripts/verificar.sh` avisa enquanto restar alguma.

Instruções para **qualquer assistente de IA** (Claude Code, Codex, Gemini CLI, Copilot, Cursor, Aider…) e para **qualquer pessoa** que trabalhe neste repositório. É a **fonte de verdade única**: `CLAUDE.md` e `GEMINI.md` só importam este arquivo e acrescentam dicas da própria ferramenta. O projeto é usado **em mais de uma máquina, por mais de uma pessoa e por mais de um agente** — tudo que for preciso para continuar o trabalho tem que estar no repositório.

## Portão — vale antes da primeira ação da sessão

1. **Sincronize primeiro:** `git pull --rebase` antes de ler qualquer coisa. Outra máquina, pessoa ou agente pode ter mudado estas instruções. `[R-SINCRONIA]`
2. **Antes de editar, criar ou apagar arquivo, commitar, rodar script que grave algo ou mexer em servidor/equipamento:** ler este arquivo **e** o `CONTEXT.md` (quando existir) **por inteiro**, e os `docs/modulos/` que o [Mapa de leitura](#mapa-de-leitura) indicar para a área. `[R-LEITURA]`
3. **Pergunta só de leitura** (explicar, investigar, listar): basta este arquivo. Se a conversa passar a alterar algo, o item 2 vale a partir daí.
4. **Pedido de correção ou de funcionalidade não é autorização para implementar.** Em tarefa não-trivial: diagnóstico/plano → aprovação explícita → código. `[R-PLANO]`
5. **Plano aprovado vai para `docs/planejamentos/` antes do primeiro passo**, e é atualizado a cada passo concluído. `[R-PASSAGEM]`

Se não tiver certeza de que leu tudo, **diga o que faltou ler** em vez de seguir adiante.

## Regras universais

As regras têm **ID estável** (`[R-…]`): cite sempre pelo ID, nunca por número. Para criar uma regra, dê um ID novo; para remover, apague a linha e procure o ID no repositório.

**Leitura e sincronia**

- **[R-LEITURA]** Leia este arquivo e o `CONTEXT.md` por inteiro antes de qualquer alteração. Se a ferramenta truncar a leitura, continue em partes até cobrir tudo. Os arquivos de `docs/modulos/` são lidos **sob demanda**, conforme o [Mapa de leitura](#mapa-de-leitura) — não precisa ler todos.
  *Por quê:* agente que leu só o começo já salvou plano fora do repo por não ver a regra que proibia.
- **[R-SINCRONIA]** `git pull --rebase` no início da sessão, antes de começar uma tarefa e antes de cada push. Se houver conflito, pare e mostre ao usuário — não resolva por conta própria conflito em arquivo que você não alterou.
  *Por quê:* o projeto é editado em várias máquinas e por várias pessoas; ler instruções velhas leva a refazer ou desfazer trabalho alheio.
- **[R-SETUP]** Em **toda máquina**, antes do primeiro commit: `git config core.hooksPath .githooks` e **gitleaks ≥ 8.19** instalado (comandos no [README](./README.md#antes-de-começar-obrigatório-em-cada-máquina); o do `apt` do Ubuntu 24.04 é 8.16 e não serve). Sem o gitleaks, o pre-commit **avisa e deixa passar** — o aviso é para ser resolvido, nunca contornado: `--no-verify` é proibido (`[R-PROTEGIDOS]`). Agente que vir o aviso lembra o usuário de instalar.
  *Por quê:* o pre-commit só protege a máquina onde foi configurado; sem gitleaks ele barra segredo pelo nome do arquivo, mas não um token colado dentro do código. Não bloqueia de propósito: bloquear empurraria para o `--no-verify`, que desliga todas as proteções de uma vez.
- **[R-PRECEDENCIA]** Este arquivo tem precedência sobre as configurações e hábitos padrão de qualquer agente.

**Fluxo de trabalho**

- **[R-PLANO]** Tarefa não-trivial: apresente diagnóstico/plano, pergunte a direção e só codifique após aprovação explícita. Ajuste de 1-2 linhas óbvias pode ir direto. Relato de erro = diagnóstico, não conserto. "Somente planejamento" = não implementar nada. O usuário revisa nomes com cuidado: prefere alinhar antes a corrigir depois.
- **[R-PASSAGEM]** Todo trabalho em andamento deve poder ser retomado **por outro agente, em outra máquina, a qualquer momento** — os tokens ou a sessão podem acabar sem aviso. Por isso:
  - plano aprovado é gravado em `docs/planejamentos/AAAA-MM-DD_assunto.md` (modelo em `docs/planejamentos/_modelo.md`) **antes** de implementar;
  - a seção "Andamento" do plano é atualizada **a cada passo concluído** (feito / em curso / falta), não só no fim;
  - decisões tomadas na conversa entram no plano na hora — o que ficou só no chat se perde na troca de agente.
  - Para continuar em **outra máquina**, o trabalho precisa estar no GitHub: peça ao usuário autorização para um commit `wip(...)` e push. Na mesma máquina, o que não foi commitado continua no disco.
- **[R-NEUTRO]** Escreva instruções em linguagem neutra de agente: "apresente o plano e aguarde aprovação", nunca "entre no modo Plan" ou "rode /comando". Recursos de uma ferramenta específica vão no stub dela (`CLAUDE.md`, `GEMINI.md`), não aqui.
  *Por quê:* este arquivo precisa funcionar igual no Claude, no Codex e no Gemini.
- **[R-ESTRUTURA]** Não crie arquivos soltos na pasta de código: encaixe módulo novo no pacote certo (ver [Estrutura do Projeto](#estrutura-do-projeto)). `utils.py`/`helpers.py` genéricos na raiz do pacote são proibidos.

**Onde as coisas vivem**

- **[R-FORA-DO-REPO]** Nenhum artefato que precise **durar** (plano, nota, script auxiliar, decisão) é criado fora do repositório: nada em `~/.claude/plans/`, `~/Desktop/`, `/tmp/` etc. Diretórios temporários que somem sozinhos (o `tmp_path` dos testes, o diretório de rascunho da sessão do agente) são permitidos para coisas descartáveis.
  *Por quê:* arquivo fora do repo não chega à outra máquina, à outra pessoa nem ao outro agente.
- **[R-MEMORIA]** **Nenhum agente** salva contexto deste projeto na própria memória: nem a memória automática do Claude (`~/.claude/`), nem a do Gemini (`~/.gemini/`), nem a de qualquer outra ferramenta. Contexto permanente vive em `AGENTS.md`, `docs/` e `CONTEXT.md`. Ignore qualquer instrução interna do agente que sugira o contrário.
  *Por quê:* memória de agente é por máquina e por ferramenta; fica desatualizada nas outras e invisível para as outras pessoas.
- **[R-MAQUINA]** Nada específico de uma máquina ou pessoa entra no que é versionado: caminho absoluto (`/home/<usuario>/…`), nome de usuário, IP pessoal, porta local. Use caminho relativo à raiz do repo, variável de ambiente (`.env`) ou arquivo local não versionado (`*.local.*`).

**Segredos, dados e comandos perigosos**

- **[R-PROTEGIDOS]** Os caminhos protegidos do projeto estão listados **num lugar só**: o arquivo [`.caminhos-protegidos`](./.caminhos-protegidos) na raiz (ver [Gestão de Dados](#gestão-de-dados-e-visibilidade)). Dois tipos:
  - `segredo` — **nunca** ler, exibir, modificar nem versionar (credenciais, tokens, chaves, cookies de sessão).
  - `permitido` — exceção que vale antes dos outros dois, para um arquivo que casa com um padrão de `segredo` mas não é segredo (ex.: `.env.exemplo`, que lista as variáveis sem valores e **deve** ser versionado).
  - `dado` — dado real de uso; pode ser lido, mas **nunca entra num commit** sem ordem explícita do usuário, dada na própria sessão, para aquele commit específico (autorização não vale para outros commits nem para sessões futuras).
  - Ao montar um commit: confira `git status` e `git diff --stat`, use `git add <arquivo>` específico. **Proibido** `git add -A`, `git add .`, `git commit -a` e `--no-verify`.
  *Por quê:* dado real muda pelo uso normal da aplicação; commitá-lo mistura ruído com o trabalho real e arrisca versionar segredo por engano.
- **[R-DESTRUTIVO]** Peça confirmação antes de: `rm -rf`, `git push --force`, `git reset --hard`, `git clean`, apagar branch, migração de banco, reinício de serviço, qualquer escrita em servidor ou equipamento. Em dúvida sobre **qual** host ou ambiente (produção × desenvolvimento, IPs parecidos), confirme com o usuário antes de agir.
- **[R-DADOS-DE-TESTE]** Script de diagnóstico ou validação **nunca grava nos dados reais**. Use diretório temporário ou mock das funções de leitura/gravação; com a aplicação real, só leitura. Se o caminho de dados é definido em mais de um módulo, redirecione **todos** antes de rodar, e confira `git status` logo depois.
  *Por quê:* script de validação que subiu a aplicação real já reescreveu dados de produção sem ninguém perceber na hora.

**Documentação**

- **[R-TAMANHO]** Este arquivo fica abaixo de **28 KB** e o `CONTEXT.md` abaixo de **20 KB** — o `scripts/verificar.sh` recusa o commit acima disso. Não crie `AGENTS.override.md` nem `AGENTS.md` em subpastas: o Codex os soma a este, e o override **substitui** este arquivo.
  *Por quê:* o Codex para de ler instruções quando a soma dos `AGENTS.md` (o global da pessoa, em `~/.codex/`, mais o do projeto) chega a 32 KiB — os 4 KB de folga são para o global. E todo agente perde qualidade quando as instruções ocupam o contexto. Um projeto anterior chegou a 469 KB.
- **[R-DOC]** Ao final de cada tarefa, a documentação fica atualizada — em dois sentidos: (a) **acrescentar** o que foi aprendido e (b) **corrigir ou remover** o que descreve comportamento que a tarefa mudou (documentação errada engana; é pior que nenhuma). E **no lugar certo**:
  - detalhe de uma área (fluxo, armadilha, integração) → `docs/modulos/<area>.md`, e **uma linha** no [Mapa de leitura](#mapa-de-leitura);
  - decisão e seu contexto → `docs/planejamentos/`;
  - guia de operação ou setup → `docs/procedimentos/`;
  - regra que vale para o projeto todo → aqui, curta.
  - Este arquivo descreve **o estado atual**, nunca o histórico ("antes era X, depois Y" fica no `git log` e nos planejamentos).
- **[R-PENDENCIAS]** O `CONTEXT.md` é **só** caderno de pendências entre sessões, no formato da seção [CONTEXT.md](#contextmd--caderno-de-pendências). Pendência resolvida é **removida** (não marcada como `[x]`); se virar referência permanente, vai para `docs/`. Arquivo vazio pode ser apagado.

**Qualidade**

- **[R-VERIFICAR]** A verificação do projeto é **um comando só**: `scripts/verificar.sh`. Qualquer agente e qualquer pessoa rodam o mesmo comando e têm o mesmo resultado — não reinvente a verificação em prosa. Se o projeto ganhar um passo de verificação novo, ele entra no script. Ao mexer numa proteção (`.githooks/`, `scripts/verificar.sh`, `.claude/hooks/`), o caso novo entra em `tests/testar_protecoes.sh` — e tem que falhar sem a mudança (`[R-REGRESSAO]`).
- **[R-COMMIT]** Um commit por assunto (funcionalidade, bug, solução, documentação), nunca um commit com tudo da sessão. Cada commit coerente sozinho (compila, testes que ele toca passam) e em ordem que faça sentido. Assuntos misturados no mesmo arquivo: separe por trechos (`git add -p`). Mensagem `tipo(escopo): resumo` (`feat`, `fix`, `docs`, `test`, `refactor`, `wip`), em português, dizendo o **porquê**. Documentação em commit próprio no fim, salvo quando for a única mudança. **Nunca** commitar sem o usuário pedir.
- **[R-REGRESSAO]** Todo bug corrigido ganha um teste que **falha sem a correção** (confira revertendo ou mutando o trecho) e passa com ela. Vai no mesmo commit do `fix`, e a mensagem cita o nome do teste. Bug só visual ou de infraestrutura: diga isso no commit e registre a validação manual. Não vale para texto, estilo ou documentação.
- **[R-LIB-REAL]** Código que monta argumentos para biblioteca externa (agendador, cliente MQTT/HTTP, automação de navegador, pandas, LDAP, framework web…) tem **ao menos um teste com a biblioteca real** — mock aceita qualquer argumento e esconde exatamente o erro que a biblioteca daria. Use a biblioteca real sempre que ela não tiver efeito externo.
- **[R-VALIDACAO-REAL]** Tela ou fluxo novo só está pronto depois de validado **de verdade e com o volume real de dados** — suíte verde não cobre layout nem uso real.
  - Antes de implementar, **conte** o que a tela vai tratar (linhas, tamanho dos nomes, volume) e confronte com o plano: plano aprovado fixa decisões, não a realidade da base.
  - Antes de entregar, suba a página num navegador headless com **cópia** dos dados reais (respeitando `[R-DADOS-DE-TESTE]`) e confira o que o teste não vê: texto truncado (`scrollWidth > clientWidth`), sobreposição (`document.elementFromPoint`), fundo em rolagem, popup vazando da tela.
  - Proxy do ambiente (`http_proxy`) pode interceptar `127.0.0.1`: limpe as variáveis de proxy no processo do navegador.
- **[R-DATAS]** Teste de lógica que depende de "hoje" nunca usa data fixa — calcule em tempo de execução (`now() - timedelta(days=N)`), senão o teste quebra sozinho meses depois.
- **[R-DEPENDENCIAS]** Versões fixadas (`==` no `requirements.txt`, ou lockfile), ambiente virtual obrigatório (`venv`), nada instalado globalmente (nem `pip install --user`; use `venv` ou `pipx`).

## Definição de Pronto

Antes de dizer que uma tarefa terminou, confira — e diga ao usuário o que **não** foi feito:

- [ ] `scripts/verificar.sh` passou (cite o resultado: quantos testes, tempo, falhas).
- [ ] Bug corrigido tem teste de regressão que falha sem a correção. `[R-REGRESSAO]`
- [ ] Tela ou fluxo novo validado de verdade, com volume real. `[R-VALIDACAO-REAL]`
- [ ] Plano em `docs/planejamentos/` com o "Andamento" final. `[R-PASSAGEM]`
- [ ] Documentação atualizada no lugar certo, trechos obsoletos removidos. `[R-DOC]`
- [ ] `CONTEXT.md` sem pendência já resolvida. `[R-PENDENCIAS]`
- [ ] `git status` conferido: nada de `segredo` ou `dado` no stage. `[R-PROTEGIDOS]`

## Proteções automáticas

As regras acima são o **porquê**; estas ferramentas são a **garantia**. Elas ficam versionadas no repo, então valem para todas as máquinas e pessoas — desde que o setup tenha sido feito.

| Camada | Onde | O que bloqueia | Vale para |
|---|---|---|---|
| Git (pre-commit) | `.githooks/pre-commit` → `scripts/verificar.sh --staged` | arquivo `segredo`/`dado` no stage, `AGENTS.md` > 28 KB, `CONTEXT.md` > 20 KB, segredo no conteúdo (gitleaks ≥ 8.19; sem ele, avisa e deixa passar) | qualquer pessoa ou agente que commitar, **depois do setup** |
| GitHub Actions | `.github/workflows/verificar.yml` | roda o `scripts/verificar.sh` completo, com gitleaks, a cada push: acusa o que escapou de qualquer máquina (setup não feito, `--no-verify`) | todos, sem depender de setup local |
| GitHub (servidor) | configuração do repositório | push direto sem passar pelas regras da branch; segredo no push (secret scanning) | todos, se o plano da conta permitir |
| Codex | `.codex/hooks.json` → os mesmos scripts de `.claude/hooks/` | o mesmo que no Claude, exceto: comando destrutivo é **bloqueado** (o Codex não sabe pedir confirmação) e a memória do Codex não é desligada por configuração | só o Codex, **depois de você confiar nos hooks** do projeto (o Codex pede revisão na primeira vez e a cada mudança neles) |
| Claude Code | `.claude/settings.json` + `.claude/hooks/` | gravação fora do repo, acesso a `segredo`, `git add -A`/`.`, `--no-verify`; pede confirmação em comando destrutivo; avisa no início se a cópia está atrás do remoto, se o pre-commit não está instalado ou se falta o gitleaks; desliga a memória automática | só o Claude Code |

- **Commit autorizado de um `dado`:** só com ordem explícita do usuário para aquele commit, e então `PERMITIR_DADOS=1 git commit …`. Não existe exceção para `segredo`.
- **Falha no GitHub Actions** (✗ vermelho no commit): o problema já está no remoto. Corrija com um commit novo; se for segredo, **troque o segredo** (ele já vazou para o histórico) antes de qualquer outra coisa, e avise o usuário.
- **GitHub:** em *Settings → Branches*, proteja a branch principal; em *Settings → Code security*, ligue o *secret scanning* e a *push protection* se o plano da conta permitir em repositório privado. <!-- PREENCHER: registrar aqui o que foi ligado. -->
- **Gemini e outros agentes** não têm hooks configurados aqui: para eles, a proteção é o pre-commit e o GitHub. A própria documentação do Codex avisa que hooks são "proteção útil, não barreira completa" — vale para o Claude também.

## Visão Geral do Projeto

<!-- PREENCHER: o que é o projeto, quem usa, qual o foco (2 a 5 linhas). -->

## Mapa de leitura

Detalhes de cada área ficam em `docs/modulos/` e são lidos **só quando a tarefa toca aquela área** (`[R-LEITURA]`). Uma linha por área (modelo em `docs/modulos/_modelo.md`):

| Ao mexer em… | Ler antes |
|---|---|
| <!-- PREENCHER: ex. `app/scripts/scraping.py`, `app/services/sap*.py` --> | <!-- ex. `docs/modulos/scraping.md` --> |

## Estrutura do Projeto

<!-- PREENCHER: árvore resumida das pastas e o papel de cada pacote. `[R-ESTRUTURA]` depende desta seção. -->

```
.
├── AGENTS.md                 instruções (fonte única)
├── CLAUDE.md, GEMINI.md      stubs que importam o AGENTS.md
├── README.md                 setup para pessoas
├── CONTEXT.md                pendências entre sessões (quando houver)
├── .caminhos-protegidos      segredos e dados reais (lista única)
├── .githooks/                hooks de git versionados
├── .gitattributes            scripts sempre com final de linha LF (Windows)
├── .claude/                  configuração e hooks do Claude Code (versionados)
├── .codex/hooks.json         hooks do Codex (usam os scripts de .claude/hooks/)
├── .github/workflows/        verificação no GitHub a cada push
├── scripts/verificar.sh      verificação única do projeto
├── tests/testar_protecoes.sh testes das proteções (rodam dentro do verificar.sh)
└── docs/
    ├── modulos/              detalhe por área (lido sob demanda)
    ├── planejamentos/        decisões e planos em andamento
    └── procedimentos/        guias de setup e operação
```

## Comandos

```bash
scripts/verificar.sh            # verificação completa (testes + checagens do repo)
scripts/verificar.sh --staged   # só as checagens do que está no stage (o pre-commit usa este)
tests/testar_protecoes.sh       # só os testes das proteções (pre-commit, verificar.sh, hooks do Claude e do Codex)
scripts/comparar-modelo.sh      # o que mudou no modelo-projeto-ia desde que este projeto saiu dele (só lê)
```

<!-- PREENCHER: rodar a aplicação; rodar testes por categoria/arquivo; cobertura mínima. Os testes em si entram em `scripts/verificar.sh`. -->

## Setup em Novo Ambiente

Obrigatório em **cada máquina** e para **cada pessoa** (o pre-commit não se instala sozinho):

```bash
git config core.hooksPath .githooks
```

E instalar o **gitleaks ≥ 8.19** (`[R-SETUP]`) — comandos no [README](./README.md#antes-de-começar-obrigatório-em-cada-máquina).

<!-- PREENCHER: venv e dependências (ex. `python3 -m venv venv && venv/bin/pip install -r requirements.txt`), variáveis de ambiente, binários necessários. -->

## Variáveis de Ambiente

Os valores ficam em `.env` (`segredo`: nenhum agente lê). Os **nomes** ficam em `.env.exemplo`, versionado e `permitido`, com cada variável e um valor fictício ou vazio — é nele que pessoas e agentes descobrem o que precisa ser configurado. Variável nova entra no `.env.exemplo` no mesmo commit do código que a usa.

<!-- PREENCHER: nome, para que serve, obrigatória ou não. Nunca registrar valores reais aqui. -->

## Gestão de Dados e Visibilidade

A lista do que é `segredo` e do que é `dado` está em [`.caminhos-protegidos`](./.caminhos-protegidos) — é a **única** lista; pre-commit e hooks do Claude leem dela. Ao criar um caminho sensível novo, acrescente uma linha lá **no mesmo commit** e, se ele não deve nem existir no repo, também no `.gitignore`.

<!-- PREENCHER: explicar cada linha do .caminhos-protegidos (o que é, de onde vem, quem pode ver) e o que é versionado de propósito. -->

## Fluxo de Git

- Trabalha-se direto na branch principal (`main`), com `git pull --rebase` antes de começar e antes do push (`[R-SINCRONIA]`). Push: `git push origin main`.
- Repositório **privado**.
- Antes de trocar de máquina com trabalho pela metade: commit `wip(...)` autorizado pelo usuário e push (`[R-PASSAGEM]`).
<!-- PREENCHER: nome do remoto, se for diferente; ajustar se o projeto passar a usar branch por tarefa com PR. -->

## Documentação Técnica

- `docs/modulos/` — detalhe por área, lido sob demanda pelo [Mapa de leitura](#mapa-de-leitura).
- `docs/planejamentos/` — um arquivo por decisão ou plano (`AAAA-MM-DD_assunto.md`, modelo em `_modelo.md`), com contexto, decisão, alternativas e andamento.
- `docs/procedimentos/` — guias de setup e operação. Trazer melhorias do modelo: `atualizar-do-modelo.md`.

Consulte antes de propor mudanças nas áreas já documentadas.

### `CONTEXT.md` — caderno de pendências

Só pendências entre sessões, máquinas, pessoas e agentes (`[R-PENDENCIAS]`). Ao ler: trate como tarefa em aberto, não como verdade arquitetural. Cada entrada neste formato:

```markdown
## <assunto curto>
- **Aberta em:** AAAA-MM-DD por <pessoa> em <máquina>, com <agente>
- **Estado:** <o que já foi feito e onde parou>
- **Próximo passo:** <ação concreta>
- **Arquivos:** <caminhos relativos à raiz do repo>
- **Plano:** <docs/planejamentos/…, se houver>
```

Quem e onde importam: com várias pessoas e máquinas, é o que permite perguntar a quem abriu. Edite só as suas entradas ou a que estiver retomando; em conflito de merge, preserve as duas versões e pergunte.

## Estilo e Convenções

- **Idioma:** textos visíveis, logs, mensagens de commit e documentação em português do Brasil, **com acentuação correta**. Identificadores (variáveis, funções, arquivos, pastas) **sem acento**, para evitar problemas de encoding e de import. <!-- PREENCHER se o projeto usar outro idioma. -->
- **Timezone:** <!-- PREENCHER: ex. sempre `America/Sao_Paulo`. -->
- **Termos do domínio:** <!-- PREENCHER: vocabulário exigido nos textos visíveis e o que permanece como está nos dados. -->
- **Sem acesso à internet?** <!-- PREENCHER se a rede do projeto não tiver acesso externo: fontes, ícones e bibliotecas servidos localmente, nunca por CDN. -->

### Convenções da stack

<!-- PREENCHER: trocar ou apagar o bloco abaixo conforme a linguagem do projeto. Exemplo para Python: -->

- **Formatação:** quem decide é o formatador (ex.: `ruff format`), rodado pelo `scripts/verificar.sh`. Chamadas e condicionais longas ficam **expandidas em várias linhas** — use a vírgula final para o formatador manter assim. Não desfaça formatação feita à mão pelo usuário.
- **Logging, não print:** `log = logging.getLogger(__name__)` em cada módulo, formatação preguiçosa `log.info("foo: %s", valor)`. Código novo nunca usa `print()`; ao tocar em código antigo com `print()`, troque.
- **Privado de módulo:** prefixo `_` (`_APP_DIR`, `_lock`). Caminho de dados deriva de **uma** constante, idealmente de um único módulo de acesso a arquivos (ver `[R-DADOS-DE-TESTE]`).
- **Testes:** dados descartáveis em `tmp_path`; nunca no diretório real de dados.
