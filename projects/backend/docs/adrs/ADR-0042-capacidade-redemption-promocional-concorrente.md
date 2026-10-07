---
document_id: "ADR-0042"
primary_nature: "Decisao"
objective: "Definir uma autoridade transacional, idempotente e auditável para reservar, consumir, liberar, expirar, reconciliar e reverter capacidade promocional stateful sob concorrência, inclusive quando cada tenant possui banco dedicado."
scope: "`PromotionRedemptionPolicyVersion`, `CapacityLimitVersion`, `PromotionCapacityLedger`, demandas stateful derivadas da combinação, limites globais/tenant/account/coupon, reserva atômica, fencing, idempotência, saga platform/tenant sem XA, aplicação tenant-local, consumo, liberação, expiração, reversão, quarentena, recombinação bounded e placement dentro de `contexts.billing`."
non_objectives: "Implementar código, DDL, migration, package, endpoint, OpenAPI, tela, job, evento, cache ou policy real; definir valores de budget, TTL, limites operacionais ou campanha; redefinir eligibility, stacking ou waterfall stateless; definir lifecycle operacional e alçadas promocionais; definir refund, crédito, tax, accounting, funding settlement, cobrança, provider ou ASAAS."
owner: "Arquitetura / Billing / Produto / Financeiro / Segurança"
status: "Accepted"
date: "2026-08-25"
version: "1.2"
keywords: "promotion capacity, redemption, atomic reservation, capacity ledger, database per tenant, fencing, idempotent saga, quarantine, bounded recombination, compensating reversal"
related_files: "README.md, ../../../docs/specs/TP-00013-enterprise-billing-implementation-task-plan.md, ADR-0019-database-per-tenant.md, ADR-0023-agnostic-payment-provider-integration.md, ADR-0027-catalogo-global-faturamento-local.md, ADR-0037-boundary-fisico-entitlements-billing.md, ADR-0038-pricing-tipado-moeda-cadencia.md, ADR-0039-taxonomia-beneficios-promocionais.md, ADR-0040-elegibilidade-promocional-seguranca-cupons.md, ADR-0041-stacking-waterfall-promocional-deterministico.md"
code_references: "AS-IS em `app/src/main/java/br/com/duoset/saas_service/contexts/billing/package-info.java`, `app/src/main/java/br/com/duoset/saas_service/contexts/billing/BillingApi.java` e `app/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/`; policies, ledger, reservation, redemption, application marker, ports, adapters, stores e contratos desta ADR são destinos planejados e ainda não existem."
principal_statement: "Toda capacidade promocional mutável é autoridade seller-owned no PostgreSQL da plataforma, dentro de `contexts.billing`. O subconjunto stateful selecionado pela combinação é reservado integralmente em uma única transação, aplicado no banco do tenant por saga idempotente sem XA e protegido por CAS, fencing, journal append-only e quarentena fail-safe; Redis, frontend, provider e bancos isolados dos tenants não são autoridade de budget global."
---

# ADR-0042 - Capacidade e redemption promocional concorrente

- Document ID: `ADR-0042`
- Primary Nature: `Decisao`
- Objective: Definir uma autoridade transacional, idempotente e auditável para reservar, consumir, liberar, expirar, reconciliar e reverter capacidade promocional stateful sob concorrência, inclusive quando cada tenant possui banco dedicado.
- Scope: `PromotionRedemptionPolicyVersion`, `CapacityLimitVersion`, `PromotionCapacityLedger`, demandas stateful derivadas da combinação, limites globais/tenant/account/coupon, reserva atômica, fencing, idempotência, saga platform/tenant sem XA, aplicação tenant-local, consumo, liberação, expiração, reversão, quarentena, recombinação bounded e placement dentro de `contexts.billing`.
- Non-objectives: Implementar código, DDL, migration, package, endpoint, OpenAPI, tela, job, evento, cache ou policy real; definir valores de budget, TTL, limites operacionais ou campanha; redefinir eligibility, stacking ou waterfall stateless; definir lifecycle operacional e alçadas promocionais; definir refund, crédito, tax, accounting, funding settlement, cobrança, provider ou ASAAS.
- Keywords: promotion capacity, redemption, atomic reservation, capacity ledger, database per tenant, fencing, idempotent saga, quarantine, bounded recombination, compensating reversal
- Related Files: `docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00038-billing-catalog-pricing-promotions.md`, `docs/product/use-cases/UC-00039-billing-contract-subscription-amendments.md`, `docs/product/use-cases/UC-00040-billing-usage-rating-invoice-close.md`, `../../../docs/specs/TP-00013-enterprise-billing-implementation-task-plan.md`, `harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md`, `ADR-0019-database-per-tenant.md`, `ADR-0023-agnostic-payment-provider-integration.md`, `ADR-0027-catalogo-global-faturamento-local.md`, `ADR-0037-boundary-fisico-entitlements-billing.md`, `ADR-0038-pricing-tipado-moeda-cadencia.md`, `ADR-0039-taxonomia-beneficios-promocionais.md`, `ADR-0040-elegibilidade-promocional-seguranca-cupons.md`, `ADR-0041-stacking-waterfall-promocional-deterministico.md`
- Code References: AS-IS em `app/src/main/java/br/com/duoset/saas_service/contexts/billing/package-info.java`, `app/src/main/java/br/com/duoset/saas_service/contexts/billing/BillingApi.java` e `app/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/`; policies, ledger, reservation, redemption, application marker, ports, adapters, stores e contratos desta ADR são destinos planejados e ainda não existem.
- Principal Decision: Toda capacidade promocional mutável é autoridade seller-owned no PostgreSQL da plataforma, dentro de `contexts.billing`. O subconjunto stateful selecionado pela combinação é reservado integralmente em uma única transação, aplicado no banco do tenant por saga idempotente sem XA e protegido por CAS, fencing, journal append-only e quarentena fail-safe; Redis, frontend, provider e bancos isolados dos tenants não são autoridade de budget global.
- Date: 2026-08-25
- Status: Accepted
- Version: 1.2
- Authors / Owners: Arquitetura / Billing / Produto / Financeiro / Segurança
- Reviewers: Solicitante humano e proprietário declarado do SaaS, com aprovação explícita de `D-04.4-D — Opção A` em 2026-08-25; Arquitetura; Financeiro; Segurança
- Stakeholders: Produto, Comercial, Financeiro, Backend, Frontend, Segurança, Controladoria, Operações e tenants contratantes
- Decision Provenance: `HUMAN_EXPLICIT`
- Decision Actor: Solicitante humano, proprietário declarado do SaaS
- Human Review: `DIRECT_DECISION` - aprovação humana direta registrada pela mensagem `D-04.4-D — Opção A aprovada` em 2026-08-25
- Current-State Reconciliation: `AI_DELEGATED` por Codex (IA) sob `AUTH-BILLING-2026-08-25-001`; revisão humana desta reconciliação `NOT_PERFORMED`, `Reviewability: OPEN`; não altera a origem humana de `D-04.4-D`
- Supersedes: N/A; especializa a autoridade stateful deixada aberta pelos ADR-0039, ADR-0040 e ADR-0041, sem alterar taxonomia, eligibility ou combinação stateless.
- Superseded by: N/A

---

# 1. Context

O ADR-0039 separa benefícios promocionais de crédito; o ADR-0040 decide
eligibility e protege cupons; e o ADR-0041 produz uma combinação determinística
com caps exclusivamente stateless. Ainda faltava responder se o conjunto
selecionado continua disponível quando múltiplas requisições concorrem por um
budget ou contador mutável e como preservar essa garantia até o aceite local.

Cada tenant possui banco dedicado. Um contador gravado somente nesses bancos não
consegue impor atomicamente um limite de campanha compartilhado por todos os
tenants. Dividir o mesmo reservation set entre control plane e bancos locais
também impediria uma decisão all-or-nothing sem XA e ampliaria o risco de
over-redemption, double spend, deadlock distribuído e compensação ambígua.

O sistema ainda não entrou em produção. A infraestrutura inicial favorece um
PostgreSQL da plataforma já pertencente ao control plane e um monólito modular,
não um novo microserviço, cluster de locks ou autoridade Redis. A decisão fecha o
modelo lógico, as garantias de concorrência e o protocolo de consistência; ela
não afirma que tabelas, classes, jobs, endpoints ou policies já existam.

`D-00 = RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only` permite
implementação/testes herméticos locais e mantém toda capacidade/efeito real
congelado. Lifecycle segue ADR-0043; RBAC/SoD/alçadas seguem ADR-0050.

---

# 2. Decision Statement

## 2.1 Autoridade seller-owned e placement central

Toda capacidade promocional mutável pertence à GV Software e tem como autoridade
um store PostgreSQL da plataforma, no control plane `saas_platform`, sob ownership
do bounded context `contexts.billing`. Essa autoridade abrange budget, counters,
reservations, redemptions, releases, expirations, reversals e quarentenas.

O store central existe para tornar uma solicitação composta atomicamente decidível
mesmo quando seus limites cruzam tenants. Ele não transforma o control plane em
banco de faturas nem move fatos comerciais aceitos para fora do tenant:

| Artefato | Autoridade planejada | Invariante |
| --- | --- | --- |
| `PromotionRedemptionPolicyVersion` e `CapacityLimitVersion` publicados | PostgreSQL da plataforma | Seller-owned, versionados, effective-dated e materialmente imutáveis. |
| `PromotionCapacityLedger`, reservation e redemption journal | PostgreSQL da plataforma | Única autoridade concorrente de capacidade; transições append-only e projeções protegidas. |
| `AcceptedPromotionCombinationSnapshot`, contrato/order e invoice | Banco dedicado do tenant | Fatos comerciais tenant-local, vinculados às refs/hashes exatas. |
| `PromotionApplicationMarker` | Banco dedicado do tenant | Evidência idempotente de preparação, aplicação ou aborto da mesma saga. |
| Cache | Derivado e descartável | Nunca autoriza reserva, consumo, liberação ou saldo. |

Não há FK, join, transaction manager ou dual-write atômico entre platform store e
tenant store. A consistência entre ambos é responsabilidade da saga definida
nesta ADR.

## 2.2 Policies versionadas, limites e dimensões fechadas

Uma `PromotionRedemptionPolicyVersion` publicada liga explicitamente cada
`PromotionVersion` stateful às versões exatas de seus limites. Publicação é
seller-owned, effective-dated e materialmente imutável. Alterar scope, dimensão,
janela, quantidade, unidade, regra de reversão, extensão ou binding cria nova
versão; não existe `latest`, default implícito ou edição retroativa.

Cada `CapacityLimitVersion` declara exatamente um scope fechado:

- `CAMPAIGN_GLOBAL`: compartilhado por toda a campanha;
- `TENANT`: isolado pelo identificador opaco do tenant;
- `BILLING_ACCOUNT`: isolado pelo identificador opaco da conta de cobrança;
- `COUPON_BATCH`: compartilhado por um lote opaco de artefatos;
- `COUPON_ARTIFACT`: exclusivo do artefato de cupom já resolvido pelo ADR-0040.

E exatamente uma dimensão tipada:

- `REDEMPTION_COUNT`;
- `MONETARY_BENEFIT_MINOR_UNITS`, com moeda explícita e inicialmente somente BRL;
- `BENEFIT_QUANTITY`, com target, unidade e semântica tipados.

`BENEFIT_QUANTITY` não autoriza inferir billability, calendário ou valuation.
Quantidade gratuita e período gratuito só podem consumir essa dimensão conforme
as semânticas aceitas nos ADRs-0044 e 0045 e após seus gates executáveis.

As janelas permitidas são `LIFETIME`, `FIXED_WINDOW` semiaberta `[start, end)` e
`CALENDAR_BUCKET` versionado. Rolling window arbitrária, consulta ad hoc,
timezone ausente ou bucket implícito são proibidos. Limites numéricos, duração,
bounds e parâmetros operacionais reais devem obedecer ao ADR-0051 e à publicação
governada do ADR-0043; esta ADR não escolhe valores comerciais nem atesta medição.

## 2.3 Demanda stateful e atomicidade do conjunto

Após B reavaliar eligibility e C recombinar, a etapa D deriva um
`PromotionCapacityRequest` canônico contendo somente o subconjunto stateful das
promoções selecionadas. Benefício puramente stateless permanece no resultado de
C e não recebe reservation fictícia.

Cada item da demanda fixa, no mínimo, referências e hashes da promoção, policy e
limites, scope keys opacas, dimensão/unidade/moeda, janela, quantidade solicitada,
`resultHash`, intent/revision e finalidade. A derivação é determinística; cliente,
frontend e provider não podem escolher ou omitir limites.

Todos os limites aplicáveis a todos os itens devem passar na mesma transação do
PostgreSQL da plataforma. A operação possui somente dois resultados de negócio:

- reservation set completo, com evidência íntegra de todos os itens; ou
- nenhuma mutação de capacidade, com referências internas exatas e confiáveis
  das candidatas indisponíveis.

Partial success, best effort, drop silencioso, reservation de somente parte de
uma `PromotionVersion`, substituição local ou continuação sem um limite aplicável
são proibidos. O pacote selecionado por C permanece indivisível; D apenas
identifica e reserva seu subconjunto que demanda estado concorrente.

## 2.4 Estado de reservation e redemption

O lifecycle fechado usa estes estados autoritativos:

| Estado | Semântica |
| --- | --- |
| `RESERVED` | Toda capacidade foi debitada provisoriamente e possui deadline/fence; ainda não existe aceite tenant-local confirmado. |
| `COMMIT_GRANTED` | A plataforma preserva o débito e emitiu uma attestation íntegra, vinculada à mesma saga, autorizando a tentativa de commit tenant-local. |
| `CONSUMED` | A aplicação tenant-local foi comprovada e o redemption tornou-se consumido. |
| `RELEASED` | Reservation não consumida foi liberada por compensação confirmada. |
| `EXPIRED` | Reservation ainda não granted expirou segundo o relógio confiável da plataforma. |
| `REVERSED` | Redemption consumido recebeu registro compensatório explícito conforme policy. |
| `QUARANTINED` | Resultado remoto ou ownership está ambíguo; a capacidade permanece indisponível até reconciliação segura. |

O fluxo nominal é:

```text
RESERVED -> COMMIT_GRANTED -> CONSUMED
```

Uma reservation não consumida pode terminar em `RELEASED`; somente `RESERVED`
sem commit grant pode expirar automaticamente. `COMMIT_GRANTED` não volta a ficar
disponível por timeout cego, pois o commit local pode ter ocorrido. Ambiguidade em
qualquer transição relevante produz `QUARANTINED`, nunca saldo presumido.

`REVERSED` não apaga `CONSUMED`. `RELEASED`, `EXPIRED`, `REVERSED` e
`QUARANTINED` são fatos auditáveis; nenhum deles autoriza reescrever o histórico.

## 2.5 Concorrência, lock ordering, CAS e fencing

A transação de reservation resolve todas as capacity keys por chave canônica e
as adquire sempre na mesma ordem total. A implementação futura deve combinar
constraints/updates condicionais do PostgreSQL, comparação de versão e locks
bounded para provar que saldo nunca fica negativo e o limite nunca é excedido.

Cada lifecycle possui version/fencing token monotônico. Todo comando de grant,
consume, release, expire, reverse ou reconcile informa estado esperado e fence
esperado. Um worker atrasado, retry fora de ordem ou mensagem duplicada não pode
agir sobre uma geração posterior. CAS que não encontra exatamente a geração e o
estado esperados não inventa sucesso: retorna o fato já existente quando
idempotente ou conflito tipado quando incompatível.

Locks de aplicação, JVM, Redis, cache, frontend ou provider não são autoridade.
Redis pode futuramente reduzir leitura ou sinalizar pressão, mas perda, eviction,
split brain ou indisponibilidade do cache não pode liberar capacidade. A ausência
do PostgreSQL autoritativo falha fechada.

## 2.6 Idempotência e resolução de resultado ambíguo

Toda mutação recebe uma idempotency key server-controlled e um fingerprint
canônico. O fingerprint cobre o seller, tenant/account opacos, intent/revision,
purpose, `resultHash`, policies/limits exatos, vetor de demandas, exclusions,
attempt ordinal e versão do canonicalizer.

- mesma key e mesmo fingerprint devolvem o mesmo resultado persistido;
- mesma key e fingerprint diferente são rejeitados como conflito;
- retry não cria nova key para contornar timeout ou resposta desconhecida;
- estado final é consultado no journal autoritativo antes de repetir uma mutação;
- attempts de recombinação têm child keys determinísticas ligadas à mesma root
  operation, sem colisão entre fingerprints diferentes.

Se a conexão falhar após o servidor poder ter confirmado uma transação, o
orquestrador relê por root operation/idempotency key. Não presume rollback, não
faz reserve novamente e não decrementa contador compensatoriamente. Se a leitura
não consegue determinar ownership seguro, a saga entra em quarentena.

## 2.7 Saga platform/tenant sem XA

A aplicação de uma combinação aceita segue uma saga idempotente:

1. B reavalia eligibility no boundary atual;
2. C combina deterministicamente e produz `PromotionCombinationResult`;
3. D reserva atomicamente a demanda stateful no platform store;
4. o tenant store cria ou reencontra um `PromotionApplicationMarker` em
   `PREPARED`, vinculado à reservation, fences e hashes exatos;
5. a plataforma faz CAS de `RESERVED` para `COMMIT_GRANTED` e emite
   `CommitGrantAttestation` íntegra;
6. uma única transação tenant-local faz CAS de `PREPARED` para `APPLIED` e grava
   snapshot aceito, contrato/order e outbox aplicáveis;
7. o consumidor idempotente do outbox comprova `APPLIED` e a plataforma faz CAS
   para `CONSUMED`.

A attestation é evidência integrity-protected vinculada a seller, tenant,
intent/revision, reservation set, result/snapshot refs, fence e boundary. Ela não
é bearer credential, não concede permissão fora do comando autenticado e não pode
ser reaproveitada por outro tenant, intent, revision ou reservation.

Antes de `APPLIED`, uma compensação confirmada faz CAS do marker `PREPARED` para
`ABORTED` e então registra `RELEASED` no platform journal. Se o tenant state está
indisponível, divergente ou ambíguo, a plataforma não libera a capacidade: marca
`QUARANTINED` e reconcilia. Isso prefere subalocação temporária a over-redemption.

Não há XA, 2PC, FK, join cross-database nem promessa de simultaneidade entre os
dois stores. O outbox e os journals tornam retries observáveis e convergentes.

## 2.8 TTL, expiração e extensão

Somente o relógio confiável da plataforma decide tempo de reservation. Timestamp
do browser, tenant, request ou provider não tem autoridade. Toda reservation fixa
`createdAt`, deadline e policy version; reservation ativa conta integralmente
contra capacidade até transição terminal autorizada.

Extensão nunca é silenciosa. Ela exige policy explícita, mesma identity/lineage,
CAS com fence atual, novo fence, deadline máximo e quantidade de extensões
bounded. Uma extensão não muda demanda, campanha, tenant, account, intent,
revision, policy ou fingerprint econômico. Valores de TTL, máximo e extensão
continuam `PENDING_EVIDENCE` até qualificação/publicação conforme ADR-0051.

Um expirer somente pode fazer CAS de `RESERVED` vencida para `EXPIRED`. Ele não
expira `COMMIT_GRANTED`, `CONSUMED` ou reservation em ownership ambíguo. Scans,
particionamento e frequência do futuro job são detalhes de implementação e SLO,
não decisões deste documento.

## 2.9 Recombinação bounded C -> D

Se D rejeitar uma reservation por capacidade concorrente, retorna internamente
uma lista exata, confiável e protegida em integridade de referências indisponíveis. Ela não
inclui saldo global, quantidade restante, identidade de outros tenants ou causa
competitiva sensível.

O orquestrador pode recombinar C com a união monotônica dessas exclusões e tentar
D novamente. O limite aprovado é:

- uma combinação/reservation inicial;
- no máximo duas recombinações adicionais;
- no máximo três attempts totais para a mesma root operation e intent/revision.

Cada attempt preserva ordem, inputs, exclusions e resultado em evidência
canônica. Antes de tentar D, o boundary de eligibility deve continuar válido; se
ficou stale, o fluxo reinicia em B sob a mesma operação governada ou termina.
Promoção excluída por uma resposta confiável de D não reaparece em attempt
posterior da mesma operação.

Ao esgotar o limite, o comando termina com indisponibilidade promocional genérica.
Loop infinito, retry irrestrito, escolha manual, nova idempotency root, redução
silenciosa do reservation set ou aceite do resultado C não reservado são
proibidos.

## 2.10 Preview e exposição de disponibilidade

Preview não reserva, não debita, não estende TTL, não cria marker e não promete
capacidade futura. Eventual indicação de disponibilidade em preview é apenas
advisory, sanitizada e não vinculante; o commit sempre executa B -> C -> D.

A resposta pública usa reason code genérico como `PROMOTION_NOT_AVAILABLE`. Ela
não expõe budget configurado, saldo, contador, lock, concorrente, coupon batch,
artefato interno, número de tenants, ritmo de consumo ou lista interna de
exclusões. Breakdown detalhado permanece restrito a auditoria autorizada e também
deve redigir dados de outros tenants.

## 2.11 Consumo, liberação e imutabilidade histórica

`CONSUMED` exige prova idempotente de `PromotionApplicationMarker.APPLIED`
vinculada exatamente ao grant, fence, tenant e hashes esperados. Mensagem do
frontend ou status do provider não prova aplicação.

`RELEASED` só é permitido para reservation não consumida e após aborto local
confirmado ou inexistência inequivocamente demonstrada pela saga. Liberação cria
evento compensatório; não apaga reservation nem decrementa uma linha histórica.

Projeções de capacidade podem manter valores correntes para concorrência, mas
devem ser deriváveis/reconciliáveis com o journal. Correção administrativa não
edita eventos: emite comando e registro compensatório autorizados, sujeitos às
alçadas dos ADRs-0043 e 0050.

## 2.12 Reversão de redemption consumido

Cancelamento, refund ou chargeback não devolvem capacidade automaticamente.
Cada policy fixa, antes do consumo, exatamente um modo:

- `NO_CAPACITY_RETURN`;
- `RETURN_CAPACITY_ON_CONFIRMED_COMPENSATION`.

No primeiro modo, a reversão registra o evento e preserva a capacidade consumida.
No segundo, o retorno só ocorre depois de uma compensação comercial confirmada e
idempotente, com referência ao redemption original. Em ambos, `REVERSED` é novo
fato linked e o consumo original permanece imutável.

Esta regra governa apenas capacidade promocional. Ela não decide valor de refund,
saldo de cliente, crédito, conta contábil, imposto, receita, funding de parceiro,
settlement ou chamada ao meio de pagamento. Budget monetário promocional mede
capacidade comercial em minor units; não é caixa nem financial ledger.

## 2.13 Reconciliação e quarentena

Reconciliadores operam uma root operation e um tenant context por vez, com tenant
resolvido por fonte confiável antes de abrir o datasource dedicado. Eles comparam
journal/fence da plataforma com marker/outbox tenant-local e aplicam somente
transições monotônicas e idempotentes.

Estados resolvíveis incluem:

- marker `APPLIED` e capacity ainda `COMMIT_GRANTED`: confirmar `CONSUMED`;
- marker `ABORTED` e capacity não consumida: confirmar `RELEASED`;
- reservation `RESERVED` expirada sem grant: confirmar `EXPIRED`;
- evidência ausente, duplicada, divergente ou tenant indisponível: manter ou
  mover para `QUARANTINED` e alertar.

Reconciliação não escolhe promoção substituta, não corrige invoice, não pula
tenant guard e não libera capacidade para "destravar" operação desconhecida.
BP Farias e qualquer outro tenant seguem o mesmo protocolo; não existem bypass,
table compartilhada, datasource default ou regra nominal por cliente.

Ao resolver `QUARANTINED`, o reconciler acrescenta a evidência da resolução e
transiciona diretamente para `CONSUMED` quando comprova aplicação ou para
`RELEASED` quando comprova, de forma inequívoca, aborto e ausência de consumo.
Não retorna a `RESERVED`, não apaga a quarentena histórica e não cria nova
reservation para a mesma aplicação.

## 2.14 Journal, outbox e evidência mínima

Toda transição stateful produz journal append-only com event identity,
root/attempt/idempotency refs, aggregate version, old/new state, fence, policies e
limits exatos, hashes, actor técnico, timestamps confiáveis e reason code. Dados
de request não autorizados, raw coupon e payload externo não são copiados.

O outbox do platform store é atômico ao journal da respectiva transação; o outbox
tenant-local é atômico ao marker e fatos comerciais locais. Delivery pode ser
at-least-once porque consumidores são idempotentes e fence-aware. Ordenação global
entre todos os tenants não é assumida; ordering por aggregate/root operation é
obrigatório.

Retenção, criptografia, acesso, observabilidade e auditoria seguem ADR-0006 e
gates de segurança aplicáveis. A futura implementação deve permitir replay e
reconciliação sem fazer o journal virar fonte de PII ou segredo.

## 2.15 Minimização de dados e segurança

O platform ledger armazena somente IDs opacos necessários de seller, tenant,
billing account, promotion/campaign, coupon batch/artifact, intent e reservation,
além de policies, dimensões, quantidades, estados, hashes e evidência técnica. Ele
não armazena:

- cliente final do tenant, nome, e-mail, documento ou endereço;
- invoice, linha fiscal, pagamento, cartão, bank slip ou payload provider;
- raw coupon, digest HMAC, segredo, token ou credencial;
- descrição comercial livre ou snapshot completo do tenant;
- dados ASAAS ou decisão recebida do provider.

Autorização valida seller e tenant scope tanto na entrada quanto em cada adapter.
Identificador opaco não substitui authorization. Observabilidade usa labels de
baixa cardinalidade e correlação sanitizada; logs não incluem capacity vectors,
coupons ou PII. Consultas cross-tenant ficam restritas a operações internas
seller-owned autorizadas e auditadas.

## 2.16 Clean Architecture e custo inicial

O slice permanece dentro de `contexts.billing`, sem criar módulo ou microserviço.
O domínio futuro conterá somente policies, value objects, capacity demand,
reservation/redemption lifecycle, invariantes, transições e canonicalização. Ele
não importa Spring, JPA, Redis, relógio do sistema, rede, frontend, tenant routing,
provider ou DTO de transporte.

A aplicação orquestra os casos de uso por ports separados para capacity store,
tenant application evidence, trusted clock, outbox/audit e policy lookup. Adapters
isolam PostgreSQL platform, banco tenant-local e transporte. Tempo e identidade
entram no domínio como valores confiáveis explícitos.

PostgreSQL é a escolha inicial coerente com custo e infraestrutura da VPS. Uma
extração futura para serviço próprio só pode ocorrer atrás dos ports e depois de
evidência de SLO, hot key, volume, isolamento operacional ou ownership de equipe.
Não se antecipa custo de deployment, rede, tracing e consistência de um serviço
separado. Sharding, partitioning, limites de lock e cache seguem os gates do
ADR-0051 e o plano de implementação futuro.

## 2.17 Boundary da aprovação

Esta decisão foi aceita como `D-04.4-D — Opção A` por decisão humana explícita.
Ela fecha:

- autoridade central de capacidade no PostgreSQL da plataforma;
- scopes e dimensões fechados;
- reservation all-or-nothing do subconjunto stateful;
- estados, fencing, CAS, idempotência, TTL conceitual e ambiguity handling;
- saga platform/tenant sem XA e marker tenant-local;
- limite de uma tentativa inicial mais duas recombinações;
- consumo, release, expiry, reversal, journal e reconciliação;
- domínio dentro de `contexts.billing`, sem microserviço ou Redis autoritativo.

O baseline complementar `D-04.4-E` a `D-14` foi aceito por decisão
`AI_DELEGATED` do Codex sob `AUTH-BILLING-2026-08-25-001`, com revisão humana
`NOT_PERFORMED` e `Reviewability: OPEN`, nos ADR-0043 a ADR-0051 e revisões vigentes
dos ADR-0023 a ADR-0025. Essa origem não altera a aprovação humana explícita desta
ADR. `D-00` permite implementação hermética local dos planos TP-00013 e não
autoriza chamada externa, Sandbox, piloto ou produção.

Continuam pendentes os gates executáveis e externos: policies/limites/TTL reais,
OpenAPI/DDL/UI, merchant/capabilities/tarifas ASAAS, PCI, Sandbox, dados e
pareceres legais/fiscais/contábeis, SLO/backup e aceite de piloto.

Não foram aprovados budget real, limite numérico, TTL, campanha, cupom, tenant,
schema, tabela, migration, índice, classe, package, endpoint, OpenAPI, tela, job,
evento, cache, alerta, dashboard, deployment ou chamada ASAAS/provider.

---

# 3. Decision Drivers

- impedir over-redemption sob concorrência entre tenants isolados;
- reservar de forma atômica todos os limites do conjunto stateful selecionado;
- preservar database-per-tenant sem XA ou contador global fragmentado;
- distinguir preview, seleção, reservation, aplicação, consumo e reversão;
- tornar retries e timeouts ambíguos seguros por idempotência e fencing;
- preferir subalocação temporária a liberar capacidade de ownership incerto;
- manter journal imutável, explicabilidade e reconciliação reproduzível;
- minimizar PII e manter provider/ASAAS fora do domínio promocional;
- aproveitar PostgreSQL e monólito modular já previstos no custo inicial;
- permitir extração futura atrás de ports sem pagar esse custo antes de evidência.

---

# 4. Considered Options

## Option A: Autoridade central PostgreSQL e saga idempotente

Description: Manter toda capacidade mutável em um ledger seller-owned no
PostgreSQL da plataforma, reservar o conjunto stateful em uma transação e aplicar
no tenant por saga fenced, idempotente e reconciliável.

Pros:

- impõe atomicamente limites globais, tenant, account e coupon;
- evita XA e preserva database-per-tenant;
- PostgreSQL fornece constraints, transações e locking já operáveis;
- reduz custo inicial e mantém futura extração possível por ports;
- timeout, retry e compensação possuem evidência auditável.

Cons:

- campanha global muito concorrida pode criar hot key;
- saga exige markers, outboxes, reconciliação e quarentena;
- falha do store central faz reservation falhar fechada;
- operação precisa monitorar reservas presas sem liberar ambiguidade.

## Option B: Limites globais na plataforma e demais contadores no tenant

Description: Dividir cada reservation set entre control plane e banco do tenant.

Pros:

- parte das escritas ficaria distribuída;
- counters tenant-local pareceriam próximos ao contrato.

Cons:

- não existe commit atômico do conjunto entre stores;
- requer saga por item e amplia combinações de compensação;
- timeout pode consumir apenas parte do pacote;
- aumenta risco de over-redemption e custo de reconciliação.

Disposition: Rejected.

## Option C: Contadores tenant-local/eventuais ou Redis como autoridade

Description: Somar eventos dos tenants de forma eventual ou usar locks/counters
Redis para decidir capacidade.

Pros:

- baixa latência aparente;
- implementação inicial de contador pode parecer simples.

Cons:

- consistência eventual aceita excesso de limite global;
- eviction, failover ou split brain tornam ownership ambíguo;
- locks sem journal transacional não protegem efeito permanente;
- replay, reversão e auditoria ficam frágeis.

Disposition: Rejected.

## Option D: Criar um microserviço dedicado de promoção agora

Description: Extrair imediatamente capacity/redemption para deployment e banco
próprios.

Pros:

- boundary operacional independente desde o início;
- possibilidade futura de escala separada.

Cons:

- aumenta custo de VPS, deployment, rede, observabilidade e suporte;
- introduz falhas distribuídas antes de existir carga comprovada;
- não elimina a saga com bancos dos tenants;
- sistema pré-produção não apresenta evidência para justificar extração.

Disposition: Rejected for now; ports preservam essa evolução.

---

# 5. Decision Outcome

A **Option A** foi aceita por aprovação humana explícita.

O PostgreSQL da plataforma é a única autoridade de capacidade promocional
stateful. A flexibilidade comercial vem de policies e limites versionados; a
segurança concorrente vem de transação all-or-nothing, fencing, idempotência,
journal e saga. Nenhum benefício stateful se torna aplicado apenas por ter sido
selecionado em C ou exibido em preview.

---

# 6. Consequences

## Positive Consequences

- Um budget global pode ser imposto entre todos os bancos de tenant.
- Todos os limites de uma promoção são debitados ou nenhum é.
- Retry duplicado não cria novo consumo.
- Ambiguidade não devolve capacidade prematuramente.
- Faturas e fatos comerciais permanecem no tenant correto.
- Journal e markers permitem reconciliação sem consulta ao provider.
- Arquitetura permanece modular, provider-neutral e extraction-ready.

## Negative Consequences

- O platform store passa a ser dependência crítica do commit promocional.
- Hot campaigns exigirão métricas, bounds e qualificação conforme ADR-0051.
- Saga e reconciler aumentam o número de estados e cenários de teste.
- Quarentena pode reduzir temporariamente capacidade disponível.
- Operações administrativas exigirão alçadas fortes e auditoria do ADR-0050.

## Neutral Consequences

- Preview continua sem garantia de disponibilidade.
- Promoções stateless não criam reservation artificial.
- Budget monetário não é saldo financeiro nem contabilização.
- O ledger central não contém invoice ou PII de cliente do tenant.
- Nomes aprovados são conceitos canônicos, não nomes de tabelas/classes.
- `D-00` libera implementação hermética local, sem capability ou efeito real.

---

# 7. Impact

## Compatibility with prior decisions

| Decisão | Efeito desta ADR |
| --- | --- |
| ADR-0000 | Registra decisão, origem, boundary e ausência de implementação de forma rastreável. |
| ADR-0019 | Mantém fatos comerciais por tenant e centraliza apenas a autoridade cross-tenant indispensável. |
| ADR-0023 | Mantém provider e ASAAS fora de capacity/redemption. |
| ADR-0027 | Especializa catálogo/autoridade seller-owned platform e aceite comercial tenant-local. |
| ADR-0037 | Mantém o novo slice interno a `contexts.billing`, sem módulo ou aresta prematura. |
| ADR-0038 | Usa BRL/minor units e versões exatas; não transforma budget em pricing. |
| ADR-0039 | Reserva benefícios tipados sem convertê-los em crédito ou refund. |
| ADR-0040 | Usa coupon artifact opaco após eligibility; não persiste raw coupon/digest no ledger. |
| ADR-0041 | Recebe o subconjunto stateful do resultado C, preserva pacote atômico e fecha o handoff C -> D. |

## Impact by area

- Backend: futuros aggregate/lifecycle e casos de uso por ports; nenhum código aqui.
- Database: futuro store central e markers locais; nenhum DDL ou migration aqui.
- Frontend: somente feedback sanitizado; nunca reserva ou mostra saldo interno.
- Security: tenant guard, minimização, fencing, idempotência e fail-closed.
- Finance: capacity em minor units não substitui ledger, tax ou accounting.
- Operations: futuros reconciler, métricas e quarentena dependem dos artifacts e
  evidence gates dos ADRs-0043, 0050 e 0051.
- Infrastructure: PostgreSQL inicial; cache/microserviço não são autoridade.
- Provider: zero chamada ASAAS em reserve, grant, consume, release ou reconcile.

---

# 8. AI Agent Considerations

Agentes que detalharem ou implementarem esta decisão devem:

1. preservar `HUMAN_EXPLICIT` e `DIRECT_DECISION` como provenance desta ADR;
2. manter toda capacidade mutável no store platform autoritativo;
3. persistir no tenant somente marker e fatos comerciais locais;
4. derivar demandas stateful server-side a partir do resultado C exato;
5. reservar todos os limits do set em uma transação ou nenhum;
6. usar lock ordering canônico, CAS, version e fencing monotônico;
7. implementar idempotency key e fingerprint antes de retries;
8. reler o journal após timeout ambíguo, sem chave nova ou reserve cego;
9. preservar os sete estados e transições autorizadas;
10. nunca autoexpirar `COMMIT_GRANTED` ou liberar estado ambíguo;
11. aplicar marker/outbox tenant-local por saga, sem XA;
12. limitar o pipeline a uma tentativa inicial e duas recombinações;
13. redigir disponibilidade e exclusions em respostas públicas;
14. manter journal append-only e reversão compensatória linked;
15. tratar Redis/cache somente como derivado e descartável;
16. não armazenar PII, raw coupon/digest, invoice ou provider payload no ledger;
17. manter domínio sem framework, I/O, tenant routing ou provider;
18. não criar microserviço sem evidência e nova decisão;
19. criar código, DDL, OpenAPI e jobs dormentes somente no escopo hermético local
    de `D-00`, sem ASAAS externo ou efeito real;
20. não atribuir a uma IA esta aprovação humana explícita nem alterar sua
    provenance retroativamente.

---

# 9. Implementation Plan Boundary

Esta seção registra somente uma ordem futura, sem autorização de execução:

1. aplicar ADR-0043 e os gates transversais aceitos sem inferir implementação;
2. congelar schemas, reason codes, canonical fingerprints e state machine;
3. materializar e qualificar limites de custo, TTL, locks, batch e SLO conforme
   ADR-0051;
4. criar modelos/test vectors de concorrência, retries e falhas ambíguas;
5. implementar domínio puro e architecture tests;
6. implementar ports e adapter transacional PostgreSQL platform;
7. implementar marker/outbox no tenant store e tenant isolation tests;
8. implementar saga, expiration, reconciliation e quarantine;
9. integrar B -> C -> D com recombinação bounded;
10. integrar contrato/rating somente por evidência aplicada/consumida;
11. publicar APIs/UI somente após RBAC, redaction e contratos aprovados;
12. executar load/chaos/recovery tests antes de rollout.

Todos os itens podem avançar hermeticamente sob `D-00`. Testes devem usar databases/fixtures
efêmeros e nenhuma credencial, tenant, cupom, valor financeiro ou ASAAS real.

---

# 10. Validation

## 10.1 Gates documentais desta decisão

- provenance registra aprovação humana explícita e revisão direta;
- PostgreSQL platform é a única autoridade de capacidade mutável;
- invoices/snapshots continuam tenant-local e sem XA;
- scopes, dimensões, janelas e estados são fechados e tipados;
- reservation é atômica para todo o subconjunto stateful;
- idempotência, fingerprint, CAS e fencing são obrigatórios;
- ambiguidade mantém capacidade indisponível em quarentena;
- saga usa marker/outbox tenant-local e journal platform;
- recombinação é limitada a uma tentativa inicial mais duas;
- preview não reserva nem promete capacidade;
- reversal é compensatória e não redefine refund/accounting;
- Redis, frontend e provider não são autoridade;
- `D-04.4-E` a `D-14` possuem ADRs aceitos com proveniência explícita; `D-00`
  está `RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only` e os evidence
  gates externos continuam pendentes;
- nenhum código, DDL, API, policy real ou ASAAS foi criado.

## 10.2 Gates futuros de implementação

- concurrency tests provam que limites nunca são excedidos;
- transaction tests provam all-or-nothing para múltiplos scopes/dimensions;
- property tests provam lock ordering e fingerprints determinísticos;
- idempotency tests cobrem replay igual e conflito de fingerprint;
- fault-injection tests cobrem timeout antes/depois de cada commit;
- fencing tests rejeitam workers e mensagens stale;
- lifecycle tests cobrem somente transições permitidas;
- saga tests cobrem PREPARED/APPLIED/ABORTED e redelivery de outbox;
- quarantine tests impedem release em ownership ambíguo;
- expiration tests usam trusted clock e não expiram commit grant;
- recombination tests limitam attempts a três e preservam exclusions;
- reversal tests cobrem os dois modos sem apagar consumo;
- reconciliation tests percorrem um tenant/root context por vez;
- tenant isolation tests rejeitam mismatch e datasource default;
- privacy tests impedem PII, coupon/digest e payload provider no ledger/log;
- architecture tests mantêm domínio sem framework/Redis/provider;
- load tests medem hot key/lock pressure antes do rollout;
- provider tests provam zero chamada ASAAS em todo o lifecycle.

Esses testes não foram executados porque a mudança é exclusivamente documental e
`D-00` permite implementação hermética local e proíbe efeitos fora desse escopo.

---

# 11. Risks and Mitigations

| Risco | Mitigação obrigatória |
| --- | --- |
| Duas requisições excederem campanha global | Transação única, updates condicionais e locks em ordem canônica. |
| Deadlock em reservation composta | Ordenação total de capacity keys, bounds e testes concorrentes. |
| Retry duplicar débito | Idempotency key, fingerprint, journal e CAS. |
| Worker stale consumir reservation nova | Fencing token monotônico em toda transição. |
| Timeout causar nova reservation | Lookup autoritativo por key antes de retry. |
| Compensação liberar benefício já aplicado | Marker tenant-local, attestation e quarantine em ambiguidade. |
| Expirer correr contra commit | Expiração somente de `RESERVED` por CAS/fence. |
| Recombinação entrar em loop | Uma tentativa inicial mais duas, exclusions monotônicas. |
| Redis/failover corromper saldo | PostgreSQL permanece autoridade; cache é derivado. |
| Platform ledger virar banco de cliente | IDs opacos e proibição explícita de PII/invoice/payload. |
| Budget monetário virar saldo contábil | Separação normativa de capacity e financial ledger. |
| Hot campaign degradar VPS | Bounds/métricas conforme ADR-0051 e extração somente com evidência. |
| Reconciliação cross-tenant vazar dados | Resolver um tenant/context por vez, tenant guard e logs redigidos. |
| Operação manual apagar histórico | Journal append-only e compensações autorizadas. |
| Provider decidir disponibilidade | Zero dependência e zero chamada ASAAS no domínio. |
| Liberação local ser confundida com rollout | `D-00` permanece explícito como local-only; chamadas externas, Sandbox ASAAS, piloto BP Farias, produção, flags `ON` e efeitos reais continuam bloqueados. |

---

# 12. Related ADRs

- [ADR-0000 - Governança documental](../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md)
- [ADR-0001 - Stack e arquitetura](ADR-0001-technology-stack-and-architecture.md)
- [ADR-0006 - Auditoria e compliance](ADR-0006-audit-compliance.md)
- [ADR-0019 - Database-per-tenant](ADR-0019-database-per-tenant.md)
- [ADR-0023 - Integração agnóstica de providers](ADR-0023-agnostic-payment-provider-integration.md)
- [ADR-0027 - Catálogo global e faturamento local](ADR-0027-catalogo-global-faturamento-local.md)
- [ADR-0037 - Boundary físico de entitlements em Billing](ADR-0037-boundary-fisico-entitlements-billing.md)
- [ADR-0038 - Pricing tipado, moeda e cadência](ADR-0038-pricing-tipado-moeda-cadencia.md)
- [ADR-0039 - Taxonomia tipada de benefícios promocionais](ADR-0039-taxonomia-beneficios-promocionais.md)
- [ADR-0040 - Elegibilidade promocional e segurança de cupons](ADR-0040-elegibilidade-promocional-seguranca-cupons.md)
- [ADR-0041 - Stacking e waterfall promocional](ADR-0041-stacking-waterfall-promocional-deterministico.md)
- [ADR-0043 - Governança e lifecycle promocional](ADR-0043-governanca-lifecycle-promocional.md)
- [ADR-0044 - Lifecycle contratual e proration](ADR-0044-lifecycle-contratual-proration-assinaturas.md)
- [ADR-0045 - Metering, rating e fechamento](ADR-0045-metering-rating-fechamento-fatura.md)
- [ADR-0046 - Correção, cancelamento e reemissão](ADR-0046-correcao-cancelamento-reemissao-fatura.md)
- [ADR-0047 - Ledger, créditos e refunds](ADR-0047-ledger-creditos-refunds-disputas-writeoff.md)
- [ADR-0048 - Fatura comercial e NFS-e](ADR-0048-separacao-fatura-comercial-documento-fiscal-nfse.md)
- [ADR-0049 - Subledger tenant-local e MRR](ADR-0049-subledger-tenant-local-mrr-normalizado.md)
- [ADR-0050 - RBAC, SoD e aprovações](ADR-0050-rbac-sod-aprovacoes-financeiras.md)
- [ADR-0051 - SLO, capacidade e rollout](ADR-0051-slo-capacidade-rollout-billing.md)

---

# 13. References

- [REQ-00042 - Billing enterprise](../product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md)
- [UC-00038 - Catálogo, pricing e promoções](../product/use-cases/UC-00038-billing-catalog-pricing-promotions.md)
- [UC-00039 - Contratos, assinaturas e amendments](../product/use-cases/UC-00039-billing-contract-subscription-amendments.md)
- [UC-00040 - Medição, rating e fechamento](../product/use-cases/UC-00040-billing-usage-rating-invoice-close.md)
- [TP-00013 - Enterprise Billing Implementation](../../../docs/specs/TP-00013-enterprise-billing-implementation-task-plan.md)
- [Manifesto de módulos](../architecture/module-registry.md)
- `app/src/main/java/br/com/duoset/saas_service/contexts/billing/package-info.java`
- `app/src/main/java/br/com/duoset/saas_service/contexts/billing/BillingApi.java`
- `app/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/`

---

# 14. Decision Lifecycle

Esta ADR está `Accepted` pela aprovação humana explícita de
`D-04.4-D — Opção A`, registrada como `HUMAN_EXPLICIT` e `DIRECT_DECISION` em
2026-08-25. A autonomia concedida posteriormente para decisões futuras não muda
retroativamente o ator nem a provenance desta decisão.

Alterar placement da autoridade, atomicidade do reservation set, scopes,
dimensões, state machine, fencing, idempotência, saga, regra de expiração,
recombination bound, reversal ou fail-safe de quarentena exige nova versão
formalmente aceita ou ADR sucessor.

Lifecycle operacional/alçadas (`D-04.4-E`) e parâmetros/SLO (`D-14`) foram
aceitos por IA nos ADRs-0043, 0050 e 0051 sob
`AUTH-BILLING-2026-08-25-001`, com revisão humana `NOT_PERFORMED`/`OPEN`.
`D-00` está `RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`;
implementação hermética local foi autorizada, mas evidências externas e readiness
não foram atestadas.

---

# 15. Change Log

| Version | Date | Author | Provenance | Changes |
| --- | --- | --- | --- | --- |
| 1.2 | 2026-08-25 | Solicitante humano, proprietário declarado / Codex (IA), materialização | `HUMAN_EXPLICIT`; `RELEASED_WITH_SCOPE — TP-00013 local-only` | Libera implementação/DDL/OpenAPI/jobs/testes herméticos locais e mantém chamadas externas, limits/policies reais, Sandbox ASAAS, piloto BP Farias, produção, flags `ON` e efeitos reais bloqueados. |
| 1.1 | 2026-08-25 | Codex (IA) | `AI_DELEGATED` por `AUTH-BILLING-2026-08-25-001`; revisão humana `NOT_PERFORMED`/`OPEN` | Reconcilia os ADRs sucessores de `D-04.4-E`–`D-14` sem modificar a decisão humana `D-04.4-D`; mantém `D-00` ativo e evidencia que limites reais, SLO, ASAAS/PCI/Sandbox e pareceres externos continuam pendentes. |
| 1.0 | 2026-08-25 | Solicitante humano, proprietário declarado do SaaS / Arquitetura / Billing / Financeiro / Segurança | `HUMAN_EXPLICIT`; `DIRECT_DECISION` | Aceita `D-04.4-D — Opção A`; define autoridade PostgreSQL platform, limits/scopes, reservation atômica, states, fencing/idempotência, saga tenant-local, uma tentativa mais duas recombinações, lifecycle compensatório, reconciliação/quarentena e clean architecture, mantendo lifecycle operacional e implementação bloqueados. |

---

# 16. Repository Structure

Qualquer implementação futura permanece como slice interno de
`contexts.billing`, com domínio puro e adapters platform/tenant conforme
ADR-0037. Este documento não cria package, módulo, serviço, tabela, migration,
índice, cache, evento, job ou diretório. Nomes concretos exigem o plano TP-00013
aplicável e permanecem dentro do escopo local-only de `D-00`.

---

# 17. Review Process

Mudança editorial pode incrementar versão menor sem alterar provenance. Alteração
em autoridade, placement, scopes, atomicidade, state machine, idempotência,
fencing, saga, expiry, recombinação, reversal, quarantine, minimização ou boundary
exige revisão de Arquitetura, Billing, Produto, Financeiro e Segurança e novo
aceite rastreável. Uma revisão futura feita por humano pode confirmar, substituir
ou superseder a decisão, mas não reclassificar seu ator histórico.

---

# 18. Notes

Eligibility responde se uma promoção pode concorrer; combinação responde qual
pacote vence; capacity/redemption responde se o subconjunto stateful pode ser
reservado, aplicado e consumido sem exceder limites concorrentes. Reservation não
é aceite, consumption não é pagamento e reversal de capacity não é refund.

Sob `D-00`, policies, aggregates, ports, adapters, stores, markers, journals,
outboxes, jobs e contratos podem ser materializados localmente pelos planos
TP-00013. Nenhuma capability deve ser inferida sem código e evidência reproduzível.
