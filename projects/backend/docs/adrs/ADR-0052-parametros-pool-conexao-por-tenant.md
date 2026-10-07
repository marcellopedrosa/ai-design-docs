---
document_id: "ADR-0052"
primary_nature: "Decisao"
objective: "Definir como o Super Admin configura parametros de pool de conexoes exclusivos por tenant sem compartilhar configuracao, instancia ou fallback entre tenants."
scope: "Control plane de tenants, configuracao versionada de HikariCP, cache derivado tenant-scoped da politica, RBAC de plataforma, ciclo de vida do TenantDatabaseRegistry, capacidade PostgreSQL, auditoria, observabilidade, migracao e rollback."
non_objectives: "Implementar endpoints, UI, migrations ou codigo; governar caches funcionais ou permitir TTL/quota de cache por tenant; alterar a decisao database-per-tenant; permitir edicao de URL/credenciais/driver/schema; definir capacidade de producao sem benchmark; adotar PgBouncer ou particionar clusters PostgreSQL."
owner: "Arquitetura / Backend / SRE / Seguranca"
status: "Accepted"
date: "2026-08-26"
version: "1.12"
keywords: "multitenancy, database-per-tenant, HikariCP, connection pool, Super Admin, capacidade, swap atomico, drain, fail-closed"
related_files: "README.md, ADR-0002-separacao-banco-por-contexto-multitenancy.md, ADR-0005-multi-tenancy-architecture.md, ADR-0009-dynamic-rbac-evolution.md, ADR-0012-error-handling-observability.md, ADR-0019-database-per-tenant.md, ../../../docs/specs/TP-00023-tenant-pool-policy-administration.md, ../../../docs/specs/TP-00024-tenant-pool-policy-contract-and-super-admin-ui.md, ../../../docs/specs/TP-00027-tenant-pool-policy-authorized-test-rollout.md, ../../../docs/specs/TP-00029-tenant-pool-policy-managed-runtime-environments.md, ../../../docs/specs/TP-00030-tenant-pool-policy-hml-prd-controlled-rollout.md, ../specs/IP-BE-23.4.3-tenant-pool-policy-managed-runtime-environments.md, ../../../docs/specs/IP-INFRA-23.5.1-tenant-pool-policy-managed-hml-activation.md, ../lessons-learned/LL-BE-00091-long-lived-chatbot-transaction-exhausts-tenant-pool.md"
code_references: "app/src/main/java/br/com/duoset/saas_service/config/persistence/routing/TenantDatabaseRegistry.java, app/src/main/java/br/com/duoset/saas_service/config/persistence/routing/TenantRoutingDataSource.java, app/src/main/java/br/com/duoset/saas_service/shared/tenancy/TenantDatabaseRegistryPort.java, app/src/main/java/br/com/duoset/saas_service/config/persistence/TenantDataSourceConfig.java, app/src/main/java/br/com/duoset/saas_service/config/persistence/PlatformDataSourceConfig.java, app/src/main/resources/application.yml, app/src/main/resources/application-tenant-pool-smoke.yml, app/src/main/java/br/com/duoset/saas_service/contexts/tenant/, /api/v1/platform/tenant-pool-policies/{tenantId}"
principal_statement: "Cada tenant tera uma politica completa e versionada no control plane, cache apenas derivado e tenant-scoped, e uma geracao HikariDataSource exclusiva por instancia da aplicacao; somente ROLE_SUPER_ADMIN podera solicitar alteracoes, ativadas por validacao de capacidade, candidato isolado, troca atomica e drenagem, sem compartilhar objetos ou usar fallback de outro tenant ou da plataforma."
---

# ADR-0052 - Pools de conexão exclusivos e configuráveis por tenant

- Document ID: `ADR-0052`
- Primary Nature: `Decisao`
- Objective: Definir como o Super Admin configura parâmetros de pool de conexões exclusivos por tenant sem compartilhar configuração, instância ou fallback entre tenants.
- Scope: Control plane de tenants, configuração versionada de HikariCP, cache derivado tenant-scoped da política, RBAC de plataforma, ciclo de vida do `TenantDatabaseRegistry`, capacidade PostgreSQL, auditoria, observabilidade, migração e rollback.
- Non-objectives: Implementar endpoints, UI, migrations ou código; governar caches funcionais ou permitir TTL/quota de cache por tenant; alterar a decisão database-per-tenant; permitir edição de URL, credenciais, driver ou schema; definir capacidade de produção sem benchmark; adotar PgBouncer ou particionar clusters PostgreSQL.
- Keywords: multitenancy, database-per-tenant, HikariCP, connection pool, Super Admin, capacidade, swap atômico, drain, fail-closed
- Related Files: [ADR-0002](ADR-0002-separacao-banco-por-contexto-multitenancy.md), [ADR-0005](ADR-0005-multi-tenancy-architecture.md), [ADR-0009](ADR-0009-dynamic-rbac-evolution.md), [ADR-0012](ADR-0012-error-handling-observability.md), [ADR-0019](ADR-0019-database-per-tenant.md), [REQ-00003](../product/requirements/REQ-00003-rbac-profile-responsibility-matrix.md), [REQ-00004](../product/requirements/REQ-00004-rbac-security-mapping.md), [REQ-00030](../product/requirements/REQ-00030-multitenancy-isolation-verification.md), [REQ-00031](../product/requirements/REQ-00031-phase2-tenant-lifecycle-and-access.md), [REQ-00046](../product/requirements/REQ-00046-chatbot-tenant-pool-starvation-resilience.md), [REQ-00047](../product/requirements/REQ-00047-super-admin-tenant-pool-policy-administration.md), [REQ-00048](../product/requirements/REQ-00048-tenant-pool-policy-cache-isolation-resilience.md), [REQ-00049](../product/requirements/REQ-00049-tenant-pool-policy-authorized-test-rollout.md), [REQ-00051](../product/requirements/REQ-00051-tenant-pool-policy-managed-runtime-environments.md), [REQ-00052](../product/requirements/REQ-00052-tenant-pool-policy-controlled-hml-prd-rollout.md), [TP-00023](../../../docs/specs/TP-00023-tenant-pool-policy-administration.md), [TP-00024](../../../docs/specs/TP-00024-tenant-pool-policy-contract-and-super-admin-ui.md), [TP-00027](../../../docs/specs/TP-00027-tenant-pool-policy-authorized-test-rollout.md), [TP-00029](../../../docs/specs/TP-00029-tenant-pool-policy-managed-runtime-environments.md), [TP-00030](../../../docs/specs/TP-00030-tenant-pool-policy-hml-prd-controlled-rollout.md), [IP-BE-23.4.3-tenant-pool-policy-managed-runtime-environments](../specs/IP-BE-23.4.3-tenant-pool-policy-managed-runtime-environments.md), [module registry](../architecture/module-registry.md), [IP-BE-3.2.10-chatbot-tenant-pool-starvation-remediation](../specs/IP-BE-3.2.10-chatbot-tenant-pool-starvation-remediation.md) e [LL-BE-00091 — Transação longa do chatbot esgota o pool tenant](../lessons-learned/LL-BE-00091-long-lived-chatbot-transaction-exhausts-tenant-pool.md).
- Code References: `TenantDatabaseRegistry`, `TenantRoutingDataSource`, `TenantDatabaseRegistryPort`, `TenantDataSourceConfig`, `PlatformDataSourceConfig`, `application-tenant-pool-smoke.yml`, `contexts.tenant` e `/api/v1/platform/tenant-pool-policies/{tenantId}`.
- Principal Decision: Cada tenant terá uma política completa e versionada no control plane, cache apenas derivado e tenant-scoped, e uma geração `HikariDataSource` exclusiva por instância da aplicação; somente `ROLE_SUPER_ADMIN` poderá solicitar alterações, ativadas por validação de capacidade, candidato isolado, troca atômica e drenagem, sem compartilhar objetos ou usar fallback de outro tenant ou da plataforma.
- Date: 2026-08-26
- Status: Accepted
- Version: 1.12
- Accepted on: 2026-08-27, por aprovação humana explícita com escopo delimitado
- Authors / Owners: Codex (OpenAI), sob solicitação do usuário / Arquitetura / Backend / SRE / Segurança
- Reviewers: Arquitetura, Segurança, Backend, DBA/SRE, Qualidade e Produto
- Stakeholders: Super Admin, Operações, Suporte, mantenedores da plataforma e todos os tenants
- Supersedes: [ADR-0002](ADR-0002-separacao-banco-por-contexto-multitenancy.md) parcialmente, somente quanto ao sizing uniforme aplicado a pools dedicados por tenant; [ADR-0019](ADR-0019-database-per-tenant.md) parcialmente, somente quanto ao fallback legado do §7.
- Superseded by: N/A

---

# 0. Limite de autoridade e estado da decisão

Em 2026-08-27, o solicitante humano aprovou explicitamente este ADR, o RF
[REQ-00047](../product/requirements/REQ-00047-super-admin-tenant-pool-policy-administration.md)
e o NFR
[REQ-00048](../product/requirements/REQ-00048-tenant-pool-policy-cache-isolation-resilience.md)
para planejamento e implementação **backend local**. Na mesma data, uma instrução
humana posterior autorizou também o planejamento e a implementação **frontend
local** desta capability. A decisão permanece
`Accepted`; o aceite arquitetural não declara implementação, benchmark,
readiness ou release concluídos.

A autorização alcança somente documentação de planejamento, código backend e
frontend, migrations, configuração da aplicação e testes locais com dados
sintéticos dentro do escopo combinado do REQ-00047 e REQ-00048. A instrução
humana de continuidade de 2026-08-27 aprovou explicitamente o wireframe textual
versionado no `IP-FE-23.3.1-tenant-pool-policy-super-admin-ui`; portanto, os componentes visuais React/Tailwind
descritos naquele plano também estão autorizados localmente. Permanecem fora da
autorização:

- implementação visual que extrapole o wireframe aprovado;
- infraestrutura externa ou alteração operacional de ambientes;
- deploy, homologação, produção, tráfego ou dados reais;
- leitura de segredos ou credenciais reais;
- definição de sizing de produção sem benchmark e capacity proof aprovados.

O gate humano de decisão e requisito está resolvido. Antes de editar o backend,
continuam obrigatórios planos de tarefa e implementation plans persistidos,
matrizes [REQ-00003](../product/requirements/REQ-00003-rbac-profile-responsibility-matrix.md)
e [REQ-00004](../product/requirements/REQ-00004-rbac-security-mapping.md) reconciliadas,
testes de isolamento, revisão de segurança e os gates técnicos deste ADR. O
[REQ-00046](../product/requirements/REQ-00046-chatbot-tenant-pool-starvation-resilience.md)
continua governando a correção localizada de starvation do chatbot; ele não
substitui o REQ-00047 nem o REQ-00048.

O [TP-00023](../../../docs/specs/TP-00023-tenant-pool-policy-administration.md)
continua coordenando o runtime backend. O
[TP-00024](../../../docs/specs/TP-00024-tenant-pool-policy-contract-and-super-admin-ui.md)
coordena o contrato HTTP backend e o frontend sem antecipar os gates de runtime.

Em 2026-08-28, nova instrução humana aprovou os próximos passos locais e o
[REQ-00049](../product/requirements/REQ-00049-tenant-pool-policy-authorized-test-rollout.md)
como terceiro componente desta decisão. A autorização permite um profile
repository-local opt-in, exclusivamente em `dev` ou `test`, com tenants
sintéticos A/B e guardas fail-closed. Ela não autoriza ambiente DEV compartilhado,
HML, staging, PRD, produção, infraestrutura ou deploy. O
[TP-00027](../../../docs/specs/TP-00027-tenant-pool-policy-authorized-test-rollout.md)
coordena esse recorte e somente planeja um rollout ambiental futuro.

Em 2026-09-01, o owner humano ampliou explicitamente o objetivo repository-local:
a operacao deve ficar disponivel pela tela durante a execucao normal, sem renovar
lease por launcher nem reiniciar a aplicacao, e o mesmo artefato deve possuir
contrato fail-closed para DEV, HML e PRD. O
[REQ-00051](../product/requirements/REQ-00051-tenant-pool-policy-managed-runtime-environments.md)
e o [TP-00029](../../../docs/specs/TP-00029-tenant-pool-policy-managed-runtime-environments.md)
governam essa ampliacao. A autorizacao permite implementacao e testes
repository-local; nao autoriza deploy, ativacao externa, segredo/dado real nem
sizing de HML/PRD sem capacity proof.

Em 2026-09-02, o owner humano aprovou o
[REQ-00052](../product/requirements/REQ-00052-tenant-pool-policy-controlled-hml-prd-rollout.md)
como quinto componente operacional e o
[TP-00030](../../../docs/specs/TP-00030-tenant-pool-policy-hml-prd-controlled-rollout.md)
como coordenador do rollout sequencial HML antes de PRD. A autorizacao desta
revisao permanece **repository-local**: permite documentacao de planejamento, a
alocacao exata do IP HML registrada no requisito e sua materializacao somente em
`Proposed`, mas nao autoriza criar efeito ambiental, acessar HML/PRD, executar
deploy, ler segredo/dado real ou definir sizing sem capacity proof. O
[IP-INFRA-23.5.1](../../../docs/specs/IP-INFRA-23.5.1-tenant-pool-policy-managed-hml-activation.md)
deve receber aprovacoes separadas para `Approved` e `In Progress`; o IP PRD
permanece nao alocado.

Efeito normativo deste aceite: especializar somente o sizing uniforme descrito no
ADR-0002 quando aplicado a pools dedicados por tenant e substituir somente o
fallback legado do ADR-0019 §7. Todo o restante dessas decisões permanece vigente.

## 0.1 Rotas de leitura seletiva

| Interesse | Seções mínimas |
| --- | --- |
| decisão e isolamento | 1, 2.1, 2.2, 2.7, 2.8 e 5 |
| sizing e capacidade | 2.3, 2.4, 2.5, 2.12, 10 e 11 |
| segurança e auditoria | 2.6, 2.9, 7 e 10 |
| rollout e operação | 2.7, 2.10, 2.12, 9, 10 e 11 |
| cache derivado da política | 2.11, 7, 9 e 10 |
| governança e aceite | 0, 12, 14, 15 e 17 |

---

# 1. Context

O [ADR-0019](ADR-0019-database-per-tenant.md) decidiu que cada escritório possui
um único banco PostgreSQL dedicado contendo as tabelas dos bounded contexts. Os
contextos de um mesmo tenant compartilham intencionalmente um único pool; tenants
diferentes não devem compartilhar esse pool.

O estado atual já cria um `HikariDataSource` novo para cada entrada do
`TenantDatabaseRegistry`, mas todos recebem os mesmos valores globais:

| Parâmetro AS-IS | Valor/fonte atual |
| --- | --- |
| `minimumIdle` | `0` |
| `maximumPoolSize` | `app.tenant-database.pool.maximum-size`, default `6` |
| `idleTimeout` | `30.000 ms` |
| `maxLifetime` | `300.000 ms` |
| demais parâmetros | defaults da biblioteca |

Essa implementação oferece isolamento de objeto, mas não oferece configuração
durável por tenant, versionamento, auditoria própria, validação do orçamento
global, concorrência de atualização ou drenagem. Uma substituição usa
`registry.put(...)` e fecha o pool anterior imediatamente. O router ainda retorna
o datasource da plataforma quando não existe `TenantContext`; o onboarding
publica/migra o pool antes de persistir o metadata do tenant; e `poolName` e logs
do registry incluem slug ou identificadores do tenant. Esses comportamentos são
AS-IS a remover, não o estado desejado. Alterações apenas em memória também seriam
perdidas no restart.

O admission control de conversas também lê o máximo global uma vez no startup e
cria gates com a mesma concorrência para todos os tenants. Portanto reduzir ou
ampliar o pool isoladamente pode romper a relação entre fluxos admitidos e
conexões disponíveis; a política de admissão deverá acompanhar a revisão efetiva
do tenant.

O [REQ-00046](../product/requirements/REQ-00046-chatbot-tenant-pool-starvation-resilience.md)
governa o corretivo localizado de starvation, enquanto a
[LL-BE-00091](../lessons-learned/LL-BE-00091-long-lived-chatbot-transaction-exhausts-tenant-pool.md)
preserva a evidência histórica direta do incidente com três conexões. Esse
incidente fundamenta os guardrails de capacidade, admissão e isolamento desta
decisão, sem determinar sozinho sizing ou valores por tenant. O código visível na
data deste ADR já usa default `6` junto de admission control, timeout e lock não
bloqueante. A lição é que somente aumentar `maximumPoolSize` não resolve retenção
de conexão, I/O externo dentro de transação ou contenção. A configuração por
tenant deve complementar, nunca contornar, esses controles.

Há três necessidades simultâneas:

1. escritórios com baixa concorrência não devem manter capacidade ociosa
   desnecessária;
2. escritórios com carga comprovadamente maior precisam de margem coerente com
   suas transações, jobs e operações `REQUIRES_NEW`;
3. a soma dos pools não pode exaurir o PostgreSQL nem permitir que um tenant maior
   prejudique todos os demais.

Neste ADR, **exclusivo** significa que política, revisão, snapshot, slot,
`HikariConfig`, `HikariDataSource`, estado de aplicação e rollback pertencem a um
único `tenantId`. Isso não afirma que cada tenant possua host PostgreSQL próprio;
vários bancos dedicados ainda podem compartilhar o mesmo cluster físico e o mesmo
orçamento de conexões.

---

# 2. Decision Statement

## 2.1 Fonte de verdade e ownership

A configuração canônica ficará no banco da plataforma (`saas_tenant`), sob
ownership do contexto Tenant/control plane. Ela não ficará somente no banco
dedicado, porque o sistema precisa conhecer os parâmetros antes de criar a
conexão capaz de acessar esse banco.

Cada revisão será completa, imutável e identificada por `(tenantId, revision)`.
Nenhum campo efetivo será resolvido em runtime por `COALESCE`, herança viva ou
fallback para um default global. Perfis como `SMALL`, `STANDARD` e `ROBUST` poderão
ser usados apenas como comandos de criação: seus valores serão copiados e
materializados em uma nova revisão do tenant. Alterar um perfil não modificará
tenants existentes.

O store persistente será a fonte de verdade. O registry em memória será estado
derivado por instância da aplicação e manterá conceitualmente:

```text
tenantId -> TenantPoolSlot
              ├── candidateGeneration(configRevision, bindingEpoch, pool)?
              ├── activeGeneration(configRevision, bindingEpoch, pool)
              └── drainingGeneration(configRevision, bindingEpoch, pool)?
```

Cada slot pronto terá exatamente uma geração ativa. No máximo um candidato e uma
geração em drenagem poderão coexistir temporariamente. Nova troca será bloqueada
enquanto a geração anterior ainda drenar, evitando crescimento ilimitado. O mesmo
`HikariConfig`, `HikariDataSource`, `TenantPoolSlot` ou geração nunca poderá ser
registrado para dois tenants, mesmo quando os valores numéricos forem idênticos.

Nenhum `HikariDataSource` bruto poderá escapar do slot, ser armazenado por bounded
context ou ficar em cache fora dele. Consumidores receberão uma aquisição
lease-aware, necessária para que troca e fechamento sejam seguros.

Os bounded contexts do **mesmo** tenant continuarão compartilhando sua geração
ativa, preservando o ADR-0019. Não será criado pool por módulo.

## 2.2 Modelo conceitual versionado

O desenho físico será fechado no plano de implementação, mas separará política
imutável, ponteiro do rollout, aplicação por runtime e reserva de capacidade:

| Campo/conceito | Regra |
| --- | --- |
| `TenantPoolPolicyRevision(tenant_id, revision)` | Snapshot completo e imutável; revisão monotônica e nunca reutilizada. |
| parâmetros allowlisted | Todos materializados e `NOT NULL` na revisão. |
| `profile_source` | Proveniência finita do seed; não participa da resolução efetiva. |
| `config_hash` | Detecta drift; não inclui segredo e deve reproduzir os getters efetivos do Hikari. |
| `requested_by`, `reason`, `correlation_id`, timestamps | Proveniência da revisão; a auditoria canônica permanece separada. |
| `TenantPoolPolicyHead` | Guarda `desired_revision`, `committed_revision`, `database_binding_epoch`, versão para CAS e estado derivado do rollout. |
| `RuntimePoolApplication` | Chave `(tenant_id, revision, deployment_epoch, runtime_instance_id)`; guarda fencing token, heartbeat e `PREPARING`, `READY`, `SWAPPED`, `DRAINED` ou `FAILED`. |
| `CapacityReservation` | Reserva durável, fenced e renovada por lease para preparação, swap e estabilização. |

Uma revisão imutável não conterá `status` mutável. `PENDING`, `PREPARING`,
`COMMITTED`, `CONVERGED`, `DEGRADED` e `FAILED` serão estados derivados do head,
dos acknowledgements por runtime e das reservas. Assim, réplicas temporariamente
em revisões diferentes não serão escondidas por um único `applied_revision`.

Deverá existir no máximo uma revisão desejada por tenant e uma revisão committed,
que é o LKG carregado por instâncias novas. Rollback criará nova revisão baseada
em snapshot anterior. Revisões e evidências serão imutáveis enquanto retidas, mas
retenção, purge e legal hold seguirão política aprovada; imutabilidade não implica
retenção eterna.

## 2.3 Parâmetros administráveis

O backend aceitará somente uma allowlist tipada:

| Parâmetro | Uso | Guardrail mínimo |
| --- | --- | --- |
| `maximumPoolSize` | Limite de conexões simultâneas por tenant e por instância da aplicação. | Positivo, dentro do teto ambiental e do orçamento global. |
| `minimumIdle` | Conexões quentes mantidas sem uso. | `0 <= minimumIdle <= maximumPoolSize`; preferir `0` quando baixa latência de primeira aquisição não for requisito medido. |
| `connectionTimeout` | Espera máxima por conexão. | Positivo, dentro do mínimo da versão Hikari em uso e coerente com o SLO da operação. |
| `validationTimeout` | Orçamento de validação da conexão. | Positivo, dentro do mínimo da biblioteca e não superior a `connectionTimeout`. |
| `idleTimeout` | Tempo para reduzir conexões ociosas. | `0` somente com semântica de desativação aprovada; é relevante apenas quando `minimumIdle < maximumPoolSize`. |
| `maxLifetime` | Renovação preventiva de conexões. | Positivo e inferior ao menor timeout imposto por PostgreSQL, proxy ou rede, com margem operacional. |
| `keepaliveTime` | Keepalive opcional para infraestrutura que encerra conexões ociosas. | `0` para desabilitado ou valor aceito pela versão e inferior a `maxLifetime`. |

Não serão administráveis por essa API: JDBC URL, database/slug, usuário, senha,
secret reference, driver, schema, catalog, `connectionInitSql`, `autoCommit`,
transaction isolation, read-only, nome do pool, registro JMX/Micrometer, Flyway ou
transaction manager. Esses campos pertencem ao binding provisionado e à
configuração segura da plataforma.

Não haverá mapa livre de propriedades Hikari. Campos desconhecidos ou relações
inválidas falharão antes de persistir/aplicar a revisão; o backend não corrigirá,
truncará ou ampliará valores silenciosamente.

Os limites e a semântica de `0` serão versionados junto da versão Hikari resolvida
pelo BOM. Antes do probe, o reconciliador executará a validação da biblioteca e
comparará os getters efetivos com o snapshot/hash solicitado. Se o Hikari
normalizar um valor, aplicar default diferente ou desabilitar silenciosamente uma
função, o candidato será rejeitado em vez de persistir um estado diferente do
declarado.

### 2.3.1 Bounds e perfis congelados para a entrega local

A primeira entrega usa HikariCP `7.0.2` e congela os seguintes hard bounds no
backend. Configuração ambiental pode **estreitar**, mas não ampliar estes limites
sem nova versão normativa e prova de capacidade:

| Campo | Bound local aprovado |
| --- | --- |
| `maximumPoolSize` | inteiro entre `6` e `50`, inclusive, sempre sujeito ao allocator global |
| `minimumIdle` | inteiro entre `0` e `min(maximumPoolSize, 10)` |
| `connectionTimeout` | `PT0.25S` a `PT30S` |
| `validationTimeout` | `PT0.25S` a `PT5S` e não superior a `connectionTimeout` |
| `idleTimeout` | `PT0S` ou `PT10S` a `PT10M`; quando ativo, deve ser menor que `maxLifetime` com margem mínima de `PT1S` |
| `maxLifetime` | `PT30S` a `PT30M` |
| `keepaliveTime` | `PT0S` ou `PT30S` a `PT5M`, sempre inferior a `maxLifetime` |

Os profiles são seeds materializados, não herança. Nesta versão, copiam:

| Profile | `minimumIdle` | `maximumPoolSize` | `connectionTimeout` | `validationTimeout` | `idleTimeout` | `maxLifetime` | `keepaliveTime` |
| --- | ---: | ---: | --- | --- | --- | --- | --- |
| `SMALL` | `0` | `6` | `PT5S` | `PT2S` | `PT30S` | `PT5M` | `PT0S` |
| `STANDARD` | `0` | `8` | `PT5S` | `PT2S` | `PT1M` | `PT10M` | `PT0S` |
| `ROBUST` | `2` | `10` | `PT5S` | `PT2S` | `PT2M` | `PT10M` | `PT0S` |

`CUSTOM` exige os sete valores completos. Estes bounds e seeds são contrato
repository-local; não declaram sizing, SLO ou adequação de produção.

## 2.4 Sizing por carga, não por rótulo comercial

O porte comercial orienta a escolha inicial, mas não dimensiona o pool sozinho.
O mínimo seguro por tenant será derivado de:

```text
maximumPoolSize_t >= C_t + R_t + O_t

C_t = concorrência de transações ordinárias admitida antes do banco
R_t = pico de conexões adicionais simultâneas por REQUIRES_NEW/fluxos equivalentes
O_t = reserva para administração, scheduler e recuperação; inicialmente >= 2
```

Todo admission controller que limite fluxos consumidores de banco deverá ser
tenant/revision-aware. A redução de `maximumPoolSize` só poderá ser committed
depois de o gate compatível estar efetivo; a ampliação do gate só ocorrerá depois
do pool maior. O `TenantConversationProcessingCoordinator`, hoje configurado uma
vez globalmente, faz parte dessa mudança coordenada.

Nesta entrega, a concorrência conversacional não é um oitavo campo editável. Ela
é derivada, persistida e incluída no hash da mesma revisão imutável:

```text
conversationConcurrencyLimit_t =
  min(8, floor((maximumPoolSize_t - 2) / 2))
```

O teto local `8` é um guardrail, não sizing produtivo. Aumentos aplicam primeiro o
pool e depois o gate; reduções aplicam primeiro o gate e depois o pool. Alterar a
fórmula ou o teto exige novas revisões, nunca muda retroativamente snapshots já
committed. O piso local de `maximumPoolSize=6` permanece nesta entrega; valores
menores exigem uma revisão normativa e inventário que prove `C`, `R` e `O`.

Seeds iniciais candidatos, sujeitos ao requisito e ao benchmark:

| Seed | Cenário inicial | `minimumIdle` | `maximumPoolSize` candidato |
| --- | --- | ---: | ---: |
| `SMALL` | política atual `C=2`, `R=2`, `O=2`; lazy | `0` | `6` |
| `STANDARD` | gate tenant-aware, exemplo `C=3`, `R=3`, `O=2` | `0` | `8` |
| `ROBUST` | gate tenant-aware, exemplo `C=4`, `R=4`, `O=2` | `1` ou `2`, somente com evidência | `10` |

Um `SMALL=4` só será válido se o gate tenant-aware já limitar `C=1`, o inventário
provar `R=1` e `O=2` permanecer suficiente. Com o gate corrente de duas conversas
e duas conexões potenciais por fluxo, `6` é o piso; o rótulo comercial nunca pode
reduzir esse invariante.

Esses números não são prova de capacidade, SLA ou promessa por plano comercial.
Um tenant grande pode continuar com pool pequeno se admission control e carga
medida assim indicarem; um tenant pequeno com jobs concorrentes pode precisar de
reserva maior.

## 2.5 Orçamento global de conexões

Toda revisão, inclusive redução de tamanho ou mudança somente de timeout, deverá
passar por admissão atômica e revalidar a política de concorrência no cluster
PostgreSQL ao qual o tenant está vinculado. Considerando que o estado permanente
já usa o máximo da nova geração, a conta será:

```text
replicasMax * (platformPoolMax + sum(nextPermanentMaximumPoolSize_t))
  + sum(activeSwapReservation_t)
  + migrationAndAdminReserve
  + emergencyHeadroom
  <= safePostgresConnectionBudget

activeSwapReservation_t = replicasMax * oldMaximumPoolSize_t, para uma troca O -> N
```

O cálculo será feito por cluster e usará o número máximo de réplicas admitido pelo
deploy, não apenas as réplicas atualmente saudáveis. A reserva de swap cobre
exatamente `O + N` por réplica durante a coexistência, soma trocas simultâneas e
permanece durável/fenced até as réplicas vivas confirmarem `DRAINED`. Expiração de
heartbeat isoladamente não libera capacidade: runtime desaparecido só será
retirado da conta após evidência confiável de terminação e ausência de suas sessões
PostgreSQL, ou intervenção operacional auditada. Duas mudanças concorrentes não
poderão reservar a mesma capacidade.

Scale-out acima de `replicasMax` falhará no preflight/readiness até que o orçamento
seja recalculado. O allocator também limitará uma reserva por tenant e bloqueará
novo swap enquanto houver geração drenando.

O fencing lease do runtime terá deadline verificado localmente na readiness e em
toda aquisição tenant. Se a renovação falhar ou o token/epoch deixar de ser
vigente, a instância falhará fechado para novo tráfego tenant, colocará pools
locais em quarentena/drenagem e exigirá novo registro seguido de reconcile antes
de voltar a adquirir conexão. Assim, uma réplica pausada ou particionada não pode
retomar uma geração stale. A reserva só será liberada depois do `DRAINED` ou da
combinação entre fencing efetivo, terminação comprovada e ausência das sessões no
PostgreSQL.

`minimumIdle=0` reduz consumo normal, mas não autoriza overcommit do máximo sem um
mecanismo adicional aprovado. Se a soma se tornar inviável em escala, PgBouncer,
separação por clusters ou outro pooler poderá ser avaliado em decisão própria.

Uma mudança que exceda o orçamento será rejeitada com erro explícito e capacidade
restante; nunca será aplicada parcialmente ou reduzida em silêncio.

Os fatos de topologia entram por uma porta explícita do contexto Tenant. Em
runtime não local, `clusterId`, `replicasMax`, `deploymentEpoch` e
`runtimeInstanceId` devem ser valores imutáveis injetados pela integração do
orquestrador e validados no startup; não existem defaults inferidos. Terminação
exige evidência da identidade/epoch exatos no orquestrador **e** ausência das
sessões PostgreSQL correspondentes. Heartbeat expirado, relógio local ou shutdown
hook isolados nunca bastam.

Como infraestrutura externa está fora do escopo aprovado, a implementação local
entrega a porta, validação fail-closed e adapters determinísticos somente em
testes. Sem adapter autoritativo homologado, membership/fencing, prepare e swap
continuam `OFF`, e readiness falha se alguém tentar ligá-los. Essa limitação não
reabre a decisão de contrato; ela é um gate operacional explícito.

## 2.6 Autorização e API de plataforma

Somente `ROLE_SUPER_ADMIN` poderá consultar histórico completo, propor, aplicar ou
reverter configuração de pool. `ROLE_TENANT_ADMIN`, `ROLE_TENANT_AUDIT`, usuários
operacionais e serviços sem capability técnica explícita serão negados.

Essa autorização usará o RBAC estático aceito pelo ADR-0009 e
`@PreAuthorize("hasRole('SUPER_ADMIN')")` como segunda barreira no backend. A UI
apenas refletirá a decisão do servidor.

A operação HTTP será de control plane e usará exclusivamente
`platformEntityManagerFactory`/`platformTransactionManager`. Para não colidir com
`BR-TEN-016`/`AC-TEN-013` do REQ-00031, ela ficará fora do namespace
`/tenants/{tenantId}/**`: o identificador final será somente o alvo administrativo,
não um `TenantContext` implícito. O request de Super Admin não abrirá datasource
tenant e rejeitará `X-Tenant-ID`/contexto conflitante.

A abertura e o probe do banco serão assíncronos, executados por reconciliador
interno confiável após o commit, usando um binding estruturado carregado do
control plane e fencing token — nunca o token ou a impersonação do usuário. Antes
de iniciar candidato, conexão ou transação, o worker instalará um escopo técnico
tipado derivado de `tenant_id + database_binding_epoch` e sempre o limpará em
`finally`, preservando `BR-TEN-007/022` do REQ-00031. O novo requisito deverá
classificar explicitamente essa rota como operação de plataforma e atualizar as
matrizes RBAC. Se Produto optar por uma rota sob `/tenants/{tenantId}/**`, a
impersonação continuará obrigatória.

Superfície REST aprovada pelo REQ-00047 e materializada no recorte local:

| Método | Destino planejado | Semântica |
| --- | --- | --- |
| `GET` | `/api/v1/platform/tenant-pool-policies/{tenantId}` | Retorna revisão desired/committed, rollout por runtime, valores não secretos e capacidade. |
| `PUT` | `/api/v1/platform/tenant-pool-policies/{tenantId}` | Persiste intenção/revisão completa e retorna operação assíncrona, com `If-Match`, idempotência e `reason`. |
| `POST` | `/api/v1/platform/tenant-pool-policies/{tenantId}/rollback` | Cria nova revisão a partir de snapshot anterior do mesmo tenant. |

O payload não exporá nem aceitará credenciais, URL JDBC, slug ou propriedades
arbitrárias. Respostas e erros seguirão o ADR-0012/RFC 7807. Conflito de versão ou
capacidade será distinguível de parâmetro inválido e falha de conectividade.

## 2.7 Aplicação blue/green e drenagem

Uma atualização seguirá esta ordem:

1. autenticar e autorizar `ROLE_SUPER_ADMIN` no control plane;
2. validar tenant, provisionamento, revisão esperada, allowlist, relações,
   admission policy e orçamento; persistir revisão/head e um único `intent_id`;
3. publicar a intenção após commit; o reconciliador interno adquire reserva
   durável/fenced, carrega binding estruturado com epoch vigente e instala o
   contexto técnico do tenant antes de qualquer conexão;
4. cada runtime cria do zero candidato exclusivo e valida configuração efetiva,
   `SELECT 1`, `current_database()`, binding e readiness das migrations, sem
   executar Flyway como efeito colateral; então persiste `READY`;
5. quando a política de readiness das réplicas vivas for satisfeita, o controller
   promove `desired_revision` a `committed_revision` por CAS;
6. em cada runtime e sob o lock curto do slot, um único ponto de linearização
   fecha o gate de aquisições antigo e troca atomicamente o ponteiro ativo;
7. persistir `SWAPPED` imediatamente após o CAS, antes de aguardar drain, para que
   replay/reconcile não reaplique a mesma revisão;
8. aguardar leases da única geração antiga retornarem, remover instrumentação,
   fechar o pool e persistir `DRAINED`;
9. marcar rollout `CONVERGED`, finalizar a intenção auditável e liberar a reserva
   transitória quando todos os runtimes vivos convergirem.

O `TenantPoolSlot` será estável e a aquisição será lease-aware. Ler a geração
ativa, validar seu gate e incrementar a lease ocorrerão atomicamente sob o mesmo
protocolo de sincronização usado pelo swap (por exemplo, read/write lock curto ou
CAS com retry). Assim, nenhuma thread poderá ler a geração antiga antes do swap e
registrar lease nela depois do fechamento do gate. A lease será registrada
**antes** de chamar `HikariDataSource#getConnection()` e liberada exatamente uma
vez no `close`, timeout, interrupção ou exceção. Observar apenas
`activeConnections == 0` depois de trocar um `DataSource` bruto não é suficiente,
pois existe corrida entre lookup, `getConnection()` e fechamento.

Drenagem além do prazo gerará estado degradado e alerta, manterá sua quota
reservada e bloqueará a próxima troca do tenant. Ela não autorizará fechar
abruptamente transação em voo. Uma política de aborto em shutdown ou emergência
exigirá runbook e decisão operacional separados.

Falha antes do commit fechará somente candidatos e manterá a geração committed do
**mesmo tenant**. Depois do commit, runtime ainda não convergido poderá manter sua
geração anteriormente válida, com binding inalterado, em `DEGRADED`, enquanto o
reconcile aplica a revisão committed. Instância nova sempre constrói a committed;
se não conseguir, não recebe tráfego tenant. Evento acelera a convergência, mas
polling durável com jitter será o safety net. Evento duplicado ou antigo será
ignorado por revisão e fencing token.

Uma atualização por tenant será aplicada por vez. O lock por tenant será curto e
não ficará aberto durante criação ou probe do pool; compare-and-set impedirá que
um candidato antigo seja publicado por último. A reserva do orçamento global terá
controle concorrente próprio.

## 2.8 Fail-closed e ausência de compartilhamento

Workload tenant-aware sem contexto, tenant desconhecido, ausência de qualquer
geração committed válida ou binding divergente falhará antes da conexão. Uma
desired revision que falhou ou ainda não foi committed **não** invalida o LKG já
aplicado do mesmo tenant; essa divergência gera `DEGRADED` e reconcile. O LKG não
expira por relógio, mas deixa de ser válido em suspensão/offboarding, revogação
explícita ou mudança do binding epoch. Não haverá fallback para:

- pool da plataforma;
- pool ou configuração de outro tenant;
- perfil/default global em runtime;
- geração candidata ainda não validada;
- revisão antiga de outro tenant.

Operações reais de plataforma continuarão usando o persistence unit de plataforma,
fora do `TenantRoutingDataSource`. A implementação removerá o fallback AS-IS de
`TenantRoutingDataSource` para `defaultDs`; invocar esse router sem contexto
falhará, enquanto o persistence unit da plataforma continuará explícito e
separado. O LKG será sempre uma revisão committed do mesmo tenant.

Esta regra substitui explicitamente apenas a cláusula de fallback legado do
ADR-0019 §7 e o sizing uniforme do ADR-0002 quando aplicado a pools dedicados por
tenant. A decisão central do ADR-0019 — banco e pool únicos por tenant — e todas as
demais regras dos dois predecessores permanecem vigentes.

## 2.9 Auditoria e observabilidade

Cada comando produzirá exatamente um registro administrativo canônico por
`intent_id`, criado como `REQUESTED` e finalizado idempotentemente com `APPLIED`,
`FAILED`, `DENIED` ou `ROLLED_BACK`. Ele conterá ator, tenant-alvo, revisão
anterior/nova, diff numérico, hash, motivo, resultado, correlation/trace ID e
timestamps. Acknowledgements `READY`, `SWAPPED` e `DRAINED` são lifecycle
operacional idempotente e não criam nova auditoria da intenção, em conformidade
com `BR-TEN-025`.

Não serão registrados senha, URL JDBC, secret reference, payload arbitrário,
exception message crua, nome ou documento do escritório. Logs e `poolName` AS-IS
que contêm slug/identidade serão substituídos por identificadores opacos de
operação e dimensões sanitizadas. Retenção e purge do audit/lifecycle obedecerão
owner, finalidade, prazo e legal hold aprovados conforme `BR-TEN-026/027` e
`AC-TEN-021/022`.

Prometheus/Micrometer observará somente dimensões finitas e allowlisted, como
`profile`, `state`, `operation` e `outcome`. `tenantId`, UUID, slug, database,
revision, `poolName` e qualquer identificador de recurso são proibidos como labels,
conforme o ADR-0012. Pools dinâmicos não serão ligados diretamente a um registry
Hikari que publique `poolName` tenant-specific sem agregação/sanitização.

Métricas agregadas mínimas:

- pools ativos, em aplicação, drenagem e falha;
- utilização, espera, timeout e duração de aquisição por buckets finitos;
- duração e falhas de apply/reconcile/drain;
- orçamento total reservado, disponível e rejeições por capacidade;
- quantidade de runtimes com drift de revisão, sem identidade em label.

Diagnóstico por tenant ficará em endpoint administrativo protegido, audit store,
logs ou traces de acesso controlado. Métricas aposentadas junto com uma geração
serão removidas para evitar vazamento e cardinalidade crescente.

## 2.10 Onboarding, backfill e rollback

Todo novo tenant receberá uma revisão completa antes de o pool se tornar roteável.
O onboarding continuará publicando o datasource somente após grants e Flyway,
conforme REQ-00031, mas mudará a ordem AS-IS: metadata e revisão inicial serão
persistidos antes de build/migration/publicação. Compensação idempotente deverá
remover registro, pool e banco incompletos ou marcar operação recuperável sem
deixar datasource roteável sem chave de plataforma.

Tenants existentes serão backfilled com o **valor efetivo resolvido no ambiente no
cutover**, sem mudança silenciosa. No código atual, os defaults explícitos são
`minimumIdle=0`, `maximumPoolSize=6`, `idleTimeout=30s` e `maxLifetime=5min`, mas
override ambiental de `maximum-size` prevalece e todos os getters efetivos deverão
ser materializados. A migration não deduzirá baseline a partir do incidente
histórico nem de valores planejados.

O rollout deverá usar shadow/readiness para provar que todos os tenants
provisionados possuem revisão válida antes de tornar a ausência fail-closed. Não
haverá dual-read permanente nem fallback pós-cutover.

Rollback de configuração cria nova revisão para o mesmo tenant e usa o mesmo
processo blue/green. Durante uma janela de estabilização limitada, a reserva
mantém capacidade para `replicasMax * (old + new)`, mesmo depois do drain, para que
um rollback continue admissível no orçamento. Ele ainda exige criação, probe,
commit e drain, portanto não é instantâneo. Depois de liberada essa reserva,
rollback volta a passar pelo orçamento e é best-effort, podendo ser rejeitado por
capacidade. A primeira entrega não incluirá alteração em massa. Uma operação bulk
futura deverá criar, validar e auditar uma revisão independente por tenant e
preservar blast radius.

A janela local de estabilização é `PT15M`, contada somente depois de a operação
atingir `CONVERGED`; antes disso, a reserva old+new permanece sem expiração. Ao
fim da janela, o reconciliador pode liberar a reserva, mas rollback continua
possível mediante nova admissão de capacidade. O valor pode ser estreitado por
ambiente, nunca ampliado sem nova revisão normativa.

Retenção e legal hold ficam definidos assim para os artefatos desta decisão:

| Artefato | Retenção mínima local |
| --- | --- |
| revisão, head histórico, intent terminal e audit administrativo | `P5Y` a partir do evento/estado terminal |
| application ack, membership histórico e reservation liberada | `P90D` após estado terminal/liberação |
| chave/hash de idempotência | `PT24H` após a última resposta reproduzível; o audit terminal permanece pela regra de cinco anos |

Legal hold congela qualquer purge dos artefatos alcançados até liberação por
autoridade externa a esta API. A primeira entrega não executa purge: qualquer job
de retenção nasce `OFF`, e estas regras orientam schema, classificação e testes
sem criar endpoint de exclusão.

## 2.11 Componente não funcional: cache derivado da política

Este ADR possui cinco componentes normativos de responsabilidade complementar:

| Componente | Natureza | Responsabilidade |
| --- | --- | --- |
| [REQ-00047](../product/requirements/REQ-00047-super-admin-tenant-pool-policy-administration.md) | RF | Comandos, consultas, revisão, aplicação e rollback da política de pool. |
| [REQ-00048](../product/requirements/REQ-00048-tenant-pool-policy-cache-isolation-resilience.md) | NFR | Isolamento, consistência, resiliência e observabilidade da projeção em cache dessa política. |
| [REQ-00049](../product/requirements/REQ-00049-tenant-pool-policy-authorized-test-rollout.md) | NFR técnico | Habilitação local opt-in, coortes A/B, envelope de capacidade, smoke, kill switch e gates para planejar rollout. |
| [REQ-00051](../product/requirements/REQ-00051-tenant-pool-policy-managed-runtime-environments.md) | NFR técnico | Operação gerenciada sem restart, membership renovável, bootstrap committed e contrato fail-closed por ambiente. |
| [REQ-00052](../product/requirements/REQ-00052-tenant-pool-policy-controlled-hml-prd-rollout.md) | NFR operacional | Gates sequenciais de capacity proof, HML, canary, observabilidade, rollback, go/no-go e promocao posterior para PRD. |

O store versionado no banco da plataforma permanece a única autoridade. Cache é
uma projeção opcional, descartável e substituível atrás de porta do contexto
Tenant. Cada entrada deverá estar vinculada ao `tenantId`, revisão, binding epoch,
schema e hash efetivo; hit divergente ou corrupto equivale a miss seguro.

Commit, rollback, suspensão ou remoção de A invalida somente A. O caminho
tenant-scoped não usará `allEntries=true`, `Cache.clear`, varredura global de
chaves ou namespace global que também invalide B. Perda de evento converge por
mismatch de revisão e TTL absoluto sem aplicar estado stale. Leitura, cópia,
retry ou falha não renovam TTL.

Miss ou indisponibilidade consulta a fonte durável. Cache/LKG jamais autoriza
revisão, ampliação de capacidade, reserva, candidate, commit, swap ou rollback.
Recomposição concorrente será bounded por tenant para que um escritório maior não
cause stampede nem bloqueie outro por lock global.

Este componente não transforma o ADR em governança geral de cache: TTL, quota,
peso, LRU/LFU, perfil de cache por porte, endpoint de eviction e governança da
instância/infraestrutura Redis permanecem fora. Os perfis `SMALL`, `STANDARD` e `ROBUST` continuam
dimensionando somente a política de conexões materializada pelo REQ-00047.

### 2.11.1 Política selecionada de uso e configuração

A política do cache derivado fica congelada pelo NFR REQ-00048 nos seguintes
termos, sem criar uma segunda decisão arquitetural:

| Aspecto | Decisão |
| --- | --- |
| Provider | Redis compartilhado entre runtimes, sem L1 Caffeine; adapter `NOOP`/store-only quando `cache-enabled=false` ou o provider não estiver disponível. |
| Conteúdo | Somente o corpo imutável da revisão `committed`; head, desired, pending, candidate, intent, reservation e audit não são cacheados. |
| Identidade | Chave exata `tenant-pool-policy:v1:{tenantId}:b{bindingEpoch}:r{revision}` e envelope com tenant, revisão, binding, hash, schema, `loadedAt` e `expiresAt`. |
| Footprint | No máximo uma entrada intencional por tenant, JSON tipado UTF-8 de até `8192` bytes, sem segredo ou PII. |
| TTL | Global `PT5M`, configurável entre `PT30S` e `PT15M`, com jitter somente redutor de `0%..10%`; leitura e falha não renovam expiração. |
| Eviction | Efeito after-commit usa `UNLINK` somente na chave anterior exata; são proibidos clear, scan, namespace global e warmup/flush global. |
| Falha | Miss, timeout, corrupção ou breaker aberto fazem bypass para o store durável; cache nunca autoriza revisão, capacidade ou efeito runtime. |
| Rebuild | Single-flight local por chave, uma leader por tenant/runtime, limiter fair `min(4, max(1, floor(platformMaximumPoolSize / 4)))`, fila `2 * limiter` e espera máxima `PT2S`. |
| Budget Redis | Uma operação possui `PT200MS`, sem retry inline; breaker local usa janela 10, mínimo 5, limiar 50%, abertura `PT10S` e uma chamada half-open. |
| Habilitação | `cache-enabled=false` por default; fora do local exige prova `activeTenants * (maximumEntryBytes + overhead medido) <= 25%` do budget Redis aprovado. |

O porte do escritório **não** parametriza TTL, quota, número de entradas ou
provider. Escritórios maiores e menores diferem exclusivamente no snapshot
Hikari persistido pelo RF REQ-00047. Isso mantém footprint previsível e impede
que volume comercial seja confundido com identidade, autoridade ou isolamento
do cache.

Configuração backend local materializada default-off; o profile de smoke do
REQ-00049 não habilita este cache:

```properties
app.tenant-pool-policy.cache-enabled=false
app.tenant-pool-policy.cache.provider=REDIS
app.tenant-pool-policy.cache.ttl=PT5M
app.tenant-pool-policy.cache.ttl-jitter-percent=10
app.tenant-pool-policy.cache.operation-timeout=PT0.2S
app.tenant-pool-policy.cache.rebuild-wait-timeout=PT2S
app.tenant-pool-policy.cache.maximum-entry-bytes=8192
```

## 2.12 Componente operacional: teste autorizado e rollout posterior

O REQ-00049 especializa a ativação sem criar nova decisão. `application.yml`
continua dark. Somente o profile `tenant-pool-smoke`, combinado com `dev` ou
`test`, pode ligar efeitos e apenas quando recebe duas coortes explícitas e
disjuntas:

| Coorte | Permissão | Regra inicial |
| --- | --- | --- |
| A mutável | GET, PUT, rollback e reconcile | um UUID sintético dedicado |
| B controle | somente GET/diagnóstico | um UUID sintético distinto; nenhum candidate/swap/drain |
| qualquer C | nenhuma | capability indisponível antes de store ou runtime |

O envelope local aprovado é conservador e não produtivo:

```text
safePostgresConnectionBudget = 80
replicasMax = 1
platformPoolMax = 10
environmentMaximumPoolSize = 10
migrationAndAdminReserve = 5
emergencyHeadroom = 15

1 * (10 + 2 * 10) + 10 + 5 + 15 = 60 <= 80
```

O cálculo cobre os dois tenants no teto e uma geração antiga durante um swap.
Valores ausentes, teto acima de `10`, coortes vazias/sobrepostas, runtime evidence
incompleta, lease sem margem ou profile compartilhado falham no startup. Cache,
onboarding, backfill, shadow, fail-closed cutover e external release ficam `OFF`.

Kill switch é sequencial: bloquear novas mutações e candidates, permitir que
swap/drain já committed termine, então desligar scheduler, revision apply,
authority, fencing, API e observabilidade. Rollback de policy continua sendo nova
revisão; conexão em voo nunca recebe force-close.

Capacidade de DEV compartilhado, HML e PRD permanece `NOT_CONFIGURED/BLOCKED` até
inventário e benchmark próprios. O plano de rollout futuro exige budget aprovado
por SRE/DBA, coorte sintética, observabilidade, canary mínimo, janela de observação,
go/no-go humano e rollback; esta revisão não executa nem autoriza essas etapas.

## 2.13 Componente operacional: runtime gerenciado por ambiente

O REQ-00051 substitui somente a limitacao do smoke como unica forma executavel.
`DARK` permanece o default comum e `LOCAL_SMOKE` continua disponivel para ensaios,
mas `MANAGED_ENVIRONMENT` passa a ser o modo duravel. Nesse modo, identidade de
cluster/deployment/runtime e configuracao ambiental sao entradas; fencing token,
deadline e row version sao autoridade do control plane e renovados por heartbeat
CAS. Perda de autoridade derruba readiness e impede novas aquisicoes antes da
expiracao.

O registry inicia e repara cada tenant pela revisao `committed`, hash e binding
epoch. Em fase ativa nao existe fallback ao baseline legado. Leitura/mutacao da
UI alcanca somente tenants provisionados cobertos; capacidade de cluster continua
fora da UI e sob ownership de SRE/DBA.

DEV local pode usar bootstrap sintetico explicitamente marcado. HML e PRD recebem
o mesmo contrato tipado, continuam `DARK` por default e so aceitam modo gerenciado
com budget persistido medido e identidade propria. O envelope `80/10/5/15/1` do
smoke/DEV nunca e fallback para ambiente externo. Esta decisao estrutura o
artefato, mas nao executa deploy nem declara readiness de HML/PRD.

O REQ-00052 governa o rollout ambiental futuro sem alterar essa protecao:
HML deve ser comprovado antes de PRD, e cada ambiente exige IP-INFRA, capacity
proof, canary, observabilidade, rollback e gates humanos proprios. A aprovacao
repository-local de 2026-09-02 nao promove `DARK`, nao declara ambiente pronto e
nao substitui as transicoes obrigatorias de cada IP-INFRA.

---

# 3. Decision Drivers

- isolamento de configuração e de runtime entre tenants;
- ajuste proporcional à concorrência real de escritórios pequenos e grandes;
- preservação de transações em voo durante reconfiguração;
- continuidade após restart e convergência em múltiplas instâncias;
- prevenção de exaustão do `max_connections` compartilhado;
- autorização exclusiva e auditável do Super Admin;
- ausência de segredos e propriedades arbitrárias na API;
- compatibilidade com database-per-tenant e pool único por tenant;
- observabilidade sem labels de alta cardinalidade;
- rollback limitado ao próprio tenant e sem fallback cross-tenant.

---

# 4. Considered Options

## Option 1: Um pool/configuração global para todos os tenants

Prós:

- implementação simples;
- baixo custo de gerenciamento.

Contras:

- não diferencia carga;
- uma alteração alcança todos os tenants;
- contradiz o isolamento e o objetivo solicitado.

## Option 2: Defaults globais mais overrides nullable resolvidos em runtime

Prós:

- reduz dados repetidos;
- facilita mudar todos os tenants sem migration.

Contras:

- alteração do default muda tenants sem revisão própria;
- fallback torna a configuração efetiva ambígua;
- dificulta auditoria, rollback e reprodução.

## Option 3: Mutar o Hikari ativo in-place

Prós:

- evita criar outro pool;
- aparente aplicação imediata.

Contras:

- apenas parte das propriedades possui mutação segura em runtime;
- produz estado intermediário observável;
- rollback e concorrência ficam frágeis;
- não valida o conjunto completo antes da ativação.

## Option 4: Snapshot versionado por tenant com geração blue/green - Selected

Prós:

- isolamento explícito de dados e objetos;
- validação completa antes do swap;
- transações em voo podem drenar;
- histórico, idempotência, reconciliação e rollback verificáveis;
- permite sizing diferente sem compartilhar estado mutável.

Contras:

- exige versionamento, slots, leases, reconciliação e headroom temporário;
- aumenta complexidade operacional e de testes.

## Option 5: Reiniciar a aplicação a cada alteração

Prós:

- todos os pools nascem da configuração persistida;
- lifecycle simples no processo.

Contras:

- amplia indisponibilidade e blast radius para todos os tenants;
- não atende ajuste seguro e localizado;
- não elimina corrida ou orçamento incorreto.

## Option 6: PgBouncer como única solução

Prós:

- reduz conexões físicas e pode ampliar escala do cluster.

Contras:

- não oferece política por tenant, RBAC, versionamento ou auditoria;
- não impede configuração cruzada na aplicação;
- possui semântica própria que exige avaliação de compatibilidade.

---

# 5. Decision Outcome

A Option 4 foi selecionada como decisão aceita por oferecer a menor unidade segura de
mudança: uma revisão e uma geração pertencentes a um tenant. Ela preserva a
topologia do ADR-0019, evita herança viva e permite que falha de configuração de A
não altere pool, versão ou disponibilidade de B.

O custo aceito é a complexidade de lifecycle e capacidade. Esse custo é necessário
porque fechar/recriar imediatamente pode interromper transações, e porque a soma
dos máximos continua sendo risco compartilhado no PostgreSQL mesmo com pools
logicamente exclusivos.

---

# 6. Consequences

## Positive Consequences

- Tenants pequenos podem permanecer lazy e econômicos.
- Tenants maiores podem receber capacidade comprovada sem alterar os demais.
- Restart reconstrói cada pool a partir de uma revisão durável e reproduzível.
- Falha de candidato mantém a última geração válida do mesmo tenant.
- Atualização e rollback possuem trilha administrativa completa.
- O orçamento global evita que robustez local cause indisponibilidade sistêmica.

## Negative Consequences

- Troca blue/green consome conexões e memória temporárias.
- Registry, API e persistence exigem mais estados, testes e reconciliação.
- Uma configuração fail-closed ausente torna o tenant indisponível até reparo.
- Scale-out multiplica o máximo configurado e exige disciplina no deploy.
- Perfis e limites ambientais precisarão de benchmark e revisão contínua.

## Neutral Consequences

- Valores iguais continuam permitidos, mas serão cópias independentes.
- Configuração operacional fica no control plane, embora o banco de negócio seja
  tenant-local.
- `minimumIdle=0` continua recomendado para economia, não como prova de capacidade.
- PgBouncer e cluster sharding permanecem evoluções futuras independentes.

---

# 7. Impact

## Architecture and Module Boundaries

- `contexts.tenant` possuirá, como destino planejado, comando administrativo,
  persistência versionada, RBAC, histórico e auditoria da política.
- `config.persistence.routing` continuará dono da tradução para Hikari, do slot,
  do candidato, do swap, do drain e do reconcile.
- `shared.tenancy` poderá expor somente um contrato técnico estreito e neutro;
  `HikariConfig`/`HikariDataSource` não atravessarão a API de módulo.
- Bounded contexts consumidores continuarão adquirindo leases pelo router e não
  conhecerão parâmetros nem reterão `DataSource` bruto.
- O router tenant deixará de usar `defaultDs` sem contexto; operações de plataforma
  continuarão no persistence unit separado.
- Admission controllers, inicialmente o de conversas, passarão a resolver limites
  por tenant/revisão e respeitarão a ordem segura ao reduzir/ampliar capacidade.
- O module registry só será atualizado quando a arquitetura AS-IS realmente mudar.

## Data Architecture

- Revisão imutável, head desired/committed, aplicação por runtime, reserva de
  capacidade e intent/audit ficarão separados no banco de plataforma.
- Constraints, optimistic locking, fencing e heartbeat impedirão revisão
  duplicada, lost update e acknowledgement de runtime morto.
- Onboarding persistirá metadata/revisão antes de publicar o pool e terá
  compensação idempotente para estados parciais.

## Security

- `ROLE_SUPER_ADMIN` exclusiva, backend autoritativo e default deny.
- API em namespace de plataforma não depende de impersonação nem abre banco do
  tenant; o reconciliador interno é o único responsável por build/probe/apply.
- Payload tipado, bounds ambientais, razão obrigatória e ausência de propriedades
  de conexão sensíveis.

## Operations and Observability

- Novo orçamento por cluster, preflight de deploy, reserva fenced de `O + N` e
  limite de uma geração draining por tenant.
- Alertas para saturação, timeout, apply/reconcile falho, drift e drain prolongado.
- Detalhe tenant-scoped somente em canal protegido, nunca em label de métrica.
- Logs/pool names deixarão de publicar slug ou identificador de tenant.

## Development Process

- REQ-00047 (RF), REQ-00048 (NFR) e matrizes RBAC reconciliadas precedem implementação.
- Mudança transversal exige plano persistido.
- Testes de A/B, concorrência, PostgreSQL real e gates arquiteturais tornam-se
  obrigatórios para a implementação.

---

# 8. AI Agent Considerations

- Agentes não poderão ampliar a autorização backend local nem inferir readiness,
  deploy ou produção a partir do estado `Accepted`.
- Nenhum agente inferirá valores de produção a partir dos seeds ilustrativos.
- Código gerado deverá criar objetos novos por tenant/revisão e provar ausência de
  aliasing.
- Agentes não poderão ler ou registrar credenciais para construir exemplos ou
  testes; fixtures serão sintéticas.
- Falha de Docker, benchmark, capacity proof ou revisão humana será reportada como
  pendência, nunca convertida em sucesso.
- Alterações de runtime preservarão testes, gates e limites de módulo definidos
  pelos standards do backend.

---

# 9. Implementation Plan

## Phase 0 - Governança aprovada e desenho executável

1. Versionar o RF REQ-00047 e o NFR REQ-00048 aprovados e reconciliar REQ-00003/REQ-00004.
2. Capturar os getters efetivos e overrides do baseline no ambiente de cutover.
3. Persistir plano e implementation plans para o backend local, API, schema,
   rollout local e rollback; frontend e infraestrutura permanecem fora do escopo.
4. Definir bounds por ambiente e orçamento seguro por cluster/replica.

## Phase 1 - Store e onboarding

1. Criar migrations aditivas no banco de plataforma.
2. Implementar revisão, head, estado por runtime, reserva e intent/audit.
3. Implementar porta de cache opcional, envelope tenant/revision-aware,
   invalidação exata e fallback para o store, mantendo-a default-off.
4. Reordenar onboarding: metadata/revisão, migration e só então publicação, com
   compensações idempotentes.
5. Backfill dos valores efetivos sem mudança comportamental e executar
   shadow/readiness.

## Phase 2 - Lifecycle do registry

1. Introduzir `TenantPoolSlot` estável e geração lease-aware.
2. Separar migration/onboarding de reconfiguração de pool.
3. Implementar prepare/READY, commit, CAS linearizável, SWAPPED, drain, DRAINED e
   reconcile por runtime.
4. Remover exposição/retenção de `DataSource` bruto e o fallback `defaultDs` do
   router tenant.
5. Tornar gates de admissão tenant/revision-aware e validar ordem de transição.

## Phase 3 - Administração e auditoria

1. Implementar use case e endpoints de plataforma protegidos.
2. Adicionar idempotência, `If-Match`, razão e erros RFC 7807.
3. Auditar uma vez por `intent_id`; manter lifecycle operacional separado.
4. Implementar rollback como nova revisão.

## Phase 4 - Capacidade e observabilidade

1. Implementar reserva atômica/fenced, heartbeat e preflight de réplicas.
2. Instrumentar métricas agregadas sem pool/tenant labels.
3. Sanitizar `poolName`/logs, criar diagnóstico protegido e alertas operacionais.
4. Executar benchmark sintético para SMALL/STANDARD/ROBUST.

## Phase 5 - Cutover

1. Provar cobertura de todos os tenants provisionados.
2. Ativar leitura da configuração versionada em coortes sintéticas.
3. Ensaiar candidate failure, crash, drift, drain preso, scale-out e rollback.
4. Remover dual-read/fallback apenas após readiness e sign-off.

Rollback da entrega será forward-only: desabilitar apply de novas revisões,
preservar store/histórico, manter a última geração segura por tenant e corrigir por
migration/revisão aditiva. Nenhuma rollback migration apagará políticas ou audit.

---

# 10. Validation

## Structural and Unit Tests

- duas configurações iguais geram snapshots, configs, pools e slots de identidades
  distintas;
- alterar A não muda valores, revisão, objeto ou rollout de B;
- parser rejeita campo livre, valor fora de bound e relações inválidas;
- validação rejeita normalização Hikari cujos getters efetivos divergem do hash;
- stale revision, comando duplicado e binding epoch divergente não publicam pool;
- revisão imutável não contém status e cada runtime mantém acknowledgement próprio;
- rollback cria revisão monotônica do mesmo tenant;
- cache put/get/evict/expire/rebuild de A não altera chave, TTL, valor ou lock de B;
- mismatch de revisão/binding/hash rejeita hit e leitura não renova TTL;
- cache/LKG nunca autoriza efeito ampliativo sem fonte durável atual;
- Modulith e Clean Architecture permanecem sem violação.

## Integration Tests

- PostgreSQL real com bancos A/B prova `current_database()` correto;
- tenant sem contexto/config/pool falha fechado, sem tocar plataforma ou B;
- candidato não roteia antes de probe/readiness;
- corrida entre lookup e `getConnection()` prova lease anterior ao Hikari e release
  exatamente uma vez em sucesso, close, timeout, interrupção e exceção;
- o ponto de linearização fecha o gate antigo e troca o ponteiro atomicamente;
- transação em voo termina na geração antiga e nova aquisição usa a committed;
- falha do candidato fecha somente o candidato e preserva o pool ativo;
- concorrência de duas mudanças no mesmo tenant escolhe apenas a revisão vigente;
- ampliações concorrentes A/B não excedem orçamento;
- réplicas divergentes, restart e evento perdido convergem desired/committed e
  acknowledgements por reconcile;
- worker instala contexto técnico antes do probe/transação e o limpa em sucesso,
  falha, timeout e interrupção;
- partição ou pausa além do fencing deadline faz readiness/aquisição falharem;
  retomada com token/revisão stale não serve tráfego até novo registro/reconcile;
- `SWAPPED` é persistido antes do drain; drain preso bloqueia nova troca e mantém
  reserva; pool/instrumentação saem somente após retorno das leases;
- gate de admissão e pool mudam na ordem segura tanto em redução como ampliação;
- onboarding nunca publica pool antes de metadata/revisão duráveis.
- cache miss, corrupção e indisponibilidade consultam o store autoritativo;
- perda de invalidação converge por revisão/TTL sem `allEntries`, scan ou fallback;
- cold cache concorrente é bounded por tenant e não bloqueia outro tenant.

## Security and API Tests

- `ROLE_SUPER_ADMIN` autorizada; demais roles e ausência de autenticação negadas;
- comando em namespace de plataforma não exige impersonação, não abre datasource
  tenant e o worker interno usa binding/fencing próprios;
- target/path e header/contexto conflitantes falham antes do use case;
- payload/response/audit/log não expõem URL, usuário, senha, slug ou secret;
- auditoria registra sucesso, falha, denied e rollback uma vez por intenção;
- conflito, validação, capacidade e indisponibilidade usam Problem Details estável.

## Observability and Capacity Tests

- nenhum Meter ID/tag contém tenant, UUID, slug, database, revision ou pool name;
- séries são removidas ao aposentar geração;
- fórmula prova `O + N` por réplica, soma swaps, preserva reserva durante drain e
  rejeita scale-out acima de `replicasMax`;
- rollback é capacity-admissible somente dentro da janela `old + new` reservada e
  rejeitável por capacidade depois;
- load test mede espera, timeout, throughput e headroom por seed sem usar produção
  ou dado real.
- outcomes agregados de cache não usam tenant, UUID, revisão, hash ou chave como label.

## Required Gates for the Authorized Local Backend Implementation

```bash
cd backend
./mvnw -B -Dtest=TenantDatabaseRegistryTest test
./mvnw -B -Ptenant-isolation-gate verify
./mvnw -B -Dtest=ModuleStructureVerificationTest test
./mvnw -B -Dtest=CleanArchitectureRulesTest,CleanArchitectureRuleContractTest test
./mvnw -B clean test
```

Selectors adicionais deverão cobrir controller, serviço, persistence, capacity
allocator, swap/drain e métricas. Os comandos acima são gates futuros; sua
presença neste ADR não alega execução nesta mudança exclusivamente documental.

Critério de sucesso: todos os cenários obrigatórios passam sem falhas, erros ou
skips exigidos; benchmark e orçamento possuem evidência reproduzível; nenhum
tenant compartilha objeto/configuração e nenhum fallback cross-tenant existe.

---

# 11. Risks and Mitigations

## Risk 1: Pool robusto exaurir o PostgreSQL

Mitigation: orçamento por cluster/replica, reserva atômica, headroom de swap,
admission control e rejeição explícita antes do candidate build.

## Risk 2: Fechamento interromper transação em voo

Mitigation: slot estável, lease por aquisição, geração draining e fechamento
somente depois de zero leases.

## Risk 3: Atualização antiga vencer corrida

Mitigation: revisão monotônica, lock curto por tenant, binding epoch e CAS antes do
swap.

## Risk 4: Crash deixar runtimes divergentes

Mitigation: head desired/committed, acknowledgement fenced por runtime, intenção
durável, evento como acelerador e reconcile periódico com jitter.

## Risk 5: Perfil global alterar vários tenants

Mitigation: perfil somente copia valores para snapshot completo; não existe
herança viva nem campo nullable efetivo.

## Risk 6: Métricas Hikari vazarem identidade/cardinalidade

Mitigation: não ligar pool dinâmico diretamente a registry com `poolName`
tenant-specific; agregar por dimensões finitas e manter detalhe em canal protegido.

## Risk 7: Super Admin causar DoS por erro de configuração

Mitigation: allowlist, bounds, orçamento, expected revision, razão, auditoria,
candidate probe, rollback e rate limit de reconfiguração.

## Risk 8: Ausência fail-closed indisponibilizar tenant legado

Mitigation: backfill do baseline efetivo, shadow/readiness completo, coortes e
remoção do fallback somente depois de cobertura comprovada.

## Risk 9: Valores por porte criarem falsa sensação de capacidade

Mitigation: seeds são ponto inicial; sizing final usa concorrência, nested
transactions, latência e load test medidos.

## Risk 10: Geração draining nunca encerrar

Mitigation: alerta, diagnóstico de leases, bloqueio de nova troca, quota reservada
e runbook; não abortar transação automaticamente apenas para liberar memória.

## Risk 11: Rollback perder capacidade após estabilização

Mitigation: reservar capacidade para `old + new` por réplica durante janela
explícita; depois dela declarar rollback best-effort e retornar rejeição de
capacidade sem alterar o LKG.

## Risk 12: Cache de A invalidar B ou autorizar estado stale

Mitigation: REQ-00048, envelope tenant/revision/binding-aware, invalidação exata,
TTL absoluto, recomposição bounded e fonte durável obrigatória para qualquer
efeito de capacidade. Cache global ou `allEntries` não participa desse caminho.

---

# 12. Related ADRs

- [ADR-0002](ADR-0002-separacao-banco-por-contexto-multitenancy.md) - preserva
  todas as suas decisões, exceto o sizing uniforme quando aplicado a pools
  dedicados por tenant, parcialmente superseded por este ADR.
- [ADR-0005](ADR-0005-multi-tenancy-architecture.md) - preserva identidade,
  `TenantContext` e isolamento em profundidade; topologia foi especializada pelo
  ADR-0019.
- [ADR-0009](ADR-0009-dynamic-rbac-evolution.md) - mantém RBAC estático e backend
  autoritativo para `ROLE_SUPER_ADMIN`.
- [ADR-0012](ADR-0012-error-handling-observability.md) - governa Problem Details,
  logs/traces protegidos e proíbe identidade em labels.
- [ADR-0019](ADR-0019-database-per-tenant.md) - decisão base de um banco e um pool
  compartilhado apenas pelos contextos do mesmo tenant.
- [ADR-0006](ADR-0006-audit-compliance.md) - direção proposta para `AuditPort`; não
  é usada como única fonte normativa por continuar `Proposed`.

---

# 13. References

- [Module Registry - Persistência multitenant](../architecture/module-registry.md#persistência-multitenant)
- [REQ-00030 - Verificação de isolamento multitenancy](../product/requirements/REQ-00030-multitenancy-isolation-verification.md)
- [REQ-00031 - Tenant Lifecycle and Access](../product/requirements/REQ-00031-phase2-tenant-lifecycle-and-access.md)
- [REQ-00046 - Resiliência contra starvation do pool](../product/requirements/REQ-00046-chatbot-tenant-pool-starvation-resilience.md)
- [REQ-00047 - Administração de política de pool por tenant](../product/requirements/REQ-00047-super-admin-tenant-pool-policy-administration.md)
- [REQ-00048 - Isolamento e resiliência do cache da política de pool](../product/requirements/REQ-00048-tenant-pool-policy-cache-isolation-resilience.md)
- [TP-00023 - Administração de políticas de pool por tenant](../../../docs/specs/TP-00023-tenant-pool-policy-administration.md)
- [IP-BE-3.2.10-chatbot-tenant-pool-starvation-remediation — Remediação do starvation](../specs/IP-BE-3.2.10-chatbot-tenant-pool-starvation-remediation.md)
- [LL-BE-00091 — Evidência histórica do esgotamento do pool tenant pelo chatbot](../lessons-learned/LL-BE-00091-long-lived-chatbot-transaction-exhausts-tenant-pool.md)
- [`TenantDatabaseRegistry.java`](../../app/src/main/java/br/com/duoset/saas_service/config/persistence/routing/TenantDatabaseRegistry.java)
- [`TenantRoutingDataSource.java`](../../app/src/main/java/br/com/duoset/saas_service/config/persistence/routing/TenantRoutingDataSource.java)
- [`TenantDatabaseRegistryPort.java`](../../app/src/main/java/br/com/duoset/saas_service/shared/tenancy/TenantDatabaseRegistryPort.java)
- [`TenantDataSourceConfig.java`](../../app/src/main/java/br/com/duoset/saas_service/config/persistence/TenantDataSourceConfig.java)
- [`PlatformDataSourceConfig.java`](../../app/src/main/java/br/com/duoset/saas_service/config/persistence/PlatformDataSourceConfig.java)

---

# 14. Decision Lifecycle

Current state: `Accepted`.

O aceite humano explícito de 2026-08-27 resolveu o gate arquitetural e autorizou
planejamento e implementação backend e frontend locais conforme o RF REQ-00047 e
o NFR REQ-00048. Em 2026-08-28, nova instrução aprovou o NFR técnico REQ-00049 e
seu smoke local opt-in A/B. A instrução humana posterior na data original aprovou o wireframe
textual do IP-FE-23.3.1-tenant-pool-policy-super-admin-ui e liberou seu visual delimitado. Infraestrutura externa,
deploy, homologação, produção e sizing produtivo sem evidência não foram
autorizados.

Em 2026-09-01, o owner humano aprovou o REQ-00051 e a implementacao
repository-local do modo gerenciado. Essa aprovacao supera somente a proibicao de
codificar o caminho multiambiente: HML/PRD continuam sem ativacao, deploy ou
sizing ate seus gates operacionais proprios.

Em 2026-09-02, o owner humano aprovou o REQ-00052 v1.1 e o TP-00030 v1.1,
incluindo somente o gate de alocacao do
`IP-INFRA-23.5.1-tenant-pool-policy-managed-hml-activation`. A aprovacao registra
ID/path e o plano foi materializado somente em `Proposed`; isso nao aprova seu
conteudo, nao inicia implementacao e nao concede deploy, acesso ambiental,
segredos, dados reais ou sizing. O IP de PRD continua `NOT_ALLOCATED`, e PRD
permanece bloqueado ate a evidencia terminal e o go/no-go de HML.

O aceite não elimina os gates de execução. Antes de declarar implementação local
concluída, permanecem obrigatórios:

1. ownership entre Tenant, Config e Shared materializado sem violação de módulo;
2. REQ-00047, REQ-00048, REQ-00049, REQ-00051, REQ-00052 e matrizes RBAC versionados, planos persistidos e escopo respeitado;
3. fórmula de capacidade e bounds locais demonstrados sem inferir produção;
4. semântica de slot, lease, drain, reconcile, fencing e multi-instância testada;
5. ausência de fallback e plano de backfill/cutover local comprovados;
6. auditoria, segurança e observabilidade compatíveis com ADR-0012;
7. gates focais, PostgreSQL, isolamento, arquitetura e suíte impactada sem skips
   obrigatórios tratados como sucesso.

Em 2026-08-31, esses gates foram satisfeitos no recorte repository-local pelas
evidências consolidadas no REQ-00049 e no TP-00027. A conclusão local não altera
os bloqueios de ambiente, capacity proof real, deploy ou produção.

Este aceite torna efetiva a supersessão parcial delimitada do ADR-0002 e do
ADR-0019. Qualquer ampliação da autorização ou mudança normativa exige revisão
humana, changelog e nova versão aceita ou ADR sucessor, conforme ADR-0000.

---

# 15. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.12 | 2026-09-02 | Owner humano / Codex (OpenAI) | Aprova REQ-00052 como quinto componente NFR operacional e TP-00030 para planejamento repository-local; registra a alocacao do IP-INFRA HML e sua criacao somente em `Proposed`, sem aprova-lo, inicia-lo, acessar ambiente, executar deploy ou inferir sizing. |
| 1.11 | 2026-09-01 | Owner humano / Codex (OpenAI) | Aprova REQ-00051 como quarto componente: runtime gerenciado sem restart, heartbeat/fencing, bootstrap committed, DEV local utilizavel pela tela e configuracao HML/PRD fail-closed sem ativacao externa. |
| 1.10 | 2026-08-31 | Owner humano / Codex (OpenAI) | Atualiza somente a rastreabilidade AS-IS: REQ-00049 e TP-00027 concluídos repository-local após routing `8/8`, isolation gate `30/30` e control-plane PostgreSQL `5/5`; rollout ambiental permanece não autorizado. |
| 1.9 | 2026-08-28 | Owner humano / Codex (OpenAI) | Atualiza somente a rastreabilidade AS-IS: componente REQ-00049 implementado no backend local, cluster exato sem fallback e release pós-drain; aceite físico Docker permanece pendente e não promove ambiente. |
| 1.8 | 2026-08-28 | Owner humano / Codex (OpenAI) | Aprova REQ-00049 como componente do ADR: profile local opt-in, A mutável/B controle, teto 10, envelope `60 <= 80`, smoke/kill switch e rollout externo somente planejado. |
| 1.7 | 2026-08-27 | Owner humano / Codex (OpenAI) | Aprova o wireframe textual e fecha bounds locais Hikari 7.0.2, seeds, rollback `PT15M`, admission conversacional derivada, fonte autoritativa de topologia e retenção/legal hold; efeitos externos permanecem default-off. |
| 1.6 | 2026-08-27 | Owner humano / Codex (OpenAI) | Registra a autorização posterior para planejamento e implementação frontend local, preservando o gate visual então pendente. |
| 1.0 | 2026-08-26 | Codex (OpenAI), sob solicitação do usuário | Criação da proposta para configuração, capacidade, aplicação e isolamento de pool por tenant. |
| 1.1 | 2026-08-26 | Codex (OpenAI), sob solicitação do usuário | Alinha baseline em `6`, separa rollout por runtime, compatibiliza impersonação/auditoria, fecha semântica de lease, capacidade, admission control e rollback. |
| 1.2 | 2026-08-27 | Codex (OpenAI), sob aprovação humana explícita | Promove a decisão a `Accepted`, autoriza somente planejamento e backend local conforme REQ-00047, preserva gates técnicos e torna efetiva a supersessão parcial estrita de sizing/fallback. |
| 1.3 | 2026-08-27 | Owner humano / Codex (OpenAI) | Mantém uma única decisão de política de pool e formaliza seus componentes RF REQ-00047 e NFR REQ-00048; cache permanece projeção tenant-scoped, descartável e fora da parametrização administrativa por porte. |
| 1.4 | 2026-08-27 | Owner humano / Codex (OpenAI) | Torna bidirecional a rastreabilidade com a LL-BE-00091 e explicita o incidente de starvation como evidência histórica dos guardrails desta decisão, sem alterar suas obrigações. |
| 1.5 | 2026-08-27 | Codex (OpenAI), sob delegação humana explícita para decidir | Fecha a política do NFR REQ-00048: Redis sem L1, revisão committed por chave exata, TTL global bounded, eviction after-commit tenant-scoped, rebuild/breaker limitados e default-off; porte continua dimensionando apenas Hikari. |

---

# 16. Repository Structure

```text
docs/
  adrs/
    README.md
    ADR-0019-database-per-tenant.md
    ADR-0052-parametros-pool-conexao-por-tenant.md
```

Os destinos backend citados e a prova root-only do REQ-00049 estão concluídos no
recorte repository-local: routing físico `8/8`, isolation gate dedicado `30/30`
e suíte PostgreSQL do control plane `5/5`, todos sem falhas, erros ou skips. Esse
AS-IS não constitui readiness, deploy ou autorização ambiental; DEV compartilhado,
HML, PRD e produção permanecem `BLOCKED/NOT_CONFIGURED`.

---

# 17. Review Process

1. Aprovação humana de ADR-0052/REQ-00047/REQ-00048 registrada em 2026-08-27, do REQ-00049 local em 2026-08-28, do REQ-00051 repository-local em 2026-09-01 e do REQ-00052/TP-00030 repository-local em 2026-09-02.
2. Produto e Arquitetura preservam o comportamento aprovado e as matrizes RBAC.
3. DBA/SRE valida orçamento, ranges e benchmark antes de qualquer sizing efetivo.
4. Segurança valida default deny, auditoria, escopo técnico e ausência de segredo.
5. Backend/Qualidade validam boundaries, lifecycle e plano de testes local.
6. Evidência local e alocacao de IP nao promovem deploy, homologação, produção ou infraestrutura; cada transicao e efeito exige seu gate proprio.
7. Qualquer mudança normativa exige nova versão revisada e aceita ou ADR sucessor;
   implementação não altera silenciosamente esta decisão.

---

# 18. Notes

Invariantes resumidos:

- um banco e uma geração ativa por tenant e por instância da aplicação;
- contextos do mesmo tenant compartilham; tenants distintos nunca compartilham;
- perfil copia valores; não existe default vivo;
- nova aquisição muda no ponto atômico somente após commit da revisão preparada;
- conexão em voo drena na geração anterior;
- falha preserva apenas o LKG committed do próprio tenant e binding vigente;
- sizing local respeita reserva e orçamento global;
- admission control é compatível com a revisão efetiva do tenant;
- `ROLE_SUPER_ADMIN` é a única autoridade humana;
- configuração de conexão sensível não faz parte da API;
- cache da política é derivado, tenant/revision-aware e invalidado somente para o tenant alvo;
- TTL, quota e eviction de caches funcionais por porte permanecem fora desta decisão;
- nenhum identificador de tenant/pool aparece em label de métrica;
- ausência de LKG/binding válido falha fechado; desired drift fica degradado e
  reconcilia, sem plataforma/outro tenant como fallback.
