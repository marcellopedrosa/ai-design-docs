---
document_id: REQ-00005
primary_nature: Requisito
objective: Tornar o validador de qualidade agnostico de stack e parametrizado por projeto.
scope: Coverage, reports, thresholds, branch naming e escopo do validador de metricas.
non_objectives: Introduzir framework de profiles ou reduzir controles ativados pelo projeto.
owner: Mantenedores do harness
status: Approved
version: 0.1
date: 2026-09-30
last_reviewed: 2026-09-30
keywords: quality, coverage, profile, agnostico
related_files: ../../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md
code_references: ../../../harness/tooling/validators/validate-quality-metrics.mjs, ../../../harness/tooling/validators/validate-quality-metrics.test.mjs
principal_statement: O core deve validar metricas somente com politica explicita do projeto, sem JaCoCo, LCOV, thresholds ou nomes de pacote como defaults universais.
---

# REQ-00005 — Quality Policy por profile

## Origem

FIX-005 e FIX-006 do plano ; PRD não aplicável por ser portabilidade do harness. ADR-0000 Accepted.

## User Story View

Como projeto adotante, quero escolher relatórios e thresholds de cobertura por configuração, para usar o harness sem herdar a stack de outro projeto.

## Comportamento e Acceptance Criteria

- AC-01 — Sem política de coverage, o validador não procura JaCoCo/LCOV nem exige diretórios backend/frontend.
- AC-02 — Com política JaCoCo explícita, usa reports e thresholds fornecidos e bloqueia relatório ausente.
- AC-03 — Com política LCOV explícita, usa reports e thresholds fornecidos e falha abaixo do limiar.
- AC-04 — Alterar threshold no arquivo de política modifica o resultado sem editar o código.
- AC-05 — Em modo delivery, política de branches protegidas é obrigatória; branch protegida é rejeitada e convenção adicional de nome só é aplicada quando configurada.

## Contrato e aprovação

Política local JSON mínima com `coverage.format`, `coverage.reports`, `coverage.thresholds` opcionais e `delivery.protectedBranches` obrigatório apenas em modo delivery; `delivery.branchPattern` é opcional. Sem perguntas abertas; profile ausente significa coverage não ativada, não PASS de cobertura. Aprovado pelo mantenedor em 2026-09-30 com “aplicação ”, que inclui FIX-005/006.
