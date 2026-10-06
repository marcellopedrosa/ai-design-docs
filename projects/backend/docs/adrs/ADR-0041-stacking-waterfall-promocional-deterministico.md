---
document_id: "ADR-0041"
primary_nature: "Decisao"
objective: "Definir uma política versionada, pura, bounded e reproduzível para combinar promoções elegíveis, resolver stacking e exclusividade, ordenar o waterfall, selecionar best price e aplicar caps stateless sem antecipar budget, redemption ou efeitos financeiros."
scope: "`PromotionCombinationPolicyVersion`, candidatas `ELIGIBLE`, grupos `STACK_ALL`, `EXCLUSIVE_PRIORITY` e `EXCLUSIVE_BEST_PRICE`, prioridades, exclusividade global/por alvo, compatibilidade com preço negociado, waterfall canônico, perfis percent/fixed, best price, caps stateless, allocation, rounding, `PromotionCombinationResult`, snapshot aceito, placement platform/tenant e handoff entre eligibility, combinação e futura reserva."
non_objectives: "Implementar código, DDL, migration, endpoint, OpenAPI, tela, policy, promoção ou valor real; definir budget/counter stateful, reservation/consume/release, idempotência transacional, concorrência, lease, reconciliação ou estorno; definir lifecycle operacional, pause/retire/revoke, alçadas, segregação de funções, tax/accounting, calendário/proration, metering/rating, ledger/crédito, provider ou ASAAS."
owner: "Arquitetura / Billing / Produto / Financeiro / Segurança"
status: "Accepted"
date: "2026-08-25"
version: "1.2"
keywords: "promotion stacking, deterministic waterfall, PromotionCombinationPolicyVersion, exclusive best price, atomic promotion package, stateless caps, largest remainder, negotiated price, PromotionCombinationResult"
related_files: "docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00038-billing-catalog-pricing-promotions.md`, `docs/product/use-cases/UC-00039-billing-contract-subscription-amendments.md`, `docs/product/use-cases/UC-00040-billing-usage-rating-invoice-close.md`, `docs/delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md`, `docs/adrs/ADR-0010-tenant-plan-parametrization.md`, `docs/adrs/ADR-0019-database-per-tenant.md`, `docs/adrs/ADR-0023-agnostic-payment-provider-integration.md`, `docs/adrs/ADR-0027-catalogo-global-faturamento-local.md`, `docs/adrs/ADR-0029-taxonomia-tipificada-entitlements.md`, `docs/adrs/ADR-0030-composicao-deterministica-enforcement-entitlements.md`, `docs/adrs/ADR-0037-boundary-fisico-entitlements-billing.md`, `docs/adrs/ADR-0038-pricing-tipado-moeda-cadencia.md`, `docs/adrs/ADR-0039-taxonomia-beneficios-promocionais.md`, `docs/adrs/ADR-0040-elegibilidade-promocional-seguranca-cupons.md"
code_references: "AS-IS em `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/package-info.java`, `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/BillingApi.java` e `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/`; policy, combiner, snapshots, ports, stores e contratos desta ADR são destinos planejados e ainda não existem."
principal_statement: "Somente candidatas `ELIGIBLE` são combinadas por uma `PromotionCombinationPolicyVersion` seller-owned, publicada e imutável. Cada `PromotionVersion` é selecionada ou rejeitada como pacote atômico por grupos e ordem fechados; o waterfall usa aritmética e rounding versionados, caps exclusivamente stateless e produz resultado auditável com hash, sem I/O, relógio, provider ou autoridade de redemption."
---

# ADR-0041 - Stacking e waterfall promocional determinísticos

- Document ID: `ADR-0041`
- Primary Nature: `Decisao`
- Objective: Definir uma política versionada, pura, bounded e reproduzível para combinar promoções elegíveis, resolver stacking e exclusividade, ordenar o waterfall, selecionar best price e aplicar caps stateless sem antecipar budget, redemption ou efeitos financeiros.
- Scope: `PromotionCombinationPolicyVersion`, candidatas `ELIGIBLE`, grupos `STACK_ALL`, `EXCLUSIVE_PRIORITY` e `EXCLUSIVE_BEST_PRICE`, prioridades, exclusividade global/por alvo, compatibilidade com preço negociado, waterfall canônico, perfis percent/fixed, best price, caps stateless, allocation, rounding, `PromotionCombinationResult`, snapshot aceito, placement platform/tenant e handoff entre eligibility, combinação e futura reserva.
- Non-objectives: Implementar código, DDL, migration, endpoint, OpenAPI, tela, policy, promoção ou valor real; definir budget/counter stateful, reservation/consume/release, idempotência transacional, concorrência, lease, reconciliação ou estorno; definir lifecycle operacional, pause/retire/revoke, alçadas, segregação de funções, tax/accounting, calendário/proration, metering/rating, ledger/crédito, provider ou ASAAS.
- Keywords: promotion stacking, deterministic waterfall, PromotionCombinationPolicyVersion, exclusive best price, atomic promotion package, stateless caps, largest remainder, negotiated price, PromotionCombinationResult
- Related Files: `docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00038-billing-catalog-pricing-promotions.md`, `docs/product/use-cases/UC-00039-billing-contract-subscription-amendments.md`, `docs/product/use-cases/UC-00040-billing-usage-rating-invoice-close.md`, `docs/delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md`, `docs/adrs/ADR-0010-tenant-plan-parametrization.md`, `docs/adrs/ADR-0019-database-per-tenant.md`, `docs/adrs/ADR-0023-agnostic-payment-provider-integration.md`, `docs/adrs/ADR-0027-catalogo-global-faturamento-local.md`, `docs/adrs/ADR-0029-taxonomia-tipificada-entitlements.md`, `docs/adrs/ADR-0030-composicao-deterministica-enforcement-entitlements.md`, `docs/adrs/ADR-0037-boundary-fisico-entitlements-billing.md`, `docs/adrs/ADR-0038-pricing-tipado-moeda-cadencia.md`, `docs/adrs/ADR-0039-taxonomia-beneficios-promocionais.md`, `docs/adrs/ADR-0040-elegibilidade-promocional-seguranca-cupons.md`
- Code References: AS-IS em `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/package-info.java`, `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/BillingApi.java` e `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/`; policy, combiner, snapshots, ports, stores e contratos desta ADR são destinos planejados e ainda não existem.
- Principal Decision: Somente candidatas `ELIGIBLE` são combinadas por uma `PromotionCombinationPolicyVersion` seller-owned, publicada e imutável. Cada `PromotionVersion` é selecionada ou rejeitada como pacote atômico por grupos e ordem fechados; o waterfall usa aritmética e rounding versionados, caps exclusivamente stateless e produz resultado auditável com hash, sem I/O, relógio, provider ou autoridade de redemption.
- Date: 2026-08-25
- Status: Accepted
- Version: 1.2
- Authors / Owners: Arquitetura / Billing / Produto / Financeiro / Segurança
- Reviewers: Responsável pelo produto, com aprovação explícita de `D-04.4-C — Opção A` em 2026-08-24; Arquitetura; Financeiro; Segurança
- Stakeholders: Produto, Comercial, Financeiro, Backend, Frontend, Segurança, Controladoria, Operações e tenants contratantes
- Supersedes: N/A; especializa a combinação deixada aberta pelos ADR-0038, ADR-0039 e ADR-0040, sem alterar pricing, taxonomia de benefícios ou eligibility.
- Superseded by: N/A

---

# 1. Context

O ADR-0038 produz um `PricingResult` reproduzível; o ADR-0039 define os tipos de
benefício que uma `PromotionVersion` pode carregar; e o ADR-0040 decide quais
promoções são candidatas `ELIGIBLE`. Ainda faltava uma autoridade para responder,
sem ambiguidade, quais candidatas vencem, em que ordem seus pacotes inteiros
participam e como seus efeitos monetários são limitados e distribuídos.

Sem uma policy própria, o resultado poderia depender da ordem da requisição ou do
banco, de `if` espalhado, de um desconto escolhido pelo frontend ou de uma busca
combinatória sem custo máximo. Também seria fácil atribuir valor monetário
fictício a entitlement, misturar cap de cálculo com budget concorrente ou
recombinar catálogo vivo durante rating e fechamento.

O sistema ainda não entrou em produção e `D-00 = RELEASED_WITH_SCOPE —
HUMAN_EXPLICIT — TP-00013 local-only` permite nova implementação hermética local,
sem efeito real. Esta decisão fecha a álgebra stateless e suas fronteiras antes de
existir compatibilidade externa ou dado real a preservar.

---

# 2. Decision Statement

## 2.1 Autoridade versionada e função pura

Toda avaliação fixa exatamente uma `PromotionCombinationPolicyVersion` por
identidade, versão, schema version e hash canônico. A policy pertence à GV
Software, é effective-dated e segue o lifecycle estrutural `DRAFT`, `PUBLISHED` e
`RETIRED`:

- `DRAFT` pode ser editada, mas não decide combinação aceita;
- `PUBLISHED` é materialmente imutável e utilizável somente dentro de sua
  boundary efetiva;
- `RETIRED` deixa de ser selecionável para novos vínculos, mas permanece
  resolvível para replay de resultados e snapshots já aceitos.

Alterar grupos, prioridades, compatibilidade, ordem, perfil, cap ou allocation
cria nova versão. Não existe `latest`, fallback, default implícito ou edição
retroativa. A operação conceitual do domínio é:

```text
combine(
  pinned PricingResult,
  eligible PromotionCandidate set,
  PromotionCombinationPolicyVersion
) -> PromotionCombinationResult
```

O `PricingResult` fixa `PriceVersion`, inputs, currency, componentes, tiers,
precisão e rounding definidos no ADR-0038. Somente candidatas que o ADR-0040
tenha decidido `ELIGIBLE`, com referências e hashes íntegros, entram no combiner.
`INELIGIBLE`, `INDETERMINATE`, policy stale ou evidência incompatível não são
silenciosamente descartadas dentro desta função: são erro de boundary ou
permanecem fora do conjunto de entrada com evidência anterior explícita.

## 2.2 `PromotionVersion` como pacote atômico

Cada candidata representa uma `PromotionVersion` inteira e imutável. O combiner
seleciona ou rejeita o pacote, nunca benefícios isolados escolhidos para fabricar
uma combinação mais vantajosa. Não há cherry-picking, divisão artificial da
promoção, troca de target ou mutação de parâmetros durante a seleção.

Quando selecionada, a promoção conserva todos os seus benefícios declarados. O
efeito monetário e o `PROMOTIONAL_ENTITLEMENT_GRANT` continuam outputs separados:

- benefícios monetários percorrem o waterfall e os caps compatíveis;
- grants selecionados são registrados separadamente para materialização futura
  pela álgebra dos ADR-0029 e ADR-0030;
- grant não reduz preço por inferência e nunca recebe valor monetário fictício;
- desconto não cria entitlement, crédito, saldo, refund ou linha negativa.

Clipping previsto por cap ou piso zero não é cherry-picking: ele é uma
transformação explícita do pacote pela policy, registrada no breakdown.

## 2.3 Grupos fechados de combinação

A policy atribui cada candidata a um binding de grupo exato e usa somente estes
modos:

| Group mode | Regra normativa |
| --- | --- |
| `STACK_ALL` | Seleciona todas as candidatas estruturalmente compatíveis do grupo, em ordem canônica. |
| `EXCLUSIVE_PRIORITY` | Seleciona exatamente a candidata vencedora pela prioridade declarada e pelo desempate canônico. |
| `EXCLUSIVE_BEST_PRICE` | Seleciona exatamente a candidata cujo pacote produz o melhor resultado comercial monetário em BRL sobre a mesma base de entrada; empate usa prioridade e desempate canônico. |

Quantidade de grupos, candidatas por grupo, targets, benefícios e estágios deve
ser finita e limitada pelo schema executável antes de habilitar a capability. Não existe matriz arbitrária de
compatibilidade, script, callback, expressão executável, busca do power set ou
otimizador global. `EXCLUSIVE_BEST_PRICE` é uma comparação local ao grupo; não
procura a combinação global ótima entre todos os grupos.

Grupo composto exclusivamente por promoções sem efeito monetário deve usar
`EXCLUSIVE_PRIORITY`, nunca `EXCLUSIVE_BEST_PRICE`, porque grants não podem ser
convertidos em moeda para comparação. Grupo misto compara somente seu resultado
monetário e preserva os grants do pacote vencedor sem atribuir-lhes preço.

## 2.4 Ordem canônica, prioridades e desempate

Toda seleção e aplicação usa a seguinte chave total:

1. estágio canônico do waterfall;
2. prioridade explícita do grupo;
3. prioridade explícita da promoção;
4. identidade canônica da `PromotionVersion`;
5. versão canônica da `PromotionVersion`;
6. hash canônico da `PromotionVersion`.

O schema da policy define um único sentido para os inteiros de prioridade e o
valida na publicação; não há prioridade ausente. A primeira versão usa menor
valor inteiro como maior precedência, tanto para grupo quanto para promoção.
Identidade, versão e hash usam comparação bytewise/canônica, sem locale. Mesmos
inputs em qualquer permutação produzem a mesma sequência, selecionados,
rejeitados, breakdown e hash. Ordem de request, coleção, mapa, query, thread ou
retorno do banco nunca participa da decisão.

## 2.5 Exclusividade global, por target e conflito estrutural

Uma candidata pode declarar, por binding versionado, exclusividade:

- `GLOBAL`: seu pacote não convive com outra promoção no resultado;
- `TARGET`: impede convivência somente sobre targets monetários ou de grant que
  se sobrepõem de forma canônica;
- ausência de exclusividade adicional: aplicam-se somente as regras do grupo.

Exclusividade é resolvida por grupo, prioridade e chave canônica antes da
aplicação monetária. Targets sobrepostos que poderiam produzir conflito precisam
estar ligados a um grupo explícito capaz de resolvê-lo. Sobreposição sem binding
resolutivo, duas declarações globais incompatíveis, target desconhecido ou grafo
ambíguo tornam o input/policy estruturalmente inválido; não se escolhe um vencedor
por acaso e não se ignora uma candidata.

## 2.6 Compatibilidade com preço negociado e preço promocional

Toda `PromotionVersion` candidata declara exatamente um modo de compatibilidade
com preço negociado:

- `ALLOW_WITH_NEGOTIATED_PRICE`;
- `DENY_WITH_NEGOTIATED_PRICE`.

Ausência, valor desconhecido ou contradição com o binding impede a combinação.
Quando o `PricingResult` informa preço negociado e a candidata usa `DENY`, ela é
rejeitada com reason code tipado; quando usa `ALLOW`, continua sujeita a grupos,
ordem e caps. A policy nunca substitui ou edita o preço negociado base.

Por target, no máximo uma referência `PROMOTIONAL_PRICE` pode vencer. Ela aponta
para uma versão publicada compatível conforme os ADR-0038 e ADR-0039; não contém
amount/rate livre e não segue `latest`. Conflitos entre preços promocionais devem
ser resolvidos por grupo/exclusividade antes do waterfall, nunca por overwrite
sequencial.

## 2.7 Waterfall canônico

Após validar todo o conjunto, a combinação executa exatamente estes estágios:

1. fixa a base `PricingResult`, inclusive preço padrão ou negociado já aceito;
2. valida novamente integridade das decisões `ELIGIBLE`, bindings, versões,
   hashes, targets, moeda e compatibilidades;
3. resolve grupos, prioridades e exclusividades;
4. aplica no máximo um `PROMOTIONAL_PRICE` vencedor por target;
5. aplica `FREE_QUANTITY` e `FREE_PERIOD` às representações comerciais tipadas,
   sem inventar billability, calendário ou rating;
6. aplica `FEE_WAIVER` somente ao fee target explicitamente elegível;
7. aplica percentuais e valores fixos conforme um perfil fechado obrigatório;
8. aplica caps stateless e sua allocation determinística;
9. impõe piso zero, rounding e residual allocation do ADR-0038;
10. emite separadamente os grants dos pacotes selecionados.

O stage 5 só produz transformação/snapshot comercial conforme parâmetros já
tipados. O efeito de calendário real de `FREE_PERIOD` segue o ADR-0044; uso,
billability e valuation de `FREE_QUANTITY` seguem o ADR-0045. A combinação não
consulta uso, invoice, ledger, budget, contador ou provider.

## 2.8 Perfis fechados para percentual e valor fixo

Cada policy declara exatamente um perfil de ordem:

- `PERCENT_THEN_FIXED`: calcula o bloco percentual, depois aplica valores fixos
  ao remainder;
- `FIXED_THEN_PERCENT`: aplica valores fixos ao remainder, depois calcula o bloco
  percentual restante.

Não há perfil default. Ausência ou valor desconhecido invalida a policy/input.
Dentro do bloco percentual, a policy declara exatamente um modo:

- `ADDITIVE_CAPPED`: soma as taxas aplicáveis com decimal exato, limita pelo cap
  percentual aplicável e calcula uma única redução sobre a base do bloco;
- `SEQUENTIAL_REMAINDER`: aplica cada percentual na ordem canônica sobre o
  remainder deixado pela etapa anterior.

Valores fixos são sempre aplicados um a um na ordem canônica e limitados ao
remainder do target. Valor excedente não vira saldo, crédito, carry-forward,
refund nem desconto em target não relacionado. Percentual usa taxa decimal
explícita; `float`, `double`, locale, coerção e arredondamento intermediário não
declarado são proibidos.

## 2.9 `EXCLUSIVE_BEST_PRICE`

Cada pacote candidato do grupo é simulado isoladamente sobre o mesmo estado de
entrada anterior ao grupo. A comparação usa o resultado comercial monetário
completo em `BRL`, após o waterfall stateless aplicável ao pacote e antes de
tributo, crédito/prepaid, invoice, ledger, cobrança ou provider. Menor total
comercial vence.

Empate monetário usa, nesta ordem, prioridade da promoção, identidade, versão e
hash canônicos. Entitlement grant, conveniência percebida, funding de parceiro,
imposto estimado ou valor futuro não participa da pontuação. O resultado registra
cada alternativa comparada e seu total sanitizado, inclusive a razão de rejeição
dos perdedores, sem expor cupom, digest ou fatos privados.

## 2.10 Caps exclusivamente stateless

Esta decisão permite caps calculáveis inteiramente a partir dos inputs canônicos
da própria combinação:

- cap por benefício;
- cap por promoção;
- cap por target;
- cap por aplicação;
- cap monetário ou percentual do resultado.

Todo cap possui moeda/unidade, base, inclusão de limites, escala, estágio e scope
explícitos. Caps são aplicados na ordem canônica da policy e registrados antes e
depois. Budget de campanha, contador global, por tenant/account/código,
limite lifetime, quantidade já consumida, capacidade concorrente ou qualquer
estado mutável ficam proibidos aqui e pertencem exclusivamente ao ADR-0042.

## 2.11 Allocation e residual

Quando um cap stateless precisa ser distribuído entre targets/contribuições, a
policy declara exatamente um modo:

- `PRIORITY_WATERFALL`: aloca em ordem canônica até esgotar o cap;
- `PRO_RATA_LARGEST_REMAINDER`: calcula quotas proporcionais com decimal exato,
  trunca para a menor unidade monetária e distribui unidades residuais pelos
  maiores restos; empate usa a chave canônica da Section 2.4.

A soma alocada deve ser exatamente igual ao menor entre cap e soma elegível,
sempre em minor units da moeda. Não há overflow para target, promoção ou conta
não relacionada, crédito, carry-forward ou próxima competência. Base zero não
permite divisão; nesse caso a allocation monetária é zero e fica explicitamente
registrada.

## 2.12 Aritmética, rounding e piso zero

Aplicam-se a precisão decimal, moeda e `RoundingPolicyVersion` fixadas pelo
ADR-0038. Cálculos intermediários conservam a precisão aprovada e arredondam
somente nos boundaries declarados. Residual usa regra estável; nenhuma unidade é
criada ou perdida por soma de linhas.

Cada target e o total final ficam no intervalo de zero até sua base elegível. O
resultado nunca é negativo. Excesso de desconto é clipped com evidência, não vira
linha negativa, conta a receber reversa, crédito, refund, prepaid ou funding
settlement. O primeiro slice continua exclusivamente em `BRL`.

## 2.13 Resultado, explicabilidade e hash

`PromotionCombinationResult` registra, no mínimo:

- `PricingResult`, `PriceVersion`, combination policy, promotion policies e
  eligibility decisions por identidade, versão, schema e hash;
- conjunto de candidatas, selecionadas e rejeitadas, sempre em ordem canônica;
- reason codes tipados para incompatibilidade, exclusividade, prioridade,
  best-price, cap, clipping ou falha de boundary;
- groups, modos, prioridades, exclusividades e chave de ordenação aplicada;
- valor/base antes e depois de cada estágio, por target e contribuição;
- perfil percent/fixed, modo percentual, caps, allocation, rounding, residues e
  clipping;
- contribuições monetárias e grants selecionados em estruturas separadas;
- resultado comercial final pre-tax e pre-credit/prepaid/provider em `BRL`;
- versões do canonicalizer/evaluator e hash determinístico do resultado.

O `resultHash` cobre exclusivamente o envelope canônico puro do
`PromotionCombinationResult`: referências/hashes dos inputs versionados,
decisão, breakdown, reason codes e versões do algoritmo, mas não seller/tenant/
account do aceite, purpose, intent/quote/revision, boundary nem campos voláteis ou
de apresentação.
Mesmos inputs canônicos, inclusive qualquer permutação do conjunto de candidatas,
produzem exatamente o mesmo resultado e `resultHash`. Reason codes para
perdedores comerciais são parte do resultado; detalhes internos sensíveis
continuam redigidos.

## 2.14 Placement e snapshot aceito

O placement especializa o ADR-0027:

| Artefato | Autoridade/store | Invariante |
| --- | --- | --- |
| `PromotionCombinationPolicyVersion` e bindings publicados | Catálogo seller-owned no control plane `saas_platform` | Imutáveis, sem tenant PII, invoice, cupom/digest, segredo ou provider. |
| Preview de combinação | Efêmero | Não reserva, consome, cria direito, invoice, crédito, outbox financeiro ou autoridade reutilizável. |
| `AcceptedPromotionCombinationSnapshot` contendo o resultado aceito | Banco dedicado do tenant | Liga pricing, eligibility, promotion e combination refs/hashes ao intent/quote/contrato; contém somente evidência sanitizada. |
| Budget, counters e redemption | PostgreSQL da plataforma conforme ADR-0042 | Autoridade separada desta ADR e ainda não implementada. |

O `AcceptedPromotionCombinationSnapshot` contém o `resultHash` e acrescenta o
envelope contratual canônico exato do aceite: seller/tenant/account opacos,
purpose, intent/quote/revision, bindings, schema e metadados autoritativos do
boundary. Seu `snapshotHash` cobre esse envelope completo, sem campos meramente
visuais. Portanto, resultados combinatórios iguais produzem o mesmo `resultHash`,
mas somente snapshots com envelope e bindings canônicos exatamente iguais
produzem o mesmo `snapshotHash`; revision/boundary diferente pode manter o
`resultHash` quando os inputs puros permanecem iguais e necessariamente muda o
`snapshotHash`.

Leitura platform e persistência tenant-local são boundaries independentes. Não há
XA, FK, join cross-store, dual-write atômico ou referência `latest`. O snapshot
local não contém raw coupon, digest HMAC, referência interna de código, PII de
cliente do tenant, segredo, payload ASAAS/provider ou configuração executável.

Rating e fechamento consomem somente o snapshot de combinação já aceito e
aplicado/reservado conforme a evidência do ADR-0042. Eles não
reavaliam eligibility, reabrem registry de cupom, recombinam catálogo vivo nem
escolhem outro best price.

## 2.15 Pipeline B, C e D

No boundary de commit, a ordem normativa é:

1. `D-04.4-B`/ADR-0040 reavalia eligibility com facts atuais imediatamente antes
   do commit;
2. `D-04.4-C`/esta ADR recomputa a combinação determinística sobre o conjunto
   `ELIGIBLE` atual;
3. ADR-0042 reserva/aplica o conjunto stateful selecionado, de forma idempotente e
   concorrente.

Se a etapa D informar que uma candidata selecionada não está mais disponível por
budget/counter stateful, não pode fazer drop parcial ou silencioso. O orquestrador
pode executar nova combinação C bounded usando a lista exata e confiável de
exclusões fornecida por D e preservando toda a evidência. Número de tentativas,
reservation set, idempotência e término seguem o ADR-0042; loop infinito e
fallback permissivo são proibidos.

Esta ADR não reserva, consome, libera, expira, reconcilia, estorna ou contabiliza
redemption. A diferença entre resultado selecionado, reservado e consumido deve
permanecer explícita.

## 2.16 Clean Architecture, custo bounded e falhas

O domínio do combiner contém value objects, grupos, comparadores, waterfall,
caps, allocation e canonicalização. Ele não importa Spring, JPA, Jackson, Redis,
relógio, rede, banco, frontend, provider ou DTO externo. A camada de aplicação
resolve as versões exatas e snapshots por ports, valida tenant scope antes de
qualquer acesso e persiste o aceite; adapters isolam platform store, tenant store,
auditoria e transporte.

Bounds são validados na publicação e novamente no ingress. O custo é função
limitada de grupos, candidatas, benefícios e targets; não há busca exponencial.
Frontend somente solicita preview/comando e renderiza resultado sanitizado. Ele
não classifica candidata, resolve grupo, calcula desconto, compara best price,
aloca residual ou gera hash autoritativo.

Problema estrutural de policy/input — versão/hash ausente, target conflitante sem
grupo, perfil desconhecido, overflow, currency mismatch ou grafo ambíguo — falha
toda a avaliação, sem resultado parcial. Perdedores esperados por exclusividade,
prioridade, best price, incompatibilidade negociada ou cap são rejeições de
negócio registradas, não exceções escondidas. Ausência de autoridade nunca vira
zero/default.

## 2.17 Boundary da aprovação

Esta decisão foi aceita como `D-04.4-C — Opção A`. Ela fecha grupos, stacking,
exclusividade, prioridades, best price, waterfall, perfis percent/fixed, caps
stateless, allocation, rounding, resultado e pipeline conceitual B → C → D.

O baseline complementar está fechado: `D-04.4-D` foi aprovado diretamente pelo
humano no ADR-0042; `D-04.4-E` a `D-14` foram decididos por IA sob
`AUTH-BILLING-2026-08-25-001`, com revisão humana `NOT_PERFORMED` e
`Reviewability: OPEN`, nos ADR-0043 a ADR-0051 e revisões vigentes dos ADR-0023 a
ADR-0025. `D-00` permite implementação hermética local dos planos TP-00013 e não
autoriza chamada externa, Sandbox, piloto ou produção.

Continuam pendentes os gates executáveis e externos: policies/limites reais,
OpenAPI/DDL/UI, merchant/capabilities/tarifas ASAAS, PCI, Sandbox, dados e
pareceres legais/fiscais/contábeis, SLO/backup e aceite de piloto.

Não foram aprovados valor comercial, policy real, prioridade real, cap numérico,
campanha, código, budget, reservation, tabela, migration, package, classe,
endpoint, OpenAPI, UI, job, evento, cache, rollout, tenant ou chamada ASAAS.

---

# 3. Decision Drivers

- produzir o mesmo resultado para inputs equivalentes em qualquer ordem;
- tornar stacking e exclusividade explícitos, versionados e auditáveis;
- preservar a promoção como pacote comercial, sem cherry-picking;
- suportar best price sem atribuir preço fictício a entitlement;
- oferecer flexibilidade por perfis fechados, não por fórmula executável;
- manter custo previsível e impedir otimização combinatória exponencial;
- distinguir cap stateless de budget/contador concorrente;
- preservar aritmética, rounding, piso zero e reconciliação de minor units;
- impedir frontend, banco ou provider de decidir desconto;
- preservar catálogo global e snapshot tenant-local sem XA;
- separar reavaliação de eligibility, combinação e futura reservation.

---

# 4. Considered Options

## Option A: Policy versionada, grupos fechados e waterfall determinístico

Description: Usar policy seller-owned imutável, promoção como pacote atômico,
três modos de grupo, ordem total, perfis fechados, best price local, caps
stateless e resultado canônico explicável.

Pros:

- alta flexibilidade comercial dentro de um contrato seguro e reproduzível;
- resultado independente de request, banco, thread ou frontend;
- auditabilidade por versões, estágios, contribuições e hash;
- custo bounded sem motor de otimização global;
- separação clara entre cálculo e estado concorrente.

Cons:

- exige schemas e validação de publicação ricos;
- força escolha explícita de perfil, grupo, prioridade, cap e compatibility;
- não encontra automaticamente uma combinação global ótima;
- requer golden/property tests e disciplina de canonicalização.

## Option B: Prioridade única e desconto sequencial simples

Description: Ordenar todas as promoções por um único número e aplicar cada
benefício ao total corrente.

Pros:

- custo inicial menor;
- implementação aparente simples.

Cons:

- não representa grupos, target exclusivity ou best price corretamente;
- tende a depender de defaults e ordem acidental;
- mistura pacote, benefício e cap;
- produz pouca explicabilidade para negociação e suporte.

Disposition: Rejected.

## Option C: Rules engine ou otimizador combinatório global

Description: Permitir matriz/DSL arbitrária e buscar o menor total entre todas as
combinações possíveis.

Pros:

- expressividade sintática máxima;
- pode encontrar ótimo monetário global sob um modelo simplificado.

Cons:

- custo exponencial e risco de abuso;
- difícil replay, auditoria, segurança e explicação;
- scripts/configuração viva viram autoridade comercial;
- grants, tax, budgets e efeitos futuros tornam a função objetivo incorreta;
- amplia lock-in e superfície operacional.

Disposition: Rejected.

---

# 5. Decision Outcome

A **Option A** foi aceita.

Flexibilidade vem de grupos, prioridades, targets, perfis e caps tipados. Não vem
de ordem incidental, escolha parcial de benefícios, fórmula arbitrária ou busca
global. O resultado continua stateless e não autoriza aplicação sem a reservation
do ADR-0042 e os gates aplicáveis.

---

# 6. Consequences

## Positive Consequences

- Preview e aceite podem ser reproduzidos por versões/hashes.
- Promoções exclusivas e stackable têm semântica inequívoca.
- Best price compara dinheiro sobre a mesma base sem monetizar grant.
- Percent/fixed, caps e residues possuem ordem fechada.
- Resultado final nunca fica negativo nem cria crédito implícito.
- Rating/close podem consumir snapshot, sem recombinar catálogo vivo.
- Domínio permanece puro, provider-neutral e testável por propriedades.

## Negative Consequences

- Publicação exige validação estrutural e simulações/golden vectors.
- Toda combinação exige prioridades e perfis explícitos.
- Cap/allocation e explicabilidade aumentam o tamanho do snapshot.
- Conflito não resolvido falha toda a avaliação, exigindo correção de policy.

## Neutral Consequences

- Best price é local ao grupo, não uma promessa de ótimo global.
- Cap stateless pode reduzir contribuição sem consumir budget.
- Uma promoção selecionada ainda não está reservada nem consumida.
- Nomes aprovados são conceitos canônicos, não classes ou tabelas.
- `D-00` libera implementação hermética local, sem capability ou efeito real.

---

# 7. Impact

## Compatibility with prior decisions

| Decisão | Efeito desta ADR |
| --- | --- |
| ADR-0010 | Proíbe stacking por settings/override genérico ou prioridade viva. |
| ADR-0019 | Mantém somente o `AcceptedPromotionCombinationSnapshot`, contendo o resultado puro aceito, no banco dedicado do tenant. |
| ADR-0023 | Mantém ASAAS/provider fora de combinação e best price. |
| ADR-0027 | Posiciona policy global seller-owned e snapshot aceito tenant-local. |
| ADR-0029 | Grants selecionados continuam contribuições tipadas separadas. |
| ADR-0030 | Combinação promocional antecede a álgebra de entitlement e não neutraliza restrições. |
| ADR-0037 | Mantém o slice dentro de `contexts.billing`, sem novo módulo ou aresta. |
| ADR-0038 | Usa `PricingResult`, decimal, BRL e rounding pinned; não muta `PriceVersion`. |
| ADR-0039 | Combina somente os benefícios fechados e preserva crédito fora da taxonomia. |
| ADR-0040 | Recebe somente candidatas `ELIGIBLE` e não transforma coupon em redemption. |
| ADR-0042 | Reserva atomicamente o subconjunto stateful selecionado e fecha o handoff C → D. |
| ADR-0043 | Governa lifecycle e publicação sem alterar a combinação histórica. |

## Impact by area

- Backend: futuro combiner puro e orchestration por ports separados.
- Database: futura policy platform e snapshot tenant-local; nenhum DDL aqui.
- Frontend: futura visualização do breakdown sanitizado, sem calculator/selector.
- Security: bounds, tenant guard, canonicalização e ausência de input executável.
- Finance: waterfall pre-tax/pre-credit em BRL, sem efeito financeiro externo.
- Operations: prioridades/caps reais e alçadas seguem os ADRs-0042/0043/0050,
  mas continuam `OFF` sem artefatos e evidências de implementação.
- Provider: nenhuma capability, status ou payload ASAAS participa do resultado.

---

# 8. AI Agent Considerations

Agentes que detalharem ou implementarem esta decisão devem:

1. aceitar somente candidatas `ELIGIBLE` com refs/hashes exatos;
2. tratar `PromotionVersion` como pacote atômico selecionado/rejeitado;
3. usar somente os três grupos e a ordem total aprovada;
4. rejeitar overlap sem binding resolutivo e perfil/default ausente;
5. aplicar exatamente os dez estágios do waterfall;
6. preservar os dois perfis e os dois modos percentuais fechados;
7. comparar best price na mesma base, em BRL e sem monetizar grant;
8. permitir apenas caps stateless e os dois modos de allocation;
9. aplicar decimal/rounding/piso zero do ADR-0038;
10. produzir breakdown completo e hash independente de permutação;
11. falhar toda a avaliação em erro estrutural, sem partial success;
12. manter resultado selecionado distinto de reservado/consumido;
13. criar budget/counter/redemption somente conforme o ADR-0042;
14. manter rating/close como consumidor do snapshot aceito, sem recombinação;
15. manter domínio sem I/O/framework/provider e frontend sem autoridade;
16. criar código, DDL, OpenAPI e policy sintética somente no escopo hermético
    local de `D-00`, sem policy comercial real nem ASAAS externo;
17. implementar os testes de propriedades, segurança e isolamento desta ADR
    somente quando houver autorização.

---

# 9. Implementation Plan Boundary

Esta seção registra somente a ordem futura:

1. aplicar os ADRs-0042/0043 e gates transversais aceitos, sem inferir evidência;
2. congelar schemas, bounds, reason codes, profiles, caps e priorities;
3. criar golden vectors de selection, waterfall, caps, rounding e permutation;
4. implementar value objects/canonicalizer/combiner puro;
5. implementar lookup de versions exatas e tenant scope por ports;
6. persistir policy platform e snapshot aceito tenant-local sem XA;
7. integrar eligibility B → combination C → reservation D;
8. integrar contrato/rating somente por snapshot aceito/aplicado;
9. publicar OpenAPI/UI somente após contrato, RBAC e redaction aprovados;
10. provar determinismo, bounded cost, isolamento e zero provider antes de rollout.

Todo item pode avançar hermeticamente sob `D-00`. Testes usarão fixtures efêmeras, sem tenant, promoção,
cupom, segredo, valor financeiro ou ASAAS real.

---

# 10. Validation

## 10.1 Gates documentais desta decisão

- `ADR-0041` está indexada individualmente no README imediato.
- A policy é seller-owned, versionada, effective-dated e imutável.
- Somente candidatas `ELIGIBLE` entram na função pura.
- Promoção é pacote atômico e grants permanecem separados.
- Os três grupos, exclusividades e ordem total estão fechados.
- Perfis percent/fixed, modos percentuais e best price estão fechados.
- Apenas caps stateless e dois modos de allocation são permitidos.
- Resultado registra breakdown, reasons, refs/hashes e hash determinístico.
- Placement global/local não cria XA, FK, join ou dual-write atômico.
- O pipeline reavalia B, recombina C e futuramente reserva D.
- `D-04.4-D` a `D-14` possuem decisões canônicas aceitas, preservando origem
  humana para `D-04.4-D` e `AI_DELEGATED`, revisão humana `NOT_PERFORMED`/`OPEN`,
  para `D-04.4-E` a `D-14`; `D-00` está `RELEASED_WITH_SCOPE — HUMAN_EXPLICIT —
  TP-00013 local-only`.
- Nenhum código, DDL, API, policy real, budget ou provider é criado.

## 10.2 Gates futuros de implementação

- golden/property tests cobrem permutação de candidatas e coleções;
- tests cobrem cada group mode, prioridade, tie-break e exclusividade;
- tests rejeitam overlap ambíguo, group/profile/mode desconhecido e bounds;
- tests provam pacote atômico e ausência de cherry-picking;
- best-price tests usam a mesma base e ignoram valor fictício de grants;
- tests cobrem preço negociado allow/deny e um promotional price por target;
- tests cobrem ambos os perfis e modos percentuais com decimal exato;
- tests cobrem ambos os allocations, minor units, largest remainder e empate;
- tests provam piso zero, cap, clipping e ausência de crédito/carry-forward;
- tests verificam `resultHash` idêntico para os mesmos inputs/permutations,
  `snapshotHash` idêntico somente para envelope/bindings aceitos idênticos,
  divergência de snapshot quando revision/boundary muda e reason ordering estável;
- tests cobrem falha total estrutural e rejeições comerciais explicadas;
- architecture tests mantêm domínio sem framework/I/O/provider;
- tenant tests impedem scope mismatch e shared datasource fallback;
- pipeline tests impedem stale eligibility, silent drop e loop infinito;
- rating/close tests impedem recombinação de catálogo vivo;
- provider tests provam zero chamada ASAAS em preview/combination/acceptance.

Esses testes não foram executados porque a mudança é exclusivamente documental e
`D-00` permite implementação hermética local e proíbe efeitos fora desse escopo.

---

# 11. Risks and Mitigations

| Risco | Mitigação obrigatória |
| --- | --- |
| Resultado depender da ordem do banco | Chave total e property tests de permutação. |
| Cherry-picking alterar intenção comercial | `PromotionVersion` é pacote atômico. |
| Power-set causar explosão de custo | Três grupos bounded e best price local, sem optimizer global. |
| Grant distorcer best price | Grants nunca recebem valor monetário. |
| Dois promotional prices sobrescreverem target | Máximo de um vencedor e conflito resolvido antes do waterfall. |
| Preço negociado receber desconto indevido | Compatibility mode explícito e ausência fail-closed. |
| Percent/fixed variar por implementação | Dois perfis e dois modos percentuais fechados. |
| Cap perder/criar centavos | Minor units, largest remainder e tie-break canônico. |
| Desconto virar saldo/crédito | Piso zero e proibição de overflow/carry-forward. |
| Cap stateless virar budget | Estado mutável é exclusivo da autoridade do ADR-0042. |
| Falha estrutural gerar benefício parcial | Falha toda a avaliação; somente perdedores normais são reasoned rejection. |
| TOCTOU entre preview e commit | Pipeline reavalia B e recomputa C antes de D. |
| Rating recombinar resultado histórico | Consumir somente snapshot aceito/aplicado pinned. |
| Frontend ou ASAAS decidir combinação | Autoridade exclusiva do domínio Billing puro. |
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
- [ADR-0040 - Elegibilidade promocional e segurança de cupons](ADR-0040-elegibilidade-promocional-seguranca-cupons.md)
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
`D-04.4-C — Opção A`. Adicionar group mode, perfil, modo percentual, allocation,
função objetivo, ordem, cap stateful, formula/DSL, monetização de grant,
recombinação em rating ou mutabilidade pós-publicação exige nova versão
formalmente aceita ou ADR sucessor.

Budget/concurrency/redemption (`D-04.4-D`) foi aceita por decisão humana explícita
no ADR-0042. Lifecycle promocional e os demais eixos `D-04.4-E` a `D-14` foram
aceitos por decisão `AI_DELEGATED` sob `AUTH-BILLING-2026-08-25-001`, com revisão
humana `NOT_PERFORMED`/`OPEN`. `D-00` está `RELEASED_WITH_SCOPE — HUMAN_EXPLICIT —
TP-00013 local-only`; evidências externas e readiness continuam separadamente pendentes.

---

# 15. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.2 | 2026-08-25 | Solicitante humano, proprietário declarado / Codex (IA), materialização | Registra `D-00 = RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`; permite implementação/DDL/OpenAPI/testes herméticos locais e mantém chamadas externas, policies comerciais reais, Sandbox ASAAS, piloto BP Farias, produção, flags `ON` e efeitos reais bloqueados. |
| 1.1 | 2026-08-25 | Codex (IA), sob `AUTH-BILLING-2026-08-25-001` | Reconcilia `D-04.4-D` humano no ADR-0042 e `D-04.4-E`–`D-14` `AI_DELEGATED`, revisão humana `NOT_PERFORMED`/`OPEN`; o resultado stateless agora encaminha ao ADR-0042 e `D-00`/evidências permanecem ativos. |
| 1.0 | 2026-08-24 | Responsável pelo produto / Arquitetura / Financeiro / Segurança | Aceita `D-04.4-C — Opção A`; define policy de combinação imutável, pacote atômico, três grupos, exclusividade/prioridade, waterfall, perfis percent/fixed, best price, caps stateless, allocation/rounding, resultado/snapshot e pipeline B → C → D, mantendo estado concorrente, lifecycle e implementação bloqueados. |

---

# 16. Repository Structure

Qualquer implementação futura permanece como slice interno de
`contexts.billing`, com domínio puro e adapters platform/tenant conforme
ADR-0037. Este documento não cria package, módulo, tabela, migration track,
cache, serviço ou diretório. Nomes concretos exigem o plano TP-00013 aplicável e
permanecem dentro do escopo local-only de `D-00`.

---

# 17. Review Process

Mudança editorial pode incrementar versão menor. Alteração em grupos, atomicidade
do pacote, prioridade, exclusividade, waterfall, perfis, best price, caps,
allocation, rounding, placement, hash, failure semantics ou pipeline B → C → D
exige revisão de Arquitetura, Billing, Produto, Financeiro e Segurança e novo
aceite explícito.

---

# 18. Notes

Eligibility responde quais promoções podem concorrer; combinação responde quais
pacotes vencem e qual seria seu efeito stateless; o ADR-0042 responde se esse
conjunto pode ser reservado e consumido sob concorrência. Nenhuma etapa substitui
a outra.

Sob `D-00`, esses tipos, policies, combiners, ports, stores e contratos podem ser
materializados localmente pelos planos TP-00013. Nenhuma capability ou existência
em runtime deve ser inferida sem código e evidência reproduzível.
