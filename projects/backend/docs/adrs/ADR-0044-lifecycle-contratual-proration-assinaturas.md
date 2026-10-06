---
document_id: "ADR-0044"
primary_nature: "Decisao"
objective: "Fechar `D-05` definindo estados, boundaries temporais, ativação, trial, renovação, amendment, proration, pause, cancelamento e reativação do contrato SaaS sem transferir autoridade ao provider."
scope: "Quote aceita, order, `CommercialAgreement`, `Subscription`, revisões, service period, billing anchor, trial, activation policy, terms evergreen/fixed, renewal, amendments, proration, pause, cancellation, reactivation, backdating, payer e snapshots tenant-local."
non_objectives: "Implementar código, DDL, OpenAPI ou UI; definir metering/rating de `D-06`, correção de invoice de `D-07`, evento financeiro por rail de `D-08`, dunning de `D-09`, refund/crédito de `D-10`, tax de `D-11`, accounting de `D-12`, RBAC concreto de `D-13`, rollout de `D-14` ou evidência externa."
owner: "Billing / Produto / Financeiro / Arquitetura"
status: "Accepted"
date: "2026-08-25"
version: "1.2"
keywords: "subscription lifecycle, commercial agreement, amendment, proration, trial, activation, renewal, pause, cancellation, billing anchor, tenant-local snapshot"
related_files: "docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00039-billing-contract-subscription-amendments.md`, `docs/delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md`, `docs/delivery/plans/implementation_plans/backend/IP-BE-13.2.1-billing-contract-subscription-amendments.md`, `docs/delivery/plans/implementation_plans/frontend/IP-FE-13.2.1-billing-contract-subscription-amendments.md`, `docs/adrs/ADR-0027-catalogo-global-faturamento-local.md`, `docs/adrs/ADR-0032-adocao-versionada-grandfathering-entitlements.md`, `docs/adrs/ADR-0034-efeitos-transicao-nao-destrutiva-entitlements.md`, `docs/adrs/ADR-0038-pricing-tipado-moeda-cadencia.md`, `docs/adrs/ADR-0042-capacidade-redemption-promocional-concorrente.md`, `docs/adrs/ADR-0043-governanca-lifecycle-promocional.md"
code_references: "AS-IS em `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/` e `frontend/src/`; aggregates, policies, ports, stores e contratos desta ADR são destinos planejados e ainda não existem."
principal_statement: "O contrato tenant-local é uma timeline imutável de revisões effective-dated; o primeiro slice usa um payer por tenant, ativação tipada, contrato mensal evergreen por default, trial e pause desligados sem policy explícita, upgrade time-weighted imediato, downgrade/cancelamento por default no próximo período e nenhuma mutação retroativa de período ou invoice fechados."
---

# ADR-0044 - Lifecycle contratual, proration e assinaturas

- Document ID: `ADR-0044`
- Primary Nature: `Decisao`
- Objective: Fechar `D-05` definindo estados, boundaries temporais, ativação, trial, renovação, amendment, proration, pause, cancelamento e reativação do contrato SaaS sem transferir autoridade ao provider.
- Scope: Quote aceita, order, `CommercialAgreement`, `Subscription`, revisões, service period, billing anchor, trial, activation policy, terms evergreen/fixed, renewal, amendments, proration, pause, cancellation, reactivation, backdating, payer e snapshots tenant-local.
- Non-objectives: Implementar código, DDL, OpenAPI ou UI; definir metering/rating de `D-06`, correção de invoice de `D-07`, evento financeiro por rail de `D-08`, dunning de `D-09`, refund/crédito de `D-10`, tax de `D-11`, accounting de `D-12`, RBAC concreto de `D-13`, rollout de `D-14` ou evidência externa.
- Keywords: subscription lifecycle, commercial agreement, amendment, proration, trial, activation, renewal, pause, cancellation, billing anchor, tenant-local snapshot
- Related Files: `docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00039-billing-contract-subscription-amendments.md`, `docs/delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md`, `docs/delivery/plans/implementation_plans/backend/IP-BE-13.2.1-billing-contract-subscription-amendments.md`, `docs/delivery/plans/implementation_plans/frontend/IP-FE-13.2.1-billing-contract-subscription-amendments.md`, `docs/adrs/ADR-0027-catalogo-global-faturamento-local.md`, `docs/adrs/ADR-0032-adocao-versionada-grandfathering-entitlements.md`, `docs/adrs/ADR-0034-efeitos-transicao-nao-destrutiva-entitlements.md`, `docs/adrs/ADR-0038-pricing-tipado-moeda-cadencia.md`, `docs/adrs/ADR-0042-capacidade-redemption-promocional-concorrente.md`, `docs/adrs/ADR-0043-governanca-lifecycle-promocional.md`
- Code References: AS-IS em `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/` e `frontend/src/`; aggregates, policies, ports, stores e contratos desta ADR são destinos planejados e ainda não existem.
- Principal Decision: O contrato tenant-local é uma timeline imutável de revisões effective-dated; o primeiro slice usa um payer por tenant, ativação tipada, contrato mensal evergreen por default, trial e pause desligados sem policy explícita, upgrade time-weighted imediato, downgrade/cancelamento por default no próximo período e nenhuma mutação retroativa de período ou invoice fechados.
- Date: 2026-08-25
- Status: Accepted
- Version: 1.2
- Decision Provenance: `AI_DELEGATED`
- Decision Actor: `AI_AGENT — Codex (OpenAI)`
- Authority Basis: `OWNER_DELEGATION — AUTH-BILLING-2026-08-25-001`
- Human Review Status: `NOT_PERFORMED`
- Reviewability: `OPEN`
- Authors: Codex (Artificial Intelligence), sob autoridade delegada
- Owners: Billing / Produto / Financeiro / Arquitetura
- Reviewers: AI — análise de arquitetura, domínio, segurança e custo; Human — N/A, nenhuma revisão substantiva desta decisão foi realizada
- Stakeholders: Proprietário do SaaS, tenants contratantes, Billing, Financeiro, Suporte, Backend, Frontend, Segurança e Operações
- Supersedes: N/A; especializa ADR-0032, ADR-0034 e ADR-0038 sem alterar seus invariantes.
- Superseded by: N/A

---

# 0. Decision Provenance

| Field | Value |
| --- | --- |
| Normative status | `Accepted` |
| Decision provenance | `AI_DELEGATED` |
| Decision actor | `AI_AGENT — Codex (OpenAI)` |
| Authority holder | Solicitante, declarado proprietário do SaaS; identidade não verificada criptograficamente pelo repositório |
| Authority grant | `AUTH-BILLING-2026-08-25-001`, registrada no TP-00013 |
| Authority scope | Escolher e materializar decisões documentais restantes de Billing a partir de `D-04.4-E` |
| Human substantive review | `NOT_PERFORMED` |
| Reviewability | `OPEN`; revisão humana pode ratificar, emendar ou superseder sem apagar a origem IA |
| Excluded attestations | Dados legais/fiscais, merchant ASAAS, PCI, Sandbox, SLO medido, produção, parecer jurídico/contábil e implementação |

`Accepted` indica vigência normativa sob a autoridade delegada; não representa
aprovação humana desta escolha. O histórico `AI_DELEGATED` é imutável mesmo se uma
revisão humana posterior ratificar a decisão.

---

# 1. Context

Os ADRs anteriores fecharam catálogo, versões, preço, entitlements e promoções,
mas não definiram como uma intenção comercial se torna contrato ativo, como o
calendário é ancorado ou como alterações afetam serviço e cobrança. Defaults
implícitos nessa área criariam retroatividade, cobranças duplicadas e divergência
entre contrato, provider e entitlement.

O projeto é pré-produção, usa database-per-tenant e tem custo inicial limitado a
um monólito modular em VPS. A solução deve maximizar flexibilidade por policies e
revisões tipadas, sem workflow engine, microserviço, calendário arbitrário ou
provider como autoridade.

---

# 2. Decision Statement

## 2.1 Autoridades e eixos independentes

O banco dedicado do tenant contém a autoridade de `CommercialAgreement`,
`Subscription`, revisões, schedules, snapshots e outbox. Catálogo/policies
publicados permanecem no store da plataforma e são pinados por identidade, versão,
schema e hash antes do commit tenant-local. Não há XA, FK ou join cross-store.

Os eixos abaixo nunca são fundidos:

| Eixo | Estados canônicos mínimos |
| --- | --- |
| Quote/order | `DRAFT`, `OFFERED`, `ACCEPTED`, `EXPIRED`, `REJECTED`, `SUPERSEDED` |
| Agreement | `PENDING_ACTIVATION`, `ACTIVE`, `PAUSE_SCHEDULED`, `PAUSED`, `CANCEL_SCHEDULED`, `CANCELED`, `EXPIRED` |
| Collection | `NOT_DUE`, `OPEN`, `PAST_DUE`, `PAID`, `DISPUTED`, `WRITTEN_OFF` |
| Entitlement | Estados dos ADR-0030/ADR-0034, derivados do snapshot contratual |
| Provider projection | Estado externo observado; nunca altera contrato por conta própria |

Toda mudança comercial cria `AgreementRevision` imutável com predecessor, reason,
actor, accepted terms, effective boundary, versões/hash e idempotency fingerprint.
Não há overwrite da revisão vigente, `latest` como autoridade ou edição retroativa.

## 2.2 Modelo temporal

- Instantes autoritativos são armazenados em UTC.
- Calendário comercial usa `BillingCalendarPolicyVersion` com timezone IANA
  explícito resolvido pelo seller/contrato; não se infere timezone da máquina,
  sessão, tenant, endereço ainda não comprovado ou locale do browser.
- Intervalos são semiabertos `[start, end)`.
- O anchor mensal preserva o dia contratado; para mês sem esse dia usa o último
  dia, sem drift dos anchors seguintes.
- Datas locais ambíguas/inexistentes por timezone falham na publicação/simulação;
  não há coerção silenciosa.
- `effectiveAt`, `servicePeriod`, `billingPeriod`, `dueAt` e `acceptedAt` são campos
  distintos.

## 2.3 Termos e renovação

Modos fechados:

| Term mode | Semântica |
| --- | --- |
| `EVERGREEN` | Renova por períodos sucessivos até cancelamento válido. |
| `FIXED_TERM_AUTO_RENEW` | Prazo fixo, com renovação automática e notice versionado. |
| `FIXED_TERM_MANUAL_RENEW` | Expira sem termo novo previamente aceito. |
| `ONE_TIME` | Um período/obrigação, sem renovação. |

O primeiro slice usa `EVERGREEN` mensal por default. Oferta anual pode usar
`FIXED_TERM_AUTO_RENEW` com notice mínimo de 30 dias. Renovação nunca adota preço,
entitlement ou promoção `latest`: aplica somente revisão/termo previamente aceito
conforme ADR-0032. Ausência de termo futuro válido mantém a revisão pinned quando
contratualmente permitido ou expira; nunca faz repricing implícito.

Base recorrente usa `IN_ADVANCE`; uso confirmado usa `IN_ARREARS`; um preço
`HYBRID` conserva componentes e períodos separados. Quote vinculável expira em
sete dias corridos ou antes se qualquer versão/hash/boundary material perder
validade. Nova expiração exige nova quote, não extensão silenciosa.

## 2.4 Activation policies

Cada oferta seleciona exatamente um modo:

| Mode | Evento suficiente |
| --- | --- |
| `PAYMENT_EFFECTIVE` | Fato normalizado e reconciliado definido pelo ADR-0023. Default self-service pago. |
| `AGREEMENT_EFFECTIVE` | Aceite íntegro + chegada de `effectiveAt`; permitido para trial e termos faturados aprovados. |
| `MANUAL_APPROVED` | Ato financeiro/comercial com approval/alçada do ADR-0050, evidence e effectiveAt. |

Redirect, callback, criação de cobrança, status de assinatura externa ou consulta
ambígua nunca ativam. O commit materializa revisão/snapshot/outbox tenant-local;
o entitlement aplica a mesma geração de forma idempotente. Ativação parcial entre
revisão e snapshot falha fechada e é reconciliada.

## 2.5 Trial

- Trial é `TrialPolicyVersion`, não boolean ou número em código, e fica `OFF` por
  default no primeiro slice.
- Quando explicitamente publicado, o perfil recomendado usa 14 dias corridos,
  limite estrutural de zero a 30 dias e no máximo um trial por tenant + product
  lineage.
- Usa `AGREEMENT_EFFECTIVE`, quotas/grants próprios e zero overage pago.
- Não exige cartão; exigir payment mandate é flag comercial explícita.
- Não converte automaticamente em obrigação paga sem termo aceito e activation
  policy satisfeita.
- No fim, converte com nova revisão ou entra em `EXPIRED`; não continua serviço por
  grace implícito.

## 2.6 Amendments e classificação

Todo amendment é simulado e classificado integralmente antes do aceite:

- `UPGRADE`;
- `DOWNGRADE`;
- `LATERAL`;
- `ADD_ON_ADD` / `ADD_ON_REMOVE`;
- `PAYER_OR_TERMS_CHANGE`;
- `CANCELLATION` / `REACTIVATION`.

Uma revisão não mistura classes incompatíveis sem quote explícita. Mudança em
total, moeda, período, versions/hashes, entitlement, promoção, due terms ou texto
material invalida o aceite; a tolerância financeira é zero minor units. Campos
exclusivamente visuais podem mudar sem alterar o hash contratual quando o schema os
classificar assim.

## 2.7 Proration fechada e reproduzível

Perfis permitidos:

| Profile | Semântica |
| --- | --- |
| `NO_PRORATION` | Mudança vale no próximo boundary; nenhum ajuste corrente. |
| `FULL_PERIOD` | Cobra/concede o período inteiro explicitamente. |
| `TIME_WEIGHTED_SECONDS` | Proporção por segundos exatos do service period semiaberto. |
| `NEXT_PERIOD_ONLY` | Agenda a revisão sem alterar o período corrente. |

Defaults iniciais:

- upgrade/add-on: `TIME_WEIGHTED_SECONDS`, efetivo imediatamente após aceite;
- downgrade/remoção: `NEXT_PERIOD_ONLY`, preservando capacity debt do ADR-0034;
- cancelamento comum: fim do período pago, sem refund automático;
- correção excepcional imediata: cálculo explícito e memo/credit conforme
  ADRs-0046/0047, nunca mutação da invoice fechada.

O cálculo usa valor decimal exato, `RoundingPolicyVersion`, base de preço pinned e
segundos do período; rounding ocorre no boundary monetário e residual é alocado
deterministicamente. O frontend/provider não calcula. Proration produz linhas
explicáveis separadas e nunca usa dia civil aproximado, `float` ou valor vivo.
O ajuste é lançado na próxima invoice aberta por default; cobrança off-cycle exige
policy e intenção próprias e nunca é inferida de um amendment.

## 2.8 Pause

Modos fechados:

| Pause mode | Serviço | Accrual/renewal | Uso histórico |
| --- | --- | --- | --- |
| `SERVICE_ONLY` | Suspende novas admissões | Continua conforme termo | Preservado |
| `SERVICE_AND_BILLING_AT_BOUNDARY` | Suspende no próximo boundary | Interrompe períodos futuros | Preservado |
| `IMMEDIATE_SERVICE_AND_ACCRUAL` | Suspende no effectiveAt | Ajuste explícito por proration | Preservado |

Pause sempre possui reason, início, fim ou max duration e resume policy. A
capability self-service fica `OFF` no primeiro slice até existir termo explícito;
quando habilitada, o default é `SERVICE_AND_BILLING_AT_BOUNDARY` e a duração
inicial máxima é 90 dias.
Pause por risco/inadimplência não usa esta state machine comercial: segue o
ADR-0025.
Nenhuma modalidade apaga dados, uso, invoice, capacidade consumida ou mandato.

## 2.9 Cancellation e reactivation

O default é `CANCEL_AT_PERIOD_END`: agenda cancelamento no fim do período já pago,
sem multa, refund ou credit implícito. `CANCEL_IMMEDIATE` exige reason e policy;
qualquer valor não utilizado vira cálculo candidato do ADR-0047, não devolução
automática.

Penalidade e waiver são zero/desabilitados no primeiro slice. Habilitação futura
exige `CancellationPolicyVersion`, base legal/comercial, preview e alçada.

Antes do effectiveAt, cancelamento agendado pode ser revogado por nova revisão
idempotente. Depois de `CANCELED`, retomada cria novo agreement/revision lineage e
reavalia preço, eligibility, capacity e activation; não reabre registro antigo.
Cancelamento local bloqueia novas intenções de cobrança e cria command externo
separado, mas timeout do provider não restaura contrato.

## 2.10 Backdating e períodos fechados

Backdating só é admitido quando:

1. effectiveAt pertence a período comercial ainda aberto;
2. nenhuma invoice finalizada ou tax document cobre o intervalo afetado;
3. todos os fatos podem ser rerated deterministicamente;
4. approval/alçada e reason do ADR-0050 são satisfeitos.

Caso contrário, a mudança é prospectiva e diferenças usam correction/credit/debit
memo. Período ou invoice fechados nunca são reescritos.

## 2.11 Payer boundary

O primeiro horizonte preserva exatamente um seller GV Software, um billing
account principal e um payer principal por tenant. Shared payer, consolidated
billing, cross-tenant account, split, marketplace, reseller e white-label ficam
fora do slice e exigem decisão sucessora. Cliente contábil do tenant nunca é payer.

## 2.12 Idempotência, concorrência e saga

- Todo command tem key + canonical fingerprint; reuse divergente falha.
- Expected revision/generation usa optimistic concurrency/CAS.
- Quote stale, policy/hash alterado ou capacity indisponível reabre a intenção;
  não aplica subconjunto.
- Leitura platform ocorre antes do commit local; a revisão tenant-local é uma
  transação com snapshots, marker e outbox.
- Efeitos externos/entre módulos são sagas idempotentes e compensatórias, sem XA.
- Commit ambíguo é resolvido por releitura da authority tenant-local, nunca retry
  com nova identidade.

## 2.13 Clean Architecture e custo

Lifecycle/calendário/proration são domínio puro dentro de `contexts.billing`, sem
Spring, JPA, relógio global, provider ou frontend. Application recebe `Clock`,
policies e stores por ports. PostgreSQL tenant-local é autoridade; Redis, se usado,
é apenas projeção. Um scheduler coordenador processa um tenant/conta por unidade,
sem novo serviço, Kafka ou workflow engine.

## 2.14 Boundary da aprovação

`D-05` fica fechado conceitualmente. `D-06` a `D-14` foram igualmente fechados
nos ADRs canônicos por Codex sob `AUTH-BILLING-2026-08-25-001`, com provenance
`AI_DELEGATED`, revisão humana `NOT_PERFORMED` e `Reviewability: OPEN`. Permanecem
evidências/contratos executáveis: OpenAPI/DDL/UI, termos jurídicos reais,
identidade legal, valores publicados, merchant/capabilities/tarifas ASAAS, PCI,
Sandbox, SLO/backup e aceite de piloto. `D-00 = RELEASED_WITH_SCOPE —
HUMAN_EXPLICIT — TP-00013 local-only` permite implementação e testes herméticos
locais, mas não chamada externa, Sandbox, piloto, produção, flag `ON` ou efeito real.

---

# 3. Decision Drivers

- replay determinístico e ausência de retroatividade;
- flexibilidade por policies fechadas e versionadas;
- separação de contrato, collection, entitlement e provider;
- precisão temporal/monetária com custo compatível com VPS;
- database-per-tenant sem transação distribuída;
- segurança contra stale quote, dupla ativação e dupla cobrança;
- caminho futuro para novos termos sem reescrever fatos históricos.

---

# 4. Considered Options

## Option A - Timeline tenant-local versionada e policies fechadas

Pros: forte auditabilidade, flexível, provider-neutral, modular e barato de operar.

Cons: exige snapshots ricos, simulação e compensações explícitas.

## Option B - Provider gerencia assinatura e proration

Rejected: transfere autoridade, não representa usage/promoções locais e aumenta
lock-in/divergência.

## Option C - Estado mutável e regras ad hoc

Rejected: impede replay, mistura eixos e cria retroatividade silenciosa.

---

# 5. Decision Outcome

A **Option A** foi escolhida autonomamente pela IA sob a delegação registrada. O
custo operacional permanece concentrado no monólito/PostgreSQL existente; a
complexidade inevitável fica no modelo explícito, não em serviços distribuídos.

---

# 6. Consequences

## Positive Consequences

- Alterações e proration são reproduzíveis e explicáveis.
- Provider não controla contrato nem entitlement.
- Upgrade e downgrade possuem defaults comerciais distintos e seguros.
- Cancelamento não apaga história nem cria refund implícito.
- Timeline permite auditoria, replay e evolução futura.

## Negative Consequences

- Mais revisões, snapshots e reason codes precisam ser persistidos.
- Immediate changes exigem cálculo e compensação robustos.
- Shared payer/consolidation ficam adiados.

## Neutral Consequences

- Valores/policies reais são dados publicados, não constantes da ADR.
- Evidência legal e financeira permanece necessária antes do rollout.

---

# 7. Impact

- Backend: novos aggregates/policies/ports planejados no slice Billing.
- Frontend: preview/aceite server-authoritative, sem proration local.
- Database: revisões/snapshots/schedules tenant-local em migration futura.
- Security: scope guard, idempotência, CAS, redaction e approvals.
- Finance: proration pre-tax; tax/refund/accounting seguem gates próprios.
- Provider: recebe intents após autoridade local; nunca recalcula contrato.

---

# 8. AI Agent Considerations

Agentes devem preservar provenance `AI_DELEGATED`, nunca atribuir revisão humana
inexistente, manter períodos semiabertos e eixos separados, usar policies/versions
exatas, impedir backdating em período fechado e não implementar antes do gate.

---

# 9. Implementation Plan Boundary

1. congelar schemas/reason codes e OpenAPI;
2. modelar value objects/policies e golden vectors;
3. criar stores tenant-local e migrations aditivas;
4. implementar quote/accept/amendment/proration puros;
5. integrar snapshots/entitlements/promotion reservation;
6. integrar activation/provider por outbox e saga;
7. implementar frontend por contrato real;
8. executar suites temporal, concorrência, tenancy e rollback;
9. pilotar somente após materializar ADRs-0050/0051 e reunir suas evidências.

A sequência hermética local pode avançar sob a liberação escopada de `D-00`; cada
efeito externo, Sandbox, piloto e rollout continua dependente do gate próprio.

---

# 10. Validation

- golden vectors cobrem anchors, month-end, leap year e DST;
- property tests cobrem intervalos semiabertos e proration/residual;
- concorrência cobre aceite duplo, quote stale e commit ambíguo;
- upgrade/downgrade/pause/cancel/backdating respeitam defaults;
- período/invoice fechados nunca são mutados;
- tenant A não observa ou conflita com tenant B;
- provider/frontend não calculam ou ativam;
- replay da mesma revisão produz mesmos hashes e outputs;
- docs e índices passam no validador.

Testes executáveis não foram criados porque esta mudança é documental.

---

# 11. Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| Proration divergir por timezone | UTC + timezone IANA + golden vectors. |
| Quote aceita mudar antes do commit | Hash/fingerprint/revalidation fail-closed. |
| Provider ativar indevidamente | Activation somente por fato interno tipado. |
| Downgrade destruir capacidade/dados | Próximo período + ADR-0034. |
| Cancelamento duplicar refund | Sem refund implícito; ADR-0047 idempotente. |
| Backdating reescrever faturamento | Somente período aberto; depois, memo. |
| Saga parcial | Outbox, CAS, releitura e compensação. |
| Custo de workflow distribuído | Monólito modular + PostgreSQL, sem engine. |

---

# 12. Related ADRs

- [ADR-0000 - Governança documental](../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md)
- [ADR-0019 - Database-per-tenant](ADR-0019-database-per-tenant.md)
- [ADR-0023 - Provider-neutral payments](ADR-0023-agnostic-payment-provider-integration.md)
- [ADR-0027 - Catálogo global e faturamento local](ADR-0027-catalogo-global-faturamento-local.md)
- [ADR-0032 - Adoção e grandfathering](ADR-0032-adocao-versionada-grandfathering-entitlements.md)
- [ADR-0034 - Efeitos não destrutivos](ADR-0034-efeitos-transicao-nao-destrutiva-entitlements.md)
- [ADR-0038 - Pricing tipado](ADR-0038-pricing-tipado-moeda-cadencia.md)
- [ADR-0042 - Capacidade promocional](ADR-0042-capacidade-redemption-promocional-concorrente.md)
- [ADR-0043 - Governança promocional](ADR-0043-governanca-lifecycle-promocional.md)
- [ADR-0045 - Metering, rating e fechamento](ADR-0045-metering-rating-fechamento-fatura.md)
- [ADR-0046 - Correção, cancelamento e reemissão](ADR-0046-correcao-cancelamento-reemissao-fatura.md)
- [ADR-0047 - Ledger, créditos e refunds](ADR-0047-ledger-creditos-refunds-disputas-writeoff.md)
- [ADR-0048 - Fatura comercial e NFS-e](ADR-0048-separacao-fatura-comercial-documento-fiscal-nfse.md)
- [ADR-0049 - Subledger tenant-local e MRR](ADR-0049-subledger-tenant-local-mrr-normalizado.md)
- [ADR-0050 - RBAC, SoD e aprovações](ADR-0050-rbac-sod-aprovacoes-financeiras.md)
- [ADR-0051 - SLO, capacidade e rollout](ADR-0051-slo-capacidade-rollout-billing.md)

---

# 13. References

- [REQ-00042](../product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md)
- [UC-00039](../product/use-cases/UC-00039-billing-contract-subscription-amendments.md)
- [TP-00013](../delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md)
- [Module Registry](../architecture/module-registry.md)

---

# 14. Decision Lifecycle

Current State: **Accepted — AI_DELEGATED**.

Ratificação humana futura atualiza `Human Review Status`, mas não apaga a origem.
Mudança em state machines, temporal model, proration profiles, activation, payer
boundary ou retroatividade exige nova versão aceita ou ADR sucessor.

Os sucessores de `D-06` a `D-14` estão aceitos com a mesma proveniência delegada;
isso não satisfaz os evidence gates. A liberação humana de `D-00` vale somente
para implementação local dos planos TP-00013.

---

# 15. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.2 | 2026-08-25 | Solicitante humano, proprietário declarado / Codex (IA), materialização | Registra `D-00 = RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`; libera implementação/testes herméticos locais e mantém chamadas externas, Sandbox ASAAS, piloto BP Farias, produção, flags `ON` e efeitos reais bloqueados pelos respectivos evidence gates. |
| 1.1 | 2026-08-25 | Codex (IA), sob `AUTH-BILLING-2026-08-25-001` | Reconcilia `D-06`–`D-14` como decisões aceitas `AI_DELEGATED`, revisão humana `NOT_PERFORMED`/`OPEN`; mantém artifacts/evidências externos pendentes e `D-00` ativo. |
| 1.0 | 2026-08-25 | Codex (IA), sob `AUTH-BILLING-2026-08-25-001` | Fecha autonomamente `D-05` com timeline tenant-local, estados/eixos, calendário, term/renewal, activation, trial, amendment, proration, pause, cancellation, backdating, payer boundary e saga idempotente; revisão humana substantiva não realizada. |

---

# 16. Repository Structure

Este ADR cria somente documentação. Alvos futuros permanecem dentro de
`contexts.billing`, com adapters platform/tenant e migration track já governados.

---

# 17. Review Process

Revisão humana permanece aberta. Ratificação deve registrar data/ator e manter a
provenance. Alteração material usa nova versão/ADR, nunca reescrita silenciosa.

---

# 18. Notes

Contrato decide o que foi vendido e quando; metering decide o que foi usado;
provider decide apenas fatos externos de cobrança. Esses três relógios precisam
ser conciliados, nunca fundidos.
