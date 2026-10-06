---
document_id: "ADR-0043"
primary_nature: "Decisao"
objective: "Definir lifecycle operacional, publicação governada, pausa, retirada, expiração, revogação, descontos de origem manual, funding attribution e controles de segurança para promoções seller-owned do Contador Fiscal."
scope: "`PromotionVersion`, `CampaignVersion`, `CouponBatchVersion`, `PromotionCapacityPolicyVersion`, estados e transições append-only, vigência, publicação, simulação, impact preview, outbox, segregação de funções, MFA, auditoria, remediação de revogação, artefatos promocionais de origem manual, funding attribution e boundaries com tax/accounting."
non_objectives: "Executar integração externa, Sandbox, piloto, produção ou efeito real; definir valores comerciais, campanhas, cupons, budgets ou alçadas reais; definir calendário contratual, proration, metering, rating, invoice, cobrança, ledger, imposto, contabilidade, FX, provider ou ASAAS; substituir as decisões transversais `D-05` a `D-14` ou ampliar a liberação local-only de `D-00`."
owner: "Arquitetura / Billing / Produto / Financeiro / Segurança"
status: "Accepted"
date: "2026-08-25"
version: "1.3"
keywords: "promotion lifecycle, campaign governance, pause, retire, expire, revoke, four-eyes, MFA, append-only audit, manual promotion, funding attribution, AI delegated decision"
related_files: "docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00038-billing-catalog-pricing-promotions.md`, `docs/product/use-cases/UC-00039-billing-contract-subscription-amendments.md`, `docs/product/use-cases/UC-00040-billing-usage-rating-invoice-close.md`, `docs/delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md`, `harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md`, `docs/adrs/ADR-0019-database-per-tenant.md`, `docs/adrs/ADR-0023-agnostic-payment-provider-integration.md`, `docs/adrs/ADR-0027-catalogo-global-faturamento-local.md`, `docs/adrs/ADR-0037-boundary-fisico-entitlements-billing.md`, `docs/adrs/ADR-0038-pricing-tipado-moeda-cadencia.md`, `docs/adrs/ADR-0039-taxonomia-beneficios-promocionais.md`, `docs/adrs/ADR-0040-elegibilidade-promocional-seguranca-cupons.md`, `docs/adrs/ADR-0041-stacking-waterfall-promocional-deterministico.md`, `docs/adrs/ADR-0042-capacidade-redemption-promocional-concorrente.md"
code_references: "AS-IS em `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/package-info.java`, `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/BillingApi.java` e `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/`; state machines, policies, commands, ports, stores, scheduler e contratos desta ADR são destinos planejados e ainda não existem."
principal_statement: "Adotar lifecycles independentes, effective-dated e append-only para versões de promoção, campanha, lote de cupons e capacidade. Publicação torna conteúdo imutável e exige validação, simulação, impact preview, autorização governada e outbox; pausa impede novas reservas e honra as existentes por padrão; retirada, expiração e revogação nunca apagam história; desconto manual somente existe como artefato promocional versionado submetido ao mesmo pipeline. A solução permanece no monólito modular e não usa workflow engine, microserviço ou provider."
---

# ADR-0043 - Governança e lifecycle operacional promocional

- Document ID: `ADR-0043`
- Primary Nature: `Decisao`
- Objective: Definir lifecycle operacional, publicação governada, pausa, retirada, expiração, revogação, descontos de origem manual, funding attribution e controles de segurança para promoções seller-owned do Contador Fiscal.
- Scope: `PromotionVersion`, `CampaignVersion`, `CouponBatchVersion`, `PromotionCapacityPolicyVersion`, estados e transições append-only, vigência, publicação, simulação, impact preview, outbox, segregação de funções, MFA, auditoria, remediação de revogação, artefatos promocionais de origem manual, funding attribution e boundaries com tax/accounting.
- Non-objectives: Executar integração externa, Sandbox, piloto, produção ou efeito real; definir valores comerciais, campanhas, cupons, budgets ou alçadas reais; definir calendário contratual, proration, metering, rating, invoice, cobrança, ledger, imposto, contabilidade, FX, provider ou ASAAS; substituir as decisões transversais `D-05` a `D-14` ou ampliar a liberação local-only de `D-00`.
- Keywords: promotion lifecycle, campaign governance, pause, retire, expire, revoke, four-eyes, MFA, append-only audit, manual promotion, funding attribution, AI delegated decision
- Related Files: `docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00038-billing-catalog-pricing-promotions.md`, `docs/product/use-cases/UC-00039-billing-contract-subscription-amendments.md`, `docs/product/use-cases/UC-00040-billing-usage-rating-invoice-close.md`, `docs/delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md`, `harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md`, `docs/adrs/ADR-0019-database-per-tenant.md`, `docs/adrs/ADR-0023-agnostic-payment-provider-integration.md`, `docs/adrs/ADR-0027-catalogo-global-faturamento-local.md`, `docs/adrs/ADR-0037-boundary-fisico-entitlements-billing.md`, `docs/adrs/ADR-0038-pricing-tipado-moeda-cadencia.md`, `docs/adrs/ADR-0039-taxonomia-beneficios-promocionais.md`, `docs/adrs/ADR-0040-elegibilidade-promocional-seguranca-cupons.md`, `docs/adrs/ADR-0041-stacking-waterfall-promocional-deterministico.md`, `docs/adrs/ADR-0042-capacidade-redemption-promocional-concorrente.md`
- Code References: AS-IS em `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/package-info.java`, `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/BillingApi.java` e `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/`; state machines, policies, commands, ports, stores, scheduler e contratos desta ADR são destinos planejados e ainda não existem.
- Principal Decision: Adotar lifecycles independentes, effective-dated e append-only para versões de promoção, campanha, lote de cupons e capacidade. Publicação torna conteúdo imutável e exige validação, simulação, impact preview, autorização governada e outbox; pausa impede novas reservas e honra as existentes por padrão; retirada, expiração e revogação nunca apagam história; desconto manual somente existe como artefato promocional versionado submetido ao mesmo pipeline. A solução permanece no monólito modular e não usa workflow engine, microserviço ou provider.
- Date: 2026-08-25
- Status: Accepted
- Version: 1.3
- Decision Provenance: `AI_DELEGATED`
- Decision Actor: `AI_AGENT — Codex (OpenAI)`
- Authority Basis: `OWNER_DELEGATION — AUTH-BILLING-2026-08-25-001`
- Human Review Status: `NOT_PERFORMED`
- Reviewability: `OPEN`
- Authors: Codex (Artificial Intelligence), sob autoridade delegada
- Owners: Arquitetura / Billing / Produto / Financeiro / Segurança
- Reviewers: AI — análise de arquitetura, domínio, segurança e custo; Human — N/A, nenhuma revisão substantiva desta decisão foi realizada
- Stakeholders: Proprietário do SaaS, Produto, Comercial, Financeiro, Backend, Frontend, Segurança, Controladoria, Operações e tenants contratantes
- Supersedes: N/A; fecha o boundary `D-04.4-E` preservado pelos ADR-0039, ADR-0040, ADR-0041 e ADR-0042.
- Superseded by: N/A

---

# 0. Decision Provenance

| Campo | Valor |
| --- | --- |
| Decision Key | `D-04.4-E` |
| Selected Option | `Opção A` |
| Decision Provenance | `AI_DELEGATED` |
| Decision Actor | `AI_AGENT — Codex (OpenAI)` |
| Authority Basis | `OWNER_DELEGATION — AUTH-BILLING-2026-08-25-001` |
| Authority holder | Solicitante, declarado proprietário do SaaS; identidade não verificada criptograficamente pelo repositório |
| Human Review Status | `NOT_PERFORMED` |
| Reviewability | `OPEN` |
| Decision Date | `2026-08-25` |
| Decision Basis | Documentação vigente do projeto, arquitetura inicial de monólito modular, custo reduzido e operação em VPS antes de produção. |

O proprietário do SaaS autorizou o Codex a decidir autonomamente os próximos gates
de Billing, mas não selecionou esta opção nem revisou seu conteúdo. O estado
`Accepted` decorre da autoridade delegada acima e não deve ser interpretado como
aprovação, coautoria ou revisão humana.

Esta é a primeira decisão de Billing registrada com proveniência
`AI_DELEGATED` sob `AUTH-BILLING-2026-08-25-001`. Uma revisão humana futura pode
confirmá-la, alterá-la ou substituí-la por nova versão/ADR, preservando este
registro e sua proveniência original. Até essa revisão, `Reviewability: OPEN`
permanece explícito em qualquer inventário ou relatório que represente a decisão.

---

# 1. Context

Os ADR-0039, ADR-0040, ADR-0041 e ADR-0042 separam, respectivamente, a natureza do
benefício promocional, eligibility e segurança de cupons, combinação stateless e
capacidade/redemption concorrente. Ainda faltava governar como cada artefato entra
e sai de operação, quem pode publicá-lo, como uma campanha é pausada sem corromper
reservas e como uma revogação emergencial preserva evidência e exige remediação.

Sem lifecycle próprio, uma edição de campanha poderia alterar silenciosamente um
snapshot já aceito; uma pausa poderia liberar capacidade ainda comprometida; um
cupom revogado poderia desaparecer da auditoria; ou um operador poderia aplicar
"desconto manual" diretamente na fatura, contornando taxonomia, eligibility,
stacking, caps e segregação de funções.

O projeto ainda não entrou em produção, opera com objetivo de baixo custo em VPS e
adota monólito modular com Clean Architecture. Introduzir workflow engine,
microserviço ou infraestrutura distribuída agora elevaria custo e superfície
operacional sem resolver uma necessidade comprovada. Ao mesmo tempo, lifecycle e
auditoria não podem depender de `if` em controller, flags mutáveis, Redis ou ação
manual fora do domínio.

`D-00 = RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only` permite
implementação e testes herméticos locais. Esta ADR fecha a decisão conceitual
`D-04.4-E`, com proveniência de IA rastreável e revisão humana aberta.

---

# 2. Decision Statement

## 2.1 Autoridades separadas e lifecycles independentes

Quatro famílias de artefatos possuem identidade, versão, hash, vigência, estado e
stream de transições próprios:

| Artefato | Autoridade exclusiva | O que não pode decidir |
| --- | --- | --- |
| `PromotionVersion` | Conteúdo e pacote de benefícios tipados do ADR-0039. | Não decide audiência, cupom, stacking, budget, imposto ou invoice. |
| `CampaignVersion` | Orquestra bindings exatos entre promoção, audiência, combinação, lote e funding attribution. | Não reescreve benefício, policy referenciada, código de cupom ou consumo. |
| `CouponBatchVersion` | Governa emissão/lote, canal, validade operacional e binding seguro do ADR-0040. | Não armazena código/digest em audit/evento, não cria desconto e não consome capacidade. |
| `PromotionCapacityPolicyVersion` | Declara limites e política stateful cuja execução pertence ao ADR-0042. | Não calcula preço, não escolhe candidata e não modifica redemption histórico. |

Uma transição em uma família nunca edita, republica ou muda automaticamente o
estado da outra. Uma `CampaignVersion` referencia versões e hashes exatos; alterar
qualquer binding material cria nova versão de campanha. Dependências são avaliadas
como gates independentes no instante confiável da operação, com reason code
tipado. Não existe `latest`, herança silenciosa, cascade update ou fallback.

Todos os artefatos são seller-owned e residem conceitualmente no catálogo/control
plane `saas_platform`, dentro do ownership de `contexts.billing`. Snapshots aceitos,
markers de aplicação e faturas continuam no banco dedicado do tenant conforme os
ADR-0019, ADR-0027, ADR-0041 e ADR-0042. Não há XA, FK ou join cross-store.

## 2.2 Estado fechado e transições permitidas

Cada versão usa, quando aplicável, o mesmo vocabulário operacional fechado, mas
mantém sua própria instância de lifecycle:

```text
DRAFT -> REVIEW_PENDING -> PUBLISHED -> ACTIVE
                         -> SCHEDULED -> ACTIVE
ACTIVE <-> PAUSED
PUBLISHED | SCHEDULED | ACTIVE | PAUSED -> RETIRED
PUBLISHED | SCHEDULED | ACTIVE | PAUSED -> REVOKED
PUBLISHED | SCHEDULED | ACTIVE | PAUSED -> EXPIRED
```

`REVIEW_PENDING -> DRAFT` é permitido somente para correção antes da publicação e
gera evento de revisão rejeitada ou devolvida. Não existe transição direta de
`DRAFT` para estado operacional. `RETIRED`, `EXPIRED` e `REVOKED` são terminais.
Correção posterior exige nova versão ligada à anterior por lineage.

| Estado | Semântica normativa |
| --- | --- |
| `DRAFT` | Editável por concorrência otimista; não é selecionável, publicável em snapshot, reservável ou consumível. |
| `REVIEW_PENDING` | Conteúdo candidato congelado por hash para revisão; alteração o devolve a `DRAFT` como nova revisão. |
| `PUBLISHED` | Aprovado, materialmente imutável e resolvível, porém ainda não ativo até o boundary explícito de ativação. |
| `SCHEDULED` | Publicado e imutável, aguardando `effectiveFrom` futuro. |
| `ACTIVE` | Pode participar de novas operações somente se todas as demais policies, referências, vigências e gates também estiverem válidos. |
| `PAUSED` | Reversível; bloqueia novas reservas/aplicações autoritativas, sem apagar ou reescrever evidência anterior. |
| `RETIRED` | Encerrado por decisão operacional; indisponível para novas reservas, mas permanentemente resolvível para replay. |
| `EXPIRED` | Encerrado pelo limite temporal exclusivo; possui os mesmos invariantes históricos de `RETIRED`. |
| `REVOKED` | Encerrado irreversivelmente por incidente ou risco; bloqueia novas operações e exige plano de remediação tipado. |

Uma rejeição de revisão é fato auditável, não estado operacional adicional.
Arquivamento visual, ocultação de UI ou cache não altera lifecycle autoritativo.
Estado ou transição desconhecida falha fechada.

## 2.3 Imutabilidade, vigência e relógio

A partir de `PUBLISHED` ou `SCHEDULED`, conteúdo, referências, benefício, scope,
funding attribution, políticas, effective interval, hash e evidência de aprovação
são imutáveis. Alteração material cria nova versão e novo processo de publicação.

Toda versão operacional declara `effectiveFrom` inclusivo e, quando bounded,
`effectiveTo` exclusivo como instantes UTC. O timezone e o calendário usados por
contrato, `FREE_PERIOD`, invoice e proration seguem exclusivamente o ADR-0044;
esta ADR usa tempo UTC apenas para governança do catálogo.

Ativação ou expiração não depende exclusivamente de um scheduler. Eligibility,
reserva e aplicação verificam sincronicamente estado e intervalo efetivo usando o
relógio confiável da plataforma. Um job idempotente e econômico pode materializar
transições `SCHEDULED -> ACTIVE` e `ACTIVE|PAUSED|SCHEDULED -> EXPIRED`, mas atraso
do job nunca mantém uma versão efetivamente expirada utilizável.

Backdating de publicação, ativação ou revogação é proibido. Uma correção que
precise representar efeito passado usa evento compensatório e a autoridade do
domínio correspondente; nunca altera a timeline original.

Para uma mesma identidade/slot lógico, versões incompatíveis não podem estar
simultaneamente ativas. Segmentos comerciais intencionalmente paralelos exigem
bindings e scopes distintos e explícitos; sobreposição ambígua impede publicação.

## 2.4 Semântica de pausa e retomada

`ACTIVE -> PAUSED` entra em vigor no commit autoritativo da transição e:

- impede novas reservations, commit grants e aplicações da versão afetada;
- faz preview/eligibility informar indisponibilidade tipada, sem apresentá-la como
  benefício resgatável;
- permite concluir somente reservation que já atingiu `COMMIT_GRANTED` no
  ADR-0042; reservation ainda apenas `RESERVED` deve ser liberada ou expirar por
  transição idempotente, e ownership ambíguo deve ser colocado em quarentena;
- não altera `AcceptedPromotionCombinationSnapshot`, contrato, redemption,
  entitlement, rating ou invoice histórico;
- não muda o estado dos artefatos referenciados ou dependentes;
- publica evento por outbox e invalida somente caches derivados.

O comportamento padrão obrigatório é `HONOR_COMMIT_GRANTED_ONLY`: o ponto de não
retorno seguro pertence ao grant de commit; operações ainda reversíveis não
atravessam a pausa. Outra disposição exige decisão formal futura e não pode surgir
como flag, default de adapter ou ação manual.

`PAUSED -> ACTIVE` exige comando explícito, autorização vigente, versão ainda
dentro do intervalo efetivo, dependências disponíveis e ausência de revogação.
Retomada nunca estende `effectiveTo`, renova reservation ou cria nova versão por
inferência. Se a vigência terminou, o estado efetivo é `EXPIRED`.

## 2.5 Retirada e expiração

`RETIRED` é uma decisão operacional explícita; `EXPIRED` decorre do término da
vigência. Ambos impedem novas reservas e novos vínculos, mas preservam:

- resolução por identidade, versão, schema e hash;
- snapshots aceitos e breakdowns históricos;
- somente reservations anteriores em `COMMIT_GRANTED` ainda aptas a concluir pelo
  ADR-0042; as demais seguem release/expiry/quarantine;
- consumos, releases, reversões e journals append-only;
- evidência de aprovação, funding attribution, auditoria e outbox;
- replay determinístico de pricing, eligibility e combinação.

Retirar ou expirar uma `CampaignVersion` não edita suas `PromotionVersion`,
`CouponBatchVersion` ou `PromotionCapacityPolicyVersion`. Retirar um lote não
revoga uma promoção usada sem aquele lote. Toda indisponibilidade é explicada pelo
gate exato que falhou.

Não há delete, hard delete, reutilização de ID, alteração de hash, atualização em
massa de snapshots ou cascade de estado. Reuso comercial exige nova versão.

## 2.6 Revogação emergencial e remediação tipada

`REVOKED` é reservado a fraude, comprometimento, erro material ou risco que exija
bloqueio imediato. A revogação é prospectiva: impede novas eligibility decisions
aceitáveis, combinações para commit, reservations e aplicações a partir do commit
autoritativo, mas nunca finge que fatos anteriores não ocorreram.

O comando de revogação exige `RevocationRemediationPlan` versionado e sem default,
contendo, no mínimo:

- reason code fechado e referência de incidente não sensível;
- artefato, versão/hash, scope e instante efetivo exatos;
- disposição de reservations ainda não consumidas:
  `HONOR_COMMIT_GRANTED_ONLY` ou `QUARANTINE_UNCOMMITTED_RESERVATIONS`;
- disposição de aceites ainda não faturados:
  `PRESERVE_ACCEPTED_FACTS` ou `QUARANTINE_FOR_REMEDIATION`;
- disposição histórica:
  `PRESERVE_CONSUMED_FACTS` ou `TYPED_COMPENSATION_REQUIRED`;
- owner operacional, prazo de revisão e correlation/causation IDs;
- referências das policies de autorização, auditoria e redaction aplicadas.

Quarantine bloqueia progressão e liberação automática até reconciliação
autoritativa; não cancela contrato, invoice ou payment, não devolve capacidade e
não cria refund. A disposition padrão de capacidade após consumo é
`NO_CAPACITY_RETURN`: cancelar, corrigir, creditar ou devolver dinheiro não repõe
budget. Uma policy publicada pode optar por
`RETURN_ON_CONFIRMED_COMPENSATION`, mas somente depois de a compensação causal e
idempotente estar confirmada pelas autoridades dos ADRs-0046/0047; nunca por mera
solicitação, timeout ou status ambíguo. Compensação exigida cria um fato vinculado
na autoridade adequada e nunca edita ou apaga redemption/snapshot original.
Cancelamento/correção, crédito/refund, fiscal e subledger permanecem separados nos
ADRs-0046, 0047, 0048 e 0049.

Revogação não pode ser desfeita. Uma versão corrigida passa por novo ciclo completo.
Falha ao persistir estado, auditoria e outbox na mesma transação impede a revogação
de ser declarada concluída.

## 2.7 Publicação governada

Cada transição de publicação executa o seguinte pipeline bounded e fail-closed:

1. recebe command idempotente, expected version e fingerprint canônico;
2. valida schema, tipos, bounds, referências exatas, hashes, scopes e vigência;
3. valida compatibilidade entre promotion, campaign, coupon, combination e
   capacity policies, sem resolver `latest`;
4. executa simulações determinísticas sobre fixtures sintéticas/sanitizadas;
5. produz impact preview imutável e sanitizado;
6. classifica o risco da mudança por policy versionada;
7. coleta decisão de aprovação autorizada, evidência de SoD e MFA aplicável;
8. verifica novamente hash, expected version e boundaries contra TOCTOU;
9. persiste transição, evidência de governança e outbox atomicamente;
10. permite ativação somente no boundary temporal e operacional explícito.

Validação rejeita benefício vazio, tipo desconhecido, referência ausente, funding
incompatível, intervalo inválido, overlap ambíguo, batch inseguro, capacity policy
incompleta, conflito de target, limite não bounded ou policy de autorização
ausente. Ausência nunca vira default, `latest`, zero ou aprovação implícita.

Simulação não reserva capacidade, não cria contrato, invoice, entitlement,
redemption, outbox financeiro ou chamada externa. Ela cobre cenários nominais,
limites, stacking, caps, estados, mudança temporal e falhas esperadas, preservando
versões do evaluator e hashes dos vetores usados.

Impact preview informa referências afetadas, quantidade agregada de bindings e
riscos de ativação/pausa/retirada, sem expor tenant PII, raw coupon, digest, budget
competitivo, segredo ou payload. Ele não promete efeito contábil ou tributário.

## 2.8 Segregação de funções, MFA e alçadas

Esta ADR fixa os enforcement points; o ADR-0050 é a autoridade transversal para
roles/capabilities, matriz de alçadas, approval seals, freshness de MFA,
delegações e identidade efetiva.

Os invariantes mínimos são:

- quem propõe uma versão não pode aprovar sua própria publicação ou agendamento;
- publicação, retomada após pausa e mudança material exigem four-eyes;
- ação privilegiada exige identidade efetiva, policy de autorização versionada e
  evidência de MFA, sem persistir token, segredo ou fator;
- pause, retire e revoke exigem reason code, expected version e auditoria;
- revoke pode usar caminho break-glass por um ator autorizado para bloquear risco,
  mas exige MFA, incidente, escopo mínimo, outbox e revisão posterior pendente;
- nenhuma role recebe acesso por nome hardcoded fora da policy transversal;
- ausência, stale evidence ou conflito de ator falha fechada;
- frontend nunca decide autorização, risco, aprovação ou transição.

Nenhuma publicação operacional pode ser implementada ou habilitada sem materializar
e testar o ADR-0050, inclusive segundo aprovador humano distinto e MFA. Um agente
de IA pode preparar draft, validação, simulação e impact preview, mas não pode ser
checker/aprovador financeiro em runtime; essa proibição é separada da proveniência
`AI_DELEGATED` desta decisão.

## 2.9 Auditoria e outbox append-only

Toda tentativa e toda transição relevante gera evidência append-only com:

- identidade/tipo do ator e identidade efetiva;
- artefato, versão, schema e hashes antes/depois;
- ação solicitada, resultado e reason codes;
- policy de autorização, decisão de aprovação e evidência referencial de MFA;
- hashes de validation, simulation e impact preview;
- instante confiável, idempotency key, correlation e causation IDs;
- referência de incidente/remediação para revogação;
- estado de human review quando a própria decisão tiver proveniência de IA.

Audit record não contém raw coupon, digest, segredo, credencial, token MFA, PII de
cliente do tenant, payload de provider ou conteúdo arbitrário. Correção de
metadado auditável é novo evento vinculado, nunca update destrutivo.

O fato de lifecycle é persistido com sua publicação de outbox na mesma transação
do store da plataforma. Consumidores são idempotentes e não podem se tornar
autoridade do estado. Retry não duplica transição; mesma idempotency key com
fingerprint divergente é rejeitada. Timeout ambíguo consulta o journal antes de
qualquer nova tentativa.

## 2.10 Desconto de origem manual

Não existe campo `manualDiscount`, override de total, edição direta de invoice,
linha negativa, SQL operacional ou comando administrativo capaz de ignorar o
pipeline promocional.

Um benefício solicitado manualmente exige um
`ManualPromotionAuthorizationVersion`, seller-owned, imutável após publicação e
ligado a uma `PromotionVersion` exata. O artefato declara:

- escopo exato de tenant/billing account por identificadores opacos;
- benefício e versão promocional, finalidade e reason code tipados;
- effective interval bounded e quantidade máxima de usos;
- funding attribution e referências de classificação;
- proposer, approver, policy de alçada e evidência de MFA;
- correlation, lineage, schema e hash canônicos.

"Manual" identifica o canal de origem, não uma exceção às regras. O artefato
passa pelo mesmo lifecycle, publication pipeline, eligibility, combinação,
capacidade/reservation e snapshot aceito dos ADR-0040, ADR-0041 e ADR-0042. Um
benefício one-off usa capacidade tipada e limitada; não altera contador à mão.

Suporte, frontend, provider e banco do tenant não podem escolher valor, target,
stacking ou aplicação fora desse artefato. Goodwill credit, credit memo, refund,
write-off e correção de invoice não são desconto manual e permanecem nos gates
financeiros próprios.

## 2.11 Funding attribution e handoff fiscal/contábil

Toda versão publicada declara funding attribution tipada:

- `SELLER_FUNDED`;
- `PARTNER_FUNDED`;
- `CO_FUNDED`.

A classificação registra somente origem econômica/provenance do benefício e,
quando aplicável, referências versionadas de participação. GV Software permanece
seller e credora; o tenant contratante permanece payer. Parceiro não vira seller,
credor ou provider customer, e clientes atendidos pelo tenant não entram na
relação de cobrança.

O artefato também carrega um `TaxAccountingHandoff` tipado, com estado e
referências de classificação versionadas aos ADRs-0048 e 0049. Esses ADRs
fecharam o boundary arquitetural, mas não atestaram dados nem pareceres
fiscais/contábeis; enquanto a evidência competente estiver ausente, o handoff
registra somente `PENDING_CLASSIFICATION` em draft/simulação e ativação produtiva
falha fechada.

Esta ADR não calcula imposto, não define base fiscal, não reconhece receita, não
cria lançamento, payable, receivable, settlement, reembolso de parceiro ou FX.
Fiscal é autoridade do ADR-0048; subledger gerencial/MRR é autoridade do
ADR-0049, sem substituir contabilidade estatutária.
Funding attribution nunca é interpretada como lançamento financeiro implícito.

## 2.12 Falhas, consistência e concorrência

Transições usam optimistic concurrency, expected version e compare-and-set. A
ordem canônica de validação e reason codes é estável. Uma operação que encontra
versão stale, hash divergente, aprovação inválida, MFA ausente, dependência
inativa, overlap, vigência encerrada ou outbox indisponível não produz estado
parcial.

Cache é somente projeção derivada. Leitura ausente ou cache stale consulta a
autoridade PostgreSQL; falha de autoridade não vira estado ativo. Redis, fila,
scheduler, frontend, arquivo de configuração e provider não podem autorizar
transição.

Mudança concorrente entre review e publish é detectada pelo hash congelado. Uma
nova revisão exige novo fingerprint e nova aprovação. Batch ou campanha grande
não usa transação cross-tenant: publica uma versão global, e consumidores
tenant-local materializam somente evidência própria pelos protocolos já aprovados.

## 2.13 Clean Architecture e custo operacional

O domínio futuro contém state machines, value objects, invariantes, transition
policies, risk classification e domain events puros. Ele não importa Spring, JPA,
Jackson, Redis, Keycloak, scheduler, rede, banco, frontend, provider ou ASAAS.

A camada de aplicação orquestra commands/queries e usa ports para:

- carregar e persistir versão exata;
- validar referências publicadas;
- obter relógio confiável;
- avaliar autorização/MFA/SoD;
- executar simulation e impact preview;
- registrar auditoria e outbox;
- projetar status e invalidar cache derivado.

Adapters isolam PostgreSQL da plataforma, IAM, scheduler, audit/outbox e transporte.
Frontend apenas edita draft permitido, solicita ações e apresenta estado/evidência
sanitizados. Nenhuma regra de lifecycle é reimplementada no cliente.

A primeira implementação, sob o escopo local-only de `D-00`, permanece como sub-slice coeso de
`contexts.billing` no monólito modular. Usa PostgreSQL e o mecanismo de outbox já
adotado pelo projeto, com job idempotente leve para boundaries temporais. Não
adota Temporal, Camunda, rules engine, broker novo, microserviço ou banco adicional.
Ports preservam extração futura se volume, SLO, hot keys ou ownership justificarem.

## 2.14 Boundary da aprovação

Esta decisão fecha `D-04.4-E — Opção A` e, com os ADR-0039 a ADR-0042, conclui as
decisões internas de `D-04.4` sobre promoções. Ela não libera uso real.

As decisões complementares `D-05` a `D-14` foram fechadas nos ADRs canônicos por
Codex sob `AUTH-BILLING-2026-08-25-001`, com provenance `AI_DELEGATED`, revisão
humana `NOT_PERFORMED` e `Reviewability: OPEN`. Isso inclui ADR-0044 a ADR-0051 e as
revisões vigentes dos ADR-0023 a ADR-0025. `D-00` permite implementação hermética
local e não autoriza chamada externa, Sandbox, piloto ou produção.

Continuam pendentes, sem false green, os contratos/artefatos executáveis e as
evidências externas: OpenAPI/DDL/UI, merchant/capabilities/tarifas ASAAS, PCI,
Sandbox, dados e pareceres legais/fiscais/contábeis, medições SLO/backup e aceite
de piloto.

Nenhum valor, promoção, campanha, cupom, role, threshold, tabela, migration,
package, classe, endpoint, OpenAPI, UI, job, evento físico, cache, rollout, tenant,
segredo ou chamada ASAAS/provider foi aprovado ou criado por esta ADR.

---

# 3. Decision Drivers

- preservar snapshots, contratos e consumos contra edição retroativa;
- separar conteúdo, campanha, lote e capacidade em autoridades independentes;
- oferecer pausa reversível sem dupla utilização ou liberação indevida;
- tornar revogação rápida, irreversível, explicável e remediável;
- impedir desconto manual fora da taxonomia e do pipeline promocional;
- aplicar SoD, MFA e auditoria nos boundaries corretos sem hardcode de roles;
- manter funding como attribution sem trocar seller/payer;
- entregar tax/accounting às autoridades próprias sem criar efeito implícito;
- assegurar publicação reproduzível por validation, simulation e impact preview;
- usar arquitetura limpa e custo compatível com uma VPS pré-produção;
- evitar workflow engine, microserviço e infraestrutura prematura;
- manter provider e ASAAS fora da governança promocional.

---

# 4. Considered Options

## Option A: State machines versionadas no monólito modular

Description: Lifecycles independentes e append-only, publicação imutável por
pipeline governado, outbox transacional, scheduler leve e enforcement síncrono,
implementados futuramente dentro de `contexts.billing` por ports.

Pros:

- preserva Clean Architecture, replay e isolamento de responsabilidades;
- usa PostgreSQL e operação já previstos para a VPS;
- fornece segurança forte sem novo produto operacional;
- mantém caminho de extração futura sem antecipar microserviço;
- unifica desconto manual e automático sob as mesmas regras.

Cons:

- requer state machines, validators e evidência de aprovação explícitos;
- aumenta o volume de eventos/snapshots de governança;
- depende da materialização e evidência das políticas do ADR-0050 antes de operar;
- scheduler e reconciliação precisam ser idempotentes.

## Option B: Workflow engine dedicado

Description: Usar Temporal, Camunda ou solução equivalente para publicação,
aprovação, pausa e revogação.

Pros:

- oferece visualização e timers prontos;
- facilita workflows humanos muito longos e variáveis.

Cons:

- eleva memória, operação, backup, atualização e observabilidade na VPS;
- duplica parte da state machine e do outbox;
- introduz lock-in e boundary distribuído antes de demanda comprovada;
- não substitui invariantes de domínio, idempotência ou auditoria.

Disposition: Rejected for the initial architecture.

## Option C: Flags mutáveis e aprovação administrativa direta

Description: Manter colunas `active/paused`, editar campanhas in-place e permitir
desconto manual por endpoint privilegiado.

Pros:

- implementação inicial aparentemente menor;
- pouca modelagem de domínio.

Cons:

- destrói replay, versionamento e explicabilidade;
- permite bypass de eligibility, stacking, capacity e SoD;
- produz comportamento dependente de ordem e defaults;
- torna revogação, auditoria e reconciliação inseguras.

Disposition: Rejected.

## Option D: Microserviço de promoções desde o início

Description: Extrair catálogo, workflow e lifecycle para serviço independente.

Pros:

- deploy e escala independentes;
- boundary de equipe explícito.

Cons:

- adiciona rede, autenticação service-to-service, deploy, tracing e falhas parciais;
- aumenta custo sem volume, SLO ou ownership que o justifique;
- complica consistência com catálogo/capacidade antes da produção.

Disposition: Rejected for now; ports keep future extraction possible.

---

# 5. Decision Outcome

A **Option A** foi selecionada autonomamente pelo `Decision Actor: Codex (IA)` sob
`AUTH-BILLING-2026-08-25-001`. `Human Review: NOT_PERFORMED` e
`Reviewability: OPEN` permanecem parte normativa da proveniência.

Flexibilidade promocional será obtida por versões, bindings, scopes e policies
tipadas. Não será obtida por edição in-place, override, workflow executável,
desconto direto na invoice ou integração com provider.

---

# 6. Consequences

## Positive Consequences

- Estado operacional e conteúdo histórico permanecem reproduzíveis.
- Pause, retire, expire e revoke possuem efeitos distintos e fechados.
- Reservas existentes não são liberadas por acidente durante pausa.
- Emergência bloqueia novas aplicações sem apagar fatos anteriores.
- Toda publicação possui validação, simulação, impacto, aprovação e outbox.
- Desconto originado por humano percorre exatamente o pipeline promocional.
- Funding não contamina seller/payer nem antecipa accounting.
- Custo inicial permanece compatível com monólito modular em VPS.

## Negative Consequences

- A modelagem cria mais versões, hashes, evidências e reason codes.
- Publicação não poderá operar antes da materialização e dos testes do ADR-0050.
- Four-eyes requer processo organizacional e identidade efetiva distinta.
- Revogação com quarantine pode exigir intervenção e reconciliação posteriores.

## Neutral Consequences

- `PUBLISHED` não significa `ACTIVE`.
- Pausa é reversível; revogação não é.
- Expiração não remove capacidade/reservas existentes por inferência.
- Job pode materializar tempo, mas o gate síncrono continua autoritativo.
- Proveniência de IA torna a decisão revisável, não automaticamente inválida.
- `D-00` libera implementação hermética local, sem capability ou efeito real.

---

# 7. Impact

## Compatibility with prior decisions

| Decisão | Efeito desta ADR |
| --- | --- |
| ADR-0000 | Aplica contrato documental e registra decisão aceita com proveniência `AI_DELEGATED`, sem atribuir revisão humana inexistente. |
| ADR-0019 | Mantém catálogo global separado dos bancos dedicados dos tenants. |
| ADR-0023 | Mantém provider/ASAAS fora de lifecycle e publicação promocional. |
| ADR-0027 | Posiciona as versões seller-owned no control plane e preserva snapshots tenant-local. |
| ADR-0037 | Mantém o slice dentro de `contexts.billing`, sem novo módulo ou aresta pública. |
| ADR-0038 | Preserva preço/rounding pinados e impede mutação promocional de `PriceVersion`. |
| ADR-0039 | Governa o lifecycle operacional da taxonomia sem ampliar benefit types. |
| ADR-0040 | Pausa/revoga gates sem expor ou editar raw coupon/digest. |
| ADR-0041 | Lifecycle não recombina nem altera resultado/snapshot histórico. |
| ADR-0042 | Pause honra reservas por padrão; revoke usa quarantine/remediação sem liberar capacidade silenciosamente. |

## Impact by area

- Backend: futuras state machines e orquestração por ports no módulo Billing.
- Database: futuras versões/audit/outbox no store da plataforma; nenhum DDL aqui.
- Frontend: futura gestão de drafts e visualização sanitizada, sem autoridade.
- Security: enforcement points para SoD, MFA, break-glass e audit append-only.
- Operations: pause/resume/retire/revoke explícitos e reconciliáveis.
- Finance: funding attribution tipada, sem lançamento, imposto ou settlement.
- Provider: nenhuma capability, status, customer ou payload ASAAS participa.

---

# 8. AI Agent Considerations

Agentes que detalharem ou implementarem esta decisão devem:

1. preservar a Section 0 e nunca converter `AI_DELEGATED` em aprovação humana;
2. modelar os quatro lifecycles como autoridades independentes;
3. aceitar somente os estados e transições fechados desta ADR;
4. tornar versão publicada imutável e effective-dated;
5. impedir `latest`, fallback, cascade update e backdating;
6. bloquear novas reservations em pause e honrar as existentes por padrão;
7. preservar replay/snapshots em retire, expire e revoke;
8. exigir `RevocationRemediationPlan` e quarantine tipada;
9. implementar publication pipeline completo, sem partial publish;
10. manter validation/simulation/impact preview livres de efeito comercial;
11. aplicar SoD/MFA pelos ports e policies do ADR-0050;
12. registrar audit/outbox append-only e sanitizado;
13. representar desconto manual somente por artefato versionado;
14. manter funding attribution separada de seller, payer, tax e accounting;
15. manter domínio sem framework/I/O/provider e frontend sem autoridade;
16. não introduzir workflow engine ou microserviço no primeiro slice;
17. criar código, DDL, OpenAPI, job dormente e policy sintética somente no escopo
    hermético local de `D-00`, sem policy comercial real nem ASAAS externo;
18. preservar todos os ADRs de `D-05` a `D-14` e seus evidence gates.

---

# 9. Implementation Plan Boundary

Esta seção registra a ordem incremental autorizada localmente por `D-00`:

1. aplicar os ADRs aceitos de `D-05` a `D-14`, especialmente ADRs-0048/0049/0050,
   sem inferir implementação ou evidência externa;
2. congelar schemas de lifecycle, transition, reason, risk e remediation;
3. criar state machines e validators puros por artefato;
4. criar canonicalization, hashes e idempotency fingerprints;
5. implementar ports de store, clock, authorization, MFA, audit e outbox;
6. implementar adapter PostgreSQL platform e scheduler idempotente leve;
7. integrar publish/schedule/activate/pause/resume/retire/expire/revoke;
8. integrar artefato manual aos pipelines B → C → D;
9. integrar fiscal/subledger somente após os contracts e evidências próprias;
10. publicar API/UI somente depois de OpenAPI, RBAC, redaction e SLO aprovados;
11. provar replay, concurrency, isolation, outbox e zero provider;
12. executar rollout bounded conforme ADR-0051 antes de qualquer ativação real.

Nenhuma etapa desta lista foi iniciada por esta decisão.

---

# 10. Validation

## 10.1 Gates documentais desta decisão

- proveniência declara `AI_DELEGATED`, Codex, autoridade, ausência de revisão
  humana e revisão aberta;
- quatro lifecycles independentes e append-only estão definidos;
- estados, transições e semânticas terminais estão fechados;
- pausa bloqueia novas reservas e honra reservas existentes por padrão;
- retire/expire preservam snapshots, reservations e consumos;
- revoke é prospectivo, irreversível e exige remediação tipada;
- publicação exige validation, simulation, impact preview, aprovação e outbox;
- desconto manual somente existe por artefato versionado;
- funding não altera seller/payer nem antecipa tax/accounting;
- SoD/MFA possuem enforcement points e policy no ADR-0050; implementação e
  evidência continuam pendentes;
- arquitetura permanece monólito modular, sem workflow engine/microserviço;
- provider/ASAAS e implementação permanecem fora do escopo.

## 10.2 Gates futuros de implementação

- unit tests cobrem todas as transições válidas e inválidas por artefato;
- property tests provam que estado terminal nunca retorna a estado ativo;
- immutability tests rejeitam alteração pós-publicação e hash divergente;
- concurrency tests cobrem expected version, idempotência e timeout ambíguo;
- clock tests cobrem boundaries inclusivo/exclusivo e scheduler atrasado;
- pause tests impedem nova reserva e preservam reservation existente;
- retire/expire tests preservam replay, snapshot e consume anterior;
- revoke tests exigem remediation plan e cobrem cada quarantine/disposition;
- publication tests cobrem validation, simulation, impact preview e TOCTOU;
- transaction tests provam lifecycle, audit e outbox atômicos;
- SoD tests impedem self-approval; MFA tests falham sem evidência válida;
- break-glass tests provam escopo mínimo e review pendente;
- manual promotion tests impedem invoice override e bypass B → C → D;
- funding tests preservam GV Software como seller e tenant como payer;
- security tests impedem PII, coupon/digest, segredo e token em audit/evento;
- architecture tests mantêm domínio sem framework/I/O/provider;
- tenant tests impedem catálogo platform de carregar PII tenant-local;
- provider tests provam zero chamada ASAAS em todos os lifecycles.

Esta ADR documental não cria testes por si só; implementação e testes herméticos
locais são autorizados pela liberação separada e escopada de `D-00`.

---

# 11. Risks and Mitigations

| Risco | Mitigação obrigatória |
| --- | --- |
| Flag mutável alterar passado | Versão publicada imutável, hash e stream append-only. |
| Lifecycle de campanha corromper promoção/lote | Autoridades e transições independentes, bindings exatos. |
| Scheduler atrasado manter promoção expirada | Gate síncrono por relógio confiável em toda operação autoritativa. |
| Pause liberar budget ainda comprometido | `HONOR_EXISTING_RESERVATIONS` e authority do ADR-0042. |
| Revoke apagar fraude ou consumo | Prospectividade, terminalidade e compensação vinculada. |
| Quarantine virar release silencioso | Nenhuma liberação sem reconciliação autoritativa. |
| Operador conceder desconto direto | Somente `ManualPromotionAuthorizationVersion` pelo pipeline completo. |
| Self-approval ou conta comprometida publicar campanha | Four-eyes, MFA, policy versionada e fail-closed. |
| Break-glass virar caminho cotidiano | Incidente obrigatório, escopo mínimo e review pendente auditável. |
| Impact preview expor estratégia/PII | Agregação, redaction e proibição de coupon/digest/segredo. |
| Funding trocar partes comerciais | GV Software seller, tenant payer, attribution sem efeito financeiro. |
| Fiscal/subledger nascer por inferência | Handoff tipado para ADRs-0048/0049, sem cálculo ou lançamento aqui. |
| Workflow engine elevar custo da VPS | State machine pura, PostgreSQL/outbox e scheduler leve. |
| Monólito impedir evolução | Ports e adapters extraction-ready, sem distribuí-lo prematuramente. |
| IA ser confundida com revisor humano | Section 0 e changelog preservam `AI_DELEGATED`/`NOT_PERFORMED`. |
| Liberação local ser confundida com rollout | `D-00` permanece explícito como local-only; chamadas externas, Sandbox ASAAS, piloto BP Farias, produção, flags `ON` e efeitos reais continuam bloqueados. |

---

# 12. Related ADRs

- [ADR-0000 - Governança documental](../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md)
- [ADR-0001 - Stack e arquitetura](ADR-0001-technology-stack-and-architecture.md)
- [ADR-0019 - Database-per-tenant](ADR-0019-database-per-tenant.md)
- [ADR-0023 - Integração agnóstica de providers](ADR-0023-agnostic-payment-provider-integration.md)
- [ADR-0027 - Catálogo global e faturamento local](ADR-0027-catalogo-global-faturamento-local.md)
- [ADR-0037 - Boundary físico de Billing](ADR-0037-boundary-fisico-entitlements-billing.md)
- [ADR-0038 - Pricing tipado, moeda e cadência](ADR-0038-pricing-tipado-moeda-cadencia.md)
- [ADR-0039 - Taxonomia de benefícios promocionais](ADR-0039-taxonomia-beneficios-promocionais.md)
- [ADR-0040 - Elegibilidade promocional e segurança de cupons](ADR-0040-elegibilidade-promocional-seguranca-cupons.md)
- [ADR-0041 - Stacking e waterfall promocional](ADR-0041-stacking-waterfall-promocional-deterministico.md)
- [ADR-0042 - Capacidade e redemption promocional concorrente](ADR-0042-capacidade-redemption-promocional-concorrente.md)
- [ADR-0044 - Lifecycle contratual e proration](ADR-0044-lifecycle-contratual-proration-assinaturas.md)
- [ADR-0045 - Metering, rating e fechamento](ADR-0045-metering-rating-fechamento-fatura.md)
- [ADR-0046 - Correção e reemissão comercial](ADR-0046-correcao-cancelamento-reemissao-fatura.md)
- [ADR-0047 - Ledger, créditos e refunds](ADR-0047-ledger-creditos-refunds-disputas-writeoff.md)
- [ADR-0048 - Fatura comercial e NFS-e](ADR-0048-separacao-fatura-comercial-documento-fiscal-nfse.md)
- [ADR-0049 - Subledger e MRR](ADR-0049-subledger-tenant-local-mrr-normalizado.md)
- [ADR-0050 - RBAC, SoD e approvals](ADR-0050-rbac-sod-aprovacoes-financeiras.md)
- [ADR-0051 - SLO, capacidade e rollout](ADR-0051-slo-capacidade-rollout-billing.md)

---

# 13. References

- [REQ-00042 - Billing enterprise](../product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md)
- [UC-00038 - Catálogo, pricing e promoções](../product/use-cases/UC-00038-billing-catalog-pricing-promotions.md)
- [UC-00039 - Contratos, assinaturas e amendments](../product/use-cases/UC-00039-billing-contract-subscription-amendments.md)
- [UC-00040 - Medição, rating e fechamento](../product/use-cases/UC-00040-billing-usage-rating-invoice-close.md)
- [TP-00013 - Enterprise Billing Implementation](../delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md)
- [Manifesto de módulos](../architecture/module-registry.md)
- `AUTH-BILLING-2026-08-25-001` — registro de autoridade delegada para as decisões restantes de Billing.
- `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/package-info.java`
- `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/BillingApi.java`
- `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/`

---

# 14. Decision Lifecycle

Esta ADR está `Accepted` por decisão autônoma do Codex sob
`AUTH-BILLING-2026-08-25-001`. Não houve revisão humana. O proprietário pode
revisar com calma posteriormente; essa revisão deve adicionar evidência e novo
estado de review sem reescrever a proveniência original.

Adicionar estado, transição, mutabilidade pós-publicação, default de pause/revoke,
tipo de desconto direto, workflow engine, microserviço, troca de seller/payer ou
autoridade de tax/accounting exige nova versão formalmente aceita ou ADR sucessor.

As decisões `D-05`, `D-06`, `D-07`, `D-08`, `D-09`, `D-10`, `D-11`, `D-12`,
`D-13` e `D-14` foram fechadas em seus ADRs canônicos. `D-00` está
`RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`; evidências externas não se tornam verdadeiras
por fechamento documental.

---

# 15. Change Log

| Version | Date | Author | Provenance | Human Review | Changes |
| --- | --- | --- | --- | --- | --- |
| 1.3 | 2026-08-25 | Solicitante humano, proprietário declarado / Codex (IA), materialização | `HUMAN_EXPLICIT`; `RELEASED_WITH_SCOPE — TP-00013 local-only` | `DIRECT_RELEASE` | Libera implementação/DDL/OpenAPI/jobs/testes herméticos locais e mantém chamadas externas, policies/campanhas reais, Sandbox ASAAS, piloto BP Farias, produção, flags `ON` e efeitos reais bloqueados. |
| 1.2 | 2026-08-25 | Codex (IA) | `AI_DELEGATED` por `AUTH-BILLING-2026-08-25-001` | `NOT_PERFORMED`; `OPEN` | Reconcilia todo o texto normativo com os ADRs aceitos de `D-05`–`D-14`, especialmente ADRs-0048/0049/0050/0051; mantém `D-00` ativo e separa decisões fechadas de implementação e evidências externas pendentes. |
| 1.1 | 2026-08-25 | Codex (IA) | `AI_DELEGATED` por `AUTH-BILLING-2026-08-25-001` | `NOT_PERFORMED` | Padroniza metadados de provenance; fixa pause/revoke em `HONOR_COMMIT_GRANTED_ONLY`, capacity return em `NO_CAPACITY_RETURN` salvo `RETURN_ON_CONFIRMED_COMPENSATION`, e reconcilia as decisões subsequentes sem liberar `D-00`. |
| 1.0 | 2026-08-25 | Codex (IA) | `AI_DELEGATED` por `AUTH-BILLING-2026-08-25-001` | `NOT_PERFORMED` | Seleciona autonomamente `D-04.4-E — Opção A`; define lifecycles separados e append-only, publicação governada, pause/retire/expire/revoke, remediação, desconto manual versionado, funding handoff, SoD/MFA/audit e arquitetura de baixo custo no monólito modular. |

---

# 16. Repository Structure

Qualquer implementação futura permanece como sub-slice interno de
`contexts.billing`, com domínio puro, aplicação por ports e adapters platform/
tenant conforme ADR-0037. Este documento não cria package, módulo, tabela,
migration track, cache, serviço, scheduler, endpoint ou diretório.

---

# 17. Review Process

1. Revisão humana futura registra revisor, data, escopo e resultado sem alterar a
   provenance original `AI_DELEGATED`.
2. Confirmação pode mudar `Human Review` para evidência correspondente em nova
   versão, preservando no changelog que a v1.0 não foi revisada por humano.
3. Discordância material produz nova versão ou ADR sucessor com rationale.
4. Mudança editorial pode incrementar versão menor, sem transformar autor/revisor.
5. Alteração normativa exige revisão de Arquitetura, Billing, Produto, Financeiro
   e Segurança segundo a policy vigente naquele momento.
6. Nenhuma revisão documental amplia a liberação local-only de `D-00` para efeito externo.

---

# 18. Notes

Lifecycle responde se um artefato publicado pode aceitar nova operação agora;
eligibility responde se uma candidata se aplica; combination responde qual pacote
vence; capacity/redemption responde se o conjunto stateful pode ser reservado e
consumido. Nenhuma dessas autoridades substitui a outra.

O registro explícito de IA permite auditoria e revisão posterior sem fingir uma
aprovação humana inexistente. Sob `D-00`, conceitos, state machines, policies,
ports, stores, jobs e contratos podem ser materializados localmente pelos planos
TP-00013; nenhuma capability deve ser inferida sem evidência reproduzível.
