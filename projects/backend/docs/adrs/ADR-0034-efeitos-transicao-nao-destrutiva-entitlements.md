---
document_id: "ADR-0034"
primary_nature: "Decisao"
objective: "Definir os efeitos operacionais de upgrade, downgrade, remoção e incompatibilidade quando uma nova revisão/snapshot canônica de entitlement se torna efetiva."
scope: "Classificação de deltas, atomicidade da revisão, dívida de capacidade, preservação de dados, políticas por capability, operações em voo, admission lease conceitual, concorrência no cutoff, segmentação temporal, preview, revalidação e compensação."
non_objectives: "Migrar tenants ou enums legados, definir backfill/shadow/cutover, cache/last-known-good/degraded mode, boundary físico, DDL, OpenAPI, nomes finais de classes/tabelas/eventos, TTLs exatos, retention, pricing, billability, rating, proration, notice period, condição financeira de ativação, alçadas finais, rollout ou autorizar implementação."
owner: "Arquitetura / Billing / Produto / Segurança"
status: "Accepted"
date: "2026-08-25"
version: "1.5"
keywords: "entitlement transition, upgrade, downgrade, capacity debt, over limit, non destructive, data impact policy, admission lease, effective at, all or nothing, no retroactive billing"
related_files: "docs/product/requirements/REQ-00005-plan-feature-matrix.md`, `docs/product/requirements/REQ-00011-chatbot-usage-limits-and-billing.md`, `docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00038-billing-catalog-pricing-promotions.md`, `docs/product/use-cases/UC-00039-billing-contract-subscription-amendments.md`, `docs/product/use-cases/UC-00040-billing-usage-rating-invoice-close.md`, `docs/delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md`, `docs/adrs/ADR-0030-composicao-deterministica-enforcement-entitlements.md`, `docs/adrs/ADR-0032-adocao-versionada-grandfathering-entitlements.md`, `docs/adrs/ADR-0035-migracao-evidence-first-entitlements-legados.md`, `docs/adrs/ADR-0036-cache-lkg-fail-safe-entitlements.md`, `docs/adrs/ADR-0037-boundary-fisico-entitlements-billing.md"
code_references: "Estado legado em `Plan`, `SubscriptionPlan`, `TenantSettings`, listeners de consumo e fluxos atuais de subscription; boundary e destinos planejados sob `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/` definidos no ADR-0037, ainda não implementados."
principal_statement: "Uma transição canônica é classificada capability a capability e ativada como revisão indivisível; reduções preservam dados e ocupação existentes, representam excesso como dívida de capacidade, restringem apenas novos aumentos conforme o modo e permitem terminar uma operação já admitida por lease curta e versionada, sem reset, exclusão ou efeito financeiro retroativo."
---

# ADR-0034 - Efeitos não destrutivos de transições de entitlement

- Document ID: `ADR-0034`
- Primary Nature: `Decisao`
- Objective: Definir os efeitos operacionais de upgrade, downgrade, remoção e incompatibilidade quando uma nova revisão/snapshot canônica de entitlement se torna efetiva.
- Scope: Classificação de deltas, atomicidade da revisão, dívida de capacidade, preservação de dados, políticas por capability, operações em voo, admission lease conceitual, concorrência no cutoff, segmentação temporal, preview, revalidação e compensação.
- Non-objectives: Migrar tenants ou enums legados, definir backfill/shadow/cutover, cache/last-known-good/degraded mode, boundary físico, DDL, OpenAPI, nomes finais de classes/tabelas/eventos, TTLs exatos, retention, pricing, billability, rating, proration, notice period, condição financeira de ativação, alçadas finais, rollout ou autorizar implementação.
- Keywords: entitlement transition, upgrade, downgrade, capacity debt, over limit, non destructive, data impact policy, admission lease, effective at, all or nothing, no retroactive billing
- Related Files: `docs/product/requirements/REQ-00005-plan-feature-matrix.md`, `docs/product/requirements/REQ-00011-chatbot-usage-limits-and-billing.md`, `docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00038-billing-catalog-pricing-promotions.md`, `docs/product/use-cases/UC-00039-billing-contract-subscription-amendments.md`, `docs/product/use-cases/UC-00040-billing-usage-rating-invoice-close.md`, `docs/delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md`, `docs/adrs/ADR-0030-composicao-deterministica-enforcement-entitlements.md`, `docs/adrs/ADR-0032-adocao-versionada-grandfathering-entitlements.md`, `docs/adrs/ADR-0035-migracao-evidence-first-entitlements-legados.md`, `docs/adrs/ADR-0036-cache-lkg-fail-safe-entitlements.md`, `docs/adrs/ADR-0037-boundary-fisico-entitlements-billing.md`
- Code References: Estado legado em `Plan`, `SubscriptionPlan`, `TenantSettings`, listeners de consumo e fluxos atuais de subscription; boundary e destinos planejados sob `backend/src/main/java/br/com/duoset/saas_service/contexts/billing/` definidos no ADR-0037, ainda não implementados.
- Principal Decision: Uma transição canônica é classificada capability a capability e ativada como revisão indivisível; reduções preservam dados e ocupação existentes, representam excesso como dívida de capacidade, restringem apenas novos aumentos conforme o modo e permitem terminar uma operação já admitida por lease curta e versionada, sem reset, exclusão ou efeito financeiro retroativo.
- Date: 2026-08-25
- Status: Accepted
- Version: 1.5
- Authors / Owners: Arquitetura / Billing / Produto / Segurança
- Reviewers: Responsável pelo produto, com aprovação explícita de `D-04.2-E — opção A` em 2026-08-23; Arquitetura
- Stakeholders: Produto, Financeiro, Jurídico, Backend, Frontend, Segurança, Dados, Operações e tenants contratantes
- Supersedes: N/A; especializa os efeitos de transição deixados abertos no ADR-0032 e restringe fluxos destrutivos ou retroativos do ADR-0010.
- Superseded by: N/A

---

# 1. Context

O [ADR-0032](ADR-0032-adocao-versionada-grandfathering-entitlements.md) definiu
quando um contrato canônico pode adotar outra `EntitlementBundleVersion`, sempre
por target exato, nova revisão e novo snapshot. Ele bloqueou a ativação de
transições redutoras ou incompatíveis até existir uma decisão explícita sobre
recursos acima do novo limite, dados existentes e operações em voo.

Uma política que exigisse apagar dados antes do downgrade criaria risco operacional
e LGPD, além de tornar mudanças comerciais quase irreversíveis. Permitir o direito
antigo por um grace genérico, por outro lado, manteria duas autoridades simultâneas
e poderia conceder entitlement além do contrato efetivo. Cancelar toda operação no
instante de corte seria simples no modelo, mas interromperia trabalho que já havia
sido legitimamente admitido.

Esta decisão fecha esses efeitos apenas para contratos já canônicos. O legado,
inclusive BP Farias enquanto não possuir snapshot canônico, foi posteriormente
governado por `D-04.2-F`/[ADR-0035](ADR-0035-migracao-evidence-first-entitlements-legados.md).

---

# 2. Decision Statement

## 2.1 Escopo e pré-condição

Esta ADR não cria um novo caminho de adoção. Ela somente governa os efeitos de uma
transição cuja versão-alvo, revisão de origem, aceite e `effectiveAt` já sejam
válidos conforme o ADR-0032 e os gates contratuais aplicáveis.

Toda ativação é **all-or-nothing por revisão**: nenhuma capability, política de
dados, termo ou snapshot pode tornar-se efetivo isoladamente. Qualquer blocker
mantém a revisão anterior integralmente autoritativa.

## 2.2 Classificação fechada dos deltas

O diff determinístico DEVE classificar cada capability em exatamente uma categoria
conceitual:

- `ADD_OR_INCREASE`;
- `UNCHANGED`;
- `DECREASE`;
- `REMOVE`;
- `MODE_CHANGE`;
- `INCOMPATIBLE`.

`MODE_CHANGE` não presume direção. A comparação deve considerar tipo, operador,
valor, unidade, janela, dimensões, modo e policy de dados para determinar se o
efeito é não redutor, redutor compatível ou incompatível.

A revisão completa recebe exatamente uma classificação:

1. `NON_REDUCTIVE` — todos os deltas são neutros ou ampliativos;
2. `REDUCTIVE_COMPATIBLE` — existe redução/remoção/mudança restritiva, mas os
   efeitos podem ser preservados pelas regras desta ADR;
3. `INCOMPATIBLE_REQUIRES_REMEDIATION` — qualquer capability exige exportação,
   migração, transformação ou outra evidência antes do efeito.

Uma capability incompatível torna toda a revisão bloqueada; o sistema não aplica
somente a parte ampliativa.

## 2.3 Temporalidade e ausência de retroatividade

Uma transição `NON_REDUCTIVE` pode ser candidata a efeito imediato ou programado
somente conforme lifecycle e condição financeira que ainda serão aprovados em
`D-05`/`D-08`. Uma transição redutora é sempre prospectiva e usa o `effectiveAt`
exato da revisão aceita, com preview e notice exigidos pelo fluxo contratual.

Nenhuma transição:

- reclassifica operação, uso ou fatura anterior;
- cria débito, crédito ou overage retroativo;
- zera, transporta ou reabre contador por inferência;
- altera intervalo já fechado;
- apaga revisão, snapshot ou evidência anterior.

## 2.4 Dívida de capacidade não destrutiva

Quando a ocupação comprometida no instante efetivo exceder um novo limite finito,
os recursos existentes são preservados e o excesso é representado
conceitualmente como `overLimitBy`/dívida de capacidade.

Para uma capability em `HARD_LIMIT`:

- leitura, exportação e operações autorizadas que mantenham ou reduzam a ocupação
  podem continuar;
- uma operação que produza aumento líquido acima da capacidade é negada;
- liberar, remover ou reduzir ocupação diminui a dívida;
- atingir o novo limite encerra a dívida sem reset ou intervenção destrutiva.

Essas permissões continuam sujeitas a isolamento, RBAC, estado da capability,
integridade do domínio e `RISK_RESTRICTION`. Esta ADR não transforma leitura ou
exportação em bypass de segurança.

`UNLIMITED -> FINITE` usa a mesma regra. `FINITE -> UNLIMITED` vale somente para
novas admissões após o efeito e não gera crédito retroativo. `SOFT_LIMIT` e
`OVERAGE_ALLOWED` passam a operar prospectivamente no novo intervalo, sem tornar
o excesso histórico billable; metering, billability e rating permanecem em
`D-06`.

## 2.5 Política fechada de impacto em dados

Cada capability relevante à transição DEVE possuir exatamente uma policy
conceitual. Quando não houver dados ou configuração persistidos, a policy é
obrigatoriamente `NO_STORED_DATA`:

- `NO_STORED_DATA` — não existe estado persistido da capability a preservar;
- `PRESERVE_READ_ONLY` — dados permanecem legíveis/exportáveis, mas novas mutações
  específicas da capability são bloqueadas;
- `PRESERVE_DORMANT` — dados/configuração permanecem inativos e podem ser
  reativados futuramente somente se houver compatibilidade de schema;
- `EXPORT_REQUIRED_BEFORE_EFFECT` — a revisão não ativa antes da evidência de
  exportação exigida;
- `MIGRATION_REQUIRED_BEFORE_EFFECT` — a revisão não ativa antes da migração e
  validação exigidas.

Nenhuma policy autoriza auto-delete, truncamento, overwrite ou perda silenciosa.
Retenção e eliminação legítimas continuam em políticas próprias, nunca como efeito
implícito de downgrade.

Após `effectiveAt`, remoção/redução de `FLAG`, `SET` ou `LEVEL` bloqueia novas
invocações incompatíveis com o direito-alvo. Dados existentes seguem somente a
policy selada no preview/revisão.

## 2.6 Admission lease para operação já admitida

Uma operação admitida antes do cutoff pode terminar **uma única vez** sob uma
autorização curta, limitada e versionada, denominada conceitualmente `admission
lease`. Ela não constitui grace geral nem mantém o snapshot anterior disponível
para novas operações.

O lease deve preservar ao menos:

- tenant e operação lógica;
- revisão, snapshot, versão e hashes de origem;
- decision/policy hash e capability;
- unidades/reserva admitidas;
- `admittedAt` e `expiresAt` limitados;
- idempotency e correlation identities.

O prazo exato não é aprovado nesta ADR. Ele deve ser curto, bounded por tipo de
operação e incapaz de renovar-se implicitamente.

Operação apenas enfileirada, mas ainda não admitida, retry após expiração, nova
etapa de workflow ou nova recorrência usa o snapshot-alvo efetivo. Lease expirado
libera ou compensa a reserva de forma idempotente.

Tenant isolation, RBAC, `RISK_RESTRICTION` e controles de abuso continuam
prevalecendo. Uma restrição emergencial pode interromper ou negar continuação no
próximo checkpoint seguro. Se um efeito externo já foi irreversivelmente
confirmado, o sistema registra e executa compensação apropriada; não finge que o
efeito não ocorreu.

## 2.7 Concorrência no cutoff

A ativação futura deve usar conceitualmente generation/epoch, revisão de origem
esperada e compare-and-set equivalente. O marker, epochs, lease e famílias
físicas seguem o ADR-0037.

No cutoff:

- leases válidos de operações anteriormente admitidas podem terminar até sua
  expiração;
- toda nova admissão usa exclusivamente a revisão/snapshot-alvo;
- target/hash ou source revision divergente bloqueia a ativação;
- intents concorrentes incompatíveis não produzem estado parcial;
- nenhum lease, reserva ou decisão de um tenant pode ser observado por outro.

## 2.8 Contadores, uso e intervalos

Contadores e `USAGE_OBSERVATION` não são entitlements e não são zerados, movidos ou
recalculados pela transição. Um período que cruza `effectiveAt` é segmentado por
revisão e intervalo efetivo, preservando lineage suficiente para `D-06` decidir
rating e eventual proration.

Mudança `SOFT_LIMIT -> HARD_LIMIT`, ou outra mudança de modo, não reclassifica
admissões e uso passados nem reabre invoice. Somente admissões posteriores ao
cutoff observam o novo modo, ressalvado o lease exato já emitido.

## 2.9 Preview, revalidação e drift

Antes do aceite/agendamento, o preview deve apresentar, sem efeito de runtime:

- diff semântico e classificação de cada capability e da revisão;
- ocupação, uso, reservas e leases relevantes no instante observado;
- dívida de capacidade projetada;
- capabilities removidas ou com modo alterado;
- policy de dados e dados/configurações impactados;
- operações em voo potencialmente afetadas;
- source/target identities, versions e hashes, além de `effectiveAt`;
- blockers, evidências exigidas e caminho de compensação.

No instante efetivo, a ativação revalida a source revision, target/hash,
pré-condições, evidências e blockers. Drift material suspende a ativação sem aplicar
parte da revisão. Um novo preview/aceite é exigido quando a mudança invalidar a
evidência contratual ou operacional anterior.

## 2.10 Cancelamento e compensação

Cancelamento antes do efeito segue o ADR-0032 e preserva toda evidência. Depois do
efeito, retorno ao conteúdo anterior exige nova revisão compensatória, novo
snapshot e novo preview. Pointer rollback, overwrite e reabertura da revisão
efetiva permanecem proibidos.

## 2.11 Boundary da aprovação

Esta decisão foi aprovada como `D-04.2-E — opção A`. Ela não remove o freeze do
TP-00013. Situação das dependências:

- `D-04.2-F`: posteriormente aceita no ADR-0035 para inventário, backfill, shadow,
  reconciliação e cutover do legado, inclusive BP Farias;
- `D-04.2-G`: posteriormente aceita no ADR-0036 para failure policy, cache
  derivado, LKG low-risk limitado, epochs, TTLs e degraded mode fail-safe;
- `D-04.2-H`: posteriormente aceita no ADR-0037 para ownership físico, APIs,
  ports/adapters, stores, migrations, tabelas, marker, outbox e cache;
- `D-05`: lifecycle, renewal, amendment, notice, proration e cancelamento;
- `D-06`: metering, billability, rating, preço e fechamento financeiro;
- `D-08`: condição de pagamento/settlement que autoriza efeito financeiro;
- `D-13`: RBAC, SoD, four-eyes, MFA e alçadas;
- `D-14`: rollout, piloto, observabilidade e rollback operacional;
- `D-00`: `RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`; autoriza
  implementação/testes herméticos locais, sem effect/rollout.

---

# 3. Decision Drivers

- impedir que downgrade destrua dados ou configuração do tenant;
- evitar duas autoridades de entitlement durante um grace genérico;
- concluir com segurança trabalho legitimamente admitido antes do cutoff;
- tornar redução previsível mesmo quando a ocupação já excede o target;
- preservar isolamento, RBAC, risco, idempotência e auditabilidade;
- impedir cobrança, crédito ou reclassificação retroativa por inferência;
- manter a revisão/snapshot tenant-local como unidade de consistência;
- separar efeitos operacionais de lifecycle, rating, provider e migração legada.

---

# 4. Considered Options

## Option A: Transição effective-dated não destrutiva

Description: Classifica deltas por capability, representa excesso como dívida de
capacidade, preserva dados por policy fechada e permite concluir apenas operações
já admitidas por lease curta/versionada.

Pros:

- preserva dados e reduz interrupção sem manter entitlement antigo para novas
  operações;
- suporta downgrade quando a ocupação está acima do target;
- fornece cutoff determinístico, auditável e testável;
- mantém rating e provider fora da autoridade operacional;
- evita rollback destrutivo.

Cons:

- exige preview, revalidação, dívida de capacidade e leases idempotentes;
- operações longas precisam de checkpoint/compensação explícitos;
- cada capability precisa declarar sua policy de impacto em dados.

## Option B: Cutover estrito e conformidade prévia

Description: No cutoff, todas as operações revalidam ou são canceladas; a redução
só ativa quando ocupação e dados já estiverem integralmente compatíveis.

Pros:

- menor quantidade de estados transitórios;
- runtime posterior observa apenas o target.

Cons:

- interrompe trabalho legitimamente admitido;
- torna downgrade inviável para tenants acima da capacidade;
- incentiva exclusão ou intervenção manual para obter conformidade;
- aumenta tickets, tempo operacional e risco de perda.

## Option C: Dual snapshot com grace mais permissivo

Description: Durante um grace, cada decisão usa o resultado mais permissivo entre
snapshot antigo e novo.

Pros:

- experiência aparentemente suave;
- reduz bloqueios imediatos.

Cons:

- cria duas autoridades e entitlement leak;
- torna billing, auditoria e suporte ambíguos;
- complica cache, rollback, segurança e término do grace;
- pode conceder capacidade que o contrato efetivo já não prevê.

---

# 5. Decision Outcome

A **Option A** foi aceita.

Uma redução altera prospectivamente novas admissões, mas não apaga o passado nem
transforma ocupação existente em violação destrutiva. A exceção temporal é
estritamente a operação já admitida e vinculada ao lease exato, nunca um grace por
tenant, usuário ou versão.

---

# 6. Consequences

## Positive Consequences

- Downgrade não exige auto-delete nem reset de uso.
- O excesso existente converge por dívida de capacidade observável.
- Cutoff diferencia operação admitida de mera fila ou retry.
- Revisão incompatível não fica parcialmente aplicada.
- Dados removidos de uma capability têm tratamento explícito.
- Intervalos e faturamento histórico permanecem reproduzíveis.

## Negative Consequences

- O modelo futuro terá estados de debt, blockers, leases e compensações.
- Preview exige leitura consistente de ocupação/reservas sem virar autoridade viva.
- Operações longas precisam definir unidade de admissão e checkpoint seguro.

## Neutral Consequences

- Nenhum limite, modo por plano, TTL ou prazo de notice foi escolhido.
- Nenhuma política de preço/overage ou proration foi aprovada.
- Nenhum tenant legado foi materializado ou migrado.
- Nenhum nome de tabela, DTO, endpoint, evento ou package foi aprovado.

---

# 7. Impact

## Compatibility with prior decisions

| Decisão | Efeito desta ADR |
| --- | --- |
| ADR-0028 | Mantém o snapshot tenant-local imutável como autoridade; a projeção local permanece apenas um read model derivado e reconstruível usado na avaliação operacional. |
| ADR-0029 | `RISK_RESTRICTION` permanece separada e dominante; uso continua não sendo entitlement. |
| ADR-0030 | Usa tipos, operadores, estados e modos fechados para classificar o diff. |
| ADR-0032 | Especializa somente os efeitos da adoção; target, revisão, aceite e compensação continuam válidos. |
| ADR-0010 | Invalida DELETE/reset, `NULL=UNLIMITED`, propagação e cobrança retroativa como caminho de downgrade. |
| ADR-0023 | Provider não admite operações nem decide entitlement; efeitos financeiros continuam posteriores. |

## Ownership boundaries

- Billing tenant-local mantém revisão, snapshot, transição e evidência contratual.
- O bounded context dono do recurso informa ocupação e executa operações permitidas
  por contrato futuro, sem tornar-se autoridade comercial.
- Segurança/Risco pode restringir operação, sem reescrever contrato.
- ASAAS não calcula debt, não emite lease e não escolhe policy de dados.
- Migração do AS-IS segue exclusivamente o ADR-0035/`D-04.2-F`.
- Cache/LKG segue o ADR-0036: não cria, renova ou amplia admission lease; quota,
  capacidade, custo e risco exigem estado atual, e `riskEpoch` corrente domina.

---

# 8. AI Agent Considerations (For Autonomous Agent Environments)

Agentes DEVEM:

- tratar a revisão inteira como indivisível;
- preservar dados e representar excesso como dívida de capacidade;
- distinguir operação admitida de fila, retry, nova etapa ou recorrência;
- manter lease curta, exata, tenant-scoped e incapaz de renovar implicitamente;
- aplicar RBAC, tenant isolation e `RISK_RESTRICTION` também durante lease;
- segmentar intervalos sem reset ou efeito financeiro retroativo;
- bloquear drift, incompatibilidade e evidência obrigatória ausente;
- aplicar o ADR-0035 à migração legada, o ADR-0036 a failure/cache/LKG e o
  ADR-0037 ao boundary físico, aplicando `D-00` somente ao escopo hermético local.

Agentes NÃO DEVEM:

- apagar recursos, configurações, uso, reservas ou snapshots por downgrade;
- usar max(old,new), grace geral ou fallback para versão antiga;
- permitir nova operação sob lease emitida para outra operação;
- inferir billability, preço, crédito ou proration;
- aplicar somente capabilities ampliativas de uma revisão bloqueada;
- migrar BP Farias ou qualquer registro legado por esta decisão;
- criar DDL, API, enum, evento, cache ou código com base apenas nesta aprovação.

---

# 9. Implementation Plan

Sequência futura, ainda bloqueada:

1. aplicar os ADR-0035, ADR-0036 e ADR-0037 e concluir as decisões
   `D-05`/`D-06`/`D-08` aplicáveis;
2. congelar state machine, contrato OpenAPI, ownership e alçadas;
3. definir contrato puro de semantic diff e data impact policy;
4. definir leitura consistente de ocupação/reservas e cálculo de debt;
5. implementar preview e activation revalidation determinísticos;
6. implementar admission/lease/confirm/expire/compensate tenant-local;
7. provar cutoff concorrente, ausência de mixed revision e isolamento;
8. implementar migração hermética sob `D-00` e executar piloto/rollout somente
   conforme `D-04.2-F`/`D-14` e autorização operacional própria.

Itens herméticos locais estão autorizados; chamadas externas, piloto, produção,
flags `ON` e efeitos reais permanecem bloqueados.

---

# 10. Validation

A implementação futura deverá provar ao menos:

- 47 recursos sob target 3 preservam 47, registram debt 44, permitem
  leitura/exportação/redução e negam o 48º aumento em hard limit;
- `UNLIMITED -> FINITE(100)` com ocupação 120 produz debt 20 sem exclusão;
- `FINITE -> UNLIMITED` não cria crédito nem reabre período anterior;
- operação admitida antes do cutoff termina uma vez dentro do lease;
- operação apenas enfileirada, retry expirado e nova recorrência usam o target;
- lease não atravessa tenant, revisão, capability, unidade ou idempotency identity;
- remoção de `FLAG`/`SET`/`LEVEL` nega nova invocação e preserva dados conforme a
  policy selada;
- `EXPORT_REQUIRED_BEFORE_EFFECT` e `MIGRATION_REQUIRED_BEFORE_EFFECT` bloqueiam a
  revisão inteira até evidência válida;
- capability incompatível impede ativação parcial das demais;
- `SOFT_LIMIT -> HARD_LIMIT` não reclassifica uso nem fatura passada;
- período cruzando `effectiveAt` preserva dois segmentos e lineage;
- source revision ou target hash divergente bloqueia sem estado parcial;
- `RISK_RESTRICTION`, RBAC e tenant isolation não são ignorados pelo lease;
- retorno pós-efeito cria revisão/snapshot compensatórios.

---

# 11. Risks and Mitigations

| Risk | Mitigation decidida ou boundary |
| --- | --- |
| Debt virar permissão ilimitada | Hard limit nega aumento líquido; debt reduz conforme ocupação cai. |
| Lease virar grace permanente | Lease é por operação, bounded, não renovável implicitamente e expira. |
| Cutoff observar versões misturadas | Expected revision, generation/epoch e ativação all-or-nothing. |
| Downgrade apagar dados | Closed data policies sem auto-delete. |
| Incompatibilidade ficar parcialmente aplicada | Um blocker impede a revisão inteira. |
| Segurança ser contornada por operação antiga | RBAC, isolation e risk continuam dominantes em checkpoints seguros. |
| Uso passado virar overage | Segmentação prospectiva; D-06 decide rating sem reclassificação implícita. |
| Preview envelhecer antes do efeito | Revalidação e drift block no `effectiveAt`. |
| BP Farias receber regra inventada | ADR-0035 exige attestation, manifest exato, shadow e quarentena segura. |
| Provider virar autoridade de cutoff | ASAAS permanece fora de entitlement/admission. |
| LKG antigo ampliar lease, quota ou debt | ADR-0036 proíbe LKG para quota/capacidade e impede criar/renovar lease; risco atual domina. |

---

# 12. Related ADRs

- [ADR-0000 - Governança documental](../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md)
- [ADR-0006 - Auditoria e compliance](ADR-0006-audit-compliance.md)
- [ADR-0010 - Parametrização de planos e limites](ADR-0010-tenant-plan-parametrization.md)
- [ADR-0019 - Database per tenant](ADR-0019-database-per-tenant.md)
- [ADR-0023 - Integração agnóstica de pagamentos](ADR-0023-agnostic-payment-provider-integration.md)
- [ADR-0028 - Entitlements versionados tenant-local](ADR-0028-entitlements-versionados-tenant-local.md)
- [ADR-0029 - Taxonomia tipificada de entitlements](ADR-0029-taxonomia-tipificada-entitlements.md)
- [ADR-0030 - Composição determinística e enforcement](ADR-0030-composicao-deterministica-enforcement-entitlements.md)
- [ADR-0032 - Adoção versionada e grandfathering](ADR-0032-adocao-versionada-grandfathering-entitlements.md)
- [ADR-0035 - Migração evidence-first do legado](ADR-0035-migracao-evidence-first-entitlements-legados.md)
- [ADR-0036 - Cache/LKG fail-safe de entitlements](ADR-0036-cache-lkg-fail-safe-entitlements.md)
- [ADR-0037 - Boundary físico e ownership de entitlements](ADR-0037-boundary-fisico-entitlements-billing.md)

---

# 13. References

- [REQ-00005 - Matriz de funcionalidades por plano](../product/requirements/REQ-00005-plan-feature-matrix.md)
- [REQ-00011 - Limites de uso e billing do chatbot](../product/requirements/REQ-00011-chatbot-usage-limits-and-billing.md)
- [REQ-00042 - Billing enterprise](../product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md)
- [UC-00038 - Catálogo, pricing e promoções](../product/use-cases/UC-00038-billing-catalog-pricing-promotions.md)
- [UC-00039 - Contratos, assinaturas e amendments](../product/use-cases/UC-00039-billing-contract-subscription-amendments.md)
- [UC-00040 - Uso, rating e fechamento](../product/use-cases/UC-00040-billing-usage-rating-invoice-close.md)
- [TP-00013 - Enterprise Billing Implementation](../delivery/plans/TP-00013-enterprise-billing-implementation-task-plan.md)
- [Manifesto de módulos](../architecture/module-registry.md)

---

# 14. Decision Lifecycle

Current State: **Accepted**

A aprovação explícita de 2026-08-23 alcança `D-04.2-E — opção A`, conforme a
alternativa recomendada apresentada imediatamente antes do aceite. `D-04.2-F` foi
posteriormente aceita no ADR-0035, `D-04.2-G` no ADR-0036 e `D-04.2-H` no
ADR-0037. As decisões posteriores foram fechadas nos ADR-0038 a ADR-0051 e nas
revisões vigentes dos ADR-0023 a ADR-0025; elas não mudam a origem humana desta
ADR. DDL, OpenAPI, implementação e testes herméticos locais estão liberados por
`D-00`; evidências externas e readiness permanecem pendentes.

---

# 15. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.5 | 2026-08-25 | Solicitante humano, proprietário declarado / Codex (IA), materialização | Registra `D-00 = RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`; permite backend/frontend/DDL/migrations/testes herméticos locais e mantém chamadas externas, Sandbox ASAAS, piloto BP Farias, produção, flags `ON` e efeitos reais bloqueados. |
| 1.4 | 2026-08-25 | Codex / Arquitetura | Reconcilia o lifecycle com D-05 a D-14 decision-complete nos ADRs sucessores, preserva a origem humana de D-04.2-E e mantém D-00, artefatos executáveis e evidências como gates. |
| 1.3 | 2026-08-24 | Responsável pelo produto / Arquitetura | Registra ADR-0037 como decisão subsequente de `D-04.2-H`: capacity debt e admission lease recebem placement tenant-local, marker/epochs/CAS e outbox definidos dentro de Billing; reserva definitiva de quota continua em `D-06` e implementação em `D-00`. |
| 1.2 | 2026-08-23 | Responsável pelo produto / Arquitetura | Registra ADR-0036 como decisão subsequente de `D-04.2-G`: cache/LKG não cria ou renova lease, quota/capacidade exige estado atual e risco domina; mantém `D-04.2-H`, `D-00` e implementação abertos. |
| 1.1 | 2026-08-23 | Responsável pelo produto / Arquitetura | Registra o ADR-0035 como decisão subsequente de `D-04.2-F`, mantendo failure/LKG, boundary físico e implementação abertos. |
| 1.0 | 2026-08-23 | Responsável pelo produto / Arquitetura | Aceite de `D-04.2-E — opção A`: classificação all-or-nothing, dívida de capacidade não destrutiva, policies de dados sem auto-delete, admission lease bounded, cutoff versionado, segmentação prospectiva e revalidação contra drift. |

---

# 16. Repository Structure

Esta decisão reside em:

```text
docs/adrs/ADR-0034-efeitos-transicao-nao-destrutiva-entitlements.md
```

Os alvos físicos estão registrados no ADR-0037 e podem ser materializados
incrementalmente no escopo local-only de `D-00`.

---

# 17. Review Process

1. A opção A foi recomendada ao responsável pelo produto; opções de cutover
   estrito e dual-snapshot grace foram apresentadas com custos e riscos.
2. O responsável pelo produto aprovou explicitamente a opção A em 2026-08-23.
3. Arquitetura materializou classificação, preservação, cutoff, segurança e
   boundaries sem autorizar implementação.
4. Mudança normativa exige nova versão aceita ou ADR sucessora.
5. As aprovações subsequentes de `D-04.2-F`, `D-04.2-G` e `D-04.2-H` pertencem
   aos ADR-0035, ADR-0036 e ADR-0037; decisões posteriores não podem ser
   inferidas deste documento.

---

# 18. Notes

Os nomes de classificações, policies e lease são vocabulário conceitual. Sua
representação física segue o ADR-0037; o contrato OpenAPI final continua pendente
dos planos e gates aplicáveis.

O AS-IS continua legado e não implementa esta decisão.
