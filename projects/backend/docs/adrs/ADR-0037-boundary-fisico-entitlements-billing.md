---
document_id: "ADR-0037"
primary_nature: "Decisao"
objective: "Definir o módulo, as APIs públicas, o layout interno, os adapters, os stores, as migrations, as famílias de tabelas, o marker de autoridade, a publicação transacional e o cache derivados do modelo canônico de entitlements."
scope: "Boundary Spring Modulith, Clean Architecture, packages planejados, APIs Java públicas, ports/adapters, catálogo seller-owned global, persistência tenant-local, migrations Flyway, tabelas-alvo, marker de cutover, transações, outbox, Redis, isolamento multitenant, jobs e condições para extração futura."
non_objectives: "Implementar código, DDL, migration, endpoint HTTP, OpenAPI, Redis, evento ou integração; autorizar execução; definir campos finais de DTO/DDL/evento, pricing, rating, invoice, cobrança, provider, lifecycle, reservas de quota definitivas, RBAC/SoD/MFA, SLO, rollout ou operação ASAAS."
owner: "Arquitetura / Billing / Produto / Segurança / Dados / Operações"
status: "Accepted"
date: "2026-08-25"
version: "1.4"
keywords: "entitlement boundary, Spring Modulith, Billing, Clean Architecture, ports and adapters, platform datasource, tenant database, Flyway, outbox, cutover marker, Redis, TenantScopeGuard, BP Farias"
related_files: "README.md, ../../../docs/specs/TP-00013-enterprise-billing-implementation-task-plan.md, ADR-0027-catalogo-global-faturamento-local.md, ADR-0028-entitlements-versionados-tenant-local.md, ADR-0029-taxonomia-tipificada-entitlements.md, ADR-0030-composicao-deterministica-enforcement-entitlements.md, ADR-0032-adocao-versionada-grandfathering-entitlements.md, ADR-0034-efeitos-transicao-nao-destrutiva-entitlements.md, ADR-0035-migracao-evidence-first-entitlements-legados.md, ADR-0036-cache-lkg-fail-safe-entitlements.md, ADR-0038-pricing-tipado-moeda-cadencia.md"
code_references: "AS-IS em `app/src/main/java/br/com/duoset/saas_service/contexts/billing/package-info.java`, `app/src/main/java/br/com/duoset/saas_service/contexts/billing/BillingApi.java`, `app/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/`, `app/src/main/java/br/com/duoset/saas_service/config/persistence/PlatformDataSourceConfig.java`, `app/src/main/java/br/com/duoset/saas_service/config/persistence/TenantDataSourceConfig.java`, `app/src/main/java/br/com/duoset/saas_service/config/persistence/routing/TenantRoutingDataSource.java`, `app/src/main/java/br/com/duoset/saas_service/config/persistence/routing/TenantDatabaseRegistry.java` e `app/src/main/resources/db/migration/billing/`; todos os packages, APIs, adapters, migrations, tabelas, eventos e keyspaces de entitlement desta ADR são destinos planejados e ainda não existem."
principal_statement: "Entitlements permanece um subdomínio coeso no único módulo `contexts.billing`, sem novo módulo, serviço ou banco físico. APIs públicas estreitas protegem o boundary; adapters separados usam o datasource de plataforma para catálogo global e o banco dedicado de cada tenant para autoridade operacional; cache Redis é derivado, e nenhuma operação tenant-local começa sem escopo de tenant validado."
---

# ADR-0037 - Boundary físico e ownership de entitlements em Billing

- Document ID: `ADR-0037`
- Primary Nature: `Decisao`
- Objective: Definir o módulo, as APIs públicas, o layout interno, os adapters, os stores, as migrations, as famílias de tabelas, o marker de autoridade, a publicação transacional e o cache derivados do modelo canônico de entitlements.
- Scope: Boundary Spring Modulith, Clean Architecture, packages planejados, APIs Java públicas, ports/adapters, catálogo seller-owned global, persistência tenant-local, migrations Flyway, tabelas-alvo, marker de cutover, transações, outbox, Redis, isolamento multitenant, jobs e condições para extração futura.
- Non-objectives: Implementar código, DDL, migration, endpoint HTTP, OpenAPI, Redis, evento ou integração; autorizar execução; definir campos finais de DTO/DDL/evento, pricing, rating, invoice, cobrança, provider, lifecycle, reservas de quota definitivas, RBAC/SoD/MFA, SLO, rollout ou operação ASAAS.
- Keywords: entitlement boundary, Spring Modulith, Billing, Clean Architecture, ports and adapters, platform datasource, tenant database, Flyway, outbox, cutover marker, Redis, TenantScopeGuard, BP Farias
- Related Files: `docs/architecture/module-registry.md`, `docs/product/requirements/REQ-00005-plan-feature-matrix.md`, `docs/product/requirements/REQ-00011-chatbot-usage-limits-and-billing.md`, `docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`, `docs/product/use-cases/UC-00038-billing-catalog-pricing-promotions.md`, `docs/product/use-cases/UC-00039-billing-contract-subscription-amendments.md`, `docs/product/use-cases/UC-00040-billing-usage-rating-invoice-close.md`, `../../../docs/specs/TP-00013-enterprise-billing-implementation-task-plan.md`, `ADR-0027-catalogo-global-faturamento-local.md`, `ADR-0028-entitlements-versionados-tenant-local.md`, `ADR-0029-taxonomia-tipificada-entitlements.md`, `ADR-0030-composicao-deterministica-enforcement-entitlements.md`, `ADR-0032-adocao-versionada-grandfathering-entitlements.md`, `ADR-0034-efeitos-transicao-nao-destrutiva-entitlements.md`, `ADR-0035-migracao-evidence-first-entitlements-legados.md`, `ADR-0036-cache-lkg-fail-safe-entitlements.md`, `ADR-0038-pricing-tipado-moeda-cadencia.md`
- Code References: AS-IS em `app/src/main/java/br/com/duoset/saas_service/contexts/billing/package-info.java`, `app/src/main/java/br/com/duoset/saas_service/contexts/billing/BillingApi.java`, `app/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/`, `app/src/main/java/br/com/duoset/saas_service/config/persistence/PlatformDataSourceConfig.java`, `app/src/main/java/br/com/duoset/saas_service/config/persistence/TenantDataSourceConfig.java`, `app/src/main/java/br/com/duoset/saas_service/config/persistence/routing/TenantRoutingDataSource.java`, `app/src/main/java/br/com/duoset/saas_service/config/persistence/routing/TenantDatabaseRegistry.java` e `app/src/main/resources/db/migration/billing/`; todos os packages, APIs, adapters, migrations, tabelas, eventos e keyspaces de entitlement desta ADR são destinos planejados e ainda não existem.
- Principal Decision: Entitlements permanece um subdomínio coeso no único módulo `contexts.billing`, sem novo módulo, serviço ou banco físico. APIs públicas estreitas protegem o boundary; adapters separados usam o datasource de plataforma para catálogo global e o banco dedicado de cada tenant para autoridade operacional; cache Redis é derivado, e nenhuma operação tenant-local começa sem escopo de tenant validado.
- Date: 2026-08-25
- Status: Accepted
- Version: 1.4
- Authors / Owners: Arquitetura / Billing / Produto / Segurança / Dados / Operações
- Reviewers: Responsável pelo produto, com aprovação explícita de `D-04.2-H — Opção A` em 2026-08-24; Arquitetura
- Stakeholders: Produto, Financeiro, Jurídico, Backend, Frontend, Segurança, Dados, Operações e tenants contratantes
- Supersedes: N/A; fecha o boundary físico deixado aberto pelos ADR-0010, ADR-0027, ADR-0028, ADR-0029, ADR-0030, ADR-0032, ADR-0034, ADR-0035 e ADR-0036.
- Superseded by: N/A

---

# 1. Context

As decisões `D-04.2-A` a `D-04.2-G` fixaram autoridade, taxonomia, composição,
adoção, transições, migração legada e comportamento fail-safe de entitlements.
Faltava localizar fisicamente essas regras sem criar um segundo domínio comercial,
uma dependência cíclica ou uma autoridade global sobre dados tenant-scoped.

O estado atual relevante é:

- o monólito possui treze módulos Spring Modulith registrados;
- `contexts.billing` já é um módulo único, com raiz pública e implementação sob
  `internal/` organizada por camadas;
- `BillingApi.hasAvailableQuota(...)` reduz decisão a `boolean` e não representa
  estado indeterminado, freshness, lineage, revision, hash ou epochs;
- o datasource de plataforma existente está fisicamente no banco atualmente
  denominado `saas_tenant` e já possui transaction manager próprio;
- `TenantRoutingDataSource` usa o banco dedicado quando há contexto, mas pode
  alcançar o datasource compartilhado/default quando o contexto está ausente;
- `TenantDatabaseRegistry` aplica `db/migration/billing` a cada banco dedicado;
- Billing já possui precedentes tenant-local de journal, invoice e outbox nas
  migrations `V5` e `V6`;
- o cache compartilhado não é autoridade de entitlement e não possui o envelope,
  as epochs nem a semântica fail-safe do ADR-0036.

A decisão precisa preservar o modular monolith e o custo de início de projeto,
mas deixar o slice extraível. Também precisa impedir que a ausência de
`TenantContext` transforme uma operação tenant-local em leitura ou escrita no
store compartilhado.

---

# 2. Decision Statement

## 2.1 Boundary modular e ownership

Entitlements permanece subdomínio coeso do módulo Spring Modulith existente
`contexts.billing`. A aprovação não cria um décimo quarto módulo, novo processo,
microserviço, deploy ou banco físico.

Billing é owner de:

- catálogo de capability e bundle comercial da GV Software;
- materialização contratual e projeção efetiva tenant-local;
- decisão tipada e admissão de capacidade;
- epochs, dívida de capacidade, leases de transição, migração/cutover e evidência;
- adapters de persistência platform/tenant, outbox e cache de entitlement.

Outros módulos consomem somente contratos públicos estreitos ou eventos
genuinamente intermodulares. Nenhum consumidor acessa `internal/`, repository,
entity, tabela, datasource ou chave Redis de Billing.

A separação interna deve manter portas estáveis e adapters substituíveis para que
uma extração futura não reescreva o domínio. Extração continua sendo decisão
posterior, justificada por ownership de equipe, lifecycle ou escala independente.

## 2.2 APIs públicas planejadas

A raiz pública de `contexts.billing` terá dois contratos segregados:

- `EntitlementDecisionApi`: consulta uma decisão tipada e devolve, conforme o
  caso, estado, modo, valor, origem, freshness, reason code, revision/hash e epochs;
- `EntitlementAdmissionApi`: reserva, confirma ou libera capacidade e devolve
  resultado tipado `ADMITTED`, `DENIED` ou `RETRY`, acompanhado do identificador
  bounded de reserva/lease quando aplicável.

DTOs públicos mínimos e tipados residem na raiz pública. Um contrato não pode
usar `boolean`, `null`, `Optional.empty()`, exception genérica ou default permissivo
para esconder `INDETERMINATE_UNAVAILABLE`, `INDETERMINATE_MISSING`,
`INDETERMINATE_CORRUPT` ou `INDETERMINATE_CONFLICT`.

`BillingApi` e seu `hasAvailableQuota(...)` são legado de transição: não se tornam
fachada do modelo-alvo e não podem ser fallback depois do cutover do ADR-0035. Sua
remoção ou adaptação exige plano, compatibilidade e testes antes da implementação.

Eventos ficam em `contexts.billing.events` somente quando atravessarem boundary
de módulo. Eventos, commands e detalhes internos permanecem em `internal/`.

## 2.3 Layout físico planejado

O destino segue a organização layer-first já adotada pelo módulo:

```text
app/src/main/java/br/com/duoset/saas_service/contexts/billing/
  EntitlementDecisionApi.java
  EntitlementAdmissionApi.java
  <DTOs públicos tipados de entitlement>
  events/
    <somente eventos genuinamente intermodulares>
  internal/
    domain/entitlement/
    application/model/entitlement/
    application/port/in/entitlement/
    application/port/out/entitlement/
    application/usecase/entitlement/
    application/service/entitlement/
    infrastructure/persistence/platform/entitlement/
    infrastructure/persistence/tenant/entitlement/
    infrastructure/cache/entitlement/
    infrastructure/messaging/entitlement/
    presentation/rest/entitlement/
```

Os nomes entre `<...>` são famílias planejadas, não arquivos aprovados
individualmente. Novos nomes concretos devem aparecer no implementation plan e no
contrato antes da codificação.

Regras de dependência:

- `domain/entitlement` é Java puro e não importa Spring, JPA, Jackson, Redis,
  Flyway, HTTP, DTO de provider ou `TenantContext`;
- application depende do domínio e de ports, nunca de adapter, datasource ou
  framework de persistência;
- adapters implementam ports e não vazam entity/JSON/provider para domínio ou API;
- presentation traduz HTTP para ports de entrada, sem recompor entitlements;
- dependências entre módulos usam somente raiz pública/eventos permitidos pelo
  Modulith;
- nenhuma classe `shared` recebe regra de composição, contrato, pricing,
  entitlement ou cache comercial.

## 2.4 Dois adapters de persistência, duas autoridades delimitadas

O mesmo módulo Billing possui dois adapters explícitos, com unidades de
persistência e transaction managers inequívocos:

1. adapter `platform`: catálogo seller-owned global e manifests imutáveis;
2. adapter `tenant`: revisions, snapshots, projeções, epochs, debts, leases,
   migração, cutover, evidência e outbox de um tenant.

O catálogo lógico `saas_platform` definido no ADR-0027 usa inicialmente o
datasource de plataforma AS-IS, fisicamente hospedado no banco hoje chamado
`saas_tenant`. Isso é um mapeamento físico transitório do control plane, não torna
o catálogo tenant-local e não cria licença para consultar o store sem transaction
manager explícito.

Não será criado banco adicional nesta etapa. Renomear ou separar fisicamente
`saas_platform` exige mudança futura atômica e governada, sem alterar IDs, versões
ou hashes comerciais.

O banco dedicado de cada tenant continua sendo a autoridade de seu snapshot,
projeção, marker e evidências. Não existem foreign key, join, cascade, query
distribuída ou transação XA entre platform e tenant.

## 2.5 Tracks de migration

As migrations planejadas são separadas pela autoridade:

- plataforma: `app/src/main/resources/db/migration/billing-platform/`, com
  tabela de histórico Flyway própria, planejada como
  `flyway_schema_history_billing_platform`;
- tenant: `app/src/main/resources/db/migration/billing/`, aplicada pelo
  registry a cada banco dedicado, preservando seu histórico tenant-local.

Migrations de plataforma nunca são incluídas no loop de bancos dedicados.
Migrations tenant nunca são executadas no datasource de plataforma por fallback.
Qualquer configuração deve selecionar location, datasource e transaction manager
explicitamente; nome ou convenção não substitui esse vínculo.

A ADR aprova locations e ownership, não cria arquivos SQL nem números de versão.
O plano de implementação deve inventariar histórias Flyway existentes e impedir
colisão antes de reservar versões.

## 2.6 Famílias de tabelas no store de plataforma

O catálogo global planejado é normalizado nas seguintes tabelas:

| Tabela | Ownership e finalidade |
| --- | --- |
| `billing_entitlement_capabilities` | Identidade estável, tipo e metadados estruturais da capability. |
| `billing_entitlement_bundles` | Identidade estável do bundle comercial seller-owned. |
| `billing_entitlement_bundle_versions` | Versões publicadas e imutáveis, com vigência, schema e hash. |
| `billing_entitlement_bundle_entries` | Valor tipado e composição de cada capability na versão exata. |
| `billing_entitlement_migration_manifests` | Manifest imutável e assinado/atestado usado pela migração evidence-first. |
| `billing_platform_outbox` | Publicação transacional de fatos de plataforma cujo boundary precise ser atravessado. |

Esse store não recebe invoice, subscription operacional, usage, quota consumida,
projeção tenant-local, PII de pagador, segredo, token ou payload ASAAS.

## 2.7 Famílias de tabelas no banco de cada tenant

Cada banco dedicado recebe, pelo mesmo track universal, as tabelas planejadas:

| Tabela | Ownership e finalidade |
| --- | --- |
| `billing_contract_revisions` | Linha temporal append-only das revisões contratuais. |
| `billing_contract_entitlement_snapshots` | Snapshot completo, imutável e autoritativo de cada revisão. |
| `billing_contract_entitlement_contributions` | Lineage normalizada das contribuições tipadas do snapshot. |
| `billing_effective_entitlement_projections` | Cabeçalho reconstruível da projeção efetiva. |
| `billing_effective_entitlement_entries` | Resultado tipado por capability, modo e boundary. |
| `billing_entitlement_epochs` | `contractEpoch` e `riskEpoch` separados, monotônicos e fenced. |
| `billing_entitlement_capacity_debts` | Ocupação acima do target após transição não destrutiva. |
| `billing_entitlement_admission_leases` | Lease curta para concluir operação admitida antes da boundary do ADR-0034. |
| `billing_entitlement_migration_runs` | Execuções idempotentes de inventário, backfill, shadow e cutover. |
| `billing_entitlement_migration_evidence` | Fingerprints, attestations, hashes e evidência de reconciliação. |
| `billing_entitlement_shadow_differences` | Diferenças explicadas/quarentenadas entre legado e canônico. |
| `billing_entitlement_authority` | Marker monotônico de autoridade, geração e fence do tenant. |
| `billing_entitlement_outbox` | Publicação transacional dos fatos tenant-local autorizados. |

As tabelas tenant-local carregam `tenant_id` como defesa em profundidade mesmo em
banco dedicado. Uniques, foreign keys internas e lookups incluem o tenant quando
necessário para impedir substituição ou associação cross-tenant.

IDs devem ser opacos e não sequenciais globalmente; timestamps usam instante com
timezone; hashes, schema versions e precondições CAS são persistidos. Campos
consultáveis e constraints permanecem normalizados. JSONB é permitido apenas para
valor tipado/lineage versionados, bounded, validados por schema e `CHECK`; não será
criado EAV genérico ou payload arbitrário como autoridade.

Revisions, snapshots, contributions, bundle versions e evidências são imutáveis.
Projeções são derivadas e só mudam por compare-and-set de versão/hash/epoch. O DDL
completo, índices, retention, particionamento e cardinalidades permanecem para os
planos de implementação e evidence gates ainda não executados.

A tabela `billing_entitlement_admission_leases` representa somente a lease de
transição já aprovada no ADR-0034. A reserva definitiva e concorrente de quota é
governada por `D-06`/ADR-0045; DDL/runtime podem avançar hermeticamente sob
`D-00`, mas evidências e capability continuam pendentes.

## 2.8 Marker de autoridade e cutover

`billing_entitlement_authority` representa uma máquina de estados finita:

- `LEGACY`: runtime legado ainda é a autoridade operacional;
- `SHADOW`: canônico é calculado e comparado sem efeitos;
- `CANONICAL`: runtime canônico é a única autoridade; fallback legado é proibido;
- `QUARANTINED`: divergência, corrupção ou evidência insuficiente impede avanço.

O marker vincula conceitualmente:

- tenant efetivo;
- geração/fence token monotônico;
- versão/hash do manifest, bundle, snapshot e projeção;
- `contractEpoch` e `riskEpoch` separados;
- versão CAS;
- instante, motivo e evidência da transição.

Transições válidas são monotônicas e forward-only. `CANONICAL` não volta a
`LEGACY` nem `SHADOW`. Commit ambíguo é resolvido relendo o marker no banco do
tenant e comparando fence/CAS/hashes; retry cego e rollback destrutivo são
proibidos.

## 2.9 Fronteiras transacionais e publicação confiável

Cada fluxo escreve em somente um store por transação:

- publicar bundle: version + entries + hash + `billing_platform_outbox` numa
  transação do datasource de plataforma;
- materializar contrato: ler versão global imutável e validar seu hash antes da
  transação; numa única transação tenant-local gravar revision, snapshot,
  contributions, projection, epochs e `billing_entitlement_outbox`;
- ativar revisão, avançar risk epoch, fazer cutover ou invalidar: marker/estado,
  dados locais afetados e outbox na mesma transação do tenant.

Não existe dual write síncrono platform+tenant, two-phase commit ou XA. Falha
entre leitura global e commit tenant é resolvida por idempotência, versão/hash
pinados e retry controlado, nunca consultando `latest` implicitamente.

Cada fato possui um único mecanismo confiável de publicação. A implementação não
pode gravar o mesmo fato simultaneamente no outbox próprio e na publication table
do Spring Modulith. A escolha por fluxo deve considerar o datasource que contém o
commit; o mecanismo precisa demonstrar atomicidade nesse datasource.

Os tipos internos inicialmente reservados são:

- `ENTITLEMENT_BUNDLE_PUBLISHED.v1`;
- `CONTRACT_ENTITLEMENT_REVISION_ACTIVATED.v1`;
- `ENTITLEMENT_RISK_EPOCH_ADVANCED.v1`;
- `ENTITLEMENT_CUTOVER_COMMITTED.v1`.

Esses nomes reservam semântica e versionamento para o plano; não criam classes ou
topics. Evento público cross-module futuro deve carregar apenas identidade mínima,
tenant quando aplicável, capability/revision/epoch e correlation metadata. Não
transporta grant completo, preço, PII, segredo ou payload de provider; consumidor
reconsulta a API pública apropriada.

## 2.10 Cache Redis derivado

Billing terá um port interno `EntitlementDecisionCachePort`, implementado por
adapter Redis dedicado. Ele não reutiliza `@Cacheable` genérico como autoridade e
não expõe Redis aos consumidores.

Keyspaces aprovados:

```text
billing:entitlement:decision:v1:{tenantUuid}:{capability}:{operationClass}
billing:entitlement:lkg:v1:{tenantUuid}:{capability}:{operationClass}
billing:entitlement:risk-epoch:v1:{tenantUuid}
```

Uma entrada contém envelope versionado com tenant binding, capability, operation
class, revision, hashes, `contractEpoch`, `riskEpoch`, schema/policy/evaluator,
modo/valor/lineage, timestamps, próxima boundary, reason code e prova de
integridade HMAC ou mecanismo autenticado equivalente.

O adapter aplica decode estrito, tamanho máximo, allowlist de schema, rotação de
chave, comparação de epoch e CAS/Lua quando necessário para impedir rollback. TTL
é absoluto desde a avaliação autoritativa, nunca sliding; hit, copy ou retry não
renovam freshness ou LKG.

Não haverá cache local L1 inicialmente, para reduzir drift e invalidation races.
Não haverá tabela SQL de LKG. Redis não vira autoridade, não recebe PII, tokens,
payload financeiro ou dados ASAAS e segue integralmente TTLs/classes do ADR-0036.

## 2.11 TenantScopeGuard e seleção segura de datasource

Toda entrada tenant-scoped deve executar um `TenantScopeGuard` planejado na
application layer antes de abrir transação ou acessar repository/cache. O guard:

1. exige tenant autenticado/efetivo não nulo;
2. compara tenant solicitado, contexto, principal e command/query;
3. valida tenant ativo e readiness necessária à operação;
4. produz deny/retry tipado em divergência ou ausência;
5. impede que o fluxo alcance o default/shared datasource.

Nenhum client, header sem prova, DTO, admin ou payload escolhe datasource,
database slug, JDBC URL, schema, store, Redis key, provider account ou tenant
efetivo. Ausência de contexto falha antes da transação; o fallback AS-IS do
`TenantRoutingDataSource` não é permitido para entitlement tenant-local.

Jobs, schedulers, listeners e workers iteram tenants por fonte autorizada e
instalam o contexto com primitive estruturada, como `TenantContext.supplyWithTenant`
ou executor seguro equivalente, sempre com cleanup em `finally`. Cada tenant usa
transação independente, readiness verificada e bounded concurrency. Falha de um
tenant não muda o datasource nem o estado de outro.

## 2.12 BP Farias, segurança e dados sensíveis

BP Farias não recebe branch, seed, feature flag, SQL, bundle, database slug ou
regra hardcoded. Ele passa pelo mesmo inventário, manifest atestado, migration,
backfill, shadow, reconciliação, cutover, packages e contratos de qualquer tenant.

O desenho preserva:

- menor privilégio separado para administração global de catálogo e operação
  tenant-local;
- tenant binding em caches, mensagens, IDs, constraints, logs e traces;
- sanitização de reason codes e auditoria sem material sensível;
- proibição de PII, credencial, token, PAN, segredo, webhook raw ou payload ASAAS
  no catálogo, entitlement, cache ou evento;
- maker-checker, MFA, SoD e alçadas governados por `D-13`/ADR-0050, com
  configuração/enforcement ainda pendentes;
- provider e cobrança fora do domínio de entitlement.

Nenhuma decisão de entitlement chama ASAAS. Um comando financeiro já persistido
continua governado pelo journal/outbox e pelas precondições do ADR-0023/ADR-0036;
esta ADR não autoriza criar, reemitir, cancelar ou cobrar invoice.

## 2.13 Frontend e boundary HTTP

Frontend consome somente contrato HTTP tipado publicado pelo backend. Ele pode
exibir estado, origem, stale flag, idade e reason code sanitizado, mas não compõe
grants, não infere default, não mantém LKG autoritativo e não decide admission.

Namespaces tenant/admin seguem o ADR-0026. Rotas, verbs, DTOs OpenAPI, paginação,
erros e autorização final permanecem para a decisão de API e os implementation
plans; os nomes das APIs Java desta ADR não criam endpoint automaticamente.

## 2.14 Boundary da aprovação

Esta decisão foi aceita como `D-04.2-H — Opção A`. Com ela, `D-04.2-A` a
`D-04.2-H` estão arquiteturalmente fechadas.

O ADR-0038 aceitou posteriormente `D-04.3` e mantém o kernel de pricing como slice
separado dentro do mesmo módulo Billing; ele não altera stores, APIs ou autoridade
de entitlement desta decisão. `D-04.4` permanece a próxima decisão comercial.

A aprovação desta ADR isoladamente não removeu o freeze então vigente. As decisões
seguintes foram aceitas, mas seus artefatos/evidências permanecem gates por fluxo:

- `D-05`: lifecycle contratual e temporal;
- `D-06`: metering, rating, reserva/concorrência de quota e precificação de uso;
- `D-08`: condições financeiras e seus efeitos;
- `D-13`: RBAC, segregação de funções, four-eyes, MFA e alçadas;
- `D-14`: rollout, cohorts, SLOs, thresholds e parâmetros operacionais;
- `D-00`: `RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`; autoriza
  implementação/testes herméticos locais, sem effect/rollout.

Esta ADR isoladamente não aprova código, DDL, número de migration, endpoint ou
payload final; os planos TP-00013 podem materializá-los localmente. Provisionamento
externo, dados reais, chamada ASAAS, piloto e produção permanecem bloqueados.

---

# 3. Decision Drivers

- manter alta coesão entre contrato, entitlement, usage e Billing;
- preservar o modular monolith de treze módulos no início do projeto;
- aplicar Clean Architecture e Dependency Inversion sem criar módulo prematuro;
- separar autoridade seller-owned global de fatos tenant-local;
- impedir join, FK, XA, dual write e fallback cross-store;
- garantir que contexto ausente falhe antes de selecionar datasource;
- deixar o slice extraível por APIs e ports estáveis;
- manter cache descartável, íntegro e limitado pelo ADR-0036;
- garantir migração universal sem tratamento especial para BP Farias;
- manter provider, PII e cobrança fora de entitlements;
- controlar custo e complexidade operacional antes de produção.

---

# 4. Considered Options

## Option A: Slice coeso e extraível dentro de `contexts.billing`

Description: Manter Entitlements no módulo Billing, com APIs públicas segregadas,
domínio interno puro, ports/adapters, persistence adapters platform/tenant, outbox
por store e cache Redis derivado.

Pros:

- máxima coesão com contrato, catálogo e usage;
- não adiciona módulo, deploy, rede ou banco físico;
- evita dependência cíclica Billing/Entitlement;
- aproveita boundary Modulith e trilha tenant-local existentes;
- permite extração futura sem expor internals;
- menor custo e blast radius no estágio pré-produção.

Cons:

- exige disciplina interna para o slice não se misturar ao Billing legado;
- dois adapters e transaction managers no mesmo módulo exigem qualifiers e testes
  arquiteturais fortes;
- extração futura ainda demandará decisão e plano próprios.

## Option B: Novo módulo Spring Modulith `contexts.entitlement`

Description: Criar agora um módulo separado, com API e dependências próprias.

Pros:

- isolamento nominal maior;
- boundary mais próximo de uma extração futura;
- ownership independente caso já existisse equipe dedicada.

Cons:

- cria o décimo quarto módulo antes de lifecycle ou escala independentes;
- favorece ciclo Billing → Entitlement → Billing ou duplicação de orquestração;
- aumenta wiring, contratos, eventos, migrations e testes transacionais;
- distribui uma única consistência comercial por boundaries prematuras.

Disposition: Deferred. Deve ser reconsiderada quando team topology, lifecycle,
deploy ou carga independente fornecerem evidência suficiente.

## Option C: Shared kernel, configuração global, microserviço ou cache como autoridade

Description: Colocar regras em `shared`, servir entitlement por rede desde o início,
usar um store global para fatos tenant ou tratar Redis como fonte autoritativa.

Pros:

- acesso aparente simples para todos os consumidores;
- deploy independente no caso do microserviço.

Cons:

- polui o kernel técnico com regra comercial;
- aumenta indisponibilidade, custo de rede e operação;
- amplia blast radius e superfície cross-tenant;
- cria dual authority e conflita com database-per-tenant;
- dificulta commit local, cutover fenced e recuperação.

Disposition: Rejected.

---

# 5. Decision Outcome

A **Option A** foi aceita.

O modelo-alvo combina um único boundary público de Billing com isolamento interno
forte. O catálogo global usa o adapter de plataforma; a autoridade operacional usa
o adapter do banco dedicado; cache e eventos permanecem derivados. A ausência de
contexto tenant nunca é convertida no datasource compartilhado.

---

# 6. Consequences

## Positive Consequences

- Entitlement permanece próximo de contrato e usage sem virar lógica compartilhada.
- Consumidores recebem resultado tipado e não dependem de storage/cache.
- Catálogo global e autoridade tenant-local têm migrations e transações distintas.
- O slice pode ser extraído futuramente por ports estáveis.
- Marker, epochs e outbox fecham o boundary físico do cutover.
- Redis não pode substituir snapshot ou projeção.
- Tenant ausente falha antes do datasource.

## Negative Consequences

- Billing terá dois adapters de persistência e exigirá wiring explícito.
- O conjunto de tabelas e testes de migração será significativo.
- APIs tipadas exigirão migração dos consumidores do `boolean` legado.
- Outbox por store e rebuild/cache demandarão observabilidade cuidadosa.

## Neutral Consequences

- Não há novo módulo, banco, microserviço ou L1 nesta etapa.
- `saas_platform` continua conceito lógico sobre o datasource físico AS-IS.
- Nomes de tabelas/keyspaces aprovam ownership, não DDL ou provisionamento.
- DDL, código e API HTTP evoluem somente pelos planos autorizados; ASAAS permanece inalterado.
- `D-00` libera implementação hermética local, sem capability ou efeito real.

---

# 7. Impact

## Compatibility with prior decisions

| Decisão | Efeito desta ADR |
| --- | --- |
| ADR-0010 | Encapsula plano/limite legado e impede que `BillingApi.hasAvailableQuota` permaneça autoridade pós-cutover. |
| ADR-0019 | Preserva banco dedicado e exige tenant binding, sem fallback compartilhado. |
| ADR-0023 | Mantém provider fora de entitlement e qualquer side effect financeiro atrás de journal/outbox próprio. |
| ADR-0026 | Mantém separação HTTP tenant/admin; API Java não cria rota global. |
| ADR-0027 | Materializa a separação catálogo global/faturamento local em adapters e tracks Flyway distintos. |
| ADR-0028 | Dá placement físico a bundle, snapshot, projeção e autoridade tenant-local. |
| ADR-0029 | Persiste contribuições/lineage tipadas sem override genérico/EAV. |
| ADR-0030 | Coloca decisão/admission tipadas atrás de APIs distintas e projection entries normalizadas. |
| ADR-0032 | Persiste revisions/snapshots imutáveis e boundary temporal sem `latest` implícito. |
| ADR-0034 | Dá placement a capacity debt e admission lease, sem aprovar reserva de quota de `D-06`. |
| ADR-0035 | Dá placement ao manifest, runs/evidence/differences e marker fenced forward-only. |
| ADR-0036 | Dá placement ao cache port/keyspace/envelope, preservando LKG limitado e fail-safe. |

## Impact by area

- Backend: novo slice planejado dentro de Billing, APIs públicas e adapters segregados.
- Database: novo track platform e expansão universal do track tenant; sem XA.
- Frontend: futuro consumo de resposta tipada e stale metadata, sem regra local.
- Security: tenant guard pré-transação, integridade do cache e least privilege.
- Operations: outbox por store, epochs, rebuild e métricas bounded por tenant.
- Cost: reutiliza processo, Redis e PostgreSQL existentes; não adiciona serviço/banco.
- Migration: BP Farias e demais tenants seguem o mesmo pipeline evidence-first.

---

# 8. AI Agent Considerations

Agentes que planejarem ou implementarem esta decisão devem:

1. distinguir sempre AS-IS de destino planejado;
2. não criar novo módulo, database ou microserviço sem ADR sucessor;
3. não mover regra de entitlement para `shared`;
4. não acessar `internal/` de Billing a partir de outro módulo;
5. manter domain puro e dependência em direção aos ports;
6. escolher explicitamente adapter/transaction manager por store;
7. provar que tenant guard executa antes de qualquer transação tenant-local;
8. impedir execução tenant de migration platform e vice-versa;
9. usar uma transação e um outbox por store, sem XA/dual write;
10. não criar L1, SQL-LKG, fallback legado ou cache-as-authority;
11. não codificar BP Farias ou qualquer tenant;
12. não incluir PII, segredo ou ASAAS em entitlement/cache/evento;
13. aplicar `D-00` somente como liberação humana local-only dos planos TP-00013;
14. criar/atualizar testes de arquitetura, isolamento, migration, concorrência,
    contrato e segurança em cada slice implementado.

---

# 9. Implementation Plan Boundary

Esta seção registra condições para planos incrementais; a execução hermética local
é autorizada separadamente por `D-00`.

Sob `D-00` e respeitando os gates técnicos aplicáveis, o plano deve ordenar:

1. congelamento do modelo/contratos e inventário de consumidores do legado;
2. configuração segura da location/history Flyway de plataforma;
3. migrations platform e tenant com testes em banco efêmero;
4. domínio puro e algebra já aprovada;
5. ports e adapters platform/tenant;
6. revisions, snapshots, projection, marker, epochs e outbox;
7. APIs públicas tipadas e migração de consumidores;
8. cache Redis derivado e invalidation/recovery;
9. migration evidence-first, shadow e cutover por tenant;
10. observabilidade, segurança, performance e rollback operacional forward-only;
11. rollout conforme `D-14`.

Cada etapa deve manter release flag/default desabilitado até seus gates. Nenhum
passo pode usar dados reais, produção, segredos ou ASAAS para validar entitlement.

---

# 10. Validation

## 10.1 Gates documentais desta decisão

- `ADR-0037` está indexada individualmente no README imediato.
- ADRs diretamente relacionados apontam para esta decisão como fechamento de H.
- Destinos ainda inexistentes estão marcados como planejados.
- `D-05`, `D-06`, `D-08`, `D-13` e `D-14` possuem decisões aceitas nos ADRs
  sucessores; seus contratos executáveis, evidências e capabilities continuam
  não implementados ou `OFF`; `D-00` permite somente construção/testes locais.
- Nenhum arquivo de código, SQL, runtime ou provider é alterado por esta aprovação.

## 10.2 Gates futuros de implementação

- teste Spring Modulith impede acesso externo a `internal/` e ciclo de módulos;
- ArchUnit garante domínio puro e dependências layer-first;
- contract tests cobrem estados tipados, freshness, reason e epochs;
- migration tests provam separação platform/tenant e idempotência por tenant;
- testes de datasource provam falha antes do fallback quando contexto falta;
- testes cross-tenant demonstram isolamento de DB, FK, cache e mensagem;
- testes de concorrência cobrem CAS, fence, epochs, marker, leases e outbox;
- testes de integridade cobrem HMAC, replay, rollback e payload inválido;
- testes de cutover provam `LEGACY → SHADOW → CANONICAL` e quarentena;
- testes de cache provam TTL absoluto, sem sliding, sem L1 e sem grant indevido;
- testes de arquitetura provam que provider/ASAAS não entra no slice;
- BP Farias passa pelas mesmas fixtures parametrizadas, sem branch próprio.

Esses gates pertencem ao plano pós-autorização e não foram executados, pois esta
mudança é exclusivamente documental.

---

# 11. Risks and Mitigations

| Risco | Mitigação obrigatória |
| --- | --- |
| Billing virar god module | Slice coeso, APIs pequenas, domain puro, ports e architecture tests. |
| Dependência cíclica ao extrair | Consumidores dependem somente das APIs/eventos públicos; nenhuma chamada reversa implícita. |
| Catálogo global migrar em todos os tenants | Location/history Flyway platform separadas e testes negativos de configuração. |
| Dado tenant-local cair no platform default | `TenantScopeGuard` antes da transação e teste de contexto ausente. |
| Transação distribuída acidental | Uma transação/outbox por store; versão/hash pinados entre commits. |
| Dupla publicação | Um único mecanismo confiável por fato e datasource. |
| Projection/cache virar autoridade | Snapshot local continua autoritativo; rebuild e TTL absoluto. |
| Replay/rollback no Redis | HMAC, tenant binding, epochs monotônicas, CAS e expiração absoluta. |
| Migração especial para BP Farias | Pipeline e fixtures universais por tenant, sem hardcode. |
| JSONB virar schema arbitrário | Campos normalizados, schema/version/CHECK e payload bounded. |
| Lease aprovar quota implicitamente | `billing_entitlement_admission_leases` limitada ao ADR-0034; `D-06` bloqueia reserva final. |
| Liberação local ser confundida com rollout | `D-00` permanece explícito como local-only; chamadas externas, Sandbox ASAAS, piloto BP Farias, produção, flags `ON` e efeitos reais continuam bloqueados. |

---

# 12. Related ADRs

- [ADR-0000 - Governança documental](../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md)
- [ADR-0001 - Stack e arquitetura](ADR-0001-technology-stack-and-architecture.md)
- [ADR-0010 - Parametrização de planos](ADR-0010-tenant-plan-parametrization.md)
- [ADR-0019 - Database-per-tenant](ADR-0019-database-per-tenant.md)
- [ADR-0023 - Integração agnóstica de providers](ADR-0023-agnostic-payment-provider-integration.md)
- [ADR-0026 - Boundary HTTP tenant/admin](ADR-0026-billing-api-tenant-admin-cutover.md)
- [ADR-0027 - Catálogo global e faturamento local](ADR-0027-catalogo-global-faturamento-local.md)
- [ADR-0028 - Entitlements versionados tenant-local](ADR-0028-entitlements-versionados-tenant-local.md)
- [ADR-0029 - Taxonomia tipificada de entitlements](ADR-0029-taxonomia-tipificada-entitlements.md)
- [ADR-0030 - Composição e enforcement](ADR-0030-composicao-deterministica-enforcement-entitlements.md)
- [ADR-0032 - Adoção e grandfathering](ADR-0032-adocao-versionada-grandfathering-entitlements.md)
- [ADR-0034 - Efeitos não destrutivos](ADR-0034-efeitos-transicao-nao-destrutiva-entitlements.md)
- [ADR-0035 - Migração evidence-first](ADR-0035-migracao-evidence-first-entitlements-legados.md)
- [ADR-0036 - Cache/LKG fail-safe](ADR-0036-cache-lkg-fail-safe-entitlements.md)
- [ADR-0038 - Pricing tipado, moeda e cadência](ADR-0038-pricing-tipado-moeda-cadencia.md)

---

# 13. References

- `docs/architecture/module-registry.md`
- `docs/product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md`
- `docs/product/use-cases/UC-00038-billing-catalog-pricing-promotions.md`
- `docs/product/use-cases/UC-00039-billing-contract-subscription-amendments.md`
- `docs/product/use-cases/UC-00040-billing-usage-rating-invoice-close.md`
- `../../../docs/specs/TP-00013-enterprise-billing-implementation-task-plan.md`
- `app/src/main/java/br/com/duoset/saas_service/contexts/billing/package-info.java`
- `app/src/main/java/br/com/duoset/saas_service/contexts/billing/BillingApi.java`
- `app/src/main/java/br/com/duoset/saas_service/config/persistence/PlatformDataSourceConfig.java`
- `app/src/main/java/br/com/duoset/saas_service/config/persistence/TenantDataSourceConfig.java`
- `app/src/main/java/br/com/duoset/saas_service/config/persistence/routing/TenantRoutingDataSource.java`
- `app/src/main/java/br/com/duoset/saas_service/config/persistence/routing/TenantDatabaseRegistry.java`
- `app/src/main/resources/db/migration/billing/`

---

# 14. Decision Lifecycle

Esta ADR está `Accepted` pela aprovação explícita de `D-04.2-H — Opção A`.
Os ADRs-0038 a ADR-0051 e as revisões vigentes dos ADR-0023 a ADR-0025 fecham as
decisões posteriores sem fundir pricing, pagamento, fiscal, ledger ou rollout com
entitlement e sem alterar a proveniência humana desta ADR.
Alterar módulo owner, criar módulo/microserviço/banco, mover autoridade, permitir
fallback compartilhado, adicionar XA/L1/SQL-LKG ou colocar regra em `shared` exige
ADR sucessor ou nova versão formalmente aceita.

---

# 15. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.4 | 2026-08-25 | Solicitante humano, proprietário declarado / Codex (IA), materialização | Registra `D-00 = RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`; permite backend/frontend/DDL/migrations/testes herméticos locais e mantém chamadas externas, Redis externo, Sandbox ASAAS, piloto BP Farias, produção, flags `ON` e efeitos reais bloqueados. |
| 1.3 | 2026-08-25 | Codex (IA), sob `AUTH-BILLING-2026-08-25-001` | Reconcilia a reserva de quota com `D-06`/ADR-0045 aceita e substitui decisões abertas por artefatos/evidências ainda não executados; mantém a origem humana de `D-04.2-H` e `D-00 ACTIVE`. |
| 1.2 | 2026-08-25 | Codex / Arquitetura | Reconcilia D-05 a D-14 com os ADRs sucessores aceitos, preserva este boundary e sua origem humana e mantém contratos executáveis, evidências, capabilities e D-00 como gates. |
| 1.1 | 2026-08-24 | Responsável pelo produto / Arquitetura | Registra ADR-0038 como decisão subsequente de `D-04.3`, preservando pricing e entitlement como slices/autoridades separados dentro de Billing e mantendo `D-04.4`/`D-00` abertos. |
| 1.0 | 2026-08-24 | Responsável pelo produto / Arquitetura | Aceita `D-04.2-H — Opção A`; mantém Entitlements dentro de `contexts.billing`, define APIs/layout/adapters/stores/migrations/tabelas/marker/outbox/cache/tenant guard e preserva todos os gates de implementação. |

---

# 16. Repository Structure

A implementação fica restrita aos destinos planejados da Section 2.3,
às duas locations de migration da Section 2.5 e às configurações estritamente
necessárias para ligar seus adapters. Nova raiz de módulo, diretório `shared`,
serviço ou banco não faz parte desta decisão.

---

# 17. Review Process

Mudança editorial pode incrementar versão menor. Mudança normativa em boundary,
ownership, autoridade, store, transação, cache ou isolamento exige revisão de
Arquitetura, Billing, Dados e Segurança e novo aceite explícito.

---

# 18. Notes

Esta ADR encerra somente a sequência arquitetural `D-04.2-A` a `D-04.2-H`.
Ela fornece precisão suficiente para elaborar planos executáveis, mas mantém
intencionalmente separados decisão, plano e implementação conforme o ADR-0000.

Sob `D-00`, símbolos, migrations, tabelas, keyspaces e eventos podem ser
materializados localmente pelos planos TP-00013. Nenhuma capability ou existência
em runtime deve ser inferida sem código e evidência reproduzível.
