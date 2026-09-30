---
document_id: REQ-00006
primary_nature: Requisito
objective: Ativar a cobertura de contratos Spring MVC apenas para profile compatível.
scope: CLI do validador de API e classificação no Registry.
non_objectives: Suportar frameworks HTTP adicionais ou reescrever a extração Spring MVC.
owner: Mantenedores do harness
status: Approved
version: 0.1
date: 2026-09-30
last_reviewed: 2026-09-30
keywords: spring-mvc, api, profile, condicional
related_files: ../../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md
code_references: ../../../harness/tooling/validators/validate-api-contract-coverage.mjs, ../../../harness/registry/tooling.yaml
principal_statement: O validador Spring MVC deve executar somente quando o profile java-spring for ativado explicitamente.
---

# REQ-00006 — Spring MVC condicional

## Origem e User Story View

FIX-007 do plano ; PRD não aplicável, por ser portabilidade do harness. Como projeto adotante não-Spring, quero que o validador especializado seja pulado explicitamente, sem falso PASS nem erro de framework ausente.

## Acceptance Criteria

- AC-01 — Sem profile `java-spring`, a CLI não executa extração Spring e informa `SKIP`.
- AC-02 — Com profile `java-spring`, a CLI executa a validação existente e preserva seu exit code.
- AC-03 — Registry classifica o validador como capability `java-spring` dependente de configuração do projeto.
- AC-04 — Testes cobrem profile desativado e ativado sem alterar o parser Spring.

## Contrato e aprovação

Ativação por `--profile java-spring` explícito; sem pergunta ou assumption aberta. Aprovado pelo mantenedor em 2026-09-30 ao pedir “aplicação ”, incluindo FIX-007.
