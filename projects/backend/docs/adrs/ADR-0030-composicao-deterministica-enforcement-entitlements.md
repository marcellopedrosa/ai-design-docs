---
document_id: "ADR-0030"
primary_nature: "Decisao"
objective: "Definir uma álgebra tipada, determinística e auditável para compor grants e restrições de entitlement, representar resultados explícitos e separar enforcement operacional de uso, rating e cobrança."
scope: "Tipos de valor de entitlement, operadores fechados de composição, precedência entre grants e restrições, estados resultantes, semântica de `UNLIMITED`, modos de enforcement, separação de uso e conteúdo mínimo da projeção efetiva."
non_objectives: "Definir valores concretos por plano, preço de overage, agregação/rating financeiro, lifecycle de inadimplência, grandfathering, upgrade/downgrade, migração/cutover, política de cache/degraded mode, DDL, OpenAPI, nomes físicos de classes/tabelas/eventos, RBAC/alçadas finais ou autorizar implementação; o gate financeiro separado foi posteriormente definido no ADR-0025 e metering/rating no ADR-0045."
owner: "Arquitetura / Billing / Produto"
status: "Accepted"
date: "2026-08-25"
version: "2.2"
keywords: "entitlement composition, typed algebra, deterministic evaluation, hard limit, soft limit, overage allowed, unlimited, risk restriction, effective entitlement projection"
related_files: "docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00038-billing-catalog-pricing-promotions.md`, `docs/product/use-cases/UC-00039-billing-contract-subscription-amendments.md`, `docs/product/use-cases/UC-00040-billing-usage-rating-invoice-close.md`, `docs/delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md`, `docs/adrs/ADR-0010-tenant-plan-parametrization.md`, `docs/adrs/ADR-0025-suspensao-tenant-inadimplencia-recuperacao.md`, `docs/adrs/ADR-0028-entitlements-versionados-tenant-local.md`, `docs/adrs/ADR-0029-taxonomia-tipificada-entitlements.md`, `docs/adrs/ADR-0032-adocao-versionada-grandfathering-entitlements.md`, `docs/adrs/ADR-0034-efeitos-transicao-nao-destrutiva-entitlements.md`, `docs/adrs/ADR-0035-migracao-evidence-first-entitlements-legados.md`, `docs/adrs/ADR-0036-cache-lkg-fail-safe-entitlements.md`, `docs/adrs/ADR-0037-boundary-fisico-entitlements-billing.md`, `docs/adrs/ADR-0038-pricing-tipado-moeda-cadencia.md`, `docs/adrs/ADR-0039-taxonomia-beneficios-promocionais.md`, `docs/adrs/ADR-0040-elegibilidade-promocional-seguranca-cupons.md`, `docs/adrs/ADR-0041-stacking-waterfall-promocional-deterministico.md`, `docs/adrs/ADR-0042-capacidade-redemption-promocional-concorrente.md`, `docs/adrs/ADR-0043-governanca-lifecycle-promocional.md`, `docs/adrs/ADR-0045-metering-rating-fechamento-fatura.md"
code_references: "Estado legado em `BillingApiAdapter`, `TenantApiImpl`, `TenantSettings`, `Plan`, `SubscriptionPlan`, `ChatbotFlowUseCase`, `ChatbotMessageCreditDeductionListener`, `ConsultaSituacaoFiscalCreditDeductionListener` e `UsageReporterScheduler`; boundary e destinos planejados sob `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/` definidos no ADR-0037, ainda não implementados."
principal_statement: "Cada capability usa tipo e operador fechados pela versão publicada; grants válidos são agregados de forma comutativa e reproduzível, restrições de risco são aplicadas em uma segunda fase e sempre prevalecem, `UNLIMITED` é valor explícito, estados indeterminados nunca concedem implicitamente e uso observado permanece separado do entitlement e do rating financeiro. Inadimplência não entra nessa álgebra: o ADR-0025 produz `FINANCIAL_ACCESS_RESTRICTION` em eixo separado, combinado somente no admission/access boundary."
---

# ADR-0030 - Composição determinística e enforcement de entitlements

- Document ID: `ADR-0030`
- Primary Nature: `Decisao`
- Objective: Definir uma álgebra tipada, determinística e auditável para compor grants e restrições de entitlement, representar resultados explícitos e separar enforcement operacional de uso, rating e cobrança.
- Scope: Tipos de valor de entitlement, operadores fechados de composição, precedência entre grants e restrições, estados resultantes, semântica de `UNLIMITED`, modos de enforcement, separação de uso e conteúdo mínimo da projeção efetiva.
- Non-objectives: Definir valores concretos por plano, preço de overage, agregação/rating financeiro, lifecycle de inadimplência, grandfathering, upgrade/downgrade, migração/cutover, política de cache/degraded mode, DDL, OpenAPI, nomes físicos de classes/tabelas/eventos, RBAC/alçadas finais ou autorizar implementação; o gate financeiro separado foi posteriormente definido no ADR-0025 e metering/rating no ADR-0045.
- Keywords: entitlement composition, typed algebra, deterministic evaluation, hard limit, soft limit, overage allowed, unlimited, risk restriction, effective entitlement projection
- Related Files: `docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00038-billing-catalog-pricing-promotions.md`, `docs/product/use-cases/UC-00039-billing-contract-subscription-amendments.md`, `docs/product/use-cases/UC-00040-billing-usage-rating-invoice-close.md`, `docs/delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md`, `docs/adrs/ADR-0010-tenant-plan-parametrization.md`, `docs/adrs/ADR-0025-suspensao-tenant-inadimplencia-recuperacao.md`, `docs/adrs/ADR-0028-entitlements-versionados-tenant-local.md`, `docs/adrs/ADR-0029-taxonomia-tipificada-entitlements.md`, `docs/adrs/ADR-0032-adocao-versionada-grandfathering-entitlements.md`, `docs/adrs/ADR-0034-efeitos-transicao-nao-destrutiva-entitlements.md`, `docs/adrs/ADR-0035-migracao-evidence-first-entitlements-legados.md`, `docs/adrs/ADR-0036-cache-lkg-fail-safe-entitlements.md`, `docs/adrs/ADR-0037-boundary-fisico-entitlements-billing.md`, `docs/adrs/ADR-0038-pricing-tipado-moeda-cadencia.md`, `docs/adrs/ADR-0039-taxonomia-beneficios-promocionais.md`, `docs/adrs/ADR-0040-elegibilidade-promocional-seguranca-cupons.md`, `docs/adrs/ADR-0041-stacking-waterfall-promocional-deterministico.md`, `docs/adrs/ADR-0042-capacidade-redemption-promocional-concorrente.md`, `docs/adrs/ADR-0043-governanca-lifecycle-promocional.md`, `docs/adrs/ADR-0045-metering-rating-fechamento-fatura.md`
- Code References: Estado legado em `BillingApiAdapter`, `TenantApiImpl`, `TenantSettings`, `Plan`, `SubscriptionPlan`, `ChatbotFlowUseCase`, `ChatbotMessageCreditDeductionListener`, `ConsultaSituacaoFiscalCreditDeductionListener` e `UsageReporterScheduler`; boundary e destinos planejados sob `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/` definidos no ADR-0037, ainda não implementados.
- Principal Decision: Cada capability usa tipo e operador fechados pela versão publicada; grants válidos são agregados de forma comutativa e reproduzível, restrições de risco são aplicadas em uma segunda fase e sempre prevalecem, `UNLIMITED` é valor explícito, estados indeterminados nunca concedem implicitamente e uso observado permanece separado do entitlement e do rating financeiro. Inadimplência não entra nessa álgebra: o ADR-0025 produz `FINANCIAL_ACCESS_RESTRICTION` em eixo separado, combinado somente no admission/access boundary.
- Date: 2026-08-25
- Status: Accepted
- Version: 2.2
- Last Reviewed: 2026-08-25
- Authors / Owners: Arquitetura / Billing / Produto
- Reviewers: Responsável pelo produto, com aprovação explícita de `D-04.2-C — opção A` em 2026-08-23; Arquitetura
- Stakeholders: Produto, Financeiro, Backend, Frontend, Segurança, Compliance, Operações e tenants contratantes
- Supersedes: N/A; especializa os ADR-0028 e ADR-0029 e restringe semânticas conflitantes de composição/enforcement do ADR-0010.
- Superseded by: N/A

---

# 0. Provenance of later Billing reconciliations

A álgebra de `D-04.2-C` permanece uma decisão humana explícita de 2026-08-23. As
especializações desta versão para `D-09` e `D-06` derivam, respectivamente, dos
ADR-0025 e ADR-0045 e possuem proveniência `AI_DELEGATED`, ator
`AI_AGENT — Codex (OpenAI)`, autoridade
`OWNER_DELEGATION — AUTH-BILLING-2026-08-25-001`, revisão humana substantiva
`NOT_PERFORMED` e reviewability `OPEN`. Ratificação futura não apaga essa origem.

A reconciliação vigente também registra `D-04.4-D` como decisão humana explícita
do ADR-0042 e `D-04.4-E` a `D-14` como decisões aceitas sob a autoridade delegada,
sem alterar a origem humana de `D-04.2-C`. A liberação humana posterior registrou
`D-00 = RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`.

---

# 1. Context

O [ADR-0028](ADR-0028-entitlements-versionados-tenant-local.md) fixou a autoridade
contratual tenant-local e o
[ADR-0029](ADR-0029-taxonomia-tipificada-entitlements.md) tipificou as fontes de
grant, exceção e restrição. Faltava definir como entradas simultaneamente vigentes
produzem uma decisão operacional reproduzível.

Sem uma álgebra explícita, implementações diferentes poderiam escolher
`last-write-wins`, interpretar `NULL` como ilimitado, permitir que uma cortesia
neutralize contenção de segurança ou misturar consumo com direito contratado. O
resultado seria dependente da ordem de leitura, difícil de auditar e vulnerável a
concorrência e fallback permissivo.

A decisão ocorre antes da implementação. Portanto, o modelo pode ser corrigido sem
preservar uma API, tabela ou enum físico inadequado.

---

# 2. Decision Statement

## 2.1 Tipos fechados de valor

Cada capability publicada em uma `EntitlementBundleVersion` DEVE declarar
exatamente um tipo conceitual:

1. **`FLAG`** — direito booleano habilitado ou não;
2. **`QUANTITY`** — quantidade exata, com unidade, dimensões e, quando aplicável,
   janela temporal explícitas;
3. **`SET`** — conjunto allowlisted de membros permitidos;
4. **`LEVEL`** — nível pertencente a uma ordem total versionada, como
   `BASIC < ADVANCED < PREMIUM`.

Entradas da mesma capability DEVEM ter tipo, unidade, dimensão e schema
compatíveis. Valor negativo, unidade divergente, membro desconhecido, level sem
ordem publicada ou overflow tornam a entrada inválida; o sistema nunca corrige ou
converte silenciosamente. Se uma contribuição aplicável e materializada estiver
inválida — inclusive uma restrição — toda a avaliação daquela capability resulta
em `INDETERMINATE_CORRUPT` ou `INDETERMINATE_CONFLICT`; a contribuição é registrada
na lineage e jamais descartada para produzir uma concessão parcial.

## 2.2 Operador de grants

A definição publicada da capability DEVE selecionar um único operador de grants,
compatível com seu tipo:

| Tipo | Operadores permitidos |
| --- | --- |
| `FLAG` | `BOOLEAN_OR` |
| `QUANTITY` | `SUM` ou `MAXIMUM` |
| `SET` | `SET_UNION` |
| `LEVEL` | `LEVEL_MAX` segundo a ordem publicada |

Somente contribuições já materializadas como elegíveis e vigentes por decisões
anteriores entram nesta álgebra. O ADR-0039 determina que uma contribuição
promocional só nasce do output não monetário `PROMOTIONAL_ENTITLEMENT_GRANT` de
uma `PromotionVersion` exata. O ADR-0040 exige decisão `ELIGIBLE` e
`EligibilityContextSnapshot` aceito antes da materialização; `INELIGIBLE`,
`INDETERMINATE`, mera posse de cupom ou promoção apenas armazenada nunca entram.
O ADR-0041 exige ainda que a `PromotionVersion` seja selecionada como pacote
atômico no `PromotionCombinationResult`; candidata rejeitada ou benefício
destacado não entra, grant não recebe valor monetário em best price e não altera
o waterfall monetário. Budget, reservation e concorrência são governados pelo
ADR-0042; o grant só prossegue após o snapshot/attestation stateful aplicável.

As contribuições elegíveis e vigentes de `COMMERCIAL_BASE`, `COMMERCIAL_ADD_ON`,
`PROMOTIONAL_GRANT` e `OPERATIONAL_EXCEPTION` são validadas e agregadas pelo mesmo
operador. O cálculo é comutativo, associativo para o domínio aceito e independente
da ordem de persistência ou leitura. A enumeração das naturezas não cria
`last-write-wins` nem prioridade oculta entre grants.

Para `FLAG`, uma contribuição de grant representa somente `ENABLED`; ausência de
uma fonte opcional não é contribuição `false`. Para `QUANTITY`, `FINITE(0)` é valor
explícito e distinto de ausência, `NOT_GRANTED` e `UNLIMITED`.

Não são permitidos `REPLACE`, subtração por grant, expressão arbitrária, script,
SpEL, JavaScript ou operador desconhecido. `OPERATIONAL_EXCEPTION` continua apenas
concessiva e não pode alterar o modo de enforcement, autorizar cobrança ou
neutralizar restrição de risco.

## 2.3 Fase de restrições

Depois de agregado o grant, todas as `RISK_RESTRICTION` vigentes e válidas são
aplicadas em uma segunda fase. Os únicos efeitos conceituais permitidos são:

| Tipo | Restrições permitidas | Composição de múltiplas restrições |
| --- | --- | --- |
| `FLAG` | `DENY` | `DENY` domina |
| `QUANTITY` | `DENY`, `CAP` | `DENY` domina; caso contrário, menor cap válido |
| `SET` | `DENY`, `SET_REMOVE` | `DENY` domina; remoções são unidas |
| `LEVEL` | `DENY`, `LEVEL_CAP` | `DENY` domina; menor level cap válido |

A restrição sempre prevalece sobre qualquer grant, inclusive promoção ou exceção
operacional. Ela nunca aumenta o resultado, nunca altera o
`ContractEntitlementSnapshot` e nunca cria preço, invoice line ou efeito no
provider. A projeção preserva separadamente o valor concedido antes das restrições
e o resultado operacional posterior.

Uma restrição sem grant não cria direito para então restringi-lo: o resultado
permanece `NOT_GRANTED`, com a restrição preservada na lineage.

### 2.3.1 Financial access is a separate axis

`PAYMENT_DELINQUENCY` nunca é convertida em `RISK_RESTRICTION`, `CAP`, `DENY` ou
contribuição desta projeção. Conforme o ADR-0025, o dunning produz uma
`FINANCIAL_ACCESS_RESTRICTION` própria, com lifecycle, grace, evidência e recovery
independentes. No boundary de autorização/admission, a operação precisa satisfazer
tanto a decisão atual de entitlement/risco quanto a decisão financeira aplicável.

Esse gate financeiro pode impedir novas operações pagas ou de custo externo, mas
não altera quantidade, modo, snapshot, hash ou lineage do entitlement; também não
bloqueia Billing, pagamento, webhook, reconciliação, segurança, suporte ou recovery
plane preservados pelo ADR-0025. Cache/LKG de entitlement não concede bypass
financeiro.

## 2.4 `UNLIMITED` explícito

`UNLIMITED` é variante explícita do valor `QUANTITY`, permitida somente quando a
definição publicada da capability a admitir. Nunca é representada por `NULL`,
`-1`, zero, ausência, máximo técnico ou constante sentinela.

Na agregação de grants, uma contribuição `UNLIMITED` válida domina contribuições
finitas. Uma `RISK_RESTRICTION` posterior ainda pode aplicar `CAP` finito ou
`DENY`. Expiração da fonte ilimitada provoca nova avaliação no instante efetivo,
sem editar o histórico.

## 2.5 Estados resultantes

Toda avaliação usa um único `effectiveAt` canônico para snapshot, vigências,
contribuições e restrições e DEVE retornar um destes estados explícitos:

- **`GRANTED(value)`** — grant válido, já considerada a fase de restrições;
- **`NOT_GRANTED`** — nenhuma concessão vigente ou restrição `DENY` determinística;
- **`INDETERMINATE_MISSING`** — autoridade/projeção obrigatória ausente;
- **`INDETERMINATE_UNAVAILABLE`** — dependência local requerida indisponível;
- **`INDETERMINATE_CORRUPT`** — hash, schema, assinatura ou conteúdo inválido;
- **`INDETERMINATE_CONFLICT`** — contribuições incompatíveis ou composição não
  determinística.

Ausência de uma fonte opcional ou não vigente significa apenas “não contribui”. A
ausência de snapshot, definição da capability, policy/operator ou outra autoridade
obrigatória produz `INDETERMINATE_MISSING`.

Estado indeterminado nunca equivale a `GRANTED`, `UNLIMITED`, zero ou
`NOT_GRANTED` silencioso. O ADR-0036 fecha a resposta operacional: somente
`INDETERMINATE_UNAVAILABLE` pode considerar LKG positivo para operação low-risk
explicitamente allowlisted; `MISSING`, `CORRUPT` e `CONFLICT` nunca recebem grant
por LKG. Quota/capacidade/custo, financeiro, administração e risco exigem estado
atual e falham de forma segura.

## 2.6 Modos de enforcement

A versão publicada da capability e seu snapshot contratual DEVEM declarar um modo
compatível, sem inferência por nome de plano ou pela quantidade:

1. **`NO_QUOTA`** — decisão de acesso sem contador de franquia; ainda respeita
   `NOT_GRANTED` e `DENY`, não equivale a `UNLIMITED` e não impede metering/rating
   independente conforme `D-06`/ADR-0045;
2. **`HARD_LIMIT`** — operação elegível exige admissão/reserva atômica e é negada
   quando a franquia disponível não comporta as unidades;
3. **`SOFT_LIMIT`** — operação é admitida após o limite, com classificação e alerta,
   mas sem criar cobrança automaticamente e sem ser reinterpretada como
   `OVERAGE_ALLOWED`;
4. **`OVERAGE_ALLOWED`** — operação é admitida e o excedente é classificado como
   candidato a overage; o modelo de preço possível segue a allowlist do ADR-0038,
   mas metering, billability, quantidade autoritativa, true-up e rating permanecem
   em `D-06`.

Grant promocional materializado conforme ADR-0039 e selecionado como pacote
atômico pelo ADR-0041, ou exceção operacional, pode ampliar temporariamente a
franquia, mas não muda `SOFT_LIMIT` para
`OVERAGE_ALLOWED` nem cria obrigação financeira.
Alterar o modo exige nova versão/snapshot pelo fluxo contratual futuro aprovado.

## 2.7 Separação entre direito, consumo e cobrança

Para capabilities com quota, a decisão pode derivar, sem fundir os conceitos:

- valor incluído da projeção de entitlement;
- unidades reservadas por admissões concorrentes;
- `USAGE_OBSERVATION` confirmada e elegível;
- saldo incluído e, quando permitido, quantidade excedente.

Reservas e uso não são contribuições de entitlement e não mudam o valor contratado.
O fechamento da reserva e o registro do uso DEVEM ser idempotentes. O algoritmo de
metering/rating e o valor monetário pertencem a `D-06`; esta ADR define apenas que
o enforcement não pode depender de cálculo do provider.

## 2.8 Projeção explicável

A `EffectiveEntitlementProjection` tenant-local DEVE preservar conceitualmente:

- tenant, contrato, snapshot identity/version/hash e instante efetivo;
- capability, tipo, unidade, janela e dimensões;
- policy/version/hash e operador utilizados;
- cada contribuição tipada aceita e cada entrada inválida com reason code; a
  presença de entrada aplicável inválida torna a capability indeterminada;
- resultado dos grants antes das restrições;
- restrições aplicadas e resultado final;
- estado resultante e modo de enforcement;
- referências de reason, evidence, approval e correlation;
- hash determinístico do resultado e timestamp de cálculo.

Uma leitura otimizada pode expor o resultado achatado, mas não pode eliminar a
lineage reconstruível nem tornar-se autoridade independente.

Esta decisão foi aprovada como `D-04.2-C — opção A`. O ADR-0032 fechou
posteriormente `D-04.2-D`, o ADR-0034 `D-04.2-E` e o ADR-0035 `D-04.2-F`; o
ADR-0036 fechou `D-04.2-G` e o ADR-0037 fechou `D-04.2-H`. `D-00` permite
implementação hermética local dos planos TP-00013 e mantém effects `OFF`.

---

# 3. Decision Drivers

- impedir que ordem de inserts, relógio de retry ou cache alterem o resultado;
- evitar retorno disfarçado do override genérico;
- permitir FLAG, quantidade, conjunto e nível sem um rules engine arbitrário;
- impedir que cortesia/promocional contorne contenção de segurança;
- distinguir direito incluído, consumo, admissão e cobrança de overage;
- representar ilimitado, ausência e corrupção sem sentinelas ambíguas;
- suportar replay, auditoria, isolamento tenant e testes determinísticos;
- manter o cálculo independente de ASAAS e demais providers.

---

# 4. Considered Options

## Option A: Álgebra tipada determinística em duas fases

Description: Agregar grants por operador fechado e compatível com o tipo; aplicar
restrições de risco depois; retornar estado e lineage explícitos.

Pros:

- determinística, reproduzível e auditável;
- flexível para capacidades booleanas, quantitativas, sets e níveis;
- não exige engine de regras genérica;
- torna segurança dominante sem apagar contrato;
- separa enforcement de rating e provider.

Cons:

- exige schemas e testes por tipo/operador;
- projeção precisa preservar mais dados do que um limite numérico.

## Option B: Cadeia fixa com último valor vencedor

Description: Ordenar fontes e substituir o valor anterior pela última entrada.

Pros:

- implementação inicial pequena;
- leitura superficialmente simples.

Cons:

- recria override genérico;
- resultado depende de precedência e ordenação incidental;
- perde contribuições acumulativas e explicabilidade;
- facilita bypass de restrição por grant posterior.

## Option C: Rules engine ou DSL arbitrária

Description: Permitir expressões configuráveis para qualquer composição.

Pros:

- máxima liberdade de configuração;
- suporta casos futuros sem alterar o código do evaluator.

Cons:

- custo, superfície de ataque e operação desproporcionais ao estágio do produto;
- risco de não determinismo, loops, expressão insegura e decisões impossíveis de
  explicar;
- versionamento, sandbox, análise estática e observabilidade complexos.

---

# 5. Decision Outcome

A **Option A** foi aceita.

Ela oferece flexibilidade comercial e operacional por tipos e operadores seguros,
sem introduzir um interpretador genérico. A precedência é estrutural: grants
comutativos primeiro, restrições subtractivas depois. Nenhuma entrada substitui
outra por ordem de gravação.

---

# 6. Consequences

## Positive Consequences

- Resultados são reproduzíveis por snapshot, instante e policy hash.
- Restrições de segurança não podem ser anuladas por promoções/cortesias.
- `UNLIMITED`, ausência e corrupção deixam de compartilhar representação.
- O mesmo evaluator conceitual cobre diferentes formatos de capability.
- Overage pode ser admitido sem delegar preço ao provider.

## Negative Consequences

- Cada tipo e operador exige matriz de compatibilidade e golden tests.
- O read model precisa manter lineage além do resultado otimizado.
- Concorrência de quota exige reserva atômica e evidência PostgreSQL futura.

## Neutral Consequences

- Valores, limites e capabilities concretos ainda não foram aprovados.
- Grandfathering/adoção foram fechados no ADR-0032, efeitos no ADR-0034 e cutover
  legado conceitual no ADR-0035; degraded/cache/LKG foram fechados no ADR-0036.
  O boundary físico foi fechado no ADR-0037; rollout segue o baseline aceito de
  `D-14`/ADR-0051; execução hermética local está liberada por `D-00`, enquanto
  evidências externas e rollout permanecem bloqueados.
- Famílias físicas foram aprovadas no ADR-0037; DDL, DTO, endpoint e payload de
  evento finais permanecem para os planos e decisões bloqueantes.

---

# 7. Impact

## Compatibility with source taxonomy

| Fonte | Participação na composição | Limites desta decisão |
| --- | --- | --- |
| `COMMERCIAL_BASE` | Grant pelo operador publicado | Não consulta catálogo vivo. |
| `COMMERCIAL_ADD_ON` | Grant com item/preço/amendment válidos | Não nasce de edição administrativa. |
| `PROMOTIONAL_GRANT` | Grant separado produzido por `PROMOTIONAL_ENTITLEMENT_GRANT` de `PromotionVersion` exata e selecionada atomicamente em `PromotionCombinationResult`, enquanto versão/vigência forem válidas | Não altera modo, não gera preço, não representa desconto/crédito e não recebe valor em best price. |
| `OPERATIONAL_EXCEPTION` | Grant temporário | Nunca restringe, cobra ou neutraliza risco. |
| `RISK_RESTRICTION` | Segunda fase subtractiva | Somente segurança, abuso ou compliance. |
| `USAGE_OBSERVATION` | Fato separado da composição do entitlement; pode participar do cálculo de saldo | Nunca grant, restriction ou preço. |

## Ownership boundaries

- ADR-0028 continua dono da autoridade e placement do snapshot/projeção.
- ADR-0029 continua dono da natureza e provenance de cada entrada.
- ADR-0039 define a origem promocional e separa grant de benefício monetário e
  crédito/saldo.
- ADR-0040 decide eligibility/coupon security antes da materialização; seu
  tri-state promocional é evidência de entrada e não substitui os estados desta
  álgebra de entitlement.
- ADR-0041 decide seleção/combinação promocional antes da materialização; somente
  o grant do pacote atômico selecionado pode prosseguir para esta álgebra, sem
  misturar seu valor não monetário ao waterfall ou ao best price.
- Esta ADR define composição, resultado e enforcement conceituais.
- ADR-0032 define adoção de outra bundle version sem alterar esta álgebra.
- ADR-0034 define debt, data policy e cutoff de transição sem alterar esta álgebra.
- O ADR-0045, ao fechar `D-06`, governa metering, quota admission PostgreSQL,
  rating e valor de overage sem alterar esta álgebra.
- O ADR-0025, ao fechar `D-09`, governa inadimplência e
  `FINANCIAL_ACCESS_RESTRICTION` fora desta projeção.
- ADR-0036 governa cache, LKG, epochs, TTLs máximos e comportamento degradado; o
  store, keyspace e contratos físicos seguem o ADR-0037.

## Compatibility with ADR-0010

As cláusulas históricas `COALESCE`, `NULL=UNLIMITED`, override por tenant,
soft/hard inferido por plano e reset implícito no upgrade não são executáveis no
modelo-alvo. Apenas requisitos funcionais ainda válidos podem ser reexpressos por
snapshot, fonte tipada e composição desta ADR após as decisões restantes.

---

# 8. AI Agent Considerations (For Autonomous Agent Environments)

Agentes DEVEM:

- usar somente os tipos, operadores, estados e modos fechados nesta ADR;
- preservar grants, restrictions, uso e rating como eixos separados;
- tratar restrição como fase final dominante;
- manter `UNLIMITED` explícito e lineage reconstruível;
- aplicar `D-04.2-D` pelo ADR-0032, `D-04.2-E` pelo ADR-0034 e `D-04.2-F` pelo
  ADR-0035, `D-04.2-G` pelo ADR-0036, `D-04.2-H` pelo ADR-0037 e a origem
  promocional pelo ADR-0039, com eligibility/coupon security pelo ADR-0040 e
  seleção/waterfall pelo ADR-0041, capacidade pelo ADR-0042, lifecycle
  promocional pelo ADR-0043, metering/rating pelo ADR-0045 e inadimplência pelo
  ADR-0025, aplicando `D-00` somente ao escopo hermético local e preservando os
  gates de evidência/efeito.

Agentes NÃO DEVEM:

- criar `last-write-wins`, prioridade oculta ou override genérico;
- representar unlimited por null/sentinela;
- executar expressão ou script fornecido por usuário;
- permitir que promoção/exceção remova restrição;
- converter benefício monetário de promoção em grant ou grant em desconto;
- cobrar automaticamente em `SOFT_LIMIT` ou `OVERAGE_ALLOWED`;
- inventar fallback para estado indeterminado fora da matriz do ADR-0036;
- implementar DDL, API ou código a partir desta aprovação isolada.

---

# 9. Implementation Plan

Sequência futura, ainda bloqueada:

1. aplicar os ADR-0032, ADR-0034, ADR-0035, ADR-0036 e ADR-0037;
2. congelar schemas conceituais e matriz tipo/operador/modo;
3. decidir ports, contratos cross-module, DDL e OpenAPI;
4. criar evaluator de domínio puro, sem dependência de Spring/provider;
5. criar projeção tenant-local derivada e repository por port;
6. adicionar reserva atômica para hard/overage quando aplicável;
7. provar determinismo, concorrência, isolamento, rebuild e rollback em shadow;
8. executar cutover somente após os gates de migração e failure policy.

Nenhum código, migration, seed, configuração, Sandbox ou integração ASAAS é
autorizado agora.

---

# 10. Validation

A implementação futura deverá provar ao menos:

- permutações das mesmas contribuições produzem o mesmo hash e resultado;
- `SUM`, `MAXIMUM`, `SET_UNION`, `LEVEL_MAX` e `BOOLEAN_OR` obedecem golden vectors;
- operador incompatível, overflow, unidade ou dimensão divergente geram estado
  indeterminado/rejeição, nunca coerção;
- contribuição aplicável inválida, especialmente restrição, nunca é ignorada para
  produzir um grant parcial;
- fonte opcional ausente não contribui, enquanto autoridade obrigatória ausente
  produz `INDETERMINATE_MISSING`;
- múltiplos caps usam o menor, remoções usam união e `DENY` domina;
- promoção/exceção não neutraliza uma restrição vigente;
- benefício monetário do ADR-0039 não entra na álgebra e somente
  `PROMOTIONAL_ENTITLEMENT_GRANT` explícito pode produzir `PROMOTIONAL_GRANT`;
- `NULL`, `-1`, zero e ausência não viram `UNLIMITED`;
- `FINITE(0)`, `NOT_GRANTED`, ausência e `UNLIMITED` permanecem distintos;
- cap finito pode restringir grant unlimited sem mudar o snapshot;
- `SOFT_LIMIT` não cobra e `OVERAGE_ALLOWED` não calcula preço;
- `NO_QUOTA` ainda respeita `NOT_GRANTED`/`DENY` e não significa unlimited;
- uso/reserva alteram saldo, mas não o entitlement concedido;
- concorrência no último slot de hard limit aceita no máximo uma admissão;
- rebuild por snapshot/policy/effectiveAt reproduz projection hash;
- tenant A nunca participa da composição ou contador de tenant B;
- estado indeterminado não usa catálogo vivo, enum, constante ou fallback oculto.

---

# 11. Risks and Mitigations

| Risk | Mitigation decidida ou boundary |
| --- | --- |
| Ordem alterar resultado | Operador único, comutativo e versionado por capability. |
| Cortesia contornar segurança | Restrição aplicada na segunda fase e dominante. |
| Unlimited acidental | Tagged value explícito; null/sentinelas proibidos. |
| Rules engine virar superfície de execução | Operadores fechados; nenhum script/DSL arbitrária. |
| Overflow/precision drift | Valor exato, bounds publicados e rejeição antes de persistir/projetar. |
| Uso virar direito | Ledger/reserva separados da projeção de grants. |
| Soft limit virar cobrança | Rating e billability seguem D-06/ADR-0045; soft limit não cria efeito financeiro por inferência. |
| Falha virar allow | ADR-0036 limita LKG positivo a `UNAVAILABLE` low-risk allowlisted e falha seguro nas classes críticas. |
| Cache achatar lineage | Resultado otimizado nunca substitui contribuições reconstruíveis; envelope LKG preserva hash/epochs/lineage. |

---

# 12. Related ADRs

- [ADR-0000 - Governança documental](../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md)
- [ADR-0006 - Auditoria e compliance](ADR-0006-audit-compliance.md)
- [ADR-0010 - Parametrização de planos e limites](ADR-0010-tenant-plan-parametrization.md)
- [ADR-0019 - Database per tenant](ADR-0019-database-per-tenant.md)
- [ADR-0023 - Integração agnóstica de pagamentos](ADR-0023-agnostic-payment-provider-integration.md)
- [ADR-0028 - Entitlements versionados tenant-local](ADR-0028-entitlements-versionados-tenant-local.md)
- [ADR-0029 - Taxonomia tipificada de entitlements](ADR-0029-taxonomia-tipificada-entitlements.md)
- [ADR-0032 - Adoção versionada e grandfathering](ADR-0032-adocao-versionada-grandfathering-entitlements.md)
- [ADR-0034 - Efeitos não destrutivos de transições](ADR-0034-efeitos-transicao-nao-destrutiva-entitlements.md)
- [ADR-0035 - Migração evidence-first do legado](ADR-0035-migracao-evidence-first-entitlements-legados.md)
- [ADR-0036 - Cache/LKG fail-safe de entitlements](ADR-0036-cache-lkg-fail-safe-entitlements.md)
- [ADR-0037 - Boundary físico e ownership de entitlements](ADR-0037-boundary-fisico-entitlements-billing.md)
- [ADR-0038 - Pricing tipado, moeda e cadência](ADR-0038-pricing-tipado-moeda-cadencia.md)
- [ADR-0039 - Taxonomia tipada de benefícios promocionais](ADR-0039-taxonomia-beneficios-promocionais.md)
- [ADR-0040 - Elegibilidade promocional e segurança de cupons](ADR-0040-elegibilidade-promocional-seguranca-cupons.md)
- [ADR-0041 - Stacking e waterfall promocional determinísticos](ADR-0041-stacking-waterfall-promocional-deterministico.md)

---

# 13. References

- [REQ-00042 - Billing enterprise](../product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md)
- [UC-00038 - Catálogo, pricing e promoções](../product/use-cases/UC-00038-billing-catalog-pricing-promotions.md)
- [UC-00039 - Contratos, assinaturas e amendments](../product/use-cases/UC-00039-billing-contract-subscription-amendments.md)
- [UC-00040 - Uso, rating e fechamento](../product/use-cases/UC-00040-billing-usage-rating-invoice-close.md)
- [TP-00013 - Enterprise Billing Implementation](../delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md)
- [Manifesto de módulos](../architecture/module-registry.md)

---

# 14. Decision Lifecycle

Current State: **Accepted**

A aprovação explícita de 2026-08-23 alcança `D-04.2-C — opção A` conforme a
alternativa apresentada imediatamente antes do aceite. `D-04.2-D` foi aceita
posteriormente no ADR-0032, `D-04.2-E` no ADR-0034 e `D-04.2-F` no ADR-0035.
`D-04.2-G` foi aceita no ADR-0036 e `D-04.2-H` no ADR-0037; `D-04.3` foi aceita
no ADR-0038 e mantém pricing separado de direito/uso. `D-04.4-A` foi aceita no
ADR-0039 e especializa somente a origem promocional; `D-04.4-B` foi aceita no
ADR-0040 e exige eligibility tri-state fail-closed antes da materialização.
`D-04.4-C` foi aceita no ADR-0041 e exige seleção atômica antes de o grant
promocional entrar nesta álgebra. `D-04.4-D` e `D-04.4-E` foram fechadas nos
ADR-0042 e ADR-0043; `D-06` foi fechada no ADR-0045; `D-09` foi fechada no
ADR-0025; `D-13`/`D-14` foram fechadas nos ADR-0050/ADR-0051. `D-00` está
`RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`; evidências externas,
capabilities, piloto e rollout permanecem pendentes.

---

# 15. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 2.2 | 2026-08-25 | Solicitante humano, proprietário declarado / Codex (IA), materialização | Registra `D-00 = RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`; permite backend/frontend/DDL/migrations/testes herméticos locais e mantém chamadas externas, Sandbox ASAAS, piloto BP Farias, produção, flags `ON` e efeitos reais bloqueados. |
| 2.1 | 2026-08-25 | Codex (IA), sob `AUTH-BILLING-2026-08-25-001` | Reconcilia metering/SoD/rollout e sucessores de promoção com ADR-0042/ADR-0043/ADR-0045/ADR-0050/ADR-0051; preserva a origem humana de `D-04.2-C`, revisão IA `NOT_PERFORMED`/`OPEN` e `D-00` ativo. |
| 2.0 | 2026-08-25 | Codex (IA), sob `AUTH-BILLING-2026-08-25-001` | Reconcilia `D-09` e `D-06`: inadimplência usa `FINANCIAL_ACCESS_RESTRICTION` fora da álgebra e o ADR-0045 governa metering/rating; registra proveniência IA e mantém `D-00` ativo. |
| 1.9 | 2026-08-24 | Responsável pelo produto / Arquitetura | Registra ADR-0041 como decisão subsequente de `D-04.4-C`: somente `PROMOTIONAL_ENTITLEMENT_GRANT` do pacote atômico selecionado em `PromotionCombinationResult` entra como contribuição; grant não recebe valor em best price nem altera waterfall monetário; `D-04.4-D`, `D-04.4-E` e `D-00` permanecem abertos. |
| 1.8 | 2026-08-24 | Responsável pelo produto / Arquitetura | Registra ADR-0040 como decisão subsequente de `D-04.4-B`: apenas contribuição promocional já `ELIGIBLE` e materializada entra na álgebra; `INELIGIBLE`/`INDETERMINATE`, cupom ou promoção armazenada não concedem grant, e o tri-state promocional não substitui estados de entitlement; `D-04.4-C` a `D-04.4-E` e `D-00` permanecem abertos. |
| 1.7 | 2026-08-24 | Responsável pelo produto / Arquitetura | Registra ADR-0039 como decisão subsequente de `D-04.4-A`: apenas o output explícito `PROMOTIONAL_ENTITLEMENT_GRANT` entra como `PROMOTIONAL_GRANT`; descontos e créditos permanecem fora da álgebra. |
| 1.6 | 2026-08-24 | Responsável pelo produto / Arquitetura | Registra ADR-0038 como decisão subsequente de `D-04.3`: pricing possui álgebra própria e `OVERAGE_ALLOWED` continua sem calcular preço/rating por si só. |
| 1.5 | 2026-08-24 | Responsável pelo produto / Arquitetura | Registra ADR-0037 como decisão subsequente de `D-04.2-H`: composição/decisão/admission recebem APIs e placement físicos dentro de Billing, com projection entries tenant-local e sem reconstrução por consumidores; `D-00` continua aberto. |
| 1.4 | 2026-08-23 | Responsável pelo produto / Arquitetura | Registra ADR-0036 como decisão subsequente de `D-04.2-G`: somente `UNAVAILABLE` low-risk allowlisted pode considerar LKG positivo; estados de integridade e classes críticas falham seguro; mantém `D-04.2-H`, `D-00` e implementação abertos. |
| 1.3 | 2026-08-23 | Responsável pelo produto / Arquitetura | Registra o ADR-0035 como decisão subsequente de `D-04.2-F`, mantendo failure/LKG, boundary físico e implementação abertos. |
| 1.2 | 2026-08-23 | Responsável pelo produto / Arquitetura | Registra o ADR-0034 como decisão subsequente de `D-04.2-E`, mantendo `D-04.2-F` a `D-04.2-H` e a implementação abertas. |
| 1.1 | 2026-08-23 | Responsável pelo produto / Arquitetura | Registra o ADR-0032 como decisão subsequente de `D-04.2-D`, mantendo `D-04.2-E` a `D-04.2-H` e a implementação abertas. |
| 1.0 | 2026-08-23 | Responsável pelo produto / Arquitetura | Aceite de `D-04.2-C — opção A`: álgebra tipada determinística, grants antes de restrições, estados explícitos, unlimited sem sentinela e enforcement separado de uso/rating. |

---

# 16. Repository Structure

Esta decisão reside em:

```text
docs/adrs/ADR-0030-composicao-deterministica-enforcement-entitlements.md
```

Alvos físicos permanecem planejados e somente serão registrados após os gates.

---

# 17. Review Process

1. A opção A foi recomendada ao responsável pelo produto; as opções B e C foram
   apresentadas com seus custos e riscos.
2. O responsável pelo produto aprovou explicitamente `D-04.2-C` em 2026-08-23,
   referindo-se à opção recomendada apresentada imediatamente antes.
3. Arquitetura materializou somente semântica, invariantes e boundaries aprovados.
4. Mudança normativa exige nova versão aceita ou ADR sucessora.
5. Aprovações posteriores não podem ser inferidas deste documento.

---

# 18. Notes

Os nomes de tipos, operadores, estados e modos são conceitos canônicos aprovados.
Sua representação física segue o ADR-0037 e pode refinar nomes internos nos
implementation plans, desde que mantenha semântica, determinismo, lineage e
proibições desta ADR.

O AS-IS continua legado e não implementa esta decisão.
