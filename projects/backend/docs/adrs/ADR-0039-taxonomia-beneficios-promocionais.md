---
document_id: "ADR-0039"
primary_nature: "Decisao"
objective: "Definir uma taxonomia fechada, segura, versionada e auditável para benefícios promocionais monetários e concessões promocionais de entitlement, preservando autoridades distintas para preço, direito e saldo financeiro."
scope: "`PromotionVersion` seller-owned, lifecycle estrutural de publicação, tipos permitidos de benefício, alvo e escopo tipados, vigência, razão, funding attribution, provenance, compatibilidade monetária com BRL, piso zero, materialização separada de `PROMOTIONAL_GRANT` e snapshots históricos."
non_objectives: "Implementar código, DDL, migration, endpoint, OpenAPI, tela, job, cache, evento ou integração; redefinir elegibilidade e segurança de cupom governadas pelo ADR-0040 ou stacking/exclusividade/waterfall governados pelo ADR-0041; definir redemption, budget, cap stateful de campanha, reserva concorrente, lifecycle operacional completo, alçadas, segregação de funções, tratamento tributário/contábil, crédito em conta, ledger pré-pago, goodwill, refund, disputa, proration, rating, invoice close, provider ou ASAAS."
owner: "Arquitetura / Billing / Produto / Financeiro / Segurança"
status: "Accepted"
date: "2026-08-25"
version: "1.4"
keywords: "promotion, PromotionVersion, promotional benefit, percentage discount, fixed amount discount, promotional price, free quantity, free period, fee waiver, promotional entitlement grant, PROMOTIONAL_GRANT, BRL, zero floor, immutable snapshot, seller funded, partner attribution"
related_files: "docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00038-billing-catalog-pricing-promotions.md`, `docs/product/use-cases/UC-00039-billing-contract-subscription-amendments.md`, `docs/delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md`, `docs/adrs/ADR-0010-tenant-plan-parametrization.md`, `docs/adrs/ADR-0023-agnostic-payment-provider-integration.md`, `docs/adrs/ADR-0027-catalogo-global-faturamento-local.md`, `docs/adrs/ADR-0028-entitlements-versionados-tenant-local.md`, `docs/adrs/ADR-0029-taxonomia-tipificada-entitlements.md`, `docs/adrs/ADR-0030-composicao-deterministica-enforcement-entitlements.md`, `docs/adrs/ADR-0032-adocao-versionada-grandfathering-entitlements.md`, `docs/adrs/ADR-0037-boundary-fisico-entitlements-billing.md`, `docs/adrs/ADR-0038-pricing-tipado-moeda-cadencia.md`, `docs/adrs/ADR-0040-elegibilidade-promocional-seguranca-cupons.md`, `docs/adrs/ADR-0041-stacking-waterfall-promocional-deterministico.md"
code_references: "AS-IS em `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/package-info.java`, `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/BillingApi.java` e `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/`; `PromotionVersion`, benefícios tipados, evaluators, snapshots, contributions, ports, adapters, contracts, tabelas e APIs desta ADR são destinos planejados e ainda não existem."
principal_statement: "A GV Software publica `PromotionVersion` imutável e effective-dated com união fechada de seis benefícios monetários e `PROMOTIONAL_ENTITLEMENT_GRANT` não monetário; benefício de preço, contribuição de entitlement e crédito/saldo são autoridades separadas, todo efeito preserva versão/hash/lineage e total monetário nunca fica negativo, sem adjustment genérico, linha negativa, DSL, fórmula ou provider."
---

# ADR-0039 - Taxonomia tipada de benefícios promocionais

- Document ID: `ADR-0039`
- Primary Nature: `Decisao`
- Objective: Definir uma taxonomia fechada, segura, versionada e auditável para benefícios promocionais monetários e concessões promocionais de entitlement, preservando autoridades distintas para preço, direito e saldo financeiro.
- Scope: `PromotionVersion` seller-owned, lifecycle estrutural de publicação, tipos permitidos de benefício, alvo e escopo tipados, vigência, razão, funding attribution, provenance, compatibilidade monetária com BRL, piso zero, materialização separada de `PROMOTIONAL_GRANT` e snapshots históricos.
- Non-objectives: Implementar código, DDL, migration, endpoint, OpenAPI, tela, job, cache, evento ou integração; redefinir elegibilidade e segurança de cupom governadas pelo ADR-0040 ou stacking/exclusividade/waterfall governados pelo ADR-0041; definir redemption, budget, cap stateful de campanha, reserva concorrente, lifecycle operacional completo, alçadas, segregação de funções, tratamento tributário/contábil, crédito em conta, ledger pré-pago, goodwill, refund, disputa, proration, rating, invoice close, provider ou ASAAS.
- Keywords: promotion, PromotionVersion, promotional benefit, percentage discount, fixed amount discount, promotional price, free quantity, free period, fee waiver, promotional entitlement grant, PROMOTIONAL_GRANT, BRL, zero floor, immutable snapshot, seller funded, partner attribution
- Related Files: `docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00038-billing-catalog-pricing-promotions.md`, `docs/product/use-cases/UC-00039-billing-contract-subscription-amendments.md`, `docs/delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md`, `docs/adrs/ADR-0010-tenant-plan-parametrization.md`, `docs/adrs/ADR-0023-agnostic-payment-provider-integration.md`, `docs/adrs/ADR-0027-catalogo-global-faturamento-local.md`, `docs/adrs/ADR-0028-entitlements-versionados-tenant-local.md`, `docs/adrs/ADR-0029-taxonomia-tipificada-entitlements.md`, `docs/adrs/ADR-0030-composicao-deterministica-enforcement-entitlements.md`, `docs/adrs/ADR-0032-adocao-versionada-grandfathering-entitlements.md`, `docs/adrs/ADR-0037-boundary-fisico-entitlements-billing.md`, `docs/adrs/ADR-0038-pricing-tipado-moeda-cadencia.md`, `docs/adrs/ADR-0040-elegibilidade-promocional-seguranca-cupons.md`, `docs/adrs/ADR-0041-stacking-waterfall-promocional-deterministico.md`
- Code References: AS-IS em `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/package-info.java`, `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/BillingApi.java` e `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/`; `PromotionVersion`, benefícios tipados, evaluators, snapshots, contributions, ports, adapters, contracts, tabelas e APIs desta ADR são destinos planejados e ainda não existem.
- Principal Decision: A GV Software publica `PromotionVersion` imutável e effective-dated com união fechada de seis benefícios monetários e `PROMOTIONAL_ENTITLEMENT_GRANT` não monetário; benefício de preço, contribuição de entitlement e crédito/saldo são autoridades separadas, todo efeito preserva versão/hash/lineage e total monetário nunca fica negativo, sem adjustment genérico, linha negativa, DSL, fórmula ou provider.
- Date: 2026-08-25
- Status: Accepted
- Version: 1.4
- Authors / Owners: Arquitetura / Billing / Produto / Financeiro / Segurança
- Reviewers: Responsável pelo produto, com aprovação explícita de `D-04.4-A — Opção A` em 2026-08-24; Arquitetura
- Stakeholders: Produto, Financeiro, Comercial, Jurídico, Backend, Frontend, Segurança, Dados, Operações, parceiros comerciais e tenants contratantes
- Supersedes: N/A; especializa promoções seller-owned do ADR-0027, a fonte `PROMOTIONAL_GRANT` do ADR-0029 e o estágio promocional mantido aberto no ADR-0038, além de restringir qualquer interpretação promocional genérica do ADR-0010.
- Superseded by: N/A

---

# 1. Context

O ADR-0027 posicionou promoções publicadas no catálogo global seller-owned e
snapshots aceitos no banco do tenant. O ADR-0029 separou grant promocional de
entitlement, enquanto o ADR-0038 manteve descontos e demais efeitos promocionais
fora do kernel de preço. Faltava definir quais benefícios uma promoção pode
representar sem transformar Billing em um mecanismo de ajustes livres.

Sem taxonomia própria, uma única operação denominada “desconto” poderia esconder
efeitos incompatíveis: reduzir preço, selecionar uma tarifa promocional, isentar
uma taxa, conceder quantidade gratuita, ampliar entitlement, depositar saldo ou
produzir linha negativa. Essa ambiguidade impediria reconstruir a obrigação,
separar funding, aplicar tributação futura e provar que uma campanha não criou
crédito ou acesso por acidente.

O projeto ainda não entrou em produção e a implementação permanece congelada.
Assim, a flexibilidade comercial pode ser construída pela composição de tipos
fechados e evolutivos, com limites explícitos entre preço, entitlement e fatos
financeiros, antes de existir compatibilidade externa.

---

# 2. Decision Statement

## 2.1 Autoridade e lifecycle estrutural de `PromotionVersion`

A GV Software é owner e seller de toda promoção do Hub. Uma promoção canônica é
representada por `PromotionVersion`, effective-dated, seller-scoped e endereçável
por identidade estável, número de versão, schema version e hash canônico.

O lifecycle conceitual mínimo usa estados fechados:

- `DRAFT`: editável, não contratável e sem efeito monetário ou operacional;
- `PUBLISHED`: conteúdo imutável e elegível apenas para os workflows que
  satisfizerem os gates normativos e executáveis aplicáveis;
- `RETIRED`: indisponível para novas aplicações, mas resolvível para replay,
  contratos, snapshots e evidências históricas já aceitas.

Publicação torna conteúdo, benefícios, alvo, vigência, provenance e funding
attribution imutáveis. Correção material exige nova versão. Retirement, expiração
ou alteração de catálogo não reescreve aplicação, contrato, cálculo, entitlement
ou snapshot aceito. A policy, os facts e o instante explícito que tornam uma
promoção candidata seguem o ADR-0040; calendário/timezone/proration seguem o
ADR-0044 e o lifecycle operacional promocional segue o ADR-0043.

Cada versão pertence ao catálogo seller-owned de `saas_platform`. Quando uma
contratação ou aplicação futura for aceita, a referência exata e o snapshot
necessário à reprodução são materializados no banco dedicado do tenant conforme
ADR-0027. Nenhum cálculo histórico resolve `latest` ou lê promoção viva.

## 2.2 União fechada de benefícios monetários

Uma `PromotionVersion` pode declarar zero ou mais benefícios monetários somente
da seguinte allowlist:

Toda `PromotionVersion` deve declarar ao menos um benefício aprovado. Zero
benefício monetário só é válido quando existir ao menos um
`PROMOTIONAL_ENTITLEMENT_GRANT`; versão completamente vazia é inválida e não pode
ser publicada.

| Código canônico | Semântica tipada | Limite obrigatório |
| --- | --- | --- |
| `PERCENTAGE_DISCOUNT` | Reduz uma base monetária elegível por percentual decimal exato. | Percentual entre zero e cem, inclusivo; a base alvo é explícita e o resultado não pode ser negativo. |
| `FIXED_AMOUNT_DISCOUNT` | Deduz um valor monetário fixo da base elegível. | Valor não negativo, em BRL no primeiro slice, limitado à base alvo remanescente. |
| `PROMOTIONAL_PRICE` | Seleciona um artefato de preço promocional publicado e versionado para o alvo elegível. | Preserva simultaneamente identidade/versão/hash do preço-base e do artefato promocional; nunca muta a `PriceVersion` original. |
| `FREE_QUANTITY` | Retira do cálculo monetário uma quantidade bounded da dimensão/linha elegível. | Quantidade, unidade, escala e alvo explícitos; não concede entitlement nem inventa usage. |
| `FREE_PERIOD` | Isenta a cobrança elegível durante quantidade bounded de períodos contratuais. | Não altera cadence, âncora, termo ou datas do contrato; ativação depende das políticas temporais futuras. |
| `FEE_WAIVER` | Isenta integralmente uma fee tipada e nomeada que seria aplicável. | Exige fee code/alvo allowlisted; não aceita linha, subtotal ou texto arbitrário como fee. |

Os códigos são discriminadores canônicos distintos. Campos opcionais não podem
converter um tipo em outro e não existe subtipo “custom”, expressão ou payload
genérico. Novos benefícios exigem decisão/versionamento formal sem reinterpretar
versões já publicadas.

`PROMOTIONAL_PRICE` não edita rate, componente ou hash da `PriceVersion`-base. A
representação física futura pode referenciar um artefato de preço promocional
compatível, mas deve conservar as duas lineages e demonstrar qual base deixou de
ser aplicada. O tipo não é override decimal, preço negociado silencioso ou
substituição in-place.

`FREE_QUANTITY` e `FREE_PERIOD` são benefícios de cálculo monetário. Eles não
criam direito de uso, não mudam modo de enforcement e não alteram contrato
temporalmente por si sós. Sua ativação faturável depende respectivamente das
autoridades de quantidade/rating do ADR-0045 e de calendário/lifecycle do
ADR-0044.

## 2.3 Benefício não monetário de entitlement

O único benefício não monetário desta taxonomia é
`PROMOTIONAL_ENTITLEMENT_GRANT`. Ele descreve uma concessão promocional explícita
e produz contribuição separada com `sourceType=PROMOTIONAL_GRANT`, conforme
ADR-0029 e ADR-0030.

Cada contribuição materializada preserva, no mínimo, a identidade, versão e hash
da `PromotionVersion`, a definição/capability alvo, valor tipado, unidade,
dimensões, vigência, snapshot/contrato aplicável, reason, provenance e lineage. A
composição, restrições dominantes, estados indeterminados e enforcement continuam
sob ADR-0030.

Um grant não reduz preço implicitamente, não cria invoice line e não altera
`PriceVersion`. Um benefício monetário não cria grant, capacidade, feature ou
quota. Uma mesma `PromotionVersion` pode declarar benefícios monetários e grants,
mas seus outputs são tipados, materializados, avaliados e auditados separadamente.

## 2.4 Fronteira com crédito, saldo e correção financeira

Não pertencem à união de benefícios promocionais:

- account credit ou saldo credor;
- aquisição ou movimentação de crédito pré-pago;
- goodwill credit ou compensação discricionária;
- refund, chargeback ou restituição;
- disputa, write-off, ajuste de reconciliação ou correção contábil;
- linha negativa ou adjustment genérico de invoice.

Esses fatos possuem lifecycle, ledger, autorização, conciliação e consequências
contábeis próprios. Ledger, saldo, expiração e refund seguem o ADR-0047; imposto e
tratamento fiscal seguem o ADR-0048; subledger e métricas gerenciais seguem o
ADR-0049. Uma promoção nunca deposita valor resgatável nem
disfarça obrigação financeira posterior.

## 2.5 Metadados obrigatórios, alvo e provenance

Cada benefício declarado possui conceitualmente:

- `benefitId` estável dentro da versão e discriminador canônico;
- target e scope tipados, com identidade/version/hash quando o alvo for versionado;
- vigência explicitamente bounded e compatível com a `PromotionVersion`;
- parâmetros próprios do tipo, moeda/unidade/escala e limites declarados;
- `reasonCode` tipado e descrição não executável;
- funding attribution tipada, versão de sua classificação e referência de
  evidência quando aplicável;
- provenance do ator/canal de origem, source, correlation e approval reference
  futura, sem segredo ou payload sensível;
- versões das policies/evaluators e lineage necessários ao replay.

Target não pode ser coluna SQL, JSONPath, reflection, claim, header, expressão ou
texto interpretado em runtime. Natureza, alvo, funding ou reason ausente,
desconhecido ou incompatível torna a publicação/aplicação inválida; não existe
fallback para “desconto genérico”.

A governança promocional do ADR-0043 e o RBAC/SoD do ADR-0050 definem os
enforcement points de publicação e aprovação. Classificação tributária/contábil
continua condicionada aos evidence gates dos ADRs-0048/0049; qualquer versão
publicada deve referenciar classificações tipadas e versionadas, nunca texto livre
como autoridade. Capturar funding attribution não antecipa quem contabiliza o
custo ou qual tratamento fiscal se aplica.

## 2.6 Seller, payer e funding attribution

GV Software permanece seller e credora da obrigação. O tenant contratante
permanece payer. Clientes contábeis atendidos pelo tenant nunca se tornam seller,
payer, provider customer ou beneficiário financeiro desta relação por causa de
uma promoção.

Funding attribution informa quem suporta comercialmente o benefício. Atribuição
integral ou parcial a parceiro não transfere propriedade do catálogo, não troca a
entidade credora, não muda merchant account e não cria relação de cobrança entre
o Hub e clientes internos do tenant. Reembolso, settlement ou accounting com
parceiro, se necessários, seguem lifecycle e handoffs próprios dos ADRs-0043 e
0049 e permanecem `OFF` sem evidência contábil competente.

## 2.7 Moeda, precisão e piso zero

Benefícios monetários respeitam moeda, minor units, decimal exato, rounding policy
e overflow do ADR-0038. No primeiro slice:

- benefício aplicável a preço faturável é compatível somente com BRL;
- valor fixo carrega BRL explicitamente e não converte moeda;
- percentual e quantidade não inferem moeda, mas somente podem reduzir base BRL
  publicável/faturável;
- artefato de `PROMOTIONAL_PRICE` deve ser currency-compatible com o preço-base;
- entitlement grant não possui valor monetário implícito.

Uma aplicação isolada ou combinada nunca pode reduzir sua base elegível abaixo de
zero nem transformar total de invoice em pagamento ao tenant. Qualquer excedente
de benefício é capped/rejeitado e não vira crédito, saldo, carry-forward ou linha
negativa. A ordem, caps stateless e alocação entre múltiplas promoções seguem o
waterfall determinístico do ADR-0041.

## 2.8 Determinismo, snapshot e ausência de provider

A avaliação individual dos tipos desta ADR permanece conceitualmente pura. A
seleção e combinação entre versões é definida pelo ADR-0041 como:

```text
combine(PricingResult, EligiblePromotionCandidates,
        PromotionCombinationPolicyVersion) -> PromotionCombinationResult
```

Todos os fatores usados na decisão entram explicitamente e participam do hash.
O evaluator não consulta relógio implícito, catálogo `latest`, configuração viva,
tenant settings, provider, webhook, locale, banco, cache ou rede durante o cálculo
puro. O ADR-0040 fornece `EligibilityDecision` e `EligibilityContextSnapshot`
pinados; `ELIGIBLE` cria somente candidata. O ADR-0041 seleciona cada
`PromotionVersion` como pacote atômico, aplica grupos/ordem/waterfall fechados e
mantém grants não monetários fora da comparação de best price. Redemption,
budget e reserva seguem o ADR-0042.

O resultado preserva conceitualmente versão/hash de promoção e alvos, entrada
canônica, benefícios aplicados/rejeitados, bases antes/depois, outputs monetários
e de entitlement separados, funding attribution, reason codes, policy versions e
hash determinístico. Preview não persiste aplicação, contrato, entitlement,
invoice, saldo ou cobrança e nunca chama ASAAS.

Expiração ou retirement posterior não modifica o resultado/snapshot aceito. Replay
usa a versão exata, os artefatos alvo pinados e o contexto materializado, não a
configuração comercial corrente.

## 2.9 Proibições explícitas

Promoções não podem usar:

- adjustment genérico, linha negativa ou desconto sem discriminador;
- DSL, SpEL, JavaScript, SQL, template executável ou fórmula arbitrária;
- mutação de `PriceVersion`, contrato, entitlement snapshot ou invoice histórica;
- `latest`, default vivo, regra hardcoded, locale ou provider como autoridade;
- crédito/saldo para absorver benefício não aplicado;
- atribuição de parceiro para trocar seller, payer, merchant ou credor;
- output monetário para conceder acesso ou grant para ocultar desconto.

Extensibilidade ocorre por novos tipos e schemas formalmente aprovados, não por
campo aberto executável.

## 2.10 Boundary da aprovação

Esta decisão foi aceita como `D-04.4-A — Opção A`. Ela fecha somente a taxonomia,
separação de autoridades, metadados e invariantes estruturais dos benefícios.

Subsequentemente, `D-04.4-B — Opção A` foi aceita no ADR-0040 para policy/facts
versionados, tri-state fail-closed, triggers/modos de cupom, HMAC,
anti-enumeration, tenant/account scope e placement. Essa decisão não altera os
sete discriminadores desta ADR nem torna um benefício aplicável.

`D-04.4-C — Opção A` foi aceita subsequentemente no ADR-0041. Essa decisão fixa
seleção atômica da `PromotionVersion`, grupos `STACK_ALL`, `EXCLUSIVE_PRIORITY` e
`EXCLUSIVE_BEST_PRICE`, ordem canônica, perfis/percentuais fechados, um único
`PROMOTIONAL_PRICE` por target, caps stateless, alocação e resultado/hash
determinísticos sem alterar os sete discriminadores desta ADR.

O baseline complementar está fechado em ADRs canônicos: `D-04.4-D` foi aprovado
diretamente pelo humano no ADR-0042; `D-04.4-E` a `D-14` foram decididos por IA
sob `AUTH-BILLING-2026-08-25-001`, com revisão humana `NOT_PERFORMED` e
`Reviewability: OPEN`, nos ADR-0043 a ADR-0051 e revisões vigentes dos ADR-0023 a
ADR-0025. `D-00 = RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`
autoriza implementação e testes herméticos locais, sem habilitar efeito real.

Também permanecem bloqueantes as evidências executáveis e externas não atestadas:
valores/campanhas reais, OpenAPI/DDL/UI, merchant/capabilities/tarifas ASAAS, PCI,
Sandbox, dados e pareceres legais/fiscais/contábeis, SLO/backup e aceite de piloto.

Não foram aprovados valores comerciais, campanha/audiência/segmento/cupom/chave
reais, policy/limites numéricos de combinação, budget, regra tributária, código,
package, DTO, DDL, migration,
endpoint, OpenAPI, UI, evento, job, cache, provisionamento, dado real ou chamada
ASAAS. Os conceitos de eligibility/cupom aceitos no ADR-0040 permanecem somente
incrementais nos planos TP-00013 sob a liberação local-only de `D-00`.

---

# 3. Decision Drivers

- oferecer flexibilidade comercial sem ajuste arbitrário ou linguagem executável;
- distinguir redução monetária, concessão de direito e saldo financeiro;
- reproduzir aplicação histórica por versão/hash e snapshot;
- impedir que free quantity/period conceda entitlement por acidente;
- impedir que grant promocional reduza cobrança implicitamente;
- preservar GV Software como seller e tenant como payer;
- suportar funding attribution sem antecipar accounting ou tributação;
- manter BRL, precisão e piso zero do kernel de pricing;
- integrar eligibility versionada do ADR-0040 e waterfall determinístico do
  ADR-0041 sem antecipar budget/reserva;
- manter provider e ASAAS fora da autoridade comercial.

---

# 4. Considered Options

## Option A: Taxonomia fechada, tipada e com autoridades separadas

Description: Usar seis benefícios monetários e um grant não monetário, todos
versionados, bounded, explicáveis e separados de crédito/saldo.

Pros:

- cobre descontos, preço promocional, quantidades/períodos gratuitos, fee waiver
  e entitlement sem um ajuste universal;
- preserva replay, segurança e auditoria;
- permite composição futura por policies explícitas;
- evita que promoção modifique preço-base ou contrato histórico;
- mantém efeitos monetários e operacionais independentes.

Cons:

- exige mais tipos, validações e contratos do que percentual/valor fixo;
- requer policies separadas; eligibility foi posteriormente fechada no ADR-0040
  e stacking/waterfall no ADR-0041, enquanto budget e alçadas permanecem em gates
  próprios;
- exige interfaces distintas para outputs monetários e de entitlement.

## Option B: Somente desconto percentual e fixo

Description: Permitir apenas redução percentual ou em valor fixo.

Pros:

- menor custo inicial;
- cálculo e UI mais simples.

Cons:

- força hacks para preço promocional, período/quantidade gratuita e fee waiver;
- não representa promoção de entitlement;
- tende a criar flags e overrides fora do modelo.

Disposition: Rejected.

## Option C: Adjustment ou expressão genérica

Description: Permitir linha negativa, expressão livre ou payload genérico capaz
de alterar qualquer subtotal/direito.

Pros:

- máxima liberdade sintática imediata;
- menor número aparente de tipos.

Cons:

- mistura preço, entitlement, crédito e correção financeira;
- amplia riscos de injection, fraude, não determinismo e abuso de privilégio;
- dificulta replay, suporte, tax, accounting e explicação de invoice;
- permite contornar seller/payer, piso zero e contrato pinned.

Disposition: Rejected.

---

# 5. Decision Outcome

A **Option A** foi aceita.

Flexibilidade promocional será obtida por composição de tipos aprovados e por
versões imutáveis, não por adjustment universal. Cada efeito conserva sua
autoridade: pricing produz redução monetária, entitlement produz
`PROMOTIONAL_GRANT` e ledger financeiro continua fora da promoção.

---

# 6. Consequences

## Positive Consequences

- Promoções podem ser reproduzidas e explicadas por versão/hash.
- Preço-base e snapshots históricos não sofrem mutação silenciosa.
- Benefício monetário não concede acesso e grant não cria desconto.
- Free period, free quantity e fee waiver não exigem linha negativa genérica.
- Funding attribution não altera seller, payer ou merchant.
- Piso zero impede promoção de virar saldo ou pagamento ao tenant.
- Provider permanece executor posterior, nunca fonte da promoção.

## Negative Consequences

- Cada benefício exige schema, validação, reason codes e testes próprios.
- O pipeline futuro precisará transportar outputs monetários e de entitlement
  separadamente.
- Promoções não poderão operar apenas com eligibility aceita no ADR-0040;
  exigem seleção/combinação do ADR-0041, enquanto budgets, lifecycle, alçadas e
  seus gates aplicáveis continuam bloqueantes.

## Neutral Consequences

- Publicação imutável não define quem pode publicar; RBAC/SoD seguem ADR-0050 e
  permanecem `OFF` sem implementação/evidência.
- Effective dating não define calendário, timezone ou proration.
- Funding attribution registra provenance, mas não contabilização ou imposto.
- Nomes aprovados são conceitos canônicos, não classes, enums, tabelas ou APIs.
- `D-00` libera implementação hermética local, sem capability, integração externa,
  piloto ou produção.

---

# 7. Impact

## Compatibility with prior decisions

| Decisão | Efeito desta ADR |
| --- | --- |
| ADR-0010 | Proíbe usar override de limite/preço como benefício promocional genérico. |
| ADR-0023 | Mantém provider fora de catálogo, cálculo e decisão promocional. |
| ADR-0027 | Posiciona `PromotionVersion` global seller-owned e snapshot/aplicação aceita tenant-local. |
| ADR-0028 | Não altera autoridade contratual nem usa catálogo vivo como fallback. |
| ADR-0029 | Especializa `PROMOTIONAL_GRANT` como output não monetário de uma `PromotionVersion` exata. |
| ADR-0030 | Grants materializados seguem composição/restrições determinísticas e nunca neutralizam risco. |
| ADR-0032 | Adoção contratual usa versão exata e nova materialização, sem overwrite. |
| ADR-0037 | Promoções permanecem slice interno de `contexts.billing`, sem novo módulo. |
| ADR-0038 | Benefícios monetários operam sobre resultados/alvos tipados sem mutar `PriceVersion`, preservando BRL, precisão e pureza. |
| ADR-0040 | Cada promoção fixa policy exata; somente decisão `ELIGIBLE` produz candidato, e cupom verificado não altera benefício nem consome redemption. |
| ADR-0041 | Seleciona `PromotionVersion` como pacote atômico, aplica grupos/ordem/waterfall determinísticos e transporta seus grants separadamente, sem lhes atribuir valor em best price. |
| ADR-0042 | Reserva/consome capacidade stateful de modo concorrente sem alterar a taxonomia. |
| ADR-0043 | Governa lifecycle, publicação, pausa, retirada e revogação sem reescrever versões históricas. |

## Impact by area

- Backend: futuro domínio puro para promotion versions, tipos e avaliação.
- Database: futuras versões globais e materializações tenant-local, sem DDL aqui.
- Frontend: futura configuração/preview por discriminadores fechados; cálculo
  autoritativo não ocorre no browser.
- Security: inputs bounded, sem DSL/linha negativa; policy/facts tri-state,
  HMAC/normalização, anti-enumeration e tenant/account scope seguem o ADR-0040.
- Finance: funding e razão rastreáveis; ledger/fiscal/subledger seguem os ADRs
  aceitos, com capabilities e evidências externas fail-closed.
- Entitlements: grants separados e vinculados a promoção versionada.
- Operations: nenhum serviço, cache, provider ou integração é criado.

---

# 8. AI Agent Considerations

Agentes que detalharem ou implementarem esta decisão devem:

1. usar somente os sete discriminadores aprovados;
2. manter `PromotionVersion` publicada imutável e snapshots pinned;
3. separar output monetário, `PROMOTIONAL_GRANT` e crédito/saldo;
4. preservar seller GV Software, payer tenant e partner funding como atribuição;
5. manter BRL, decimal exato, rounding e piso zero do ADR-0038;
6. impedir que `FREE_QUANTITY` ou `FREE_PERIOD` conceda entitlement;
7. impedir que grant altere preço ou produza invoice line;
8. conservar base e promotional price por versões/hashes independentes;
9. rejeitar adjustment genérico, linha negativa, DSL e fórmula;
10. consumir somente `EligibilityDecision`/snapshot do ADR-0040 e não interpretar
    `ELIGIBLE` ou cupom verificado como aplicação; stacking/waterfall seguem o
    ADR-0041 e budget/redemption seguem o ADR-0042;
11. aplicar alçadas, fiscal e subledger apenas pelos ADRs-0043, 0048, 0049 e 0050
    e pelos respectivos gates de evidência;
12. não criar código, DDL, OpenAPI, provider ou ASAAS a partir deste aceite;
13. marcar símbolos e stores ainda inexistentes como destinos planejados;
14. aplicar `D-00` somente como liberação humana local-only dos planos TP-00013;
15. criar testes de unidade, propriedades, contrato, precisão, imutabilidade,
    isolamento e segurança quando a implementação for autorizada.

---

# 9. Implementation Plan Boundary

Esta seção somente registra a ordem exigida para planos futuros:

1. aplicar os ADR-0040 a ADR-0043 e os gates transversais aceitos, sem inferir
   evidência de implementação;
2. congelar schemas, códigos, targets, reason codes e policy versions;
3. implementar value objects e lifecycle/hash imutável de `PromotionVersion`;
4. implementar validators por tipo, moeda, target, vigência e provenance;
5. implementar avaliação monetária pura, sem persistência ou provider;
6. implementar materialização separada de `PROMOTIONAL_GRANT`;
7. integrar o snapshot elegível do ADR-0040 e o resultado de waterfall do
   ADR-0041; integrar budget/reserva conforme o ADR-0042, sem confundir
   verificação, seleção e consumo;
8. persistir catálogo global e snapshots tenant-local após DDL aprovado;
9. publicar OpenAPI/UI somente após contratos e autorização definidos;
10. provar determinismo, segurança, isolamento e reconciliação antes do rollout.

Todo item pode avançar hermeticamente sob `D-00`. Nenhum passo usa produção, dado real, segredo ou
ASAAS para validar promoção.

---

# 10. Validation

## 10.1 Gates documentais desta decisão

- `ADR-0039` está indexada individualmente no README imediato.
- A allowlist contém exatamente seis benefícios monetários e um não monetário.
- Toda versão contém ao menos um benefício aprovado; versão vazia é inválida.
- Benefício monetário, entitlement grant e crédito/saldo permanecem separados.
- Seller, payer, funding attribution, BRL e piso zero estão explícitos.
- `PROMOTIONAL_PRICE` não muta a `PriceVersion`-base.
- Expiração não reescreve snapshot ou resultado aceito.
- `D-04.4-B` a `D-14` possuem ADRs aceitos; `D-04.4-D` preserva origem humana e
  `D-04.4-E` a `D-14` preservam origem `AI_DELEGATED`, revisão humana
  `NOT_PERFORMED`/`OPEN`; `D-00` está `RELEASED_WITH_SCOPE — HUMAN_EXPLICIT —
  TP-00013 local-only`.
- Nenhum código, SQL, contrato executável ou provider é criado por este aceite.

## 10.2 Gates futuros de implementação

- unit tests cobrem cada tipo, zero, limites e targets permitidos;
- property tests provam determinismo, piso zero e invariantes monetários;
- contract/golden tests provam versões, hashes, breakdown e reason codes estáveis;
- mutation/negative tests rejeitam tipo desconhecido, payload genérico, DSL,
  linha negativa, moeda/target/unidade incompatível e metadata ausente;
- testes de imutabilidade provam que publication, expiry e retirement não alteram
  versão ou snapshot histórico;
- testes de separação provam que benefício monetário não concede entitlement,
  grant não altera preço e excedente não vira saldo;
- testes de pin provam ausência de `latest`, default vivo ou provider lookup;
- testes tenant A/B provam isolamento de snapshot e aplicação futura;
- architecture tests mantêm evaluator sem I/O/framework/provider e frontend sem
  cálculo autoritativo;
- testes de provider provam que preview/aplicação pura não chama ASAAS;
- testes futuros de eligibility/coupon seguem os gates do ADR-0040 e testes de
  waterfall os gates do ADR-0041; budget/reserva segue o ADR-0042.

Esses testes não foram executados porque não existe mudança de software nem
autorização de implementação neste aceite documental.

---

# 11. Risks and Mitigations

| Risco | Mitigação obrigatória |
| --- | --- |
| Taxonomia virar adjustment genérico | Allowlist fechada, target tipado e nenhuma expressão/payload executável. |
| Desconto criar total negativo ou saldo | Piso zero; excedente capped/rejeitado e nunca carregado para ledger. |
| Promoção monetária conceder acesso | Outputs monetário e `PROMOTIONAL_GRANT` separados por tipo e boundary. |
| Grant ocultar desconto | Grant não produz preço, invoice line ou mutação de `PriceVersion`. |
| Preço promocional reescrever contrato | Base e artefato promocional preservam versões/hashes/lineage independentes. |
| Free quantity inventar uso/direito | Atua somente na base monetária; rating e entitlement são autoridades separadas. |
| Expiração alterar histórico | Snapshot pinado e replay pela versão/contexto aceitos. |
| Parceiro virar seller/payer por funding | Funding é attribution; seller/credor GV e payer tenant permanecem invariantes. |
| Cupom ser enumerado ou falsificado | ADR-0040 exige auth/scope antes do lookup, facts server-derived, HMAC sem plaintext, normalização fechada, rate limit e resposta pública genérica. |
| Redemption ser duplicado ou reutilizado | Reservation/consume/release idempotentes seguem ADR-0042. |
| Stack produzir resultado dependente de ordem | ADR-0041 exige policy pinada, ordem canônica, permutação estável e hash determinístico. |
| Budget excedido por concorrência | Aplicação com budget exige reserva/concorrência conforme ADR-0042. |
| Tratamento fiscal implícito | Funding/tax são provenance; cálculo fiscal exige ruleset/evidência do ADR-0048 e lifecycle do ADR-0043. |
| Provider virar source of truth | Avaliação e snapshot são locais; ASAAS permanece fora. |
| Liberação local ser confundida com rollout | `D-00` permanece explícito como local-only; chamadas externas, Sandbox ASAAS, piloto BP Farias, produção, flags `ON` e efeitos reais continuam bloqueados. |

---

# 12. Related ADRs

- [ADR-0000 - Governança documental](../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md)
- [ADR-0001 - Stack e arquitetura](ADR-0001-technology-stack-and-architecture.md)
- [ADR-0010 - Parametrização de planos](ADR-0010-tenant-plan-parametrization.md)
- [ADR-0019 - Database-per-tenant](ADR-0019-database-per-tenant.md)
- [ADR-0023 - Integração agnóstica de providers](ADR-0023-agnostic-payment-provider-integration.md)
- [ADR-0027 - Catálogo global e faturamento local](ADR-0027-catalogo-global-faturamento-local.md)
- [ADR-0028 - Entitlements versionados tenant-local](ADR-0028-entitlements-versionados-tenant-local.md)
- [ADR-0029 - Taxonomia tipificada de entitlements](ADR-0029-taxonomia-tipificada-entitlements.md)
- [ADR-0030 - Composição e enforcement de entitlements](ADR-0030-composicao-deterministica-enforcement-entitlements.md)
- [ADR-0032 - Adoção e grandfathering](ADR-0032-adocao-versionada-grandfathering-entitlements.md)
- [ADR-0037 - Boundary físico de entitlements em Billing](ADR-0037-boundary-fisico-entitlements-billing.md)
- [ADR-0038 - Pricing tipado, moeda e cadência](ADR-0038-pricing-tipado-moeda-cadencia.md)
- [ADR-0040 - Elegibilidade promocional e segurança de cupons](ADR-0040-elegibilidade-promocional-seguranca-cupons.md)
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
- [TP-00013 - Enterprise Billing Implementation](../delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md)
- [Manifesto de módulos](../architecture/module-registry.md)
- `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/package-info.java`
- `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/BillingApi.java`
- `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/`

---

# 14. Decision Lifecycle

Esta ADR está `Accepted` pela aprovação explícita de
`D-04.4-A — Opção A`. Adicionar benefício, tornar tipo customizável, misturar
autoridades, remover piso zero, permitir mutabilidade pós-publicação ou trocar
seller/payer exige nova versão formalmente aceita ou ADR sucessor.

Eligibility/coupon security (`D-04.4-B`) foi aceita subsequentemente no ADR-0040.
Stacking/waterfall (`D-04.4-C`) foi aceita subsequentemente no ADR-0041.
Budget/concurrency (`D-04.4-D`) foi aceita por decisão humana explícita no
ADR-0042. Lifecycle promocional e os demais eixos `D-04.4-E` a `D-14` foram
aceitos por decisão `AI_DELEGATED` sob `AUTH-BILLING-2026-08-25-001`, com revisão
humana `NOT_PERFORMED`/`OPEN`, nos ADRs canônicos aplicáveis. `D-00` está
`RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`; evidências externas
e readiness permanecem separadamente pendentes.

---

# 15. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.4 | 2026-08-25 | Solicitante humano, proprietário declarado / Codex (IA), materialização | Registra `D-00 = RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`; permite implementação/testes herméticos locais e mantém chamadas externas, Sandbox ASAAS, piloto BP Farias, produção, flags `ON` e efeitos reais bloqueados. |
| 1.3 | 2026-08-25 | Codex (IA), sob `AUTH-BILLING-2026-08-25-001` | Reconcilia os sucessores aceitos: `D-04.4-D` mantém aprovação humana no ADR-0042; `D-04.4-E`–`D-14` mantêm origem `AI_DELEGATED`, revisão humana `NOT_PERFORMED`/`OPEN`; preserva `D-00` ativo e os evidence gates externos/executáveis. |
| 1.2 | 2026-08-24 | Responsável pelo produto / Arquitetura | Registra ADR-0041 como decisão subsequente de `D-04.4-C`: `PromotionVersion` é pacote atômico, combinação usa grupos/ordem/waterfall fechados, best price não valora grants, `PROMOTIONAL_PRICE` é único por target e caps/alocação stateless são determinísticos; `D-04.4-D`, `D-04.4-E` e `D-00` permanecem abertos. |
| 1.1 | 2026-08-24 | Responsável pelo produto / Arquitetura / Segurança | Registra ADR-0040 como decisão subsequente de `D-04.4-B`: `PromotionVersion` fixa policy exata, somente `ELIGIBLE` vira candidato e cupom opaco/HMAC tenant-account-scoped não altera benefício nem consome redemption; mantém `D-04.4-C` a `D-04.4-E` e `D-00` abertos. |
| 1.0 | 2026-08-24 | Responsável pelo produto / Arquitetura | Aceita `D-04.4-A — Opção A`; define `PromotionVersion` imutável, seis benefícios monetários e `PROMOTIONAL_ENTITLEMENT_GRANT`, separa preço/entitlement/crédito, preserva seller/payer/funding/BRL/piso zero e mantém subdecisões e implementação bloqueadas. |

---

# 16. Repository Structure

Qualquer implementação futura permanece dentro de `contexts.billing`, respeitando
os stores platform/tenant e o boundary do ADR-0037. Este documento não cria
package, módulo, serviço, banco, migration track ou diretório de código. Os alvos
concretos do slice de promoções devem ser aprovados no implementation plan antes
da edição.

---

# 17. Review Process

Mudança editorial pode incrementar versão menor. Alteração em discriminador,
autoridade, lifecycle estrutural, target, funding invariant, moeda, piso zero,
imutabilidade, snapshot ou separação de outputs exige revisão de Arquitetura,
Billing, Produto, Financeiro e Segurança e novo aceite explícito.

---

# 18. Notes

Esta ADR maximiza flexibilidade por tipos combináveis e seguros. Representar um
benefício não o torna aplicável: eligibility/coupon security seguem o ADR-0040 e
produzem somente candidata; seleção/stacking/waterfall seguem o ADR-0041 e
produzem resultado pinado; budget/reserva, lifecycle operacional, alçadas, fiscal
e subledger seguem os ADRs-0042, 0043, 0050, 0048 e 0049, sem transformar decisão
documental em capability implementada ou evidência externa.

Sob `D-00`, esses tipos, policies, versions, ports, stores e contratos podem ser
materializados localmente pelos planos TP-00013. Nenhuma capability ou existência
em runtime deve ser inferida sem código e evidência reproduzível.
