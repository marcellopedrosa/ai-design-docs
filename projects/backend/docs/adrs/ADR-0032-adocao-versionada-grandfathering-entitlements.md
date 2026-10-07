---
document_id: "ADR-0032"
primary_nature: "Decisao"
objective: "Definir como contratos já materializados adotam uma nova `EntitlementBundleVersion` sem catálogo vivo, fan-out, surpresa contratual ou perda de rastreabilidade."
scope: "Grandfathering de contratos canônicos, modos fechados de adoção, seleção de versão-alvo, revisão contratual e snapshot tenant-local, agendamento, cancelamento, compensação, coerência com preço e conteúdo mínimo de auditoria."
non_objectives: "Migrar tenants do modelo legado, definir upgrade/downgrade e efeitos sobre capacidade/dados, proration, notice period exato, renovação/cancelamento completos, pricing, metering/rating, DDL, OpenAPI, nomes físicos de classes/tabelas/eventos, alçadas finais, rollout ou autorizar implementação."
owner: "Arquitetura / Billing / Produto"
status: "Accepted"
date: "2026-08-25"
version: "1.7"
keywords: "entitlement adoption, grandfathering, pinned contract, renewal adoption, scheduled transition, exact version, contract revision, tenant-local snapshot, no latest, no fan-out"
related_files: "README.md, ../../../docs/specs/TP-00013-enterprise-billing-implementation-task-plan.md, ADR-0027-catalogo-global-faturamento-local.md, ADR-0028-entitlements-versionados-tenant-local.md, ADR-0029-taxonomia-tipificada-entitlements.md, ADR-0030-composicao-deterministica-enforcement-entitlements.md, ADR-0034-efeitos-transicao-nao-destrutiva-entitlements.md, ADR-0035-migracao-evidence-first-entitlements-legados.md, ADR-0036-cache-lkg-fail-safe-entitlements.md, ADR-0037-boundary-fisico-entitlements-billing.md, ADR-0038-pricing-tipado-moeda-cadencia.md"
code_references: "Estado legado em `Plan`, `SubscriptionPlan`, `TenantSettings`, `BillingApiAdapter` e fluxos atuais de subscription; boundary e destinos planejados sob `app/src/main/java/br/com/duoset/saas_service/contexts/billing/` definidos no ADR-0037, ainda não implementados."
principal_statement: "Contratos canônicos permanecem vinculados à versão e ao snapshot materializados; a adoção ocorre somente por política contratual fechada e versão-alvo exata, produzindo nova revisão e novo snapshot tenant-local auditável, nunca por `latest`, publicação, coorte ou mutação retroativa."
---

# ADR-0032 - Adoção versionada e grandfathering de entitlements

- Document ID: `ADR-0032`
- Primary Nature: `Decisao`
- Objective: Definir como contratos já materializados adotam uma nova `EntitlementBundleVersion` sem catálogo vivo, fan-out, surpresa contratual ou perda de rastreabilidade.
- Scope: Grandfathering de contratos canônicos, modos fechados de adoção, seleção de versão-alvo, revisão contratual e snapshot tenant-local, agendamento, cancelamento, compensação, coerência com preço e conteúdo mínimo de auditoria.
- Non-objectives: Migrar tenants do modelo legado, definir upgrade/downgrade e efeitos sobre capacidade/dados, proration, notice period exato, renovação/cancelamento completos, pricing, metering/rating, DDL, OpenAPI, nomes físicos de classes/tabelas/eventos, alçadas finais, rollout ou autorizar implementação.
- Keywords: entitlement adoption, grandfathering, pinned contract, renewal adoption, scheduled transition, exact version, contract revision, tenant-local snapshot, no latest, no fan-out
- Related Files: `docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00038-billing-catalog-pricing-promotions.md`, `docs/product/use-cases/UC-00039-billing-contract-subscription-amendments.md`, `docs/product/use-cases/UC-00040-billing-usage-rating-invoice-close.md`, `../../../docs/specs/TP-00013-enterprise-billing-implementation-task-plan.md`, `ADR-0027-catalogo-global-faturamento-local.md`, `ADR-0028-entitlements-versionados-tenant-local.md`, `ADR-0029-taxonomia-tipificada-entitlements.md`, `ADR-0030-composicao-deterministica-enforcement-entitlements.md`, `ADR-0034-efeitos-transicao-nao-destrutiva-entitlements.md`, `ADR-0035-migracao-evidence-first-entitlements-legados.md`, `ADR-0036-cache-lkg-fail-safe-entitlements.md`, `ADR-0037-boundary-fisico-entitlements-billing.md`, `ADR-0038-pricing-tipado-moeda-cadencia.md`
- Code References: Estado legado em `Plan`, `SubscriptionPlan`, `TenantSettings`, `BillingApiAdapter` e fluxos atuais de subscription; boundary e destinos planejados sob `app/src/main/java/br/com/duoset/saas_service/contexts/billing/` definidos no ADR-0037, ainda não implementados.
- Principal Decision: Contratos canônicos permanecem vinculados à versão e ao snapshot materializados; a adoção ocorre somente por política contratual fechada e versão-alvo exata, produzindo nova revisão e novo snapshot tenant-local auditável, nunca por `latest`, publicação, coorte ou mutação retroativa.
- Date: 2026-08-25
- Status: Accepted
- Version: 1.7
- Authors / Owners: Arquitetura / Billing / Produto
- Reviewers: Responsável pelo produto, com aprovação explícita de `D-04.2-D — opção A` em 2026-08-23; Arquitetura
- Stakeholders: Produto, Financeiro, Jurídico, Backend, Frontend, Segurança, Operações e tenants contratantes
- Supersedes: N/A; especializa o grandfathering que permaneceu aberto nos ADR-0027 a ADR-0030 e restringe fluxos automáticos conflitantes do ADR-0010.
- Superseded by: N/A

---

# 1. Context

O [ADR-0028](ADR-0028-entitlements-versionados-tenant-local.md) impede que publicar
uma nova versão global altere um contrato existente. Os
[ADR-0029](ADR-0029-taxonomia-tipificada-entitlements.md) e
[ADR-0030](ADR-0030-composicao-deterministica-enforcement-entitlements.md)
definem quais fontes entram na projeção e como elas são compostas. Faltava decidir
como um contrato já canônico poderia, legitimamente, sair da versão materializada
para outra versão.

Uma referência móvel como `latest`, um fan-out ao publicar catálogo ou uma regra
implícita de “todo tenant acompanha o plano atual” destruiria grandfathering,
reprodutibilidade e previsibilidade comercial. No extremo oposto, exigir sempre um
processo manual individual impediria renovação previamente acordada e campanhas de
transição controladas.

A decisão deve permitir evolução comercial sem reintroduzir catálogo vivo como
autoridade. Ela também deve distinguir adoção entre duas versões canônicas do
backfill dos enums/settings legados e separar o ato de escolher uma versão dos
efeitos de uma redução de capacidade.

---

# 2. Decision Statement

## 2.1 Escopo canônico e default de grandfathering

Esta decisão aplica-se somente a contratos que já possuem revisão contratual e
`ContractEntitlementSnapshot` canônicos. Cada revisão permanece vinculada à
identidade, versão e hash exatos da `EntitlementBundleVersion` materializada.

O default obrigatório é **`PINNED_UNTIL_EXPLICIT_AMENDMENT`**: o contrato conserva
seu snapshot até existir amendment explícito, aceito e efetivo. Ausência de policy,
dado ambíguo ou registro legado nunca é interpretada como adoção automática.

Tenants ainda representados apenas por `Plan`, `SubscriptionPlan`,
`TenantSettings`, overrides ou outros registros AS-IS não ganham snapshot por esta
decisão. Seu backfill, shadow comparison e cutover pertencem a `D-04.2-F`.

## 2.2 Modos fechados de adoção

A revisão contratual DEVE selar exatamente um dos seguintes modos conceituais:

1. **`PINNED_UNTIL_EXPLICIT_AMENDMENT`** — permanece na versão atual; adotar outra
   exige novo amendment e aceite explícito;
2. **`ADOPT_AT_RENEWAL`** — permitido somente quando a regra de adoção na renovação
   já fizer parte de termo aceito. Durante a preparação da renovação, o sistema
   resolve e sela uma versão-alvo exata, registra o diff e produz o preview/notice
   exigido pelo fluxo contratual; a execução nunca mantém referência móvel;
3. **`SCHEDULED_TRANSITION`** — permitido somente para versão-alvo e `effectiveAt`
   exatos, cobertos por aceite contratual específico e pela evidência de aprovação
   aplicável.

Os nomes são vocabulário conceitual aprovado, não nomes obrigatórios de enum, DTO,
tabela ou evento.

Não existe modo `AUTO_LATEST`, “seguir plano corrente”, adoção por acesso ao
catálogo, substituição administrativa direta ou política implícita por segmento.

## 2.3 Publicação, depreciação e coortes

Publicar uma nova `EntitlementBundleVersion` pode torná-la elegível para novos
quotes, contratos ou propostas. A publicação, por si só, NÃO DEVE:

- alterar revisão, snapshot, projeção, preço ou direito de contrato existente;
- criar um transition job por tenant;
- fazer fan-out para bancos de tenants;
- substituir a versão de contratos em renewal ainda não preparado.

Deprecar ou retirar uma versão de novas vendas pode impedir sua seleção para novos
contratos, mas não apaga sua definição nem invalida snapshots já materializados.
Segurança, abuso ou compliance emergencial usam `RISK_RESTRICTION`; não forçam
adoção disfarçada nem reescrevem contrato.

Uma coorte comercial pode selecionar candidatos e gerar ofertas, previews ou
transições propostas. A coorte nunca é autoridade de mutação. Cada contrato ainda
precisa satisfazer seu modo, termo aceito, versão exata e gates aplicáveis.

## 2.4 Intenção e execução da adoção

Toda adoção DEVE preservar conceitualmente:

- tenant e contrato;
- revisão e snapshot de origem, com identity/version/hash;
- versão-alvo exata e seu hash publicado;
- modo de adoção e causa;
- `effectiveAt` canônico;
- diff explicável de capabilities, tipos, operadores, modos e valores;
- referências de quote/amendment/renewal, termo aceito, notice e aprovação;
- actor, reason, correlation e idempotency identity;
- estado da transição e eventual referência compensatória.

No instante efetivo, uma adoção válida produz **nova revisão contratual** e
**novo `ContractEntitlementSnapshot` completo** no banco dedicado daquele tenant.
O snapshot anterior permanece imutável e historicamente resolvível. A
`EffectiveEntitlementProjection` é reconstruída a partir da nova autoridade; ela
não é editada para simular a mudança.

Replays com a mesma identidade lógica devem observar o mesmo resultado. Uma
origem diferente da revisão esperada, target/hash divergente ou duas intenções
incompatíveis não podem aplicar parcialmente a transição; o conflito deve ser
preservado para resolução explícita.

## 2.5 Atomicidade local e relação com preço

A ativação local da revisão, dos termos comerciais nela incluídos e do snapshot de
entitlement forma uma única fronteira de consistência tenant-local. Não pode haver
revisão nova com snapshot antigo nem snapshot novo associado à revisão anterior.

Adotar uma versão de entitlement **não altera preço implicitamente**. Conforme o
ADR-0038, quando preço e entitlement mudarem juntos, o mesmo amendment/revisão deve
declarar a `PriceVersion` por identidade/versão/hash exatos e a versão de
entitlement, preservar os snapshots anterior e novo e atribuir um `effectiveAt`
coerente. Nenhum dos dois resolve `latest`. A política de proration, notice,
cobrança e condição de ativação foi aceita em `D-05` no
[ADR-0044](ADR-0044-lifecycle-contratual-proration-assinaturas.md); contratos
executáveis podem avançar localmente sob `D-00`, enquanto evidências permanecem pendentes.

Não existe transação distribuída com ASAAS. Esta decisão não chama provider nem
torna status externo autoridade de entitlement. Eventual comando financeiro sai
somente após commit local por outbox e pelos estados aceitos no ADR-0044 e nos
[ADR-0023](ADR-0023-agnostic-payment-provider-integration.md) e
[ADR-0024](ADR-0024-seguranca-tokenizacao-cartao-recorrente.md), sem habilitar
capability enquanto faltarem os artefatos e as evidências exigidos.

## 2.6 Cancelamento, compensação e histórico

Uma transição ainda não efetiva pode ser cancelada conforme o lifecycle do
ADR-0044 e a autoridade do
[ADR-0050](ADR-0050-rbac-sod-aprovacoes-financeiras.md), sem apagar sua intenção,
aceite, motivo ou auditoria. Cancelamento é uma mudança de estado idempotente,
não exclusão física da evidência; o enforcement executável dessas regras permanece
pendente.

Depois do `effectiveAt`, desfazer a adoção exige nova revisão compensatória e novo
snapshot. O sistema nunca reabre, sobrescreve ou retrocede ponteiros na revisão já
efetiva.

Expiração de promoção, exceção ou ramp já materializada e effective-dated apenas
reavalia a projeção no instante previsto; isso não constitui adoção de outra
`EntitlementBundleVersion`.

## 2.7 Gate para transições redutoras ou incompatíveis

Esta decisão permite identificar, comparar e propor uma transição redutora ou
incompatível, mas não define sozinha seus efeitos. `D-04.2-E` foi posteriormente
aceita no [ADR-0034](ADR-0034-efeitos-transicao-nao-destrutiva-entitlements.md):
redução compatível preserva dados/ocupação e usa debt/policies/lease; qualquer
incompatibilidade ou evidência obrigatória ausente bloqueia a revisão inteira.

## 2.8 Boundary da aprovação

Esta decisão foi aprovada como `D-04.2-D — opção A`. Ela não remove o freeze do
TP-00013. Status vigente das decisões relacionadas:

- `D-04.2-E`: posteriormente aceita no ADR-0034 para upgrade/downgrade e efeitos
  sobre capacidade, operações e dados;
- `D-04.2-F`: posteriormente aceita no ADR-0035 para backfill, shadow,
  reconciliação e cutover do legado;
- `D-04.2-G`: posteriormente aceita no ADR-0036 para failure policy, cache
  derivado, LKG low-risk limitado, epochs, TTLs e degraded mode fail-safe;
- `D-04.2-H`: posteriormente aceita no ADR-0037 para ownership físico, APIs,
  ports/adapters, stores, migrations, tabelas, marker, outbox e cache;
- `D-04.4-D`: aceita por decisão humana explícita no ADR-0042;
- `D-04.4-E` a `D-14`: aceitas como `AI_DELEGATED`, por `AI_AGENT — Codex
  (OpenAI)` sob `AUTH-BILLING-2026-08-25-001`, com revisão humana substantiva
  `NOT_PERFORMED` e `Reviewability: OPEN`; os ADR-0043 a ADR-0051 e as revisões
  vigentes dos ADR-0023 a ADR-0025 são suas fontes canônicas;
- `D-13`: autoridade, RBAC, SoD, four-eyes e MFA estão definidos no ADR-0050;
- `D-14`: rollout, reconciliação, rollback e piloto estão definidos no ADR-0051,
  sem declarar targets medidos ou readiness comprovada;
- `D-00`: `RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`; DDL,
  OpenAPI, enforcement e testes herméticos locais são permitidos, sem effects/rollout.

---

# 3. Decision Drivers

- preservar confiança contratual e grandfathering por default;
- permitir evolução no renewal ou em transição programada previamente aceita;
- impedir dependência de `latest`, catálogo vivo, fan-out e ordem de execução;
- manter cada banco tenant-local como unidade de consistência;
- tornar diff, aceite, notice, causa e versão reconstruíveis;
- separar entitlement, preço, provider e dados operacionais;
- permitir retry e concorrência sem revisão ou snapshot parcialmente aplicados;
- manter o modelo utilizável antes de existir produção e legado massivo.

---

# 4. Considered Options

## Option A: Política versionada por contrato, com default pinned

Description: Cada contrato sela um modo fechado; adoção usa versão exata e produz
nova revisão/snapshot tenant-local.

Pros:

- equilibra estabilidade contratual e evolução programável;
- suporta amendment, renewal aceito e campanha agendada sem catálogo vivo;
- preserva histórico, idempotência e explicabilidade;
- evita fan-out implícito e long-lived `latest` pointers.

Cons:

- exige workflow de preview, aceite, agendamento e compensação;
- mantém mais de uma versão atendida durante o grandfathering;
- depende de contratos e testes por modo.

## Option B: Adotar automaticamente a versão corrente no renewal

Description: Todo contrato recebe a versão considerada corrente ao renovar,
independentemente de termo de adoção específico.

Pros:

- operação inicial menor;
- reduz a cauda de versões antigas.

Cons:

- cria surpresa contratual e pode reduzir direitos sem acordo suficiente;
- “corrente” pode mudar entre quote, notice e renewal;
- acopla renewal ao catálogo vivo;
- mistura adoção, downgrade, preço e efeitos em dados.

## Option C: Grandfathering perpétuo com opt-in individual por versão

Description: Nenhuma renovação ou campanha pode adotar uma versão sem novo opt-in
afirmativo individual, ainda que o contrato já contenha regra de adoção futura.

Pros:

- máxima estabilidade e consentimento explícito por mudança;
- modelo conceitual simples.

Cons:

- impede automação contratualmente acordada;
- produz longa cauda de versões e custo operacional crescente;
- dificulta correções e evolução uniforme de ofertas.

## Invalid alternative: adoção imediata ao publicar

Não é opção válida porque contradiz a imutabilidade do snapshot e a ausência de
fan-out aprovadas nos ADR-0027 e ADR-0028.

---

# 5. Decision Outcome

A **Option A** foi aceita.

O contrato é grandfathered por default. Evolução automática só existe no sentido
estrito de executar, no instante acordado, uma policy já aceita e uma versão exata
previamente selada. Nunca significa acompanhar `latest` ou herdar alterações do
catálogo.

---

# 6. Consequences

## Positive Consequences

- Contratos existentes não sofrem mudança por publicação ou depreciação.
- Renewal e campanhas podem evoluir ofertas sem mutação silenciosa.
- Toda adoção é reproduzível por source/target hash e `effectiveAt`.
- Preço e entitlement podem mudar coerentemente sem se confundirem.
- Cancelamento e rollback preservam histórico por compensação.

## Negative Consequences

- O runtime futuro precisará resolver múltiplas versões válidas em paralelo.
- Preview/diff e estados agendados aumentam o modelo contratual.
- Suporte e observabilidade devem explicar versões antigas e transições futuras.

## Neutral Consequences

- Nenhuma versão concreta, prazo de notice ou matriz de ofertas foi aprovada.
- Nenhum tenant legado foi migrado.
- Esta ADR original não autorizou efeito de downgrade; o ADR-0034 posteriormente
  fechou efeitos não destrutivos sem alterar o escopo de adoção daqui.
- Nenhum DDL, endpoint, evento ou package físico foi escolhido.

---

# 7. Impact

## Compatibility with prior decisions

| Decisão | Efeito desta ADR |
| --- | --- |
| ADR-0027 | Preserva catálogo global e uma transação por banco do tenant; coorte não faz fan-out autoritativo. |
| ADR-0028 | Mantém snapshot imutável; adoção cria outro snapshot em vez de editar o anterior. |
| ADR-0029 | Mudança contratual não substitui promoção, exceção ou restrição tipificada. |
| ADR-0030 | A nova projeção continua usando os tipos, operadores, estados e modos aprovados. |
| ADR-0010 | Upgrade implícito, reset de override e herança de default vivo permanecem não executáveis. |

## Ownership boundaries

- Catálogo publica versões; não decide adoção de um contrato existente.
- O contrato tenant-local e seu termo aceito autorizam a transição.
- Billing materializa revisão/snapshot e mantém a verdade comercial local.
- ASAAS executa somente capacidades financeiras posteriores por port neutro.
- Dados de produto e operações em voo seguem o ADR-0034.
- Legado e piloto sem snapshot canônico seguem o ADR-0035/`D-04.2-F`.
- Cache/LKG nunca altera adoção, revisão ou snapshot; o ADR-0036 limita
  `expiresAt` por `effectiveAt` e exige estado atual para mutações contratuais.

---

# 8. AI Agent Considerations (For Autonomous Agent Environments)

Agentes DEVEM:

- usar `PINNED_UNTIL_EXPLICIT_AMENDMENT` como default conceitual;
- exigir versão-alvo exata, termo aplicável e `effectiveAt` para renewal/schedule;
- criar nova revisão e snapshot; nunca editar o snapshot anterior;
- preservar diff, aceite, notice, aprovação, reason e correlation;
- aplicar debt/data policies/admission lease do ADR-0034 em reduções compatíveis e
  manter incompatibilidade bloqueada até remediação;
- aplicar o ADR-0035 à migração legada, o ADR-0036 a failure/cache/LKG e o
  ADR-0037 ao boundary físico, aplicando `D-00` somente ao escopo hermético local.

Agentes NÃO DEVEM:

- criar `latest`, fan-out, overwrite ou adoção por simples publicação;
- transformar coorte em autoridade contratual;
- repricing por inferência;
- usar migração de versão para contenção de segurança;
- migrar registros legados ou o piloto por esta decisão;
- implementar DDL, API, código, configuração ou provider a partir desta aprovação.

---

# 9. Implementation Plan

Sequência executável incremental, autorizada localmente por `D-00` e ainda sujeita
aos gates de artefatos/evidências aplicáveis:

1. implementar os contratos aceitos nos ADR-0034 a ADR-0037;
2. materializar lifecycle/proration/notice do ADR-0044 e controles/alçadas do
   ADR-0050;
3. congelar state machine conceitual e contrato OpenAPI;
4. definir modelo tenant-local aditivo para intent, revisão, snapshot e audit;
5. implementar preview/diff puro e determinístico;
6. implementar ativação tenant-local idempotente e outbox posterior;
7. provar concorrência, retry, cancelamento, compensação e isolamento;
8. executar shadow/cutover somente conforme o ADR-0035 e o rollout do ADR-0051.

Nenhum item dessa sequência está autorizado agora.

---

# 10. Validation

A implementação futura deverá provar ao menos:

- publicar/deprecar V2 não altera contrato/snapshot V1;
- contrato sem policy permanece pinned;
- renewal usa a versão exata selada no preparo, mesmo que V3 seja publicada depois;
- schedule não aceita target ou `effectiveAt` ausente;
- coorte gera proposta sem mutar contrato;
- replay da mesma transição não duplica revisão ou snapshot;
- intents concorrentes para a mesma revisão não produzem estado parcial;
- nova revisão e snapshot tornam-se efetivos juntos no banco de um tenant;
- tenant A nunca agenda ou materializa snapshot no banco do tenant B;
- adoção sem mudança de preço preserva o price snapshot;
- preço e entitlement conjuntos não ficam meio aplicados localmente;
- cancelamento pré-efeito preserva evidência e impede ativação;
- rollback pós-efeito cria revisão compensatória;
- redução compatível observa debt/policies/lease do ADR-0034 e incompatibilidade
  não ativa antes da remediação exigida;
- expiração de promoção/exceção não é tratada como adoção de bundle;
- nenhum fluxo consulta `latest`, default vivo ou ASAAS para decidir entitlement.

---

# 11. Risks and Mitigations

| Risk | Mitigation decidida ou boundary |
| --- | --- |
| Versão mudar entre preview e renewal | Target identity/version/hash exatos são selados antes do efeito. |
| Publicação alterar contratos | Ausência de fan-out e default pinned. |
| Campanha sobrescrever tenants | Coorte apenas propõe; contrato/policy autoriza cada transição. |
| Repricing silencioso | Entitlement não muda preço; alteração conjunta é explícita na mesma revisão. |
| Revisão e snapshot divergirem | Uma fronteira tenant-local de ativação; sem mutação parcial. |
| Retry duplicar contrato | Identidade idempotente e expected source revision. |
| Downgrade destruir dados | ADR-0034 preserva dados/ocupação, usa debt/policy e proíbe auto-delete. |
| Legado ganhar contrato inventado | ADR-0035 exige evidence-first, manifest exato, attestation e quarentena segura. |
| Falha de provider corromper entitlement | Nenhuma transação distribuída; provider não é autoridade. |
| Rollback apagar histórico | Nova revisão compensatória, nunca overwrite. |
| Cache/LKG atravessar `effectiveAt` ou autorizar adoção | ADR-0036 corta validade na boundary conhecida e proíbe LKG em mutação contratual/admin. |

---

# 12. Related ADRs

- [ADR-0000 - Governança documental](../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md)
- [ADR-0006 - Auditoria e compliance](ADR-0006-audit-compliance.md)
- [ADR-0010 - Parametrização de planos e limites](ADR-0010-tenant-plan-parametrization.md)
- [ADR-0019 - Database per tenant](ADR-0019-database-per-tenant.md)
- [ADR-0023 - Integração agnóstica de pagamentos](ADR-0023-agnostic-payment-provider-integration.md)
- [ADR-0027 - Catálogo global e faturamento tenant-local](ADR-0027-catalogo-global-faturamento-local.md)
- [ADR-0028 - Entitlements versionados tenant-local](ADR-0028-entitlements-versionados-tenant-local.md)
- [ADR-0029 - Taxonomia tipificada de entitlements](ADR-0029-taxonomia-tipificada-entitlements.md)
- [ADR-0030 - Composição determinística e enforcement](ADR-0030-composicao-deterministica-enforcement-entitlements.md)
- [ADR-0034 - Efeitos não destrutivos de transições](ADR-0034-efeitos-transicao-nao-destrutiva-entitlements.md)
- [ADR-0035 - Migração evidence-first do legado](ADR-0035-migracao-evidence-first-entitlements-legados.md)
- [ADR-0036 - Cache/LKG fail-safe de entitlements](ADR-0036-cache-lkg-fail-safe-entitlements.md)
- [ADR-0037 - Boundary físico e ownership de entitlements](ADR-0037-boundary-fisico-entitlements-billing.md)
- [ADR-0038 - Pricing tipado, moeda e cadência](ADR-0038-pricing-tipado-moeda-cadencia.md)

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

A aprovação explícita de 2026-08-23 alcança `D-04.2-D — opção A`, conforme a
alternativa recomendada apresentada imediatamente antes do aceite. `D-04.2-E` a
`D-04.3` foram posteriormente aceitas nos ADR-0034 a ADR-0038. `D-04.4-D` foi
aceita por decisão humana explícita no ADR-0042; `D-04.4-E` a `D-14` foram aceitas
como `AI_DELEGATED`, por `AI_AGENT — Codex (OpenAI)` sob
`AUTH-BILLING-2026-08-25-001`, com revisão humana `NOT_PERFORMED` e
`Reviewability: OPEN`. Essa conclusão decisória não comprova artefatos nem
readiness: `D-00` está `RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013
local-only`; implementação hermética local é permitida e evidências/readiness continuam pendentes.

---

# 15. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.7 | 2026-08-25 | Solicitante humano, proprietário declarado / Codex (IA), materialização | Registra `D-00 = RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`; permite backend/frontend/DDL/migrations/testes herméticos locais e mantém chamadas externas, Sandbox ASAAS, piloto BP Farias, produção, flags `ON` e efeitos reais bloqueados. |
| 1.6 | 2026-08-25 | Codex / Arquitetura | Reconcilia `D-04.4-D` humana e `D-04.4-E` a `D-14` `AI_DELEGATED` sob `AUTH-BILLING-2026-08-25-001`, aponta lifecycle e alçadas aos ADR-0044/ADR-0050/ADR-0051 e preserva `D-00`, artefatos e evidências como gates pendentes. |
| 1.5 | 2026-08-24 | Responsável pelo produto / Arquitetura | Registra ADR-0038 como decisão subsequente de `D-04.3`: alteração conjunta pina `PriceVersion` e entitlement por versões/hashes exatos, sem `latest` ou repricing implícito. |
| 1.4 | 2026-08-24 | Responsável pelo produto / Arquitetura | Registra ADR-0037 como decisão subsequente de `D-04.2-H`: revisions/snapshots imutáveis recebem placement tenant-local e transações/outbox definidos dentro de Billing; `D-00` continua aberto. |
| 1.3 | 2026-08-23 | Responsável pelo produto / Arquitetura | Registra ADR-0036 como decisão subsequente de `D-04.2-G`: cache/LKG não altera adoção, não atravessa boundaries conhecidas e não autoriza mutação contratual; mantém `D-04.2-H`, `D-00` e implementação abertos. |
| 1.2 | 2026-08-23 | Responsável pelo produto / Arquitetura | Registra o ADR-0035 como decisão subsequente de `D-04.2-F`, mantendo failure/LKG, boundary físico e implementação abertos. |
| 1.1 | 2026-08-23 | Responsável pelo produto / Arquitetura | Registra o ADR-0034 como decisão subsequente de `D-04.2-E`, mantendo `D-04.2-F` a `D-04.2-H` e a implementação abertas. |
| 1.0 | 2026-08-23 | Responsável pelo produto / Arquitetura | Aceite de `D-04.2-D — opção A`: grandfathering pinned por default, renewal/schedule somente sob termo aceito e versão exata, nova revisão/snapshot tenant-local, sem latest, fan-out ou repricing implícito. |

---

# 16. Repository Structure

Esta decisão reside em:

```text
ADR-0032-adocao-versionada-grandfathering-entitlements.md
```

Alvos físicos permanecem planejados e somente serão registrados após os gates.

---

# 17. Review Process

1. A opção A foi recomendada ao responsável pelo produto; as opções B e C foram
   apresentadas com custos, riscos e alternativa inválida.
2. O responsável pelo produto aprovou explicitamente a opção A em 2026-08-23.
3. Arquitetura materializou policy, invariantes, auditabilidade e boundaries.
4. Mudança normativa exige nova versão aceita ou ADR sucessora.
5. As aprovações subsequentes de `D-04.2-E`, `D-04.2-F`, `D-04.2-G` e
   `D-04.2-H` pertencem aos ADR-0034, ADR-0035, ADR-0036 e ADR-0037; decisões
   posteriores não podem ser inferidas daqui.
6. A reconciliação vigente registra `D-04.4-D` como `HUMAN_EXPLICIT` e
   `D-04.4-E` a `D-14` como `AI_DELEGATED` sob
   `AUTH-BILLING-2026-08-25-001`; nenhuma revisão humana substantiva dessas
   decisões delegadas foi realizada (`NOT_PERFORMED`), e a revisão permanece
   aberta (`OPEN`) sem apagar a origem de IA.

---

# 18. Notes

Os três modos de adoção são conceitos canônicos. A representação física segue o
ADR-0037 e pode refinar nomes internos nos implementation plans, desde que
preserve default, versão exata, aceite, atomicidade tenant-local, histórico e
proibições desta ADR.

O AS-IS continua legado e não implementa esta decisão.
