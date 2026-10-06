---
document_id: ONBOARD-TENANT-POOL-POLICY-AUTHORIZED-TEST-ROLLOUT
primary_nature: Regra
objective: Executar e encerrar com segurança o smoke local autorizado da política de pool por tenant com coortes A/B e capacidade limitada.
scope: Workspace local, profiles dev/test, tenants sintéticos, backend, PostgreSQL/Testcontainers, upgrade, isolamento, rollback, drain, kill switch e evidência.
non_objectives: Ambiente compartilhado, infra/, deploy, HML, PRD, produção, dados reais, sizing externo, cache, onboarding ou external release.
owner: Backend, SRE/DBA, Observabilidade e Arquitetura
status: Active
version: 1.9
date: 2026-08-28
last_reviewed: 2026-09-01
keywords: runbook, tenant-pool, local-smoke, A/B, Hikari, capacity, rollback, drain
related_files: docs/adrs/ADR-0052-parametros-pool-conexao-por-tenant.md, docs/product/requirements/REQ-00049-tenant-pool-policy-authorized-test-rollout.md, docs/product/use-cases/UC-00046-super-admin-tenant-pool-policy-management.md, docs/delivery/plans/TP-00027-tenant-pool-policy-authorized-test-rollout.md, docs/delivery/plans/TP-00028-tenant-pool-policy-local-ui-activation.md, docs/delivery/plans/implementation_plans/backend/IP-BE-23.4.1-tenant-pool-policy-authorized-test-enablement.md, docs/delivery/plans/implementation_plans/backend/IP-BE-23.4.2-tenant-pool-policy-local-ui-activation.md
code_references: backend/pom.xml, backend/src/main/resources/application.yml, backend/src/main/resources/application-tenant-pool-smoke.yml, backend/src/test/java/br/com/duoset/saas_service/config/persistence/TenantDatabaseRoutingIsolationIT.java, backend/scripts/tenant-pool-smoke-local.sh, backend/scripts/tenant-pool-smoke/
principal_statement: O smoke somente é válido em dev/test local nas matrizes ACTIVE ou DRAIN_ONLY, com A mutável, B controle e autoridade persistida aderente ao budget 80/teto 10; termina em DARK e não autoriza promoção ambiental.
---

# Runbook — rollout autorizado de teste da política de pool por tenant

## 1. Environment, Authority and Limits

Execute somente neste workspace e com dados sintéticos. O profile canônico é
`tenant-pool-smoke`, combinado com `dev` ou `test`. Não execute contra Compose,
host, banco ou identidade compartilhados com dados reais. Este runbook prova um
recorte local e não autoriza deploy.

Tenants canônicos do IT físico existente:

- A mutável: `aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa`;
- B controle: `bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb`.

## 2. Prerequisites

- documentação validada e
  IP-BE-23.4.1-tenant-pool-policy-authorized-test-enablement vigente;
- Java/Maven Wrapper e Docker local autorizados;
- PostgreSQL 16 efêmero, nunca banco real;
- base `application.yml` com flags `false`;
- lease runtime futura com margem mínima validada pelo startup guard;
- nenhum outro `tenant-isolation-gate` escrevendo em
  `backend/build/tenant-isolation-gate`; aguarde o run anterior terminar;
- cold start do Keycloak dispõe de até cinco minutos, mas somente HTTP `200` no
  endpoint OIDC do realm importado satisfaz readiness;
- nenhuma senha informada em comando, log ou documento.

O profile usa build output integral próprio. Builds Maven/IDE comuns continuam em
`backend/target` e não fornecem classes ou reports ao isolation gate. `clean` remove
o estado anterior do diretório dedicado, mas não autoriza dois writers do mesmo
profile.

## 3. Identity, Topology and Capacity Budget

| Value | Local smoke |
| --- | ---: |
| `replicasMax` | 1 |
| `platformPoolMax` | 10 |
| tenant A max | 10 |
| tenant B max | 10 |
| uma geração old transitória | 10 |
| migration/admin reserve | 5 |
| emergency headroom | 15 |
| safe budget | 80 |

Preflight conservador:

```text
1 * (10 + 10 + 10) + 10 + 5 + 15 = 60 <= 80
```

DEV compartilhado, HML e PRD não possuem valores neste runbook. Ausência de
budget medido significa `BLOCKED`, não herança de `80`.

Antes de ativar, confirme por `runtime.cluster-id` que a linha persistida está
`CONFIGURED` e contém exatamente `80/10/5/15/1`; confirme também que o membership
do runtime configurado está ativo, não expirado e possui epoch/instance/fencing/
row-version iguais. Outro cluster nunca é fallback. O allocator repetirá a
comparação do budget sob lock; divergência posterior também é `NO-GO`.

## 4. Profile and Flag Order

`application.yml` permanece dark. O profile opt-in exige IDs A/B, identidade
runtime completa e admite somente estas matrizes derivadas das próprias flags:

| Flag | `ACTIVE` | `DRAIN_ONLY` | `DARK` |
| --- | :---: | :---: | :---: |
| API read, authority, revision apply, fencing, scheduler, observabilidade, evidence | `true` | `true` | `false` |
| mutations, preflight, reservation, candidate apply | `true` | `false` | `false` |
| coortes/envelope | presentes | preservados | vazios |

Permanecem `false`: cache, onboarding, backfill, shadow, fail-closed cutover e
external release. O startup guard rejeita outra combinação; não configure campo
`phase`, pois `ACTIVE` e `DRAIN_ONLY` são classificações da matriz completa.

## 5. Synthetic A/B Setup

Use somente as fixtures efêmeras dos testes. A deve iniciar com snapshot
`SMALL/6`; B com snapshot próprio. Confirme bancos físicos distintos e ausência de
pool/default compartilhado antes do primeiro swap.

Para um backend vivo local, forneça por ambiente, sem versionar valores:

- profiles `dev,tenant-pool-smoke`;
- IDs A/B acima;
- `cluster-id`, `deployment-epoch`, `runtime-instance-id`, `fencing-token`,
  `lease-deadline` e `row-version` sintéticos;
- os valores de capacidade da seção 3.

Se qualquer valor estiver ausente, não contorne o startup guard.

## 6. Smoke Command

Da raiz, valide documentos; depois, em `backend/`, execute:

```bash
./mvnw -B -Dtest=TenantPoolPolicyPropertiesTest,TenantPoolLifecyclePropertiesTest,TenantPoolPolicyAuthorizedTestEnvironmentGuardTest,TenantPoolPolicyAuthorizedTestProfileContextTest test
./mvnw -B -Dtest=TenantPoolPolicyAdministrationFeatureGateAdapterTest,TenantPoolPolicyAdministrationServiceTest,TenantPoolCandidatePreparerTest,TenantPoolReconcilerTest test
./mvnw -B -Dtest=TenantPoolPolicyCapacityReservationAdapterTest,TenantPoolCapacityAllocatorTest,TenantPoolCapacityEnvironmentControlPlanePostgresTest test
./mvnw -B -Dtest=TenantDatabaseRoutingIsolationIT test
```

Se o host exigir shell com acesso Docker, use somente o mecanismo local
autorizado. Não coloque senha na linha de comando nem no histórico.

Antes do Maven, confirme que o registry resolve e que as imagens pinadas estão
locais:

```bash
resolvectl query registry-1.docker.io
sudo docker image inspect testcontainers/ryuk:0.13.0
sudo docker image inspect postgres:16.14-alpine3.24
sudo docker image inspect quay.io/keycloak/keycloak:26.6.3
```

Se uma imagem estiver ausente, faça o pull explícito somente após a consulta DNS
passar. Nunca desabilite Ryuk, altere o pin, edite `/etc/resolv.conf` ou use
`docker system prune` para contornar o gate.

No host em que o daemon exige root, o operador humano executa:

```bash
sudo -s
cd /home/duoset/Documents/workspace/saas-service/backend
./mvnw -B -Dtest=TenantPoolPolicyControlPlaneMigrationPostgresTest,TenantPoolCapacityEnvironmentControlPlanePostgresTest,TenantPoolBlueGreenMultiInstancePostgresTest,TenantPoolCapacityMultiInstancePostgresTest,TenantPoolPolicyIntentAuditPostgresTest,TenantDatabaseRoutingIsolationIT test
./mvnw -B clean -Ptenant-isolation-gate verify
exit
```

Digite a senha apenas no prompt do `sudo`; nunca a acrescente ao comando.

### 6.1 Sessão manual pela interface

O TP-00028 adiciona um launcher local para a UI sem alterar os defaults do
Compose. Ele reserva exclusivamente A
`cccccccc-cccc-4ccc-8ccc-cccccccccccc`, B
`dddddddd-dddd-4ddd-8ddd-dddddddddddd`, os bancos marcados
`saas_pool_smoke_a`/`saas_pool_smoke_b` e o cluster `pool-local-smoke`.

No host em que o daemon exige root, execute a partir da raiz:

```bash
sudo -s
cd /home/duoset/Documents/workspace/saas-service
./backend/scripts/tenant-pool-smoke-local.sh start
exit
```

Depois, acesse `http://localhost:3000` como Super Admin global, sem impersonação,
e navegue em `Principal > Escritórios > Pool Smoke A > Pool de conexões`. A é
mutável e B é controle somente leitura. A lease dura oito minutos; antes de
expirar, renove no shell com acesso Docker:

```bash
./backend/scripts/tenant-pool-smoke-local.sh renew
```

Consulte sem revelar segredos e encerre sempre retornando ao `DARK`:

```bash
./backend/scripts/tenant-pool-smoke-local.sh status
./backend/scripts/tenant-pool-smoke-local.sh stop
```

`renew` reinicia apenas o backend opt-in. `stop` valida os marcadores, remove
somente a fixture reservada e restaura o backend normal. Não execute os SQLs
diretamente nem altere os UUIDs, nomes de banco, cluster ou envelope.

Durante o gate, classes, test-classes, JAR e evidência devem existir somente sob
`backend/build/tenant-isolation-gate`. Os quatro XML obrigatórios ficam em:

```text
backend/build/tenant-isolation-gate/failsafe-reports/
```

Rejeite integralmente o run se outro gate usar esse diretório, se qualquer selector
executar zero testes, se faltar relatório, se houver falha/erro/skip ou se não
terminar com `BUILD SUCCESS`.

## 7. Change, Isolation and Drain

Aceite a prova somente se:

1. A prepara candidato `ROBUST/10` ligado ao banco A;
2. B continua no banco B com o mesmo snapshot;
3. swap torna a revisão nova de A ativa;
4. conexão antiga de A continua executando enquanto sua lease está aberta;
5. `finalizeDraining(A)` retorna `false` durante a lease;
6. liberar a lease permite `finalizeDraining(A)=true`;
7. B permanece inalterado após cada estágio.

## 8. Rollback

Crie/aplique uma nova revisão de A a partir do snapshot `SMALL/6`. Não altere a
revisão histórica. Repita a lease na geração `ROBUST/10`, prove drain bloqueado,
libere-a e finalize. B deve manter banco, snapshot e geração próprios.

## 9. Metrics and Gates

```bash
./mvnw -B -Dtest=TenantPoolPolicyFeatureFlagTest,SaasServiceApplicationTests test
./mvnw -B -Dtest=ModuleStructureVerificationTest test
./mvnw -B -Dtest=CleanArchitectureRulesTest,CleanArchitectureRuleContractTest test
./mvnw -B clean -Ptenant-isolation-gate verify
```

Meters não contêm tenant/UUID/revision. Registre testes, contagens, falhas e skips
separadamente. Um skip Docker não é pass. Se o gate já foi executado na seção 6,
esta linha não deve iniciar um segundo run concorrente: reutilize somente os quatro
reports completos daquela mesma invocation.

## 10. Kill Switch and Recovery

1. Entre em `DRAIN_ONLY`: desligue mutations, preflight, reservation e candidate;
   mantenha API read, authority, revision apply, fencing, scheduler,
   observabilidade e runtime evidence.
2. Confirme que intent não committed não prepara, não chama `commitIfReady`, não
   troca geração e não cria reserva.
3. Acompanhe somente revisões já committed até `SWAPPED/DRAINED`; permita
   reconstrução do candidate committed perdido após restart, preserve leases e
   nunca force-close.
4. Confirme ausência de geração draining e reserva aberta. No cluster sintético
   dedicado, a reserva concluída deve estar `RELEASED`, com `released_at`, e não
   pode restar aplicação diferente de `DRAINED`:

   ```sql
   SELECT COUNT(*) AS open_reservations
     FROM tenant_pool_capacity_reservation
    WHERE cluster_id = :cluster_id
      AND state NOT IN ('RELEASED', 'FAILED');

   SELECT COUNT(*) AS not_drained_applications
     FROM tenant_pool_runtime_application
    WHERE cluster_id = :cluster_id
      AND state <> 'DRAINED';
   ```

   Ambos os resultados devem ser zero. A passagem transitória
   `STABILIZING -> RELEASABLE -> RELEASED` ocorre na mesma transação que
   terminaliza o intent; `external-release-enabled` continua `false`.
5. Entre em `DARK`, desligue as flags restantes e reinicie sem
   `tenant-pool-smoke`; preserve revisions, heads, intents e audit.
6. Em erro de policy, rollback é nova revisão; nunca force-close ou down migration.

## 11. Handoff and Evidence Classification

O handoff confirma:

- base dark e profile removido;
- A/B exclusivamente sintéticos;
- fórmula `60 <= 80`;
- upgrade, isolamento, drain e rollback provados;
- nenhum acesso a frontend, infra externa, HML, PRD ou produção;
- rollout ambiental ainda `PLANNED/NOT_AUTHORIZED`.

## 12. Controlled Rollout Plan

Somente após novo plano/autorização:

1. medir capacidade real e aprovar budget por ambiente;
2. habilitar telemetria/read para coorte sintética;
3. executar canary de um tenant dedicado não real;
4. observar saturação, timeouts, drift e drain por janela aprovada;
5. ampliar coorte gradualmente com go/no-go humano;
6. usar kill switch e rollback por revisão em qualquer degradação.

## 13. Operational Risks

| Risk | Control |
| --- | --- |
| A alcançar B/C | Coortes separadas e guardas duplicadas. |
| Expirar lease durante teste | Deadline explícita com margem; ensaio curto. |
| Budget fictício promover ambiente | Matriz externa `BLOCKED/NOT_CONFIGURED`. |
| Kill switch parar drain | Ordem em duas etapas. |
| Evidência local virar readiness | Classificação `repository-local only`. |

## 14. Latest Repository-Local Rehearsal Evidence

Em 2026-08-28, sem acesso externo:

- compilação completa: `BUILD SUCCESS`;
- profile/coortes/capacidade/reconciler: `59/59 PASS`;
- regressão final allocator/reservation adapter: `10/10 PASS`;
- contexto Spring dark: `1/1 PASS`;
- Modulith/Clean Architecture: `29/29 PASS`;
- governança documental: `PASS`, 677 Markdown e 657 artefatos indexados em
  2026-08-31;
- migration PostgreSQL fornecida pelo operador: `2/2 PASS`;
- smoke físico e convergência JDBC `RELEASED`: `PENDING` naquele checkpoint,
  posteriormente fechados pelas evidências de 2026-08-31 abaixo.
- o operador executou `clean -Ptenant-isolation-gate verify` em 2026-08-29;
  Keycloak passou `7/7`, HTTP terminou com `8` erros e Hibernate/Routing não
  descobriram testes porque classes desapareceram do output compartilhado durante
  o Failsafe. Sem `BUILD SUCCESS`, a evidência foi classificada `FAIL/INVALID`.
- após o incidente, o profile foi isolado em
  `backend/build/tenant-isolation-gate`; model evaluation e
  `clean package -DskipITs` passaram (`1229` fontes main, `496` test e JAR), e os
  dois workflows passaram na validação YAML com consumers fail-closed atualizados.
- o rehearsal seguinte usou o output dedicado e descobriu os quatro selectors,
  mas permaneceu `FAIL`: Keycloak e HTTP abortaram no timeout de startup de 180 s,
  Hibernate passou `7/7` e Routing executou `8` com `1` erro, `0` falhas e `0`
  skips porque o snapshot tinha hash `CUSTOM` e origem `ROBUST`;
- a correção preserva o fail-closed: o smoke agora materializa os sete valores de
  `SMALL`, aplica `ROBUST` com hash `ROBUST`, retorna a `SMALL` com hash `SMALL` e
  aguarda o endpoint OIDC real por até cinco minutos. Compilação e teste Hikari
  focal passaram; naquele checkpoint o gate root-only completo ainda precisava
  ser repetido e foi posteriormente aprovado em `30/30`.
- a tentativa focal posterior ficou `NOT_EXECUTED / ENVIRONMENT BLOCKED`: após
  compilar, o dockerd não resolveu `registry-1.docker.io` via `127.0.0.53` para
  obter `testcontainers/ryuk:0.13.0`; Ryuk, PostgreSQL e os oito cenários não
  iniciaram. O warning de `/root/.docker/config.json` não foi a causa.
- o DNS de registry/auth Docker Hub e Quay respondeu normalmente na verificação
  posterior; cache/pull e execução Maven ainda exigem o shell root humano.
- em 2026-08-31, o operador executou o routing físico em shell root: `8/8 PASS`,
  zero falhas/erros/skips e `BUILD SUCCESS`; A/B aplicaram corretamente as oito
  migrations de `certificate`;
- a mensagem `Flyway migration failed for allowlisted context 'certificate'` no
  fim desse run é esperada pelo cenário `missingdatabase`: a exceção é propagada,
  capturada pelo teste e o datasource inválido permanece não publicado;
- o gate dedicado posterior terminou `30/30 PASS`, com Keycloak `7/7`, HTTP
  `8/8`, Hibernate PostgreSQL `7/7` e Routing `8/8`, todos sem falhas, erros ou
  skips, seguido de `BUILD SUCCESS`;
- a suíte PostgreSQL final do control plane terminou `5/5 PASS`, zero falhas,
  erros ou skips e `BUILD SUCCESS` às 20:59:47 -03:00: CapacityEnvironment
  `2/2`, BlueGreenMultiInstance `1/1`, CapacityMultiInstance `1/1` e IntentAudit
  `1/1`, usando Testcontainers com `postgres:16.14-alpine3.24`. O teste de
  migration V69 `2/2` já possuía evidência anterior aceita.

Comando final informado pelo operador no shell root local:

```bash
./mvnw -B -Dtest=TenantPoolCapacityEnvironmentControlPlanePostgresTest,TenantPoolBlueGreenMultiInstancePostgresTest,TenantPoolCapacityMultiInstancePostgresTest,TenantPoolPolicyIntentAuditPostgresTest test
```

Os runs negativos anteriores permanecem históricos e não foram convertidos em
aceite. Os dois novos runs usam a implementação corrigida e o isolation gate
dedicado; somente eles sustentam a aprovação do smoke físico e do gate. O handoff
foi concluído em `DARK`; DEV compartilhado, HML e PRD continuam
`BLOCKED/NOT_CONFIGURED`, e o rollout externo segue `PLANNED/NOT_AUTHORIZED`.

Como `DARK` remove coortes e identidade runtime por definição, a precondição
durável da etapa 4 é verificada antes de remover o profile. Não se introduz campo
de fase concorrente nem fallback global de cluster.

## 15. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.9 | 2026-09-01 | Codex (OpenAI), sob autorização humana explícita | Documenta o launcher manual local do TP-00028, sua coorte reservada, lease curta, renovação explícita e retorno obrigatório ao DARK. |
| 1.0 | 2026-08-28 | Codex (OpenAI), sob aprovação humana explícita | Cria o runbook do smoke local autorizado. |
| 1.1 | 2026-08-28 | Codex (OpenAI), sob aprovação humana explícita | Define ACTIVE/DRAIN_ONLY/DARK, recuperação committed e igualdade runtime/envelope/autoridade persistida. |
| 1.2 | 2026-08-28 | Codex (OpenAI), sob aprovação humana explícita | Alinha fixtures A/B, explicita precondição durável para DARK, comando root-only e evidência parcial sem promover rollout externo. |
| 1.3 | 2026-08-29 | Codex (OpenAI), sob aprovação humana explícita | Rejeita o run `clean` contaminado e passa a exigir build output integral dedicado, um writer, quatro selectors completos e reports da mesma invocation. |
| 1.4 | 2026-08-29 | Codex (OpenAI), sob aprovação humana explícita | Registra o hardening POM/CI e sua prova sem Docker; o runbook continua aguardando apenas o rehearsal root-only exclusivo e o handoff DARK. |
| 1.5 | 2026-08-29 | Codex (OpenAI), sob aprovação humana explícita | Registra o rehearsal dedicado negativo, a política de readiness OIDC de cinco minutos e a fixture completa SMALL/ROBUST/SMALL antes do novo gate. |
| 1.6 | 2026-08-31 | Codex (OpenAI), sob aprovação humana explícita | Registra bloqueio pré-teste por DNS/pull do Ryuk e acrescenta preflight das imagens pinadas sem bypass do resource reaper. |
| 1.7 | 2026-08-31 | Codex (OpenAI), sob aprovação humana explícita | Registra o routing físico `8/8` e o isolation gate dedicado `30/30` aprovados, explica o cenário negativo de `certificate` e preserva a suíte PostgreSQL do control plane como pendência explícita. |
| 1.8 | 2026-08-31 | Codex (OpenAI), sob aprovação humana explícita | Registra a suíte PostgreSQL final `5/5`, conclui o handoff local em `DARK` e mantém todo rollout ambiental como `PLANNED/NOT_AUTHORIZED`. |
