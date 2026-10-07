---
document_id: TP-00053
primary_nature: Plano
objective: Expandir a cobertura de produto por features rastreáveis para Tenant, Fiscal e Identidade/Acesso sem duplicar critérios funcionais.
scope: Inventário seletivo de funcionalidades, três novos PRDs, matrizes de feature e cobertura de acceptance criteria nos cinco PRDs, template, índices e validação documental.
non_objectives: Copiar Given/When/Then para PRDs, alterar requisitos ou casos de uso, validar hipóteses em nome dos owners, decidir arquitetura, escrever produto executável ou acessar ambientes.
owner: Produto, Arquitetura e Documentação
status: Completed
date: 2026-09-10
version: 1.1
last_reviewed: 2026-09-10
keywords: prd, features, tenant, fiscal, acesso, acceptance-criteria, rastreabilidade
related_files: do../../product/requirements/README.md, harne../../../harness/templates/TPL-00001-prd.md, do../../product/requirements/README.md, do../../product/business/product-vision.md
code_references: infra/scripts/validate-docs.sh, validate-documentation-governance.test.mjs
principal_statement: Cada feature de produto deve apontar para requisitos e IDs ou seções de aceite canônicos, mantendo o PRD como visão de resultado e o requisito como autoridade funcional.
---

# TP-00053 — Cobertura de features e critérios nos PRDs

## 1. Objective and outcome

Produzir uma visão de produto navegável e completa o suficiente para descobrir as
features de Tenant, Fiscal e Identidade/Acesso e verificar sua cobertura funcional
sem transferir comportamento normativo dos requisitos para os PRDs.

O resultado esperado é uma cadeia explícita `PRD -> feature -> REQ -> AC/section`,
com lifecycle observado e lacunas visíveis. Billing e Omnichannel recebem a mesma
estrutura para evitar dois contratos de PRD.

## 2. Sources and constraints

- Solicitação humana de 2026-09-10 para maximizar a descoberta de funcionalidades
  nos contextos Tenant, Fiscal e Acesso.
- [Visão do produto](../../product/business/product-vision.md), perfis, proposta de valor e
  princípios de negócio.
- [Índice de requisitos](../../product/requirements/README.md) e requisitos selecionados por
  título, módulo, ator, regra ou relação explícita.
- [Índice de PRDs](../../product/requirements/README.md) e
  [TPL-00001](../../../harness/templates/TPL-00001-prd.md).
- ADR-0000: PRD agrega requisitos, mas não copia acceptance criteria, fluxos ou
  arquitetura e não progride sem `Validated` humano.

## 3. Decisions for this change

1. Feature recebe ID local estável `F-<contexto>-NNN`, resultado/audiência,
   requisito, referência de aceite e estado documental.
2. A referência de aceite usa IDs publicados e link para a seção canônica; texto
   Given/When/Then não é reproduzido.
3. Requisito sem IDs individuais é marcado `section-level; IDs ausentes`, tornando
   a lacuna auditável sem inventar identificadores.
4. Requisito transversal pode aparecer em mais de um PRD quando a contribuição for
   distinta; a linha explicita o recorte e não cria ownership técnico novo.
5. Os novos PRDs nascem `In Review` e `BLOCKED`, porque inventário funcional não é
   evidência de problema, adoção, métrica ou aprovação de produto.

## 4. Tasks

### TP-00053-T01 — Materializar features e cobertura documental

**What:** Atualizar o contrato de PRD, enriquecer Billing/Omnichannel e criar os
PRDs Tenant, Fiscal e Identidade/Acesso com mapas rastreáveis.

**Where:** `do../../product/requirements/`, `docs/adrs/`,
`harne../../../harness/templates/TPL-00001-prd.md`, `harne../../../harness/templates/README.md`,
`do../../product/business/product-vision.md`, `do../../product/business/README.md` e seus índices
imediatos aplicáveis.

**Depends on:** Solicitação humana; ADR-0000 v4.14; fontes da Section 2.

**Reuses:** Estrutura dos PRD-00001/00002, lifecycle da coleção, títulos, estados e
IDs de aceite publicados nos requisitos.

**Requirements:** ADR-0000; PRD-00001/00002; REQ-00001–REQ-00061 somente quando
selecionados por contribuição explícita; TPL-00012.

**Gate Audit:** Trabalho exclusivamente documental para definir e rastrear produto;
Implementation Readiness de código não se aplica a esta task.

**Acceptance Tests:** Existem cinco PRDs indexados; cada um possui features com ID,
valor, REQ, cobertura de aceite e estado; nenhum reproduz Given/When/Then, fluxo de
UC ou decisão arquitetural; novos PRDs permanecem `In Review/BLOCKED`.

**Prohibited:** Inventar feature sem requisito/fonte, inventar AC, baseline, target,
evidência ou aprovação; alterar comportamento funcional; usar `TBD`.

**Mandatory:** Linkar cada artefato novo no índice imediato, registrar lacuna de ID
de aceite e preservar o owner humano do Product Definition Gate.

**Definition of Done:** Template e índice atualizados; PRD-00001–PRD-00005 possuem
matriz de features e cobertura; links locais resolvem; estados refletem as fontes.

**Result:** `PASS` — cinco PRDs indexados com 76 features únicas e cobertura até
REQ/aceite/estado; três novos PRDs permanecem `In Review/BLOCKED`.

### TP-00053-T02 — Proteger o contrato de feature e aceite

**What:** Fazer o validador rejeitar PRD sem matriz de features, referência de REQ
ou referência de acceptance criteria/seção canônica.

**Where:** `infra/scripts/validate-docs.sh`,
`validate-documentation-governance.test.mjs` e o índice documental
obrigatório `README.md`.

**Depends on:** TP-00053-T01 concluída e IRG `READY` registrado nesta task para os
dois paths exatos.

**Reuses:** `validateProductRequirementsGovernance` e fixtures herméticas atuais.

**Requirements:** ADR-0000 v4.14, índice de PRDs atualizado e TPL-00012 atualizado.

**Gate Audit:** `READY` — auditoria `implementation-readiness` executada e repetida
em 2026-09-10 pelo AgentOrchestrator após incluir o índice imediato obrigatório.
O escopo executável limita-se aos dois scripts de **Where**. Product
Definition: `not applicable`, pois a task protege governança documental e não cria
nem altera comportamento de produto. Fontes: ADR-0000 v4.15 `Accepted`, índice de
PRDs v1.1 e TPL-00012 v1.1; Use Case, Requirement, User Story View e OpenAPI:
`not applicable` pela mesma justificativa. T01 está materializada; nenhuma
assumption, Open Question, conflito ou dependência da task está pendente.
Granularidade: uma entrega observável e um handoff — validador e seu teste são
inseparáveis; não requer decomposição.

**Acceptance Tests:** Fixture válida passa; ausência de feature ID, REQ ou
referência de aceite falha; suíte Node e wrapper agregado retornam código `0`.

**Prohibited:** Aceitar texto duplicado como fonte, inferir AC, mascarar falha
existente, enfraquecer lifecycle ou acessar rede.

**Mandatory:** Atualizar teste focal e executar
`node --test validate-documentation-governance.test.mjs` e
`./infra/scripts/validate-docs.sh`.

**Definition of Done:** IRG `READY` antecede edição; regressões passam; wrapper
final passa e as contagens são registradas.

**Result:** `PASS` — fixture válida e quatro regressões negativas cobrem feature
ausente, REQ ausente, aceite ausente e duplicação Given/When/Then.

## 5. Final validation

- `node --test validate-documentation-governance.test.mjs`
- `./infra/scripts/validate-docs.sh`

Resultados em 2026-09-10:

- teste Node: `1/1 PASS`;
- governança documental: `782 Markdown`, `31 directories`, `776 indexed artifacts`;
- cobertura HTTP concorrente: `226/226 implemented covered`, `2 planned`, `PASS`;
- testes do contrato Quality Gate: `7 scenarios PASS`;
- governança IP-INFRA e validação estrutural agregada: `PASS`.

## 6. Handoff status

`Completed`: T01 e T02 concluídas no escopo autorizado. O wrapper agregado retornou
código `0`; nenhum PRD foi promovido a `Validated` e nenhuma decisão funcional,
arquitetural ou ambiental foi inferida.
