---
document_id: TP-00068
primary_nature: Plano
objective: Corrigir o erro TENANT_POOL_MUTATION_DISABLED e preparar a configuração controlada da política de pool por tenant em HML e PRD.
scope: Diagnóstico repository-local, documentação de configuração, validação de flags, capacidade, autoridade, readiness, rollout e rollback para HML/PRD; nenhuma execução ambiental nesta etapa.
non_objectives: Não acessar produção, não ler ou registrar segredos, não inferir sizing, não executar deploy, não ativar flags em HML/PRD e não alterar dados reais.
owner: Backend, Infraestrutura, SRE/DBA, Segurança e Qualidade
status: In Progress
version: 1.0
date: 2026-10-01
last_reviewed: 2026-10-01
keywords: tenant-pool, mutations-disabled, hml, prd, readiness, capacity, rollback
related_files: ../../backend/docs/onboarding/tenant-pool-policy-hml-prd-configuration.md, ../../backend/docs/onboarding/tenant-pool-policy-managed-dev-runbook.md, docs/product/requirements/REQ-00051-tenant-pool-policy-managed-runtime-environments.md, docs/product/requirements/REQ-00052-tenant-pool-policy-controlled-hml-prd-rollout.md, ../../backend/docs/adrs/ADR-0052-parametros-pool-conexao-por-tenant.md
code_references: backend/src/main/resources/application-hml.yml, backend/src/main/resources/application-prd.yml, backend/src/main/java/br/com/duoset/saas_service/config/persistence/routing/lifecycle/, infra/scripts/deploy-production.sh
principal_statement: A mutação só pode ser habilitada após capacidade e autoridade persistidas estarem comprovadas; defaults DARK/OFF permanecem fail-closed.
---

# TP-00068 — Correção de `TENANT_POOL_MUTATION_DISABLED` em HML/PRD

## Diagnóstico inicial

O erro HTTP 503 `TENANT_POOL_MUTATION_DISABLED` é compatível com a configuração
atual de `application-hml.yml` e `application-prd.yml`: `mode=DARK` e
`mutations-enabled=false` por default, acompanhados de flags de autoridade,
capacity reservation, fencing e runtime evidence desligadas. O erro não prova
que seja seguro ativar a capability; apenas identifica o guard fail-closed que
recusou a operação.

## Fases

1. Confirmar ambiente, versão do artefato e profile efetivo sem expor segredos.
2. Provar capacity envelope e autoridade persistida por ambiente.
3. Validar readiness, membership fence, pools committed e observabilidade.
4. Executar canary de um tenant sintético/autorizado, com alteração, isolamento,
   rollback e drain.
5. Obter go/no-go humano separado para cada ambiente.
6. Somente após aprovação, aplicar a configuração pelo mecanismo de deploy
   governado e validar rollback.

## Critérios de aceite

- `TENANT_POOL_MUTATION_DISABLED` deixa de ocorrer apenas após todas as flags e
  pré-condições obrigatórias estarem válidas.
- Nenhum tenant usa parâmetros de outro tenant.
- Readiness permanece fechada diante de qualquer autoridade, capacity ou fence
  ausente/expirada.
- Rollback restaura a revisão anterior e drena gerações antigas sem restart
  forçado.
- Evidência inclui versão, profile, flags sanitizadas, estado de readiness,
  revisão, canary, rollback e drain; nunca inclui segredo ou dado real.

## Gate atual

`BLOCKED / Proposed`: este documento autoriza planejamento documental somente.
Deploy, acesso HML/PRD e alteração de flags exigem autorização operacional
separada, sizing SRE/DBA e readiness `READY` para os paths executáveis.
