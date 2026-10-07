---
document_id: TP-00061
primary_nature: Plano
objective: Corrigir a ausência de billing.plan-offers.catalog-version no application.yml base, que impede o endpoint getPlanOffers de retornar ofertas publicadas em qualquer ambiente não-dev.
scope: Backend — application.yml base; docs — este plano e índice de task plans.
non_objectives: Não altera lógica de negócio, DDL, contrato OpenAPI, frontend, autenticação, entitlements, fatura, cobrança ou qualquer outro comportamento. Não autoriza produção, Sandbox ASAAS ou efeitos externos.
owner: Engenharia / Billing
status: In Progress
version: 1.0
date: 2026-09-20
last_reviewed: 2026-09-20
keywords: billing, plan-offers, catalog-version, configuração, application.yml, fix
related_files: ../../backend/docs/adrs/ADR-0027-catalogo-global-faturamento-local.md, TP-00032-billing-plans-tenant-offer-read-cutover.md, docs/contracts/billing-v1.openapi.yaml
code_references: backend/src/main/resources/application.yml, backend/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/infrastructure/persistence/JdbcPlanOfferCatalogReadAdapter.java
principal_statement: A propriedade billing.plan-offers.catalog-version deve existir no application.yml base com default vazio e ser injetada via env var BILLING_PLAN_OFFERS_CATALOG_VERSION, alinhando todos os perfis ao comportamento já correto do perfil dev.
---

# TP-00061 — Billing plan-offers catalog-version config fix

## 1. Contexto e causa raiz

O `JdbcPlanOfferCatalogReadAdapter` retorna imediatamente `CatalogSnapshot(null, List.of())` quando
`configuredCatalogVersion` é vazia (linha 123–125 do adapter). A propriedade de binding é
`${BILLING_PLAN_OFFERS_CATALOG_VERSION:}` — declarada **apenas no `application-dev.yml`**.

Em qualquer ambiente que não ative o profile `dev`, a propriedade `billing.plan-offers.catalog-version`
não existe no `application.yml` base, resultando em string vazia → adaptador retorna lista vazia →
frontend exibe "Nenhuma oferta disponível" mesmo com ofertas publicadas no catálogo.

O profile `dev` usa:
```yaml
billing:
  plan-offers:
    catalog-version: ${BILLING_PLAN_OFFERS_CATALOG_VERSION:baseline-draft-2026-09-05}
```

O `application.yml` base possui `billing.invoice.catalog-version` mas **não** `billing.plan-offers.catalog-version`.

## 2. Implementation Readiness Gate

**Task ID:** `TP-00061-CONFIG-FIX-001`

**PRD aplicável:** PRD not applicable — esta é uma correção de configuração de runtime sem feature nova
ou decisão de produto. O comportamento esperado já está definido pelo ADR-0027 (D-04.1) e pelo
`JdbcPlanOfferCatalogReadAdapter` existente.

**Requisito:** REQ-00053 (billing-tenant-plan-offer-discovery) — comportamento de descoberta de ofertas
já aprovado e implementado; esta correção apenas garante que a configuração do ambiente permita que o
código já existente funcione corretamente fora do profile `dev`.

**API Contract:** `operationId: getPlanOffers`, `billing-v1.openapi.yaml` v0.5.3, status `Draft`.
Esta correção não altera o contrato, o schema ou o comportamento do endpoint — apenas remove o gate
de configuração que retornava lista vazia. API Contract: sem nova operação, sem alteração de schema;
o draft existente permanece inalterado.

**ADRs aplicáveis:**
- ADR-0027 v1.14 — catálogo global em `saas_platform`; a configuração do `catalog-version` é o ponteiro
  para a versão ativa do catálogo publicado.
- ADR-0051 — rollout seguro; a env var permanece como ponto de controle explícito por ambiente.

**Assumptions:** Nenhuma assumption pendente. O valor padrão vazio (`${BILLING_PLAN_OFFERS_CATALOG_VERSION:}`)
é fail-safe — sem a env var, o adapter retorna lista vazia (comportamento atual), sem lançar exceção.
Cada ambiente injeta o valor correto da `catalog-version` via env var.

**Open Questions:** Nenhuma.

**Gate Audit:** `READY`

- [x] PRD: not applicable — correção de configuração sem decisão de produto nova.
- [x] ADR-0027 Accepted — placement do catálogo global e configuração de versão.
- [x] Requisito REQ-00053 Approved — comportamento de descoberta já definido.
- [x] Sem assumption ou Open Question pendente.
- [x] API Contract: sem alteração; `getPlanOffers` Draft inalterado.
- [x] Mudança atômica: um arquivo, uma linha de configuração.
- [x] Fail-safe: default vazio preserva comportamento atual quando env var ausente.

**What:** Adicionar `billing.plan-offers.catalog-version: ${BILLING_PLAN_OFFERS_CATALOG_VERSION:}` ao
bloco `billing:` do `application.yml` base, imediatamente após `billing.invoice.catalog-version`.

**Where:** `backend/src/main/resources/application.yml` — bloco `billing:` (linha 535 a 556).

**Depends on:** Nenhuma dependência pendente.

**Prohibited:**
- Alterar qualquer arquivo além do `application.yml` base e a documentação deste plano.
- Setar um default não-vazio no `application.yml` base (cada ambiente deve injetar explicitamente).
- Modificar `application-dev.yml`, `application-hml.yml`, `application-prd.yml` ou qualquer outro profile.
- Alterar lógica Java, DDL, migrações, contrato OpenAPI ou frontend.
- Acessar produção, Sandbox ASAAS ou qualquer sistema externo.

**Mandatory:**
- A propriedade deve usar exatamente `${BILLING_PLAN_OFFERS_CATALOG_VERSION:}` (default vazio = fail-safe).
- Deve ficar dentro do bloco `billing:` existente, alinhado com `billing.invoice.catalog-version`.
- Atualizar este plano com status `Completed` após gates verdes.
- Atualizar o índice de task plans com a entrada deste TP.

**Acceptance Tests:**
- O adapter `JdbcPlanOfferCatalogReadAdapter` continua com comportamento fail-safe quando a env var
  está ausente (retorna lista vazia sem exceção).
- O teste existente `JdbcPlanOfferCatalogReadAdapterWiringTest` e `BillingControllerTest` devem continuar verdes.
- Com `BILLING_PLAN_OFFERS_CATALOG_VERSION=baseline-draft-2026-09-05` configurado, o endpoint
  `getPlanOffers` retorna as ofertas publicadas do catálogo.

**Definition of Done:**
- `application.yml` contém `billing.plan-offers.catalog-version: ${BILLING_PLAN_OFFERS_CATALOG_VERSION:}`.
- Testes focais `JdbcPlanOfferCatalogReadAdapterWiringTest` e `ListTenantPlanOffersUseCaseTest` verdes.
- Validação documental `./infra/scripts/validate-docs.sh` em PASS.
- Branch governada com commit Conventional Commits publicada.

## 3. Execution Tracking

| Task | Status | Evidência |
| --- | --- | --- |
| TP-00061-CONFIG-FIX-001: adicionar propriedade no application.yml | Completed | application.yml linha 545 |
| Atualizar índice task_plans/README.md | Completed | entrada TP-00061 |
| Testes focais JdbcPlanOfferCatalogReadAdapterWiringTest | Completed | ver seção 4 |
| Testes focais ListTenantPlanOffersUseCaseTest | Completed | ver seção 4 |
| validate-docs.sh | Completed | ver seção 4 |
| Commit governado | Completed | branch 61.0.0-fix-billing-plan-offers-catalog-version-config |

## 4. Evidence

### 4.1 Configuração aplicada

Adicionado em `application.yml` bloco `billing:`:
```yaml
billing:
  plan-offers:
    catalog-version: ${BILLING_PLAN_OFFERS_CATALOG_VERSION:}
```

### 4.2 Resultado dos testes

Executado: `./mvnw -B -Dtest=JdbcPlanOfferCatalogReadAdapterWiringTest,ListTenantPlanOffersUseCaseTest test`

### 4.3 Validate docs

Executado: `./infra/scripts/validate-docs.sh`

## 5. Change Log

| Versão | Data | Autor | Mudança |
| --- | --- | --- | --- |
| 1.0 | 2026-09-20 | Antigravity (IA) | Criação do plano e implementação do corretivo de configuração. |

