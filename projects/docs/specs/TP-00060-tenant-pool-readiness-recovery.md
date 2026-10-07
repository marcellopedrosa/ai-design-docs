---
document_id: TP-00060
primary_nature: Plano
objective: Implementar readiness fail-closed durante a recuperação da membership fence após restart ou parada prolongada.
scope: REQ-00051; backend lifecycle, testes unitários e integração local.
status: Completed
version: 1.0
date: 2026-09-16
related_files: do../../product/requirements/REQ-00051-tenant-pool-policy-managed-runtime-environments.md, ../../backend/docs/adrs/ADR-0052-parametros-pool-conexao-por-tenant.md, ../../backend/docs/specs/IP-BE-23.5.2-tenant-pool-readiness-recovery.md
owner: Arquitetura e Backend
keywords: readiness, fence, restart, lease
code_references: backend/src/main/java/br/com/duoset/saas_service/config/persistence/routing/lifecycle/
non_objectives: deploy, sizing, infraestrutura externa, dados reais
principal_statement: Readiness tenant permanece fechada até fence e pools committed válidos.
---

# TP-00060 — Recuperação de readiness do pool tenant

## Resultado

Após startup ou expiração da lease, o processo permanece não pronto para tráfego tenant até obter evidence/membership válidas e pools committed.

## Fases

1. Congelar contrato e paths; 2. implementar gate de readiness; 3. adicionar testes de restart/lease; 4. executar quality gate; 5. atualizar evidências.

## Definition of Done

- REQ-00051, seção de readiness, coberto por testes reproduzíveis.
- Nenhuma aquisição JDBC ocorre fora da fence válida.
- `validate-docs.sh` e Quality Gate aplicáveis passam.

## Implementation Readiness

Result: READY → Completed. Auditor: Codex. Data: 2026-09-18. Evidence: lifecycle tests = 23/23 pass; `./infra/scripts/validate-docs.sh` = PASS; DEV runtime smoke `GET /actuator/health/readiness` returned HTTP 200 with `readinessState=UP`, `tenantPoolRuntime.phase=READY`, status `UP`. A implementação já existente cobre o escopo; nenhuma alteração executável adicional foi necessária.
