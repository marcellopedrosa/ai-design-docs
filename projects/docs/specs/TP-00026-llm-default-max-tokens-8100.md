---
document_id: "TP-00026"
primary_nature: "Plano"
objective: "Alinhar o default operacional de max_tokens dos provedores LLM para 8100."
scope: "Defaults de persistência tenant e formulários administrativos, seed incremental e testes afetados."
non_objectives: "Alterar limites de schema ou sobrescrever valores explicitamente configurados por tenants."
owner: "Engenharia de Plataforma"
status: "In Progress"
date: "2026-08-28"
version: "1.0"
last_reviewed: "2026-08-28"
keywords: "llm, max_tokens, gemini, defaults"
related_files: "../../backend/docs/adrs/ADR-0007-multi-provider-llm-integration.md, TP-00001-backend-spring-modulith-task-plan.md, TP-00002-frontend-nextjs-task-plan.md"
code_references: "backend/src/main/resources/db/migration/tenant, frontend/src/components/llm"
principal_statement: "O default passa de 1024 para 8100; overrides explícitos permanecem intactos e migrations existentes não são reescritas."
---

# TP-00026 — Default de max_tokens em 8100

## Escopo e decisão

O novo valor padrão é `8100`, dentro do limite de schema existente (`8192`).
Será aplicado aos novos provedores e ao registro Gemini seedado somente quando ele
ainda estiver no valor histórico `1024`; valores configurados explicitamente não serão
alterados.

## Sequência

1. Criar migration tenant incremental para atualizar o default da coluna e o seed conhecido.
2. Ajustar defaults dos modais administrativos e fixtures/testes frontend.
3. Atualizar fixture de persistência backend e executar validação documental e testes focados.

## Critérios de saída

- Nenhuma migration histórica é editada.
- Testes backend e frontend afetados passam.
- `./infra/scripts/validate-docs.sh` passa.
