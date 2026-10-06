---
document_id: "ONBOARD-TENANT-POOL-POLICY-LOCAL-ROLLOUT"
primary_nature: "Regra"
objective: "Executar e verificar com segurança o rollout exclusivamente local da política de pool por tenant, inclusive cache derivado, observabilidade, falhas e rollback."
scope: "Workspace local, backend Java/Spring, fixtures sintéticas, PostgreSQL/Redis/Keycloak efêmeros via Docker/Testcontainers e estágios D0 a D5."
non_objectives: "Não habilitar flags em ambiente compartilhado, alterar infra/, dimensionar produção, criar dashboards/alertas externos, executar deploy/canary ou acessar HML/PRD/produção/dados reais."
owner: "Backend, Observabilidade e Arquitetura"
status: "Active"
version: "1.2"
date: "2026-08-28"
last_reviewed: "2026-09-06"
keywords: "tenant, pool, HikariCP, Redis, cache, Testcontainers, rollout-local, rollback"
related_files: "docs/adrs/ADR-0052-parametros-pool-conexao-por-tenant.md, docs/product/requirements/REQ-00047-super-admin-tenant-pool-policy-administration.md, docs/product/requirements/REQ-00048-tenant-pool-policy-cache-isolation-resilience.md, docs/product/requirements/REQ-00049-tenant-pool-policy-authorized-test-rollout.md, docs/product/use-cases/UC-00046-super-admin-tenant-pool-policy-management.md, docs/delivery/plans/TP-00023-tenant-pool-policy-administration.md, docs/delivery/plans/implementation_plans/backend/IP-BE-23.3.2-tenant-pool-policy-observability-and-rollout.md, docs/onboarding/tenant-pool-policy-authorized-test-rollout-runbook.md"
code_references: "backend/src/main/java/br/com/duoset/saas_service/config/persistence/routing/, backend/src/main/java/br/com/duoset/saas_service/contexts/tenant/, backend/src/main/resources/application.yml, backend/src/test/java/br/com/duoset/saas_service/"
principal_statement: "O rollout deste runbook é uma prova hermética repository-local: usa somente tenants e serviços efêmeros sintéticos, termina com todas as flags OFF e não constitui autorização ou evidência de deploy e produção."
---

# Runbook — rollout local da política de pool por tenant

## 1. Ambiente, autoridade e limites

Este procedimento verifica o recorte local aprovado do ADR-0052, do RF
REQ-00047, do NFR REQ-00048 e do UC-00046. Execute a partir do workspace local,
sem credenciais ou dados reais. PostgreSQL, Redis e Keycloak devem ser instâncias
efêmeras de teste; nenhum comando deste runbook altera `infra/`, HML, PRD ou
produção.

O porte do escritório altera somente os parâmetros Hikari persistidos para o
tenant. TTL, limite de rebuild, footprint e política do cache são globais: um
tenant ocupa no máximo uma entrada committed intencional, sem L1 Caffeine e sem
compartilhamento de snapshot mutável.

## 2. Pré-requisitos

- Java 25 e Maven Wrapper do repositório;
- Docker local acessível pelo usuário atual ou por sessão de grupo já autorizada;
- daemon com capacidade para containers efêmeros PostgreSQL 16, Redis 7 e
  Keycloak;
- nenhuma flag de efeito promovida no profile base; o profile opt-in do
  REQ-00049 pertence somente ao runbook autorizado separado;
- execução a partir de `backend/`, exceto o gate documental;
- somente IDs, bancos, payloads e credenciais sintéticos gerados pelos testes.

Não informe senha em comando, log ou documento. Se o shell atual ainda não
reconhecer o grupo Docker, use a forma local administrada pelo host, como
`sg docker -c '<comando>'`; não contorne permissões do socket.

## 3. Matriz de segurança default-off

Antes e depois do ensaio, confira em `backend/src/main/resources/application.yml`:

| Propriedade | Valor obrigatório no repositório |
| --- |:---:|
| `app.tenant-pool-policy.mutations-enabled` | `false` |
| `app.tenant-pool-policy.authoritative-read-enabled` | `false` |
| `app.tenant-pool-policy.candidate-apply-enabled` | `false` |
| `app.tenant-pool-policy.revision-apply-enabled` | `false` |
| `app.tenant-pool-policy.fail-closed-cutover-enabled` | `false` |
| `app.tenant-pool-policy.cache-enabled` | `false` |
| `app.tenant-pool-policy.initial-policy-onboarding-enabled` | `false` |
| `app.tenant-pool-policy.capacity-preflight-enabled` | `false` |
| `app.tenant-pool-policy.capacity-reservation-enabled` | `false` |
| `app.tenant-pool-policy.membership-fencing-enabled` | `false` |
| `app.tenant-pool-policy.external-release-enabled` | `false` |
| `app.tenant-pool-policy.api-read-enabled` | `false` |
| `app.tenant-pool-policy.observability.enabled` | `false` |
| `app.tenant-pool-policy.reconcile-scheduler-enabled` | `false` |
| `app.tenant-pool-policy.runtime.evidence-enabled` | `false` |
| `app.tenant-pool-policy.backfill.enabled` | `false` |
| `app.tenant-pool-policy.shadow.enabled` | `false` |

Os valores acima são do profile base. Overrides existem no contexto hermético dos
testes e, exclusivamente conforme o REQ-00049, no profile opt-in governado pelo
[runbook autorizado](tenant-pool-policy-authorized-test-rollout-runbook.md).
Encerrar esta matriz D0–D5 com o profile opt-in ativo ou qualquer item base acima
em `true` bloqueia o handoff.

## 4. Execução D0–D5

Todos os comandos desta seção partem de `backend/`.

### D0 — boot dark e flags

```bash
./mvnw -B -Dtest=TenantPoolPolicyFeatureFlagTest,TenantPoolPolicyRunnerContextTest,SaasServiceApplicationContextTest test
```

Resultado esperado: propriedades default-off, runners ausentes no contexto
default e aplicação inicializada sem ativar API, cache, scheduler ou apply.

### D1 — baseline, backfill e shadow sintéticos

```bash
./mvnw -B -Dtest=TenantPoolPolicyBackfillUseCaseTest,TenantPoolPolicyBackfillTenantServiceTest,TenantPoolPolicyShadowComparatorTest test
```

Resultado esperado: snapshot efetivo tenant-bound, hash determinístico, reexecução
idempotente e nenhuma troca de pool.

### D2 — API e mutação no-op

```bash
./mvnw -B -Dtest=TenantPoolPolicyAdministrationServiceTest,TenantPoolPolicyControllerTest,TenantPoolPolicyPlatformBoundaryFilterTest,TenantPoolPolicyExceptionHandlerTest test
```

Resultado esperado: autorização `ROLE_SUPER_ADMIN`, boundary de plataforma,
idempotência e audit preservados; apply/cutover continuam desligados.

### D3 — lifecycle em um runtime

```bash
./mvnw -B -Dtest=TenantPoolPolicyLocalRolloutIT,TenantPoolMetricsLifecycleTest,TenantPoolMeterCardinalityTest test
```

Resultado esperado: prepare/probe/commit/swap/drain herméticos, retirement
idempotente, nenhum ghost meter e tenant B intacto.

### D4 — concorrência e restart sintéticos

```bash
./mvnw -B -Dtest=TenantPoolPolicyRuntimeRestartIT,TenantPoolReconcilerTest,TenantPoolSlotTest test
```

Resultado esperado: restart, fencing, evento perdido e estado stale convergem
sem fallback para outro tenant e sem duplicar efeitos terminais.

### D5 — failure injection e rollback

```bash
./mvnw -B -Dtest=TenantPoolPolicyFailureInjectionIT,TenantPoolPolicyDrainAndRollbackIT test
```

Resultado esperado: falha de candidato, registry de métricas, drain preso e
rollback preservam LKG, reservas e conexões em voo; rollback funcional cria nova
revisão.

## 5. Cache por tenant

Execute a prova focal sem dependência externa:

```bash
./mvnw -B -Dtest=TenantPoolPolicyCatalogAdapterTest,TenantPoolPolicyCacheContractTest,TenantPoolPolicyCacheIsolationTest,TenantPoolPolicyCacheResilienceTest,TenantPoolPolicyCacheEvictionServiceTest,TenantPoolPolicyCacheMetricsTest test
```

Com Docker local, execute a prova tecnologicamente fiel:

```bash
sg docker -c './mvnw -B -Dtest=TenantPoolPolicyRedisPostgresIndependentIT,TenantPoolPolicyStorePostgresTest,TenantPoolBlueGreenMultiInstancePostgresTest test'
```

Aceite somente quando:

- a chave for `tenant-pool-policy:v1:{tenantId}:b{bindingEpoch}:r{revision}`;
- o head committed vier do PostgreSQL antes da seleção da chave;
- mismatch de tenant, revisão, binding ou hash produzir miss seguro;
- TTL global absoluto não for renovado por leitura ou falha;
- commit, rollback, suspensão e offboarding programarem `UNLINK` da chave
  anterior exata somente após commit;
- rollback transacional não evictar e falha do Redis não desfizer o commit;
- timeout `PT200MS`, ausência de retry inline, breaker e single-flight/fila
  bounded desviarem com segurança para o store;
- operação, expiração, rebuild ou falha de A não alterarem chave, TTL ou valor de
  B;
- a API não expuser TTL, quota, provider ou configuração de cache por porte.

Mudança futura de binding deve invocar o mesmo serviço after-commit com a tupla
anterior exata. Até existir tal fluxo, revisão/binding esperado e TTL impedem que
uma chave antiga seja selecionada.

## 6. Métricas e privacidade

O catálogo permitido possui prefixo `tenant_pool_` e somente estas famílias:

- `tenant_pool_policy_operations`;
- `tenant_pool_runtime_generations`;
- `tenant_pool_connection_acquire_duration`;
- `tenant_pool_connection_timeouts`;
- `tenant_pool_reconcile_duration`;
- `tenant_pool_capacity_connections`;
- `tenant_pool_capacity_rejections`;
- `tenant_pool_runtime_drift`;
- `tenant_pool_apply_failures`;
- `tenant_pool_policy_cache_operations`;
- `tenant_pool_policy_cache_breaker`;
- `tenant_pool_policy_cache_rebuild`.

Valide a allowlist e a estabilidade das séries:

```bash
./mvnw -B -Dtest=MicrometerTenantPoolPolicyMetricsAdapterTest,TenantPoolMetricDimensionsTest,TenantPoolMetricsLifecycleTest,TenantPoolMeterCardinalityTest,TenantPoolObservationServiceTest test
```

Tenant, UUID, slug, database, JDBC, revisão, hash, Redis key, pool name e operation
ID não podem aparecer em `Meter.Id`. Operation ID é permitido apenas como
correlação high-cardinality em trace protegido. Logs não registram payload,
credencial, URL JDBC, chave Redis completa ou mensagem bruta de exceção.

## 7. Gates finais

```bash
./mvnw -B -Dtest=ModuleStructureVerificationTest test
./mvnw -B -Dtest=CleanArchitectureRulesTest,CleanArchitectureRuleContractTest test
sg docker -c './mvnw -B -Ptenant-isolation-gate verify'
./mvnw -B clean test
```

A falha de teste impactado bloqueia o recorte. Falha comprovadamente preexistente
e fora do tenant pool deve ser registrada com classe, contagem e status do gate
global; não pode ser ocultada, convertida em sucesso ou corrigida expandindo este
escopo sem requisito/plano próprio.

Da raiz do monorepo, valide os documentos:

```bash
./infra/scripts/validate-docs.sh
```

## 8. Kill switch e recuperação

1. Mantenha/desative `mutations-enabled`, `candidate-apply-enabled`,
   `revision-apply-enabled` e `reconcile-scheduler-enabled` para impedir novos
   intents e prepares.
2. Não interrompa commit/drain já persistido e não feche conexão/transação em
   voo; retirement continua lease-aware.
3. Se cache ou observabilidade falhar, mantenha `cache-enabled=false` e
   `observability.enabled=false`; o store durável e o runtime LKG permanecem
   autoritativos.
4. Preserve revisions, heads, intents, reservations, applications e audit.
5. Corrija schema e configuração somente forward. Rollback funcional de policy é
   nova revisão validada pelo allocator, nunca down migration.
6. Repita D0–D5 e os gates antes de novo handoff.

## 9. Handoff e classificação de evidência

O handoff repository-local deve informar comandos, contagens, falhas, skips,
versões efêmeras e confirmar todas as flags `OFF`. A prova local pode concluir o
[IP-BE-23.3.2-tenant-pool-policy-observability-and-rollout](../delivery/plans/implementation_plans/backend/IP-BE-23.3.2-tenant-pool-policy-observability-and-rollout.md)
e o TP-00023 apenas no escopo autorizado.

Continuam `NOT PROVEN` e exigem plano/autorização separados: budget/overhead real
do Redis, sizing e benchmark de ambiente, thresholds/SLO, dashboards e alertas
implantados, infraestrutura externa, promoção de flag, deploy, canary, HML, PRD,
produção e qualquer dado real.

## 10. Riscos operacionais

| Risco | Controle obrigatório |
| --- | --- |
| A invalidar B | chave e `UNLINK` exatos, after-commit e teste A/B |
| cache stale ampliar capacidade | head/store durável antes de qualquer decisão ampliativa |
| stampede | single-flight por chave e limiter/fila globais bounded |
| cardinalidade ou identificação | catálogo/allowlist finitos e inspeção de todos os `Meter.Id` |
| swap deixar séries ou pool órfão | handle idempotente ligado ao retirement lease-aware |
| prova local ser tratada como readiness | classificação explícita `NOT PROVEN` para ambiente/deploy/produção |

## 11. Change Log

| Version | Date | Changes |
| --- | --- | --- |
| 1.2 | 2026-09-06 | Atualiza o pré-requisito local para Java 25; não altera sizing, flags, critérios D0–D5 ou autoridade ambiental. |
| 1.1 | 2026-08-28 | Distingue a matriz base dark do profile local opt-in governado pelo REQ-00049 e pelo runbook autorizado. |
| 1.0 | 2026-08-28 | Cria a matriz hermética D0–D5 com handoff default-off. |
