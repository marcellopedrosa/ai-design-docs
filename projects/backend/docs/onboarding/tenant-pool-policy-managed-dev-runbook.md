---
document_id: ONBOARD-TENANT-POOL-POLICY-MANAGED-DEV
primary_nature: Regra
objective: Iniciar e validar no DEV local o runtime gerenciado da politica de pool por tenant e testar alteracao e rollback pela interface sem reiniciar a aplicacao.
scope: Workspace local, Docker Compose de desenvolvimento, Keycloak DEV, backend, frontend, readiness, Super Admin global, alteracao A/B, convergencia e rollback com dados locais autorizados.
non_objectives: Executar HML/PRD, deploy, producao, dado real, sizing externo, editar Compose/infra, habilitar cache ou revelar credenciais e tokens.
owner: Backend, Frontend, SRE/DBA e Qualidade
status: Active
version: 1.5
date: 2026-09-01
last_reviewed: 2026-09-01
keywords: runbook, tenant-pool, managed-environment, dev, interface, Hikari, rollback
related_files: docs/adrs/ADR-0052-parametros-pool-conexao-por-tenant.md, docs/product/requirements/REQ-00051-tenant-pool-policy-managed-runtime-environments.md, docs/product/use-cases/UC-00046-super-admin-tenant-pool-policy-management.md, docs/delivery/plans/TP-00029-tenant-pool-policy-managed-runtime-environments.md, docs/delivery/plans/implementation_plans/backend/IP-BE-23.4.3-tenant-pool-policy-managed-runtime-environments.md, docs/delivery/plans/implementation_plans/frontend/IP-FE-23.3.1-tenant-pool-policy-super-admin-ui.md, docs/onboarding/keycloak-provisioning-identity.md
code_references: docker-compose.yml, docker-compose.override.yml, start-dev-bot.sh, backend/src/main/resources/application-dev.yml, backend/src/main/java/br/com/duoset/saas_service/config/persistence/routing/, frontend/src/app/(dashboard)/tenants/[id]/
principal_statement: O profile DEV inicia MANAGED_ENVIRONMENT com autoridade sintetica local e permite que o Super Admin global altere e reverta pela tela o pool exclusivo de um tenant; depois do rebuild que instala o codigo, cada operacao converge sem novo restart.
---

# Runbook — politica de pool gerenciada no DEV

## 1. Limites e resultado esperado

Execute somente no workspace e no Compose locais. O profile `dev` ativa o modo
`MANAGED_ENVIRONMENT` com envelope sintetico `80/10/5/15/1`, uma replica,
bootstrap local, membership renovavel, scheduler e API administrativa. A base
comum e HML/PRD permanecem `DARK` por default.

O resultado esperado e:

- backend e frontend iniciados pelo fluxo normal, sem launcher `LOCAL_SMOKE`;
- readiness e componente `tenantPoolRuntime` em `UP`/`READY`;
- aba `Pool de conexoes` acessivel somente ao Super Admin global sem
  impersonacao;
- PUT e rollback retornando operacao assincrona e convergindo por prepare, commit,
  swap e drain, sem rebuild entre operacoes;
- tenant B permanecendo inalterado durante operacoes no tenant A.

## 2. Pre-requisitos

- Docker local ativo e autorizado somente para este workspace;
- arquivos owner-only `.env.dev.local` e `.dev-secrets` preparados sem imprimir
  seu conteudo;
- `frontend/.env.local` configurado para o realm `saas-admin`, client
  `saas-frontend-spa` e MSW desabilitado;
- ao menos um tenant local ativo com banco provisionado e migrations validas;
- nenhuma execucao concorrente alterando o mesmo banco de plataforma;
- capacidade agregada dos tenants committed dentro do envelope configurado.

Se os arquivos owner-only ainda nao existirem, execute da raiz:

```bash
./start-dev-bot.sh --prepare-env-only
```

Esse comando prepara arquivos locais; nao registre, copie ou exiba seus valores.

## 3. Validar e iniciar o stack

Antes do rebuild, valide a migration e o gate de isolamento no Docker local:

```bash
cd /home/duoset/Documents/workspace/saas-service/backend
sudo ./mvnw -B -Dtest=TenantPoolManagedStartupCapacityPostgresTest,TenantPoolPolicyControlPlaneMigrationPostgresTest,TenantPoolPolicyStorePostgresTest,TenantPoolCapacityEnvironmentControlPlanePostgresTest,TenantPoolBlueGreenMultiInstancePostgresTest,TenantPoolCapacityMultiInstancePostgresTest,TenantPoolPolicyIntentAuditPostgresTest,TenantPoolRuntimeMembershipServicePostgresTest,TenantDatabaseRoutingIsolationIT test
sudo ./mvnw -B clean -Ptenant-isolation-gate verify
```

Os dois comandos devem terminar em `BUILD SUCCESS`, sem tratar skip como aceite.
Eles nao substituem os testes unitarios e de arquitetura do plano.

A fixture PostgreSQL/Testcontainers deve preservar a estrategia de wait nativa do
`PostgreSQLContainer`. Nao a substitua por um teste generico de listening-port:
porta aberta nao prova a readiness interna do PostgreSQL e pode antecipar a
criacao do contexto. A matriz corrente chegou a `18/18 PASS` depois de remover
essa sobrescrita e manter o wait nativo.

Da raiz do workspace:

```bash
sudo docker compose --env-file .env.dev.local -f docker-compose.yml -f docker-compose.override.yml config --quiet
sudo docker compose --env-file .env.dev.local -f docker-compose.yml -f docker-compose.override.yml up -d --build
sudo docker compose --env-file .env.dev.local -f docker-compose.yml -f docker-compose.override.yml ps -a
```

O initializer do Keycloak deve terminar com `Exited (0)` e os servicos duraveis
devem ficar ativos. O Dockerfile do backend executa build sem testes; os gates de
teste deste plano devem ser executados separadamente.

Quando somente o codigo backend mudou e as dependencias ja estao ativas:

```bash
sudo docker compose --env-file .env.dev.local -f docker-compose.yml -f docker-compose.override.yml build backend
sudo docker compose --env-file .env.dev.local -f docker-compose.yml -f docker-compose.override.yml up -d --no-deps --force-recreate backend
```

Somente `build backend` nao substitui o processo vivo. O `force-recreate` e
necessario uma vez para instalar o novo artefato; ajustes posteriores feitos pela
tela nao exigem restart.

## 4. Verificar autoridade e readiness

O healthcheck do container prova liveness, nao a readiness da capability. Valide:

```bash
curl -fsS http://127.0.0.1:8080/actuator/health/readiness
curl -fsS http://127.0.0.1:8080/actuator/health/tenantPoolRuntime
curl -fsS http://127.0.0.1:8180/realms/saas-admin/.well-known/openid-configuration >/dev/null
curl -fsSI http://127.0.0.1:3000 >/dev/null
```

O primeiro endpoint deve retornar `UP`; o componente tenant pool deve retornar
`UP` com `phase=READY`. No rebuild DEV, uma lease anterior ainda valida pode
causar espera limitada de ate uma lease, sem takeover. Budget excedido,
autoridade divergente, coverage incompleta ou committed acima do teto ambiental
devem impedir readiness.

Logs de diagnostico podem ser limitados aos containers, sem imprimir env files:

```bash
sudo docker logs saas-backend --tail 200
sudo docker logs saas-keycloak-provisioning-init --tail 200
```

## 5. Testar pela interface

1. Acesse `http://localhost:3000` e autentique como o Super Admin DEV global. A
   senha permanece no mecanismo owner-only; nao a copie para comando ou log.
2. Garanta que a impersonacao esta desligada.
3. Navegue em `Principal > Escritorios > tenant provisionado > Pool de conexoes`.
4. Confirme que a resposta inicial mostra revisoes desired/committed, capacidade,
   estado e teto ambiental; no default DEV, `maximumPoolSizeMax` e `10`.
5. Escolha um tenant A, registre os valores iniciais e solicite um ajuste dentro
   dos bounds, informando motivo operacional.
6. Aguarde a tela chegar a `CONVERGED`; confirme desired igual a committed e
   contadores ready, swapped e drained iguais ao total requerido.
   Depois do drain, a reserva de seguranca continua contabilizada por `PT15M`;
   isso nao compartilha capacidade com outro tenant nem exige restart.
7. Abra um tenant B e confirme que revisao, pool, datasource e estado nao mudaram.
8. Volte ao tenant A, crie rollback para uma revisao elegivel e aguarde novamente
   `CONVERGED`, incluindo drain completo.
9. Repita uma segunda alteracao sem reiniciar backend para provar a operacao ao
   vivo e a nova janela de polling.

No DevTools, o GET de
`/api/v1/platform/tenant-pool-policies/{tenantId}` deve responder `200` com ETag
forte. PUT/rollback devem responder `202`. Nao copie bearer token para o shell.

## 6. Diagnostico fail-closed

| Sintoma | Verificacao segura |
| --- | --- |
| Backend demora apos rebuild | Aguarde no maximo a lease DEV anterior; depois disso, falha e erro de `REPLICA_LIMIT` exigem diagnostico. |
| Readiness `DOWN` | Consulte somente o componente sanitizado e os ultimos logs; verifique capacity, coverage, membership e committed. |
| `Tenant runtime membership fence is unavailable or expired` durante recriptografia/backfill no startup | O artefato esta sem a barreira de startup corrigida ou perdeu a lease. Nao desabilite o fence: confirme que capacity, membership/evidence, pools committed e runners tenant aparecem nessa ordem e que readiness so abre ao final. Rebuild/recrie o backend com o artefato corrente; se persistir, preserve o log e interrompa o smoke. |
| `managed runtime authority differs from configured envelope` | Confirme que todo deadline criado no Java foi normalizado para microssegundos, a precisao persistivel de `TIMESTAMPTZ`, antes de `insert`, `renew` e composicao do snapshot retornado. Compare o snapshot relido de forma exata; nunca adicione tolerancia, arredondamento somente no comparador nem relaxe cluster, epoch, fence ou row version. |
| Readiness volta a `UP` sem heartbeat valido | Interrompa o smoke: reconcile nao pode promover o fence gerenciado. Confirme o artefato corrente e preserve os logs de heartbeat/capacity sem expor evidence sensivel. |
| Budget excedido | Nao aumente silenciosamente. Conte os maxima committed/reservados e ajuste apenas o envelope DEV autorizado ou os snapshots. |
| Aba ausente | Confirme Super Admin efetivo, contexto global e ausencia de impersonacao. |
| Aba abre com erro generico e nenhum GET aparece no backend para o tenant DEV `all-a` | Confirme que o frontend usa o schema tenantId canonico `8-4-4-4-12` do contrato de pool, sem exigir nibble UUID de versao. Nao troque o ID do seed nem relaxe `operationId`; instale o artefato frontend corrigido e repita o GET. |
| Login falha em volume persistido | Siga o runbook de identidade do Keycloak; rebuild backend nao reconcilia usuario persistido. |
| Operacao `FAILED` | Preserve o LKG, diagnostique o failure code e crie nova revisao; nao reutilize a revisao falha. |

## 7. HML e PRD

O mesmo binario possui propriedades tipadas em `application-hml.yml` e
`application-prd.yml`, ambos `DARK` por default e sem fallback dos numeros DEV.
Este runbook nao autoriza fornecer capacidade, editar Compose/deploy ou ativar
esses ambientes. A promocao exige sizing SRE/DBA, autoridade persistida,
observabilidade, canary, rollback e o `IP-INFRA` proprio exigido pela governanca.

## 8. Evidencia minima do ensaio

- comandos de build/start usados, sem segredos;
- status de readiness e fase sanitizada;
- tenant A e B escolhidos, usando apenas IDs/nomes locais autorizados;
- revisoes antes/depois, maxima efetivos e estado terminal;
- prova de isolamento B, rollback e drain;
- falhas, skips e comandos nao executados.

Checkpoint repository-local desta revisao: backend Compose
`running/healthy`, `restart=0`, readiness `UP`, `tenantPoolRuntime=READY` e
backfill `total=1`, `alreadyPresent=1`, `drift=0`, `failed=0`; frontend `/login`
alcancavel; API administrativa sem autenticacao responde `401`; gate de
isolamento `30/30 PASS`, sem falha, erro ou skip. O E2E
autenticado nao foi executado porque `E2E_KEYCLOAK_USERNAME`,
`E2E_KEYCLOAK_PASSWORD` e `AUTH_SESSION_SECRET` estao ausentes, e a politica
proibe extrair segredos dos containers. Esse checkpoint nao substitui o smoke
humano Super Admin A/B, rollback e drain.

## 9. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.5 | 2026-09-01 | Codex (OpenAI) | Registra o diagnostico do tenant DEV `all-a` rejeitado pelo UUID versionado do frontend antes da rede e orienta preservar seed, path canonico e IDs operacionais estritos. |
| 1.4 | 2026-09-01 | Codex (OpenAI) | Inclui a prova PostgreSQL de membership, preserva o wait nativo do Testcontainers, documenta diagnostico de precisao da autoridade e registra o checkpoint DEV sem converter disponibilidade em aceite UI autenticado. |
| 1.3 | 2026-09-01 | Codex (OpenAI) | Acrescenta diagnostico de ownership do fence e impede que reconcile seja tratado como renovacao de authority. |
| 1.2 | 2026-09-01 | Codex (OpenAI) | Documenta a barreira de startup e o diagnostico fail-closed para consumers tenant executados sem membership fence vigente. |
| 1.1 | 2026-09-01 | Codex (OpenAI) | Acrescenta os gates PostgreSQL/isolamento e explicita a retencao de capacidade por PT15M apos o drain. |
| 1.0 | 2026-09-01 | Codex (OpenAI) | Cria o procedimento do DEV gerenciado normal para rebuild, readiness, tela, isolamento A/B e rollback sem restart. |
