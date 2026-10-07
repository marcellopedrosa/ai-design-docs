---
document_id: TP-00051
primary_nature: Plano
objective: Coordenar a ativacao da colecao canonica de PRDs e sua integracao ao gate de prontidao documental.
scope: ADR-0000, mapas e indices, template de PRD, PRD-00001, PRD-00002, Implementation Readiness, validador documental e testes hermeticos.
non_objectives: Alterar comportamento do produto, aprovar hipoteses de mercado, promover PRDs a Validated, executar Git, acessar rede, ambiente externo ou dados reais.
owner: Arquitetura, Produto e Qualidade
status: Completed
date: 2026-09-09
version: 1.1
last_reviewed: 2026-09-09
keywords: prd, produto, governanca, readiness, documentacao
related_files: harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md, do../../product/requirements/README.md - destino planejado, harne../../../harness/templates/TPL-00001-prd.md - destino planejado, do../../agents/standards/implementation-readiness-standard.md
code_references: infra/scripts/validate-docs.sh, validate-documentation-governance.test.mjs, infra/scripts/validate-docs.sh
principal_statement: A colecao de PRDs deve tornar explicitos problema, publico, resultados, metricas e hipoteses de produto sem duplicar requisitos, casos de uso ou decisoes arquiteturais.
---

# TP-00051 — Governanca de Product Requirements Documents

## 1. Objective and outcome

Ativar `do../../product/requirements/` como fonte canonica de intencao e validacao de
iniciativas de produto, preservando `do../../product/requirements/` como fonte de comportamento
observavel e `do../../product/use-cases/` como fonte dos fluxos. O resultado esperado e uma
cadeia rastreavel `visao de produto -> PRD Validated -> requisitos -> casos de uso ->
planos -> implementacao`.

## 2. Sources and constraints

- Solicitacao humana de 2026-09-09, que define a colecao, os dois PRDs iniciais e
  os limites de conteudo.
- [ADR-0000](../../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md), decisao a ser
  atualizada para ativar o novo tipo documental e seu gate.
- [Visao do produto](../../product/business/product-vision.md), fonte de contexto comercial.
- [Requisitos](../../product/requirements/README.md) e [casos de uso](../../product/use-cases/README.md),
  fontes que nao podem ser duplicadas pelos PRDs.
- [Implementation Readiness](../../agents/standards/implementation-readiness-standard.md),
  hard gate que passara a exigir o PRD aplicavel em `Validated`.

## 3. Scope

### In scope

- Criar o indice semantico e o contrato de `do../../product/requirements/`.
- Criar `../../docs/prds/PRD-00001-billing-enterprise.md` e
  `../../docs/prds/PRD-00002-omnichannel-experience.md` a partir das fontes existentes.
- Criar `TPL-00001-prd.md` para agentes de IA.
- Atualizar ADR, mapas, indices, standard e skills pareadas de readiness.
- Tornar o novo contrato verificavel pelo wrapper documental e por teste hermetico.

### Out of scope

- Inventar pesquisa com cliente, baseline, meta numerica ou evidencia de mercado.
- Marcar os PRDs como `Validated` sem aprovacao e evidencias do owner de Produto.
- Reescrever acceptance criteria, fluxos de UC, arquitetura ou implementacao.
- Alterar backend, frontend, website, infraestrutura de produto ou ambientes.

## 4. Tasks

### TP-00051-T01 — Materializar a decisao e os artefatos documentais

**What:** Publicar a taxonomia, o template e os dois PRDs iniciais, com indices e
gate semantico coerentes.

**Where:** `docs/adrs/`, `docs/`, `do../../ai/`, `do../../product/requirements/`,
`harne../../../harness/templates/`, `do../../product/requirements/`, `do../../agents/standards/`,
`.agents/skills/implementation-readiness/` e
`.claude/skills/implementation-readiness/`.

**Depends on:** Solicitacao humana e fontes listadas na Section 2.

**Reuses:** Contrato minimo do ADR-0000, lifecycle do IRG e convencoes dos indices
existentes.

**Requirements:** Solicitacao humana; ADR-0000; product vision; standards de
governanca e readiness.

**Gate Audit:** Mudanca documental destinada a materializar as fontes do gate;
Implementation Readiness nao se aplica antes desta task por nao escrever software.

**Acceptance Tests:** Cada artefato criado possui contrato completo e entrada
individual no indice imediato; os PRDs nao repetem ACs, fluxos ou arquitetura; o
status inicial reflete a ausencia de validacao de produto.

**Prohibited:** Declarar evidencia de mercado inexistente, usar `TBD`, criar
`US-NNN`, promover PRD sem owner ou duplicar fonte inferior.

**Mandatory:** Atualizar os indices imediatos, preservar links resolviveis e
registrar hipoteses/perguntas abertas de forma acionavel.

**Definition of Done:** Taxonomia e lifecycle decididos; indice, template e dois
PRDs presentes; readiness documental atualizado; links locais resolvem.

### TP-00051-T02 — Proteger deterministicamente a colecao

**What:** Fazer o validador rejeitar ausencia, nome, natureza, lifecycle, indice ou
template divergentes do contrato de PRD.

**Where:** `infra/scripts/validate-docs.sh`,
`validate-documentation-governance.test.mjs` e
`infra/scripts/validate-docs.sh`.

**Depends on:** `TP-00051-T01` concluida e auditoria IRG `READY` para esta versao e
estes paths.

**Reuses:** Validadores de colecao, nomes, IDs, templates e repositorio ja
existentes.

**Requirements:** ADR-0000 v4.14 `Accepted`; contrato de
`do../../product/requirements/`; TPL-00012; Implementation Readiness Standard v1.3.

**Gate Audit:** `READY` em 2026-09-09, auditado pela skill
`implementation-readiness`, somente para
`infra/scripts/validate-docs.sh`,
`validate-documentation-governance.test.mjs` e
`infra/scripts/validate-docs.sh`, na versao corrente desta task.

- Product Definition: `not applicable`; a entrega torna verificavel uma regra de
  governanca documental e nao altera problema, publico, valor, comportamento ou
  metrica do produto.
- Fontes superiores: ADR-0000 v4.14 `Accepted`, contrato da colecao e TPL-00012
  estao materializados; Requirement, User Story View e Use Case sao `N/A` pela
  mesma ausencia de comportamento de produto.
- Assumptions: nenhuma; os paths, estados, natureza e contrato a verificar estao
  definidos pelas fontes versionadas.
- Open Questions: nenhuma para esta entrega; T01 esta concluida e nao ha decisao
  de produto ou arquitetura delegada ao validador.
- Dependencias e escopo: T01 concluida; os tres paths autorizados, non-objectives,
  reuso, comandos e resultado esperado estao declarados nesta task.
- Testes: unidade hermetica positiva e negativas para PRD, seguida do teste Node
  completo e do wrapper documental; falha preexistente fora do escopo sera
  preservada e registrada, nunca mascarada.
- DoD: binaria e reproduzivel pelos comandos da Section 6.

**Result:** `READY`; qualquer mudanca nas fontes, paths ou escopo invalida esta
auditoria. PRD-00001 e PRD-00002 continuarem `In Review` nao bloqueia esta entrega
puramente documental, nem autoriza implementacao de suas iniciativas.

**Acceptance Tests:** Teste hermetico positivo para PRD valido e negativos para
nome, natureza e lifecycle; wrapper agregado retorna codigo `0` no estado final.

**Prohibited:** Enfraquecer controles existentes, mascarar divergencia, acessar
rede, instalar dependencias ou executar Git.

**Mandatory:** Atualizar teste relevante antes de concluir; executar o teste Node
focal e `./infra/scripts/validate-docs.sh`.

**Definition of Done:** IRG `READY` registrado antes da edicao; teste novo passa;
wrapper agregado passa; resultado e contagens sao registrados neste plano.

## 5. Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| PRD duplicar requisito ou caso de uso | Template e validador preservam referencias sem copiar ACs ou fluxos. |
| Implementacao tecnica ser confundida com validacao de produto | PRDs iniciais permanecem `In Review` e separam evidencia tecnica de evidencia de resultado. |
| Novo gate invalidar retroativamente todo o legado | A regra entra em vigor na proxima mudanca do escopo legado; novas iniciativas exigem PRD antes de avancar. |
| Codex e Claude divergirem | Skills pareadas recebem a mesma mudanca semantica. |

## 6. Final validation

- `node --test validate-documentation-governance.test.mjs`: `PASS`.
- `./infra/scripts/validate-docs.sh`: `PASS`; 777 Markdown, 31 diretórios e
  758 artefatos indexados; 7 cenários do Quality Gate e 1 plano IP-INFRA também
  passaram; validação estrutural encerrou com código `0`.

## 7. Handoff status

`Completed`: coleção, índice, TPL-00012, dois PRDs `In Review`, Product Definition
Gate, readiness pareado e proteção executável estão materializados e validados.
Os PRDs permanecem deliberadamente `BLOCKED` para progressão de produto até os
owners resolverem hipóteses, métricas, perguntas e aprovações registradas.
