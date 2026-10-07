---
document_id: TP-00056
primary_nature: Plano
objective: Remover do frontend os consumidores fiscais sem controller backend e reconciliar o catálogo OpenAPI, preservando os downloads PDF efetivamente implementados.
scope: Frontend fiscal de DARF, monitor de lotes e repositório genérico de documentos; contrato Fiscal e inventários direcionais relacionados.
non_objectives: Alterar backend, remover emissão/histórico/download de DAS, remover relatório fiscal PDF, criar endpoints substitutos ou mudar integrações SERPRO.
owner: Frontend, Arquitetura e Produto Fiscal
status: Completed
version: 1.1
date: 2026-09-11
last_reviewed: 2026-09-11
keywords: fiscal, darf, batch, documentos, frontend, expurgo, consumer-only, openapi
related_files: do../../product/requirements/REQ-00033-phase2-fiscal-serpro-operations.md, do../../product/use-cases/UC-00030-phase2-fiscal-operations.md, docs/analysis/ANL-00055-backend-api-contract-coverage-inventory.md, docs/analysis/ANL-00056-api-contract-validation-loop.md, docs/analysis/ANL-00057-frontend-backend-api-contract-catalog.md, docs/contracts/fiscal-v1.openapi.yaml, TP-00002-frontend-nextjs-task-plan.md, TP-00052-backend-api-contract-baseline.md, ../../frontend/docs/specs/IP-FE-3.3.1-fiscal-wireframes.md, do../../agents/standards/implementation-readiness-standard.md
code_references: frontend/src/app/(dashboard)/fiscal/, frontend/src/components/fiscal/, frontend/src/services/fiscalService.ts, frontend/src/hooks/queries/useFiscalQueries.ts, frontend/src/mocks/, frontend/e2e/fiscal/, docs/contracts/fiscal-v1.openapi.yaml
principal_statement: O expurgo elimina somente cinco chamadas frontend sem implementação backend e mantém intactos GET /api/v1/fiscal/consulta/{consultaId}/pdf e GET /api/v1/fiscal/das/{dasId}/download.
---

# TP-00056 — Expurgo de consumidores fiscais sem backend

## 1. Overview

O solicitante determinou em 2026-09-11 o expurgo das telas e chamadas de DARF e
processamento em lote. A análise adicional comprovou que o repositório genérico de
documentos também é mock-only: a listagem `GET /api/v1/fiscal/documents` e os links
`/api/v1/fiscal/documents/{id}/download` não possuem controller backend.

O recorte preserva as duas entregas PDF reais e já consumidas pelo frontend:

- `GET /api/v1/fiscal/consulta/{consultaId}/pdf`, implementado por `FiscalController`;
- `GET /api/v1/fiscal/das/{dasId}/download`, implementado por `DasController`.

Nenhum arquivo sob `backend/` faz parte do escopo.

## 2. Implementation Readiness Gate

### 2.1 Gate Audit

| Control | Required state | Observed evidence | Result |
| --- | --- | --- | --- |
| Product Definition | PRD `Validated` ou `N/A` técnico justificado | `N/A`: correção de paridade remove superfícies sem API e sem capacidade backend suportada; a decisão explícita do solicitante não cria produto novo. | N/A |
| Requirements | Fonte aprovada | [REQ-00033 v1.1](../../product/requirements/REQ-00033-phase2-fiscal-serpro-operations.md) mantém DARF/2.3.3 bloqueado e reconhece somente capacidades backend observadas. | PASS |
| ADRs | Decisões aceitas aplicáveis | [ADR-0000](../../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md) exige plano transversal e readiness antes da escrita. | PASS |
| Use Cases | Aprovado ou `N/A` | [UC-00030 v1.1](../../product/use-cases/UC-00030-phase2-fiscal-operations.md) classifica DARF como BLOCK e confirma PDF fiscal/DAS implementados. | PASS |
| Adherence analysis | Evidência atual | [ANL-00057 v1.0](../../analysis/ANL-00057-frontend-backend-api-contract-catalog.md) prova cinco consumidores Fiscal sem controller. | PASS |
| Assumptions | Nenhuma proposta | A existência/ausência foi verificada em controllers, services, hooks, routes e mocks; não há assumption. | PASS |
| Open Questions | Nenhuma aberta | A dúvida sobre documentos foi resolvida: repositório e download genéricos são mock-only; PDFs fiscal e DAS são rotas independentes e reais. | PASS |
| Dependencies | Disponíveis e sem conflito | Código e documentos estão locais; mudanças concorrentes identificadas estão fora dos paths produtivos fiscais. | PASS |
| API Contract | Active ou `N/A` objetivo | `N/A`: as cinco operações a retirar estão Draft e marcadas `consumer-only-backend-unimplemented`; não são APIs backend. As operações PDF reais não serão alteradas. | N/A |
| Granularity / Decomposition | Um resultado por task | `TP-00056-T01` a `T04` separam DARF, lotes, documentos e reconciliação documental. | PASS |

### 2.2 Readiness por unidade

| Task | What | Where | Result |
| --- | --- | --- | --- |
| `TP-00056-T01` | Remover toda a superfície frontend de DARF sem backend. | rota DARF, CTA de débito, componente, service/hook/types/mocks e E2E associados | READY |
| `TP-00056-T02` | Remover toda a superfície frontend de processamento em lote sem backend. | rota batch, componente, service/hook/types e mocks associados | READY |
| `TP-00056-T03` | Remover o repositório genérico mock-only sem atingir PDFs reais. | rota documents, gallery/filtros, service/hook/types e mocks associados | READY |
| `TP-00056-T04` | Reconciliar contratos e inventários após T01–T03. | contrato Fiscal, `ANL-00055-backend-api-contract-coverage-inventory`, `ANL-00056-api-contract-validation-loop`, `ANL-00057-frontend-backend-api-contract-catalog`, `TP-00052-backend-api-contract-baseline` e índices imediatos | READY |

### 2.3 Acceptance Tests

| Acceptance criterion | Planned test/evidence | Expected result |
| --- | --- | --- |
| `AC-056-001` | Busca dirigida por cinco methods/paths e símbolos removidos em `frontend/`. | Zero consumidores produtivos e mocks órfãos. |
| `AC-056-002` | Teste focal do `DebitoTable`. | Tabela continua renderizando débitos sem CTA DARF. |
| `AC-056-003` | Testes fiscais impactados, typecheck e lint frontend. | Zero falhas novas. |
| `AC-056-004` | Busca e testes existentes de download DAS/relatório. | Consumidores e endpoints reais preservados. |
| `AC-056-005` | Parse OpenAPI e sentinel de cobertura direcional. | 228 controllers cobertos; cinco consumer-only remanescentes fora de Fiscal. |
| `AC-056-006` | `./infra/scripts/validate-docs.sh`. | Governança documental focal/agregada sem erro causado pelo recorte. |

### 2.4 Prohibited

- Alterar qualquer arquivo em `backend/`.
- Remover ou mudar `/api/v1/fiscal/consulta/{consultaId}/pdf`.
- Remover ou mudar `/api/v1/fiscal/das`, seu histórico ou `/{dasId}/download`.
- Criar redirects silenciosos ou endpoints substitutos.
- Alterar consumers fiscais, Billing ou Omnichannel fora dos símbolos enumerados.

### 2.5 Mandatory

- Remover rotas, consumers, tipos, mocks, fixtures, traduções e testes que existam
  exclusivamente para DARF, batch e repositório genérico.
- Manter a consulta fiscal, o detalhamento de débitos, DAS Cobrança e ambos os
  downloads PDF reais.
- Atualizar contrato e inventários apenas depois da remoção dos consumidores.
- Executar a skill `quality-gate` com o mesmo escopo READY.

### 2.6 Result

| Field | Value |
| --- | --- |
| **Readiness Result** | `READY` para `TP-00056-T01`–`T04` |
| **Auditor** | `@AgentOrchestrator using implementation-readiness` |
| **Source Versions** | `REQ-00033 v1.1`; `UC-00030 v1.1`; `ANL-00057 v1.0`; Fiscal Draft `0.5.0` |
| **Scope Authorized** | Paths declarados em T01–T04; nenhum path backend |
| **Decomposition** | Parent `TP-00056` → `T01` DARF, `T02` batch, `T03` documents, `T04` docs/contracts |
| **Blockers / Decision Owner** | N/A |

## 3. Atomic execution contracts

### TP-00056-T01 — DARF frontend

| Field | Contract |
| --- | --- |
| **What** | Nenhuma tela, CTA ou chamada REST frontend permite emitir ou listar DARF. |
| **Where** | `frontend/src/app/(dashboard)/fiscal/darf/`, `DebitoTable.tsx`, `DarfCard.tsx`, `paths.ts`, `protected-routes.ts`, `fiscalService.ts`, `useFiscalQueries.ts`, `types/fiscal.ts`, mocks fiscais e E2E fiscal. |
| **Depends on** | Gate READY deste plano. |
| **Reuses** | Consulta fiscal e tabela de débitos existentes, sem coluna de ação DARF. |
| **Requirements** | `REQ-00033`, `UC-00030`, frontend/Next.js/testing standards. |
| **Definition of Done** | Símbolos e URLs DARF removidos; consulta fiscal continua tipada e testada. |

### TP-00056-T02 — Batch frontend

| Field | Contract |
| --- | --- |
| **What** | A rota e todas as dependências exclusivas do monitor/cancelamento de lotes deixam de existir. |
| **Where** | rota `fiscal/batch`, `BatchMonitor.tsx`, `fiscalAdvanced.ts`, service/hook e mocks advanced. |
| **Depends on** | Gate READY deste plano. |
| **Reuses** | N/A; a capability não possui backend. |
| **Requirements** | Decisão explícita do solicitante e `ANL-00057`. |
| **Definition of Done** | URLs `/fiscal/batch` e `/api/v1/fiscal/batch*` ausentes do frontend. |

### TP-00056-T03 — Repositório genérico frontend

| Field | Contract |
| --- | --- |
| **What** | A rota e dependências do repositório mock-only deixam de existir, preservando downloads reais. |
| **Where** | rota `fiscal/documents`, `DocumentGallery.tsx`, `DocumentFilters.tsx`, `fiscalAdvanced.ts`, service/hook e mocks advanced. |
| **Depends on** | Evidência de separação entre `/documents*`, `/consulta/{id}/pdf` e `/das/{id}/download`. |
| **Reuses** | `fiscalService.downloadConectaPdf` e `fiscalService.downloadDas` permanecem intactos. |
| **Requirements** | `REQ-00010`, `REQ-00022` somente como fronteira de preservação; `ANL-00057`. |
| **Definition of Done** | `/documents*` ausente; testes de download reais continuam verdes. |

### TP-00056-T04 — Reconciliação documental

| Field | Contract |
| --- | --- |
| **What** | O catálogo deixa de registrar as cinco chamadas Fiscal retiradas e mantém as 228 operações backend. |
| **Where** | `docs/contracts/fiscal-v1.openapi.yaml`, `docs/contracts/README.md`, `ANL-00055`, `ANL-00056`, `ANL-00057`, `TP-00052` e índices imediatos. |
| **Depends on** | T01–T03 concluídas e busca de consumidores zerada. |
| **Reuses** | Scripts existentes de parse, cobertura e governança documental. |
| **Requirements** | API Contract Standard, ADR-0000 e governança documental. |
| **Definition of Done** | Fiscal volta a 16 operações; catálogo global a 233; consumer-only global a cinco; validadores verdes ou blocker externo discriminado. |

## 4. Execution tracking

| Task | Status | Evidence |
| --- | --- | --- |
| `TP-00056-T01` | Completed | Busca dirigida não encontra rota, CTA, service, hook, tipo ou mock DARF no frontend; `DebitoTable.test.tsx` passa sem CTA. |
| `TP-00056-T02` | Completed | Busca dirigida não encontra `/fiscal/batch`, subpaths, monitor, cancelamento ou mocks no frontend. |
| `TP-00056-T03` | Completed | Repositório genérico não existe no frontend; downloads reais `downloadConectaPdf` e `downloadDas` permanecem ligados aos controllers. |
| `TP-00056-T04` | Completed | Fiscal OpenAPI 0.6.0 possui 16 operações implementadas e zero consumer-only; inventários e documentos oficiais foram reconciliados. |

## 5. Assurance

| Gate / comando | Resultado | Evidência |
| --- | --- | --- |
| Busca consumer-only em `frontend/src` e `frontend/e2e` | PASS | Zero ocorrência dos paths e símbolos expurgados. |
| JSON pt-BR + parse do Fiscal OpenAPI | PASS | Catálogos JSON válidos; OpenAPI `0.6.0` válido com 15 paths e 16 operações. |
| `node --test validate-api-contract-coverage.test.mjs` | PASS | 1/1 teste. |
| `node validate-api-contract-coverage.mjs --root .` | PASS | 228/228 operações backend cobertas; 233 contratos; 208 Draft; cinco consumer-only fora de Fiscal. |
| Vitest fiscal focal | PASS | `DebitoTable`, `DasCobrancaPage` e `fiscalService`: 9/9 testes. |
| Quality Gate frontend focused | PASS | `QUALITY_GATE_RESULT=PASS`; `DebitoTable.test.tsx` 1/1. |
| `npm run typecheck` | PASS | Zero erro TypeScript. |
| ESLint dos arquivos fiscais selecionados | PASS com baseline | Zero erro e três warnings preexistentes em `fiscal/page.tsx`, arquivo sem diff neste lote. |
| `npm test` agregado | FAIL externo ao Fiscal | 1.316/1.322 testes passaram; três falhas RBAC e três timeouts em Certificados/Billing, sem falha fiscal. |
| Build frontend | BLOCKED por política | `.env.local` existe; conteúdo não foi lido e o build não foi executado. |
| `./infra/scripts/validate-docs.sh` | PASS | Governança, cobertura API, quality scaffold, métricas, granularidade, políticas e estrutura documental verdes. |
| Backend | N/A | `git diff --name-only -- backend` vazio; nenhum controller ou código backend alterado. |

O resultado final é `Completed — repository-local`: o objetivo fiscal e o gate
focal estão verdes. As falhas agregadas externas não foram mascaradas nem
corrigidas fora do escopo.

## 6. Change log

| Version | Date | Change |
| --- | --- | --- |
| 1.1 | 2026-09-11 | Conclui T01–T04, publica Fiscal OpenAPI 0.6.0 com 16 operações implementadas, supersede o wireframe legado, preserva PDFs reais e registra gates focais/documentais verdes e baseline agregado externo. |
| 1.0 | 2026-09-11 | Materializa decisão de expurgo, análise dos PDFs, decomposição semântica e IRG READY antes de qualquer edição executável. |
