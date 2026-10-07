---
document_id: IP-INFRA-23.5.1-tenant-pool-policy-managed-hml-activation
primary_nature: Plano
objective: Materializar e validar, exclusivamente no repositorio, o contrato operacional fail-closed para uma futura ativacao controlada da politica gerenciada de pool por tenant em HML.
scope: Wiring HML de TENANT_POOL_MANAGED_*, contrato env example nao secreto, provisionamento autoritativo de capacidade, identidade de runtime, fases DARK/PREPARE/ACTIVE/DRAIN_ONLY, readiness, observabilidade, runbook e testes repository-local.
non_objectives: Aprovar ou iniciar implementacao; acessar, configurar ou executar HML real; fazer deploy; ler ou criar segredo; inferir sizing; habilitar cache ou external release; criar IP-INFRA PRD; alterar PRD, producao ou infraestrutura externa.
owner: Engenharia / DevOps
status: Draft
related_files: docs/product/requirements/REQ-00052-tenant-pool-policy-controlled-hml-prd-rollout.md, TP-00030-tenant-pool-policy-hml-prd-controlled-rollout.md
date: 2026-09-02
version: 1.0
last_reviewed: 2026-09-02
keywords: tenant, pool, hml, managed-environment, capacity, runtime-identity, readiness, rollout
code_references: docker-compose.hml.yml, backend/src/main/resources/application-hml.yml, backend/src/main/java/br/com/duoset/saas_service/config/persistence/routing/, backend/src/main/java/br/com/duoset/saas_service/contexts/tenant/, infra/deploy/, infra/scripts/, infra/monitoring/prometheus/
principal_statement: Este plano Proposed especifica apenas mudancas e provas repository-local para HML; nao aprova implementacao, nao autoriza efeito ambiental e mantem HML em DARK ate gates humanos posteriores e independentes.
allocation_gate_evidence: docs/product/requirements/REQ-00052-tenant-pool-policy-controlled-hml-prd-rollout.md#hml-ip-infra-allocation
approved_gate_evidence: ""
in_progress_gate_evidence: ""
completed_gate_evidence: ""
cancelled_gate_evidence: ""
---

# IP-INFRA-23.5.1-tenant-pool-policy-managed-hml-activation — Ativacao gerenciada da politica de pool em HML

> **Declaracao principal:** este plano alocado em `Proposed` delimita a futura implementacao repository-local do adapter HML; nesta fase permite somente revisao e validacao documental, sem autorizar codificacao de produto/infra, comando operacional, acesso ao ambiente, deploy ou ativacao. HML deve permanecer `DARK` ate os gates `Approved`, `In Progress` e de efeito externo aplicaveis.

## Autoridade e lifecycle

| Campo | Valor |
| --- | --- |
| Estado atual | `Proposed` |
| Gate de alocacao | `docs/product/requirements/REQ-00052-tenant-pool-policy-controlled-hml-prd-rollout.md#hml-ip-infra-allocation` |
| Alcadas representadas/delegadas | O gate de alocacao permite somente criar este ID/path em `Proposed`, com escopo repository-local HML; nao delega aprovacao, inicio, acesso ambiental ou deploy. |
| Proxima transicao permitida | `Approved`, somente por novo aceite humano explicito e evidencia distinta. |

Cada campo de evidencia deve apontar para um documento governado `Approved` ou
`Completed`, com fragmento de decisao e mencao ao `document_id` exato. Evidencias
nao podem ser autorreferencias, indices, templates, URLs ou caminhos externos. Os
campos de transicoes futuras ficam vazios ate seus respectivos gates acontecerem.

O fragmento referenciado deve conter um unico registro inequívoco no formato
governado pela colecao:

```text
ip_infra_gate: subject=<document_id>; gate_kind=<allocation|approved|in_progress|completed|cancelled>; decision=Approved; decided_at=<AAAA-MM-DD>; approver=<pessoa ou alcada humana>; anchor=<fragmento>
```

## Contexto, objetivo e escopo

O profile `hml` ja declara o contrato tipado do runtime gerenciado e preserva
`DARK` como default. O Compose HML ainda nao transporta o conjunto
`TENANT_POOL_MANAGED_*`; nao existe contrato ambiental versionado, provisionador
seguro da autoridade de capacidade, identidade nova por processo/restart,
aceite HML baseado no componente `tenantPoolRuntime`, alertas operacionais
completos nem runbook proprio de ativacao.

O objetivo verificavel deste plano e deixar o repositorio apto a representar e
validar uma configuracao HML completa, sem converter essa aptidao em deploy ou
readiness real. A futura implementacao, somente depois de `Approved` e
`In Progress`, inclui:

1. wiring explicito e testavel das variaveis owner-supplied
   `TENANT_POOL_MANAGED_*` do profile HML e injecao separada da identidade efemera
   pelo adapter de runtime;
2. contrato `.env.example` versionado, nao secreto e incapaz de fornecer sizing
   DEV ou credencial;
3. provisionador idempotente, transacional e fail-closed da capacidade
   autoritativa, com `dry-run`, `create-or-verify` e alteracao por CAS;
4. `deploymentEpoch` proprio da release e `runtimeInstanceId` unico, gerado e
   exportado pelo entrypoint HML imediatamente antes de cada `exec` da JVM, com
   tratamento conservador das leases antigas;
5. representacao integral das matrizes `DARK`, `PREPARE`, `ACTIVE` e
   `DRAIN_ONLY`, sem combinacao hibrida de flags;
6. aceite por readiness geral `UP` e componente `tenantPoolRuntime=READY`;
7. metricas, alertas e dashboard sem cardinalidade tenant-scoped;
8. runbook HML com precondicoes, comandos propostos, stop conditions, rollback e
   evidencias sanitizadas;
9. testes locais de shell, Compose com valores dummy, backend PostgreSQL,
   arquitetura e isolamento.

### Matriz fechada de arquivos da implementacao futura

Os paths abaixo sao normativos para este plano. Qualquer path adicional ou troca
de mecanismo exige refinamento deste `Proposed` ou nova aprovacao antes do inicio.

| Responsabilidade | Path exato | Acao planejada |
| --- | --- | --- |
| Wiring, fases e healthcheck HML | `docker-compose.hml.yml` | Alterar somente o servico backend: variaveis owner-supplied sem default DEV, entrypoint gerenciado e healthcheck `/actuator/health/readiness`. |
| Contrato HML nao secreto | `infra/deploy/tenant-pool-policy-hml.env.example` | Criar com tipos/origens e valores vazios; omitir segredo, sizing aprovado e runtime instance ID. |
| Validacao fail-closed da matriz | `infra/scripts/validate-tenant-pool-policy-hml-config.sh` | Criar; parser sem `source`/`eval`, somente `--env-file` explicito e `--phase`, sem carregar `.env` implicitamente. |
| Teste sintetico do contrato/Compose | `infra/scripts/tests/tenant-pool-policy-hml-config-test.sh` | Criar; usar diretorio privado de `mktemp`, valores dummy e somente `config --quiet`. |
| Adapter de identidade do orquestrador | `backend/docker/tenant-pool-managed-runtime-entrypoint.sh` | Criar; gerar a identidade efemera imediatamente antes de executar a JVM e nunca aceitar valor owner-supplied. |
| Empacotamento do adapter | `backend/Dockerfile` | Alterar somente para copiar o entrypoint; o uso fica restrito ao override HML. |
| Teste sintetico de identidade | `backend/scripts/tests/tenant-pool-managed-runtime-entrypoint-test.sh` | Criar; provar unicidade por exec, imutabilidade intraprocesso, redacao e falha fechada. |
| Guard de configuracao gerenciada | `backend/src/main/java/br/com/duoset/saas_service/config/persistence/routing/lifecycle/TenantPoolPolicyAuthorizedTestEnvironmentGuard.java` | Rejeitar explicitamente cache ligado em HML/PRD e qualquer identidade ausente/reutilizada fora do DEV local. |
| Testes do guard/runtime | `backend/src/test/java/br/com/duoset/saas_service/config/persistence/routing/lifecycle/TenantPoolPolicyAuthorizedTestEnvironmentGuardTest.java` e `backend/src/test/java/br/com/duoset/saas_service/config/persistence/routing/lifecycle/TenantPoolManagedRuntimeCoordinatorTest.java` | Estender para cache, HML sem injecao e ausencia de geracao backend ambiental. |
| API PostgreSQL governada de capacidade | `backend/src/main/resources/db/migration/tenant/V74__add_tenant_pool_capacity_authority_provisioner.sql` | Criar funcoes estritas de dry-run, create-or-verify e CAS sob lock/fence; se `V74` deixar de estar livre, pausar e atualizar este plano antes de editar. |
| Teste PostgreSQL do provisionador | `backend/src/test/java/br/com/duoset/saas_service/contexts/tenant/internal/infrastructure/persistence/pool/TenantPoolCapacityAuthorityProvisionerPostgresTest.java` | Criar; cobrir idempotencia, mismatch, CAS stale, concorrencia, membership/reserva ativa e rollback. |
| Wrapper owner-only de capacidade | `infra/scripts/tenant-pool-capacity-authority.sh` | Criar com dry-run default e apply/CAS explicitos; chamar somente a funcao governada via `docker compose exec -T postgres-app psql`, sem segredo em argv/log. |
| Teste sintetico do wrapper | `infra/scripts/tests/tenant-pool-capacity-authority-test.sh` | Criar com fake Docker; cobrir argv, redacao, bloqueios e ausencia de efeito externo. |
| Estado gerenciado observavel | `backend/src/main/java/br/com/duoset/saas_service/config/persistence/routing/observability/TenantPoolRuntimeMetrics.java` | Estender apenas com dimensoes bounded de readiness, autoridade, membership e fencing. |
| Dimensoes/allowlist bounded | `backend/src/main/java/br/com/duoset/saas_service/config/persistence/routing/observability/TenantPoolMetricDimensions.java`, `backend/src/main/java/br/com/duoset/saas_service/config/persistence/routing/observability/AggregatingTenantPoolMetricsTrackerFactory.java` e `backend/src/main/java/br/com/duoset/saas_service/shared/config/metrics/TenantPoolMeterPolicy.java` | Estender sem tenant, UUID, database, revisao ou pool name. |
| Publicacao de readiness | `backend/src/main/java/br/com/duoset/saas_service/config/persistence/routing/lifecycle/TenantPoolManagedReadinessFinalizer.java` | Publicar o estado agregado sem tenant, UUID, database ou pool name. |
| Testes de metricas/readiness | `backend/src/test/java/br/com/duoset/saas_service/config/persistence/routing/observability/TenantPoolMetricsLifecycleTest.java`, `backend/src/test/java/br/com/duoset/saas_service/config/persistence/routing/observability/TenantPoolMeterCardinalityTest.java` e `backend/src/test/java/br/com/duoset/saas_service/config/persistence/routing/lifecycle/TenantPoolManagedReadinessFinalizerTest.java` | Estender com estados bounded, redacao e `READY`/`DOWN`. |
| Validador de readiness | `infra/scripts/validate-tenant-pool-hml-readiness.sh` | Criar parser JSON offline que exige geral `UP`, componente `tenantPoolRuntime` `UP` e detalhe `phase=READY`; a chamada HTTP fica no wrapper ambiental futuro. |
| Teste sintetico de readiness | `infra/scripts/tests/tenant-pool-hml-readiness-test.sh` | Criar com respostas JSON locais positivas/negativas, sem rede. |
| Alertas HML objetivos | `infra/monitoring/prometheus/alert_rules.yml` | Acrescentar somente invariantes sem sizing inferido: readiness negativa, fenced, timeout/failure e headroom zero. |
| Template de thresholds HML | `infra/monitoring/prometheus/tenant-pool-alert-thresholds.hml.yml.example` | Criar sem valores e sem carga pelo Prometheus; SRE deve aprovar antes de qualquer regra dependente de threshold/janela. |
| Dashboard HML | `infra/monitoring/grafana/dashboards/tenant-pool-runtime.json` | Criar paineis agregados, sem label tenant-scoped. |
| Teste sintetico de observabilidade | `infra/scripts/tests/tenant-pool-observability-test.sh` | Criar; validar nomes, allowlist, cardinalidade, expressoes e ausencia de dado sensivel. |
| Orquestracao futura, nao executada | `infra/scripts/activate-hml-tenant-pool-policy.sh` | Criar wrapper fail-closed de fase, readiness, stop e rollback; execucao exige gate ambiental separado. |
| Teste sintetico da orquestracao | `infra/scripts/tests/activate-hml-tenant-pool-policy-test.sh` | Criar com doubles locais; provar que nenhum caminho de teste acessa HML. |
| Runbook HML | `docs/onboarding/tenant-pool-policy-managed-hml-runbook.md` | Criar em `Draft` e indexar em `docs/onboarding/README.md`; nao publicar comandos como autorizados. |

O provisionador permanece infraestrutura owner-only porque a capacidade do
cluster nao e configuracao de produto nem operacao da interface Super Admin. A
API PostgreSQL nasce por migration do modulo Tenant, e nao como SQL ad hoc em
Infra, endpoint HTTP/UI ou `ApplicationRunner` da aplicacao completa. Ela usa a
mesma linha autoritativa e o mesmo lock `FOR UPDATE` do allocator; um advisory
transaction lock serve somente para serializar a chave ainda ausente. Criacao
depende da unicidade da chave e verificacao committed. Mudanca usa CAS por
`row_version` e `allocator_fence` esperados e rejeita membership vigente ou
reserva retida. O wrapper nao e ligado ao startup nem ao `docker compose up`,
evitando escrita ambiental acidental.

O entrypoint e a integracao do orquestrador exigida pelo ADR-0052. O Compose HML
o seleciona somente para o servico backend e fornece a JVM como comando; fora de
HML, o `ENTRYPOINT` atual da imagem permanece inalterado. Em modo gerenciado, o
adapter rejeita identidade preexistente, obtem entropia do kernel, exporta uma
identidade nova e faz `exec` da JVM. Em `DARK`, apenas encaminha o processo sem
inventar identidade.

A topologia Compose vigente fixa `container_name` e nao comprova scale nem rolling
multi-replica. Portanto `replicasMax` representa somente capacidade aprovada, nao
quantidade inferida de containers. Este IP nao remove essa restricao: qualquer
rolling multi-replica exige inventario/topologia e gate proprios; um restart HML
deve contabilizar ou aguardar a lease anterior de forma conservadora. O healthcheck
HML deixa de aceitar mera liveness e aponta para readiness, mas isso nao transforma
o Compose local em evidencia ambiental.

Permanecem fora do escopo:

- qualquer leitura de `.env` real, `.deploy/`, segredo, token, dump, backup,
  tenant ou dado ambiental;
- execucao de `up`, `run`, `exec`, deploy, SSH, provider, cluster ou HML;
- escolha ou inferencia dos numeros de capacidade, thresholds, janela, tenant
  canario, tenant controle, operador ou credencial;
- habilitacao de cache Redis; o primeiro rollout HML mantem cache `OFF`;
- alteracao de PRD, workflow de producao ou criacao do IP-INFRA PRD;
- `external-release`, auto-apply, autorremediacao de drift, force-close de
  conexao/transacao ou liberacao otimista de reserva/lease;
- edicao dos parametros ambientais de capacidade pela interface Super Admin.

## Contrato de configuracao HML proposto

### Inventario obrigatorio

O wiring deve transportar os nomes abaixo sem renome, valor implicito DEV ou
recomposicao silenciosa. O contrato de exemplo documenta presenca, tipo e origem;
os valores ambientais efetivos continuam pertencendo aos owners de HML.

| Grupo | Variaveis |
| --- | --- |
| Modo | `TENANT_POOL_MANAGED_MODE` |
| Envelope de capacidade | `TENANT_POOL_MANAGED_ENVIRONMENT_MAXIMUM_POOL_SIZE`, `TENANT_POOL_MANAGED_SAFE_CONNECTION_BUDGET`, `TENANT_POOL_MANAGED_REPLICAS_MAX`, `TENANT_POOL_MANAGED_PLATFORM_POOL_MAX`, `TENANT_POOL_MANAGED_MIGRATION_ADMIN_RESERVE`, `TENANT_POOL_MANAGED_EMERGENCY_HEADROOM` |
| Leitura e aplicacao | `TENANT_POOL_MANAGED_API_READ_ENABLED`, `TENANT_POOL_MANAGED_MUTATIONS_ENABLED`, `TENANT_POOL_MANAGED_AUTHORITATIVE_READ_ENABLED`, `TENANT_POOL_MANAGED_CANDIDATE_APPLY_ENABLED`, `TENANT_POOL_MANAGED_REVISION_APPLY_ENABLED`, `TENANT_POOL_MANAGED_FAIL_CLOSED_CUTOVER_ENABLED` |
| Lifecycle e capacidade | `TENANT_POOL_MANAGED_INITIAL_ONBOARDING_ENABLED`, `TENANT_POOL_MANAGED_CAPACITY_PREFLIGHT_ENABLED`, `TENANT_POOL_MANAGED_CAPACITY_RESERVATION_ENABLED`, `TENANT_POOL_MANAGED_MEMBERSHIP_FENCING_ENABLED`, `TENANT_POOL_MANAGED_RECONCILE_ENABLED` |
| Cache e observabilidade | `TENANT_POOL_MANAGED_CACHE_ENABLED`, `TENANT_POOL_MANAGED_OBSERVABILITY_ENABLED` |
| Coverage | `TENANT_POOL_MANAGED_BACKFILL_ENABLED`, `TENANT_POOL_MANAGED_SHADOW_ENABLED` |
| Evidencia e identidade estavel | `TENANT_POOL_MANAGED_RUNTIME_EVIDENCE_ENABLED`, `TENANT_POOL_MANAGED_CLUSTER_ID`, `TENANT_POOL_MANAGED_DEPLOYMENT_EPOCH` |
| Identidade efemera do processo | `TENANT_POOL_MANAGED_RUNTIME_INSTANCE_ID`, gerada/injetada somente pelo entrypoint HML imediatamente antes da JVM; proibida no env file owner-supplied |
| Lease | `TENANT_POOL_MANAGED_LEASE_DURATION`, `TENANT_POOL_MANAGED_HEARTBEAT_INTERVAL`, `TENANT_POOL_MANAGED_RENEWAL_SAFETY_MARGIN` |

O futuro adapter deve observar estes invariantes:

- `DARK`/`false` sao defaults de seguranca, nao valores de capacidade;
- ao selecionar `MANAGED_ENVIRONMENT`, envelope, identidade estavel, duracoes e
  matriz devem estar integralmente presentes; o entrypoint deve gerar e exportar
  a identidade efemera antes de iniciar o backend;
- `TENANT_POOL_MANAGED_REPLICAS_MAX` deve ser unico e identico no envelope e no
  runtime;
- valores vazios, placeholders, overflow, booleano invalido, combinacao parcial,
  copia de DEV ou substituicao silenciosa bloqueiam renderizacao/startup;
- `external-release-enabled` e `local-bootstrap-enabled` permanecem hardcoded em
  `false` no profile HML;
- `TENANT_POOL_MANAGED_CACHE_ENABLED=false` permanece obrigatorio neste plano;
- o `.env.example` nao contem segredo, sizing aprovado nem
  `TENANT_POOL_MANAGED_RUNTIME_INSTANCE_ID` e nao e usado como arquivo de deploy;
  fixtures dummy distintas servem apenas a testes locais;
- validadores e scripts nunca executam `env`, `set -x`, dump de configuracao ou
  mensagem que revele password, URL com credencial, token ou conteudo de arquivo
  secreto.

### Matrizes atomicas de fase

`PREPARE`, `ACTIVE` e `DRAIN_ONLY` sao fases derivadas de conjuntos exatos de
flags com `TENANT_POOL_MANAGED_MODE=MANAGED_ENVIRONMENT`. Nao sao novos valores
do enum de modo. A configuracao deve ser gerada ou validada atomicamente:

| Chave/grupo | `DARK` | `PREPARE` | `ACTIVE` | `DRAIN_ONLY` |
| --- | --- | --- | --- | --- |
| `TENANT_POOL_MANAGED_MODE` | `DARK` | `MANAGED_ENVIRONMENT` | `MANAGED_ENVIRONMENT` | `MANAGED_ENVIRONMENT` |
| API read, authoritative read, revision apply, membership fencing, reconcile e observabilidade | `false` | `true` | `true` | `true` |
| Runtime evidence | `false` | `true` | `true` | `true` |
| Mutations e capacity preflight | `false` | `false` | `true` | `false` |
| Candidate apply e capacity reservation | `false` | `false` | `true` | `false` |
| Fail-closed cutover | `false` | `false` | `true` | `true` |
| Initial onboarding | `false` | `true` | `true` | `false` |
| Backfill e shadow | `false` | `true` | `false` | `false` |
| Cache | `false` | `false` | `false` | `false` |
| External release/local bootstrap | `false` | `false` | `false` | `false` |

Qualquer estado que nao corresponda exatamente a uma linha vertical valida deve
falhar fechado. A unica promocao permitida e `DARK -> PREPARE -> ACTIVE`; a unica
desativacao operacional e `ACTIVE -> DRAIN_ONLY -> DARK`.

## Capacidade autoritativa e identidade

O provisionador repository-local proposto deve:

1. usar `dry-run` como caminho sem efeito e exigir opcao explicita distinta para
   aplicar, alem do futuro gate ambiental;
2. receber valores nao secretos tipados separadamente do mecanismo de credencial
   owner-only; segredo nunca pode ser argumento de linha de comando ou log;
3. abrir uma transacao no datasource da plataforma e adquirir o mesmo lock/fence
   autoritativo usado pelo allocator;
4. se a chave ambiental nao existir, criar exatamente um registro
   `CONFIGURED` com cluster, `replicasMax`, envelope e versao esperados;
5. se existir e for byte-a-byte/field-a-field equivalente, retornar
   `ALREADY_CONFIGURED` sem update e sem incrementar versao;
6. se existir com qualquer divergencia, abortar; mudanca somente por operacao CAS
   separada, com versao/hash esperado e novo capacity proof aprovado;
7. rejeitar CAS enquanto existir membership `REGISTERED`/`ACTIVE` nao expirada ou
   reserva `HELD`/`STABILIZING`/`RELEASABLE`/`DEGRADED`, forçando alteracao de
   capacidade somente no boundary `DARK` e drenado;
8. reconsultar e verificar o estado committed na mesma transacao, sem
   `upsert`, last-write-wins, delete/recreate, clamp ou fallback;
9. emitir apenas resultado sanitizado, identificador operacional nao sensivel e
   hash seguro da intencao; nunca imprimir JDBC URL, usuario, senha, tenant,
   database binding ou conteudo do arquivo de credencial;
10. possuir testes PostgreSQL para create, verify idempotente, conflito, CAS stale,
   concorrencia, rollback transacional e ausencia de vazamento em stdout/stderr.

O lifecycle de identidade deve separar:

- `clusterId`: identidade estavel e exclusiva do cluster HML aprovado;
- `deploymentEpoch`: valor nao secreto novo a cada release/rollback operacional,
  materializado uma vez pelo mecanismo de release;
- `runtimeInstanceId`: valor nao secreto e imprevisivelmente unico, gerado pela
  integracao do orquestrador — o adapter/entrypoint exclusivo do servico backend
  HML — dentro do container e exportado imediatamente antes de cada `exec` da
  JVM, inclusive restart do mesmo container. O backend apenas exige e consome a
  injecao imutavel durante a vida do processo; nao gera, persiste, reutiliza nem
  aplica fallback para esse valor. O env file de operador nao pode fornece-lo.

O startup nao reutiliza identidade persistida. Diante de lease antiga sem
terminacao autoritativa, deve aguardar expiracao mais margem ou falhar fechado;
nao pode apagar membership, reduzir contador, liberar quota ou assumir morte da
instancia. Rolling restart deve considerar simultaneamente runtime antigo e novo
no `replicasMax` e no budget. Reutilizacao, colisao, epoch divergente, CAS stale ou
ausencia de margem bloqueiam readiness e novas aquisicoes.

## Dependencias e pre-condicoes

| Item | Evidencia | Estado | Comportamento fail-closed |
| --- | --- | --- | --- |
| Gate de alocacao do ID/path | `docs/product/requirements/REQ-00052-tenant-pool-policy-controlled-hml-prd-rollout.md#hml-ip-infra-allocation` | `RECORDED` | Sem referencia valida, este arquivo nao pode existir como plano governado. |
| Gate `Approved` deste plano | `approved_gate_evidence` | `NOT_PROVEN` | Nenhuma mudanca de codigo, Compose, script ou documento operacional pode iniciar. |
| Gate `In Progress` deste plano | `in_progress_gate_evidence` | `NOT_PROVEN` | Mesmo aprovado, nenhum arquivo de implementacao ou teste pode ser alterado. |
| REQ-00052 e TP-00030 coerentes com o escopo HML | Fontes em `related_files` | `REQUIRED` | Divergencia de autoridade interrompe o plano e retorna aos owners. |
| Capacity proof HML medido e aprovado | Evidencia futura SRE/DBA, sem valores neste plano | `NOT_PROVEN` | `MANAGED_ENVIRONMENT` nao renderiza/inicia e nenhum valor DEV e usado. |
| Revisao de Seguranca | Evidencia futura de rede, TLS, IAM, secrets, RBAC e auditoria | `NOT_PROVEN` | Nenhum gate ambiental ou comando com credencial e permitido. |
| Revisao de Dados | Evidencia futura de PostgreSQL, lock/CAS, backup, restore e estado | `NOT_PROVEN` | Provisionamento ambiental e rollout permanecem bloqueados. |
| Identidade e topologia HML | Inventario futuro, sanitizado e aprovado | `NOT_PROVEN` | Cluster, epoch, instance ou replicas ausentes/divergentes falham fechado. |
| Observabilidade e thresholds | Evidencia futura de SRE/DevOps | `NOT_PROVEN` | `PREPARE`/`ACTIVE` e qualquer janela de observacao permanecem bloqueados. |
| Autorizacao de acesso/deploy HML | Gate humano futuro fora deste plano Proposed | `NOT_PROVEN` | Nenhum comando ambiental e executado, ainda que todos os testes locais passem. |
| IP-INFRA PRD e evidencia HML terminal | Fora do escopo deste artefato | `BLOCKED` | Nenhuma alteracao, alocacao ou ativacao de PRD pode ser inferida. |

## Work packages e checkpoints humanos

| Etapa | Entrega | Dependencias | Gate humano | Estado |
| --- | --- | --- | --- | --- |
| WP-HML-0 | Revisao deste plano e fechamento de paths/owners sem ampliar o escopo | Gate de alocacao | Engenharia/DevOps, Arquitetura, SRE/DBA, Seguranca e Dados | `Em revisao`; permitido em `Proposed` |
| WP-HML-1 | Wiring Compose HML de todo `TENANT_POOL_MANAGED_*`, contrato example e validador condicional sem defaults DEV | `Approved` + `In Progress` | Maintainer Humano de Infraestrutura | `Blocked` |
| WP-HML-2 | Provisionador idempotente `dry-run`/`create-or-verify`/CAS e testes PostgreSQL | WP-HML-1 + desenho de Dados | SRE/DBA + Dados + Seguranca | `Blocked` |
| WP-HML-3 | Identidade por release/processo e politica conservadora de lease/restart | WP-HML-1 + topologia HML aprovada | DevOps + SRE/DBA + Arquitetura | `Blocked` |
| WP-HML-4 | Check de readiness `UP` + `tenantPoolRuntime=READY`, metricas, alertas e dashboard | WP-HML-2 + WP-HML-3 | SRE/DevOps + Seguranca | `Blocked` |
| WP-HML-5 | Runbook HML indexado com fases, stop conditions, evidencias e rollback | WP-HML-1 a WP-HML-4 | DevOps + SRE/DBA + Qualidade | `Blocked` |
| WP-HML-6 | Testes shell/Compose dummy/backend PostgreSQL/arquitetura/isolation e validadores documentais | WP-HML-1 a WP-HML-5 | Qualidade + owners impactados | `Blocked` |
| WP-HML-7 | Handoff repository-local, sem executar HML | WP-HML-6 sem falha ou skip convertido em aceite | Maintainer Humano de Infraestrutura | `Blocked` |
| WP-HML-8 | Futuro pedido separado de acesso e efeito HML | Plano repository-local concluido e capacity proof real | Maintainer Humano + owners ambientais | `Blocked` |

Nenhum checkpoint pode ser pulado. `Proposed` permite revisar/refinar o plano e
executar somente seus validadores documentais. `Approved` aceita o escopo, mas
ainda nao autoriza editar artefatos de implementacao. `In Progress` e a evidencia
distinta necessaria para iniciar a implementacao repository-local. WP-HML-8 nao e
autorizado por este documento.

## Readiness, metricas e alertas

O aceite futuro do adapter HML deve exigir simultaneamente:

- health group de readiness com estado geral `UP`;
- componente autorizado `tenantPoolRuntime` exatamente `READY`;
- membership corrente, fencing dentro da margem, capacity authority exata,
  coverage integral e committed/binding sem drift;
- check sem logar resposta autenticada, token, tenant ou detalhes de binding;
- ausencia de aceite por liveness, mero status do container ou espera temporal.

Prometheus deve continuar raspando metricas bounded. Alertas e dashboard devem
cobrir, sem labels de tenant/UUID/database/revisao/pool name:

- saturacao, tempo de aquisicao e timeouts;
- rejeicao de capacidade e headroom agregado;
- falhas de candidate, probe, commit, swap, apply e reconcile;
- drift de revisao/autoridade, perda de heartbeat/fencing e readiness `DOWN`;
- geracoes simultaneas, drain prolongado e reserva retida.

Thresholds e janela nao serao inferidos no repositorio. O contrato deve exigir
valores aprovados pelo owner ambiental e falhar fechado quando ausentes. Cache
permanece `OFF`; este plano nao cria alerta para justificar sua habilitacao.

## Seguranca, dados e tenants

- Dados permitidos nesta implementacao: fixtures sinteticas, valores dummy e
  identificadores locais nao sensiveis.
- Dados proibidos: tenant real, UUID/slug real, credencial, token, JDBC URL real,
  payload, dump, backup, state, `.env` owner-only e conteudo de `.deploy/`.
- O canario HML, o controle B e seus operadores nao sao escolhidos por este plano;
  futura operacao exige tenants sinteticos dedicados e autorizacao propria.
- O provisionador altera somente a autoridade ambiental da plataforma; nunca
  escreve banco dedicado de tenant nem torna capacidade editavel por Super Admin.
- Cada pool, candidate, slot, geracao, lease, drain e rollback permanece exclusivo
  do tenant; ausencia de contexto nao usa fallback da plataforma ou de outro tenant.
- Arquivos example permanecem sem segredo. Credenciais futuras usam mecanismo
  owner-only existente, fora de argv, stdout/stderr e do repositorio.
- Seguranca revisa rede, TLS, IAM, secret handling, RBAC e auditoria; Dados revisa
  PostgreSQL, lock/CAS, capacidade, backup/restore e qualquer efeito stateful.
- Nenhuma etapa local concede acesso a HML ou substitui segregacao de funcoes.

## Plano de validacao

Os validadores documentais desta criacao em `Proposed` sao executaveis agora por
forca do ADR-0000, do TP-00030 e da autorizacao humana de 2026-09-02. Testes de
shell, Compose e backend pertencentes a implementacao futura dependem do gate
`In Progress`; qualquer teste que precise de Docker local, download ou permissao
especial obedece tambem ao gate do ambiente de execucao. Nenhum comando abaixo
autoriza HML.

### Documentacao da criacao `Proposed`

```bash
bash infra/scripts/tests/validate-ip-infra-docs-test.sh
./infra/scripts/validate-docs.sh
```

### Shell da implementacao futura

Depois de `In Progress`, executar:

```bash
bash -n backend/docker/tenant-pool-managed-runtime-entrypoint.sh infra/scripts/validate-tenant-pool-policy-hml-config.sh infra/scripts/tenant-pool-capacity-authority.sh infra/scripts/validate-tenant-pool-hml-readiness.sh infra/scripts/activate-hml-tenant-pool-policy.sh
bash infra/scripts/tests/tenant-pool-policy-hml-config-test.sh
bash backend/scripts/tests/tenant-pool-managed-runtime-entrypoint-test.sh
bash infra/scripts/tests/tenant-pool-capacity-authority-test.sh
bash infra/scripts/tests/tenant-pool-hml-readiness-test.sh
bash infra/scripts/tests/tenant-pool-observability-test.sh
bash infra/scripts/tests/activate-hml-tenant-pool-policy-test.sh
```

### Compose e contrato ambiental

- renderizar somente `config --quiet`, com arquivo temporario dummy explicito e
  as combinacoes base + HML; nunca carregar `.env` implicitamente;
- provar inventario completo, passagem literal e ausencia de defaults DEV;
- provar `DARK` sem autoridade ambiental e cada matriz gerenciada integral;
- rejeitar variavel ausente/vazia, matriz hibrida, cache/external release ligados,
  replicas divergentes, identidade repetida e duration insegura;
- provar que nenhum teste executa `up`, `run`, `exec`, rede ou HML.

O teste focal exato cria sua fixture em diretorio privado obtido por `mktemp -d`,
resolve o path antes da chamada e executa internamente apenas:

```bash
bash infra/scripts/tests/tenant-pool-policy-hml-config-test.sh
```

### Backend PostgreSQL, arquitetura e isolamento

Os seletores devem ser confirmados contra o codigo vigente no inicio do WP-HML-6.
O minimo proposto inclui:

```bash
cd backend
./mvnw -B -Dtest=TenantPoolPolicyControlPlaneMigrationPostgresTest,TenantPoolCapacityAuthorityProvisionerPostgresTest,TenantPoolCapacityEnvironmentControlPlanePostgresTest,TenantPoolBlueGreenMultiInstancePostgresTest,TenantPoolCapacityMultiInstancePostgresTest,TenantPoolPolicyIntentAuditPostgresTest test
./mvnw -B -Dtest=ModuleStructureVerificationTest,CleanArchitectureRulesTest,CleanArchitectureRuleContractTest test
./mvnw -B clean -Ptenant-isolation-gate verify
```

Testes adicionais do provisionador devem cobrir `dry-run`, create, verify
idempotente, CAS stale, conflito concorrente, rollback transacional e redacao de
logs. Testes de identidade devem cobrir duas instancias, restart do mesmo
container, epoch novo, lease antiga, margem, replicas excedidas e readiness
fail-closed. Falha, erro ou skip nao equivale a aceite.

## Stop conditions

Interromper antes da mudanca repository-local se faltar `Approved` ou
`In Progress`. Depois de iniciado, interromper e retornar aos owners diante de:

- referencia documental divergente, escopo ampliado ou necessidade de tocar PRD;
- capacidade/threshold inferido, default DEV, placeholder ou segredo no repo/log;
- necessidade de ler `.env`, `.deploy/`, provider, HML, tenant ou dado real;
- matriz hibrida, cache/external release habilitado ou local bootstrap em HML;
- provisionamento sem lock/CAS, update destrutivo, identity reuse ou liberacao
  otimista de lease/reserva;
- readiness sem `tenantPoolRuntime=READY`, observabilidade ausente ou label de alta
  cardinalidade/sensivel;
- teste falho, skip usado como aceite ou Compose que exija efeito;
- ausencia de revisao de Seguranca/Dados ou qualquer nova dependencia material.

Para uma futura operacao HML, tambem sao stop conditions: readiness `DOWN`, CAS
stale, authority/coverage/drift divergente, heartbeat/fence sem margem, budget
excedido, drain preso, isolamento A/B inconclusivo, alerta sem resposta ou gate
humano pendente.

## Rollback e recuperacao

Durante a futura implementacao repository-local, cada work package deve permanecer
reversivel e isolado. Uma falha reverte apenas os arquivos daquele pacote pelo
Maintainer Humano, preservando migrations e contratos aditivos ja aceitos. Nao ha
efeito ambiental a recuperar nesta fase documental/repository-local.

Antes de qualquer HML real, o runbook deve provar:

1. bloqueio de novas mutacoes e candidates;
2. transicao integral `ACTIVE -> DRAIN_ONLY`;
3. conclusao segura de committed/swap/drain e retorno posterior a `DARK`;
4. ausencia de force-close de conexao ou transacao em voo;
5. preservacao de revisoes, heads, intents, reservations, applications, membership
   e audit;
6. rollback funcional por nova revisao do mesmo tenant, novamente submetida a
   capacity admission, candidate, probe, commit, swap e drain;
7. expiracao conservadora de lease antiga, sem delete/reuse; capacity authority
   divergente e corrigida somente por novo CAS aprovado;
8. migrations forward-only; restore de banco e disaster recovery permanecem
   operacoes separadas, sujeitas a autorizacao propria.

O sinal de abortar nao autoriza automaticamente executar rollback ambiental. O
operador e as alcadas futuras devem estar identificados no runbook e no gate de
efeito HML.

## Evidencias e handoff

| Evidencia | Resultado | Referencia |
| --- | --- | --- |
| Alocacao exata deste ID/path | `RECORDED` | `docs/product/requirements/REQ-00052-tenant-pool-policy-controlled-hml-prd-rollout.md#hml-ip-infra-allocation` |
| Sintaxe dos validadores documentais | `PASS` | `bash -n infra/scripts/validate-docs.sh infra/scripts/validate-ip-infra-docs.sh infra/scripts/tests/validate-ip-infra-docs-test.sh` em 2026-09-02 |
| Teste focal da governanca IP-INFRA | `PASS` | `validate-ip-infra-docs-test.sh`; coleção real reconhecida com 1 plano especifico em 2026-09-02 |
| Gate documental global | `PASS` | 691 Markdown, 30 diretorios, 671 artefatos indexados e estrutura valida em 2026-09-02 |
| Aprovacao do plano | `NOT_PROVEN` | `approved_gate_evidence` vazio |
| Autorizacao de inicio | `NOT_PROVEN` | `in_progress_gate_evidence` vazio |
| Wiring e contrato example HML | `NOT_PROVEN` | WP-HML-1 bloqueado |
| Provisionador e provas PostgreSQL | `NOT_PROVEN` | WP-HML-2 bloqueado |
| Identidade/restart/lease | `NOT_PROVEN` | WP-HML-3 bloqueado |
| Readiness, metricas e alertas | `NOT_PROVEN` | WP-HML-4 bloqueado |
| Runbook HML | `NOT_PROVEN` | WP-HML-5 bloqueado |
| Gates locais focados e impactados | `NOT_PROVEN` | WP-HML-6 bloqueado |
| Capacity proof e autorizacao ambiental HML | `NOT_PROVEN` | Fora do efeito autorizado por este Proposed |
| PRD | `NOT_PROVEN/BLOCKED` | Fora do escopo; nenhum IP criado |

O handoff deve informar arquivos alterados, owners/revisores, comandos e
resultados, ambiente local usado, skips, riscos e gates pendentes. Conclusao do
repositorio nao declara HML pronta, acessada ou ativada.

## Historico

| Versao | Data | Responsavel | Mudanca | Evidencia do gate |
| --- | --- | --- | --- | --- |
| 1.0 | 2026-09-02 | Engenharia / DevOps, sob gate humano de alocacao | Criacao e refinamento em `Proposed`: fecha paths, boundary de capacidade, identidade do orquestrador, readiness, cache `OFF`, observabilidade sem sizing inferido e validacao documental. | `docs/product/requirements/REQ-00052-tenant-pool-policy-controlled-hml-prd-rollout.md#hml-ip-infra-allocation` |
