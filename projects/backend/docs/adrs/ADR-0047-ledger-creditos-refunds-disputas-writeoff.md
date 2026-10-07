---
document_id: "ADR-0047"
primary_nature: "Decisao"
objective: "Fechar `D-10` definindo autoridades, tipos, elegibilidade, concorrência e reversões para credit memo, saldos, unapplied cash, refund, dispute, chargeback e write-off sem apagar fatos financeiros."
scope: "`contexts.billing`, banco dedicado do tenant, `CreditMemo`, `AccountCreditLot`, `CreditApplication`, `UnappliedCash`, allocation, refund, payment reversal, dispute, chargeback, write-off, command journal, inbox/outbox, auditoria e integração provider-neutral."
non_objectives: "Implementar código, DDL, OpenAPI ou UI; criar wallet, prepaid/top-up, transferência, saque, marketplace ou split; definir tax/NFS-e de D-11, plano contábil/recognition de D-12, roles/alçadas exatos de D-13 ou rollout de D-14; atestar capability/fee ASAAS, parecer legal/contábil/fiscal, Sandbox ou produção."
owner: "Billing / Financeiro / Produto / Arquitetura"
status: "Accepted"
date: "2026-08-25"
version: "1.2"
keywords: "account credit, credit memo, unapplied cash, allocation, refund, dispute, chargeback, write-off, append-only ledger, tenant-local, idempotency"
related_files: "README.md, ../../../docs/specs/TP-00013-enterprise-billing-implementation-task-plan.md, ../specs/IP-BE-13.6.1-billing-credits-refunds-disputes.md, ../../../frontend/docs/specs/IP-FE-13.6.1-billing-credits-refunds-disputes.md, ADR-0023-agnostic-payment-provider-integration.md, ADR-0025-suspensao-tenant-inadimplencia-recuperacao.md, ADR-0027-catalogo-global-faturamento-local.md, ADR-0038-pricing-tipado-moeda-cadencia.md, ADR-0039-taxonomia-beneficios-promocionais.md, ADR-0046-correcao-cancelamento-reemissao-fatura.md"
code_references: "AS-IS em `app/src/main/java/br/com/duoset/saas_service/contexts/billing/` e `frontend/src/`; aggregates, policies, ports, stores, APIs e adapters descritos aqui são destinos planejados e ainda não existem."
principal_statement: "O database do tenant mantém um ledger operacional append-only, separado de promoções, invoices e subledger contábil, que habilita `CreditMemo`, créditos tipados, `UnappliedCash`, allocation determinística, refund somente pelo rail original, dispute/chargeback compensatórios e write-off não equivalente a pagamento; wallet/prepaid/transferências e representment automático ficam `OFF`."
---

# ADR-0047 - Ledger de créditos, refunds, disputas e write-off

- Document ID: `ADR-0047`
- Primary Nature: `Decisao`
- Objective: Fechar `D-10` definindo autoridades, tipos, elegibilidade, concorrência e reversões para credit memo, saldos, unapplied cash, refund, dispute, chargeback e write-off sem apagar fatos financeiros.
- Scope: `contexts.billing`, banco dedicado do tenant, `CreditMemo`, `AccountCreditLot`, `CreditApplication`, `UnappliedCash`, allocation, refund, payment reversal, dispute, chargeback, write-off, command journal, inbox/outbox, auditoria e integração provider-neutral.
- Non-objectives: Implementar código, DDL, OpenAPI ou UI; criar wallet, prepaid/top-up, transferência, saque, marketplace ou split; definir tax/NFS-e de D-11, plano contábil/recognition de D-12, roles/alçadas exatos de D-13 ou rollout de D-14; atestar capability/fee ASAAS, parecer legal/contábil/fiscal, Sandbox ou produção.
- Keywords: account credit, credit memo, unapplied cash, allocation, refund, dispute, chargeback, write-off, append-only ledger, tenant-local, idempotency
- Related Files: `docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00041-billing-invoice-correction-reissue.md`, `docs/product/use-cases/UC-00042-billing-payment-reconciliation-dunning.md`, `docs/product/use-cases/UC-00043-billing-credits-refunds-disputes.md`, `../../../docs/specs/TP-00013-enterprise-billing-implementation-task-plan.md`, `../specs/IP-BE-13.6.1-billing-credits-refunds-disputes.md`, `../../../frontend/docs/specs/IP-FE-13.6.1-billing-credits-refunds-disputes.md`, `ADR-0023-agnostic-payment-provider-integration.md`, `ADR-0025-suspensao-tenant-inadimplencia-recuperacao.md`, `ADR-0027-catalogo-global-faturamento-local.md`, `ADR-0038-pricing-tipado-moeda-cadencia.md`, `ADR-0039-taxonomia-beneficios-promocionais.md`, `ADR-0046-correcao-cancelamento-reemissao-fatura.md`
- Code References: AS-IS em `app/src/main/java/br/com/duoset/saas_service/contexts/billing/` e `frontend/src/`; aggregates, policies, ports, stores, APIs e adapters descritos aqui são destinos planejados e ainda não existem.
- Principal Decision: O database do tenant mantém um ledger operacional append-only, separado de promoções, invoices e subledger contábil, que habilita `CreditMemo`, créditos tipados, `UnappliedCash`, allocation determinística, refund somente pelo rail original, dispute/chargeback compensatórios e write-off não equivalente a pagamento; wallet/prepaid/transferências e representment automático ficam `OFF`.
- Date: 2026-08-25
- Status: Accepted
- Version: 1.2
- Decision Provenance: `AI_DELEGATED`
- Decision Actor: `AI_AGENT — Codex (OpenAI)`
- Authority Basis: `OWNER_DELEGATION — AUTH-BILLING-2026-08-25-001`
- Human Review Status: `NOT_PERFORMED`
- Reviewability: `OPEN`
- Authors: Codex (Artificial Intelligence), sob autoridade delegada
- Owners: Billing / Financeiro / Produto / Arquitetura
- Reviewers: AI — análise de arquitetura, domínio, segurança, integridade financeira e custo; Human — N/A, nenhuma revisão substantiva desta decisão foi realizada
- Stakeholders: Proprietário do SaaS, tenants contratantes, Financeiro, Collections, Suporte, Billing, Segurança, Backend, Frontend, Fiscal, Contabilidade e Operações
- Supersedes: N/A; especializa ADR-0023, ADR-0025, ADR-0039 e a cadeia corretiva de ADR-0046 sem alterar suas autoridades.
- Superseded by: N/A

---

# 0. Decision Provenance

| Field | Value |
| --- | --- |
| Normative status | `Accepted` |
| Decision package | `D-10` |
| Decision provenance | `AI_DELEGATED` |
| Decision actor | `AI_AGENT — Codex (OpenAI)` |
| Authority holder | Solicitante, declarado proprietário do SaaS; identidade não verificada criptograficamente pelo repositório |
| Authority grant | `AUTH-BILLING-2026-08-25-001`, registrada no TP-00013 |
| Human substantive review | `NOT_PERFORMED` |
| Reviewability | `OPEN`; revisão humana pode ratificar, emendar ou superseder sem apagar a origem IA |
| Excluded attestations | Capability/fee ASAAS, accounting/tax/legal treatment, PCI, Sandbox, produção, dados reais e implementação |

`Accepted` indica vigência normativa sob autoridade delegada, não aprovação humana,
implementação ou prontidão operacional. `D-00 = RELEASED_WITH_SCOPE —
HUMAN_EXPLICIT — TP-00013 local-only` permite código e testes herméticos locais.
ADR-0050 governa aprovação/SoD e ADR-0051 governa habilitação/rollout;
ambos foram decididos por IA sob a mesma autoridade, sem revisão humana
substantiva nem evidência operacional.

---

# 1. Context

Invoice, pagamento, promoção, crédito e caixa respondem perguntas diferentes. Uma
linha promocional reduz preço antes da invoice; um credit memo corrige uma obrigação
documentada; um pagamento prova caixa; unapplied cash é caixa ainda sem destino; um
account credit é direito financeiro com origem e condições; refund devolve caixa;
write-off reconhece que a cobrança não será perseguida. Fundi-los em um campo
`balance` permitiria sacar promoção, apagar dívida, duplicar refund e restaurar
acesso por baixa contábil.

O baseline não possui essas autoridades implementadas. O projeto é pré-produção,
database-per-tenant, modular monolith e VPS-first. A decisão deve oferecer
flexibilidade por tipos/policies e movimentos causais, mas evitar serviço de wallet,
novo banco, microserviço, broker ou engine genérica incompatíveis com o custo
inicial.

---

# 2. Decision Statement

## 2.1 Autoridades separadas

| Autoridade | Responsabilidade | Proibições |
| --- | --- | --- |
| Invoice/correction chain | Valor comercial finalizado e `CreditMemo`/`DebitMemo` causal conforme ADR-0046 | Não recebe update de valor após finalização. |
| Payment/cash | Pagamento confirmado/settled, reversal e disponibilidade de caixa | Não vira crédito/promocional por rename. |
| Operational balance ledger | Grants, applications, releases, expiry explícita, unapplied cash, refund reservations e compensações | Não substitui invoice nem o subledger gerencial do ADR-0049. |
| Provider command journal | Intenção externa, idempotency key, outcome e reconciliação | Não decide elegibilidade comercial. |
| Dunning/access | Saldo elegível e efeitos `PAYMENT_DELINQUENCY` conforme ADR-0025 | Write-off/refund/dispute não significam payment/recovery. |
| Fiscal/accounting | Documento fiscal do ADR-0048 e posting estatutário fora do ADR-0049 | Não são inferidos pelo ledger operacional. |

Todas as autoridades financeiras desta decisão residem no banco dedicado do tenant
e são alteradas em transação local única com outbox. O store de plataforma pode
conter apenas índice pré-tenant sanitizado do ADR-0023; não replica saldo, credit
lot, refund, dispute ou write-off. Não há XA, FK/join cross-store ou datasource
default.

## 2.2 Ledger operacional append-only

O ledger registra movimentos imutáveis com, no mínimo:

- `movementId`, `tenantId`, `billingAccountId` e moeda, somente `BRL` no primeiro
  slice conforme ADR-0038;
- `movementType`, source type/id e target type/id;
- amount não negativo; direção é definida pelo tipo, nunca por valor negativo;
- `effectiveAt`, `recordedAt`, policy/version e optimistic/fencing version;
- actor/service principal, reason code, evidence reference e approval reference;
- predecessor/causal movement, idempotency key e payload fingerprint;
- correlation/trace e outbox publication identity.

Correção cria movimento compensatório ligado ao original. `UPDATE` de amount/source,
`DELETE`, reaproveitamento de ID, saldo manual e lançamento sem causa são proibidos.
Mesmo ID + mesmo fingerprint é idempotente; mesmo ID + payload divergente é conflito
e quarentena. Projeções de saldo são reconstruíveis e nunca substituem o journal.

Este é um ledger operacional de Billing, não um livro contábil em partidas dobradas.
O ADR-0049 traduz movimentos aprovados em posting intents gerenciais balanceados;
posting estatutário continua `PENDING_EVIDENCE` do owner contábil e este ADR não
inventa revenue recognition.

## 2.3 Tipos habilitados e capabilities desligadas

O primeiro slice habilita:

| Tipo | Origem válida | Uso |
| --- | --- | --- |
| `CREDIT_MEMO_CREDIT` | `CreditMemo` finalizado e elegível | Reduz obrigação aberta ou cria lote conforme destino aprovado. |
| `REFUNDABLE_CASH_CREDIT` | Caixa confirmado/settled elegível ou credit memo sobre pagamento | Pode sustentar refund pelo rail original, sujeito à Section 2.7. |
| `CONTRACTUAL_CREDIT` | Termo/revisão contratual aprovado | Aplicação apenas no scope/período definido; refund somente se explicitamente elegível. |
| `GOODWILL_CREDIT` | Concessão comercial aprovada | Não sacável, não transferível e nunca representa caixa. |
| `PROMOTIONAL_CREDIT` | Campanha que explicitamente produz lote financeiro pela autoridade D-10 | Não sacável, não transferível; não substitui `PromotionBenefit` de ADR-0039. |
| `UNAPPLIED_CASH` | Excesso ou recebimento sem allocation definitiva | Continua caixa do payer, sem conversão implícita em wallet/account credit. |

ADR-0046 continua owner da emissão do `CreditMemo` e de sua
`AdjustmentApplication` sobre obrigação aberta. “Habilitar CreditMemo” nesta ADR
significa aceitar esse documento finalizado como causa financeira e resolver seus
`AccountCreditCandidate`/`RefundCandidate`; ADR-0047 não emite nem reescreve o documento.
`CreditApplication` aplica um `AccountCreditLot` e não é alias da
`AdjustmentApplication` do ADR-0046.

Permanecem modeláveis apenas como capability futura e `OFF`:

- prepaid balance, top-up e consumo pré-pago;
- wallet genérica ou stored-value account;
- transferência entre tenants, billing accounts, pagadores ou moedas;
- saque/withdrawal e payout alternativo;
- marketplace, split, subconta, escrow e antecipação;
- conversão automática de overpayment em crédito promocional/prepaid;
- saldo negativo/limite de crédito e FX.

API, import, operação de suporte ou adapter que tentar essas capacidades falha com
reason canônico; não cria um movimento “genérico”. Habilitação futura exige novo
ADR/requisito e análise regulatória, contábil, fraude e segurança.

## 2.4 Effective period e expiração

Todo lote de goodwill, promoção ou crédito contratual possui `effectiveFrom`
explícito e `effectiveTo` opcional sob timezone/policy versionada. Ausência de
`effectiveTo` significa **sem expiração**, nunca “usar default do sistema”.

Quando `effectiveTo` existir, expiry cria movimento próprio no boundary exato e
somente sobre saldo ainda disponível. Não retroage, não remove application e não
transforma valor expirado em receita/caixa por inferência. Alterar período cria
novo lote/reversal aprovado; não edita o lote publicado.

Goodwill e promoção são sempre não sacáveis e não transferíveis, mesmo sem expiry.
Metadado ausente não amplia natureza, scope, rail ou refundability.

## 2.5 Unapplied cash e overpayment

Pagamento pode ser parcial, múltiplo ou superior ao saldo, mas cada allocation
fecha em minor units. O excesso cria `UnappliedCashPosition` causal ao payment e
permanece **unapplied** até uma destas decisões explícitas:

1. allocation futura a obrigação do mesmo tenant, billing account e moeda; ou
2. refund elegível pelo rail original.

O excesso não vira wallet, prepaid, goodwill, promoção, receita, desconto ou saldo
transferível. Não expira por silêncio. Payment reversal, dispute ou chargeback
aplica hold/compensação sobre a posição correspondente sem apagar sua origem.

## 2.6 Allocation determinística

Uma `AllocationPolicyVersion` pinada decide destino e ordem. O primeiro slice usa:

1. instrução explícita autorizada, quando fornecida e elegível;
2. caso contrário, obrigações vencidas do mesmo account/moeda;
3. depois, obrigações abertas já emitidas;
4. desempate por `dueAt`, `finalizedAt`, número canônico e ID;
5. por obrigação, menor entre source available e eligible outstanding balance;
6. residual continua na fonte original, sem arredondamento implícito.

Ao escolher fontes para uma obrigação, o default favorável ao payer consome
primeiro créditos não sacáveis com expiry mais próxima, depois créditos não
sacáveis sem expiry e somente então unapplied cash/refundable credit. Dentro da
mesma classe: `effectiveTo`, `effectiveFrom`, `createdAt`, `lotId`. Uma policy
futura pode mudar a ordem prospectivamente, mas não recomputa applications.

Allocation, unallocation e reallocation são movimentos separados. Unapply só é
permitido quando nenhum efeito posterior o torna inconsistente; caso contrário,
usa cadeia compensatória aprovada. Locks/optimistic version/unique constraints
garantem que allocations concorrentes nunca excedam source ou target. Não há
allocation cross-tenant, cross-account ou cross-currency.

## 2.7 Refund pelo rail original

Refund exige simultaneamente:

- solicitação, reason/evidence, preview e approval conforme ADR-0050;
- base comercial elegível, como credit memo/refund decision ou unapplied cash;
- payment original autenticado/reconciliado e provider/account/rail conhecidos;
- capability de refund comprovada no mesmo rail original;
- valor e moeda compatíveis;
- ausência de conflito tenant/account e de hold/dispute impeditivo.

O teto no instante do comando é:

```text
min(commerciallyEligibleAmount, providerEligibleConfirmedOrSettledAmount)
- successfulRefunds
- pendingOrUnknownRefundReservations
- reversalsAndChargebacks
- protectedDisputedAmount
```

Cada termo é não negativo e causal ao mesmo payment/moeda. O valor solicitado deve
ser maior que zero e menor ou igual ao teto. `PENDING` e `UNKNOWN` reservam o valor
até reconciliação para impedir duas devoluções concorrentes. Crédito promocional ou
goodwill nunca integra `commerciallyEligibleAmount`.

O refund usa exclusivamente o rail/payment original. Ausência de capability,
conta encerrada ou rail indisponível abre revisão operacional e não autoriza Pix,
transferência, wallet, cash manual ou outro provider automaticamente.

Antes de chamar o provider, Billing persiste `RefundRequest`, approval seal,
`ProviderCommand` e reservation com chave lógica única. Outcomes:
`PENDING`, `SUCCEEDED`, `PARTIALLY_SUCCEEDED`, `REJECTED`, `UNKNOWN`,
`RECONCILED` e `MANUAL_REVIEW`. Timeout/5xx após possível efeito remoto fica
`UNKNOWN`; polling/webhook/reconciliation prova o resultado antes de novo comando.
Sucesso cria movimentos de refund e reversão de allocations elegíveis; nunca edita
payment, invoice ou settlement originais.

## 2.8 Dispute, chargeback e reversal

Evento autenticado/reconciliado de dispute ou chargeback:

1. deduplica no inbox sanitizado do ADR-0023;
2. abre/atualiza `DisputeCase` tenant-local monotônico;
3. aplica hold no cash/refundable balance afetado;
4. cria movimentos compensatórios para principal e fee observada;
5. recalcula saldo/collection por policy, sem editar payment/allocation original;
6. publica fatos causais para ADRs-0025 e 0049.

Reversal/win/loss posterior cria novos movimentos causais; nunca faz `DELETE`,
backdate de payment ou sobrescrita de journal. Eventos duplicados/fora de ordem são
no-op ou avanço monotônico. Valor desconhecido, referência conflitante ou estado
ambíguo permanece em hold/quarentena e bloqueia refund concorrente.

Representment automático, submissão automática de evidências e decisão autônoma de
contestar ficam `OFF`. Evidência operacional usa referência protegida e metadata
mínima; payload/provider document bruto não entra em log, evento público ou label.

## 2.9 Write-off

Write-off é decisão imutável de cessar/reduzir cobrança de receivable sob policy e
approval. Ele:

- não é payment, settlement, refund, cancelamento, credit memo ou delete;
- não altera invoice/documento fiscal/contrato por conta própria;
- cria movimento próprio sobre o outstanding elegível e preserva obrigação;
- não produz `PAYMENT_EFFECTIVE` e não recupera acesso por default;
- não remove dispute, chargeback, fee ou outro effect;
- admite recovery posterior somente como novo payment/allocation e movimentos
  causais, preservando o write-off original.

No primeiro slice, write-off não encerra automaticamente `DunningCase` nem remove
`FINANCIAL_ACCESS_RESTRICTION`. Qualquer policy futura diferente exige decisão
explícita e nunca pode chamar baixa de pagamento.

## 2.10 Crédito, promoção e invoice não se confundem

- `PromotionBenefit`/`AcceptedPromotionCombinationSnapshot` reduzem preço antes
  da invoice e não criam saldo residual.
- `PROMOTIONAL_ENTITLEMENT_GRANT` concede capability, não dinheiro.
- `PROMOTIONAL_CREDIT` só existe quando workflow desta ADR cria lote financeiro
  explícito com funding, período e approval; não é inferido de desconto não usado.
- `CreditMemo` corrige obrigação e pode originar application/refundability segundo
  decisão causal; não equivale ao movimento de caixa.
- Total negativo de invoice é proibido; excesso torna-se lote/posição tipado, nunca
  invoice negativa.

## 2.11 Segurança, SoD e isolamento

- Scope tenant/account/moeda é resolvido antes do repository; BOLA falha antes de
  revelar existência, saldo, payment ou provider ID.
- APIs públicas usam IDs internos; provider/account/rail são resolvidos
  server-side e nunca escolhidos pelo browser para rotear dinheiro.
- Issuance/reversal de credit, refund, write-off, reparo manual e resolução material
  de dispute exigem approval seal/four-eyes do ADR-0050; requester não aprova o próprio
  efeito e fracionamento cumulativo não contorna controle.
- Enquanto ADR-0050 não estiver materializado/testado, operações monetárias controladas ficam
  `OFF`; leitura/preview/dry-run não concede saldo nem chama provider.
- Evidence references são opacas, acesso usa RBAC/purpose/audit, e logs/traces/
  métricas não contêm PII financeira, payload, tenant/invoice/payment em label.
- Segredos do provider permanecem no adapter/configuração aprovada; ledger nunca
  armazena API key, webhook token, PAN, CVV ou `creditCardToken`.

## 2.12 Falha segura, flags e rollback

Capabilities começam `OFF` conforme ADR-0051 e avançam por coorte. Kill switch de novas
mutações não desliga webhook, inbox, reconciliação, recovery ou compensação de
comando já enviado.

| Falha | Comportamento |
| --- | --- |
| Policy/approval ausente, ambígua ou expirada | Não cria movimento/comando; `BILLING_APPROVAL_REQUIRED`/regra inefetiva. |
| Payload idempotente divergente | Conflito e auditoria; zero segundo efeito. |
| Saldo/eligibility concorrente mudou | CAS falha; recalcular preview e exigir novo approval quando material. |
| Provider outcome ambíguo | `UNKNOWN`, reservation preservada, reconcile; sem retry/fallback cego. |
| Evento sem tenant mapping | Quarentena sanitizada; nunca datasource default/scan. |
| Adapter/capability indisponível | Operação permanece `OFF`/pending review; não troca rail/provider. |
| Rollback de aplicação | Preserva ledger/journal/inbox/outbox; reprocessa IDs existentes ou compensa. |
| Período fechado | Movimento prospectivo permitido pelo ADR-0049; nunca update/backdate destrutivo. |

---

# 3. Decision Drivers

- Preservar centavos, causalidade e histórico sob concorrência/replay.
- Evitar que promoção, crédito, caixa e dívida compartilhem semântica ambígua.
- Devolver somente caixa elegível e impedir refund duplicado após timeout.
- Manter provider como executor, não autoridade comercial.
- Isolar tenants e impedir transferência/saldo cross-account.
- Permitir evolução por tipos/policies sem engine genérica ou novo serviço.
- Compatibilizar Clean Architecture, SOLID, Spring Modulith e VPS inicial.
- Manter SoD, auditoria, reconciliation e rollback antes de efeitos externos.

---

# 4. Considered Options

## Option A - Ledger operacional tenant-local, tipado e append-only

**Description:** movimentos causais imutáveis, projections reconstruíveis,
provider por ports e capabilities avançadas desligadas.

**Pros:** integridade, isolamento, explicabilidade, baixo custo operacional e
extração futura possível.

**Cons:** exige mais tipos, constraints, reconciliation e workflows do que um campo
de saldo mutável.

**Outcome:** Chosen.

## Option B - Um saldo mutável por tenant

**Description:** coluna `balance` recebe descontos, créditos, pagamentos e refunds.

**Pros:** implementação aparente simples.

**Cons:** perde origem/natureza, permite saque de promoção, sofre lost update e não
reconcilia reversões.

**Outcome:** Rejected.

## Option C - Provider como wallet/ledger autoritativo

**Description:** saldo e estados ASAAS comandam o domínio local.

**Pros:** menos modelos locais no curto prazo.

**Cons:** acoplamento, perda de reprodutibilidade, isolamento/portabilidade fracos e
conflito com ADR-0023.

**Outcome:** Rejected.

## Option D - Wallet/prepaid/marketplace completo no primeiro release

**Description:** stored value, top-up, transfer, payout, split e FX desde o início.

**Pros:** máxima amplitude comercial imediata.

**Cons:** custo, fraude, regulação, segurança, accounting e operação muito maiores
que o problema SaaS atual.

**Outcome:** Rejected for the first architecture; capabilities `OFF`.

---

# 5. Decision Outcome

A Option A foi escolhida. Ela fecha as capacidades necessárias a cobrança SaaS e
correções sem transformar o Hub em wallet. O tradeoff é manter modelos e workflows
distintos; isso evita que uma operação monetária seja reinterpretada por
conveniência e permite conciliar cada efeito até sua origem.

---

# 6. Consequences

## Positive Consequences

- Overpayment, crédito e caixa nunca desaparecem nem mudam de natureza.
- Refund concorrente/ambíguo reserva teto e converge sem dupla devolução.
- Promoção/goodwill não podem ser sacados ou transferidos.
- Dispute/chargeback/write-off preservam documentos e movements originais.
- Um tenant não financia, recebe ou consulta saldo de outro.

## Negative Consequences

- Há mais aggregates, state machines, constraints e filas operacionais.
- Provider, fiscal e accounting exigem reconciliação independente.
- Capabilities flexíveis de wallet/prepaid ficam adiadas.
- SoD pode manter operações desligadas até existir segundo aprovador.

## Neutral Consequences

- Projection de saldo é cache reconstruível e pode ser otimizada depois.
- O mesmo modelo aceita novos tipos somente por decisão explícita, não enum
  desconhecido ou movement genérico.
- Accepted não significa implementação ou availability.

---

# 7. Impact

- **Architecture:** novo slice interno de balance/adjustments em
  `contexts.billing`, sem módulo/serviço/banco novo.
- **Data:** famílias tenant-local append-only para movements, lots, applications,
  unapplied cash, refund, dispute, write-off, journal/outbox e projections.
- **Backend:** domínio Java puro; application ports para clock, repository,
  approval, audit, provider e publication; adapters isolam JPA/ASAAS.
- **Frontend/API:** preview e estados canônicos; zero cálculo autoritativo ou
  provider routing no browser.
- **Security:** BOLA, SoD, idempotency, redaction, immutable audit e fail-safe.
- **Operations:** queues para `UNKNOWN`, divergence, dispute deadlines e
  compensations; metrics de baixa cardinalidade.
- **Cost:** PostgreSQL/worker existentes; sem broker, Redis autoritativo, engine ou
  datastore adicional.

---

# 8. AI Agent Considerations

Agentes de implementação DEVEM partir dos IPs aprovados, gerar testes e preservar
as autoridades desta decisão. Não podem:

- habilitar capability `OFF`;
- inventar alçada, conta contábil, tratamento fiscal, fee ou capability ASAAS;
- criar movement/adjustment genérico;
- transformar promo/goodwill em dinheiro sacável;
- usar update/delete para corrigir fato financeiro;
- retry/fallback em refund `UNKNOWN`;
- tratar write-off como payment/recovery;
- acessar produção, segredos, dados reais ou contatar cliente/provider.

Human review permanece aberta. Ratificação futura registra reviewer/data/evidence,
mas não apaga `AI_DELEGATED`.

---

# 9. Implementation Plan

Esta sequência não inicia implementação:

1. reconciliar ADR/REQ/UC/TP/IP, aplicar a liberação local-only de `D-00` e
   preservar os evidence gates dos ADRs-0050/0051;
2. congelar contratos, reason codes, schemas, policies e approval seals;
3. criar migrations tenant-local aditivas e constraints de idempotência/saldo;
4. implementar domínio puro e projections/rebuild;
5. implementar application services, local transactions e outbox;
6. implementar provider refund/dispute adapters e reconciliation;
7. expor APIs/UI server-authoritative com BOLA/SoD;
8. executar shadow/dry-run, testes de concorrência e Sandbox autorizado;
9. habilitar por capability/coorte somente após evidência do ADR-0051.

Rollback desabilita novas mutações e preserva ingestão/reconciliation. Schema não
recebe down migration destrutiva; reversão financeira usa movements compensatórios.

---

# 10. Validation

## 10.1 Domain and persistence

- property tests provam `opening + movements = projection` e zero saldo negativo;
- mesmo key/fingerprint é idempotente; fingerprint divergente conflita;
- rebuild produz o mesmo saldo/hash;
- nenhuma mutação altera/apaga movement finalizado;
- tenant/account/currency divergente falha antes do repository.

## 10.2 Allocation and credits

- golden vectors provam a waterfall e desempates em minor units;
- duas allocations concorrentes no último centavo consomem no máximo o disponível;
- overpayment permanece unapplied até allocation/refund explícito;
- goodwill/promo não são sacáveis/transferíveis;
- `effectiveTo` ausente nunca expira; expiry explícita cria movement no boundary.

## 10.3 Refund and provider

- refund acumulado, reservations `PENDING/UNKNOWN`, reversals, chargebacks e hold
  nunca excedem o teto elegível;
- timeout-after-effect permanece `UNKNOWN` e reconcile converge sem segundo POST;
- rail/provider alternativo não é selecionado automaticamente;
- callback/response sem reconciliação não produz sucesso;
- contract suite e Sandbox usam somente dados sintéticos/ambiente autorizado.

## 10.4 Dispute/write-off/security

- duplicate/reorder de dispute produz movimentos uma vez e monotônicos;
- chargeback preserva payment/invoice/allocation originais;
- representment automático permanece inacessível;
- write-off produz zero `PAYMENT_EFFECTIVE` e zero recovery de acesso;
- requester não autoaprova e fracionamento cumulativo falha;
- BOLA A→B, logs/trace/metrics e evidence access passam testes negativos.

## 10.5 Architecture and operations

- domain/application não importam SDK/provider/JPA/web;
- `ApplicationModules.verify()` e ArchUnit permanecem verdes;
- kill switch bloqueia novos comandos sem parar inbox/reconciliation;
- queues/alerts cobrem `UNKNOWN`, stale reservation, divergence e dispute deadline;
- nenhum teste obrigatório é skip usado como aceite.

---

# 11. Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Saldo mutável diverge do histórico | Crédito/perda invisível | Ledger append-only + rebuild/reconciliation. |
| Refund duplicado após timeout | Perda de caixa | Reservation persist-before-call + `UNKNOWN` + reconcile. |
| Crédito promocional sacado | Fraude/perda | Natureza fechada, non-withdrawable e tests. |
| Overpayment vira receita/saldo genérico | Passivo perdido | `UnappliedCash` sem expiry/conversão implícita. |
| Allocation concorrente excede saldo | Centavos duplicados | Lock/CAS/unique + invariant transaction. |
| Chargeback apaga payment | Audit/accounting incorretos | Hold + movements compensatórios. |
| Write-off restaura serviço | Acesso sem quitação | Sem `PAYMENT_EFFECTIVE`; ADR-0025 causal. |
| Cross-tenant transfer/BOLA | Vazamento/perda | Scope guard e capabilities de transfer `OFF`. |
| Novo tipo vira adjustment genérico | Semântica indistinguível | Algebra fechada e decisão versionada. |
| Rollback interrompe webhook | Estado externo não converge | Kill switches separados de ingest/reconcile. |

---

# 12. Resolved Decisions and Evidence Gates

Não resta escolha arquitetural aberta em `D-10`. Permanecem evidências que a IA
não pode fabricar:

| Gate | Owner | Default enquanto ausente |
| --- | --- | --- |
| Capability, estados, limites, prazo e fees de refund/dispute ASAAS por merchant/rail | Adapter + Financeiro + QA | Capability externa `OFF`; zero chamada. |
| Alçadas, roles, MFA e segundo aprovador | ADR-0050 / Segurança / Financeiro | Decisão aceita; implementação/evidência ausente mantém mutação controlada `OFF`. |
| Tratamento fiscal de credit memo/refund | ADR-0048 / Fiscal/Jurídico | Boundary aceito; dados/pareceres pendentes mantêm estado fiscal sem falso complete. |
| Contas/postings/fees/revenue recognition | ADR-0049 / Contabilidade | Subledger gerencial aceito; sem lançamento estatutário inferido. |
| SLO, capacity, backup, Sandbox e rollout | ADR-0051 / SRE/QA | Targets aceitos; medição/evidência ausente mantém flags `OFF`, sem piloto/produção. |

---

# 13. Related ADRs

- [ADR-0000 - Governança documental](../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md)
- [ADR-0005 - Multi-Tenancy Architecture](ADR-0005-multi-tenancy-architecture.md)
- [ADR-0006 - Audit and Compliance](ADR-0006-audit-compliance.md)
- [ADR-0019 - Database per Tenant](ADR-0019-database-per-tenant.md)
- [ADR-0023 - Integração agnóstica de provedores](ADR-0023-agnostic-payment-provider-integration.md)
- [ADR-0025 - Inadimplência e recuperação](ADR-0025-suspensao-tenant-inadimplencia-recuperacao.md)
- [ADR-0027 - Catálogo global e faturamento local](ADR-0027-catalogo-global-faturamento-local.md)
- [ADR-0038 - Pricing tipado, moeda e cadência](ADR-0038-pricing-tipado-moeda-cadencia.md)
- [ADR-0039 - Benefícios promocionais](ADR-0039-taxonomia-beneficios-promocionais.md)
- [ADR-0046 - Correção, cancelamento e reemissão](ADR-0046-correcao-cancelamento-reemissao-fatura.md)
- [ADR-0048 - Fatura comercial e NFS-e](ADR-0048-separacao-fatura-comercial-documento-fiscal-nfse.md)
- [ADR-0049 - Subledger tenant-local e MRR](ADR-0049-subledger-tenant-local-mrr-normalizado.md)
- [ADR-0050 - RBAC, SoD e aprovações](ADR-0050-rbac-sod-aprovacoes-financeiras.md)
- [ADR-0051 - SLO, capacidade e rollout](ADR-0051-slo-capacidade-rollout-billing.md)

---

# 14. References

- [REQ-00042 - Enterprise Multitenant Billing](../product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md)
- [UC-00041 - Invoice Correction and Reissue](../product/use-cases/UC-00041-billing-invoice-correction-reissue.md)
- [UC-00042 - Payment, Reconciliation and Dunning](../product/use-cases/UC-00042-billing-payment-reconciliation-dunning.md)
- [UC-00043 - Credits, Refunds and Disputes](../product/use-cases/UC-00043-billing-credits-refunds-disputes.md)
- [TP-00013 - Enterprise Billing Implementation](../../../docs/specs/TP-00013-enterprise-billing-implementation-task-plan.md)
- [IP-BE-13.6.1-billing-credits-refunds-disputes](../specs/IP-BE-13.6.1-billing-credits-refunds-disputes.md)
- [IP-FE-13.6.1-billing-credits-refunds-disputes](../../../frontend/docs/specs/IP-FE-13.6.1-billing-credits-refunds-disputes.md)
- [Module Registry](../architecture/module-registry.md)

---

# 15. Decision Lifecycle

Current State: **Accepted**

`D-10` foi decidido por Codex sob autoridade delegada e não recebeu revisão humana
substantiva. O status torna a arquitetura normativa; implementação hermética local
está liberada por `D-00`, enquanto external effects continuam bloqueados pelos
gates de evidência da Section 12.
`D-11` a `D-14` estão aceitos nos ADR-0048 a ADR-0051 sob a mesma provenance
`AI_DELEGATED`, revisão humana `NOT_PERFORMED`/`OPEN`; isso não comprova os
attestations externos. Uma revisão humana futura pode ratificar, emendar ou
superseder, mas deve preservar a proveniência.

---

# 16. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.2 | 2026-08-25 | Solicitante humano, proprietário declarado / Codex (IA), materialização | Registra `D-00 = RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`; permite implementação/testes herméticos locais e mantém chamadas externas, Sandbox ASAAS, piloto BP Farias, produção, flags `ON` e efeitos reais bloqueados. |
| 1.1 | 2026-08-25 | Codex (AI), sob `AUTH-BILLING-2026-08-25-001` | Reconcilia `D-11`–`D-14` com ADRs-0048–0051 aceitos `AI_DELEGATED`, revisao humana `NOT_PERFORMED`/`OPEN`; mantém ASAAS/fiscal/contábil/SLO/Sandbox como evidence gates e `D-00` ativo. |
| 1.0 | 2026-08-25 | Codex (AI), sob `AUTH-BILLING-2026-08-25-001` | Fecha `D-10`: ledger operacional tenant-local append-only, CreditMemo/créditos/unapplied cash, allocation determinística, refund no rail original com reservation/UNKNOWN/reconcile, dispute/chargeback compensatórios, write-off separado e capabilities wallet/prepaid/transfer/representment `OFF`; nenhuma implementação/revisão humana/evidência externa é afirmada. |

---

# 17. Repository Structure

```text
docs/
  adrs/
    ADR-0047-ledger-creditos-refunds-disputas-writeoff.md
```

Este ADR deve permanecer indexado individualmente no README imediato conforme o
ADR-0000; ele não cria código, migration, API, tabela ou adapter existente.

---

# 18. Review Process

1. Revisão humana registra reviewer, data, escopo e evidência sem alterar a origem.
2. Ratificação atualiza `Human Review Status`, não o `Decision Provenance`.
3. Mudança normativa cria nova versão aceita ou ADR sucessor.
4. Habilitação operacional exige todos os gates da Section 12.

---

# 19. Notes

- “Crédito” sem tipo/origem não é um input válido.
- “Refund aprovado” não significa “refund executado”; provider outcome e
  reconciliation permanecem eixos próprios.
- “Write-off” não prova pagamento nem quitação para entitlement.
- “Saldo disponível” é uma projection explicável, não autoridade editável.
- Máxima flexibilidade é obtida por tipos/policies/versionamento, não por movement
  genérico, script, valor negativo ou provider como domínio.
