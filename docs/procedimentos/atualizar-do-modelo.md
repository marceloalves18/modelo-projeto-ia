# Atualizar um projeto a partir do modelo

O botão *Use this template* do GitHub copia o modelo **uma vez** e não mantém ligação. Quando o `modelo-projeto-ia` ganhar uma melhoria, cada projeto derivado precisa trazê-la à mão. Este procedimento vale para pessoas e agentes; o agente segue `[R-PLANO]` (mostra o que vai trazer e espera aprovação).

## 1. Ver o que mudou

```bash
git pull --rebase
scripts/comparar-modelo.sh             # versão e lista de arquivos diferentes
scripts/comparar-modelo.sh --detalhes  # diff de cada um ('-' = modelo, '+' = projeto)
```

O script só lê. Repositório do modelo é privado: a máquina precisa de acesso a ele (`gh auth setup-git`).

## 2. Trazer cada arquivo

- **Arquivo igual em todo projeto** (`.githooks/`, `scripts/verificar.sh`, `.claude/hooks/`, `.codex/hooks.json`, `tests/testar_protecoes.sh`, `.gitattributes`, `.github/workflows/`): copie a versão do modelo. Se o projeto mudou algo de propósito nele, reaplique a mudança por cima e registre o motivo no `AGENTS.md`.
  ```bash
  git fetch --depth 1 https://github.com/marceloalves18/modelo-projeto-ia.git main
  git checkout FETCH_HEAD -- scripts/verificar.sh    # um arquivo por vez
  ```
- **`scripts/verificar.sh`:** a seção de testes do projeto (a que era `PREENCHER`) é do projeto — preserve-a ao copiar.
- **`AGENTS.md` e `README.md`:** **não** copie inteiros. Compare só as seções que vêm do modelo (Portão, Regras universais, Definição de Pronto, Proteções automáticas) e traga as mudanças trecho a trecho. As seções do projeto ficam como estão.
- **`.caminhos-protegidos`:** é do projeto. Do modelo, traga só linhas de exemplo novas que fizerem sentido.

## 3. Conferir e registrar

1. `scripts/verificar.sh` — os testes das proteções têm que passar.
2. Atualize a linha `> **Modelo:**` do `AGENTS.md` para a versão trazida.
3. Um commit por assunto (`[R-COMMIT]`), por exemplo `chore(modelo): atualiza proteções para o modelo v1.1`.
