---
document_id: TP-00057
primary_nature: Plano
objective: Remover do frontend os cinco consumidores sem controller remanescentes em Omnichannel e Tenant e reconciliar contratos e documentos oficiais, sem alterar o backend.
scope: Painel genérico de webhooks do chatbot, busca administrativa de tenants, contratos Omnichannel/Tenant e inventários direcionais relacionados.
non_objectives: Alterar backend; remover callbacks reais de Telegram, WhatsApp ou Stripe; remover configurações dos provedores; criar endpoints substitutos.
owner: Frontend, Arquitetura, Produto Omnichannel e Tenant
status: Completed
version: 1.1
date: 2026-09-11
last_reviewed: 2026-09-11
keywords: omnichannel, tenant, webhook, frontend, expurgo, consumer-only, openapi
related_files: docs/analysis/ANL-00055-backend-api-contract-coverage-inventory.md, docs/analysis/ANL-00056-api-contract-validation-loop.md, docs/analysis/ANL-00057-frontend-backend-api-contract-catalog.md, docs/contracts/omnichannel-v1.openapi.yaml, docs/contracts/tenant-v1.openapi.yaml, TP-00052-backend-api-contract-baseline.md, ../../frontend/docs/specs/IP-FE-3.8.1-omnichannel-inbox-and-settings.md, do../../product/use-cases/UC-00001-dashboard-view.md
code_references: frontend/src/components/inbox/, frontend/src/services/chatbotService.ts, frontend/src/hooks/queries/useChatbotQueries.ts, frontend/src/services/dashboardService.ts, frontend/src/hooks/queries/useDashboardQueries.ts, frontend/src/mocks/, frontend/src/types/
principal_statement: O expurgo elimina quatro operações de administração genérica de webhooks de saída e uma busca de tenants sem consumidor de tela, preservando os callbacks reais e as configurações Telegram/WhatsApp.
---

# TP-00057 — Expurgo dos consumidores órfãos Omnichannel/Tenant

## 1. Overview

O solicitante decidiu em 2026-09-11 remover os cinco consumidores frontend que não
possuem controller correspondente. A inspeção confirmou que o painel genérico de
webhooks modela destinos de saída (`callbackUrl`, `secret`, eventos e `ping`) e não
é porta de entrada dos provedores. Ele também não está montado em página de
produção. A busca `GET /api/v1/admin/tenants?search=...` não possui consumidor de
tela; existem somente service, hook, mock e teste isolados.

Permanecem fora do expurgo:

- `POST /api/v1/telegram/webhook/{tenantId}/{botConfigId}`;
- `GET` e `POST /api/v1/whatsapp/webhook`;
- `/api/v1/tenant/telegram/configs` e `/api/v1/tenant/whatsapp/configs`;
- qualquer controller ou código sob `backend/`.

## 2. Implementation Readiness Gate

### 2.1 Gate Audit

| Control | Observed evidence | Result |
| --- | --- | --- |
| Product Definition | `N/A` técnico: remoção de código não montado e sem capacidade backend; a decisão explícita do solicitante resolve manter versus remover. | N/A |
| Requirements / Use Cases | Documentos que ainda citam as superfícies órfãs serão reconciliados para não instruir sua recriação; nenhuma jornada suportada será removida. | PASS |
| ADRs | ADR-0000 exige plano transversal, readiness e reconciliação documental. | PASS |
| Adherence analysis | ANL-00057 prova quatro chamadas Omnichannel e uma Tenant sem controller; busca de uso prova ausência de montagem/consumidor de tela. | PASS |
| Assumptions | A natureza dos webhooks foi verificada pelos modelos, rotas e fluxos reais de registro/callback; não há hipótese proposta. | PASS |
| Open Questions | A dúvida sobre callbacks externos foi resolvida: as cinco operações não são callbacks de Telegram/WhatsApp. | PASS |
| Dependencies | Fontes e testes estão locais; nenhum backend precisa ser alterado. | PASS |
| API Contract | `N/A`: as cinco operações a retirar são Draft `consumer-only-backend-unimplemented`; callbacks/configurações reais permanecem contratados. | N/A |
| Granularity / Decomposition | T01, T02 e T03 separam resultados independentes de Omnichannel, Tenant e documentação. | PASS |

### 2.2 Readiness por unidade

| Task | What | Where | Result |
| --- | --- | --- | --- |
| `TP-00057-T01` | Remover painel, clientes, hooks, tipos, mocks e testes do webhook genérico de saída. | `frontend/src` Omnichannel | READY |
| `TP-00057-T02` | Remover service, hook, tipo, mock e teste exclusivos da busca administrativa órfã. | `frontend/src` Dashboard/Tenant | READY |
| `TP-00057-T03` | Retirar as cinco projeções dos OpenAPIs e reconciliar documentos oficiais e índices. | `docs/contracts`, análises, planos, caso de uso e índices imediatos | READY |

### 2.3 Acceptance Tests

| Acceptance criterion | Evidence | Expected result |
| --- | --- | --- |
| `AC-057-001` | Busca pelos cinco pares método/path e símbolos exclusivos. | Zero consumidor produtivo, mock ou teste órfão. |
| `AC-057-002` | Busca dirigida pelos callbacks e configurações reais. | Telegram/WhatsApp preservados. |
| `AC-057-003` | Testes focais Omnichannel/Dashboard, typecheck e lint. | Zero falha causada pelo recorte. |
| `AC-057-004` | Parse OpenAPI e sentinel de cobertura direcional. | 228/228 operações backend cobertas; zero consumer-only; 203 Draft. |
| `AC-057-005` | `./infra/scripts/validate-docs.sh`. | Governança documental sem erro causado pelo recorte. |

### 2.4 Prohibited

- Alterar qualquer arquivo em `backend/`.
- Remover ou mudar callbacks reais de Telegram, WhatsApp ou Stripe.
- Remover ou mudar as APIs de configuração Telegram/WhatsApp.
- Criar redirects silenciosos ou endpoints substitutos.
- Tratar mock, teste ou tipo frontend como evidência de API disponível.

### 2.5 Mandatory

- Remover todas as dependências exclusivas das cinco chamadas órfãs.
- Reconciliar contratos e documentos oficiais para impedir recriação por agentes.
- Manter explícita a classificação de callbacks externos no catálogo direcional.
- Executar a skill `quality-gate` com o mesmo escopo `READY`.

### 2.6 Result

| Field | Value |
| --- | --- |
| **Readiness Result** | `READY` para `TP-00057-T01`–`T03` |
| **Auditor** | `@AgentOrchestrator using implementation-readiness` |
| **Source Versions** | `ANL-00057 v1.2`; Omnichannel Draft `0.9.0`; Tenant Draft `0.10.0` |
| **Scope Authorized** | Paths declarados em T01–T03; nenhum path backend |
| **Decomposition** | Parent `TP-00057` → T01 Omnichannel, T02 Tenant, T03 contratos/documentos |
| **Blockers / Decision Owner** | N/A |

## 3. Execution tracking

| Task | Status | Evidence |
| --- | --- | --- |
| `TP-00057-T01` | Completed | Componentes, service, hooks, tipos, mocks, traduções e testes exclusivos da gestão genérica de webhooks foram removidos; busca dirigida zerou os símbolos. |
| `TP-00057-T02` | Completed | Service/hook/tipo/mock/teste duplicados da busca administrativa foram removidos; `TenantSelector` segue consumindo `listTenants` real. |
| `TP-00057-T03` | Completed | Omnichannel 0.10.0 e Tenant 0.11.0 possuem somente operações backend; inventários e documentos oficiais foram reconciliados. |

## 4. Assurance

| Gate / comando | Resultado | Evidência |
| --- | --- | --- |
| Busca de consumers/símbolos órfãos | PASS | Zero ocorrência em código, mocks e testes frontend dos símbolos e da query removidos. |
| Preservação de provedores | PASS | Callbacks Telegram/WhatsApp e oito operações de configuração continuam em frontend, backend e Omnichannel OpenAPI. |
| Vitest focal impactado | PASS | 32/32 testes em três arquivos; quality gate focused adicional 11/11. |
| Typecheck, ESLint e Prettier focal | PASS | Zero erro; os quatro arquivos inicialmente divergentes foram formatados e o check foi repetido com sucesso. |
| Suíte frontend agregada | FAIL externo ao recorte | 1.314/1.317 testes passaram; três falhas RBAC preexistentes em `auth-return-to.test.ts` e `menu-utils.test.ts`, sem falha nos arquivos alterados. |
| Build frontend | BLOCKED por política | `frontend/.env.local` existe; conteúdo não foi lido e o build não foi executado. |
| Sentinel de contratos | PASS | 51 controllers, 228/228 operações cobertas, 17 contratos, 228 operações contratadas, zero planned e 203 Draft. |
| `./infra/scripts/validate-docs.sh` | PASS | Governança, contratos, quality scaffold, métricas, granularidade, políticas, referências e estrutura documental verdes. |
| Backend | N/A | Nenhum arquivo em `backend/` foi alterado. |

O resultado é `Completed — repository-local`: o objetivo e os gates focais estão
verdes. As falhas agregadas externas e o build bloqueado não foram mascarados nem
corrigidos fora do escopo.

## 5. Change log

| Version | Date | Change |
| --- | --- | --- |
| 1.1 | 2026-09-11 | Conclui T01–T03, publica Omnichannel 0.10.0/Tenant 0.11.0, zera consumer-only, preserva provedores reais e registra gates focais verdes e baseline agregado externo. |
| 1.0 | 2026-09-11 | Materializa a decisão de expurgo, preserva callbacks/configurações reais, decompõe o trabalho e registra IRG READY antes da edição executável. |
