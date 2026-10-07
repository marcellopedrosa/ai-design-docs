---
document_id: "ADR-0038"
primary_nature: "Decisao"
objective: "Definir o núcleo canônico, tipado, composável, determinístico e versionado de pricing, incluindo moeda inicialmente faturável, cadências, momento da cobrança, modelos permitidos, semântica numérica, versionamento contratual e simulação pura."
scope: "Catálogo seller-owned de preços, `PriceVersion`, componentes de preço, moeda ISO, cadência comercial, charge timing, dimensões tipadas, tiers, limites monetários, compromisso mínimo, cálculo pré-pago sem ledger, regras de arredondamento, pin contratual, preço negociado e resultado de simulação."
non_objectives: "Implementar código, DDL, migration, endpoint HTTP, OpenAPI, tela, job, cache, evento ou integração; definir preço comercial concreto; publicar catálogo em runtime; aprovar fórmula arbitrária; redefinir promotion waterfall/stacking/exclusividade governados pelo ADR-0041, eligibility/cupom do ADR-0040, budget, alçada, proration, calendário contratual, metering/rating autoritativo, fechamento de invoice, imposto, ledger/saldo/top-up pré-pago, FX, liquidação multimoeda, provider ou ASAAS."
owner: "Arquitetura / Billing / Produto / Financeiro / Segurança / Dados"
status: "Accepted"
date: "2026-08-25"
version: "1.9"
keywords: "pricing, PriceVersion, BRL, ISO 4217, currency-ready, billing cadence, charge timing, fixed price, per seat, per unit, package block, tiered pricing, allowance, overage, minimum commitment, prepaid calculation, exact decimal, rounding, deterministic simulation"
related_files: "README.md, ../../../docs/specs/TP-00013-enterprise-billing-implementation-task-plan.md, ADR-0010-tenant-plan-parametrization.md, ADR-0023-agnostic-payment-provider-integration.md, ADR-0027-catalogo-global-faturamento-local.md, ADR-0028-entitlements-versionados-tenant-local.md, ADR-0029-taxonomia-tipificada-entitlements.md, ADR-0030-composicao-deterministica-enforcement-entitlements.md, ADR-0032-adocao-versionada-grandfathering-entitlements.md, ADR-0037-boundary-fisico-entitlements-billing.md, ADR-0039-taxonomia-beneficios-promocionais.md, ADR-0040-elegibilidade-promocional-seguranca-cupons.md, ADR-0041-stacking-waterfall-promocional-deterministico.md"
code_references: "AS-IS em `app/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/domain/catalog/`, `app/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/domain/pricing/`, `app/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/application/model/pricing/`, `app/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/application/usecase/pricing/` e testes espelho; os slices S1–S6 materializam `PriceVersion`, moeda/policy monetária, `FIXED`, `PER_SEAT`, `PER_UNIT`, `PACKAGE_BLOCK`, `STAIRSTEP`, schemas versionados de quantidade/rate, policies pinadas de rounding/contagem/tiers, inputs V1–V3, conteúdo/resultado V1–V5, lifecycle/hash, evaluator/resultado e simulação puros. Demais modelos, ports/adapters, persistência, DDL, OpenAPI e UI continuam planejados."
principal_statement: "Pricing usa uma álgebra fechada de componentes tipados, dados monetários exatos e `PriceVersion` publicada imutável. Somente BRL e as cadências `MONTHLY`, `ANNUAL` e `ONE_TIME` podem ser publicadas e faturadas inicialmente; timing usa `IN_ADVANCE`, `IN_ARREARS` ou `HYBRID`, contratos fixam versão e hash exatos, e toda simulação é pura, explicável e independente de provider, sem DSL ou fórmula executável arbitrária."
---

# ADR-0038 - Pricing tipado, moeda e cadência do primeiro slice

- Document ID: `ADR-0038`
- Primary Nature: `Decisao`
- Objective: Definir o núcleo canônico, tipado, composável, determinístico e versionado de pricing, incluindo moeda inicialmente faturável, cadências, momento da cobrança, modelos permitidos, semântica numérica, versionamento contratual e simulação pura.
- Scope: Catálogo seller-owned de preços, `PriceVersion`, componentes de preço, moeda ISO, cadência comercial, charge timing, dimensões tipadas, tiers, limites monetários, compromisso mínimo, cálculo pré-pago sem ledger, regras de arredondamento, pin contratual, preço negociado e resultado de simulação.
- Non-objectives: Implementar código, DDL, migration, endpoint HTTP, OpenAPI, tela, job, cache, evento ou integração; definir preço comercial concreto; publicar catálogo em runtime; aprovar fórmula arbitrária; redefinir promotion waterfall/stacking/exclusividade governados pelo ADR-0041, eligibility/cupom do ADR-0040, budget, alçada, proration, calendário contratual, metering/rating autoritativo, fechamento de invoice, imposto, ledger/saldo/top-up pré-pago, FX, liquidação multimoeda, provider ou ASAAS.
- Keywords: pricing, PriceVersion, BRL, ISO 4217, currency-ready, billing cadence, charge timing, fixed price, per seat, per unit, package block, tiered pricing, allowance, overage, minimum commitment, prepaid calculation, exact decimal, rounding, deterministic simulation
- Related Files: `docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00038-billing-catalog-pricing-promotions.md`, `docs/product/use-cases/UC-00039-billing-contract-subscription-amendments.md`, `docs/product/use-cases/UC-00040-billing-usage-rating-invoice-close.md`, `../../../docs/specs/TP-00013-enterprise-billing-implementation-task-plan.md`, `ADR-0010-tenant-plan-parametrization.md`, `ADR-0023-agnostic-payment-provider-integration.md`, `ADR-0027-catalogo-global-faturamento-local.md`, `ADR-0028-entitlements-versionados-tenant-local.md`, `ADR-0029-taxonomia-tipificada-entitlements.md`, `ADR-0030-composicao-deterministica-enforcement-entitlements.md`, `ADR-0032-adocao-versionada-grandfathering-entitlements.md`, `ADR-0037-boundary-fisico-entitlements-billing.md`, `ADR-0039-taxonomia-beneficios-promocionais.md`, `ADR-0040-elegibilidade-promocional-seguranca-cupons.md`, `ADR-0041-stacking-waterfall-promocional-deterministico.md`
- Code References: AS-IS em `app/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/domain/catalog/`, `app/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/domain/pricing/`, `app/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/application/model/pricing/`, `app/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/application/usecase/pricing/` e testes espelho; os slices S1–S6 materializam `PriceVersion`, moeda/policy monetária, `FIXED`, `PER_SEAT`, `PER_UNIT`, `PACKAGE_BLOCK`, `STAIRSTEP`, schemas versionados de quantidade/rate, policies pinadas de rounding/contagem/tiers, inputs V1–V3, conteúdo/resultado V1–V5, lifecycle/hash, evaluator/resultado e simulação puros. Demais modelos, ports/adapters, persistência, DDL, OpenAPI e UI continuam planejados.
- Principal Decision: Pricing usa uma álgebra fechada de componentes tipados, dados monetários exatos e `PriceVersion` publicada imutável. Somente BRL e as cadências `MONTHLY`, `ANNUAL` e `ONE_TIME` podem ser publicadas e faturadas inicialmente; timing usa `IN_ADVANCE`, `IN_ARREARS` ou `HYBRID`, contratos fixam versão e hash exatos, e toda simulação é pura, explicável e independente de provider, sem DSL ou fórmula executável arbitrária.
- Date: 2026-08-25
- Status: Accepted
- Version: 1.9
- Authors / Owners: Arquitetura / Billing / Produto / Financeiro / Segurança / Dados
- Reviewers: Responsável pelo produto, com aprovação explícita de `D-04.3 — Opção A` em 2026-08-24; Arquitetura
- Stakeholders: Produto, Financeiro, Comercial, Jurídico, Backend, Frontend, Segurança, Dados, Operações e tenants contratantes
- Supersedes: N/A; restringe o desenho de pricing implícito ou provider-owned do ADR-0008 e especializa os aspectos de preço ainda abertos no ADR-0010.
- Superseded by: N/A

---

# 1. Context

O catálogo global e o faturamento tenant-local foram separados pelo ADR-0027. Os
ADRs de entitlements fecharam autoridade, taxonomia, composição, adoção e boundary
físico, mas não definiram como representar ou calcular preço. Sem uma decisão
própria, o primeiro slice poderia cair em um de dois extremos inadequados:

- um valor mensal fixo e rígido, incapaz de atender contratos enterprise;
- uma linguagem de fórmulas arbitrárias, difícil de proteger, auditar, reproduzir
  e manter entre catálogo, contrato, simulação e invoice.

O projeto ainda não entrou em produção. Isso permite fixar uma base pequena e
forte antes de existir compatibilidade externa, preservando flexibilidade por
composição de tipos fechados em vez de execução de código fornecido pelo usuário.

Também é necessário separar quatro conceitos que costumam ser misturados:

1. entitlement define o que pode ser usado;
2. pricing transforma entradas comerciais tipadas em valores calculados;
3. rating determina a quantidade faturável a partir de fatos de uso;
4. invoicing materializa obrigações financeiras e seus efeitos externos.

Esta ADR fecha apenas o segundo conceito e as fronteiras necessárias com os
demais. Nenhuma aprovação de pricing autoriza chamada ao ASAAS, geração de invoice,
medição de uso ou alteração de direito.

---

# 2. Decision Statement

## 2.1 Kernel de pricing fechado, composável e puro

O núcleo canônico é uma função determinística conceitual:

```text
evaluate(PriceVersion, PricingInput) -> PricingResult
```

Todos os dados que influenciam o cálculo fazem parte da versão ou da entrada
explícita. O evaluator não consulta relógio implícito, locale, configuração viva,
catálogo `latest`, banco, cache, tenant settings, entitlement, provider, webhook,
rede ou variável de ambiente durante o cálculo.

Uma `PriceVersion` compõe componentes tipados de uma allowlist fechada. Cada
componente possui identidade estável dentro da versão, tipo, dimensão, parâmetros,
ordem/dependências permitidas e política numérica explicitamente versionada.
Componentes base produzem linhas; constraints aplicam-se somente ao subtotal
nomeado. Dependências formam um grafo acíclico e são validadas antes da publicação.

Composição significa combinar tipos conhecidos, não criar linguagem programável.
O evaluator rejeita tipo, campo, dimensão, referência, escala ou combinação fora
do schema da versão.

## 2.2 Moeda e arquitetura currency-ready

Todo valor monetário, inclusive rate, mínimo, máximo, compromisso, linha,
subtotal e total, carrega código ISO 4217 explícito. Ausência de moeda, moeda
inferida por locale ou default silencioso é inválida.

No primeiro slice:

- `BRL` é a única moeda com capabilities `PUBLISHABLE` e `BILLABLE` e a única que
  pode constar em `PriceVersion` publicada, contrato ativável, simulação comercial
  vinculante ou invoice faturável;
- outra moeda ISO pode ser representada somente em artefato de draft para permitir
  evolução do schema, mas falha no gate de publicação e ativação;
- componentes de moedas distintas nunca são somados, comparados ou compensados;
- não existe conversão implícita, taxa cambial default ou arredondamento derivado
  de locale;
- currency code, minor-unit exponent e versão da política monetária ficam pinados
  no artefato calculado.

A arquitetura permanece currency-ready por tornar moeda parte do tipo e do hash,
não por executar multimoeda agora. FX, fonte de taxa, instante de conversão, moeda
funcional, moeda de apresentação, ganho/perda cambial e liquidação multimoeda
dependem de decisão posterior e não podem ser simulados como se estivessem aceitos.

## 2.3 Lifecycle e imutabilidade de `PriceVersion`

O lifecycle conceitual usa estados fechados:

- `DRAFT`: editável no catálogo seller-owned e nunca contratável/faturável;
- `PUBLISHED`: conteúdo imutável, endereçável por identidade, número de versão e
  hash canônico;
- `RETIRED`: indisponível para novas contratações, mas ainda resolvível para
  contratos existentes e reprodutibilidade histórica.

Enquanto `DRAFT`, evolução usa optimistic concurrency para não perder edição
concorrente. Publicar cria um artefato imutável. Correção material exige nova
versão; não existe edição in-place, substituição de conteúdo mantendo versão/hash,
nem mutação de uma versão por sync de provider. Retirar uma versão não recalcula
contratos já pinados.

A versão inclui, no mínimo, identidade da oferta/item, moeda, cadence, charge
timing, componentes, schemas de dimensão/entrada, política numérica, versões dos
evaluators aceitos e hash determinístico. Campos finais de persistência e API
permanecem para os planos após a autorização de implementação.

Intervalos de vigência incompatíveis para a mesma chave de seleção são rejeitados
antes da publicação. Vigência não resolve colisão por ordem de inserção, `latest`
ou prioridade implícita.

## 2.4 Cadências publicáveis e charge timing

As únicas cadências publicáveis e faturáveis inicialmente são:

- `MONTHLY`: período recorrente mensal;
- `ANNUAL`: período recorrente anual;
- `ONE_TIME`: ocorrência única explicitamente vinculada ao contrato.

Uma cadência customizada pode existir como representação tipada de draft, mas não
pode ser publicada, contratada, ativada, simulada como vinculante ou faturada fora
das âncoras, calendário, timezone, boundaries, proration e lifecycle do ADR-0044.
Não se codifica custom cadence em string livre ou cron expression.

O momento da cobrança é tipado como:

- `IN_ADVANCE`: componente conhecido cobrado no início da boundary aplicável;
- `IN_ARREARS`: componente calculado após o encerramento de uma janela com entradas
  autoritativas já consolidadas;
- `HYBRID`: versão composta por componentes explicitamente separados entre
  `IN_ADVANCE` e `IN_ARREARS`, cada qual com subtotal e lineage próprios.

`HYBRID` não permite uma linha ambígua parcialmente cobrada duas vezes. Ele exige
componentes separados e explicitamente classificados como `IN_ADVANCE` ou
`IN_ARREARS`. O contrato
e o breakdown distinguem as parcelas. Ativação temporal, catch-up, proration e
calendário seguem o ADR-0044; quantidade de uso e fechamento em arrears seguem o
ADR-0045.

## 2.5 Allowlist de modelos

A allowlist inicial é fechada. Os nomes separados por barra na aprovação são
códigos distintos, nunca uma opção dinâmica ou expressão textual.

| Código canônico | Categoria | Semântica determinística |
| --- | --- | --- |
| `FIXED` | Base | Valor fixo independente de quantidade, aplicado uma vez na boundary explícita. |
| `PER_SEAT` | Base | Quantidade não negativa de assentos multiplicada por rate exato. |
| `PER_UNIT` | Base | Quantidade não negativa de uma dimensão allowlisted multiplicada por rate exato. |
| `PACKAGE_BLOCK` | Base | Preço por pacote/bloco com tamanho e regra de arredondamento da quantidade de blocos explicitamente pinados; excedente não é inferido. |
| `STAIRSTEP` | Base tiered | Um único valor de degrau é selecionado pela quantidade total. |
| `VOLUME_TIER` | Base tiered | A faixa da quantidade total seleciona um rate aplicado à quantidade inteira. |
| `GRADUATED_TIER` | Base tiered | Cada faixa cobra somente a parcela da quantidade contida em seu intervalo. |
| `ALLOWANCE_OVERAGE` | Base condicionado | Deduz allowance explícita e calcula somente a quantidade positiva excedente pelo rate pinado. |
| `MIN_MAX` | Constraint | Aplica piso e/ou teto no stage explicitamente publicado do componente ou subtotal alvo; não representa budget, desconto ou alçada. |
| `MINIMUM_COMMITMENT` | Constraint contratual | Calcula compromisso mínimo contratual comparável ao valor elegível, sem inferir consumo, true-up ou crédito. |
| `SETUP_ONE_TIME` | Base one-time | Componente único de setup/cobrança única, com vigência e idempotência governadas pelo lifecycle futuro. |
| `PREPAID_CREDIT_CALCULATION_ONLY` | Cálculo isolado | Calcula somente o preço de aquisição de crédito pré-pago, sem criar, consultar ou movimentar ledger, saldo, reserva, expiração ou top-up. |

`PACKAGE_BLOCK`, `MIN_MAX` e `SETUP_ONE_TIME` são discriminadores canônicos únicos.
Suas diferenças internas são parâmetros fechados e validados pelo schema da
versão, nunca subclasses, strings ou expressões selecionadas pelo usuário.

Nenhum modelo possui comportamento implícito fora da tabela. Por exemplo,
`PACKAGE_BLOCK` não cobra excedente automaticamente, `PER_SEAT` exige quantidade
inteira elegível e não descobre usuários,
`MINIMUM_COMMITMENT` não executa reconciliação/true-up e
`PREPAID_CREDIT_CALCULATION_ONLY` não altera saldo.

Modelos que dependem de uso observado podem ser definidos e exercitados com
entrada controlada em simulação pura. Sua ativação faturável permanece bloqueada
até materializar e qualificar metering, deduplicação, correção, janela, late
arrival, rating, quota/reserva e autoridade da quantidade do ADR-0045.

## 2.6 Dimensões e schema de entrada

Cada componente referencia uma dimensão por código estável pertencente a um
`PricingDimensionSchemaVersion`. O schema define tipo, unidade, precisão, escala,
cardinalidade, limites e obrigatoriedade. Não são aceitos nome livre, JSONPath,
reflection, coluna SQL, expressão, header ou claim como dimensão executável.

O catálogo pode evoluir a allowlist por nova versão de schema, sem alterar
`PriceVersion` publicada. Cada versão declara somente as dimensões efetivamente
usadas e rejeita entradas extras desconhecidas, ausência de campo obrigatório,
unidade incompatível, quantidade negativa, precisão excessiva ou valor fora dos
limites bounded.

Assentos, unidades contratuais e quantidades de simulação são entradas, nunca
buscas escondidas no evaluator. Transformar evento bruto em quantidade faturável
pertence ao ADR-0045, mesmo quando o resultado utiliza um modelo já permitido aqui.

## 2.7 Semântica fechada de tiers

Tiers usam intervalos ordenados, contínuos e sem sobreposição. Cada boundary
declara valor, unidade e inclusividade/exclusividade; a combinação pertence ao
schema e ao evaluator versionados, nunca à convenção do runtime. A última faixa
declara upper bound ilimitado explicitamente quando aplicável; `null`, ausência ou
sentinela numérica não significam ilimitado.

Uma versão tiered é inválida quando:

- começa acima da origem declarada sem política explícita;
- contém gap, overlap, ordem regressiva ou boundary duplicada;
- mistura unidade ou escala entre faixas;
- omite rate/amount exigido pelo modelo;
- combina mais de uma semântica tiered no mesmo componente;
- depende de regra externa ou de `latest` para resolver um limite.

A semântica de boundary e continuidade é parte da versão do evaluator. Alterá-la
exige nova versão de policy e nova `PriceVersion`; não se muda interpretação de
dado histórico.

## 2.8 Exatidão monetária e arredondamento

Totais monetários persistíveis e retornados pelo boundary são representados em
minor units inteiras da moeda, com overflow detectado. Quantidades, rates e
intermediários usam decimal exato com precisão e escala declaradas. `float`,
`double`, binary floating point, conversão via string localizada e truncamento
silencioso são proibidos em domínio, contrato, persistência e transporte.

Cada `PriceVersion` pina uma `RoundingPolicyVersion`. A policy define uma sequência
fechada e auditável entre os stages permitidos:

1. validação/normalização da escala de entrada;
2. cálculo exato por tier;
3. agregação exata por componente;
4. conversão monetária por componente ou subtotal, conforme policy explícita;
5. aplicação de `MIN_MAX` ou `MINIMUM_COMMITMENT` ao stage/subtotal alvo;
6. alocação determinística de residual, quando aplicável;
7. totalização em minor units com aritmética verificada.

Modo, escala, stage e regra de residual são explícitos e versionados. Não há
rounding escondido a cada multiplicação, dependente de banco/linguagem, nem ajuste
manual para forçar reconciliação. A taxonomia promocional foi aceita no ADR-0039,
e eligibility/coupon security no ADR-0040, mas decisão `ELIGIBLE` cria somente um
candidato e não um stage de pricing. O ADR-0041 fecha o waterfall promocional
como função pura posterior sobre `PricingResult` pinado, sem mutar `PriceVersion`.
Capacidade/redemption e governança promocional seguem, respectivamente, os
ADRs-0042 e 0043. Imposto/fiscal e subledger/analytics seguem os ADRs-0048 e
0049; nenhum desses eixos é inferido pelo kernel de pricing.

## 2.9 Pin contratual e preço negociado

Cada item de contrato tenant-local referencia identidade, versão e hash exatos da
`PriceVersion` aceita e materializa o snapshot necessário à reprodução. Resolver
`latest`, preço padrão vivo, default do plano, setting do tenant ou preço atual do
provider durante simulação, fechamento ou reemissão é proibido.

Preço negociado somente existe como `PriceVersion` contratual seller-owned,
aprovada, auditável e imutável. Ele pode ter audience/eligibility comercial
restrita, mas não é um
override numérico livre no banco do tenant, um campo editável da subscription ou
uma alteração direta de invoice.

Nova versão do catálogo não repricinga contratos existentes. Adoção exige evento
contratual e nova revisão/snapshot conforme ADR-0032 e a política temporal de
ADR-0044. Desconto, cortesia e promoção não são disfarçados como preço negociado;
seguem a taxonomia do ADR-0039 e a eligibility versionada do ADR-0040; combinação,
compatibilidade explícita com preço negociado e waterfall seguem o ADR-0041;
reserva/consumo e lifecycle seguem os ADRs-0042 e 0043.

## 2.10 Simulação pura, explicável e reprodutível

A mesma `PriceVersion` e o mesmo `PricingInput` canônico produzem o mesmo
`PricingResult`, independentemente de nó, horário, locale, banco, cache ou provider.
Qualquer instante, boundary ou quantidade relevante deve chegar explicitamente na
entrada e participar do hash.

O resultado de simulação contém conceitualmente:

- identidade, versão e hash da `PriceVersion`;
- versões de schema, evaluator e rounding policy;
- moeda, cadence e charge timing;
- entrada normalizada e seu hash, sem PII;
- breakdown estável por componente, tier, quantidade, rate e minor units;
- subtotais nomeados, constraints e total;
- regras/componentes aplicados e rejeitados, com reason codes fechados;
- warnings sobre modelo representável mas ainda não ativável;
- hash determinístico do resultado canônico.

Simulação não persiste contrato, uso, ledger, invoice ou cobrança; não reserva
quota, não concede entitlement, não publica evento e não chama ASAAS. Preview de
promoção, proration, imposto, FX ou provider só pode aparecer depois de suas
políticas serem aprovadas e fornecidas como entradas tipadas do pipeline futuro.

Hash serve para reprodução e detecção de drift; não substitui assinatura,
autorização, auditoria ou aprovação maker-checker.

## 2.11 Separação de pricing, entitlement, rating e provider

Os boundaries permanecem independentes:

- entitlement pode conceder capacidade sem definir preço;
- uma `PriceVersion` não concede direito nem altera projection de entitlement;
- pricing aceita quantidade explícita, mas não decide qual uso é billable;
- rating produz quantidade classificada conforme o ADR-0045;
- invoice consome resultado pinado e evidência, sem recalcular por catálogo vivo;
- provider recebe comando financeiro apenas depois do commit local e nunca calcula
  o preço autoritativo do Hub;
- status, invoice ou subscription do ASAAS não vira `PriceVersion`, entitlement
  ou quantidade de rating.

Os tipos e boundaries promocionais seguem o ADR-0039, e eligibility/coupon
security segue o ADR-0040 sem alterar `PriceVersion` ou produzir cálculo.
Stacking/exclusividade, waterfall, best price, caps stateless e alocação seguem o
ADR-0041 como stage puro posterior, preservando o `PricingResult` de entrada.
Budget/concorrência e governança promocional seguem os ADRs-0042/0043. Lifecycle
contratual e proration seguem o ADR-0044; metering, rating e overage autoritativo,
o ADR-0045; cobrança e pagamento efetivo, os ADRs-0023/0024; dunning, o ADR-0025;
correção comercial, o ADR-0046; ledger/refund, o ADR-0047; fiscal, o ADR-0048;
subledger gerencial/MRR, o ADR-0049; autorização financeira, o ADR-0050; e
SLO/rollout, o ADR-0051. Capabilities diferidas e evidências externas permanecem
fail-closed conforme cada sucessor.

## 2.12 Boundary da aprovação

Esta decisão foi aceita como `D-04.3 — Opção A`. Ela fecha conceitualmente o
kernel de pricing, moeda inicial, cadências publicáveis, timing, modelos,
versionamento, pin contratual, aritmética e simulação.

A aprovação desta ADR, isoladamente, não removeu o freeze então vigente. O
baseline decisório complementar foi fechado posteriormente por ADRs canônicos:

- `D-04.4-D` foi aprovado diretamente pelo humano no ADR-0042;
- `D-04.4-E` a `D-14` foram decididos por IA sob
  `AUTH-BILLING-2026-08-25-001`, com revisão humana `NOT_PERFORMED` e
  `Reviewability: OPEN`, nos ADR-0043 a ADR-0051 e nas revisões vigentes dos
  ADR-0023 a ADR-0025;
- a autorização humana posterior registrou `D-00 = RELEASED_WITH_SCOPE —
  HUMAN_EXPLICIT — TP-00013 local-only`, permitindo backend, frontend, DDL,
  migrations e testes herméticos locais dos planos TP-00013.

Continuam pendentes os artefatos ainda não implementados e as evidências externas,
entre elas merchant/capabilities/tarifas ASAAS, PCI, Sandbox, dados e pareceres
legais/fiscais/contábeis, medições de SLO/backup e aceite de piloto. Fechamento
documental ou código local não satisfaz esses gates.

Não foram aprovados valores comerciais, provisionamento, uso de dado real ou
chamada ASAAS. Código, packages, DTOs, DDL, migrations, endpoints, OpenAPI, UI,
eventos e jobs dormentes podem ser criados somente pelos planos locais autorizados.

---

# 3. Decision Drivers

- suportar contratos SaaS enterprise sem linguagem de execução arbitrária;
- reproduzir cálculo histórico para fechamento, correção, disputa e auditoria;
- eliminar diferenças por float, locale, ordem de avaliação ou arredondamento oculto;
- permitir preço fixo, assentos, unidades, pacotes, blocos, tiers e compromissos;
- separar preço de entitlement, rating, invoice, imposto e provider;
- manter contratos pinned e impedir repricing por catálogo vivo;
- preparar multimoeda sem assumir FX e complexidade contábil prematuramente;
- fornecer simulação explicável antes de qualquer efeito financeiro;
- limitar custo e superfície de segurança do primeiro release;
- preservar o modular monolith e a arquitetura limpa definidos pelo ADR-0037.

---

# 4. Considered Options

## Option A: Álgebra tipada, composável, determinística e versionada

Description: Adotar allowlist fechada de modelos, moeda e cadência explícitas,
aritmética exata, `PriceVersion` imutável, contrato pinned e evaluator puro, deixando
políticas independentes para decisões próprias.

Pros:

- cobre modelos enterprise por composição sem executar código não confiável;
- mantém cálculo reprodutível e auditável;
- permite evolução por novos tipos/schema versions;
- reduz dependência de provider e risco de vendor lock-in;
- prepara currency sem assumir FX agora;
- evita remodelar todo o domínio ao adicionar novos modelos aprovados.

Cons:

- exige schema registry, validações e testes de propriedades mais rigorosos;
- aumenta o número de tipos e reason codes em relação a um preço fixo simples;
- exige governança formal para publicar novas versões e modelos.

## Option B: Somente preço fixo mensal em BRL

Description: Representar cada oferta por um único valor mensal.

Pros:

- menor esforço inicial;
- cálculo e interface mais simples.

Cons:

- não cobre anual, one-time, seat, unit, package, tier ou commitment;
- força overrides e exceções fora do modelo;
- exigiria remodelagem de catálogo, contrato e invoice para clientes enterprise;
- incentiva o provider a assumir regra comercial.

Disposition: Rejected.

## Option C: DSL/fórmula arbitrária e multimoeda completa no primeiro slice

Description: Permitir scripts ou expressões de usuário, custom cadence, FX e
liquidação multimoeda desde o início.

Pros:

- máxima liberdade sintática imediata;
- novos cálculos poderiam ser cadastrados sem novo tipo de domínio.

Cons:

- amplia risco de execução, injection, exfiltração, denial of service e não
  determinismo;
- dificulta análise estática, auditoria, migração, suporte e explicação de invoice;
- combina pricing, calendário, FX, imposto e contabilidade prematuramente;
- eleva significativamente custo e prazo antes da primeira produção.

Disposition: Rejected.

---

# 5. Decision Outcome

A **Option A** foi aceita.

Flexibilidade será obtida por composição explícita de componentes versionados, não
por texto executável. BRL, três cadências publicáveis e a allowlist inicial formam
o primeiro envelope operacional; extensões exigem novas versões e decisões sem
alterar o significado de contratos já aceitos.

---

# 6. Consequences

## Positive Consequences

- Cálculos podem ser reproduzidos por versão/hash e entrada canônica.
- Contratos não sofrem repricing silencioso.
- Modelos enterprise cabem em uma álgebra bounded e testável.
- Provider não vira autoridade comercial.
- Erros de ponto flutuante e locale são excluídos do boundary.
- Simulação fornece breakdown e reason codes antes de qualquer commit.
- O schema pode evoluir para novas moedas sem misturar FX agora.

## Negative Consequences

- Publicação requer validação estrutural, numérica e semântica extensa.
- Cada novo modelo exige versão de schema/evaluator e suíte de propriedades.
- Contratos negociados geram mais `PriceVersion`, não simples override.
- Modelos dependentes de uso permanecem inativos até a implementação e a
  qualificação dos gates do ADR-0045.

## Neutral Consequences

- BRL é limitação operacional inicial, não pressuposto implícito do domínio.
- Custom cadence é representável em draft, mas não publicável.
- Pré-pago nesta decisão é cálculo, não stored value ou ledger.
- Nomes de tipos aprovam semântica, não classes, enums, tabelas ou endpoints.
- `D-00` libera implementação hermética local dos planos TP-00013, sem liberar
  capability, integração externa, piloto ou produção.

---

# 7. Impact

## Compatibility with prior decisions

| Decisão | Efeito desta ADR |
| --- | --- |
| ADR-0010 | Substitui valores/defaults/overrides implícitos por `PriceVersion` tipada e pinned; não altera a autoridade de entitlements. |
| ADR-0019 | Mantém contrato e fatos financeiros no banco dedicado do tenant. |
| ADR-0023 | Mantém preço autoritativo local e provider-neutral; ASAAS não calcula catálogo nem simulação. |
| ADR-0027 | Usa catálogo seller-owned para versões globais e snapshot tenant-local para reprodução. |
| ADR-0028 | Separa preço de entitlement e impede que catálogo vivo altere contrato materializado. |
| ADR-0029 | Mantém promoção de entitlement distinta de desconto/promocional monetário. |
| ADR-0030 | Reutiliza princípios de álgebra fechada/determinismo sem misturar composição de grants com cálculo de preço. |
| ADR-0032 | Contrato pinned adota nova `PriceVersion` somente por nova revisão válida. |
| ADR-0037 | Pricing permanece slice interno de `contexts.billing`, sem novo módulo ou provider no domínio. |
| ADR-0039 | Benefícios promocionais são tipados fora de `PriceVersion`; qualquer stage futuro depende dos gates restantes, e grants/créditos permanecem autoridades separadas. |
| ADR-0040 | Eligibility tri-state produz apenas candidato versionado; cupom não carrega rate/benefício e nenhum dos dois altera `PriceVersion` ou executa stage monetário. |
| ADR-0041 | Combina um `PricingResult` pinado por policy pura/imutável, preserva a `PriceVersion`, exige compatibilidade explícita com preço negociado e mantém best price em BRL pre-tax/pre-credit/pre-provider. |

## Impact by area

- Backend: slices S1–S6 já contêm domínio/evaluator puros para `FIXED`,
  `PER_SEAT`, `PER_UNIT` decimal, `PACKAGE_BLOCK` e `STAIRSTEP` em BRL antecipado,
  com schemas, policies e protocolos versionados; modelos adicionais seguem
  incrementais.
- Database: futuras versões globais e snapshots/referências tenant-local, sem DDL aprovado aqui.
- Frontend: futura edição/preview tipados, sem cálculo autoritativo no browser.
- Security: nenhuma DSL; inputs bounded; sem PII, segredo ou provider payload.
- Finance: valores reproduzíveis e breakdown auditável, sem ainda fechar invoice/tax.
- Operations: nenhuma dependência nova de serviço, banco ou provider nesta decisão.
- Migration: preços legados precisarão de versão/hash explícitos antes de virarem autoridade.

---

# 8. AI Agent Considerations

Agentes que detalharem ou implementarem esta decisão devem:

1. não criar DSL, SpEL, JavaScript, SQL, template executável ou fórmula arbitrária;
2. não usar `float`/`double` para dinheiro, rate, quantidade ou intermediário;
3. manter moeda explícita e rejeitar publicação não BRL no primeiro slice;
4. não ativar custom cadence fora das policies aceitas no ADR-0044;
5. não tratar quantidade fornecida à simulação como rating autoritativo;
6. não criar ledger/saldo/top-up a partir do modelo pré-pago de cálculo;
7. aplicar a taxonomia do ADR-0039, eligibility/coupon security do ADR-0040 e o
   promotion stage puro/determinístico do ADR-0041, a capacidade do ADR-0042 e o
   lifecycle do ADR-0043, sem embutir benefício, policy ou código em
   `PriceVersion`;
8. manter `PriceVersion` publicada imutável e contratos pinned por versão/hash;
9. não resolver `latest`, defaults vivos, settings de tenant ou preço de provider;
10. produzir breakdown, reason codes e hash determinísticos;
11. manter evaluator puro, sem I/O, relógio implícito, locale ou estado global;
12. separar pricing de entitlement, rating, invoice, tax e provider;
13. marcar símbolos e stores ainda inexistentes como destinos planejados;
14. aplicar `D-00` somente como liberação humana local-only dos planos TP-00013,
    nunca como autorização externa ou operacional;
15. criar testes de unidade, propriedades, contrato, precisão, overflow, tiers,
    determinismo, segurança e isolamento em cada slice implementado.

---

# 9. Implementation Plan Boundary

Esta seção registra a ordem incremental dos planos; itens S1–S6 já concluídos não
implicam conclusão dos itens seguintes:

1. inventariar preço legado e consumidores sem promover nenhum valor a autoridade;
2. congelar contratos de domínio, códigos, schema e reason codes;
3. implementar value objects exatos de moeda, quantity e rate;
4. implementar lifecycle/hash imutável de `PriceVersion`;
5. implementar validators de currency, cadence, dimensions, DAG e tiers;
6. implementar componentes base, tiered e constraints em incrementos pequenos;
7. implementar rounding policies e canonicalização/hash;
8. implementar evaluator e simulation result puros;
9. persistir catálogo global e pin/snapshot tenant-local após DDL aprovado;
10. publicar OpenAPI/UI somente após contratos e autorização definidos;
11. integrar lifecycle, rating, promoções, fiscal e invoice exclusivamente pelos
    contracts dos ADRs canônicos aceitos e após os respectivos gates executáveis;
12. validar propriedades, determinismo cross-runtime e reconciliação antes do rollout.

Os itens podem avançar hermeticamente sob `D-00`; cada gate técnico aplicável
continua obrigatório. Nenhum passo usa produção, dado real, segredo, rede externa,
Sandbox ASAAS ou piloto BP Farias para validar o cálculo.

---

# 10. Validation

## 10.1 Gates documentais desta decisão

- `ADR-0038` está indexada individualmente no README imediato.
- A allowlist não contém extensão por string, script ou fórmula.
- BRL e as três cadências publicáveis estão explícitas.
- Modelos de uso e pré-pago preservam os gates do ADR-0045 e do ADR-0047.
- `PriceVersion`, pin contratual, aritmética e simulação têm invariantes verificáveis.
- `D-04.4-A` a `D-14` possuem decisões canônicas aceitas; a origem humana de
  `D-04.4-D` e a origem `AI_DELEGATED` de `D-04.4-E` a `D-14` permanecem
  distinguíveis. `D-00` está `RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013
  local-only`; evidências externas e readiness continuam explicitamente não atestadas.
- Esta aprovação não cria provider nem efeito externo; os slices S1–S6 foram
  materializados separadamente sob o implementation plan autorizado.

## 10.2 Gates futuros de implementação

- unit tests cobrem cada modelo, zero, boundaries, valores altos e combinações válidas;
- property tests cobrem determinismo, monotonicidade aplicável, partição de tiers e invariantes de min/max;
- testes de precisão provam ausência de binary floating point, overflow silencioso e rounding oculto;
- golden tests provam canonicalização e hashes estáveis entre versões compatíveis;
- mutation/negative tests rejeitam DSL, tipo desconhecido, ciclo, gap/overlap, escala, moeda e cadence inválidos;
- contract tests provam breakdown, applied/rejected rules, reason codes e versions;
- testes de imutabilidade provam que publicação e retirement não alteram conteúdo histórico;
- testes tenant provam pin exato sem `latest`, default vivo ou cross-tenant lookup;
- architecture tests mantêm evaluator sem I/O/framework/provider e frontend sem cálculo autoritativo;
- testes de provider provam que simulação não chama ASAAS;
- modelos dependentes de usage permanecem disabled até implementação e gates de
  qualificação do ADR-0045.

Os slices S1–S6 possuem testes focais e arquiteturais locais registrados no
[`IP-BE-13.1.1-billing-catalog-pricing-promotions`](../specs/IP-BE-13.1.1-billing-catalog-pricing-promotions.md);
gates de modelos ainda não implementados permanecem futuros.

---

# 11. Risks and Mitigations

| Risco | Mitigação obrigatória |
| --- | --- |
| Álgebra tipada virar DSL disfarçada | Allowlist fechada, schemas bounded, DAG acíclico e nenhuma expressão executável. |
| Diferença de centavos | Decimal exato, minor units, rounding policy versionada e golden/property tests. |
| Off-by-one em tiers | Inclusividade explícita/versionada, continuidade e validação de gaps/overlaps. |
| Repricing silencioso | Contrato fixa identidade/versão/hash e nunca resolve `latest`. |
| Override negociado sem governança | Nova `PriceVersion` aprovada e imutável; sem campo livre tenant-local. |
| Multimoeda parcial parecer suportada | Gate de publicação/faturamento aceita somente BRL; FX explicitamente ausente. |
| Usage simulado virar autoridade | Input de simulação é explícito e sem efeitos; rating segue a autoridade separada do ADR-0045. |
| Pré-pago criar dívida/saldo incorreto | Modelo limita-se a cálculo; ledger, reserva, expiry e top-up ficam fora. |
| Promoção ser embutida como rate especial opaco | ADR-0039 exige benefício tipado e lineage separada; negotiated pricing exige versão própria. |
| `HYBRID` duplicar cobrança | Componentes advance/arrears e subtotais separados, com IDs idempotentes governados pelos ADRs-0044/0045. |
| Resultado depender de runtime | Entrada canônica, versões pinadas, pureza e hashes/golden tests. |
| Liberação local ser confundida com rollout | `D-00` permanece explícito como `RELEASED_WITH_SCOPE`; chamadas externas, Sandbox ASAAS, piloto BP Farias, produção, flags `ON` e efeitos reais continuam bloqueados. |

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
- [ADR-0039 - Taxonomia tipada de benefícios promocionais](ADR-0039-taxonomia-beneficios-promocionais.md)
- [ADR-0040 - Elegibilidade promocional e segurança de cupons](ADR-0040-elegibilidade-promocional-seguranca-cupons.md)
- [ADR-0041 - Stacking e waterfall promocional determinísticos](ADR-0041-stacking-waterfall-promocional-deterministico.md)
- [ADR-0042 - Capacidade e redemption promocional](ADR-0042-capacidade-redemption-promocional-concorrente.md)
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

- `docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`
- `docs/product/use-cases/UC-00038-billing-catalog-pricing-promotions.md`
- `docs/product/use-cases/UC-00039-billing-contract-subscription-amendments.md`
- `docs/product/use-cases/UC-00040-billing-usage-rating-invoice-close.md`
- `../../../docs/specs/TP-00013-enterprise-billing-implementation-task-plan.md`
- `app/src/main/java/br/com/duoset/saas_service/contexts/billing/package-info.java`
- `app/src/main/java/br/com/duoset/saas_service/contexts/billing/BillingApi.java`
- `app/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/`
- `app/src/main/resources/db/migration/billing/`

---

# 14. Decision Lifecycle

Esta ADR está `Accepted` pela aprovação explícita de `D-04.3 — Opção A`; o
ADR-0039 fechou `D-04.4-A`, ADR-0040 fechou `D-04.4-B` e ADR-0041 fechou
`D-04.4-C` sem mutar o kernel de pricing. O ADR-0042, por decisão humana explícita,
fechou capacidade/redemption; o ADR-0043 e os demais sucessores até ADR-0051
fecharam `D-04.4-E` a `D-14` por decisão `AI_DELEGATED` sob
`AUTH-BILLING-2026-08-25-001`, sem revisão humana substantiva. `D-00` está
`RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`; gates de evidência
externa, Sandbox, piloto, produção e efeitos reais continuam fail-closed.
Adicionar moeda faturável, custom cadence ativável, modelo executável, fórmula,
semântica de tier/rounding incompatível ou mutabilidade pós-publicação exige nova
versão formalmente aceita ou ADR sucessor. Adicionar componente dentro da álgebra
existente exige schema/evaluator versionados, revisão e compatibilidade histórica.

---

# 15. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.9 | 2026-08-25 | Codex (IA), sob liberação humana explícita | Atualiza referências executáveis após S6: `STAIRSTEP` usa tiers contíguos `[lower,upper)`, último unbounded, seleção exactly-one, amount flat, policy/hash próprios, evaluator V4 e conteúdo/resultado V5, preservando S1–S5. Registra `130/130` focados, `29/29` arquiteturais, `381` combinados com `1` skip preexistente e review independente `GO`; mantém uso autoritativo, persistência, provider e efeitos reais pendentes. |
| 1.8 | 2026-08-25 | Codex (IA), sob liberação humana explícita | Atualiza as referências executáveis após S5: `PACKAGE_BLOCK` usa policy de contagem/hash próprios, ceiling decimal exato, conteúdo/resultado V4, máximo end-to-end e composição com FIXED/PER_SEAT/PER_UNIT. Registra os gates locais e duas reauditorias pós-fix `GO`; mantém demais modelos, meter/rating, persistência, provider e efeitos reais pendentes. |
| 1.7 | 2026-08-25 | Codex (IA), sob liberação humana explícita | Atualiza as referências executáveis após S4: PER_UNIT decimal, schemas pinados de quantidade/rate, rounding HALF_EVEN, layouts V3, composição com FIXED/PER_SEAT e goldens literais estão materializados no kernel puro. Registra os gates locais no TP-00013 e no IP-BE-13.1.1-billing-catalog-pricing-promotions; mantém PACKAGE_BLOCK, demais modelos, meter/rating, persistência, provider e efeitos reais pendentes. |
| 1.6 | 2026-08-25 | Codex (IA), sob liberação humana explícita | Atualiza as referências executáveis após S2/S3: FIXED multi-cadência e PER_SEAT dimensional/componível estão materializados no kernel puro, com compatibilidade canônica legada e gates locais registrados no TP-00013 e no IP-BE-13.1.1-billing-catalog-pricing-promotions; mantém PER_UNIT, demais modelos, persistência, provider e efeitos reais pendentes. |
| 1.5 | 2026-08-25 | Solicitante humano, proprietário declarado / Codex (IA), materialização | Registra `D-00 = RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`, referencia o slice S1 de pricing puro já materializado e mantém chamadas externas, Sandbox ASAAS, piloto BP Farias, produção, flags `ON`, capabilities e efeitos reais bloqueados pelos gates próprios. |
| 1.4 | 2026-08-25 | Codex (IA), sob `AUTH-BILLING-2026-08-25-001` | Reconcilia o estado vigente: ADR-0042 registra `D-04.4-D` humano; ADR-0043 e sucessores fecham `D-04.4-E`–`D-14` como `AI_DELEGATED`, revisão humana `NOT_PERFORMED`/`OPEN`; mantém `D-00` ativo e separa decisões aceitas das evidências ASAAS/PCI/Sandbox/fiscais/contábeis/SLO ainda pendentes. |
| 1.3 | 2026-08-24 | Responsável pelo produto / Arquitetura | Registra ADR-0041 como decisão subsequente de `D-04.4-C`: combinação promocional recebe `PricingResult` pinado, aplica policy/ordem/caps/alocação determinísticos e best price BRL pre-tax/pre-credit sem mutar `PriceVersion`; `D-04.4-D`, `D-04.4-E` e `D-00` seguem abertos. |
| 1.2 | 2026-08-24 | Responsável pelo produto / Arquitetura | Registra ADR-0040 como decisão subsequente de `D-04.4-B`: eligibility tri-state e cupom verificado produzem somente candidato versionado, sem alterar `PriceVersion`, rate ou cálculo; promotion stage continua bloqueado por `D-04.4-C` a `D-04.4-E` e implementação por `D-00`. |
| 1.1 | 2026-08-24 | Responsável pelo produto / Arquitetura | Registra ADR-0039 como decisão subsequente de `D-04.4-A`: benefícios promocionais permanecem fora de `PriceVersion`, com outputs tipados e policies de aplicação ainda bloqueadas em `D-04.4-B` a `D-04.4-E`. |
| 1.0 | 2026-08-24 | Responsável pelo produto / Arquitetura | Aceita `D-04.3 — Opção A`; define kernel tipado/composável/determinístico/versionado, BRL inicial, cadências/timing, allowlist de modelos, semântica exata de tiers/rounding, `PriceVersion` imutável, pin contratual e simulação pura, preservando todos os gates de implementação. |

---

# 16. Repository Structure

Qualquer implementação permanece dentro de `contexts.billing`, respeitando as
camadas e adapters do ADR-0037. Os slices S1–S6 usam os packages
`domain.catalog`, `domain.pricing` e `application.*.pricing`; novos caminhos
continuam sujeitos ao implementation plan antes da edição.

---

# 17. Review Process

Mudança editorial pode incrementar versão menor. Alteração em moeda publicável,
cadence, timing, modelo, tier boundary, aritmética, rounding, lifecycle, pin ou
pureza exige revisão de Arquitetura, Billing, Produto, Financeiro e Segurança e
novo aceite explícito.

---

# 18. Notes

Esta ADR maximiza flexibilidade por tipos combináveis e evolutivos, preservando
explicabilidade e segurança. Representar uma possibilidade no schema não significa
que ela esteja ativável: custom cadence, usage rating, promotions, prepaid ledger,
tax e FX permanecem bloqueados até sua implementação e os gates de evidência dos
ADRs canônicos aplicáveis.

Tipos já materializados nos slices S1–S6 constam nas Code References. Quantidades
`PER_SEAT` e `PER_UNIT` permanecem inputs explícitos de simulação: sua origem
autoritativa, meter/rating e uso em invoice não foram implementados. No S4,
quantidade, rate e rounding possuem contratos e hashes independentes. No S5,
`PACKAGE_BLOCK` separa capacidade comprada de allowance, sela a contagem de blocos
em policy própria e preserva todos os derivados no breakdown. No S6, `STAIRSTEP`
seleciona exatamente um valor total flat por tiers contíguos e terminal unbounded,
sem monotonicidade implícita; o roteamento canônico falha fechado por
evaluator/profile. Os demais tipos,
policies, ports, stores e contratos continuam alvos incrementais; sua existência
em runtime não deve ser inferida sem código e evidência reproduzível.
