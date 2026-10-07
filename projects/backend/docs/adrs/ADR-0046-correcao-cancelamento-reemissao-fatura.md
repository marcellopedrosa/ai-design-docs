---
document_id: "ADR-0046"
primary_nature: "Decisao"
objective: "Fechar `D-07` definindo taxonomia nao ambigua, imutabilidade, reenvio, regeneracao de representacao, void pre-effect, replacement e credit/debit memo para faturas comerciais."
scope: "Draft revision, invoice finalizada, `DocumentRepresentation`, artifact storage, resend/reprint, regenerate, `VOID`, replacement, credit memo, debit memo, correction chain, applications, closed period, holds de provider/dunning/fiscal, idempotencia e Clean Architecture."
non_objectives: "Executar chamadas externas, Sandbox, piloto, producao ou efeito real; cancelar assinatura do ADR-0044; executar charge/payment de `D-08`, dunning de `D-09`, refund de `D-10`, cancelamento/substituicao fiscal de `D-11`, posting contabil estatutario de `D-12`, RBAC/alçadas de `D-13`, rollout de `D-14` ou ampliar a liberacao local-only de `D-00`."
owner: "Billing / Produto / Financeiro / Arquitetura"
status: "Accepted"
date: "2026-08-25"
version: "1.2"
keywords: "invoice correction, immutable invoice, resend, reprint, representation version, artifact, void, replacement, credit memo, debit memo, correction chain, closed period, provider hold, dunning hold, fiscal hold"
related_files: "README.md, ../../../docs/specs/TP-00013-enterprise-billing-implementation-task-plan.md, ../specs/IP-BE-13.4.1-billing-invoice-correction-reissue.md, ../../../frontend/docs/specs/IP-FE-13.4.1-billing-invoice-correction-reissue.md, ADR-0023-agnostic-payment-provider-integration.md, ADR-0027-catalogo-global-faturamento-local.md, ADR-0038-pricing-tipado-moeda-cadencia.md, ADR-0044-lifecycle-contratual-proration-assinaturas.md, ADR-0045-metering-rating-fechamento-fatura.md"
code_references: "AS-IS em `app/src/main/java/br/com/duoset/saas_service/contexts/billing/` e `frontend/src/`; correction documents, chains, artifact port/store, holds, policies e contratos desta ADR sao destinos planejados e ainda nao existem."
principal_statement: "Invoice finalizada nunca tem snapshot, linhas, total ou numero reescritos; reenvio reutiliza exatamente o artifact existente, regeneracao cria nova representation version sem alterar fatos comerciais, `VOID` e permitido somente antes de efeitos downstream e toda correcao material posterior usa replacement ou credit/debit memo causal, forward-only e tenant-local."
---

# ADR-0046 - Correcao, cancelamento e reemissao de fatura comercial

- Document ID: `ADR-0046`
- Primary Nature: `Decisao`
- Objective: Fechar `D-07` definindo taxonomia nao ambigua, imutabilidade, reenvio, regeneracao de representacao, void pre-effect, replacement e credit/debit memo para faturas comerciais.
- Scope: Draft revision, invoice finalizada, `DocumentRepresentation`, artifact storage, resend/reprint, regenerate, `VOID`, replacement, credit memo, debit memo, correction chain, applications, closed period, holds de provider/dunning/fiscal, idempotencia e Clean Architecture.
- Non-objectives: Executar chamadas externas, Sandbox, piloto, producao ou efeito real; cancelar assinatura do ADR-0044; executar charge/payment de `D-08`, dunning de `D-09`, refund de `D-10`, cancelamento/substituicao fiscal de `D-11`, posting contabil estatutario de `D-12`, RBAC/alçadas de `D-13`, rollout de `D-14` ou ampliar a liberacao local-only de `D-00`.
- Keywords: invoice correction, immutable invoice, resend, reprint, representation version, artifact, void, replacement, credit memo, debit memo, correction chain, closed period, provider hold, dunning hold, fiscal hold
- Related Files: `docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00041-billing-invoice-correction-reissue.md`, `../../../docs/specs/TP-00013-enterprise-billing-implementation-task-plan.md`, `../specs/IP-BE-13.4.1-billing-invoice-correction-reissue.md`, `../../../frontend/docs/specs/IP-FE-13.4.1-billing-invoice-correction-reissue.md`, `ADR-0023-agnostic-payment-provider-integration.md`, `ADR-0027-catalogo-global-faturamento-local.md`, `ADR-0038-pricing-tipado-moeda-cadencia.md`, `ADR-0044-lifecycle-contratual-proration-assinaturas.md`, `ADR-0045-metering-rating-fechamento-fatura.md`
- Code References: AS-IS em `app/src/main/java/br/com/duoset/saas_service/contexts/billing/` e `frontend/src/`; correction documents, chains, artifact port/store, holds, policies e contratos desta ADR sao destinos planejados e ainda nao existem.
- Principal Decision: Invoice finalizada nunca tem snapshot, linhas, total ou numero reescritos; reenvio reutiliza exatamente o artifact existente, regeneracao cria nova representation version sem alterar fatos comerciais, `VOID` e permitido somente antes de efeitos downstream e toda correcao material posterior usa replacement ou credit/debit memo causal, forward-only e tenant-local.
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
- Reviewers: AI — analise de arquitetura, dominio, seguranca e custo; Human — N/A, nenhuma revisao substantiva desta decisao foi realizada
- Stakeholders: Proprietario do SaaS, tenants contratantes, Billing, Financeiro, Suporte, Backend, Frontend, Seguranca, Fiscal e Operacoes
- Supersedes: N/A; especializa ADR-0044 e ADR-0045 sem alterar lifecycle contratual, rating ou fechamento.
- Superseded by: N/A

---

# 0. Decision Provenance

| Field | Value |
| --- | --- |
| Normative status | `Accepted` |
| Decision provenance | `AI_DELEGATED` |
| Decision actor | `AI_AGENT — Codex (OpenAI)` |
| Authority holder | Solicitante, declarado proprietario do SaaS; identidade nao verificada criptograficamente pelo repositorio |
| Authority grant | `AUTH-BILLING-2026-08-25-001`, registrada no TP-00013 |
| Authority scope | Escolher e materializar autonomamente as decisoes documentais restantes de Billing |
| Human substantive review | `NOT_PERFORMED` |
| Reviewability | `OPEN`; revisao humana pode ratificar, emendar ou superseder sem apagar a origem IA |
| Excluded attestations | Dados reais, legal/fiscal, merchant ASAAS, PCI, Sandbox, SLO medido, producao, parecer juridico/contabil e implementacao |

O estado `Accepted` deriva da delegacao do owner, nao de revisao humana. Esta ADR
deve permanecer identificavel como decisao feita por IA, inclusive se for
ratificada, emendada ou substituida no futuro.

---

# 1. Context

O [ADR-0044](ADR-0044-lifecycle-contratual-proration-assinaturas.md) separou
cancelamento de contrato de correcao de cobranca e proibiu mutacao retroativa. O
ADR-0045 finaliza documentos comerciais imutaveis, com numero, linhas, journal e
outbox na transacao do tenant. Ainda faltava resolver a expressao ambigua
"reemitir fatura" e fechar quais operacoes apenas redistribuem um artifact e quais
criam novo efeito comercial.

Grandes sistemas distinguem documento canonico, representacao visual, saldo,
collection, fiscal e accounting. Mistura-los permitiria que uma troca de layout
alterasse valor, que um timeout de provider parecesse cancelamento ou que uma
invoice paga fosse apagada. Esta decisao adota correction chain append-only e um
artifact port simples, inicialmente implementavel no PostgreSQL ja operado na
VPS.

---

# 2. Decision Statement

## 2.1 Taxonomia fechada da intencao

O termo livre "reemissao" nunca e command executavel. Toda solicitacao seleciona
uma intencao fechada:

| Intent | Efeito permitido |
| --- | --- |
| `REVISE_DRAFT` | Cria nova draft version antes da finalizacao; invalida preview/approval anteriores. |
| `RESEND_EXISTING_REPRESENTATION` | Entrega exatamente bytes/ID/version/hash existentes; nenhum efeito comercial. |
| `REGENERATE_REPRESENTATION` | Cria nova representation version do mesmo snapshot canonico; nenhum efeito comercial. |
| `VOID_PRE_EFFECT` | Invalida comercialmente o documento elegivel por evento compensatorio, somente antes de downstream effects. |
| `REPLACE_DOCUMENT` | Cria nova invoice correta e relation causal com a original. |
| `ISSUE_CREDIT_MEMO` | Reduz obrigacao por documento positivo separado e aplicacao causal. |
| `ISSUE_DEBIT_MEMO` | Acrescenta obrigacao por documento positivo separado e aplicacao causal. |

Solicitacao ambigua retorna `BILLING_ACTION_AMBIGUOUS` com efeitos e pre-condicoes
sanitizados; nao escolhe automaticamente a acao de maior impacto. Cancelar
subscription, charge, payment, NFS-e ou journal contabil sao intents de outros
boundaries e nao aliases dessas operacoes.

## 2.2 Imutabilidade e eixos independentes

Depois de `FINALIZED`, os seguintes campos nunca mudam: invoice ID/number/series,
seller, payer, moeda, service/billing periods, agreement/rating/promotion/tax refs,
lines, quantities, unit prices, discounts, totals, due terms e hashes. Estado
posterior e registrado por evento/link append-only; nao por overwrite ou delete.

Os eixos abaixo possuem identities e states independentes:

- invoice comercial e correction documents;
- `DocumentRepresentation` e delivery attempts;
- receivable, payment allocation e provider projection do ADR-0023;
- dunning case do ADR-0025;
- refund/account credit do ADR-0047;
- fiscal document do ADR-0048;
- accounting posting/period fora do subledger gerencial do ADR-0049.

Uma transicao em um eixo nunca confirma, cancela ou reabre outro por inferencia.
O banco dedicado do tenant continua autoridade comercial; provider, renderer e
frontend sao adapters.

## 2.3 Revisao de draft

Antes de finalizacao, `REVISE_DRAFT` cria `InvoiceDraftVersion` imutavel com
predecessor, diff, reason, actor, effective refs e hash. Mudanca material exige
novo rating/tax preview aplicavel e invalida approval ligado ao hash anterior.
Abandono do draft nao consome numero definitivo nem produz void de invoice.

Finalizacao continua obedecendo a transacao unica do ADR-0045. `REVISE_DRAFT` nao
serve para contornar late-event, closed-period, pricing pinned ou promotion
capacity.

## 2.4 Resend e reprint do mesmo artifact

`RESEND_EXISTING_REPRESENTATION` seleciona uma representation `AVAILABLE`, verifica
scope e integridade, e reutiliza exatamente o mesmo `representationId`, version,
content type, byte length, bytes e content hash. Somente `DeliveryAttempt` novo e
append-only pode surgir.

Resend/reprint nao:

- gera novo numero ou nova invoice;
- executa renderer;
- atualiza template, locale, branding ou vencimento;
- cria receivable, journal financeiro, fiscal document ou provider intent;
- muda o estado de collection;
- substitui artifact com hash divergente.

Falha de canal nao reexecuta efeito financeiro. Retry da mesma delivery key e
fingerprint retorna/conclui a tentativa canonica. Artifact ausente ou com hash
invalido entra em integrity hold; nao e regenerado silenciosamente como se fosse o
original.

## 2.5 Regeneracao de representation version

`REGENERATE_REPRESENTATION` e uma operacao explicita e nao financeira. Ela pode
alterar somente presentation fields allowlisted, como template version, locale,
branding, acessibilidade e renderer version. O renderer recebe o mesmo
`CanonicalInvoiceSnapshot` e nao recalcula linhas, tax, desconto, total, due terms
ou fiscal identity.

O resultado e nova `DocumentRepresentation` com predecessor, generation intent,
template/renderer refs, bytes, hash e timestamp proprios. Versoes anteriores
permanecem imutaveis e acessiveis conforme autorizacao/retencao. Um pointer de
representation preferida pode avancar por CAS, mas nao apaga nem altera a anterior.

Se qualquer campo comercial, financeiro, fiscal ou de vencimento precisa mudar,
a operacao e rejeitada e reclassificada para replacement/credit/debit conforme o
caso. Regeneracao nunca e chamada de "segunda via fiscal" e nao simula nova
autorizacao publica.

## 2.6 Artifact port e storage inicial

O dominio conhece somente metadata e `InvoiceArtifactPort`; nunca JPA `byte[]`,
filesystem path, bucket, URL publica ou SDK de storage. Application commands
separam `store`, `read`, `verifyIntegrity` e `openAuthorizedStream`. O adapter
inicial usa PostgreSQL tenant-local com `bytea`, porque reduz componentes e custo
operacional no ambiente de VPS.

Contrato inicial:

- apenas `application/pdf` e renderer/template versions allowlisted;
- limite maximo de `5 MiB` por artifact, validado antes e durante o stream;
- SHA-256 sobre bytes exatos, tamanho e metadata canonica persistidos;
- unique key por tenant + representation ID/version e idempotency fingerprint;
- bytes nunca trafegam em outbox, logs, metrics ou audit details;
- artifact e invoice metadata sao gravados em transacoes separadas: falha de
  rendering nao desfaz invoice finalizada;
- retry de generation antes de `AVAILABLE` reutiliza a mesma generation intent;
  depois de `AVAILABLE`, bytes sao imutaveis.

Magic bytes, content type, tamanho e hash sao verificados. Download ocorre somente
apos authorization a cada acesso, com headers seguros e sem path/URL fornecido
pelo cliente. Encryption, backup, retention e legal hold seguem policies do
ambiente; exclusao automatica nao e inferida. O port permite migrar para object
storage futuramente sem mudar dominio ou IDs, se evidência do ADR-0051 justificar.

## 2.7 `VOID_PRE_EFFECT`

`VOID` nao apaga nem edita invoice. Ele acrescenta state event, reason, evidence,
actor, expected version e lote compensatorio do commercial subledger. E elegivel
somente quando nao existe downstream effect confirmado ou materialmente observado:

- payment allocation, recebimento parcial/total ou refund;
- payment/charge/collection command enviado ao provider;
- dunning case, fee ou communication efetivamente iniciado;
- fiscal document autorizado, cancel request ou substituicao;
- posting contabil estatutario ou periodo fechado;
- replacement, credit/debit memo ou correction application conflitante.

Estado externo `PENDING`, `UNKNOWN`, timeout ou reconciliation gap nao prova
ausencia de efeito e coloca a operacao em hold. Mesmo que o efeito seja depois
compensado, sua existencia historica torna `VOID_PRE_EFFECT` inelegivel; usa-se a
correction chain apropriada. A representacao ja entregue, isoladamente, nao altera
valor, mas exige reason/audit e comunicacao de void conforme policy.

Invoice DRAFT abandonada nao e `VOID_PRE_EFFECT`. Invoice finalizada elegivel
permanece consultavel com numero/linhas originais, `collectible=false` e causal
event. Qualquer cancelamento fiscal ou de provider e command separado nos gates
correspondentes.

## 2.8 Replacement causal

`REPLACE_DOCUMENT` corrige integralmente identidade comercial, payer/due terms,
lines ou totals quando void simples nao e adequado. Ele cria nova invoice com
novo ID, numero, snapshot, lines, journal e outbox; a original permanece intacta.
`ReplacementLink` e bidirecional, tipado, aciclico e possui reason, diff, evidence,
approval ref e predecessor hash.

Uma invoice tem no maximo um replacement ativo por correction intent. Unique
constraint/CAS impedem substitutos concorrentes. Replacement nao transfere
silenciosamente payment allocation, provider object, fiscal identity ou saldo.
Quando a original possui downstream effects, o plano deve compor credit/debit
memo e comandos separados dos ADRs-0023/0025/0047/0048/0049; ate que os holds
sejam resolvidos,
nao se declara saldo corrigido.

## 2.9 Credit memo, debit memo e no-negative-invoice

`CreditMemo` e `DebitMemo` sao documentos comerciais imutaveis, positivos em sua
propria magnitude, com ID/numero/series, lines, tax allocation refs, service period
original, posting period permitido, reason, approval e causal links.

- credit memo reduz saldo por `AdjustmentApplication` append-only;
- debit memo cria obrigacao incremental; nao aumenta a invoice original;
- aplicacao e desaplicacao usam novos movimentos, nunca update destrutivo;
- soma aplicada nao excede saldo elegivel da target obligation;
- quantidade, moeda, seller, payer e tax lineage devem ser compatíveis;
- correction chain nao admite ciclo, orphan link ou double application.

Invoice e correction document nunca possuem total final negativo. Credito que
ultrapassa saldo aberto, inclusive em invoice paga, produz `AccountCreditCandidate`
ou `RefundCandidate` pelo excedente. Isso nao cria dinheiro, saldo utilizavel ou
refund confirmado: o ADR-0047 decide eligibility, funding, approval e execution.

Subfaturamento usa debit memo/complemento. Late usage e rerating de periodo fechado
entram como candidate causal e nunca como edicao de line original.

## 2.10 Periodo fechado e compensacao forward-only

Invoice, rating, service period e journal de periodo fechado nunca sao reabertos,
backdated ou reescritos. A correcao:

1. preserva original service/billing period e source refs;
2. finaliza correction document no primeiro posting period permitido;
3. registra a diferenca entre service date, document date e posting date;
4. cria movimento compensatorio linkado ao batch original;
5. encaminha efeitos fiscal/subledger aos ADRs-0048/0049 sem presumir resultado.

Se nenhum periodo permitido estiver disponivel, a request fica em
`HOLD_ACCOUNTING_PERIOD`; nao se escolhe data artificial. Correcao forward-only
nao altera revenue recognition ou declaracao fiscal por conta propria.

## 2.11 Provider, dunning, fiscal e accounting holds

Preview e commit revalidam snapshots dos eixos dependentes. Estados minimos de
hold sao:

| Hold | Trigger | Saida segura |
| --- | --- | --- |
| `HOLD_PROVIDER_RECONCILIATION` | Intent/charge/payment externo `PENDING`, `UNKNOWN` ou divergente. | ADR-0023 reconcilia fato autenticado; nenhum retry destrutivo. |
| `HOLD_DUNNING_COORDINATION` | Caso/tentativa/fee/notice de cobranca ativo. | ADR-0025 pausa/encerra/compensa explicitamente. |
| `HOLD_FISCAL_ALIGNMENT` | Fiscal autorizado, cancel/substitution pendente ou estado divergente. | ADR-0048 confirma acao permitida; comercial nao finge efeito fiscal. |
| `HOLD_ACCOUNTING_PERIOD` | Periodo fechado ou posting desconhecido. | ADR-0049 fornece periodo/compensacao gerencial permitidos; estatutario permanece evidence-gated. |

Holds sao reasoned, tenant-scoped e auditaveis. Nao alteram invoice ou escondem o
pedido. Uma mudanca de provider/dunning/fiscal/accounting snapshot invalida preview
e approval anterior. Timeout, callback do browser, redirect ou HTTP 2xx nao sao
evidencia suficiente para liberar hold.

## 2.12 Transacao, idempotencia e concorrencia

Todo correction command possui idempotency key, canonical fingerprint, expected
invoice/correction-chain generation e correlation/causation IDs. Mesma key e
fingerprint retorna o resultado canonico; reuse divergente falha. Commit ambiguo e
resolvido por releitura tenant-local, nunca por nova key.

Finalizacao de void/replacement/credit/debit persiste em uma transacao do tenant o
document/state event, lines quando aplicavel, numero, causal links,
`AdjustmentApplication`, commercial journal batch, idempotency record e outbox.
Falha de balanceamento, chain, number ou outbox faz rollback integral. Provider,
fiscal, accounting e rendering ocorrem depois por sagas/outbox separados, sem XA.

Batch apenas coordena sub-keys; cada documento e unidade transacional independente.
Resultado `PARTIAL` nao autoriza repetir os itens concluidos.

## 2.13 Approvals, seguranca e privacidade

Reason code estruturado e justificativa sao obrigatorios em void, replacement,
credit e debit. Four-eyes, approval seal, MFA, break-glass e capabilities seguem o
ADR-0050; nenhuma UI ou endpoint recebe permissao implícita antes de seus contracts
e controles serem materializados. Alteracao do preview hash invalida approval e
solicitante nunca se autoaprova.

Tenant/seller/account scope e verificado antes de carregar ou revelar invoice,
artifact, correction chain, payment ou fiscal refs. IDs nao sao autorizacao.
Downloads usam anti-enumeration, rate limit, audit redigido, headers seguros e
session/authorization atual; artifact nao e URL publica permanente.

PII, bank refs, fiscal payload, provider payload, artifact bytes e evidence raw nao
aparecem em logs, metrics ou outbox. Renderer recebe payload minimo, versionado e
escapado; template nao executa codigo/URL arbitrarios. Erro publico nao revela
existencia ou saldo de outro tenant.

## 2.14 Clean Architecture e custo

Correction policy, chain, eligibility, applications e representation metadata
ficam no domain de `contexts.billing`, sem Spring, JPA, `bytea`, filesystem,
renderer ou ASAAS. Application ports isolam artifact, renderer, delivery,
provider state, fiscal state, accounting period e stores. Adapters convertem
DTOs externos para fatos internos tipados.

O primeiro slice reutiliza monolito modular e PostgreSQL tenant-local. O `bytea`
capado evita S3/MinIO e credenciais adicionais antes de escala medida. Renderer e
scheduler permanecem workers do mesmo deploy com limites/bulkheads; microservico,
workflow engine e object store sao opcoes futuras atras dos ports, nao requisitos
iniciais.

## 2.15 Boundary da aprovacao

`D-07` fica fechado conceitualmente. `D-08` a `D-14` tambem foram fechados nos ADRs
canonicos por Codex sob `AUTH-BILLING-2026-08-25-001`, com provenance
`AI_DELEGATED`, revisao humana `NOT_PERFORMED` e `Reviewability: OPEN`. `D-00 =
RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only` permite código, DDL,
OpenAPI, renderer e testes herméticos locais; provider/ASAAS externo e mudança
operacional permanecem bloqueados pelos gates próprios.

Merchant/capabilities/tarifas ASAAS, PCI, Sandbox, OpenAPI/DDL/UI, dados/pareceres
legais-fiscais-contabeis, SLO/backup e aceite de piloto continuam como evidencias
ou artefatos pendentes, nao decisoes abertas.

---

# 3. Decision Drivers

- preservar invoice finalizada como evidencia imutavel;
- remover ambiguidade entre resend, regenerate, void e correction;
- evitar saldo negativo e dupla aplicacao de credito;
- coordenar eixos externos sem falso sucesso ou transacao distribuida;
- suportar periodo fechado por compensacao prospectiva;
- reduzir custo inicial da VPS sem acoplar dominio ao PostgreSQL;
- permitir storage futuro por port;
- proteger PII, artifacts e informacao cross-tenant.

---

# 4. Considered Options

## Option A - Correction chain append-only e artifact port com PostgreSQL inicial

Pros: auditavel, provider-neutral, sem mutacao retroativa, baixo custo inicial e
evolucao de storage por port.

Cons: mais documentos/links, holds e compensacoes; `bytea` exige cap e monitoracao.

## Option B - Editar/reabrir invoice finalizada

Rejected: destrói evidencia, quebra payment/fiscal/accounting reconciliation e
torna replay impossivel.

## Option C - Tratar toda reemissao como nova invoice

Rejected: duplica numero/obrigacao e mistura problema visual com correcao
financeira.

## Option D - Object storage e workflow service desde o primeiro slice

Rejected: adiciona custo, credenciais e operacao sem volume medido; ports
preservam migracao posterior.

---

# 5. Decision Outcome

A **Option A** foi escolhida autonomamente pela IA sob
`AUTH-BILLING-2026-08-25-001`. A alternativa preserva integridade financeira e
forense com infraestrutura compatível com a VPS inicial, sem fechar a evolucao de
storage ou processamento.

---

# 6. Consequences

## Positive Consequences

- Resend nunca duplica invoice ou efeito financeiro.
- Mudanca visual fica rastreada em representation version propria.
- Original e correction chain explicam todo ajuste.
- Void nao mascara efeitos downstream existentes.
- Periodo fechado permanece fechado.
- Storage inicial nao exige novo servico nem credencial.

## Negative Consequences

- Operacao precisa escolher intent explicita em vez de um botao generico.
- Holds podem atrasar correcao enquanto outros eixos reconciliam.
- Artifacts aumentam o banco e exigem cap, backup e observabilidade.
- Credit/debit/replacement exigem numbering e journal adicionais.

## Neutral Consequences

- Representacao preferida pode mudar; versoes anteriores permanecem.
- Refund, fiscal e accounting continuam decisoes separadas.
- Um artifact PDF nao e a fonte de verdade do documento comercial.

---

# 7. Impact

- Backend: correction domain, chain, policies, use cases e ports planejados.
- Frontend: intent selector explicito, preview/diff server-authoritative e holds.
- Database: correction documents, links, applications, representations, artifacts,
  journal/outbox em migrations futuras tenant-local.
- Security: authorization por acesso, integrity hash, artifact cap e redaction.
- Operations: renderer/delivery retries separados e reconciliacao de holds.
- Provider/ASAAS: commands obedecem ao ADR-0023 somente apos seus evidence gates;
  projection externa nao governa invoice.

---

# 8. AI Agent Considerations

Agentes devem manter provenance `AI_DELEGATED`, nunca atribuir revisao humana,
preservar invoice finalizada, distinguir resend de regenerate, aplicar void apenas
pre-effect, usar correction documents causais e implementar somente no escopo
hermético local liberado por `D-00`.

---

# 9. Implementation Plan Boundary

1. congelar intent taxonomy, state machines, reasons, errors e OpenAPI;
2. criar golden vectors de correction chains, applications e representation hash;
3. modelar domain puro e ports de artifact/renderer/delivery/dependent states;
4. criar migrations aditivas, constraints de aciclicidade/idempotencia e cap;
5. implementar resend/integrity e regenerate sem efeito financeiro;
6. implementar eligibility/holds de void e correction preview;
7. implementar transacao de replacement/credit/debit/application/journal/outbox;
8. implementar adapter PostgreSQL `bytea` e renderer limitado;
9. integrar frontend somente via API real e autorizacao;
10. executar testes de tenancy, concorrencia, crash, closed-period, artifact e E2E;
11. liberar somente apos materializar em contratos/runtime os ADRs ja aceitos de
    `D-08`–`D-14`, reunir evidencias aplicaveis e obter autorização operacional
    própria antes de qualquer efeito externo ou rollout.

Esta sequencia nao cria autorizacao para codigo ou provider.

---

# 10. Validation

- invoice finalizada rejeita update/delete de snapshot, lines, total e numero;
- resend entrega os mesmos bytes/ID/version/hash e cria somente delivery attempt;
- artifact corrompido bloqueia resend sem regeneracao silenciosa;
- regenerate cria version nova e preserva todos os campos canonicos;
- mudanca material nao passa como regenerate;
- void falha se qualquer downstream effect existe ou permanece ambiguo;
- replacements concorrentes produzem no maximo um link ativo;
- credit/debit application nunca torna invoice negativa nem duplica saldo;
- chain e aciclica, causal e reproduzivel;
- periodo fechado recebe compensacao no periodo permitido sem reopen;
- holds nao inferem sucesso de timeout/callback/HTTP;
- correction finalization e atomica com number/journal/outbox;
- artifact acima de `5 MiB` ou fora do content type e rejeitado;
- tenant A nao consulta artifact/chain/saldo do tenant B;
- docs e links passam no validador apos indexacao pelo integrador.

Esta ADR documental não cria testes por si só; implementação e testes herméticos
locais são autorizados pela liberação separada e escopada de `D-00`.

---

# 11. Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| "Reemitir" duplicar obrigacao | Intent taxonomy fechada e confirmacao explicita. |
| Regenerate alterar valor | Canonical snapshot imutavel e presentation allowlist. |
| Void esconder pagamento/fiscal | Pre-effect eligibility + holds fail-closed. |
| Credit aplicado duas vezes | Unique constraint, CAS e application append-only. |
| Correction chain ciclica | Invariantes de causalidade e validacao transacional. |
| Closed period ser reaberto | Forward-only memo/journal em periodo permitido. |
| Timeout externo produzir falso sucesso | Reconciliacao por fato tipado antes de liberar hold. |
| `bytea` pressionar VPS/backup | Cap de `5 MiB`, metrics e port para migracao futura. |
| Artifact vazar PII | Scope antes do fetch, streaming autorizado e redaction. |

---

# 12. Related ADRs

- [ADR-0000 - Governanca documental](../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md)
- [ADR-0019 - Database-per-tenant](ADR-0019-database-per-tenant.md)
- [ADR-0023 - Provider-neutral payments](ADR-0023-agnostic-payment-provider-integration.md)
- [ADR-0027 - Catalogo global e faturamento local](ADR-0027-catalogo-global-faturamento-local.md)
- [ADR-0038 - Pricing tipado](ADR-0038-pricing-tipado-moeda-cadencia.md)
- [ADR-0044 - Lifecycle contratual, proration e assinaturas](ADR-0044-lifecycle-contratual-proration-assinaturas.md)
- [ADR-0045 - Metering, rating e fechamento](ADR-0045-metering-rating-fechamento-fatura.md)
- [ADR-0047 - Ledger, creditos e refunds](ADR-0047-ledger-creditos-refunds-disputas-writeoff.md)
- [ADR-0048 - Fatura comercial e NFS-e](ADR-0048-separacao-fatura-comercial-documento-fiscal-nfse.md)
- [ADR-0049 - Subledger tenant-local e MRR](ADR-0049-subledger-tenant-local-mrr-normalizado.md)
- [ADR-0050 - RBAC, SoD e aprovacoes](ADR-0050-rbac-sod-aprovacoes-financeiras.md)
- [ADR-0051 - SLO, capacidade e rollout](ADR-0051-slo-capacidade-rollout-billing.md)

---

# 13. References

- [REQ-00042](../product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md)
- [UC-00041](../product/use-cases/UC-00041-billing-invoice-correction-reissue.md)
- [TP-00013](../../../docs/specs/TP-00013-enterprise-billing-implementation-task-plan.md)
- [IP-BE-13.4.1-billing-invoice-correction-reissue](../specs/IP-BE-13.4.1-billing-invoice-correction-reissue.md)
- [IP-FE-13.4.1-billing-invoice-correction-reissue](../../../frontend/docs/specs/IP-FE-13.4.1-billing-invoice-correction-reissue.md)
- [Module Registry](../architecture/module-registry.md)

---

# 14. Decision Lifecycle

Current State: **Accepted — AI_DELEGATED**.

Ratificacao humana futura deve registrar ator/data sem apagar a origem. Mudanca em
immutability, intent taxonomy, void eligibility, correction chain, no-negative,
closed-period, holds ou artifact authority exige nova versao aceita ou sucessora.

`D-08` a `D-14` estao aceitos com a mesma origem delegada e revisao humana aberta;
isso nao comprova implementação/evidência. `D-00` foi liberado por humano somente
para implementação local dos planos TP-00013.

---

# 15. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.2 | 2026-08-25 | Solicitante humano, proprietário declarado / Codex (IA), materialização | Registra `D-00 = RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`; permite código/DDL/OpenAPI/renderer/testes herméticos locais e mantém chamadas externas, Sandbox ASAAS, piloto BP Farias, produção, flags `ON` e efeitos reais bloqueados. |
| 1.1 | 2026-08-25 | Codex (IA), sob `AUTH-BILLING-2026-08-25-001` | Reconcilia os holds e handoffs com ADRs-0023/0025/0047–0051 aceitos; registra `D-08`–`D-14` como `AI_DELEGATED`, revisao humana `NOT_PERFORMED`/`OPEN`, mantendo evidencias pendentes e `D-00` ativo. |
| 1.0 | 2026-08-25 | Codex (IA), sob `AUTH-BILLING-2026-08-25-001` | Fecha autonomamente `D-07` com invoice imutavel, resend exato, regeneration versionada, void pre-effect, replacement/credit/debit causal, no-negative, compensacao forward-only, holds e artifact port PostgreSQL capado; revisao humana substantiva nao realizada. |

---

# 16. Repository Structure

Este ADR cria somente documentacao. Os alvos futuros ficam em `contexts.billing`,
com domain/application independentes de storage e adapters PostgreSQL, renderer,
delivery e integracoes externas isolados.

---

# 17. Review Process

Revisao humana permanece `OPEN`. Ratificacao adiciona evidencias e status de review
sem reclassificar a decisao original. Emenda material usa nova versao/ADR; nenhuma
revisao humana pode ser presumida a partir da delegacao do owner.

---

# 18. Notes

- "Cancelamento" nesta ADR significa `VOID`/correcao da fatura comercial GV
  Software contra o tenant, nao cancelamento de subscription, charge ou NFS-e.
- BP Farias usa as mesmas policies, artifact port, holds e correction chain, sem
  excecao por tenant.
- O cap de `5 MiB` e uma decisao inicial de custo e seguranca; alteracao exige
  evidencia conforme ADR-0051 e nova versao de policy/ADR, nunca override
  silencioso.
