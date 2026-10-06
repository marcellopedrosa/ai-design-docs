---
document_id: ONBOARD-TENANT-POOL-POLICY-HML-PRD
primary_nature: Regra
objective: Orientar um agente de infraestrutura na configuração segura e auditável da política de pool por tenant em HML e PRD.
scope: HML e PRD; inspeção sanitizada, capacity proof, autoridade, flags, readiness, canary, rollback e drain.
non_objectives: Não executar comandos neste documento automaticamente, não acessar segredos, não copiar valores reais para o repositório, não inferir sizing e não contornar o pipeline de deploy.
owner: Infraestrutura, SRE/DBA, Backend e Segurança
status: Draft
version: 1.0
date: 2026-10-01
last_reviewed: 2026-10-01
keywords: onboarding, tenant-pool, hml, prd, mutations-disabled, capacity, rollback
related_files: docs/delivery/plans/TP-00068-tenant-pool-production-mutation-disabled.md, docs/onboarding/tenant-pool-policy-managed-dev-runbook.md, docs/onboarding/production-vps-deployment.md, docs/product/requirements/REQ-00051-tenant-pool-policy-managed-runtime-environments.md, docs/product/requirements/REQ-00052-tenant-pool-policy-controlled-hml-prd-rollout.md, docs/adrs/ADR-0052-parametros-pool-conexao-por-tenant.md
code_references: backend/src/main/resources/application-hml.yml, backend/src/main/resources/application-prd.yml, infra/scripts/deploy-production.sh, docker-compose.hml.yml, docker-compose.prd.yml
principal_statement: HML e PRD só deixam DARK/OFF após prova de capacidade, autoridade, readiness e aprovação operacional explícita.
---

# Onboarding — Configuração de pool por tenant em HML e PRD

## 1. Regra de segurança

O erro `TENANT_POOL_MUTATION_DISABLED` é esperado quando `mode=DARK` ou
`mutations-enabled=false`. Não altere uma única flag isoladamente. HML e PRD
devem permanecer fail-closed até o envelope de capacidade e a autoridade do
runtime estarem persistidos e comprovados.

Não registre, copie ou imprima valores de `DB_PASSWORD`, tokens, chaves,
`runtime-instance-id` ou qualquer variável owner-only. Use somente o mecanismo
de secrets/env-file já aprovado pelo ambiente.

## 2. Variáveis que precisam de custódia operacional

Os nomes abaixo são referências de configuração, não valores a serem inventados:

| Grupo | Variáveis |
| --- | --- |
| Ativação | `TENANT_POOL_MANAGED_MODE`, `TENANT_POOL_MANAGED_API_READ_ENABLED`, `TENANT_POOL_MANAGED_MUTATIONS_ENABLED` |
| Capacidade | `TENANT_POOL_MANAGED_ENVIRONMENT_MAXIMUM_POOL_SIZE`, `TENANT_POOL_MANAGED_SAFE_CONNECTION_BUDGET`, `TENANT_POOL_MANAGED_REPLICAS_MAX`, `TENANT_POOL_MANAGED_PLATFORM_POOL_MAX`, `TENANT_POOL_MANAGED_MIGRATION_ADMIN_RESERVE`, `TENANT_POOL_MANAGED_EMERGENCY_HEADROOM` |
| Aplicação fenced | `TENANT_POOL_MANAGED_AUTHORITATIVE_READ_ENABLED`, `TENANT_POOL_MANAGED_CANDIDATE_APPLY_ENABLED`, `TENANT_POOL_MANAGED_REVISION_APPLY_ENABLED`, `TENANT_POOL_MANAGED_FAIL_CLOSED_CUTOVER_ENABLED`, `TENANT_POOL_MANAGED_CAPACITY_PREFLIGHT_ENABLED`, `TENANT_POOL_MANAGED_CAPACITY_RESERVATION_ENABLED`, `TENANT_POOL_MANAGED_MEMBERSHIP_FENCING_ENABLED` |
| Runtime | `TENANT_POOL_MANAGED_RUNTIME_EVIDENCE_ENABLED`, `TENANT_POOL_MANAGED_CLUSTER_ID`, `TENANT_POOL_MANAGED_REPLICAS_MAX`, `TENANT_POOL_MANAGED_DEPLOYMENT_EPOCH`, `TENANT_POOL_MANAGED_RUNTIME_INSTANCE_ID`, `TENANT_POOL_MANAGED_LEASE_DURATION`, `TENANT_POOL_MANAGED_HEARTBEAT_INTERVAL`, `TENANT_POOL_MANAGED_RENEWAL_SAFETY_MARGIN` |

Sizing deve vir de SRE/DBA e do limite real do PostgreSQL; nunca use os valores
DEV como fallback.

## 2.1 Matriz explícita: contrato DEV versus ativação HML/PRD

DEV serve somente como referência do contrato completo. Em DEV, o profile usa
`MANAGED_ENVIRONMENT`, todas as flags de prepare/apply/fencing ficam habilitadas,
há bootstrap local de evidence e existe envelope sintético `80/10/5/15/1`.
Esses números não podem ser promovidos para HML ou PRD.

| Controle | DEV observado | HML | PRD |
| --- | --- | --- | --- |
| `activation.mode` | `MANAGED_ENVIRONMENT` | `DARK` até capacity/authority/canary aprovados; depois `MANAGED_ENVIRONMENT` | `DARK` até HML concluído e go/no-go específico; depois `MANAGED_ENVIRONMENT` |
| `api-read-enabled` | `true` | `false` até leitura sanitizada aprovada; depois conforme change ticket | `false` até leitura sanitizada aprovada; depois conforme change ticket |
| `mutations-enabled` | `true` | `false` até canary e readiness `READY`; só então `true` | `false` até HML, capacity e go/no-go PRD; só então `true` |
| `authoritative-read-enabled` | `true` | obrigatório antes de qualquer mutation | obrigatório antes de qualquer mutation |
| `candidate-apply-enabled` / `revision-apply-enabled` | `true` / `true` | ambos `false` até authority, reservation e fencing válidas; depois `true` juntos | ambos `false` até authority, reservation e fencing válidas; depois `true` juntos |
| `fail-closed-cutover-enabled` | `true` | obrigatório antes de mutation | obrigatório antes de mutation |
| `capacity-preflight-enabled` / `capacity-reservation-enabled` | `true` / `true` | ambos obrigatórios; valores dimensionados por SRE/DBA | ambos obrigatórios; valores dimensionados por SRE/DBA |
| `membership-fencing-enabled` | `true` | obrigatório | obrigatório |
| `reconcile-scheduler-enabled` / observabilidade | `true` / `true` | obrigatórios antes do canary | obrigatórios antes do canary |
| runtime evidence/bootstrap | evidence `true`, bootstrap local `true` | evidence `true`; bootstrap local não pode ser usado como autoridade | evidence `true`; bootstrap local não pode ser usado como autoridade |
| lease/heartbeat/margem | `PT2M` / `PT30S` / `PT30S` | valores aprovados pelo owner do runtime, sempre com margem positiva | valores aprovados pelo owner do runtime, sempre com margem positiva |
| capacity envelope | sintético `80/10/5/15/1` | obrigatório, sem fallback DEV | obrigatório, sem fallback DEV |

As células HML/PRD que dizem “depois” representam estado permitido somente após
aprovação e evidência; não são valores para copiar diretamente para um env-file.
`mutations-enabled=true` sem `READY`, fencing, reservation, authority e canary
é configuração inválida e deve ser recusada pelo gate operacional.

## 3. Pré-validação sem efeito

1. Confirmar que o artefato e o profile são os esperados para HML ou PRD.
2. Validar a composição do ambiente e o schema de configuração sem imprimir o
   env-file nem os secrets.
3. Confirmar que a autoridade de capacidade, membership e committed pools estão
   disponíveis para o runtime selecionado.
4. Confirmar readiness sanitizada e observabilidade antes de qualquer mutation.

Falha em qualquer item mantém `mode=DARK` e `mutations-enabled=false`.

## 4. Sequência de ativação autorizada

1. Registrar change ticket, owner, janela, ambiente e rollback.
2. Aplicar somente o envelope dimensionado e a identidade runtime aprovados.
3. Iniciar em modo de leitura/prepare quando previsto pelo plano; não liberar
   mutation antes de `READY`.
4. Confirmar `/actuator/health/readiness` com `readinessState=UP` e
   `tenantPoolRuntime.phase=READY`.
5. Executar canary com um tenant autorizado e registrar revisão, pool, datasource,
   swap, drain e ausência de alteração em um tenant B.
6. Executar rollback controlado se qualquer métrica, isolamento ou drain falhar.
7. Expandir somente após go/no-go humano explícito.

## 5. Diagnóstico do 503

| Sintoma | Ação segura |
| --- | --- |
| `TENANT_POOL_MUTATION_DISABLED` | Verificar `mode`, `mutations-enabled`, readiness e autoridade; não habilitar isoladamente. |
| `REPLICA_LIMIT`, `CAPACITY_UNAVAILABLE` ou readiness `DOWN` | Preservar DARK/OFF; solicitar revisão SRE/DBA do envelope. |
| Fence ausente/expirada | Não desabilitar fencing; restaurar heartbeat/authority e aguardar READY. |
| Mutation aceita mas não converge | Preservar LKG, interromper expansão e executar rollback da revisão. |

## 6. Rollback e encerramento

Rollback deve ser forward-only pelo mecanismo de deploy aprovado: desativar a
capability, preservar o último estado committed seguro, aguardar drain das
gerações antigas e verificar readiness. Não remover tabelas, pools, revisões ou
evidências para “limpar” o incidente.

## 7. Gate de execução

Este onboarding é `Draft` e não autoriza acesso HML/PRD, deploy ou alteração de
flags. Um agente de infraestrutura só pode executar após o TP-00068 estar
`Approved`, o plano de ambiente correspondente estar `READY` e existir aprovação
operacional explícita para a janela.
