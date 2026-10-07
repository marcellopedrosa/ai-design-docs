---
document_id: "ADR-0029"
primary_nature: "Decisao"
objective: "Separar direitos comerciais, add-ons cobraveis, concessoes promocionais, excecoes operacionais, restricoes de risco e fatos de uso, eliminando overrides genericos que misturem contrato, operacao e cobranca."
scope: "Classificacao canonica das fontes que podem compor futuramente um entitlement efetivo, metadados conceituais obrigatorios e limites entre contrato, promocao, operacao, risco e uso observado."
non_objectives: "Definir composicao ou precedencia entre fontes, estados e semantica de capability/quota, hard-limit, soft-limit, overage, unlimited, lifecycle de inadimplencia, grandfathering, upgrade/downgrade, backfill/cutover, resposta a falhas, cache, boundary modular, DDL, OpenAPI, RBAC/alçadas finais ou autorizar implementacao; `PAYMENT_DELINQUENCY` foi posteriormente classificada pelo ADR-0025 em eixo financeiro separado."
owner: "Arquitetura / Billing / Produto"
status: "Accepted"
date: "2026-08-25"
version: "1.13"
keywords: "entitlement taxonomy, commercial base, commercial add-on, promotional grant, operational exception, risk restriction, usage observation, typed source, no generic override"
related_files: "README.md, ../../../docs/specs/TP-00013-enterprise-billing-implementation-task-plan.md, ADR-0006-audit-compliance.md, ADR-0010-tenant-plan-parametrization.md, ADR-0025-suspensao-tenant-inadimplencia-recuperacao.md, ADR-0028-entitlements-versionados-tenant-local.md, ADR-0030-composicao-deterministica-enforcement-entitlements.md, ADR-0032-adocao-versionada-grandfathering-entitlements.md, ADR-0034-efeitos-transicao-nao-destrutiva-entitlements.md, ADR-0035-migracao-evidence-first-entitlements-legados.md, ADR-0036-cache-lkg-fail-safe-entitlements.md, ADR-0037-boundary-fisico-entitlements-billing.md, ADR-0038-pricing-tipado-moeda-cadencia.md, ADR-0039-taxonomia-beneficios-promocionais.md, ADR-0040-elegibilidade-promocional-seguranca-cupons.md, ADR-0041-stacking-waterfall-promocional-deterministico.md"
code_references: "Estado legado em `TenantController`, `UpdateTenantUseCase`, `TenantSettings`, `TenantApiImpl`, `Plan`, `SubscriptionPlan`, `BillingApiAdapter`, `ChatbotMessageCreditDeductionListener`, `ConsultaSituacaoFiscalCreditDeductionListener`, `UsageReporterScheduler` e `SuspendOverdueTenantUseCase`; boundary e destinos planejados sob `app/src/main/java/br/com/duoset/saas_service/contexts/billing/` definidos no ADR-0037, ainda não implementados."
principal_statement: "Toda fonte de entitlement deve ser classificada como `COMMERCIAL_BASE`, `COMMERCIAL_ADD_ON`, `PROMOTIONAL_GRANT`, `OPERATIONAL_EXCEPTION` ou `RISK_RESTRICTION`; `USAGE_OBSERVATION` permanece fato de consumo e nunca entitlement. Add-on cobrável exige item contratual e amendment; `PROMOTIONAL_GRANT` exige `PromotionVersion` exata conforme ADR-0039, decisão `ELIGIBLE` conforme ADR-0040 e seleção atômica registrada em `PromotionCombinationResult` conforme ADR-0041; exceção operacional é temporária e não cobra implicitamente, restrição de risco cobre somente segurança/abuso/compliance, e inadimplência usa o eixo distinto `FINANCIAL_ACCESS_RESTRICTION` do ADR-0025, sem reescrever contrato ou fingir risco."
---

# ADR-0029 - Taxonomia tipificada de concessões e restrições de entitlement

- Document ID: `ADR-0029`
- Primary Nature: `Decisao`
- Objective: Separar direitos comerciais, add-ons cobraveis, concessoes promocionais, excecoes operacionais, restricoes de risco e fatos de uso, eliminando overrides genericos que misturem contrato, operacao e cobranca.
- Scope: Classificacao canonica das fontes que podem compor futuramente um entitlement efetivo, metadados conceituais obrigatorios e limites entre contrato, promocao, operacao, risco e uso observado.
- Non-objectives: Definir composicao ou precedencia entre fontes, estados e semantica de capability/quota, hard-limit, soft-limit, overage, unlimited, lifecycle de inadimplencia, grandfathering, upgrade/downgrade, backfill/cutover, resposta a falhas, cache, boundary modular, DDL, OpenAPI, RBAC/alçadas finais ou autorizar implementacao; `PAYMENT_DELINQUENCY` foi posteriormente classificada pelo ADR-0025 em eixo financeiro separado.
- Keywords: entitlement taxonomy, commercial base, commercial add-on, promotional grant, operational exception, risk restriction, usage observation, typed source, no generic override
- Related Files: `docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00038-billing-catalog-pricing-promotions.md`, `docs/product/use-cases/UC-00039-billing-contract-subscription-amendments.md`, `docs/product/use-cases/UC-00040-billing-usage-rating-invoice-close.md`, `../../../docs/specs/TP-00013-enterprise-billing-implementation-task-plan.md`, `ADR-0006-audit-compliance.md`, `ADR-0010-tenant-plan-parametrization.md`, `ADR-0025-suspensao-tenant-inadimplencia-recuperacao.md`, `ADR-0028-entitlements-versionados-tenant-local.md`, `ADR-0030-composicao-deterministica-enforcement-entitlements.md`, `ADR-0032-adocao-versionada-grandfathering-entitlements.md`, `ADR-0034-efeitos-transicao-nao-destrutiva-entitlements.md`, `ADR-0035-migracao-evidence-first-entitlements-legados.md`, `ADR-0036-cache-lkg-fail-safe-entitlements.md`, `ADR-0037-boundary-fisico-entitlements-billing.md`, `ADR-0038-pricing-tipado-moeda-cadencia.md`, `ADR-0039-taxonomia-beneficios-promocionais.md`, `ADR-0040-elegibilidade-promocional-seguranca-cupons.md`, `ADR-0041-stacking-waterfall-promocional-deterministico.md`
- Code References: Estado legado em `TenantController`, `UpdateTenantUseCase`, `TenantSettings`, `TenantApiImpl`, `Plan`, `SubscriptionPlan`, `BillingApiAdapter`, `ChatbotMessageCreditDeductionListener`, `ConsultaSituacaoFiscalCreditDeductionListener`, `UsageReporterScheduler` e `SuspendOverdueTenantUseCase`; boundary e destinos planejados sob `app/src/main/java/br/com/duoset/saas_service/contexts/billing/` definidos no ADR-0037, ainda não implementados.
- Principal Decision: Toda fonte de entitlement deve ser classificada como `COMMERCIAL_BASE`, `COMMERCIAL_ADD_ON`, `PROMOTIONAL_GRANT`, `OPERATIONAL_EXCEPTION` ou `RISK_RESTRICTION`; `USAGE_OBSERVATION` permanece fato de consumo e nunca entitlement. Add-on cobrável exige item contratual e amendment; `PROMOTIONAL_GRANT` exige `PromotionVersion` exata conforme ADR-0039, decisão `ELIGIBLE` conforme ADR-0040 e seleção atômica registrada em `PromotionCombinationResult` conforme ADR-0041; exceção operacional é temporária e não cobra implicitamente, restrição de risco cobre somente segurança/abuso/compliance, e inadimplência usa o eixo distinto `FINANCIAL_ACCESS_RESTRICTION` do ADR-0025, sem reescrever contrato ou fingir risco.
- Date: 2026-08-25
- Status: Accepted
- Version: 1.13
- Last Reviewed: 2026-08-25
- Authors / Owners: Arquitetura / Billing / Produto
- Reviewers: Responsável pelo produto, com aprovação explícita de `D-04.2-B — opção A` em 2026-08-23; Arquitetura
- Stakeholders: Produto, Financeiro, Backend, Frontend, Segurança, Compliance, Operações e tenants contratantes
- Supersedes: N/A; especializa o ADR-0028 e restringe modelos de override genérico do ADR-0010. A composição foi aceita no ADR-0030, a adoção no ADR-0032, os efeitos no ADR-0034, a migração legada no ADR-0035, failure/cache/LKG no ADR-0036 e boundary físico no ADR-0037.
- Superseded by: N/A

---

# 0. Provenance of the D-09 reconciliation

A taxonomia original de `D-04.2-B` permanece uma decisão humana explícita de
2026-08-23. A classificação posterior de inadimplência registrada nesta versão
vem de `D-09`/ADR-0025 e possui proveniência `AI_DELEGATED`, ator
`AI_AGENT — Codex (OpenAI)`, autoridade
`OWNER_DELEGATION — AUTH-BILLING-2026-08-25-001`, revisão humana substantiva
`NOT_PERFORMED` e reviewability `OPEN`. Essa origem de IA não pode ser apagada por
ratificação futura.

A reconciliação vigente também registra que `D-04.4-D` foi aceita diretamente
pelo humano no ADR-0042 e que `D-04.4-E` a `D-14` foram aceitas sob a mesma
autoridade delegada. Isso não altera a origem humana de `D-04.2-B`, não constitui
revisão humana das decisões delegadas. `D-00 = RELEASED_WITH_SCOPE —
HUMAN_EXPLICIT — TP-00013 local-only` permite implementação hermética local.

---

# 1. Context

O [ADR-0028](ADR-0028-entitlements-versionados-tenant-local.md) fixou uma
autoridade contratual tenant-local e imutável, mas deixou intencionalmente aberta a
classificação dos elementos que futuramente poderão participar da projeção
operacional. Sem uma taxonomia explícita, um único campo de “override” poderia
representar situações incompatíveis:

- um direito vendido e cobrado;
- um benefício promocional com prazo;
- uma cortesia operacional temporária;
- uma contenção por segurança, abuso ou compliance;
- ou apenas consumo já observado.

Essa ambiguidade permite conceder sem cobrar, cobrar sem vínculo contratual,
transformar incidente em mudança comercial, perder add-on em troca de plano ou
usar consumo como se fosse autorização. O ADR-0010 propôs overrides numéricos por
tenant sem preservar obrigatoriamente origem contratual, preço, vigência e natureza.
O modelo ainda não foi implementado, permitindo corrigir a fronteira antes de criar
dual-write ou dívida de migração.

---

# 2. Decision Statement

Toda entrada que possa influenciar futuramente a projeção de entitlement DEVE ter
exatamente uma natureza canônica:

1. **`COMMERCIAL_BASE`** — direito aceito na composição contratual base e
   materializado no `ContractEntitlementSnapshot`. Sua origem é o contrato e a
   `EntitlementBundleVersion` correspondente.
2. **`COMMERCIAL_ADD_ON`** — ampliação cobrável posterior ao contrato base. DEVE
   possuir `SubscriptionItem`, preço/moeda explícitos e o `Amendment` aceito que a
   introduziu, alterou ou encerrou. Nunca nasce de edição administrativa de limite.
3. **`PROMOTIONAL_GRANT`** — contribuição não monetária produzida separadamente
   por `PROMOTIONAL_ENTITLEMENT_GRANT`, vinculada à identidade, versão e hash da
   `PromotionVersion` publicada conforme ADR-0039, a uma decisão `ELIGIBLE` e ao
   `EligibilityContextSnapshot` aceito conforme ADR-0040, e à seleção do pacote
   promocional atômico em `PromotionCombinationResult` pinado conforme ADR-0041,
   além da materialização contratual aplicável e sua vigência. `INELIGIBLE`,
   `INDETERMINATE`, candidata elegível porém rejeitada pela combinação ou benefício
   destacado de promoção não selecionada nunca produzem contribuição. Desconto,
   preço promocional, quantidade/período gratuito e fee waiver sem concessão
   operacional permanecem efeitos monetários, não entitlement.
4. **`OPERATIONAL_EXCEPTION`** — concessão operacional temporária, motivada,
   evidenciada, aprovada e com expiração obrigatória. É somente concessiva: nunca
   reduz ou bloqueia direito. Não modifica o contrato, não cria `SubscriptionItem`,
   não gera invoice line nem cobrança implícita.
5. **`RISK_RESTRICTION`** — restrição em eixo próprio por segurança, abuso,
   ou compliance. É somente restritiva: nunca amplia direito. Preserva o direito
   contratado no snapshot, registra origem/revisão e nunca cria cobrança ou
   reescreve histórico.

`PAYMENT_DELINQUENCY` não pertence a nenhuma das cinco naturezas e não é
`RISK_RESTRICTION`. O ADR-0025, ao fechar `D-09`, criou o eixo separado
`FINANCIAL_ACCESS_RESTRICTION`: ele restringe prospectivamente operações pagas ou
de custo externo segundo policy de dunning, preserva contrato/snapshot e recovery
plane e nunca converte atraso financeiro em alegação de segurança, abuso ou
compliance.

`USAGE_OBSERVATION` representa fato de uso observado, confirmado ou agregado. Ele
NÃO É entitlement, concessão, restrição, preço ou autorização e não pode ser
gravado na mesma taxonomia como se fosse uma fonte de direito.

Toda concessão ou restrição DEVE preservar conceitualmente:

- `sourceType`, `sourceId` e, quando aplicável, `sourceVersion`;
- scope explícito de capability/meter e dimensões allowlisted;
- período de vigência e referência temporal inequívoca;
- `reasonCode` tipado;
- `evidenceRef` mínima, sem segredo ou payload sensível;
- ator/canal de origem, `approvalRef`, correlation e timestamps auditáveis;
- referência ao snapshot/contrato afetado sem mutá-lo;
- referência monetária obrigatória somente quando a natureza for comercial e
  cobrável.

O sistema NÃO DEVE oferecer “override numérico genérico”. Toda operação
administrativa futura deve declarar a natureza acima e satisfazer seus invariantes.
A projeção futura deve preservar as contribuições tipadas e sua lineage, sem
achatá-las em um número sem explicação.

Natureza ausente, desconhecida ou incompatível com sua origem é inválida e nunca
concede direito. O ADR-0030 posteriormente definiu estado indeterminado para a
capability; o ADR-0036 determina que `MISSING`, `CORRUPT` e `CONFLICT` nunca usam
LKG positivo. Somente indisponibilidade técnica `UNAVAILABLE` pode consultar LKG
low-risk allowlisted, preservando natureza e lineage.

Esta decisão foi aprovada como `D-04.2-B — opção A`. Ela não define a composição,
precedência ou decisão de enforcement entre as naturezas; esse contrato foi
posteriormente aceito em `D-04.2-C`/ADR-0030. Ela também não remove o freeze do
TP-00013.

---

# 3. Decision Drivers

- impedir concessão de serviço sem termo/preço quando deveria ser add-on;
- impedir cobrança automática por cortesia ou ajuste operacional;
- preservar contrato e auditoria mesmo durante restrição temporária;
- tornar promoção reproduzível por versão e vigência;
- manter fatos de uso separados de direitos e decisões;
- eliminar um campo administrativo capaz de contornar quote/amendment/approval;
- permitir projeção local explicável sem introduzir policy engine genérico;
- manter independência de ASAAS e de qualquer payment provider.

---

# 4. Considered Options

## Option A: Taxonomia tipada com eixos comerciais, operacionais e de risco

Description: Usar as cinco naturezas aprovadas, lineage obrigatória e uso observado
fora do modelo de entitlement.

Pros:

- preserva intenção e efeito de cada alteração;
- separa cobrança, cortesia, contenção e medição;
- permite auditoria e expiração por natureza;
- evita bypass de contrato por edição numérica;
- suporta evolução futura de composição e enforcement.

Cons:

- exige mais tipos e validações do que um único campo;
- requer workflows distintos para contrato, promoção, operação e risco.

## Option B: Override genérico com valor, motivo e data

Description: Manter um registro numérico único e acrescentar metadados opcionais.

Pros:

- modelo inicial pequeno;
- UI administrativa aparentemente simples.

Cons:

- metadados opcionais não garantem vínculo comercial;
- mistura aumento, redução, cortesia e add-on;
- facilita cobrança ou concessão implícita;
- não elimina a ambiguidade do ADR-0010.

## Option C: Somente contrato, sem exceção operacional ou restrição separada

Description: Toda mudança exige amendment comercial.

Pros:

- uma única fonte de direito;
- histórico contratual direto.

Cons:

- força incidentes, suporte e segurança para dentro do contrato;
- torna mitigação temporária lenta ou comercialmente incorreta;
- pode gerar preço/invoice para ações que não são venda.

---

# 5. Decision Outcome

A **Option A** foi aceita.

Ela oferece a flexibilidade necessária sem transformar Billing em um policy engine
genérico. A natureza obrigatória torna inválida por construção a edição de um
limite sem origem: add-on precisa de contrato/preço, promoção precisa de versão,
exceção precisa de expiração/aprovação e restrição precisa de motivo/evidência. A
composição, deliberadamente fora do aceite original, foi posteriormente fechada no
ADR-0030.

---

# 6. Consequences

## Positive Consequences

- Cada direito/restrição possui origem e responsabilidade claras.
- Add-on cobrável permanece reconciliável com contrato e invoice futura.
- Exceção operacional não produz receita fictícia.
- Restrição não destrói o histórico do que foi contratado.
- Promoção pode expirar sem editar catálogo ou snapshot anterior.
- Uso observado não consegue conceder acesso por acidente.

## Negative Consequences

- Serão necessários workflows e permissões distintos.
- A projeção futura precisará explicar múltiplas contribuições tipadas.
- Migração legada terá de classificar ou colocar registros ambíguos em fila, nunca
  adivinhar sua natureza.

## Neutral Consequences

- A taxonomia não decide o resultado quando grant e restriction coexistem.
- O preço continua fora deste ADR e é governado pelo ADR-0038; a origem e a
  separação dos benefícios promocionais seguem o ADR-0039, enquanto eligibility
  tri-state e coupon security seguem o ADR-0040 e seleção/waterfall do pacote
  atômico segue o ADR-0041. Valores comerciais concretos, budget e rating/overage
  autoritativo permanecem fora destas decisões.
- Famílias físicas e boundary foram aprovados no ADR-0037; DDL, DTOs e payloads
  finais podem avançar nos implementation plans sob a liberação local-only de `D-00`.

---

# 7. Impact

## Authority and mutation boundaries

| Natureza | Fonte obrigatória | Pode cobrar implicitamente? | Muta contrato/snapshot? |
| --- | --- | --- | --- |
| `COMMERCIAL_BASE` | Contrato + `EntitlementBundleVersion` | Somente pelo fluxo comercial explícito | Não; nova revisão materializa novo snapshot conforme decisões futuras. |
| `COMMERCIAL_ADD_ON` | `SubscriptionItem` + preço + `Amendment` | Não implicitamente; cobrança deriva do item/termo aprovado | Não reescreve snapshot anterior. |
| `PROMOTIONAL_GRANT` | `PromotionVersion` exata + output `PROMOTIONAL_ENTITLEMENT_GRANT` + decisão `ELIGIBLE`/`EligibilityContextSnapshot` do ADR-0040 + seleção atômica em `PromotionCombinationResult` do ADR-0041 + termo/snapshot + vigência | Não; benefício monetário é output separado pelo ADR-0039 | Não reescreve versão publicada, preço ou snapshot anterior. |
| `OPERATIONAL_EXCEPTION` | Workflow operacional aprovado + expiração | Nunca | Nunca. |
| `RISK_RESTRICTION` | Workflow de segurança, abuso ou compliance aprovado | Nunca cria cobrança | Nunca. |
| `FINANCIAL_ACCESS_RESTRICTION` | Caso de dunning elegível conforme ADR-0025; eixo financeiro separado, não fonte de entitlement | Nunca cria cobrança nova | Nunca; restringe acesso prospectivo sem fingir risco. |
| `USAGE_OBSERVATION` | Evento/fato de uso idempotente | Não por si só | Não é entrada de entitlement. |

## Separation from provider and invoicing

- Nenhuma natureza chama ASAAS ou outro provider.
- Um `COMMERCIAL_ADD_ON` não cria cobrança externa por existir; ele participa do
  contrato/rating/invoice conforme decisões posteriores.
- `OPERATIONAL_EXCEPTION` e `RISK_RESTRICTION` não criam invoice line.
- `USAGE_OBSERVATION` só poderá influenciar rating ou quota segundo policies
  aprovadas, nunca por conversão implícita em grant.

## Compatibility with existing decisions

- **ADR-0028:** especializado; todas as naturezas referenciam a autoridade
  tenant-local sem substituí-la.
- **ADR-0010:** restringido; `tenant_resource_overrides` não pode ser implementado
  como campo genérico que misture as naturezas acima.
- **ADR-0030:** complementa esta taxonomia com tipos de valor, composição
  determinística, restrições dominantes, estados e modos explícitos.
- **ADR-0039:** especializa a origem promocional: somente
  `PROMOTIONAL_ENTITLEMENT_GRANT` de `PromotionVersion` exata produz esta natureza,
  sem misturá-la com desconto, crédito ou saldo.
- **ADR-0040:** restringe a materialização promocional: somente decisão
  `ELIGIBLE`, ligada à policy, facts e snapshot exatos, pode originar a
  contribuição; `INELIGIBLE` e `INDETERMINATE` não entram nesta taxonomia.
- **ADR-0041:** restringe a contribuição promocional a uma `PromotionVersion`
  selecionada como pacote atômico no `PromotionCombinationResult`; grant não
  recebe valor monetário, não influencia best price e benefício isolado de pacote
  rejeitado não entra na composição de entitlement.
- **ADR-0006:** audit/evidence aplicam-se, mas ações, retenção e RBAC finais ainda
  dependem dos gates correspondentes.
- **Inadimplência:** `D-09` foi fechada pelo ADR-0025; `PAYMENT_DELINQUENCY`
  materializa exclusivamente `FINANCIAL_ACCESS_RESTRICTION`, em eixo separado das
  cinco naturezas e sem alterar `RISK_RESTRICTION`.

---

# 8. AI Agent Considerations (For Autonomous Agent Environments)

Agentes DEVEM tratar `D-04.2-B` como taxonomia fechada, aplicar `D-04.2-C` pelo
ADR-0030, `D-04.2-D` pelo ADR-0032, `D-04.2-E` pelo ADR-0034 e `D-04.2-F` pelo
ADR-0035, `D-04.2-G` pelo ADR-0036 e `D-04.2-H` pelo ADR-0037. Devem aplicar a
origem promocional do ADR-0039, eligibility/coupon security do ADR-0040 e seleção
atômica/waterfall do ADR-0041, capacidade/redemption do ADR-0042 e lifecycle do
ADR-0043, aplicando `D-00` somente ao escopo hermético local dos planos TP-00013.

Eles NÃO DEVEM:

- criar endpoint, tabela ou formulário de override numérico genérico;
- transformar add-on pago em exceção administrativa;
- gerar preço/invoice a partir de exceção ou restrição;
- apagar direito contratado para representar bloqueio;
- usar `USAGE_OBSERVATION` como grant;
- inventar precedência diferente da composição em duas fases do ADR-0030;
- converter benefício monetário do ADR-0039 em grant ou grant em desconto;
- implementar antes da remoção explícita do freeze.

---

# 9. Implementation Plan

Sequência futura, não autorizada por esta decisão:

1. aplicar os ADR-0030, ADR-0032, ADR-0034, ADR-0035, ADR-0036 e ADR-0037;
2. congelar as decisões restantes, permissions, ports, schemas e OpenAPI;
3. inventariar settings/overrides legados e sua evidência disponível;
4. classificar somente dados com origem comprovável; enviar ambiguidades para fila;
5. implementar aggregates/read models tenant-local de forma aditiva;
6. validar shadow projection, isolamento, auditoria e rollback;
7. executar cutover por tenant apenas conforme `D-04.2-F`.

Nenhum código, migration, seed, configuração, Sandbox ou integração ASAAS é
autorizado agora.

---

# 10. Validation

A implementação futura deverá provar que:

- um add-on sem `SubscriptionItem`, preço ou amendment é rejeitado;
- uma exceção sem expiração, motivo, evidência ou aprovação é rejeitada;
- uma exceção nunca reduz direitos e uma restrição nunca os amplia;
- uma exceção/restrição nunca cria item, invoice line ou chamada de provider;
- uma restrição não altera o `ContractEntitlementSnapshot` original;
- uma promoção expirada deixa de contribuir segundo a policy futura sem editar sua
  versão ou o snapshot histórico;
- somente `PROMOTIONAL_ENTITLEMENT_GRANT` com `PromotionVersion` exata pode
  materializar `PROMOTIONAL_GRANT`, sem alterar preço;
- um fato de uso não pode ser persistido como concessão;
- nenhum caminho administrativo aceita natureza ausente ou “generic override”;
- tenant A não lê, cria, aprova, restringe ou excepciona entitlement de B;
- lineage e audit permitem explicar cada contribuição sem guardar payload sensível.

---

# 11. Risks and Mitigations

| Risk | Mitigation decidida ou boundary |
| --- | --- |
| Add-on existir sem cobrança | Vínculo obrigatório com item, preço e amendment. |
| Cortesia gerar cobrança | `OPERATIONAL_EXCEPTION` não é item comercial e não produz invoice. |
| Restrição apagar direito contratado | Eixo separado e snapshot imutável. |
| Exceção operacional permanente | Expiração obrigatória; duração/alçada exatas seguem D-13/ADR-0050 e seu contrato executável. |
| Uso virar autorização | `USAGE_OBSERVATION` fora da taxonomia de entitlement. |
| Projeção achatar origens | Lineage por natureza/source/version obrigatória. |
| Conflito entre grant e restriction | Aplicar composição em duas fases e restrição dominante do ADR-0030. |
| Migração adivinhar natureza | ADR-0035 exige manifest tipado e quarentena para ambiguidade. |
| Cache/LKG achatar ou reviver fonte inválida | ADR-0036 exige envelope com lineage/hash/epochs; `MISSING`, `CORRUPT` e `CONFLICT` falham de forma segura. |
| Desconto monetário virar grant implícito | ADR-0039 separa outputs e exige `PROMOTIONAL_ENTITLEMENT_GRANT` explícito. |

---

# 12. Related ADRs

- [ADR-0000 - Governança documental](../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md)
- [ADR-0006 - Auditoria e compliance](ADR-0006-audit-compliance.md)
- [ADR-0010 - Parametrização de planos e limites](ADR-0010-tenant-plan-parametrization.md)
- [ADR-0019 - Database per tenant](ADR-0019-database-per-tenant.md)
- [ADR-0023 - Integração agnóstica de pagamentos](ADR-0023-agnostic-payment-provider-integration.md)
- [ADR-0025 - Inadimplência e recuperação segura](ADR-0025-suspensao-tenant-inadimplencia-recuperacao.md)
- [ADR-0028 - Entitlements versionados tenant-local](ADR-0028-entitlements-versionados-tenant-local.md)
- [ADR-0030 - Composição determinística e enforcement](ADR-0030-composicao-deterministica-enforcement-entitlements.md)
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
- [TP-00013 - Enterprise Billing Implementation](../../../docs/specs/TP-00013-enterprise-billing-implementation-task-plan.md)
- [Manifesto de módulos](../architecture/module-registry.md)

---

# 14. Decision Lifecycle

Current State: **Accepted**

A aprovação explícita de 2026-08-23 alcança somente `D-04.2-B — opção A`.
`D-04.2-C` foi aceita posteriormente no ADR-0030, `D-04.2-D` no ADR-0032 e
`D-04.2-E` no ADR-0034, `D-04.2-F` no ADR-0035, `D-04.2-G` no ADR-0036 e
`D-04.2-H` no ADR-0037; `D-04.3` foi aceita no ADR-0038 sem misturar preço e
entitlement. `D-04.4-A` foi aceita posteriormente no ADR-0039 e vincula
`PROMOTIONAL_GRANT` a `PROMOTIONAL_ENTITLEMENT_GRANT` de uma `PromotionVersion`
exata; `D-04.4-B` foi aceita no ADR-0040 e exige decisão `ELIGIBLE` materializada
antes da combinação. `D-04.4-C` foi aceita no ADR-0041 e exige seleção do pacote
atômico no `PromotionCombinationResult` antes que seu grant possa prosseguir para
a futura reserva/materialização. `D-04.4-D` foi fechada no ADR-0042 e
`D-04.4-E` no ADR-0043. `D-09` foi fechada no ADR-0025 com
`FINANCIAL_ACCESS_RESTRICTION` separado; `D-13`/`D-14` foram fechadas nos
ADR-0050/ADR-0051. `D-00` está `RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013
local-only`; evidências externas, capabilities, piloto e rollout permanecem pendentes.

---

# 15. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.13 | 2026-08-25 | Solicitante humano, proprietário declarado / Codex (IA), materialização | Registra `D-00 = RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`; permite backend/frontend/DDL/migrations/testes herméticos locais e mantém chamadas externas, Sandbox ASAAS, piloto BP Farias, produção, flags `ON` e efeitos reais bloqueados. |
| 1.12 | 2026-08-25 | Codex (IA), sob `AUTH-BILLING-2026-08-25-001` | Reconcilia capacidade/lifecycle/SoD/rollout com ADR-0042/ADR-0043/ADR-0050/ADR-0051; preserva a origem humana de `D-04.2-B`, identifica os sucessores delegados e mantém revisão humana `NOT_PERFORMED`/`OPEN`, evidências e `D-00` ativos. |
| 1.11 | 2026-08-25 | Codex (IA), sob `AUTH-BILLING-2026-08-25-001` | Reconcilia a decisão delegada `D-09`/ADR-0025: `PAYMENT_DELINQUENCY` usa o eixo separado `FINANCIAL_ACCESS_RESTRICTION`, nunca `RISK_RESTRICTION`; registra proveniência IA e preserva o freeze de implementação. |
| 1.10 | 2026-08-24 | Responsável pelo produto / Arquitetura | Registra ADR-0041 como decisão subsequente de `D-04.4-C`: `PROMOTIONAL_GRANT` só pode derivar do pacote atômico selecionado em `PromotionCombinationResult`; candidata rejeitada ou benefício destacado não contribui, e grant permanece sem valor monetário em best price; `D-04.4-D`, `D-04.4-E` e `D-00` seguem abertos. |
| 1.9 | 2026-08-24 | Responsável pelo produto / Arquitetura | Registra ADR-0040 como decisão subsequente de `D-04.4-B`: `PROMOTIONAL_GRANT` exige decisão `ELIGIBLE` e `EligibilityContextSnapshot` exatos; `INELIGIBLE`/`INDETERMINATE`, mera posse de cupom ou registro de promoção nunca criam contribuição; `D-04.4-C` a `D-04.4-E` e `D-00` permanecem abertos. |
| 1.8 | 2026-08-24 | Responsável pelo produto / Arquitetura | Registra ADR-0039 como decisão subsequente de `D-04.4-A`: `PROMOTIONAL_GRANT` só nasce de output não monetário explícito de `PromotionVersion` exata e permanece separado de benefícios monetários e crédito/saldo. |
| 1.7 | 2026-08-24 | Responsável pelo produto / Arquitetura | Registra ADR-0038 como decisão subsequente de `D-04.3` e preserva a separação entre fonte de entitlement, modelo de preço, promoção monetária e rating. |
| 1.6 | 2026-08-24 | Responsável pelo produto / Arquitetura | Registra ADR-0037 como decisão subsequente de `D-04.2-H`: contributions/lineage tipadas recebem placement em Billing e no store tenant-local, sem EAV genérico; `D-00` permanece aberto. |
| 1.5 | 2026-08-23 | Responsável pelo produto / Arquitetura | Registra ADR-0036 como decisão subsequente de `D-04.2-G`: entradas cache/LKG preservam lineage e somente `UNAVAILABLE` low-risk allowlisted pode usar LKG positivo; mantém `D-04.2-H`, `D-00` e implementação abertos. |
| 1.4 | 2026-08-23 | Responsável pelo produto / Arquitetura | Registra o ADR-0035 como decisão subsequente de `D-04.2-F`, mantendo failure/LKG, boundary físico e implementação abertos. |
| 1.3 | 2026-08-23 | Responsável pelo produto / Arquitetura | Registra o ADR-0034 como decisão subsequente de `D-04.2-E`, mantendo `D-04.2-F` a `D-04.2-H` e a implementação abertas. |
| 1.2 | 2026-08-23 | Responsável pelo produto / Arquitetura | Registra o ADR-0032 como decisão subsequente de `D-04.2-D`, mantendo `D-04.2-E` a `D-04.2-H` e a implementação abertas. |
| 1.1 | 2026-08-23 | Responsável pelo produto / Arquitetura | Registra o ADR-0030 como decisão subsequente de `D-04.2-C`, mantendo `D-04.2-D` a `D-04.2-H` e a implementação abertas. |
| 1.0 | 2026-08-23 | Responsável pelo produto / Arquitetura | Aceite de `D-04.2-B — opção A`: taxonomia tipada de direitos, add-ons, promoções, exceções e restrições; uso observado separado e override genérico proibido. |

---

# 16. Repository Structure

Esta decisão reside em:

```text
ADR-0029-taxonomia-tipificada-entitlements.md
```

Alvos físicos permanecem planejados e somente serão registrados após os gates.

---

# 17. Review Process

1. A opção A foi recomendada ao responsável pelo produto; as opções B e C ficam
   registradas como alternativas consideradas durante a materialização.
2. O responsável pelo produto registrou aprovação explícita da opção A em
   2026-08-23.
3. Arquitetura materializou somente taxonomia, invariantes e boundaries aprovados.
4. Mudança normativa exige nova versão aceita ou ADR sucessora.
5. Aprovações posteriores não podem ser inferidas deste documento.

---

# 18. Notes

Os nomes das naturezas são conceitos canônicos aprovados. Nomes físicos de enum,
tabela, classe, endpoint e mensagem permanecem abertos. A projeção futura poderá
usar estrutura diferente, desde que preserve as naturezas, lineage e proibições
desta decisão.

O AS-IS continua legado e não implementa este ADR.
