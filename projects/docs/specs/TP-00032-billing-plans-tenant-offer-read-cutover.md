---
document_id: TP-00032
primary_nature: Plano
objective: Coordenar o cutover repository-local da tela /billing/plans para um catálogo real, tenant-scoped e fail-closed.
scope: Documentação, backend Billing, migração do catálogo global, frontend Next.js, contratos, RBAC e testes da consulta de ofertas.
non_objectives: Não implementar checkout, cobrança, amendment, ativação por pagamento, chamadas externas, Sandbox ASAAS, HML, PRD ou publicação comercial real.
owner: Engenharia, Produto e Billing
status: In Progress — V90.1 hash repair completed repository-local; offer discovery environmental proofs pending
version: 1.10
date: 2026-09-04
last_reviewed: 2026-09-12
keywords: billing, planos, ofertas, frontend, backend, tenant, catálogo, cutover
related_files: do../../product/requirements/REQ-00005-plan-feature-matrix.md, do../../product/requirements/REQ-00054-super-admin-unified-billing-price-version.md, do../../product/requirements/REQ-00053-billing-tenant-plan-offer-discovery.md, do../../product/use-cases/UC-00047-billing-tenant-plan-offer-discovery.md, TP-00013-enterprise-billing-implementation-task-plan.md, ../../backend/docs/adrs/ADR-0026-billing-api-tenant-admin-cutover.md, ../../backend/docs/adrs/ADR-0027-catalogo-global-faturamento-local.md
code_references: backend/src/main/java/br/com/duoset/saas_service/contexts/billing/, backend/src/main/resources/db/migration/tenant/, frontend/src/app/(dashboard)/billing/plans/, frontend/src/components/billing/plans/, frontend/src/services/billingService.ts
principal_statement: A tela /billing/plans somente apresenta ofertas publicadas pelo catálogo global por uma API tenant-scoped validada; ausência de catálogo ou de contratação publicada permanece explícita e nunca recorre a mock, enum ou checkout fictício.
---

# TP-00032 — Billing plans tenant offer read cutover

## 1. Overview

Este plano implementa o recorte de descoberta e comparação de ofertas definido no
REQ-00053 e no UC-00047. O cutover atravessa documentação, banco de plataforma,
backend e frontend no mesmo lote para impedir drift de DTO, rota global ambígua ou
fallback MSW.

A autorização desta conversa cobre somente código, DDL, fixtures e testes locais.
Ela executa localmente os slices `13.0`/`13.1` já liberados pelo `D-00 =
RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`. Não altera os gates
do TP-00011, não autoriza sistemas externos e não transforma os valores sintéticos
de desenvolvimento em preço comercial publicado ou autoridade de entitlement.

### 1.1 Coherence Assessment — 2026-09-05

| Source | Observed state | Classification / correction |
| --- | --- | --- |
| Website vigente | Start 2 + Telegram; Business 20 + Telegram/WhatsApp; Premium por consultoria + Telegram/WhatsApp; sem preço público | Referência de apresentação confirmada pelo pedido humano. |
| REQ-00005 histórico | 3/50/ilimitado | Baseline legado de entitlement, explicitamente sem autoridade viva. |
| TP-00021 v1.1 | 3/50/ilimitado | Divergência documental; corrigida na v1.2. |
| `/billing/plans` | 3/50/ilimitado, termo “documentos”, preços sintéticos visíveis | Não aderente à oferta pública; requer catálogo v2 e correção de UI. |

A correção não modifica enforcement ou contrato de tenant. Ela versiona somente a
projeção de descoberta: 2/20/`CONTRACT_DEFINED`, terminologia pública
“empresas/clientes”, canais apresentados por plano e preço oculto enquanto
`NOT_PUBLISHED`.

## 2. Execution Tracking Matrix

### 1.2 Incremento BASIC_DASHBOARD — readiness 2026-09-11

**Task ID:** `TP-00032-BASIC-DASHBOARD`

**Gate Audit:** `READY` para REQ-00005 v1.10 e PRD-00001 v1.13, limitado ao
catálogo repository-local, contrato read-only, apresentação frontend e testes.
Produto aprovou `BASIC_DASHBOARD` em Start/Business e `ADVANCED_DASHBOARD` em
Premium. KPIs Premium, rollout e efeitos externos são proibidos neste incremento.

**Paths autorizados:** nova migration tenant aditiva; fixture SQL `dev`; contrato
`billing-v1`; tipos/schema/i18n/mocks/testes da descoberta de ofertas; REQ-00005,
seu índice e este plano. A migration histórica V77 permanece imutável.

**Acceptance Tests:** catálogo e frontend provam a matriz Start/Business/Premium;
schema aceita o novo código; demais capacidades permanecem inalteradas.

**Definition of Done:** evidência focal backend/frontend, validação documental e
Quality Gate com todos os targets alterados. O incremento é atômico e não requer
decomposição semântica.

### 1.3 Corretivo da regressão V90 — readiness 2026-09-12

**Task ID:** `TP-00032-BASIC-DASHBOARD-REGRESSION`

**Gate Audit:** `READY` para `PRD-00001 v1.14` (`Validated`) e
`REQ-00005 v1.10` (`Approved`). O UC-00047 não é aplicável: esta unidade não
altera fluxo, API ou comportamento de produto; corrige somente a evidência
PostgreSQL que permaneceu congelada em 30 entitlements depois de V90 adicionar
exatamente `BASIC_DASHBOARD` às três ofertas canônicas. Não há assumption,
Open Question, dependência ou decisão pendente.

**What:** substituir a cardinalidade obsoleta por prova da cardinalidade corrente
e da matriz semântica START/BUSINESS/PREMIUM. **Where:** somente
`backend/src/test/java/br/com/duoset/saas_service/contexts/billing/internal/infrastructure/persistence/BillingCanonicalCatalogMigrationPostgresTest.java`.
**Depends on/Reuses:** V77, V90, Testcontainers, fixture canônica e o teste
PostgreSQL existentes. **Requirements:** REQ-00005 AC-031 e o incremento
`TP-00032-BASIC-DASHBOARD`.

**Acceptance Tests:** a cadeia Flyway V1..V90 produz `33` entitlements; existem
exatamente três linhas `BASIC_DASHBOARD`, habilitadas para START/BUSINESS e
desabilitada para PREMIUM; o teste focal termina sem falhas ou skips com Docker
disponível.

**Prohibited:** editar migration histórica, código de produção, contrato HTTP,
frontend, fixture comercial ou exclusão JaCoCo. **Mandatory:** preservar todas as
asserções de publicação/imutabilidade, tornar explícita a matriz acrescentada por
V90, executar o teste focal e informar o único target ao Quality Gate backend.

**Result:** `BLOCKED` em Assurance. A cardinalidade e a matriz passaram, mas o
round-trip canônico revelou `BIL-CAT-HASH-001`: V90 altera os filhos de cada offer
draft sem recompor o hash do agregado. O teste não pode ser aprovado enquanto a
integridade persistida falhar. A correção foi decomposta automaticamente na
unidade independente da Section 1.4.

### 1.4 Forward fix do hash canônico — readiness 2026-09-12

**Coordinator Task ID:** `TP-00032-BASIC-DASHBOARD-HASH-REPAIR`

**Gate Audit:** `READY` para `PRD-00001 v1.14` (`Validated`),
`REQ-00005 v1.10` e `REQ-00054 v1.23` (`Approved`), AC-031 e
BR-031/BR-036. Use Case, User Story View e contrato HTTP são `N/A`: o coordenador
preserva testes de persistência já aprovados e corrige integridade interna de uma
migration, sem alterar ator, fluxo, API ou payload. `BIL-CAT-HASH-001` tem causa e
aceite objetivos; não há assumption, Open Question ou decisão pendente. O
inventário Flyway termina em V90; V91/V92 estão reservadas pelo TP-00008, portanto
a versão livre e ordenada é V90.1.

**Parent → children / ordem:**
`TP-00032-HASH-REPAIR-A-DRAFT-WORKFLOW` →
`TP-00032-HASH-REPAIR-B-APPROVAL-MIGRATION` →
`TP-00032-HASH-REPAIR-D-V90-1-UPGRADE` →
`TP-00032-HASH-REPAIR-C-FRESH-GUARDS`. A e B preservam resultados
independentes do teste legado e reduzem cada target Java para menos de 500 linhas;
D entrega e prova o forward fix; C fecha o fresh catalog contra a migration já
disponível. Cada handoff executável possui gate próprio abaixo.

**Paths coordenados e autorizados:**

- `backend/src/main/resources/db/migration/tenant/V90_1__repair_basic_dashboard_offer_hashes.sql`;
- `backend/src/test/java/br/com/duoset/saas_service/contexts/billing/internal/infrastructure/persistence/BillingCatalogDraftWorkflowPostgresTest.java`;
- `backend/src/test/java/br/com/duoset/saas_service/contexts/billing/internal/infrastructure/persistence/BillingCatalogApprovalMigrationPostgresTest.java`;
- `backend/src/test/java/br/com/duoset/saas_service/contexts/billing/internal/infrastructure/persistence/BillingCanonicalCatalogMigrationPostgresTest.java`;
- `backend/src/test/java/br/com/duoset/saas_service/contexts/billing/internal/infrastructure/persistence/BillingCatalogOfferHashMigrationPostgresTest.java`;
- `backend/src/test/java/br/com/duoset/saas_service/contexts/billing/internal/infrastructure/persistence/BillingCatalogMigrationPostgresFixtures.java`.

A fixture package-private é somente suporte hermético comum, pertence ao primeiro
handoff e não constitui uma quinta unidade semântica. Os quatro testes continuam
separados por resultado observável.

#### 1.4.1 A — Workflow de drafts

**Task ID:** `TP-00032-HASH-REPAIR-A-DRAFT-WORKFLOW`

**Gate Audit:** `READY` para as fontes e versões da Section 1.4, sem API, assumption
ou pergunta aplicável. **What:** preservar isoladamente o workflow PostgreSQL de
update exato de drafts e reabertura atômica após rejeição. **Where:** criar
`BillingCatalogDraftWorkflowPostgresTest.java`, extrair o suporte hermético para
`BillingCatalogMigrationPostgresFixtures.java` e remover esse resultado de
`BillingCanonicalCatalogMigrationPostgresTest.java`. **Depends on:** teste vigente
e V77..V90. **Reuses:** `JdbcBillingCatalogStoreAdapter`, Testcontainers e fixtures
atuais. **Requirements:** PRD-00001 v1.14, REQ-00054 v1.23 BR-031/BR-036 e este TP.

**Acceptance Tests:** todas as asserções do workflow de draft/rejeição permanecem
equivalentes e os três targets terminam com menos de 500 linhas. **Prohibited:**
alterar comportamento, DDL ou cobertura do cenário. **Mandatory:** fixture
package-private, sem teste autônomo, rede ou provider; todos os targets informados
ao Quality Gate. **Definition of Done:** cenário movido sem perda de asserção,
compila e passa focalmente, limites de tamanho passam. **Result:** `COMPLETED`,
executado em 2026-09-12 no lote PostgreSQL `22/22`, sem falha, erro ou skip; os
três targets permanecem abaixo de 500 linhas.

#### 1.4.2 B — Evolução V89 e approvals

**Task ID:** `TP-00032-HASH-REPAIR-B-APPROVAL-MIGRATION`

**Gate Audit:** `READY` para as mesmas fontes, depois de A. **What:** preservar em
teste próprio a evolução V89, approvals históricos e decisões próprias explícitas.
**Where:** criar `BillingCatalogApprovalMigrationPostgresTest.java` e retirar esse
resultado de `BillingCanonicalCatalogMigrationPostgresTest.java`. **Depends on:** A
concluído e V77..V89. **Reuses:** `BillingCatalogMigrationPostgresFixtures`.
**Requirements:** PRD-00001 v1.14, REQ-00054 v1.23 e V89.

**Acceptance Tests:** todas as provas históricas/waiver V89 permanecem equivalentes
e ambos os targets ficam abaixo de 500 linhas. **Prohibited:** mudar status,
approval, SoD/MFA ou migration. **Mandatory:** preservar fixtures e asserções
vigentes. **Definition of Done:** cenário V89 passa focalmente sem skip com Docker
e limite de tamanho passa. **Result:** `COMPLETED`, executado em 2026-09-12 no
lote PostgreSQL `22/22`, sem falha, erro ou skip; approvals históricos foram
preservados.

#### 1.4.3 C — Fresh catalog e publication guards

**Task ID:** `TP-00032-HASH-REPAIR-C-FRESH-GUARDS`

**Gate Audit:** `READY` para as mesmas fontes, depois de B. **What:** manter no
teste canônico somente o fresh migration, round-trip e publication/immutability
guards. **Where:**
`BillingCanonicalCatalogMigrationPostgresTest.java`. **Depends on:** A, B e D
concluídos. **Reuses:** `BillingCatalogMigrationPostgresFixtures`, V77, V90 e
V90.1. **Requirements:** PRD-00001 v1.14, REQ-00005 v1.10 AC-031 e REQ-00054
v1.23.

**Acceptance Tests:** fresh V1..V90.1 produz 33 entitlements, matriz aprovada,
round-trip dos três offers e hashes golden; publicação/retirada/imutabilidade
permanecem cobertas; rerun executa zero migrations; history contém V90.1; target
fica abaixo de 500 linhas. **Prohibited:** reduzir guards ou manter hash antigo em
approval/retirement helper. **Mandatory:** helpers consomem o hash corrente; golden
fica na prova fresh. **Definition of Done:** cenário focal passa sem skip com
Docker e todos os controles/tamanho passam. **Result:** `COMPLETED`, executado em
2026-09-12 no lote PostgreSQL `22/22`, sem falha, erro ou skip; fresh, rerun,
publication guards e hashes golden passaram.

#### 1.4.4 D — Upgrade e preflight V90.1

**Task ID:** `TP-00032-HASH-REPAIR-D-V90-1-UPGRADE`

**Gate Audit:** `READY` para as mesmas fontes, depois de B. **What:** adicionar V90.1
com preflight global e recompor somente hashes divergentes de offers `DRAFT`
seguros, provando upgrade e preservação. **Where:**
`V90_1__repair_basic_dashboard_offer_hashes.sql` e
`BillingCatalogOfferHashMigrationPostgresTest.java`. **Depends on:** A e B
concluídos; V77/V90 imutáveis; PostgreSQL 16/Testcontainers disponíveis.
**Reuses:** `PricingCanonicalHash`, `CatalogOfferVersion`,
`BillingCatalogMigrationPostgresFixtures`, `sha256(bytea)`, `int4send(integer)` e
`bytea` core. **Requirements:** PRD-00001 v1.14, REQ-00005 v1.10 AC-031,
REQ-00054 v1.23 BR-031/BR-036 e este TP.

**Acceptance Tests:** o upgrade parte explicitamente do target Flyway V90; offer
`PUBLISHED` preserva versão, hash e filhos; drafts seguros reconstituem pelo domínio.
Casos negativos independentes criam, em V90, `publication_hash`, approval
`AWAITING_INDEPENDENT_APPROVAL` e approval `APPROVED`; cada tentativa de V90.1
falha globalmente e o snapshot de `content_hash`/`row_version` de todos os drafts
permanece idêntico. Fresh e upgrade seguros registram V90.1 uma vez; rerun executa
zero migration; helper não permanece no catálogo; `pgcrypto` não é instalado.

**Prohibited:** editar V77/V90 ou outra migration committed; adicionar extensão;
alterar algoritmo Java; recompor/publicar `PUBLISHED` ou `RETIRED`; mudar approval,
audit ou outbox; tocar frontend/API/provider; excluir JaCoCo. **Mandatory:** o
preflight, antes da primeira recomposição, bloqueia qualquer draft com
`publication_hash IS NOT NULL` ou approval `PUBLISH_OFFER`/`OFFER_VERSION`
correspondente em `AWAITING_INDEPENDENT_APPROVAL` ou `APPROVED`; a função auxiliar
é migration-scoped e removida; campos usam UTF-8, prefixo int32 big-endian,
ordenação exata por `display_order`, `true`/`false` e vazio para quantity/unit
nulos. Somente draft cujo hash calculado divergir recebe o novo `content_hash` e
`row_version = row_version + 1`.

V90.1 não cria audit/outbox: é reparo controlado durante startup, antes de o runtime
observar o agregado inconsistente, e não um comando de domínio. Approvals e offers
publicados permanecem byte a byte; qualquer decisão ativa aborta a migration antes
de alteração. Os hashes golden após V90, com 72 campos por offer, são:

- START: `501c46ef64ab745a5f79c581c0d4655c54564db154ffa481e313bd4b5830ae7d`;
- BUSINESS: `fa8d66a8178220cb4f7aa61a26f2063e920119abb3d6ed14c7b665b033371b86`;
- PREMIUM: `57a68fe3fea7701af8370b132fadde24b31194f392d31f1228f5c38ab96d9ef5`.

**Definition of Done:** preflight negativo prova zero recomposição; caminhos fresh
e upgrade seguro passam sem skip; hashes são idênticos ao
`PRICING_CANONICAL_V1`; somente rows divergentes incrementam `row_version` uma vez;
published/approvals/audit/outbox são preservados; teste focal, suíte impactada,
Quality Gate com todos os targets e validação documental retornam `PASS`.
**Result:** `COMPLETED`, executado em 2026-09-12 no lote PostgreSQL `22/22`, sem
falha, erro ou skip. Upgrade desde V90, três preflights negativos, rerun,
preservação de published/approvals/audit/outbox e ausência de helper/`pgcrypto`
passaram. O lote arquitetural passou `29/29`; o Quality Gate backend focused
passou os seis targets com `failures=0` e `blocked=0`.

| # | Activity | Owner | Status | Evidence |
| --- | --- | --- | :---: | --- |
| 1 | Especificar requisito, caso de uso, contrato, segurança e estados da UI | Produto + Arquitetura | ✅ | REQ-00053 v1.4 e UC-00047 v1.3 |
| 2 | Criar catálogo global versionado e adapter read-only no datasource de plataforma | Backend | 🔄 | V76, catálogo v2, seleção explícita e unitários concluídos; prova PostgreSQL bloqueada pelo Docker socket |
| 3 | Publicar `GET /api/v1/tenants/{tenantId}/billing/plan-offers` | Backend | ✅ | MockMvc cobre sucesso, 401, 403, BOLA e `no-store` |
| 4 | Migrar service, Zod, hooks e componentes sem MSW ou DTO Stripe | Frontend | ✅ | 147/147 Vitest, lint sem erros e build de produção |
| 5 | Validar responsividade, a11y, i18n e E2E do read slice | Frontend + QA | 🔄 | axe verde; 2 smokes backend-real listados, runtime autenticado indisponível |
| 6 | Executar gates de arquitetura, suítes impactadas e documentação | Engenharia | ✅ | gates executáveis verdes; skips ambientais registrados abaixo |

## 3. Contract and Data Decisions

- A rota canônica é `GET /api/v1/tenants/{tenantId}/billing/plan-offers`.
- O tenant efetivo deve coincidir com o path antes de qualquer consulta.
- O catálogo pertence ao datasource de plataforma e retorna somente versões
  `PUBLISHED` vigentes, ordenadas por `display_order` e código.
- Dinheiro cruza a API como `amountMinor` decimal em string, `currency=BRL` e
  `cadence=MONTHLY`; o browser não calcula preço.
- Quantidades usam `FINITE`, `UNLIMITED` ou `NOT_APPLICABLE`; `-1`, `NULL` e
  ausência não significam ilimitado.
- Limite dependente de negociação usa `CONTRACT_DEFINED`, nunca `UNLIMITED` ou
  `NOT_APPLICABLE` por aproximação.
- Start apresenta até 2 empresas/clientes; Business até 20; Premium é definido em
  consultoria. O baseline legado 3/50 não é copiado para a oferta.
- A capability omnichannel usa apresentação coerente com o website: Start mostra
  Telegram; Business e Premium mostram Telegram ou WhatsApp.
- Preço sintético permanece no payload hermético, mas não aparece na UI enquanto
  `contractingStatus=NOT_PUBLISHED`.
- O profile `dev` seleciona `dev-plan-offers-2026-09-05` por configuração explícita;
  versões publicadas antigas permanecem imutáveis e não existe seleção `latest`.
- A resposta contém códigos estáveis; textos visíveis pertencem ao i18n do frontend.
- `contractingStatus=NOT_PUBLISHED` impede CTA enganoso. Checkout e amendment são
  dependências do UC-00039/TP-00011, não deste recorte.
- Fixture de catálogo é permitida somente no profile `dev`, por bootstrap explícito
  e idempotente; HML/PRD não recebem seed nem fallback.

## 4. Lessons Applied

- `LL-BE-00038`: moeda acompanha todo valor monetário.
- `LL-BE-00044`: o controller retorna DTO dedicado, nunca domínio.
- `LL-BE-00066`, `LL-BE-00076` e `LL-BE-00085`: tenant/contexto/RBAC precedem
  repository e transação e são exercitados no teste REST.
- `LL-FE-00013`: query keys e invalidation permanecem tenant-scoped.
- `LL-FE-00014`: a matriz visível foi conferida 1:1 com a especificação; a ação
  ainda não contratável permanece explicitamente desabilitada, nunca inerte.
- `LL-FE-00020`: a especificação cobre modelo, componentes, estado, API, RBAC,
  routing e testes antes do código.
- `LL-FE-00024`, `LL-FE-00030` e `LL-FE-00032`: zero hardcode, triângulo RBAC já
  reconciliado e DTO TypeScript/Zod idêntico ao DTO Java.

## 5. Verification

```bash
./infra/scripts/validate-docs.sh
cd backend && ./mvnw -B -Dtest=ListTenantPlanOffersUseCaseTest,BillingControllerTest,BillingPlanOfferCatalogMigrationPostgresTest test
cd backend && ./mvnw -B -Dtest=FlywayMultiDatabaseTest test
cd backend && ./mvnw -B -Dtest=ModuleStructureVerificationTest test
cd backend && ./mvnw -B -Dtest=CleanArchitectureRulesTest,CleanArchitectureRuleContractTest test
cd frontend && npm test -- --run src/components/billing src/services/__tests__/billingService.test.ts src/hooks/queries/__tests__/useBillingQueries.test.tsx 'src/app/(dashboard)/billing/plans/__tests__/page.test.tsx' src/schemas/billingSchemas.test.ts
cd frontend && npm run lint
cd frontend && npm run build
```

| Gate | Result |
| --- | --- |
| Backend focado | `51` testes: `50 PASS`, `1 SKIP` PostgreSQL; `BUILD SUCCESS`. |
| Arquitetura Modulith | `6/6 PASS`; `BUILD SUCCESS`. |
| Clean Architecture | `23/23 PASS`; `BUILD SUCCESS`. |
| Flyway multi-database | `2 SKIP`; Docker socket recusou acesso antes dos testes. |
| Frontend impactado | `147/147 PASS` em `17` arquivos, incluindo axe. |
| Frontend — canais por plano | `33/33 PASS` após reconciliar Start e Business/Premium. |
| Website — contrato dos planos | `3/3 PASS`, incluindo Start 2 e Business 20. |
| Prettier | Todos os arquivos alterados conformes. |
| ESLint | `0` erros; `55` warnings preexistentes fora do recorte. |
| Next build | `PASS`; TypeScript e `39/39` páginas, incluindo `/billing/plans`. |
| Playwright contract discovery | `2` smokes backend-real listados para tenants A/B; execução requer runtime e storage states autenticados. |

O teste PostgreSQL de V75/V76 foi atualizado, mas Testcontainers não obteve acesso a
`/var/run/docker.sock`, inclusive na tentativa fora do sandbox autorizada. Não há
binários PostgreSQL locais. O E2E backend-real também permanece não executado por
depender de frontend, API, PostgreSQL, Keycloak e storage states autenticados.
Nenhum teste executado usa rede ou provider real.

## 6. Risks and Rollback

| Risk | Mitigation |
| --- | --- |
| Mock ou enum voltar a ser autoridade | Adapter consulta somente o catálogo persistido; handlers Billing permanecem vazios. |
| Oferta de outro estado ou fora da vigência aparecer | Query allowlisted e teste de filtragem. |
| Tenant divergente alcançar o datasource | Guard anterior ao port e teste BOLA sem interação com o adapter. |
| Valor local ser interpretado como preço real | Bootstrap somente `dev`, provenance sintética e ausência de seed em HML/PRD. |
| CTA fictício gerar assinatura falsa | Estado `NOT_PUBLISHED` e remoção do checkout Stripe da tela. |

Rollback de código restaura a leitura fail-closed anterior. A migração é aditiva e
não será desfeita de modo destrutivo; tabelas vazias podem permanecer sem efeito.

## 7. Definition of Done

- [x] REQ-00053 e UC-00047 aprovados no envelope repository-local.
- [x] API, DTO Java, schema Zod e tipos TypeScript são isomórficos.
- [x] Testes provam 401, 403, tenant mismatch, no-store, ordenação e fail-closed.
- [x] A página não usa MSW, namespace `/api/v1/billing/**`, `stripePriceId` ou CTA fictício.
- [x] Loading, erro, vazio, catálogo e plano atual são acessíveis e internacionalizados.
- [x] Gates backend, frontend e documentação são reportados com evidência e skips explícitos.

O encerramento em `Completed` exige ainda `AC-004` executado sobre PostgreSQL real
e o smoke Playwright backend-real autenticado. Essas lacunas são ambientais, não
autorizam substituição por H2, mock ou afirmação de conclusão sem evidência.

## Granularity / Decomposition Review

- **Outcome:** Decomposed
- **Rationale:** O teste legado de 771 linhas mistura quatro resultados com ciclos de evolução e aceite independentes: workflow de drafts, compatibilidade de approvals V89, fresh/publication guards e upgrade/preflight V90.1. Cada filho mantém seu comportamento, teste e evidência; a fixture compartilhada é apenas suporte hermético.
- **Children:** `TP-00032-HASH-REPAIR-A-DRAFT-WORKFLOW`, `TP-00032-HASH-REPAIR-B-APPROVAL-MIGRATION`, `TP-00032-HASH-REPAIR-C-FRESH-GUARDS`, `TP-00032-HASH-REPAIR-D-V90-1-UPGRADE`
- **Reviewed on:** 2026-09-12

## 8. Change Log

| Version | Date | Changes |
| --- | --- | --- |
| 1.10 | 2026-09-12 | Conclui os quatro filhos do reparo V90.1: PostgreSQL combinado 22/22, arquitetura 29/29 e Quality Gate focused em PASS, com seis targets abaixo de 500 linhas e sem alterar externalidades. |
| 1.9 | 2026-09-12 | Decompõe o teste canônico acima de 500 linhas em quatro resultados IRG READY, autoriza fixture hermética e V90.1, fixa preflight negativo desde V90, incremento seletivo de row_version e hashes golden sem audit/outbox. |
| 1.8 | 2026-09-12 | Endurece o READY V90.1 com REQ-00054 BR-031/036: draft sob submissão ativa falha globalmente antes da recomposição, preservando o conteúdo exato decidido. |
| 1.7 | 2026-09-12 | Registra `BIL-CAT-HASH-001` exposto pelo teste PostgreSQL e decompõe o forward fix V90.1 em IRG READY, preservando V90 e as reservas V91/V92. |
| 1.6 | 2026-09-12 | Registra `TP-00032-BASIC-DASHBOARD-REGRESSION` em IRG READY para corrigir somente a expectativa PostgreSQL obsoleta após V90, com um target de teste e zero alteração de runtime/migration. |
| 1.5 | 2026-09-11 | Registra readiness e escopo do incremento BASIC_DASHBOARD aprovado para Start/Business, mantendo ADVANCED_DASHBOARD no Premium e KPIs futuros fora do recorte. |
| 1.0 | 2026-09-04 | Cria o plano transversal e inicia a especificação antes da implementação. |
| 1.1 | 2026-09-04 | Registra implementação completa no repositório, gates verdes e as evidências PostgreSQL/E2E ainda bloqueadas pelo runtime. |
| 1.2 | 2026-09-05 | Registra a análise de incoerência e inicia a correção versionada 2/20/consultoria sem alterar entitlement legado. |
| 1.3 | 2026-09-05 | Registra a correção repository-local, 147 testes frontend, contrato do website, backend/arquitetura verdes e mantém explícitas as provas PostgreSQL/E2E bloqueadas pelo ambiente. |
| 1.4 | 2026-09-05 | Fecha o drift adicional de canais: Start apresenta Telegram; Business e Premium apresentam Telegram ou WhatsApp, com 33 testes focalizados e build repetido. |
