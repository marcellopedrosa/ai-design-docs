---
document_id: TP-00035
primary_nature: Plano
objective: Coordenar a gestão administrativa de planos, add-ons, contratos e faturamento sobre uma única autoridade de PriceVersion.
scope: Especificação, catálogo global seller-owned, contratos tenant-local, assinatura por itens, descontos tipados, rating, fatura, superfícies Super Admin e cutover repository-local.
non_objectives: Não publicar ou ativar preços em ambiente, não acessar produção ou dados reais, não chamar provider, não executar rollout ambiental e não reabrir decisões aceitas dos ADRs de Billing.
owner: Engenharia, Produto, Billing e Financeiro
status: In Progress — invoice RBAC child blocked by API contracts; prior scoped evidence preserved
version: 1.10
date: 2026-09-08
last_reviewed: 2026-09-12
keywords: billing, super admin, catálogo, planos, add-ons, priceversion, contrato, assinatura, desconto, fatura
related_files: TP-00013-enterprise-billing-implementation-task-plan.md, TP-00038-billing-contract-context-temporary-mfa-disablement.md, do../../product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md, do../../product/requirements/REQ-00054-super-admin-unified-billing-price-version.md, do../../product/use-cases/UC-00048-super-admin-billing-catalog-price-versions.md, do../../product/use-cases/UC-00049-super-admin-tenant-contract-add-ons-discounts.md, do../../product/use-cases/UC-00050-super-admin-billing-preview-invoice-close.md, ../../backend/docs/specs/IP-BE-13.3.3-price-version-invoice-rating-cutover.md, ../../backend/docs/specs/IP-BE-13.3.3.1-super-admin-invoice-rbac-hardening.md, docs/contracts/billing-v1.openapi.yaml, docs/contracts/billing-super-admin-decisions-v1.openapi.yaml
code_references: backend/src/main/java/br/com/duoset/saas_service/contexts/billing/, backend/src/main/resources/application.yml, backend/src/main/resources/db/migration/tenant/, backend/src/main/resources/db/migration/billing/, frontend/src/app/(dashboard)/admin/, frontend/src/app/(dashboard)/billing/, frontend/src/components/billing/tenant/BillingTenantLauncher.tsx, .env.example, docker-compose.yml, infra/deploy/production.env.example
principal_statement: Todo plano e add-on faturável nasce no catálogo como PriceVersion publicada, é pinado em SubscriptionItem e snapshot contratual tenant-local e chega à linha de fatura sem consulta a preço vivo, setting ou mapa hardcoded.
---

# TP-00035 — Gestão Super Admin unificada de Billing

## 1. Overview

Este plano especializa os workstreams 13.1, 13.2 e 13.3 do
[TP-00013](TP-00013-enterprise-billing-implementation-task-plan.md). O objetivo é
eliminar as três autoridades hoje desconectadas — oferta de descoberta, plano da
assinatura e preço de fechamento — e fazer catálogo, contrato, rating e fatura
transportarem a mesma PriceVersion por identidade, versão e hash.

A administração começa no console Super Admin. Catálogo é global; qualquer
operação sobre contrato ou fatura exige seleção explícita de um tenant e entrada
em contexto tenant-scoped governado. `ROLE_SUPER_ADMIN` é cumulativa com
authority fina, `BILLING_TENANT_IMPERSONATE`, purpose e tenant guard. D-13.3
permite que o mesmo Super Admin autorizado prepare, decida e efetive; D-13.5
dispensa MFA para todas as roles em DEV/HML/PRD até rollback formal, sem ampliar
RBAC.

### 1.1 AS-IS gap matrix

| Área | Estado observado | Gap a eliminar |
| --- | --- | --- |
| Descoberta de planos | billing_plan_offer_versions guarda amount_minor diretamente e alimenta /billing/plans. | É projeção de descoberta sem referência à PriceVersion canônica. |
| Pricing | PriceVersion e o evaluator puro existem no domínio e têm testes para modelos tipados. | Não há repository, DDL canônico, API administrativa ou approval workflow. |
| Assinatura | Subscription e tenant plan legados representam um único enum/string. | Não há CommercialAgreement, AgreementRevision, SubscriptionItem, Amendment ou snapshot de preço aceito. |
| Add-ons | Não existe catálogo administrativo nem item contratual persistido. | Um add-on não pode ser cadastrado, contratado, prorated ou faturado com lineage. |
| Fechamento | BillingInvoiceProperties mantém START=9900, BUSINESS=29900 e PREMIUM=89900; TenantPlanInvoiceSourceAdapter lê TenantApi.plan. | O valor vem de configuração paralela e não da PriceVersion aceita pelo contrato. |
| Invoice | Release 0 cria somente uma linha RECURRING_PLAN e exige desconto zero. | Não representa base, add-on, proration e desconto tipado com referências reproduzíveis. |
| Frontend | /billing/plans é read-only e não há console administrativo de Billing funcional. | Faltam catálogo, contratação tenant-local, approvals, preview e lineage. |

Em 2026-09-05, o responsável humano ratificou os preços-base mensais de Start,
Business e Premium como R$ 99,00, R$ 299,00 e R$ 899,00. Essa decisão aprova os
valores para parametrização em `PriceVersion` `DRAFT`; ela não transforma
`BillingInvoiceProperties`, V75/V76 ou fixtures na autoridade canônica, não
publica oferta e não autoriza backfill de contrato. A Section 10.1 fecha o
contrato da migration e preserva decisão/publicação explícita, auditável e
autorizada sem exigir segundo humano.

### 1.2 Target authority flow

| Estágio | Autoridade | Store | Saída obrigatória |
| --- | --- | --- | --- |
| Catálogo | Product/Offer/AddOn + PriceVersion publicada | Plataforma saas_platform | ID, versão, hash, moeda, cadence, timing e componentes tipados |
| Proposta | QuoteItem | Banco do tenant selecionado | Referência exata ao preço-base ou de add-on e preview reproduzível |
| Contrato | AgreementRevision + SubscriptionItem | Banco dedicado do tenant | AcceptedPricingSnapshot e ContractEntitlementSnapshot |
| Desconto | PromotionVersion ou ManualPromotionAuthorizationVersion | Definição global + snapshot aceito tenant-local | Resultado promocional aplicado e hash, sem override livre |
| Rating | RatingInputSnapshot e RatingResult | Banco do tenant | Quantidade, PriceVersion, desconto e breakdown pinados |
| Fatura | CommercialInvoiceLine | Banco do tenant | Lineage até SubscriptionItem, PriceVersion, contrato, rating e promoção |

Não existe hierarquia runtime do tipo “tenant herda o preço atual do plano”. Existe
linhagem explícita:

    OfferVersion
      -> base PriceVersion exata
      -> zero ou mais add-ons, cada qual com PriceVersion própria
      -> QuoteItem / SubscriptionItem
      -> AcceptedPricingSnapshot tenant-local
      -> RatingResult
      -> CommercialInvoiceLine

Preço negociado é outra PriceVersion seller-owned, restrita à audiência comercial,
aprovada e imutável. Desconto não é rebatizado como preço: usa a taxonomia
promocional aceita; somente PROMOTIONAL_PRICE referencia uma PriceVersion
promocional adicional.

## 2. Execution Tracking Matrix

Legenda: Pending, In Progress, Done, Blocked.

| Fase | Atividade | Owner | Status | Evidência / saída |
| --- | --- | --- | --- | --- |
| 0 | Inventariar AS-IS, ADRs, requisitos, UCs e lições aprendidas | Arquitetura | Done | Matriz da Section 1.1 |
| 0 | Criar REQ-00054 e UC-00048 a UC-00050 | Produto + Arquitetura | Done | Especificações vinculadas |
| 0 | Criar seis implementation plans especializados | Backend + Frontend | Done | IP-BE/IP-FE 13.1.2, 13.2.2 e 13.3.3 |
| 1 | Resolver critérios comerciais e operacionais pendentes | Produto + Financeiro + Humano responsável | Done | 9/9 decisões materializadas; HD-07=A encerrou o gate na Section 10 |
| 2 | Persistir e administrar catálogo/PriceVersion global | Backend + Frontend | In Progress | IP-BE-13.1.2-super-admin-catalog-price-version-management iniciado pelo backend; frontend sucede OpenAPI estável |
| 3 | Materializar contratos, itens, add-ons e descontos por tenant | Backend + Frontend | Pending | IP-BE-13.2.2-super-admin-tenant-commercial-contracts e IP-FE-13.2.2-super-admin-tenant-commercial-contracts |
| 4 | Cortar rating/fatura para snapshots e PriceVersion | Backend + Frontend | Blocked | IP-BE-13.3.3.1-super-admin-invoice-rbac-hardening registra IRG `BLOCKED` por dez operações Draft e uma autorização Active incompatível; nenhum dos seis paths está autorizado |
| 5 | Migrar por tenant, executar shadow, reconciliar e cortar | Billing + Dados + QA | Pending | Manifest, divergências, attestation e rollback |
| 6 | Qualificar segurança, PostgreSQL, E2E e rollout separado | Segurança + QA + Operações | Pending | Gates verdes e evidência ambiental |

| Fase | Total | Done | In Progress | Blocked | Pending | Progresso |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Especificação | 3 | 3 | 0 | 0 | 0 | 100% |
| Decisão humana | 9 | 9 | 0 | 0 | 0 | 100% |
| Implementação e cutover | 5 | 0 | 1 | 1 | 3 | 0% |
| Total | 17 | 12 | 1 | 1 | 3 | 71% |

O Human Decision Gate está fechado. A execução repository-local começa pelo
catálogo backend e só avança para cada sucessor após contrato e gates do slice
anterior. Publicação comercial, tenants reais, providers e rollout continuam sem
autorização neste plano.

O fechamento funcional de AC-066 não substitui o gate contract-first. A folha
`BILLING-IAM-INVOICE-SUPERADMIN-RBAC` permanece bloqueada até Arquitetura/API e
Billing/Security publicarem cobertura `Active` coerente para suas onze operações
e um novo IRG declarar `READY` para os seis paths exatos.

As decisões posteriores D-13.3 e D-13.5 sucedem o recorte histórico D-13.1 sem
reabrir as nove decisões originais. O mesmo Super Admin autorizado pode decidir
sua ação e MFA permanece dispensada em DEV/HML/PRD até rollback formal; o
[TP-00038](TP-00038-billing-contract-context-temporary-mfa-disablement.md)
preserva a evidência histórica e a reversibilidade, sem ampliar RBAC.

## 3. Context and Constraints

### 3.1 Invariants

1. Catálogo, preço e promoção publicados são globais, seller-owned e imutáveis.
2. Contrato, SubscriptionItem, snapshots, rating e invoices são tenant-local.
3. Uma transação nunca abrange o store global e um banco de tenant.
4. O contexto do tenant é estabelecido antes de repository, EntityManager,
   conexão ou transação tenant-scoped.
5. Rating e close não consultam catálogo vivo, latest, Tenant.plan, provider ou
   BillingInvoiceProperties.planPricesMinor.
6. Toda linha faturável de base/add-on aponta para PriceVersion exata; toda
   redução aponta para resultado promocional aceito.
7. Publicar preço não reprifica contrato; adoção exige nova revisão/amendment.
8. Mudança material invalida preview e ApprovalSeal.
9. Invoice finalizada e Release 0 histórico nunca são reescritos.
10. Decisão exige Super Admin humano autorizado e evidência íntegra, mas não um
    segundo humano; o mesmo ator pode preparar, decidir e efetivar conforme D-13.3.

### 3.2 Roles and effective context

| Perfil | Responsabilidade | Limite |
| --- | --- | --- |
| Super Admin autorizado | Criar, simular, preparar, decidir e efetivar conforme a authority exata e a alçada. | Pode decidir a própria ação; identidade humana, hash, auditoria e guards continuam obrigatórios. |
| Super Admin em contexto tenant | Operar contratos/runs do tenant selecionado após impersonação explícita. | Path, header, tenant ativo, purpose, authority e TTL devem coincidir; família invoice também exige `BILLING_TENANT_IMPERSONATE`. MFA segue D-13.5 até rollback. |
| Representante comercial do tenant | Aceitar diretamente o hash da proposta no produto. | Requer `BILLING_CONTRACT_ACCEPT`; venda assistida usa o fallback documental de HD-04. |
| Billing scheduler | Executar somente commands previamente autorizados e tenant-local. | Nunca é checker nem cria política/preço. |

### 3.3 Modules and stores

| Módulo | Store | Responsabilidade |
| --- | --- | --- |
| contexts.billing — catalog adapter | Plataforma, atualmente exposta pelo tenantDataSource/tenantFlyway | Produtos, ofertas, add-ons, PriceVersions, promoções, approvals e outbox global |
| contexts.billing — tenant adapters | TenantRoutingDataSource e migration track db/migration/billing | Contratos, itens, snapshots, rating, invoices, journal e outbox |
| frontend | Browser, sem autoridade financeira | Intenções tipadas, estado, diff, approvals e apresentação |
| Keycloak/Security | IAM | Roles, authorities, MFA, identidade humana efetiva e evidência preservada para todos os fluxos fora do waiver contratual |

O nome tenantDataSource é legado: no código atual ele aponta para o banco de
plataforma. O implementation plan deve respeitar o binding efetivo e não inferir
placement pelo nome do diretório.

## 4. Phase Details

### Phase 0 — Specification and decision freeze

| ID | Activity | Owner | Dependency | Deliverable |
| --- | --- | --- | --- | --- |
| 0.1 | Caracterizar as três autoridades AS-IS | Arquitetura | — | Gap matrix |
| 0.2 | Fixar comportamento observável | Produto | 0.1 | REQ-00054 |
| 0.3 | Detalhar jornadas e telas | Produto + Frontend | 0.2 | UC-00048 a UC-00050 |
| 0.4 | Decompor backend/frontend | Engenharia | 0.3 | Seis IPs |
| 0.5 | Submeter critérios comerciais ao humano | Produto + Financeiro | 0.4 | Section 10 decidida |

Acceptance:

- nenhum documento trata preço hardcoded como valor oficial;
- hierarquia viva é rejeitada e lineage pinada é explícita;
- cada tela possui rota, modelo, componentes, estados, RBAC e testes;
- todo código futuro possui implementation plan correspondente.

### Phase 1 — Global catalog and PriceVersion administration

| ID | Activity | Owner | Dependency | Deliverable |
| --- | --- | --- | --- | --- |
| 1.1 | Criar persistence model global e repositories | Backend | 0.5 | PriceVersion e catálogo persistidos |
| 1.2 | Implementar simulation, lifecycle e approval | Backend | 1.1 | Commands idempotentes e auditados |
| 1.3 | Publicar OpenAPI admin | Backend + Segurança | 1.2 | /api/v1/admin/billing/catalog |
| 1.4 | Implementar console de catálogo/add-ons | Frontend | 1.3 | /admin/billing/catalog e /admin/billing/add-ons |
| 1.5 | Derivar projeção consumida por /billing/plans | Backend | 1.2 | Read model V2 com PriceVersion ref |

Acceptance: preço publicado é imutável, maker não aprova, a tela tenant lê a
mesma autoridade e nenhum profile recebe publicação comercial automática. A
migration pode criar os três drafts-base ratificados, mas não uma oferta
`PUBLISHED` ou um contrato.

### Phase 2 — Tenant contracts, subscription items and discounts

| ID | Activity | Owner | Dependency | Deliverable |
| --- | --- | --- | --- | --- |
| 2.1 | Criar aggregates e migrations tenant-local | Backend | 1.2 | Agreement, revisions, items, amendments e snapshots |
| 2.2 | Implementar quote/preview/accept/apply | Backend | 2.1 | Workflow reproduzível |
| 2.3 | Implementar promoção manual governada | Backend | 1.2, 2.2 | Snapshot aceito, sem manualDiscount |
| 2.4 | Criar launcher Super Admin e workspace tenant | Frontend | 2.2 | Seleção, impersonação e jornadas |
| 2.5 | Provar add/remove/proration/discount | QA | 2.3, 2.4 | Unit, PostgreSQL, MVC e E2E |

Acceptance: base e cada add-on são SubscriptionItems distintos; cada item pina
PriceVersion; desconto só entra por artefato promocional aprovado; snapshots
locais bastam para faturar sem catálogo disponível.

### Phase 3 — Rating and invoice cutover

| ID | Activity | Owner | Dependency | Deliverable |
| --- | --- | --- | --- | --- |
| 3.1 | Criar RatingInputSnapshot a partir do contrato | Backend | 2.2 | Input pinado |
| 3.2 | Expandir invoice/lines de forma aditiva | Backend | 3.1 | Lineage base/add-on/proration/discount |
| 3.3 | Substituir fonte de preço Release 0 | Backend | 3.2 | Nenhum planPricesMinor no caminho V2 |
| 3.4 | Implementar preview, approval e finalize UI | Frontend | 3.2 | Run/invoice workspace |
| 3.5 | Executar shadow e reconciliar | Billing + Financeiro | 3.3 | Comparação por tenant sem efeito |

Acceptance: close usa somente snapshot local; alteração contratual invalida
preview; invoice V2 preserva refs/hashes; invoices V1 continuam legíveis e
imutáveis.

### Phase 4 — Fenced tenant cutover and qualification

| ID | Activity | Owner | Dependency | Deliverable |
| --- | --- | --- | --- | --- |
| 4.1 | Inventariar tenants e gerar manifest explícito | Dados | 3.5 | Mapeamento sem inferência |
| 4.2 | Materializar baseline prospectivo | Backend | 4.1 | Agreement/snapshots por tenant |
| 4.3 | Cortar um tenant por vez sob fence | Operações | 4.2 | Single authority |
| 4.4 | Executar gates completos | QA + Segurança | 4.3 | Evidências reproduzíveis |
| 4.5 | Preparar rollout em plano separado | Operações | 4.4 | Sem promoção implícita |

Acceptance: divergência ou evidência ausente mantém tenant no legado; não existe
dual-read decisório pós-corte; rollback desabilita V2 para novas operações sem
apagar versões, contratos ou invoices.

## 5. Agent Chain per Workstream

1. Produto/Arquitetura congela regra e critérios.
2. Backend congela OpenAPI, domínio, ports, DDL e testes.
3. Frontend deriva types/Zod do contrato backend e implementa a UI.
4. Segurança valida RBAC, BOLA, purpose, maker-checker e a matriz MFA/waiver do
   TP-00038, preservando MFA fora do recorte contratual.
5. QA executa testes focalizados, suites impactadas, PostgreSQL, E2E e gates.
6. Orquestração atualiza evidências, lessons learned e status sem falso verde.

Catálogo pode iniciar antes da UI contratual. Contrato depende de catálogo
publicável. Rating/invoice depende de contrato e snapshots. Frontend de cada
trilha pode avançar com fixtures contratuais herméticas somente depois do OpenAPI,
sem MSW como fallback integrado.

## 6. Dependency Diagram

    Human Decision Gate
        -> Catalog + PriceVersion
        -> Tenant Quote/Agreement/SubscriptionItem
        -> Accepted Pricing/Promotion Snapshots
        -> Rating Input/Result
        -> Invoice Preview + Approval
        -> Tenant-local Finalize
        -> Provider command only in a separately authorized plan

## 7. Agent Responsibility Matrix

| Área | Specification | Catalog | Contract | Invoice | Qualification |
| --- | --- | --- | --- | --- | --- |
| Produto/Financeiro | Regras e valores | Aprovar catálogo | Termos e desconto | Critérios de close | Attestation |
| Arquitetura | ADR adherence | Placement/ports | Boundary tenant | Lineage/atomicidade | Cutover |
| Backend | AS-IS | Domain/API/DDL | Domain/API/DDL | Rating/close/DDL | Gates |
| Frontend | Screen specs | Admin UI | Tenant workspace | Run/invoice UI | E2E/a11y |
| Segurança | Threat model | SoD/MFA | BOLA/purpose | Approval seal | Audit |
| QA | Acceptance map | Tests | Tests | Tests | Evidence |

## 8. Coordination Rules

1. Software só é editado após o Human Decision Gate fechado, este plano em
   `In Progress` e a validação documental canônica verde.
2. Cada mudança transversal começa pelo menor implementation plan aplicável.
3. OpenAPI/DTO Java precedem type e Zod TypeScript; handlers herméticos replicam
   exatamente a shape e nunca escondem falha backend-real.
4. Migrations globais usam o datasource de plataforma efetivo; migrations
   contratuais/financeiras usam o track tenant-local de Billing.
5. O tenant context precede qualquer transação; testes devem observar ausência de
   interação quando guard falha.
6. Nenhum gate arquitetural pode ser desabilitado para obter suíte verde.
7. Cutover é por tenant, com fingerprint, manifest, shadow, fence e rollback.
8. Toda mudança material em preço, contrato ou desconto invalida hash/approval
   anterior e exige novo preview.
9. Ações externas, Sandbox, HML, PRD e dados reais exigem planos e autorizações
   separados.

## 9. Verification

Validação documental deste loop:

    ./infra/scripts/validate-docs.sh

Comandos planejados para execução dos implementation plans:

    cd backend && ./mvnw -B -Dtest=<focused-tests> test
    cd backend && ./mvnw -B -Dtest=ModuleStructureVerificationTest test
    cd backend && ./mvnw -B -Dtest=CleanArchitectureRulesTest,CleanArchitectureRuleContractTest test
    cd backend && ./mvnw -B clean test
    cd frontend && npm test -- --run <impacted-tests>
    cd frontend && npm run lint
    cd frontend && npm run format:check
    cd frontend && npm run build
    cd frontend && npx playwright test --project=<billing-project>

PostgreSQL/Flyway e E2E autenticado são evidências obrigatórias para o cutover.
H2, mocks de repository e MSW isolados não substituem esses gates.

## 10. Human Decision Gate — fechado

As respostas humanas de 2026-09-05 foram reconciliadas com os ADRs canônicos. O
registro abaixo distingue decisão de negócio, autorização de implementação e
publicação ambiental: aprovar um valor não publica uma oferta, não ativa desconto
e não altera contrato existente. A origem é `HUMAN_EXPLICIT` nesta conversa; o
repositório não comprova criptograficamente a identidade do solicitante.

| ID | Estado final | Decisão materializada |
| --- | --- | --- |
| HD-01 | `ACCEPTED_WITH_SCOPE` | Start/Business/Premium usam a matriz da Section 10.1: BRL, `MONTHLY`, `IN_ADVANCE`, `FIXED` e `DRAFT`. A vigência é informada e aprovada no futuro command de publicação, nunca inventada pela migration. |
| HD-02 | `ACCEPTED_WITH_SCOPE` | Criar migration aditiva que permita catálogo parametrizado e materialize os três drafts-base. Add-ons são parametrizáveis, mas nenhum SKU de add-on é criado ou publicado sem matriz própria. |
| HD-03 | `ACCEPTED` | Primeiro cutover cobre `BASE_PLAN` e `ADD_ON` com modelo `FIXED` e cadências `MONTHLY`, `ANNUAL` ou `ONE_TIME`; outros modelos ficam `OFF` até slice completo. |
| HD-04 | `ACCEPTED` | Adotada a opção A híbrida: aceite direto pelo tenant ou termo externo assinado com registro e validação independentes por dois Super Admins. |
| HD-05 | `ACCEPTED_FAIL_CLOSED` | Somente percentual **ou** valor fixo por alvo/período, seller-funded e sem stacking. Como nenhum cap numérico foi informado, cadastro/simulação podem existir, mas publicação/aplicação de desconto ficam `OFF`. |
| HD-06 | `ACCEPTED` | Adotada a opção A: `America/Recife`, `grace=24h`, `safetyLag=5m`, proration por segundos para upgrade/add-on e downgrade/remoção no próximo boundary. |
| HD-07 | `ACCEPTED` | Adotada a opção A: matriz fina por verbo, identidade humana efetiva, contexto elevado server-side, MFA recente de 15 min, impersonação hard TTL 30 min/idle 15 min e ApprovalSeal single-use de 15 min. |
| HD-08 | `ACCEPTED` | Cutover usa dry-run e manifest explícito por tenant; grandfathering pina versões/snapshots, não há inferência por enum/valor, dual-read decisório ou reescrita de invoice V1. |
| HD-09 | `ACCEPTED` | Adotada a opção A: bruto/desconto/líquido e lineage promocional seguem ao handoff fiscal; ausência de ruleset mantém `REVIEW_REQUIRED` e impede emissão. |

As nove decisões estão fechadas. Isso autoriza implementação, migrations e testes
somente no repositório/local. HD-05 continua produzindo desconto executável `OFF`
até uma decisão futura fornecer cap; fechar o gate não inventa esse valor.

Em 2026-09-06, `D-13.1 = HUMAN_EXPLICIT` adicionou uma emenda posterior sem
alterar a contagem histórica de 9/9: enquanto
`billing.security.admin-contract-context-mfa-enabled=false`, o POST
administrativo pode emitir waiver apenas para Super Admin e conjunto não vazio
integralmente contido na allowlist `BILLING_CONTRACT_*` do TP-00038. O contexto
dispensado só é aceito no uso das mesmas authorities contratuais, inclusive
`BILLING_CONTRACT_ACCEPT_VALIDATE`; SoD, checker distinto e approval permanecem.
Reativar a flag invalida o waiver no próximo uso. Tenant Admin, catálogo,
invoice/run e demais operações continuam sob MFA.

### 10.1 Matriz de preços-base e contrato da migration — HD-01/HD-02

| Product code | Product kind | Valor de exibição | amountMinor | Currency | Cadence | Timing | Model | Estado criado |
| --- | --- | ---: | ---: | --- | --- | --- | --- | --- |
| `START` | `BASE_PLAN` | R$ 99,00 | `9900` | `BRL` | `MONTHLY` | `IN_ADVANCE` | `FIXED` | `DRAFT` |
| `BUSINESS` | `BASE_PLAN` | R$ 299,00 | `29900` | `BRL` | `MONTHLY` | `IN_ADVANCE` | `FIXED` | `DRAFT` |
| `PREMIUM` | `BASE_PLAN` | R$ 899,00 | `89900` | `BRL` | `MONTHLY` | `IN_ADVANCE` | `FIXED` | `DRAFT` |

`BRL`/`MONTHLY`/`FIXED` seguem o ADR-0038; base recorrente `IN_ADVANCE` segue o
ADR-0044. A migration não escolhe `effectiveFrom`: a janela efetiva pertence ao
payload/hash submetido ao workflow de publicação. A oferta mantém Start com 2
empresas/clientes, Business com 20 e Premium como `CONTRACT_DEFINED`, conforme
REQ-00053; capacidade é entitlement versionado, não componente monetário.

A entrega de migration deve obedecer cumulativamente:

1. usar o próximo número Flyway livre confirmado imediatamente antes da edição;
2. criar o schema global canônico de Product/Offer/PriceVersion e referências,
   ou estendê-lo aditivamente caso outro slice o tenha criado primeiro;
3. criar IDs estáveis e três `PriceVersion` drafts reproduzíveis com os valores
   acima, sem copiar `amount_minor` para uma nova autoridade paralela;
4. não editar V75/V76, não publicar automaticamente, não criar contrato, não
   reprificar tenant e não chamar provider;
5. criar zero Product `ADD_ON` até existir SKU, unidade, compatibilidade,
   entitlement e preço aprovados; depois disso o cadastro ocorrerá pelo console,
   sem nova mudança de código para cada add-on;
6. provar em PostgreSQL o binding do datasource, constraints, money/currency,
   hash/reconstituição, lifecycle `DRAFT` e ausência de rows `PUBLISHED`.

### 10.2 Escopo funcional e descontos — HD-03/HD-05/HD-08

- Planos e add-ons do primeiro slice usam somente componente `FIXED`; valores
  anual e one-time não são inferidos a partir do mensal e nascem em drafts próprios.
- No máximo um `PERCENTAGE_DISCOUNT` **ou** `FIXED_AMOUNT_DISCOUNT` pode vencer
  por alvo e período. O benefício é seller-funded, não cumulativo, tem vigência,
  reason, referência e cap explícitos e nunca vira linha negativa ou override.
- Na ausência do cap, `discountsEnabled=false`; nenhum default percentual ou
  monetário será inventado.
- Migração de tenant é opt-in, forward-only e auditada. O manifest informa origem,
  OfferVersion/PriceVersion destino, hash, contrato/snapshot e resultado do shadow;
  divergência mantém aquele tenant no legado.

### 10.3 HD-04 — aceite híbrido materializado

Aceite é o ato que transforma uma proposta em obrigação contratual; approval de
preço por Super Admin não substitui o aceite do tenant. Em qualquer trilha, o hash
exato da `QuoteRevision`, versão dos termos, tenant, ator e `acceptedAt` em UTC
ficam selados. Mudança material exige novo aceite.

A decisão humana adotou a opção A. O fluxo principal é o aceite do hash por
usuário autenticado do tenant com `BILLING_CONTRACT_ACCEPT`. No fallback de venda
assistida, o signatário do tenant assina termo externo; um Super Admin registra o
hash e a `evidenceRef`, e outro humano distinto valida o mesmo registro. Super
Admins registram e conferem evidência, mas nunca assinam ou aceitam pelo tenant.
Ambas as jornadas são obrigatórias na API, UI, auditoria e testes.

### 10.4 HD-06 — cutoff, preview e proration materializados

`Cutoff` não é a data em que o cliente perde o direito de solicitar mudança. É o
instante em que os inputs de uma fatura são selados. Antes dele, uma mudança
material invalida preview/seal e força recálculo; depois dele, a fatura fechada
nunca muda e a diferença segue para período aberto por amendment ou memo.

Os ADRs já fixam: anchor no dia local do contrato (último dia quando o mês não o
possui, sem drift), upgrade/add-on imediato por `TIME_WEIGHTED_SECONDS`,
downgrade/remoção no próximo boundary e invoice finalizada imutável. A decisão
humana adotou a opção A para a `ClosePolicyVersion` inicial:

- timezone `America/Recife`;
- `grace=24h` após o fim do período;
- `safetyLag=5m` e watermarks completos antes do fechamento;
- upgrade/add-on aceito antes do cutoff é prorated por segundos e lançado na
  próxima invoice aberta;
- downgrade/remoção entra no próximo boundary;
- qualquer mudança material invalida preview e `ApprovalSeal`; documento já
  finalizado nunca é reaberto.

### 10.5 HD-07 — baseline de autorização e impersonação; D-13.3/D-13.5

O responsável humano adotou a opção A em 2026-09-05. As decisões posteriores
D-13.3 e D-13.5 substituíram somente segregação humana e MFA: qualquer Super
Admin humano com authority/alçada pode preparar, decidir e efetivar a própria
ação, e MFA fica dispensada em DEV/HML/PRD até rollback formal. Menor privilégio,
tenant guard, hash/seal de integridade, idempotência e auditoria permanecem.

#### 10.5.1 O que existe hoje e por que não basta para mutations financeiras

No AS-IS, a personificação guarda tenant selecionado no cliente e o backend
valida tenant/path/header antes de instalar o contexto efetivo. Esse mecanismo é
útil para navegação e leitura tenant-scoped, mas não prova isoladamente purpose,
MFA recente, duração da elevação ou aprovação do conteúdo financeiro exato. O
`tenantId` persistido no browser nunca será credencial nem authority.

O alvo aprovado adiciona uma `BillingElevatedContext` emitida e validada no
servidor. Ela vincula `contextId`, `actorSub`, `humanPrincipalId`, `tenantId`
quando aplicável, purpose, authorities concedidas, `issuedAt`, `expiresAt`,
`idleExpiresAt`, referência da MFA e estado de revogação. Alterar tenant ou
purpose exige outro contexto; expiração encerra apenas a operação elevada, não a
sessão comum do usuário no produto.

#### 10.5.2 Quatro controles independentes

1. **Identidade humana:** o ator é comprovado pelo `sub` imutável e pelo
   `humanPrincipalId` canônico do IAM quando aplicável. IA, job, service account
   e break-glass não executam a decisão financeira humana.
2. **Authority por verbo:** `ROLE_SUPER_ADMIN` permite entrar no console, mas não
   concede automaticamente publicar preço, validar aceite ou finalizar invoice.
   Roles podem agrupar authorities; o backend autoriza o verbo concreto.
3. **Contexto elevado/impersonação:** para contrato ou invoice, o servidor sela
   ator, tenant, purpose, authorities e prazo. Durante D-13.5 registra
   `mfaRequired=false`; após rollback formal volta a selar prova MFA quando
   requerida. Path, header e contexto devem coincidir antes de datasource ou
   transação tenant-local.
4. **ApprovalSeal:** a decisão referencia ação, aggregate, revisão,
   `payloadHash`, tenant, moeda/total quando aplicável, ator e prazo. É single-use;
   mudança material, execução, revogação ou expiração exige novo preview e nova
   decisão, sem exigir identidade distinta.

O `humanPrincipalId` não é criado por sessão nem usado como mero identificador de
conta. Realms novos registram o atributo como admin-only e emitem a claim com AMR;
o recovery de volume local reconcilia os mappers e apenas a identidade DEV cuja
pessoa é conhecida. Conta legada sem associação humana autoritativa permanece
sem mutation financeira. Esse fail-closed é deliberado: gerar IDs diferentes por
conta faria duas contas da mesma pessoa aparentarem maker e checker distintos.

#### 10.5.3 Matriz fina aprovada

| Operação | Authority verificada | Segregação / contexto |
| --- | --- | --- |
| Ler catálogo | `BILLING_CATALOG_READ` | Global; sem acesso automático a contrato/fatura de tenant. |
| Criar/editar draft | `BILLING_CATALOG_DRAFT` | Maker; versão publicada continua imutável. |
| Simular preço | `BILLING_PRICE_SIMULATE` | Sem publicação; mesmo evaluator do command final. |
| Submeter preço | `BILLING_PRICE_SUBMIT` | Congela revisão e hash propostos pelo maker. |
| Aprovar preço | `BILLING_PRICE_APPROVE` | Super Admin humano autorizado decide exatamente o hash; pode ser o preparador. |
| Publicar preço | `BILLING_PRICE_PUBLISH` | Executor autorizado consome o seal; pode ser o preparador/decisor ou terceiro autorizado. |
| Entrar no tenant | `BILLING_TENANT_IMPERSONATE` | Purpose + contexto servidor; MFA dispensada por D-13.5 até rollback; não concede outros verbos. |
| Preparar contrato | `BILLING_CONTRACT_DRAFT` / `BILLING_CONTRACT_SUBMIT` | Tenant efetivo obrigatório. |
| Aceitar no produto | `BILLING_CONTRACT_ACCEPT` | Authority do representante do tenant; Super Admin não a herda. |
| Registrar termo externo | `BILLING_CONTRACT_ACCEPT_RECORD` | Super Admin maker registra hash/evidenceRef. |
| Validar termo externo | `BILLING_CONTRACT_ACCEPT_VALIDATE` | Super Admin humano autorizado valida o mesmo hash/evidência; pode ser o registrador. |
| Preparar invoice | `BILLING_INVOICE_PREVIEW` | Tenant efetivo; conteúdo ainda não final. |
| Aprovar invoice | `BILLING_INVOICE_APPROVE` | Super Admin humano autorizado decide generation/previewHash/total; pode ser o preparador. |
| Finalizar invoice | `BILLING_INVOICE_FINALIZE` | Executor autorizado consome seal válido e single-use. |

Não haverá `BILLING_*_ALL`, wildcard ou equivalência implícita entre essas
authorities. Um usuário pode receber mais de um bundle operacional e decidir a
própria ação somente quando possuir cada grant e alçada exatos.

#### 10.5.4 Os quatro relógios não são a mesma coisa

- **MFA recente:** quando requerida, idade máxima da prova de segundo fator ao
  executar um verbo sensível; ao vencer, pede novo step-up. Waiver contratual não
  inicia nem renova esse relógio.
- **Hard TTL da impersonação:** vida máxima do contexto tenant elevado, mesmo que
  haja atividade.
- **Idle TTL da impersonação:** encerra o contexto elevado após inatividade.
- **TTL do ApprovalSeal:** janela para executar exatamente o command aprovado;
  o seal também termina no primeiro uso.

Exemplo com o perfil aprovado: Alice cria e submete preço com hash `H1`, decide
`H1` e publica dentro da alçada porque possui as três authorities; outro Super
Admin autorizado também poderia decidir ou publicar. Se o valor mudar para `H2`,
se o seal expirar ou se já tiver sido usado, a publicação falha e exige novo
ciclo. Em contrato, o
contexto tenant de Alice dura no máximo 30 minutos e expira após 15 minutos sem
atividade; isso não a desconecta do produto, apenas fecha a elevação de Billing.

| Controle | Valor aprovado |
| --- | --- |
| MFA recente | Dispensada em DEV/HML/PRD por D-13.5; após rollback, no máximo 15 minutos desde o step-up server-validated. |
| Impersonação | Hard TTL de 30 minutos e idle TTL de 15 minutos. |
| ApprovalSeal | 15 minutos, single-use e vinculado ao command/hash exato. |
| Dispensa temporária | Todas as roles em DEV/HML/PRD enquanto D-13.5 vigorar; rollback formal restaura a policy sem ampliar authorities. |

Ausência de segundo humano não bloqueia a decisão. Ausência de role, authority,
alçada, tenant/purpose/contexto válido, integridade ou auditoria continua
fail-closed.

### 10.6 HD-09 — handoff fiscal materializado

São duas decisões diferentes. A fatura comercial precisa explicar o desconto; a
NFS-e depende de regra tributária competente. Registrar `SELLER_FUNDED` informa
quem suporta comercialmente o benefício, mas não decide se ele reduz base de
cálculo fiscal.

A decisão humana adotou a opção A. A linha comercial preserva bruto,
`discountAmountMinor` positivo, líquido, `PromotionVersion`, reason e funding. A
intenção fiscal leva esses campos e uma `taxTreatmentRef`; sem ruleset aplicável,
fica `REVIEW_REQUIRED` e não emite. Financeiro atesta apresentação e classificação
comercial; Fiscal/Contábil atesta tratamento por jurisdição, fonte, vigência e
`evidenceRef`; Jurídico participa quando a policy interna exigir.

Não é opção válida assumir que todo desconto reduz imposto, enviar linha negativa,
fundir invoice comercial com NFS-e ou usar provider de pagamento como autoridade.

### 10.7 Fechamento e autorização do loop

`HD-07=A` foi registrado como `HUMAN_EXPLICIT`. O gate está fechado e este loop
está autorizado a implementar código, migrations e testes herméticos locais na
ordem dos implementation plans. A autorização não cobre publicação de
PriceVersion/OfferVersion, ativação para tenant real, integração externa,
Sandbox, HML, PRD ou rollout.

D-13.3/D-13.5 também são `HUMAN_EXPLICIT`: dispensam o segundo aprovador e MFA
em DEV/HML/PRD até rollback formal, sem dispensar role, authority, alçada,
personificação, contexto, integridade ou auditoria. Nenhuma dessas decisões
autoriza alteração no Keycloak, efeito ambiental ou promoção implícita de
contrato HTTP Draft.

Para `BILLING-IAM-INVOICE-SUPERADMIN-RBAC`, o loop para antes do código: as dez
operações de `billing-v1` Draft conservam OQs bloqueantes e o contrato Active de
`billingRunApprove` diverge de AC-066. O IRG do IP-BE-13.3.3.1-super-admin-invoice-rbac-hardening registra owner e
condição objetiva de retomada.

### 10.8 Definition of Done e critérios de aceitação do loop

| ID | Resultado observável obrigatório | Evidência mínima |
| --- | --- | --- |
| DoD-01 | Catálogo global persiste Product/Offer/PriceVersion e cria somente drafts START=9900, BUSINESS=29900 e PREMIUM=89900 em BRL/MONTHLY/IN_ADVANCE/FIXED. | Migration aditiva, round-trip PostgreSQL e ausência de publicação/add-on semeado. |
| DoD-02 | API Super Admin cria, consulta, simula, submete, decide e publica versões conforme lifecycle, hash, authorities e D-13.3/D-13.5. | Testes de domínio, MVC/security, replay/stale e decisão própria autorizada. |
| DoD-03 | `/billing/plans` deriva preço e entitlements 2/20/consultoria da projeção canônica, sem mapa ou amount paralelo. | Contrato backend-real, componente e E2E da rota. |
| DoD-04 | Plano e add-on são cadastráveis sem código e contratados como SubscriptionItems com PriceVersion/snapshots exatos. | PostgreSQL, API tenant-scoped e jornada frontend de quote/contrato. |
| DoD-05 | Aceite direto e fallback externo usam hash/evidência e authorities; decisão própria é permitida ao Super Admin autorizado. | Casos positivo, BOLA, self-validation, stale e idempotência. |
| DoD-06 | BillingElevatedContext é server-issued, tenant/purpose/authorities-bound, hard TTL 30 min e idle 15 min; MFA segue D-13.5 e rollback. Família invoice exige cumulativamente humano, Super Admin, impersonação, authority exata e contexto válido. | Testes de guard antes de datasource/transação, matriz RBAC/contexto e UX de expiração/troca. |
| DoD-07 | Rating/close usa snapshots PriceVersion tenant-local; linha V2 preserva base/add-on/proration, bruto/desconto/líquido e lineage, sem Tenant.plan ou planPricesMinor no caminho V2. | Sentinels, PostgreSQL e regressão V1/V2. |
| DoD-08 | Preview, Decision/ApprovalSeal de 15 min single-use e finalize são separados, idempotentes e invalidam em drift. | Testes de concorrência, expiry, replay, rollback e decisão própria autorizada. |
| DoD-09 | Consoles de catálogo, contrato e faturamento possuem rotas protegidas, estados completos, i18n, a11y e nenhuma ação inerte. | Vitest/axe, triângulo RBAC, lint, typecheck, build e Playwright backend-real. |
| DoD-10 | DTO Java, OpenAPI, TypeScript, Zod e fixtures são 1:1; gates Modulith/ArchUnit permanecem ativos. | Contract tests, architecture gates e varreduras finais sem drift. |
| DoD-11 | Documentação, índices, evidências, comandos, falhas e skips refletem o resultado real. | `validate-docs.sh` final e changelogs/status sem falso verde. |

## 11. Corrective task TP-00035-CF-01 — actionable catalog approval failures

### Task contract

| Field | Value |
| --- | --- |
| What | Distinguish an expired/missing MFA proof from an authority denial in catalog approval Problem Details and present the checker with an actionable, localized reason and the existing real MFA reauthentication action. |
| Where | `BillingCatalogAdminExceptionHandler`; `BillingCatalogAdminControllerTest`; `CatalogApprovalWorkspace`; its colocated component test; and the `pt-BR` Billing message catalog. Exact paths are recorded in IP-BE/FE-13.1.2 corrective tasks. |
| Depends on | REQ-00054 v1.15 `Approved`; UC-00048 v1.7 `Approved`; ADR-0050 v1.5 `Accepted`; catalog approval endpoint and `AuthProvider.reauthenticate` already available repository-locally. |
| Reuses | Existing RFC 9457 handler, `isBillingMfaRequired`, `AuthContext.reauthenticate`, `role="alert"`, Billing i18n namespace and focused MVC/component test patterns. |
| Requirements | REQ-00054 AC-004, AC-031 and AC-033 plus Section 14; UC-00048 Sections 5, 9, 15 and 18; ADR-0050 Sections 2.1, 2.7 and 2.9; frontend/backend package standards. |

### Gate Audit

| Control | Evidence |
| --- | --- |
| Superior sources | REQ-00054 v1.15 is `Approved`, UC-00048 v1.7 is `Approved`, and ADR-0050 v1.5 is `Accepted`; all already require fresh MFA, explicit forbidden/error states and localized accessible feedback. REQ-00054 v1.15 adds only the tenant-GUID compatibility AC-063 and expressly preserves catalog MFA/authority, so it does not alter this corrective task. |
| User Story View | Existing actor/value is the independent Super Admin checker who needs to understand and recover from a denied decision in order to complete the governed approval; mapped to AC-004/031/033 and UC-00048 step 9 plus failure states. |
| Assumptions | None. The captured 403, current handler mapping and UI fallback are directly reproducible in the repository; no cause is inferred after the backend starts returning the exact reason code. |
| Open Questions | None. Error taxonomy and recovery are already decided by REQ-00054 and ADR-0050. |
| Dependencies | Endpoint, typed error metadata, MFA classifier and real reauthentication callback exist; no install, external service, migration or environment mutation is required. |
| Scope | Limited to error taxonomy/presentation/tests for `/admin/billing/catalog/approvals/[approvalId]`; no authorization rule, lifecycle or approval semantics change. |
| Task | What/Where/Depends on/Reuses/Requirements, tests, prohibitions, mandatory items and finite DoD are explicit here and in both implementation plans. |

### Acceptance Tests

| Criterion | Evidence |
| --- | --- |
| AC-004 / MFA remains mandatory | MVC regression proves `MFA_REQUIRED` returns HTTP 403 with `BILLING_MFA_REQUIRED`, while `ACCESS_DENIED` remains `BILLING_FORBIDDEN`; the impacted controller/use-case/security suite passed 32/32. |
| AC-031 / explicit error and forbidden states | Component regression submits a decision, receives each typed 403 and verifies distinct controlled feedback; the exact MFA case exposes and invokes the real reauthentication callback. |
| AC-033 / i18n and accessibility | Visible strings come from `billing.json`; the decision error remains an alert, heading order is valid, raw server content is absent and the focused component test passes axe. |

### Prohibited

- Do not bypass MFA, maker-checker, `BILLING_PRICE_APPROVE`, purpose, ETag or idempotency.
- Do not display raw response bodies, stack traces, secrets or unsanitized backend text.
- Do not alter PriceVersion/OfferVersion state, publish data, call external systems, deploy or access real data.
- Do not broaden the corrective slice beyond catalog approval error taxonomy and presentation.

### Mandatory

- Preserve fail-closed behavior and distinguish only the already-modeled `MFA_REQUIRED` reason.
- Use controlled i18n messages and the existing server-driven error code classifier.
- Add focused backend MVC and frontend component/a11y regressions.
- Run focused tests, impacted package gates and the documentation validator without network or installation.

### Definition of Done

- [x] `MFA_REQUIRED` and `ACCESS_DENIED` produce distinct stable error codes under HTTP 403.
- [x] The approval screen explains MFA renewal or authorization denial instead of the generic failure sentence.
- [x] The MFA action calls the existing real reauthentication callback; no local authorization decision is introduced.
- [ ] Focused backend/frontend tests and applicable quality/documentation gates pass with current evidence recorded.

The last item remains open: scoped backend/frontend gates pass, but the package
PR gates are not green. Backend PR is `BLOCKED` by the absent JaCoCo plugin and
`check` goal. Frontend PR is `FAIL`/`BLOCKED`: the changed test passes 3/3, lint
and typecheck pass, while unrelated coverage tests and the broad format baseline
fail and build is refused because a local environment file exists. E2E was not
selected or authorized for this repository-local correction.

### Execution result

`IMPLEMENTED / SCOPED PASS / PACKAGE ASSURANCE NOT GREEN` — readiness was
`READY` before editing and was re-audited against REQ-00054 v1.15. The exact
corrective behavior and its scoped suites are complete without guard relaxation;
the pre-existing/package-wide blockers above prevent a false overall `PASS`.

## 12. Granularity / Decomposition Review

| Field | Result |
| --- | --- |
| **Outcome** | `Decomposed` |
| **Rationale** | O TP coordenador excede 500 linhas porque conserva decisões, matriz, dependências e evidência agregada; execução ocorre somente nos IPs filhos por resultado, nunca por autorização genérica deste pai. |
| **Children** | IP-BE/IP-FE 13.1.2, 13.2.2 e 13.3.3; o boundary `BILLING-IAM-INVOICE-SUPERADMIN-RBAC` foi isolado no IP-BE-13.3.3.1-super-admin-invoice-rbac-hardening com seis paths e IRG próprio `BLOCKED`. |
| **Reviewed on** | `2026-09-12` |

## 13. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.10 | 2026-09-12 | Codex / implementation-readiness | Reconcilia D-13.3/D-13.5 e AC-066, decompõe o hardening invoice no IP-BE-13.3.3.1-super-admin-invoice-rbac-hardening e registra IRG `BLOCKED` pelos contratos HTTP Draft/incompatível; nenhum código é autorizado. |
| 1.9 | 2026-09-08 | Codex / implementação | Registra o corretivo implementado, suites impactadas backend 32/32 e frontend 6/6 verdes e mantém o assurance de pacote explicitamente não verde pelos blockers/falhas amplos observados. |
| 1.8 | 2026-09-08 | Codex / reconciliação | Reaudita `TP-00035-CF-01` contra REQ-00054 v1.15; AC-063 trata somente tenant GUID e preserva integralmente MFA/authority do catálogo, mantendo o corretivo `READY`. |
| 1.7 | 2026-09-08 | Solicitante humano / Codex, corretivo | Registra `TP-00035-CF-01` como `READY` para separar MFA de authority no Problem Details e tornar o erro da tela de approval explícito e recuperável, sem relaxar controles financeiros. |
| 1.6 | 2026-09-06 | Solicitante humano / Codex, materialização | Vincula `D-13.1`/TP-00038: somente o POST Super Admin emite o waiver, aceito no uso das cinco authorities contratuais, inclusive `ACCEPT_VALIDATE`; preserva os nove HDs, SoD/approval e MFA dos demais fluxos. |
| 1.5 | 2026-09-05 | Codex / implementação | Materializa o contrato IAM de identidade humana/AMR e a estratégia segura para realms persistidos antes do hardening de código. |
| 1.4 | 2026-09-05 | Solicitante humano / Codex, execução | Materializa HD-07=A, fecha 9/9 decisões, promove o plano a In Progress e congela o Definition of Done cross-stack antes da implementação. |
| 1.3 | 2026-09-05 | Solicitante humano / Codex, materialização | Materializa HD-04=A, HD-06=A e HD-09=A; reduz o gate a HD-07 e detalha identidade, authorities, contexto elevado, ApprovalSeal e perfis de TTL para a rodada 3. |
| 1.2 | 2026-09-05 | Solicitante humano / Codex, materialização | Registra HD-01/02/03/05/08 como decisões humanas explícitas, fixa drafts-base de R$ 99/299/899 e detalha HD-04/06/07/09 para a rodada 2 sem iniciar software. |
| 1.1 | 2026-09-05 | Codex / AgentOrchestrator | Consolida HD-01–HD-09 somente após criar todos os artefatos e mantém execução bloqueada até decisão humana. |
| 1.0 | 2026-09-05 | Codex / AgentOrchestrator | Cria o plano coordenador, registra AS-IS/TO-BE e mantém a implementação aguardando o gate humano consolidado. |
