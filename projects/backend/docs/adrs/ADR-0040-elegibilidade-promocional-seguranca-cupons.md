---
document_id: "ADR-0040"
primary_nature: "Decisao"
objective: "Definir uma política promocional de elegibilidade fechada, versionada, determinística e fail-closed, além do modelo seguro de emissão e verificação de cupons sem transformar o código em credencial de acesso ou autoridade de redemption."
scope: "`PromotionEligibilityPolicyVersion`, árvore tipada de predicados, fatos permitidos, `EligibilityContextSnapshot`, resultado tri-state, triggers automáticos ou por cupom, modos de cupom, `CouponBatchVersion`, emissão/verificação, normalização, HMAC, proteção contra enumeração e abuso, isolamento tenant/account, pontos de reavaliação e placement conceitual platform/tenant."
non_objectives: "Implementar código, DDL, migration, endpoint, OpenAPI, tela, chave, campanha, cupom real, cache, evento, rate limit operacional ou integração; redefinir stacking, exclusividade, waterfall, melhor preço, allocation e caps stateless governados pelo ADR-0041; definir budgets, caps stateful, reservation/consume/release, lifecycle operacional completo, pause/retirement/revocation comercial, alçadas, segregação de funções, tax/accounting, proration, rating, ledger, provider ou ASAAS."
owner: "Arquitetura / Billing / Produto / Segurança"
status: "Accepted"
date: "2026-08-25"
version: "1.3"
keywords: "promotion eligibility, PromotionEligibilityPolicyVersion, EligibilityContextSnapshot, tri-state, fail-closed, coupon security, CouponBatchVersion, public shared, private shared, unique assigned, batch unique, HMAC, anti-enumeration, tenant scope, deterministic policy"
related_files: "docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00038-billing-catalog-pricing-promotions.md`, `docs/product/use-cases/UC-00039-billing-contract-subscription-amendments.md`, `docs/product/use-cases/UC-00040-billing-usage-rating-invoice-close.md`, `docs/delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md`, `docs/adrs/ADR-0010-tenant-plan-parametrization.md`, `docs/adrs/ADR-0019-database-per-tenant.md`, `docs/adrs/ADR-0023-agnostic-payment-provider-integration.md`, `docs/adrs/ADR-0027-catalogo-global-faturamento-local.md`, `docs/adrs/ADR-0029-taxonomia-tipificada-entitlements.md`, `docs/adrs/ADR-0030-composicao-deterministica-enforcement-entitlements.md`, `docs/adrs/ADR-0037-boundary-fisico-entitlements-billing.md`, `docs/adrs/ADR-0038-pricing-tipado-moeda-cadencia.md`, `docs/adrs/ADR-0039-taxonomia-beneficios-promocionais.md`, `docs/adrs/ADR-0041-stacking-waterfall-promocional-deterministico.md"
code_references: "AS-IS em `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/package-info.java`, `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/BillingApi.java` e `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/`; policies, snapshots, evaluators, coupon registry, crypto ports, rate-limit ports, stores, contracts e APIs desta ADR são destinos planejados e ainda não existem."
principal_statement: "Cada `PromotionVersion` referencia uma `PromotionEligibilityPolicyVersion` publicada e imutável; somente fatos server-derived e predicados tipados podem produzir `ELIGIBLE`, enquanto ausência, inconsistência ou fonte não confiável produz `INDETERMINATE` e falha fechada. Cupom é identificador opaco, nunca autenticação, e sua verificação tenant-scoped usa normalização fechada e HMAC com segredo fora do banco, sem plaintext, enumeração, provider ou autoridade de consumo."
---

# ADR-0040 - Elegibilidade promocional e segurança de cupons

- Document ID: `ADR-0040`
- Primary Nature: `Decisao`
- Objective: Definir uma política promocional de elegibilidade fechada, versionada, determinística e fail-closed, além do modelo seguro de emissão e verificação de cupons sem transformar o código em credencial de acesso ou autoridade de redemption.
- Scope: `PromotionEligibilityPolicyVersion`, árvore tipada de predicados, fatos permitidos, `EligibilityContextSnapshot`, resultado tri-state, triggers automáticos ou por cupom, modos de cupom, `CouponBatchVersion`, emissão/verificação, normalização, HMAC, proteção contra enumeração e abuso, isolamento tenant/account, pontos de reavaliação e placement conceitual platform/tenant.
- Non-objectives: Implementar código, DDL, migration, endpoint, OpenAPI, tela, chave, campanha, cupom real, cache, evento, rate limit operacional ou integração; redefinir stacking, exclusividade, waterfall, melhor preço, allocation e caps stateless governados pelo ADR-0041; definir budgets, caps stateful, reservation/consume/release, lifecycle operacional completo, pause/retirement/revocation comercial, alçadas, segregação de funções, tax/accounting, proration, rating, ledger, provider ou ASAAS.
- Keywords: promotion eligibility, PromotionEligibilityPolicyVersion, EligibilityContextSnapshot, tri-state, fail-closed, coupon security, CouponBatchVersion, public shared, private shared, unique assigned, batch unique, HMAC, anti-enumeration, tenant scope, deterministic policy
- Related Files: `docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00038-billing-catalog-pricing-promotions.md`, `docs/product/use-cases/UC-00039-billing-contract-subscription-amendments.md`, `docs/product/use-cases/UC-00040-billing-usage-rating-invoice-close.md`, `docs/delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md`, `docs/adrs/ADR-0010-tenant-plan-parametrization.md`, `docs/adrs/ADR-0019-database-per-tenant.md`, `docs/adrs/ADR-0023-agnostic-payment-provider-integration.md`, `docs/adrs/ADR-0027-catalogo-global-faturamento-local.md`, `docs/adrs/ADR-0029-taxonomia-tipificada-entitlements.md`, `docs/adrs/ADR-0030-composicao-deterministica-enforcement-entitlements.md`, `docs/adrs/ADR-0037-boundary-fisico-entitlements-billing.md`, `docs/adrs/ADR-0038-pricing-tipado-moeda-cadencia.md`, `docs/adrs/ADR-0039-taxonomia-beneficios-promocionais.md`, `docs/adrs/ADR-0041-stacking-waterfall-promocional-deterministico.md`
- Code References: AS-IS em `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/package-info.java`, `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/BillingApi.java` e `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/`; policies, snapshots, evaluators, coupon registry, crypto ports, rate-limit ports, stores, contracts e APIs desta ADR são destinos planejados e ainda não existem.
- Principal Decision: Cada `PromotionVersion` referencia uma `PromotionEligibilityPolicyVersion` publicada e imutável; somente fatos server-derived e predicados tipados podem produzir `ELIGIBLE`, enquanto ausência, inconsistência ou fonte não confiável produz `INDETERMINATE` e falha fechada. Cupom é identificador opaco, nunca autenticação, e sua verificação tenant-scoped usa normalização fechada e HMAC com segredo fora do banco, sem plaintext, enumeração, provider ou autoridade de consumo.
- Date: 2026-08-25
- Status: Accepted
- Version: 1.3
- Authors / Owners: Arquitetura / Billing / Produto / Segurança
- Reviewers: Responsável pelo produto, com aprovação explícita de `D-04.4-B — Opção A` em 2026-08-24; Arquitetura; Segurança
- Stakeholders: Produto, Comercial, Financeiro, Backend, Frontend, Segurança, Privacidade, Operações e tenants contratantes
- Supersedes: N/A; especializa a elegibilidade mantida aberta no ADR-0039, sem alterar sua taxonomia de benefícios, e restringe qualquer filtro/cupom genérico implícito no ADR-0010.
- Superseded by: N/A

---

# 1. Context

O ADR-0039 definiu quais benefícios uma promoção pode representar, mas
deliberadamente não decidiu quem pode recebê-los nem como um cupom comprova a
intenção promocional. Sem uma policy própria, regras de audiência tenderiam a se
espalhar por controllers, consultas, headers, flags de frontend e configurações
vivas, tornando o resultado impossível de reproduzir e vulnerável a fraude.

Cupons também possuem ameaças diferentes de pricing. Código em texto puro pode
ser enumerado, vazado por URL, log ou analytics, reutilizado entre tenants ou
tratado incorretamente como autenticação. Um preview elegível pode ainda ficar
obsoleto antes do aceite ou da futura reserva, criando uma janela de TOCTOU.

O projeto ainda não entrou em produção. `D-00 = RELEASED_WITH_SCOPE —
HUMAN_EXPLICIT — TP-00013 local-only` libera implementação e testes herméticos
locais, mantendo qualquer efeito real congelado.
É, portanto, possível definir uma gramática segura e bounded antes de existir
contrato externo ou compatibilidade legada a preservar.

---

# 2. Decision Statement

## 2.1 Autoridade versionada de elegibilidade

Cada `PromotionVersion` deve referenciar exatamente uma
`PromotionEligibilityPolicyVersion` por identidade, versão, schema version e hash
canônico. A policy pertence à GV Software, é effective-dated e segue o lifecycle
estrutural fechado `DRAFT`, `PUBLISHED` e `RETIRED`:

- `DRAFT` pode ser editada, mas não decide eligibility;
- `PUBLISHED` é materialmente imutável e pode ser referenciada por versões
  promocionais compatíveis;
- `RETIRED` deixa de ser selecionável para novas referências, mas continua
  resolvível para replay de snapshots já aceitos.

Uma correção material cria nova versão. `PromotionVersion` publicada nunca segue
`latest`, policy viva ou default. Alterar policy não reescreve quote, contrato,
snapshot ou resultado que fixou versão/hash anteriores. Publicação/retirement e
revogação emergencial seguem o ADR-0043; alçadas/SoD, o ADR-0050; bounds/rollout,
o ADR-0051.

## 2.2 Gramática fechada de predicados

A policy é uma árvore finita com somente três nós de composição:

- `ALL_OF`: conjunção de um ou mais filhos;
- `ANY_OF`: disjunção de um ou mais filhos;
- `NOT`: negação de exatamente um filho.

Nós vazios, aridade inválida, profundidade, quantidade de nós, literais ou payload
acima dos limites publicados e discriminadores desconhecidos tornam a versão
inválida. Os limites numéricos serão congelados no contrato executável antes da
habilitação da capability, mas
devem ser finitos, pequenos o suficiente para custo previsível e aplicados tanto
na publicação quanto antes da avaliação.

Folhas só podem consultar fatos tipados destas famílias:

| Família de fato | Autoridade permitida | Comparações permitidas em conceito |
| --- | --- | --- |
| Tenant e billing account | Identidades do contexto autenticado e do snapshot comercial | Igualdade ou conjunto finito de IDs opacos. |
| Segmento | Membership materializada para uma `SegmentVersion` exata | Presença/ausência tipada e versão/hash exatos. |
| Catálogo | Produto, oferta, plano, add-on e `PriceVersion` exatos | Igualdade ou conjunto finito de referências versionadas. |
| Movimento comercial | Compra inicial, renewal, upgrade ou downgrade canônico | Igualdade ou conjunto finito de enums fechados. |
| Contrato | Estado e cadence do snapshot/revisão aplicável | Igualdade ou conjunto finito de valores fechados. |
| Quantidade comercial | Quantity, seats ou commitment do intent canônico | Intervalo decimal bounded com escala e limites inclusivo/exclusivo explícitos. |
| Local/canal | Canal, região e país canônicos | Igualdade ou conjunto finito de códigos allowlisted. |
| Tempo | Janela explícita comparada a um instante confiável injetado | Inclusão em intervalo com limites e timezone aprovados no artefato. |
| Histórico contratual | Fato materializado até cutoff explícito | Predicado histórico fechado, com revisão/hash e sem consulta livre. |

Cada leaf possui discriminador e schema próprios; não existe comparador universal,
campo dinâmico ou coerção entre tipos. Policy não pode ler campo livre, claim do
cliente, header, query param, cookie, SQL, JSONPath, reflection, regex arbitrária,
SpEL, JavaScript, DSL, callback, configuração viva, `latest`, provider ou PII raw.

Uso corrente, contador de redemption, budget consumido e capacidade concorrente
não são fatos desta policy. Uso/rating pertence ao ADR-0045; contadores, budgets e
consumo promocional pertencem ao ADR-0042.

## 2.3 Semântica tri-state e fail-closed

Toda folha e toda composição produz exatamente um estado:

- `ELIGIBLE`: a regra foi comprovada por fatos íntegros, vigentes e confiáveis;
- `INELIGIBLE`: um fato confiável prova que a regra não é satisfeita;
- `INDETERMINATE`: falta autoridade obrigatória ou há dado stale, incompatível,
  corrompido, conflitante, desconhecido ou não confiável.

A álgebra normativa é:

| Operador | Resultado |
| --- | --- |
| `ALL_OF` | `INELIGIBLE` se qualquer filho for `INELIGIBLE`; `ELIGIBLE` somente se todos forem `ELIGIBLE`; nos demais casos, `INDETERMINATE`. |
| `ANY_OF` | `ELIGIBLE` se qualquer filho for `ELIGIBLE`; `INELIGIBLE` somente se todos forem `INELIGIBLE`; nos demais casos, `INDETERMINATE`. |
| `NOT` | Troca `ELIGIBLE` por `INELIGIBLE` e vice-versa; preserva `INDETERMINATE`. |

No boundary de aplicação, somente `ELIGIBLE` permite que a promoção se torne
candidata à combinação futura. `INELIGIBLE` e `INDETERMINATE` não concedem
benefício, grant, reservation ou fallback. O estado indeterminado permanece
distinto internamente para diagnóstico e observabilidade protegidos; ele nunca é
convertido em eligible por `NOT`, default, retry permissivo ou frontend.

Reason codes são fechados e estáveis. A resposta pública não revela se código,
segmento, conta, policy ou campanha existe; detalhes ficam apenas em auditoria
autorizada e redigida.

## 2.4 `EligibilityContextSnapshot` e proveniência dos fatos

O evaluator recebe um `EligibilityContextSnapshot` explícito e canônico. Ele
preserva conceitualmente:

- seller GV Software, `tenantId` e `billingAccountId` opacos;
- propósito da avaliação e identity/hash do intent, quote ou revisão aplicável;
- identidade/versão/hash da `PromotionVersion`, da policy e dos artefatos de
  catálogo/segmento usados;
- cada fato com tipo, valor canônico, source, source revision/hash,
  `materializedAt`, cutoff e effective boundary;
- instante confiável `evaluatedAt`, explicitamente injetado;
- referência verificada do cupom quando exigido, nunca seu valor bruto ou digest;
- versões de schema, normalização e evaluator, reason codes e `contextHash`.

Tenant, conta, canal, país, região, contrato, quantity e histórico são derivados
server-side de fontes canônicas. Header, claim arbitrária ou campo enviado pelo
browser não se torna fato apenas por ter formato válido. Canal é o workflow
autenticado, país/região vêm de classificação confiável sem endereço raw, segmento
usa membership de versão exata e histórico possui cutoff para impedir leitura do
futuro.

O snapshot contém somente o mínimo necessário. Não inclui nome, e-mail, telefone,
documento, endereço, cliente contábil do tenant, segredo, código bruto, digest,
payload provider ou dado ASAAS.

## 2.5 Modos de ativação da promoção

Cada `PromotionVersion` declara exatamente um trigger:

- `AUTOMATIC`: a policy é avaliada sem cupom;
- `COUPON_REQUIRED`: além da policy, é obrigatória uma referência de cupom
  verificada e compatível.

Cupom não seleciona benefício livre, não altera policy, não amplia audience e não
substitui autenticação. A condição final para `COUPON_REQUIRED` é a conjunção entre
policy da promoção, policy/audience do batch e eventual assignment exato. Uma
regra de batch pode restringir, nunca ampliar, a policy da `PromotionVersion`.

Enviar código a uma promoção `AUTOMATIC` não a torna diferente nem escolhe outra
promoção. Ausência de código em `COUPON_REQUIRED` produz resposta pública genérica
de não aplicabilidade.

## 2.6 Modos de cupom e lineage

`CouponBatchVersion` publicada é seller-owned, immutable, effective-dated e ligada
por identidade/versão/hash à `PromotionVersion` e à
`PromotionEligibilityPolicyVersion` exatas. Cada registro verificável de código
também preserva essas três referências e exatamente um modo:

| Modo | Semântica |
| --- | --- |
| `PUBLIC_SHARED` | Código deliberadamente público e compartilhável; sua posse não é segredo nem prova de identidade. |
| `PRIVATE_SHARED` | Código compartilhado em audiência restrita, com alta entropia; posse continua não sendo autenticação. |
| `UNIQUE_ASSIGNED` | Código único previamente ligado a `tenantId` e `billingAccountId` opacos exatos. |
| `BATCH_UNIQUE` | Cada artefato do batch possui segredo único; assignment prévio é opcional, mas o uso sempre ocorre em contexto tenant/account autenticado. |

Modo, bindings e versões não podem ser alterados depois da emissão. Um código não
carrega amount, percentual, grant, tenant-editable claim ou regra executável. O
registro resolvido server-side é a autoridade; payload autoexplicativo enviado
pelo cliente não é aceito.

`UNIQUE_ASSIGNED` nunca é ligado a cliente contábil interno do tenant. A única
relação comercial abrangida continua GV Software como seller e tenant como payer.

## 2.7 Armazenamento, HMAC, lookup e rotação

O valor bruto de cupom privado ou único não é persistido. A verificação usa digest
HMAC keyed, com `keyId`, versão de algoritmo e domain separation. A entrada
canônica do HMAC inclui, no mínimo, domínio/protocolo, normalization version, modo,
locator/batch version e código normalizado; assignment exato participa do binding
quando aplicável.

Requisitos obrigatórios:

- segredo HMAC dedicado reside somente em secret store/KMS aprovado, nunca em
  banco, documentação, código, configuração versionada, log ou evento;
- digest possui força efetiva mínima de 128 bits e comparação em tempo constante;
- `keyId` é opaco, não secreto, e permite rotação sem tentativa sobre todas as
  chaves;
- parser versionado pode usar locator opaco não secreto para localizar batch/key
  em custo bounded, mas nunca expõe promoção, tenant, account ou benefício;
- lookup inexistente percorre caminho equivalente/dummy e usa resposta/timing
  normalizados; comparação constante isolada não é tratada como proteção completa;
- chaves antigas necessárias à verificação permanecem protegidas somente até a
  boundary aprovada; comprometimento exige revogação/reemissão governada, pois não
  existe plaintext recuperável.

Os parâmetros exatos de algoritmo, entropia, rotação, retenção e revogação serão
materializados com Segurança conforme os ADRs-0043, 0050 e 0051, sem enfraquecer
os invariantes acima nem alegar evidência inexistente.

## 2.8 Normalização e proteção do valor bruto

Cada batch fixa uma normalization version fechada. O primeiro perfil deve usar
entrada gerada ASCII-only, tamanho máximo validado antes de qualquer trabalho
caro e alfabeto que evite caracteres visualmente ambíguos para códigos privados e
únicos. Não há NFKC permissivo, transliteração ou aceitação de Unicode confusable.
Case folding, separadores e comprimento, quando admitidos, são parte explícita da
versão e não heurística de runtime.

O valor bruto:

- entra somente em comando autenticado por body; nunca URL, path ou query string;
- é redigido antes de log, trace, métrica, evento, audit payload, erro, analytics,
  APM, WAF capture, referrer, cache ou storage de browser;
- deixa de circular após o ingress; serviços internos recebem apenas referência
  verificada e contexto selado;
- para modo privado/único, é exibido uma única vez na emissão, com resposta
  `no-store`; recuperação posterior significa revogar/reemitir, nunca revelar;
- para `PUBLIC_SHARED`, pode ser divulgado por canal aprovado, mas continua fora
  da telemetria e nunca é credencial.

Digest e referência interna também são dados sensíveis, de acesso mínimo, e não
aparecem em frontend, invoice, snapshot, evento público ou mensagem de erro.

## 2.9 Autenticação, tenant scope, anti-enumeration e abuso

Autenticação e `TenantScopeGuard` ocorrem antes de lookup ou avaliação cara. O
tenant do principal, path, contexto instalado, billing account e eventual
assignment precisam coincidir. Ausência ou divergência falha antes de repository,
cache ou datasource default/shared. Cupom jamais autentica ator ou autoriza troca
de tenant/account.

Para ator já autenticado, inexistência, modo errado, batch inválido, expiração,
assignment divergente, policy `INELIGIBLE` ou `INDETERMINATE` retornam a mesma
resposta pública `PROMOTION_NOT_APPLICABLE`, sem informar qual condição falhou.
Falhas de autenticação/autorização continuam `401`/`403` antes do processamento e
throttling pode retornar `429` genérico; nenhuma dessas respostas ecoa o código.

Rate limiting multidimensional deve combinar ator, tenant/account e sinais de rede
minimizados, sem usar raw code ou digest como chave. Ele ocorre antes de HMAC,
lookup amplo ou avaliação e possui limites de custo/candidatos. Falha do limiter
em fluxo `COUPON_REQUIRED` falha fechada; promoções `AUTOMATIC` não dependem do
limiter de cupons. Retenção e cardinalidade dos sinais devem ser bounded para não
criar nova coleção de PII nem permitir DoS de um tenant contra outro.

Tentativas, reasons protegidos e correlação podem ser auditados de forma
tenant-scoped, minimizada e redigida. O frontend exibe somente mensagem genérica e
nunca diferencia cupom inexistente de audiência não elegível.

## 2.10 Placement e fronteiras transacionais

O placement conceitual especializa o ADR-0027:

| Artefato | Autoridade/store | Invariante |
| --- | --- | --- |
| `PromotionEligibilityPolicyVersion`, `SegmentVersion` e `CouponBatchVersion` | Catálogo seller-owned no control plane `saas_platform` | Publicado imutável, sem PII, invoice, segredo ou payload provider. |
| Registro verificável de cupom | Registry seller-owned no control plane `saas_platform` | Somente digest/key metadata, modo, bindings de versão e assignment opaco mínimo; sem plaintext ou contato do tenant. |
| Preview de eligibility | Efêmero | Não cria snapshot autoritativo, direito, reservation, invoice ou outbox financeiro. |
| `EligibilityContextSnapshot` e resultado aceitos | Banco dedicado do tenant | Materialização mínima ligada ao intent/quote/contrato, com tenant/account, versions/hashes, facts/reasons sanitizados e sem código/digest. |
| Redemption, budget e contadores | PostgreSQL da plataforma conforme ADR-0042 | Autoridade transacional, store e coordenação entre scopes global/tenant/account/código são separados desta ADR e continuam não implementados. |

Publicação/registro platform e aceite tenant-local são commits independentes.
Não há XA, FK, join, dual-write atômico ou fallback por catálogo vivo. O workflow
lê e verifica a versão global imutável, então grava um snapshot local próprio;
falha ou commit ambíguo não autoriza aplicação parcial. Nomes físicos de tabelas,
ports, transactions e payloads são materializados incrementalmente pelos planos
TP-00013 no escopo local-only de `D-00`.

## 2.11 Pontos de avaliação, freshness e TOCTOU

Eligibility deve ser avaliada:

1. em preview, apenas para explicação sem efeito;
2. imediatamente antes de vincular promoção a quote, termo ou amendment;
3. novamente no commit que tentar reservar/aplicar a promoção conforme ADR-0042.

Resultado de preview ou binding anterior não é bearer credential. Evidência
reutilizável deve estar ligada a tenant, billing account, purpose, intent/quote,
context hash, policy/promotion/batch/code refs, `evaluatedAt` e boundary de
expiração. Mudança de fato, versão, hash, propósito, account ou boundary invalida
o resultado. Snapshot stale nunca autoriza commit.

No commit, facts atuais são reavaliados por esta ADR; o ADR-0041 recomputa a
combinação canônica; só então o ADR-0042 reserva atomicamente o conjunto
selecionado. Se a reserva falhar, não há aplicação parcial, consumo implícito,
queda silenciosa de cupom ou reaproveitamento do preview. Esta ADR não define a
máquina de estados de redemption.

## 2.12 Determinismo, custo bounded e Clean Architecture

A avaliação de domínio é conceitualmente pura:

```text
evaluate(PromotionEligibilityPolicyVersion, EligibilityContextSnapshot)
  -> EligibilityDecision
```

`ALL_OF` e `ANY_OF` canonicalizam filhos por hash, sem depender da ordem de
inserção ou retorno do banco. Mesmos inputs canônicos, versões e instante produzem
o mesmo estado, reason set ordenado e hash. Candidate selection usa prefilter
tipado/indexável e carrega facts compartilhados uma vez; não avalia todas as
promoções nem executa N+1 por predicado.

O domínio contém AST, tipos, álgebra tri-state, canonicalização e evaluator, sem
Spring, JPA, Jackson, Redis, relógio implícito, rede ou provider. A camada de
aplicação orquestra scope guard, fact materialization, policy lookup, rate limit e
verificação de cupom por ports. Adapters implementam persistência, criptografia,
secret store, auditoria e transporte. O frontend coleta o código e renderiza
resultado sanitizado; nunca avalia, normaliza para autoridade, calcula HMAC ou
seleciona promotion.

ASAAS e qualquer provider ficam fora de emissão, verificação e eligibility.

## 2.13 Boundary da aprovação

Esta decisão foi aceita como `D-04.4-B — Opção A`. Ela fecha a gramática de
eligibility, os facts permitidos, tri-state fail-closed, triggers/modos de cupom,
linhas de segurança e separation of concerns.

Subsequentemente, `D-04.4-C — Opção A` foi aceita no ADR-0041. A combinação
consome somente candidatas `ELIGIBLE` e sua evidência pinada; não relê cupom bruto
nem reinterpreta os facts desta ADR. No commit, esta ADR reavalia eligibility, o
ADR-0041 recombina e o ADR-0042 reserva o conjunto selecionado.

O baseline complementar está fechado: `D-04.4-D` foi aprovado diretamente pelo
humano no ADR-0042; `D-04.4-E` a `D-14` foram decididos por IA sob
`AUTH-BILLING-2026-08-25-001`, com revisão humana `NOT_PERFORMED` e
`Reviewability: OPEN`, nos ADR-0043 a ADR-0051 e revisões vigentes dos ADR-0023 a
ADR-0025. `D-00` permite implementação hermética local dos planos TP-00013 e não
autoriza chamada externa, Sandbox, piloto ou produção.

Continuam pendentes os gates executáveis e externos: campanha/limites reais,
OpenAPI/DDL/UI, merchant/capabilities/tarifas ASAAS, PCI, Sandbox, dados e
pareceres legais/fiscais/contábeis, SLO/backup e aceite de piloto.

Não foram aprovados campanha, audiência, segmento, código, chave, limite numérico,
emissão real, benefício aplicável, redemption, DDL, package, classe, endpoint,
OpenAPI, UI, job, evento, cache, dado real, segredo ou chamada ASAAS.

---

# 3. Decision Drivers

- produzir eligibility reproduzível e explicável por versões/hashes;
- impedir fail-open diante de dado ausente, stale ou não confiável;
- oferecer audiência flexível sem expressão arbitrária;
- impedir que cupom seja autenticação, claim de benefício ou chave cross-tenant;
- reduzir enumeração, vazamento, replay de preview e brute force;
- preservar privacidade e ausência de código em telemetria;
- limitar profundidade, cardinalidade e custo de avaliação;
- manter domínio puro e provider-neutral;
- separar verificação de cupom de redemption concorrente;
- preservar catálogo global e materialização tenant-local sem XA.

---

# 4. Considered Options

## Option A: Policy tipada/versionada, tri-state e cupons opacos protegidos

Description: Usar árvore fechada sobre facts server-derived, resultado tri-state
fail-closed e registro de cupom com HMAC, isolamento tenant/account,
anti-enumeration e reavaliação nos boundaries.

Pros:

- alta flexibilidade por composição segura de predicados;
- replay determinístico e razão auditável;
- segurança de cupom independente do provider;
- proteção contra ausência de fato, enumeração e vazamento;
- separação clara de `D-04.4-C` e `D-04.4-D`.

Cons:

- exige schemas, fact materialization, crypto/key management e testes de
  segurança mais ricos;
- impõe limites estruturais e não permite campo ad hoc;
- requer reavaliação antes de binding e commit.

## Option B: Filtros mínimos e cupom em plaintext

Description: Usar flags/colunas simples, booleano eligible/ineligible e armazenar
o código para consulta direta.

Pros:

- menor custo inicial;
- implementação e operação aparentam ser simples.

Cons:

- ausência de fato tende a virar fail-open;
- plaintext vaza por banco, suporte e telemetria;
- filtros crescem sem versionamento ou replay;
- favorece BOLA, enumeração e divergência frontend/backend.

Disposition: Rejected.

## Option C: Rules engine, DSL ou serviço externo de elegibilidade

Description: Delegar predicates e coupons a scripts, expressão genérica ou motor
externo.

Pros:

- liberdade sintática e mudança rápida;
- catálogo aparente de regras ilimitado.

Cons:

- amplia injection, custo, lock-in e superfície operacional;
- dificulta determinismo, auditoria, tenant isolation e replay;
- adiciona disponibilidade externa à contratação;
- pode transformar provider/configuração em autoridade comercial.

Disposition: Rejected.

---

# 5. Decision Outcome

A **Option A** foi aceita.

Flexibilidade será obtida pela composição bounded de facts e predicados tipados,
não por campo livre. Somente `ELIGIBLE` produz candidato; cupom verificado apenas
satisfaz o trigger e nunca substitui policy, autenticação ou futura reserva.

---

# 6. Consequences

## Positive Consequences

- Eligibility pode ser reproduzida por policy/context/version hash.
- Fato ausente ou conflitante não concede benefício.
- Cupom privado/único não fica disponível em plaintext.
- Tenant/account e intent ficam ligados à evidência.
- Preview não cria autoridade reutilizável.
- Frontend, provider e configuração viva deixam de decidir audience.
- Custo de policy e candidate evaluation permanece bounded.

## Negative Consequences

- É necessário materializar fatos confiáveis e suas revisions/hashes.
- Crypto/key rotation, emissão one-time e rate limiting exigem operação própria.
- Publicação de policy complexa requer validação estrutural e golden vectors.
- Reavaliação no commit aumenta trabalho, embora elimine decisão stale.

## Neutral Consequences

- `PUBLIC_SHARED` não é segredo e depende integralmente de autenticação/policy.
- Esta ADR não torna uma promoção reservável ou aplicável; stacking/waterfall é
  autoridade separada do ADR-0041.
- Nomes aprovados são conceitos canônicos, não classes, tabelas ou endpoints.
- Limites numéricos e alçadas permanecem nos gates operacionais.
- `D-00` libera implementação hermética local, sem capability ou efeito real.

---

# 7. Impact

## Compatibility with prior decisions

| Decisão | Efeito desta ADR |
| --- | --- |
| ADR-0010 | Proíbe eligibility por override de plano/settings e cupom em campo livre. |
| ADR-0019 | Mantém evidência aceita e fatos tenant-scoped no banco dedicado do tenant. |
| ADR-0023 | Mantém provider e ASAAS fora de eligibility e coupon verification. |
| ADR-0027 | Posiciona policies/batches/registry seller-owned no control plane e snapshot aceito tenant-local. |
| ADR-0029 | `PROMOTIONAL_GRANT` só pode nascer depois de promoção elegível e materializada, sem mudar sua natureza. |
| ADR-0030 | Apenas grant já elegível/materializado entra na álgebra de entitlement. |
| ADR-0037 | Mantém o slice dentro de `contexts.billing`, sem módulo ou dependência novos. |
| ADR-0038 | Eligibility seleciona candidato, mas não altera `PriceVersion` nem executa pricing. |
| ADR-0039 | Especializa a aplicabilidade dos benefícios tipados sem mudar a allowlist ou autoridades. |
| ADR-0041 | Consome somente candidatas `ELIGIBLE`/evidência pinada, sem reler cupom ou facts; no commit, esta ADR reavalia antes de a combinação ser recalculada e reservada. |
| ADR-0042 | Reserva o conjunto stateful selecionado com autoridade PostgreSQL, atomicidade e reconciliação próprias. |
| ADR-0043 | Governa publicação, pausa, retirada e revogação de promoção/campanha/lote/capacidade. |

## Impact by area

- Backend: futuro evaluator puro, orchestration e adapters separados por ports.
- Database: futuros artefatos platform e materialização tenant-local, sem DDL aqui.
- Frontend: futura entrada de cupom por body e resposta sanitizada, sem cálculo.
- Security: HMAC, segredo externo, normalização fechada, anti-enumeration, rate
  limiting, one-time reveal e tenant scope obrigatórios.
- Privacy: facts e auditoria minimizados, sem PII raw ou código/digest em telemetry.
- Operations: rotação/revogação e SLO seguem os ADRs-0043/0051, mas parâmetros
  reais e evidências operacionais continuam fail-closed.
- Finance/Provider: nenhum ledger, cobrança, invoice ou ASAAS é acionado.

---

# 8. AI Agent Considerations

Agentes que detalharem ou implementarem esta decisão devem:

1. usar somente `ALL_OF`, `ANY_OF`, `NOT` e leaf discriminada;
2. aplicar exatamente a tabela tri-state, preservando indeterminate sob `NOT`;
3. impor bounds antes de parse/evaluation e canonicalizar ordem comutativa;
4. aceitar somente facts server-derived com source revision/hash/cutoff;
5. fixar policy/promotion/batch/code refs exatos, nunca `latest`;
6. tratar coupon como identificador, nunca auth ou payload de benefício;
7. guardar somente HMAC keyed e metadata, com segredo fora do banco;
8. impedir raw/digest em URL, logs, traces, metrics, events, analytics e frontend;
9. validar principal/path/context/account antes de lookup e transação;
10. retornar `PROMOTION_NOT_APPLICABLE` sem oracle de existência;
11. reavaliar facts no binding e futuro commit; preview não autoriza;
12. depois da reavaliação no commit, entregar candidatas/evidências pinadas ao
    ADR-0041 para recombinação pura e somente então ao ADR-0042;
13. reservar, consumir e liberar redemption exclusivamente conforme ADR-0042;
14. manter domínio sem I/O/framework/provider e frontend sem autoridade;
15. criar código, DDL, OpenAPI e fixtures somente no escopo hermético local de
    `D-00`, sem chave/cupom real nem ASAAS externo;
16. criar os testes de segurança, propriedades e isolamento desta ADR quando a
    implementação for autorizada.

---

# 9. Implementation Plan Boundary

Esta seção registra somente a ordem futura:

1. aplicar os ADR-0041 a ADR-0043 e os gates transversais aceitos, sem inferir
   implementação ou evidência operacional;
2. congelar schemas, bounds, facts, operators, reasons e normalization profile;
3. congelar threat model, algoritmo HMAC, key lifecycle e contratos de redaction;
4. implementar AST/value objects/evaluator puro e property tests;
5. implementar fact materialization e scope guard por ports;
6. implementar emissão/verificação, secret adapter e rate limiter;
7. persistir catálogo/registry platform e snapshots aceitos tenant-local;
8. integrar a combinação conforme ADR-0041 somente após reavaliação desta ADR e
   reservation conforme ADR-0042;
9. publicar OpenAPI/UI somente após contrato, RBAC e redaction aprovados;
10. provar isolamento, determinismo, timing/error equivalence e ausência de
    vazamento antes de rollout.

Todo item pode avançar hermeticamente sob `D-00`. Testes usarão secrets/fixtures efêmeros e nunca
produção, cupom real, tenant real ou ASAAS.

---

# 10. Validation

## 10.1 Gates documentais desta decisão

- `ADR-0040` está indexada individualmente no README imediato.
- `PromotionVersion` fixa uma policy exata e publicada.
- A árvore aceita somente `ALL_OF`, `ANY_OF`, `NOT` e facts allowlisted.
- A tabela tri-state é total e `INDETERMINATE` falha fechada.
- Triggers e quatro modos de cupom estão fechados.
- HMAC, key separation, normalização e one-time reveal estão explícitos.
- Tenant/account guard, resposta genérica e rate limiting estão explícitos.
- Preview, binding e commit possuem reavaliação/boundaries distintas.
- Placement global/local não cria XA ou dual-write.
- `D-04.4-C` a `D-14` possuem ADRs aceitos; `D-04.4-D` preserva origem humana e
  `D-04.4-E` a `D-14` preservam origem `AI_DELEGATED`, revisão humana
  `NOT_PERFORMED`/`OPEN`; `D-00` está `RELEASED_WITH_SCOPE — HUMAN_EXPLICIT —
  TP-00013 local-only`.
- Nenhum código, SQL, chave, cupom, contrato executável ou provider é criado.

## 10.2 Gates futuros de implementação

- golden/property tests cobrem a tabela tri-state, inclusive `NOT` de
  indeterminate e permutação de filhos;
- tests rejeitam nó vazio/desconhecido, type mismatch, payload oversized,
  depth/arity/node/literal bomb e custo/candidatos acima do bound;
- tests provam canonical hash, reason ordering e resultado idêntico para inputs
  equivalentes;
- tests rejeitam fact vindo de header/claim/browser, revision/hash inválido,
  cutoff futuro, segment version divergente e PII raw;
- crypto tests cobrem domain/batch/mode/assignment substitution, entropia,
  normalização/confusables, constant-time compare, key rotation e compromise;
- security tests provam resposta equivalente para miss/expired/wrong account/
  ineligible/indeterminate e ausência de enumeration por timing observável;
- leak tests provam zero raw/digest em log, trace, metric, event, audit público,
  browser storage, analytics e error;
- tenant tests cobrem principal/path/context/account mismatch e ausência de shared
  datasource fallback;
- TOCTOU tests rejeitam preview stale, purpose/intent replay e mudança de facts no
  commit;
- rate-limit tests cobrem brute force, cardinalidade, falha do limiter e isolamento
  entre tenants;
- architecture tests mantêm domínio sem I/O/framework/provider e frontend sem
  evaluator/HMAC;
- provider tests provam zero chamada ASAAS em emissão/verificação/evaluation.

Esses testes não foram executados porque a mudança é exclusivamente documental e
`D-00` permite implementação hermética local e proíbe efeitos fora desse escopo.

---

# 11. Risks and Mitigations

| Risco | Mitigação obrigatória |
| --- | --- |
| `NOT` de dado ausente conceder promoção | Tabela tri-state preserva `INDETERMINATE`. |
| Policy causar CPU/stack DoS | Bounds de depth/nodes/arity/literals/input e prefilter indexável. |
| Fact do cliente forjar eligibility | Somente materialização server-derived com source revision/hash. |
| Código ser enumerado | Auth/scope primeiro, rate limit, lookup bounded e resposta/timing genéricos. |
| Banco expor cupons | Somente HMAC keyed; segredo fora do store; plaintext não recuperável. |
| Normalização aceitar confusable | Perfil ASCII fechado, versionado e sem NFKC/transliteração permissiva. |
| Código vazar por observabilidade | Body-only, redaction precoce e zero raw/digest em toda telemetry. |
| Cupom cruzar tenant/account | Guard antes do lookup e assignment/binding exatos. |
| Cupom virar autenticação | Autenticação/RBAC antecedem o cupom; posse nunca autoriza. |
| Preview ser reutilizado no commit | Evidência bound e reavaliação obrigatória com facts atuais. |
| Verificação ser confundida com consumo | ADR-0042 é a única autoridade de reservation/consume/release. |
| Control plane causar dual-write | Commits platform/tenant independentes, snapshot local e nenhuma XA/FK/join. |
| Frontend ou ASAAS decidir audience | Evaluator canônico no domínio Billing; frontend/provider sem autoridade. |
| Liberação local ser confundida com rollout | `D-00` permanece explícito como local-only; chamadas externas, Sandbox ASAAS, piloto BP Farias, produção, flags `ON` e efeitos reais continuam bloqueados. |

---

# 12. Related ADRs

- [ADR-0000 - Governança documental](../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md)
- [ADR-0001 - Stack e arquitetura](ADR-0001-technology-stack-and-architecture.md)
- [ADR-0010 - Parametrização de planos](ADR-0010-tenant-plan-parametrization.md)
- [ADR-0019 - Database-per-tenant](ADR-0019-database-per-tenant.md)
- [ADR-0023 - Integração agnóstica de providers](ADR-0023-agnostic-payment-provider-integration.md)
- [ADR-0027 - Catálogo global e faturamento local](ADR-0027-catalogo-global-faturamento-local.md)
- [ADR-0029 - Taxonomia tipificada de entitlements](ADR-0029-taxonomia-tipificada-entitlements.md)
- [ADR-0030 - Composição e enforcement de entitlements](ADR-0030-composicao-deterministica-enforcement-entitlements.md)
- [ADR-0037 - Boundary físico de entitlements em Billing](ADR-0037-boundary-fisico-entitlements-billing.md)
- [ADR-0038 - Pricing tipado, moeda e cadência](ADR-0038-pricing-tipado-moeda-cadencia.md)
- [ADR-0039 - Taxonomia tipada de benefícios promocionais](ADR-0039-taxonomia-beneficios-promocionais.md)
- [ADR-0041 - Stacking e waterfall promocional determinísticos](ADR-0041-stacking-waterfall-promocional-deterministico.md)
- [ADR-0042 - Capacidade e redemption promocional](ADR-0042-capacidade-redemption-promocional-concorrente.md)
- [ADR-0043 - Governança e lifecycle promocional](ADR-0043-governanca-lifecycle-promocional.md)
- [ADR-0044 - Lifecycle contratual e proration](ADR-0044-lifecycle-contratual-proration-assinaturas.md)
- [ADR-0045 - Metering, rating e fechamento](ADR-0045-metering-rating-fechamento-fatura.md)
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
- [TP-00013 - Enterprise Billing Implementation](../delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md)
- [Manifesto de módulos](../architecture/module-registry.md)
- `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/package-info.java`
- `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/BillingApi.java`
- `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/`

---

# 14. Decision Lifecycle

Esta ADR está `Accepted` pela aprovação explícita de
`D-04.4-B — Opção A`. Adicionar fact genérico, operador executável, fallback
permissivo, novo modo de cupom, plaintext, autenticação por cupom, lookup
cross-tenant ou mutabilidade pós-publicação exige nova versão formalmente aceita
ou ADR sucessor.

Stacking/waterfall (`D-04.4-C`) foi aceita subsequentemente no ADR-0041, sem
alterar a álgebra tri-state ou a segurança de cupom desta ADR. Budget/concurrency/
redemption (`D-04.4-D`) foi aceita por decisão humana explícita no ADR-0042.
Lifecycle promocional e os demais eixos `D-04.4-E` a `D-14` foram aceitos por
decisão `AI_DELEGATED` sob `AUTH-BILLING-2026-08-25-001`, com revisão humana
`NOT_PERFORMED`/`OPEN`. `D-00` está `RELEASED_WITH_SCOPE — HUMAN_EXPLICIT —
TP-00013 local-only`; evidências externas e readiness continuam separadamente pendentes.

---

# 15. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.3 | 2026-08-25 | Solicitante humano, proprietário declarado / Codex (IA), materialização | Registra `D-00 = RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`; permite implementação/DDL/OpenAPI/testes herméticos locais, com fixtures efêmeras, e mantém chamadas externas, chaves/cupons reais, Sandbox ASAAS, piloto BP Farias, produção, flags `ON` e efeitos reais bloqueados. |
| 1.2 | 2026-08-25 | Codex (IA), sob `AUTH-BILLING-2026-08-25-001` | Reconcilia os sucessores aceitos: `D-04.4-D` humano no ADR-0042 e `D-04.4-E`–`D-14` `AI_DELEGATED`, revisão humana `NOT_PERFORMED`/`OPEN`; substitui referências de decisão aberta pelos ADRs canônicos e mantém `D-00`/evidências ativos. |
| 1.1 | 2026-08-24 | Responsável pelo produto / Arquitetura / Segurança | Registra ADR-0041 como decisão subsequente de `D-04.4-C`: combinação consome apenas candidatas `ELIGIBLE` e evidência pinada, sem cupom/facts vivos; no commit, ADR-0040 reavalia, ADR-0041 recombina e `D-04.4-D` reservará atomicamente; mantém `D-04.4-D`, `D-04.4-E` e `D-00` abertos. |
| 1.0 | 2026-08-24 | Responsável pelo produto / Arquitetura / Segurança | Aceita `D-04.4-B — Opção A`; define policy/facts/predicados versionados, tri-state fail-closed, triggers e quatro modos de cupom, HMAC/normalização/anti-enumeration, tenant scope, reavaliação e placement platform/tenant, mantendo consumo, waterfall, lifecycle e implementação bloqueados. |

---

# 16. Repository Structure

Qualquer implementação futura permanece como slice interno de
`contexts.billing`, com domínio puro e adapters platform/tenant/crypto/audit,
conforme ADR-0037. Este documento não cria package, módulo, tabela, migration
track, cache, serviço ou diretório. Nomes concretos exigem o plano TP-00013
aplicável e permanecem dentro do escopo local-only de `D-00`.

---

# 17. Review Process

Mudança editorial pode incrementar versão menor. Alteração em facts, operators,
tri-state, trigger/mode, normalização, HMAC, binding, resposta pública, placement,
freshness, tenant scope ou boundary de redemption exige revisão de Arquitetura,
Billing, Produto e Segurança e novo aceite explícito.

---

# 18. Notes

Eligibility responde se a promoção pode participar da próxima etapa; o ADR-0041
responde qual pacote promocional vence e em qual waterfall; o ADR-0042 responde se
budget/redemption pode ser reservado. Essa separação evita que verificação de
cupom ou combinação se torne lock, contador ou autorização de consumo.

Sob `D-00`, esses tipos, policies, evaluators, ports, stores e contratos podem ser
materializados localmente pelos planos TP-00013. Nenhuma capability ou existência
em runtime deve ser inferida sem código e evidência reproduzível.
