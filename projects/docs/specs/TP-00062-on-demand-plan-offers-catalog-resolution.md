---
document_id: TP-00062
primary_nature: Plano
objective: Implementar e comprovar a resolução on-demand da versão publicada do catálogo de ofertas de plano diretamente no banco de dados na ausência de override explícito por configuração.
scope: Backend — JdbcPlanOfferCatalogReadAdapter e testes associados; docs — REQ-00053, este plano e índice de task plans.
non_objectives: Não altera DDL, contrato OpenAPI, frontend, autenticação, entitlements, fatura, cobrança ou provedores de pagamento. Não autoriza produção, Sandbox ASAAS ou efeitos externos.
owner: Engenharia / Billing
status: In Progress
version: 1.0
date: 2026-09-21
last_reviewed: 2026-09-21
keywords: billing, plan-offers, catalog-version, on-demand, banco de dados, resolução dinâmica, override
related_files: ../../docs/prds/PRD-00001-billing-enterprise.md, do../../product/requirements/REQ-00053-billing-tenant-plan-offer-discovery.md, do../../product/use-cases/UC-00047-billing-tenant-plan-offer-discovery.md, ../../backend/docs/adrs/ADR-0027-catalogo-global-faturamento-local.md, TP-00061-billing-plan-offers-catalog-version-config.md, docs/contracts/billing-v1.openapi.yaml
code_references: backend/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/infrastructure/persistence/JdbcPlanOfferCatalogReadAdapter.java
principal_statement: O adaptador JdbcPlanOfferCatalogReadAdapter resolve on-demand a versão publicada e vigente mais recente do banco de dados quando a configuração de catálogo for omitida ou vazia, mantendo o valor configurado como override opcional.
---

# TP-00062 — Resolução on-demand da versão ativa do catálogo de ofertas

## 1. Overview

Este plano de tarefa implementa a evolução do adaptador `JdbcPlanOfferCatalogReadAdapter` para
resolver dinamicamente a versão ativa do catálogo comercial publicada no banco de dados
(`saas_platform`), eliminando a necessidade de fixação manual rígida de variável de ambiente
ou reinicialização da aplicação após a publicação de novos catálogos pelo painel administrativo.

A propriedade de configuração `billing.plan-offers.catalog-version` permanece suportada como
um *override* opcional e explícito para ambientes que necessitem fixar temporariamente uma versão.

## 2. Implementation Readiness Gate

**Task ID:** `TP-00062-ON-DEMAND-CATALOG-001`

### 2.1 Gate Audit

| Control | Required state | Observed evidence | Result |
|---|---|---|---|
| Product Definition | Applicable PRD `Validated` | `PRD-00001 v1.15` (`Validated`) cobre `REQ-00053` e a descoberta de ofertas | `PASS` |
| Requirements | `Approved` | `REQ-00053 v1.6` (`Approved / Implemented repository-local`) | `PASS` |
| ADRs | `Accepted` | `ADR-0027 v1.14` (`Accepted`) define catálogo global seller-owned em `saas_platform` | `PASS` |
| Use Cases | `Approved` | `UC-00047 v1.3` (`Approved / Implemented repository-local`) | `PASS` |
| Assumptions | All `Validated` or `Rejected` | Nenhuma assumption aberta; comportamento de fallback dinâmico fail-closed validado | `PASS` |
| Open Questions | All `Resolved` | Nenhuma pergunta aberta no escopo da resolução de versão | `PASS` |
| Dependencies | Available and non-conflicting | `saas_platform` schema e tabelas `billing_catalog_offer_versions` disponíveis | `PASS` |
| API Contract | Canonical contract auto-approved | `getPlanOffers` em `docs/contracts/billing-v1.openapi.yaml` v0.5.3 (Draft) inalterado | `PASS` |
| Granularity / Decomposition | One observable delivery and one handoff | Unidade atômica focada exclusivamente no adaptador de leitura do catálogo | `PASS` |

### 2.2 Acceptance Tests

| Acceptance criterion | Planned test/evidence | Owner | Expected result |
|---|---|---|---|
| `AC-018`: override explícito | `JdbcPlanOfferCatalogReadAdapterTest#shouldUseConfiguredVersionWhenPresent` | Billing / Backend | Versão configurada é utilizada diretamente na consulta |
| `AC-019`: resolução dinâmica on-demand | `JdbcPlanOfferCatalogReadAdapterTest#shouldResolveLatestPublishedCatalogVersionWhenUnconfigured` | Billing / Backend | Versão publicada vigente mais recente no banco é resolvida e utilizada |
| `AC-019`: fail-closed sem versão publicada | `JdbcPlanOfferCatalogReadAdapterTest#shouldReturnEmptySnapshotWhenNoPublishedCatalogEffective` | Billing / Backend | Retorna `CatalogSnapshot(null, List.of())` com segurança |

### 2.3 Prohibited

- Não alterar contratos OpenAPI ou schemas de resposta da API `GET /api/v1/tenants/{tenantId}/billing/plan-offers`.
- Não quebrar o comportamento de *override* quando `billing.plan-offers.catalog-version` estiver configurada.
- Não executar mutações no banco de dados (`INSERT`, `UPDATE`, `DELETE`) durante a leitura de ofertas.
- Não consultar versões não publicadas (`DRAFT`) ou retiradas (`RETIRED`) como ativas.
- Não acessar rede externa, Sandbox ASAAS ou ambiente de produção.

### 2.4 Mandatory

- Consultar apenas versões com `version.lifecycle = 'PUBLISHED'` e `version.published_at IS NOT NULL`.
- Validar a janela de vigência com `asOf`: `version.effective_from <= asOf` e (`version.effective_until IS NULL OR version.effective_until > asOf`).
- Garantir que preços públicos estejam publicados e vigentes para as ofertas selecionadas.
- Em caso de ausência de versão publicada vigente, retornar `CatalogSnapshot(null, List.of())` de forma honesta e segura (*fail-closed*).
- Manter o gate documental `./infra/scripts/validate-docs.sh` e testes focais em `PASS`.

### 2.5 Definition of Done

- `JdbcPlanOfferCatalogReadAdapter` implementa `RESOLVE_ACTIVE_CATALOG_VERSION_QUERY` com resolução dinâmica on-demand.
- Testes unitários e/ou de integração comprovam resolução dinâmica, fallback fail-closed e override por configuração.
- `./mvnw -B test` nos testes impactados passa com zero falhas e zero skips.
- `./infra/scripts/validate-docs.sh` passa com resultado `PASS`.
- Commit Conventional Commits na branch governada `62.0.0-feat-on-demand-plan-offers-catalog-resolution`.

## 3. Execution Tracking Matrix

| Task | Status | Evidência |
| --- | --- | --- |
| TP-00062-ON-DEMAND-CATALOG-001: implementar resolução on-demand no adapter | Completed | `JdbcPlanOfferCatalogReadAdapter.java` |
| Cobertura de teste da resolução on-demand | Completed | `JdbcPlanOfferCatalogReadAdapterTest.java` |
| Testes focais Maven | Completed | `BillingControllerTest`, `ListTenantPlanOffersUseCaseTest`, `JdbcPlanOfferCatalogReadAdapterTest` |
| Validação documental | Completed | `./infra/scripts/validate-docs.sh` PASS |
| Commit e entrega Git | Completed | Branch `62.0.0-feat-on-demand-plan-offers-catalog-resolution` |

## 4. Evidence

### 4.1 Código de resolução dinâmica

O método `resolveCatalogVersion(Timestamp effectiveAt)` seleciona dinamicamente a versão mais recente
efetiva quando `configuredCatalogVersion` for vazia.

### 4.2 Testes executados

Comando: `./mvnw -B -Dtest="JdbcPlanOfferCatalogReadAdapterTest,JdbcPlanOfferCatalogReadAdapterWiringTest,ListTenantPlanOffersUseCaseTest,BillingControllerTest" test`

### 4.3 Validação documental

Comando: `./infra/scripts/validate-docs.sh`

## 5. Change Log

| Versão | Data | Autor | Mudança |
| --- | --- | --- | --- |
| 1.0 | 2026-09-21 | Antigravity (IA) | Criação do plano e especificação da resolução on-demand do catálogo de ofertas. |

