# Aplicar o modelo num projeto que já existe

Lições de 2026-10-17, ao aplicar o modelo no `automacao-apontamentos` e planejar o `prog_ssv`, o `SCA_Instrumentos-Nodejs-MQTT` e o `servidor-autenticacao-centralizado`. O agente segue `[R-PLANO]`: plano gravado em `docs/planejamentos/` do projeto e aprovado antes de mexer.

## Ordem

1. **Levantar sem alterar:** sessões de agente abertas na pasta (`readlink /proc/*/cwd`; cuidado: `pgrep -f claude` acha o próprio comando), `git status`, remoto, tamanho de cada seção do `AGENTS.md` e do `CONTEXT.md`, memórias de agente sobre o projeto, e **segredos** (passo 2).
2. **Segredos primeiro.** O `gitleaks` só pega formato de chave: **leia** os documentos procurando senha em texto aberto (seções "Credenciais", "senha `…`", hashes `{CRYPT}`). Se houver e o repositório tiver poucos clones, tire os valores para um arquivo `*.local.*` fora do git e reescreva o histórico com `git filter-repo --replace-text` (backup com `git bundle` antes; conferir 0 ocorrências depois). O push forçado é do usuário. Depois do push forçado, o commit antigo continua acessível no GitHub pelo hash até a limpeza interna; apagar e recriar o repositório é a única forma garantida.
3. **Reduzir `CONTEXT.md` (< 20 KB) e `AGENTS.md` (< 28 KB) antes de ligar as proteções.** Com o pre-commit ligado, **nenhum commit entra** enquanto um dos dois passar do limite — e afrouxar o limite no projeto quebra `tests/testar_protecoes.sh`; `--no-verify` é proibido.
4. **Só então copiar as proteções** do modelo e ajustar o `.caminhos-protegidos` do projeto.

## Como mover documentação sem perder nada

- Mover **sem reescrever**, cortando pelos títulos, e conferir que o texto somado das partes é igual ao original.
- Cada seção é lida por inteiro antes de ser movida (substitui a leitura completa de um arquivo grande de uma vez — combinar isso com o usuário como exceção à regra de leitura).
- Enxugar (só a versão atual de cada regra) é uma etapa **separada**, um arquivo por vez, com revisão do usuário.
- No fim, **conferência termo a termo**: todo termo entre crases do arquivo original tem que estar em algum arquivo novo ou no histórico; o que faltar, avaliar um por um.
- Referências "ver seção X abaixo" e "pendência N" quebram com a mudança: reapontar para o arquivo novo.

## Commits

- Um por assunto. Quando dois assuntos mexem no mesmo arquivo, montar o estado intermediário e gravá-lo no índice (`git hash-object -w` + `git update-index --cacheinfo`), conferindo `git diff --cached` antes de cada commit.
- **Nunca encadear edição, commit e push num comando só**: uma edição que falha em silêncio gera commit com mensagem que não bate com o conteúdo.
