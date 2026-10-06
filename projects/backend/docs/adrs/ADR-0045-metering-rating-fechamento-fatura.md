---
document_id: "ADR-0045"
primary_nature: "Decisao"
objective: "Fechar `D-06` definindo a autoridade de eventos de uso, deduplicacao, agregacao, quota, rating reproduzivel, late events e fechamento tenant-local de fatura comercial."
scope: "`UsageEventLedger`, identidade e hash de payload, dimensoes allowlisted, `COUNT`/`SUM`, quotas, admission, copy de quota versionada/localizada, classes de controle nao billable, agregados, rating pinned, watermark, late events, billing run, numeracao comercial, statement de total zero, journal comercial e outbox."
non_objectives: "Executar chamadas externas, Sandbox, piloto, producao ou efeito real; definir o texto editorial final das mensagens ou permitir customizacao por tenant no primeiro slice; redefinir correcao/reemissao, collection/provider, dunning, refund, fiscal, subledger, RBAC/alçadas ou SLO/rollout governados pelos ADRs sucessores; ampliar a liberacao local-only de `D-00`."
owner: "Billing / Produto / Financeiro / Arquitetura"
status: "Accepted"
date: "2026-08-25"
version: "1.2"
keywords: "metering, usage event ledger, payload hash, deduplication, aggregation, COUNT, SUM, quota, PostgreSQL admission, rating pinned, watermark, late event, billing run, commercial invoice, zero-total statement, tenant-local"
related_files: "docs/product/requirements/REQ-00011-chatbot-usage-limits-and-billing.md`, `docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00022-chatbot-quota-enforcement.md`, `docs/product/use-cases/UC-00040-billing-usage-rating-invoice-close.md`, `docs/delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md`, `docs/delivery/plans/implementation_plans/backend/IP-BE-13.3.1-billing-usage-rating-invoice-close.md`, `docs/delivery/plans/implementation_plans/frontend/IP-FE-13.3.1-billing-usage-rating-invoice-close.md`, `docs/adrs/ADR-0030-composicao-deterministica-enforcement-entitlements.md`, `docs/adrs/ADR-0034-efeitos-transicao-nao-destrutiva-entitlements.md`, `docs/adrs/ADR-0038-pricing-tipado-moeda-cadencia.md`, `docs/adrs/ADR-0041-stacking-waterfall-promocional-deterministico.md`, `docs/adrs/ADR-0042-capacidade-redemption-promocional-concorrente.md`, `docs/adrs/ADR-0044-lifecycle-contratual-proration-assinaturas.md"
code_references: "AS-IS em `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/` e `frontend/src/`; ledger, aggregates, policies, ports, stores, billing run e contratos desta ADR sao destinos planejados e ainda nao existem."
principal_statement: "Uso aceito forma ledger append-only no banco dedicado do tenant; identidade e payload hash tornam ingestao idempotente, dimensoes sao tipadas e allowlisted, somente `COUNT` e `SUM` entram no primeiro slice, quotas usam admission atomica PostgreSQL, copy de esgotamento vem de template server-side versionado/localizado, classes de saida/handoff/seguranca server-classified permanecem admitidas e nao billable, rating consome snapshots pinados e cada close finaliza invoice ou statement de total zero em uma unica transacao tenant-local."
---

# ADR-0045 - Metering, rating e fechamento de fatura comercial

- Document ID: `ADR-0045`
- Primary Nature: `Decisao`
- Objective: Fechar `D-06` definindo a autoridade de eventos de uso, deduplicacao, agregacao, quota, rating reproduzivel, late events e fechamento tenant-local de fatura comercial.
- Scope: `UsageEventLedger`, identidade e hash de payload, dimensoes allowlisted, `COUNT`/`SUM`, quotas, admission, copy de quota versionada/localizada, classes de controle nao billable, agregados, rating pinned, watermark, late events, billing run, numeracao comercial, statement de total zero, journal comercial e outbox.
- Non-objectives: Executar chamadas externas, Sandbox, piloto, producao ou efeito real; definir o texto editorial final das mensagens ou permitir customizacao por tenant no primeiro slice; redefinir correcao/reemissao, collection/provider, dunning, refund, fiscal, subledger, RBAC/alçadas ou SLO/rollout governados pelos ADRs sucessores; ampliar a liberacao local-only de `D-00`.
- Keywords: metering, usage event ledger, payload hash, deduplication, aggregation, COUNT, SUM, quota, PostgreSQL admission, rating pinned, watermark, late event, billing run, commercial invoice, zero-total statement, tenant-local
- Related Files: `docs/product/requirements/REQ-00011-chatbot-usage-limits-and-billing.md`, `docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00022-chatbot-quota-enforcement.md`, `docs/product/use-cases/UC-00040-billing-usage-rating-invoice-close.md`, `docs/delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md`, `docs/delivery/plans/implementation_plans/backend/IP-BE-13.3.1-billing-usage-rating-invoice-close.md`, `docs/delivery/plans/implementation_plans/frontend/IP-FE-13.3.1-billing-usage-rating-invoice-close.md`, `docs/adrs/ADR-0030-composicao-deterministica-enforcement-entitlements.md`, `docs/adrs/ADR-0034-efeitos-transicao-nao-destrutiva-entitlements.md`, `docs/adrs/ADR-0038-pricing-tipado-moeda-cadencia.md`, `docs/adrs/ADR-0041-stacking-waterfall-promocional-deterministico.md`, `docs/adrs/ADR-0042-capacidade-redemption-promocional-concorrente.md`, `docs/adrs/ADR-0044-lifecycle-contratual-proration-assinaturas.md`
- Code References: AS-IS em `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/` e `frontend/src/`; ledger, aggregates, policies, ports, stores, billing run e contratos desta ADR sao destinos planejados e ainda nao existem.
- Principal Decision: Uso aceito forma ledger append-only no banco dedicado do tenant; identidade e payload hash tornam ingestao idempotente, dimensoes sao tipadas e allowlisted, somente `COUNT` e `SUM` entram no primeiro slice, quotas usam admission atomica PostgreSQL, copy de esgotamento vem de template server-side versionado/localizado, classes de saida/handoff/seguranca server-classified permanecem admitidas e nao billable, rating consome snapshots pinados e cada close finaliza invoice ou statement de total zero em uma unica transacao tenant-local.
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
- Stakeholders: Proprietario do SaaS, tenants contratantes, Billing, Financeiro, Suporte, Backend, Frontend, Seguranca e Operacoes
- Supersedes: N/A; especializa ADR-0030, ADR-0034, ADR-0038, ADR-0041, ADR-0042 e ADR-0044 sem alterar seus invariantes.
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

`Accepted` indica vigencia normativa sob autoridade delegada. Nao significa que
uma pessoa revisou ou aprovou o merito desta escolha. A provenance
`AI_DELEGATED` permanece historica e imutavel mesmo apos eventual ratificacao.

---

# 1. Context

O [ADR-0044](ADR-0044-lifecycle-contratual-proration-assinaturas.md) fixou o
contrato como timeline tenant-local, com service periods semiabertos, revisoes e
precos pinados. Faltava fechar como fatos de uso entram sem duplicacao, como quota
e overage permanecem separados, como rating pode ser reproduzido e como um periodo
se torna documento comercial imutavel.

Aceitar contadores mutaveis, dimensoes livres ou rating contra catalogo vivo
permitiria dupla cobranca, explosao de cardinalidade e resultados impossiveis de
auditar. Fechar todos os tenants numa transacao ou delegar calculo ao provider
conflitaria com database-per-tenant e com o custo inicial de monolito modular em
VPS. Esta decisao concentra consistencia em PostgreSQL e processa cada tenant como
unidade independente.

---

# 2. Decision Statement

## 2.1 Autoridades e separacao dos fatos

O banco dedicado de cada tenant e a unica autoridade para seu
`UsageEventLedger`, admission/reservas de quota, agregados, `RatingResult`,
`BillingRun`, invoice/statement, sequencia comercial, journal comercial e outbox.
O store da plataforma fornece somente definicoes e versoes publicadas, que devem
ser materializadas e pinadas antes do processamento tenant-local. Nao ha XA, FK,
join ou transacao cross-store.

Os fatos abaixo sao independentes:

| Fato | Autoridade | Nao implica |
| --- | --- | --- |
| Uso observado | `UsageEventLedger` tenant-local | entitlement, cobranca ou pagamento |
| Admission/quota | Projecao e reserva tenant-local atuais | billability ou preco |
| Rating | `RatingResult` imutavel com inputs pinados | invoice finalizada ou recebimento |
| Documento comercial | Invoice/statement finalizado | efeito no provider, fiscal ou pagamento |
| Provider/fiscal/subledger | ADRs-0023, 0048 e 0049 | mutacao do uso ou rating historico |

Cache e Redis podem acelerar leitura, mas nunca decidir deduplicacao, quota,
rating ou close. Rating e close nao usam LKG. O provider nao ingere uso como
autoridade, nao calcula preco e nao fecha invoice.

## 2.2 Ledger append-only e identidade do evento

Todo fato aceito e um `UsageEvent` imutavel. Sua identidade canonica e composta
por `tenantId`, `sourceNamespace` versionado e `sourceEventId`; o tenant e derivado
do contexto autenticado e nunca confiado a partir do payload. O evento inclui no
minimo:

- `occurredAt`, `observedAt` e `acceptedAt` distintos, em UTC;
- meter, schema e unit versions;
- quantidade decimal exata, quando aplicavel;
- dimensoes normalizadas conforme schema;
- agreement/subscription, billing account e effective revision refs;
- `canonicalPayloadHash`, correlation/causation refs e provenance;
- eventual `compensatesEventId`, reason e evidence autorizada.

Canonicalizacao tem schema versionado, encoding definido e rejeita valores
ambiguous, non-finite, overflow, precision superior ao contrato e timestamps sem
offset. Mesma identidade + mesmo hash e replay idempotente e retorna o receipt
original. Mesma identidade + hash diferente produz
`USAGE_EVENT_IDENTITY_CONFLICT`, preserva evidencia sanitizada e nao altera uso,
quota ou valor.

Eventos aceitos nunca sao atualizados ou apagados. Correcao usa evento
compensatorio causal, com quantidade assinada permitida somente pelo command de
correcao e alçada futura; eventos ordinarios nao enviam quantidade negativa. Uma
compensacao nao pode exceder o fato elegivel, cruzar tenant/unit/meter ou formar
ciclo. Rejeicoes possuem ingestion receipt/audit, mas nao fingem uso aceito.

## 2.3 Meter definitions e dimensoes allowlisted

`MeterDefinitionVersion` e imutavel, effective-dated e seller-owned. Define:

- `meterCode`, `unit`, precision e aggregation function;
- dimensoes obrigatorias/opcionais, tipo, normalizacao e cardinality policy;
- fontes autorizadas e schema de evento;
- segmentacao comercial permitida;
- late-event e correction policies referenciadas;
- hash canonico e periodo de validade.

Somente dimensoes explicitamente allowlisted podem participar de deduplicacao,
agregacao, rating, logs ou metrics. Chave desconhecida, valor fora do dominio,
dimensao obrigatoria ausente ou quantidade/unidade incompatível falha antes de
qualquer contador. PII, segredo, texto livre e payload de provider nao sao
dimensoes de rating.

O primeiro slice habilita apenas:

| Aggregation | Semantica |
| --- | --- |
| `COUNT` | Soma exatamente uma unidade por evento aceito e nao compensado, preservando membership. |
| `SUM` | Soma quantidades decimais exatas na mesma unidade e precision versionadas. |

`UNIQUE_COUNT`, `MIN`, `MAX`, `AVERAGE`, percentile, duration/session, formula,
SQL, SpEL, JavaScript e agregacao arbitraria permanecem `DISABLED`. Publicacao de
preco que exija funcao desabilitada falha; nao ha aproximacao silenciosa.

## 2.4 Agregacao deterministica

Um `UsageAggregateVersion` fixa a janela semiaberta, meter version, membros
ordenados, dimensoes de agrupamento, agreement revision, entitlement generation,
price/promotion refs, unit, quantidade, correction lineage e `aggregateHash`.
Eventos governados por revisoes, moedas, units, sellers ou snapshots incompatíveis
nunca sao mesclados. Uma janela que cruza `effectiveAt` e segmentada sem resetar ou
transferir contador.

Agregacao e pura sobre um conjunto identificado de eventos. Mesmos membros,
schemas e policies, em qualquer ordem de chegada, produzem quantidade, breakdown e
hash identicos. Novos fatos em periodo aberto criam nova versao; versao anterior
nao e sobrescrita. Aggregate materializado e uma projecao verificavel, nunca
substituto dos eventos-fonte.

## 2.5 Quota modes e admission PostgreSQL

Os modos fechados do entitlement conservam a seguinte semantica:

| Mode | Admission | Metering e billing |
| --- | --- | --- |
| `NO_QUOTA` | Admite somente se capability estiver concedida e sem restricao dominante. | Uso pode ser medido; ausencia de quota nao cria preco. |
| `HARD_LIMIT` | Exige reserva atomica antes do aumento liquido. | Confirmacao consome; release/expiry devolve somente a reserva nao consumida. |
| `SOFT_LIMIT` | Admite com contador atual e sinalizacao quando cruza limite. | Nunca transforma excedente em cobranca por inferencia. |
| `OVERAGE_ALLOWED` | Admite e separa allowance de excedente candidato. | Somente price/rating pinned torna o excedente billable. |

`UsageAdmission` e `QuotaReservation` sao autoridades PostgreSQL tenant-local.
Unique constraints, compare-and-set e transacao serializavel ou lock de linha em
ordem deterministica garantem que duas requisicoes nao consumam o ultimo slot.
Redis lock, contador em memoria e leitura seguida de write sem condicao sao
proibidos.

Estados minimos sao `RESERVED`, `CONSUMED`, `RELEASED` e `EXPIRED`. Reservation e
curta, vinculada a tenant, capability, window, revision/generation, operation ID,
quantidade e fence. Same key + same fingerprint retorna o estado canonico; reuse
divergente falha. Confirm/release/expiry sao idempotentes e append-only. Operacao
de outro contexto confirma por saga/outbox; nao ha XA. Resultado ambiguo exige
releitura, nunca nova key ou blind retry.

Uma admission lease nao ignora RBAC/risco atual, nao cobre item apenas enfileirado
e nao se renova silenciosamente. Limite, timezone, window e prazo sao definidos por
policy versionada; o primeiro slice admite `CONTRACT_PERIOD` e
`CALENDAR_BUCKET`, enquanto rolling window arbitraria permanece desabilitada.

### 2.5.1 Copy de quota esgotada

A resposta ao esgotamento de quota referencia `QuotaMessageTemplateVersion`
seller-owned, server-side, imutavel depois de publicada e localizada por locale
suportado. O resultado de admission carrega template code/version, reason code e
parametros tipados/sanitizados; controller e frontend apenas transportam/renderizam
o contrato retornado e nao mantêm copy hardcoded nem inventam fallback textual.

O primeiro slice usa somente o catalogo padrao publicado pela GV Software.
Customizacao por tenant/admin permanece `OFF`; locale ausente ou template
incompativel falha para um fallback server-side igualmente versionado, nunca para
string embutida em controller, adapter ou cliente. Conteudo editorial e idiomas
publicados sao dados governados e nao sao definidos por esta ADR.

### 2.5.2 Classes de controle admitidas com quota comercial esgotada

Esgotamento de quota comercial nao pode impedir operacoes necessarias para sair,
obter atendimento humano ou preservar seguranca/consentimento. A classificacao
server-side fechada admite, mesmo sem saldo comercial:

- `OPT_OUT` / `EXIT`;
- `HUMAN_HANDOFF`;
- `SECURITY` / `CONSENT`.

Essas operacoes nao consomem quota comercial, nao formam billable usage e nao
podem gerar overage, invoice line ou credito. Podem produzir somente receipt/
telemetria operacional minimizada e auditavel, separada do `UsageEventLedger`
faturavel. Um rate limit/anti-abuse independente e fail-closed protege o caminho
sem reutilizar a quota comercial como controle de seguranca.

A classe e derivada no servidor por command/event type allowlisted, estado e
policy versionada. Browser, cliente de API, tenant admin, texto da mensagem,
header, claim ou payload arbitrario nao escolhem nem sobrescrevem a classe. Classe
desconhecida, evidencia insuficiente ou tentativa de spoofing segue admission
comercial comum e registra reason sanitizado; nunca recebe bypass permissivo.

## 2.6 Rating pinned e reproduzivel

`RatingInputSnapshot` referencia exatamente:

- agreement/subscription revision e service/billing segment do ADR-0044;
- `MeterDefinitionVersion` e `UsageAggregateVersion`;
- `ContractEntitlementSnapshot` e projection generation efetivas;
- `PriceVersion`, currency, cadence, tier e rounding policies do ADR-0038;
- `AcceptedPromotionCombinationSnapshot` e attestation stateful aplicavel dos
  ADR-0041/ADR-0042;
- tax input/reference quando o ruleset do ADR-0048 o tornar obrigatorio;
- cutoff, watermark, policy refs/hashes e canonical input hash.

O rating nunca consulta `latest`, catalogo vivo, fatos promocionais vivos, raw
coupon, frontend ou provider. Cada `RatingResult` e imutavel e contem quantidade
included/billable, tiers, rates decimais, desconto monetario, grants separados,
rounding/residual, subtotal em minor units, applied/rejected reasons, input refs e
`ratingResultHash`.

Mesmos inputs pinados produzem o mesmo resultado/hash. Rerating sem troca de
input e verificacao, nao novo fato. Rerating autorizado em periodo aberto cria
nova versao causal; depois do close produz adjustment candidate do ADR-0046, nunca
muta invoice. Valor negativo nao e invoice: vira candidato tipado de credito e
aguarda ADRs-0046/0047.

Modelos de preco do ADR-0038 podem ser executados somente quando usam nenhum
aggregate ou `COUNT`/`SUM` e possuem todos os parametros pinados. Prepaid ledger,
burndown, top-up, FX e formula arbitraria permanecem fora.

## 2.7 Watermark, cutoff e late events

Cada fonte obrigatoria publica `UsageSourceCheckpoint` monotonicamente crescente.
O watermark elegivel do periodo e o menor checkpoint verificado entre as fontes
requeridas. `ClosePolicyVersion` define source set, safety lag e grace, sem usar
relogio da maquina ou ausencia de evento como prova de completude. Fonte obrigatoria
ausente, regredida ou conflitante coloca somente aquele tenant/periodo em hold.

O close fixa `cutoffAt`, watermark e conjunto de event IDs/hashes. Evento que
ocorreu no periodo, mas foi aceito depois do cutoff, e late event:

- permanece append-only no ledger;
- nao modifica aggregate/rating/invoice finalizados;
- cria `LateUsageAdjustmentCandidate` com original period, reason e lineage;
- e aplicado prospectivamente em periodo aberto por memo/ajuste governado pelo
  ADR-0046, fiscal pelo ADR-0048 e subledger pelo ADR-0049.

Evento tardio em periodo ainda aberto pode gerar nova aggregate/rating version.
Replay nao muda classificacao. Backfill nao inventa dimensao ou revisao historica.

## 2.8 Billing run por tenant

O coordenador pode descobrir varios tenants, mas cada `BillingRunItem` resolve um
unico tenant, billing account, currency, commercial series e periodo. Estados
minimos: `PLANNED`, `READY`, `REVIEW_REQUIRED`, `FINALIZING`, `FINALIZED`,
`FAILED_RETRYABLE` e `FAILED_TERMINAL`. Falha de um tenant nao abre transacao,
rollback ou fallback no banco de outro.

Antes de finalizar, o run valida:

1. tenant guard e autoridade atual;
2. periodo e agreement revision do ADR-0044;
3. watermarks/checkpoints requeridos;
4. event, aggregate e rating hashes;
5. entitlement, price e promotion snapshots pinados;
6. moeda unica, seller e payer coerentes;
7. ausencia de run/fatura canonica concorrente;
8. approvals/holds exigidos pelos ADRs-0048/0050.

Command usa idempotency key, canonical fingerprint e expected generation. Mesmo
key/fingerprint apos crash retorna o resultado canonico. Payload divergente falha.
Commit ambiguo e resolvido por leitura da autoridade tenant-local.

## 2.9 Finalizacao atomica e numeracao comercial

A finalizacao ocorre em exatamente uma transacao no banco do tenant e persiste:

- invoice comercial ou zero-total statement e snapshot imutavel;
- linhas com rating/usage/contract/promotion/tax refs e hashes;
- alocacao do proximo numero da serie comercial;
- `CommercialBillingJournalBatch` balanceado;
- idempotency record e estado final do run;
- outbox events sem payload sensivel.

`CommercialBillingJournalBatch` e subledger operacional de Billing; nao afirma
posting contabil ou livro estatutario, que permanecem fora do ADR-0049. Falha em linha,
numero, journal ou outbox faz rollback integral.

O ID canonico do documento e UUID. O numero humano e monotonicamente crescente
dentro de serie comercial imutavel e exclusiva do tenant/seller, atribuida no
onboarding. Gaps por rollback, reserva abortada ou operacao administrativa sao
aceitos e auditados; numero nunca e reutilizado, renumerado ou prometido como
gapless. Numeracao fiscal e independente e pertence ao ADR-0048.

## 2.10 Total zero e collectible

Se o total final e maior que zero, o resultado e `CommercialInvoice` elegivel para
collection somente apos os gates do ADR-0023. Se o total e exatamente zero, o
resultado e `ZeroTotalBillingStatement`, finalizado e numerado para explicabilidade,
mas com `collectible=false` e collection state `NOT_APPLICABLE`.

Statement de total zero nunca cria receivable, payment intent, charge, boleto,
Pix, dunning ou chamada de provider. Total inferior a zero e invalido como invoice
ou statement e segue como credit candidate causal. Frontend e provider nao podem
promover zero para valor minimo.

## 2.11 Clean Architecture, seguranca e custo

Metering, aggregation, quota, rating e close sao sub-slices coesos de
`contexts.billing`. Domain layer nao importa Spring, JPA, Redis, renderer,
frontend, ASAAS ou DTO de provider. Application orquestra por ports, recebe
`Clock` e policies explicitamente; adapters implementam PostgreSQL tenant-local,
catalogo da plataforma, scheduler e delivery de eventos.

O primeiro horizonte usa o PostgreSQL e o scheduler ja operados no monolito. Nao
adota Kafka, stream processor, data warehouse, microservico de metering ou banco
time-series. Particionamento, outbox relay e extracao futura permanecem possiveis
atras dos ports, condicionados a dados e qualificacao do ADR-0051.

Antes de repository ou disclosure, todo command/query verifica tenant, billing
account, role/authority e resource scope. Source credentials possuem menor
privilegio e rotacao; hashes nao substituem protecao de payload. Logs, metrics e
outbox nao carregam PII, raw payload, secret, coupon ou provider credential.
Erro publico nao revela existencia de outro tenant, contadores, allowance ou
event IDs competitivos.

## 2.12 Boundary da aprovacao

`D-06` fica fechado conceitualmente, inclusive quanto a copy de quota e classes de
controle da Section 2.5. `D-07` a `D-14` tambem foram fechados nos ADRs canonicos
por Codex sob `AUTH-BILLING-2026-08-25-001`, com provenance `AI_DELEGATED`, revisao
humana `NOT_PERFORMED` e `Reviewability: OPEN`. `D-00 = RELEASED_WITH_SCOPE —
HUMAN_EXPLICIT — TP-00013 local-only` permite implementação, DDL, OpenAPI, jobs
dormentes e testes herméticos locais; integração externa e efeitos reais seguem proibidos.

OpenAPI/DDL/UI, templates/idiomas reais, merchant/capabilities/tarifas ASAAS, PCI,
Sandbox, dados/pareceres legais-fiscais-contabeis, SLO/backup e aceite de piloto
continuam como artefatos ou evidencias pendentes, nao decisoes abertas.

---

# 3. Decision Drivers

- impedir dupla contagem e dupla cobranca sob replay/concorrencia;
- preservar explicabilidade desde invoice line ate evento-fonte;
- rating reproduzivel sem catalogo, frontend ou provider vivos;
- quotas seguras em PostgreSQL, compativeis com VPS e monolito modular;
- fechamento isolado por tenant, sem blast radius cross-tenant;
- late events e correcoes forward-only;
- flexibilidade por schemas/policies fechados e versionados;
- separar comercial, financeiro, fiscal e contabil.

---

# 4. Considered Options

## Option A - Ledger tenant-local append-only e close transacional em PostgreSQL

Pros: idempotencia forte, auditoria completa, baixo custo inicial, isolamento por
tenant, replay deterministico e provider-neutrality.

Cons: exige snapshots ricos, compensacoes, checkpoints e disciplina de
cardinalidade; throughput futuro pode exigir particionamento.

## Option B - Contadores mutaveis e rating sob demanda

Rejected: perde membership/lineage, torna correcao destrutiva e permite divergencia
sob retry ou troca de catalogo.

## Option C - Streaming/microservico e eventual consistency desde o inicio

Rejected: eleva custo operacional da VPS, nao elimina a necessidade de autoridade
transacional e amplia sagas antes de haver escala medida.

## Option D - Provider como meter/rating/invoice authority

Rejected: cria lock-in, mistura contrato e collection e nao preserva regras,
promocoes e database-per-tenant locais.

---

# 5. Decision Outcome

A **Option A** foi escolhida autonomamente pela IA sob
`AUTH-BILLING-2026-08-25-001`. PostgreSQL concentra as garantias que exigem
consistencia; domain policies e ports preservam evolucao sem antecipar custo de
infraestrutura distribuida.

---

# 6. Consequences

## Positive Consequences

- Um evento e contado no maximo uma vez por identidade.
- Toda linha pode explicar aggregates, eventos e snapshots usados.
- Quota concorrente falha fechada sem Redis como authority.
- Close parcial entre invoice, lines, numero, journal e outbox nao existe.
- Late event nao reabre nem reescreve documento finalizado.
- Tenant com falha nao bloqueia transacao de outro tenant.

## Negative Consequences

- Ledger append-only cresce e exigira politica de particionamento/retencao legal.
- Checkpoints e compensation events tornam o modelo mais explicito e volumoso.
- Apenas `COUNT` e `SUM` limitam casos analiticos no primeiro slice.
- Gaps de numeracao precisam ser explicados a operacao.

## Neutral Consequences

- Kafka, Redis e data warehouse nao sao proibidos como derivados futuros.
- Valor real, fiscal, approvals e thresholds operacionais seguem evidence gates
  dos ADRs aceitos aplicaveis.
- Commercial invoice nao e documento fiscal nem comprovante de pagamento.

---

# 7. Impact

- Backend: novos domain types, use cases e ports planejados em `contexts.billing`.
- Frontend: consulta/preview server-authoritative e drill-down autorizado; sem
  calculo local de quota, rating ou total.
- Database: migrations futuras tenant-local para ledger, admission, aggregates,
  rating, runs, documents, sequence, journal e outbox.
- Security: tenant guard, source authentication, anti-replay, redaction e scopes.
- Operations: scheduler tenant-by-tenant, holds explicitos e reconciliacao.
- Provider: nenhum impacto antes de materializar os gates do ADR-0023; ASAAS nao
  recebe autoridade de uso.

---

# 8. AI Agent Considerations

Agentes devem preservar `AI_DELEGATED`, nao atribuir revisao humana, nunca trocar
evento por contador destrutivo, manter `COUNT`/`SUM` como allowlist inicial,
rejeitar rating live/latest, isolar close por tenant, servir copy somente por
template server-side versionado, impedir classificacao de bypass pelo cliente e
implementar somente no escopo hermético local liberado por `D-00`.

---

# 9. Implementation Plan Boundary

1. congelar schemas canonicos, enums, errors e OpenAPI;
2. criar golden vectors de canonicalizacao, aggregation, quota e rating;
3. modelar domain puro e application ports;
4. criar migrations aditivas tenant-local e constraints de idempotencia;
5. implementar ingestion/compensation e admission PostgreSQL;
6. implementar catalogo/template server-side e classificacao fechada das operacoes
   de controle com rate-limit/anti-abuse independente;
7. implementar aggregate/rating pinned e rerating verificavel;
8. implementar checkpoints, late candidates e billing run por tenant;
9. implementar transacao unica de invoice/lines/sequence/journal/outbox;
10. integrar frontend somente por contratos reais;
11. executar testes concorrentes, tenancy, temporal, monetario, crash/replay e E2E;
12. manter flags `OFF` e liberar efeito/rollout somente apos materializar
    ADRs-0050/0051, reunir evidencias e obter autorização operacional própria.

Esta sequencia e boundary de planejamento, nao autorizacao de implementacao.

---

# 10. Validation

- same identity/hash retorna o mesmo receipt; payload divergente conflita;
- compensacao preserva original, causalidade e soma explicavel;
- dimensoes fora da allowlist nao chegam a aggregate/metric/rating;
- permutacoes de eventos geram o mesmo aggregate/hash para `COUNT` e `SUM`;
- duas admissions no ultimo slot aceitam no maximo uma;
- `NO_QUOTA`, `HARD_LIMIT`, `SOFT_LIMIT` e `OVERAGE_ALLOWED` nao se confundem;
- copy de quota referencia template/versao/locale server-side e nao existe em
  controller/frontend nem aceita customizacao tenant no primeiro slice;
- `OPT_OUT`/`EXIT`, `HUMAN_HANDOFF` e `SECURITY`/`CONSENT` server-classified
  continuam admitidos sem quota, nao consomem nem faturam e possuem anti-abuse
  separado; spoof pelo cliente falha fechado;
- rating com os mesmos snapshots reproduz valor, breakdown e hash;
- late event nao altera documento finalizado;
- close concorrente produz um unico documento/numero/journal/outbox;
- rollback pode gerar gap, mas numero nunca e reutilizado;
- total zero nunca cria collection/provider/dunning;
- falha do tenant A nao acessa nem reverte tenant B;
- docs e links passam no validador apos indexacao pelo integrador.

Esta ADR documental não cria testes por si só; implementação e testes herméticos
locais são autorizados pela liberação separada e escopada de `D-00`.

---

# 11. Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| Evento duplicado ou alterado | Chave composta + canonical payload hash + unique constraint. |
| Cardinalidade incontrolavel | Meter schema e dimensions allowlisted; texto livre/PII proibidos. |
| Quota ultrapassada por race | Reservation PostgreSQL atomica, CAS/locks e fence. |
| Copy divergir ou ficar hardcoded por canal | Catalogo/template server-side versionado e localizado; cliente somente renderiza. |
| Bypass de controle virar uso gratis | Classificacao server-side allowlisted, nao billable, rate-limit independente e spoof fail-closed. |
| Rating muda com catalogo | Todos os inputs/versions/hashes pinados. |
| Fonte silenciosa causa close incompleto | Watermark minimo e hold fail-closed. |
| Late event reescreve receita | Candidate forward-only; invoice imutavel. |
| Crash duplica numero/documento | Uma transacao + idempotency record + releitura canonica. |
| Ledger cresce alem da VPS | Indices/particoes planejados e gate medido conforme ADR-0051. |
| Journal ser confundido com contabilidade | Nome/subledger comercial e boundary explicito do ADR-0049. |

---

# 12. Related ADRs

- [ADR-0000 - Governanca documental](../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md)
- [ADR-0019 - Database-per-tenant](ADR-0019-database-per-tenant.md)
- [ADR-0023 - Provider-neutral payments](ADR-0023-agnostic-payment-provider-integration.md)
- [ADR-0027 - Catalogo global e faturamento local](ADR-0027-catalogo-global-faturamento-local.md)
- [ADR-0030 - Composicao e enforcement](ADR-0030-composicao-deterministica-enforcement-entitlements.md)
- [ADR-0034 - Efeitos nao destrutivos](ADR-0034-efeitos-transicao-nao-destrutiva-entitlements.md)
- [ADR-0038 - Pricing tipado](ADR-0038-pricing-tipado-moeda-cadencia.md)
- [ADR-0041 - Stacking promocional](ADR-0041-stacking-waterfall-promocional-deterministico.md)
- [ADR-0042 - Capacidade promocional](ADR-0042-capacidade-redemption-promocional-concorrente.md)
- [ADR-0044 - Lifecycle contratual e proration](ADR-0044-lifecycle-contratual-proration-assinaturas.md)
- [ADR-0046 - Correcao, cancelamento e reemissao](ADR-0046-correcao-cancelamento-reemissao-fatura.md)
- [ADR-0047 - Ledger, creditos e refunds](ADR-0047-ledger-creditos-refunds-disputas-writeoff.md)
- [ADR-0048 - Fatura comercial e NFS-e](ADR-0048-separacao-fatura-comercial-documento-fiscal-nfse.md)
- [ADR-0049 - Subledger tenant-local e MRR](ADR-0049-subledger-tenant-local-mrr-normalizado.md)
- [ADR-0050 - RBAC, SoD e aprovacoes](ADR-0050-rbac-sod-aprovacoes-financeiras.md)
- [ADR-0051 - SLO, capacidade e rollout](ADR-0051-slo-capacidade-rollout-billing.md)

---

# 13. References

- [REQ-00042](../product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md)
- [REQ-00011](../product/requirements/REQ-00011-chatbot-usage-limits-and-billing.md)
- [UC-00022](../product/use-cases/UC-00022-chatbot-quota-enforcement.md)
- [UC-00040](../product/use-cases/UC-00040-billing-usage-rating-invoice-close.md)
- [TP-00013](../delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md)
- [IP-BE-13.3.1-billing-usage-rating-invoice-close](../delivery/plans/implementation_plans/backend/IP-BE-13.3.1-billing-usage-rating-invoice-close.md)
- [IP-FE-13.3.1-billing-usage-rating-invoice-close](../delivery/plans/implementation_plans/frontend/IP-FE-13.3.1-billing-usage-rating-invoice-close.md)
- [Module Registry](../architecture/module-registry.md)

---

# 14. Decision Lifecycle

Current State: **Accepted — AI_DELEGATED**.

Ratificacao humana futura deve registrar ator/data e nao pode apagar a origem.
Mudanca em identity/hash, append-only, aggregation allowlist, quota admission,
template/copy, classificacao de controle, rating pins, late-event policy, atomic
close, numbering ou zero-total boundary exige nova versao aceita ou ADR sucessor.

`D-07` a `D-14` estao aceitos com a mesma origem delegada e revisao humana aberta;
isso nao comprova implementação/evidência. `D-00` foi liberado por humano somente
para implementação local dos planos TP-00013.

---

# 15. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.2 | 2026-08-25 | Solicitante humano, proprietário declarado / Codex (IA), materialização | Registra `D-00 = RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`; permite código/DDL/OpenAPI/jobs dormentes/testes herméticos locais e mantém chamadas externas, Sandbox ASAAS, piloto BP Farias, produção, flags `ON` e efeitos reais bloqueados. |
| 1.1 | 2026-08-25 | Codex (IA), sob `AUTH-BILLING-2026-08-25-001` | Emenda `D-06` como `AI_DELEGATED`, revisao humana `NOT_PERFORMED`/`OPEN`: copy de quota usa template server-side versionado/localizado com customizacao tenant `OFF`; `OPT_OUT`/`EXIT`, `HUMAN_HANDOFF` e `SECURITY`/`CONSENT` server-classified permanecem admitidos e nao billable sob anti-abuse separado. Reconcilia `D-07`–`D-14`, mantendo evidencias pendentes e `D-00` ativo. |
| 1.0 | 2026-08-25 | Codex (IA), sob `AUTH-BILLING-2026-08-25-001` | Fecha autonomamente `D-06` com ledger tenant-local append-only, identity/hash, dimensions allowlisted, `COUNT`/`SUM`, quota/admission PostgreSQL, rating pinned, late events, close por tenant, numeracao monotona com gaps, statement zero e transacao atomica; revisao humana substantiva nao realizada. |

---

# 16. Repository Structure

Este ADR cria somente documentacao. Os alvos futuros permanecem em
`contexts.billing`, com domain/application/adapter separados, migrations
tenant-local e adapters de plataforma somente para definicoes publicadas.

---

# 17. Review Process

Revisao humana permanece `OPEN`. Ratificacao deve adicionar evidencia sem mudar a
provenance; emenda material requer nova versao ou ADR sucessor. Nenhuma revisao
humana foi inferida de mensagens de delegacao ou do status `Accepted`.

---

# 18. Notes

- O documento usa `invoice` para fatura comercial GV Software contra o tenant,
  nunca para cliente final do escritorio contabil.
- BP Farias percorre o mesmo fluxo e as mesmas policies, sem branch por tenant.
- Valores, limites de safety lag, retention e capacidade serao configurados e
  validados nos gates proprios; nao sao segredo nem constante desta ADR.
