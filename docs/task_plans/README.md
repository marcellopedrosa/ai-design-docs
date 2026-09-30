---
document_id: TASK-PLANS-INDEX
primary_nature: Contexto
objective: Catalogar planos que coordenam mudancas sem redefinir fontes superiores.
scope: Task Plans e Implementation Plans.
non_objectives: Nao criar requisito, decisao ou approval por meio de plano.
owner: Engenharia e Arquitetura
status: Active
version: 1.1
date: 2026-09-10
last_reviewed: 2026-09-30
keywords: planos, tasks, readiness, handoff
related_files: implementation_plans/README.md, ../templates/TPL-00005-task-plan.md, TP-00001-harness-remediation.md
code_references: ../../tooling/harness-doctor/index.mjs, ../../tooling/contracts/validator.mjs
principal_statement: Cada task entrega um resultado observavel, um handoff e um contrato finito auditado antes da execucao.
---

# Task Plans

## Contrato da coleção

- Conteúdo aceito: decomposição semântica, dependências, ordem, gates e handoffs.
- Nomes: `TP-NNNNN-short-title.md`.
- Estados: `Draft`, `Ready`, `In Progress`, `Blocked`, `Completed`, `Deprecated`.
- Critério de granularidade: uma iniciativa coordenadora; cada task filha possui um
  resultado e handoff próprios.

## Índice

| Plano | Objetivo | Status |
| --- | --- | --- |
| [TP-00001](TP-00001-harness-remediation.md) | Coordenar a remediação cirúrgica de engenharia do harness v2 (T-04 a T-12) | In Progress |

Veja também [Implementation Plans](implementation_plans/README.md).

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.1 | 2026-09-30 | Cataloga TP-00001 para a remediação cirúrgica de engenharia v2. |
| 1.0 | 2026-09-10 | Baseline inicial da coleção de Task Plans. |

