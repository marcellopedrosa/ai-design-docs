---
document_id: TPL-00005
primary_nature: Template
objective: Fornecer o molde de um Task Plan com decomposicao semantica e readiness.
scope: Fontes, tasks, dependencias, gates, handoffs e tracking.
non_objectives: Nao redefinir requirement, ADR ou approval.
owner: Engenharia e Arquitetura
status: Active
version: 1.0
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: template, task-plan, decomposicao, readiness
related_files: README.md, ../task_plans/README.md
code_references: N/A - template documental.
principal_statement: Task Plan coordena unidades semanticas; cada unidade tem resultado, handoff e gate proprios.
---

# Template — Task Plan

Crie em `docs/task_plans/TP-NNNNN-short-title.md` e atualize o `README.md` da
coleção na mesma mudança.

```markdown
---
document_id: TP-NNNNN
primary_nature: Plano
objective: Coordenar {{resultado da iniciativa}}.
scope: {{requirements, modulos e boundaries}}
non_objectives: {{exclusoes}}
owner: {{owner}}
status: Draft
version: 0.1
date: YYYY-MM-DD
last_reviewed: YYYY-MM-DD
keywords: {{termos}}
related_files: {{PRD, REQ, UC, ADRs, contratos e IPs}}
code_references: {{paths planejados}}
principal_statement: O plano coordena {{resultado}} sem redefinir fontes superiores.
---

# TP-NNNNN — {{titulo}}

## Fontes e versões

| Fonte | Versão/status | Escopo consumido |
| --- | --- | --- |
| PRD-NNNNN | {{versao/Validated}} | {{outcomes/features}} |
| REQ-NNNNN | {{versao/Approved}} | {{ACs}} |

## Granularidade / Decomposição

- Resultado coordenado: {{resultado}}
- Critério de divisão: resultados, owners, dependências, riscos, autorizações e handoffs independentes.
- Relação pai → filhos: {{TASK IDs ou N/A enquanto auditado}}

## Dependências e ordem

| Task | Depends on | Handoff para | Estado |
| --- | --- | --- | --- |
| TASK-NNNNN.1 | N/A | {{owner seguinte}} | Draft |

## TASK-NNNNN.1 — {{resultado observável}}

- What: {{um resultado}}
- Where: {{paths/boundaries exatos}}
- Depends on: {{IDs ou N/A}}
- Reuses: {{componentes/contratos}}
- Requirements: {{IDs, versões e ACs}}

### Gate Audit

| Controle | Evidência | Estado |
| --- | --- | --- |
| Product Definition | {{PRD ou N/A justificado}} | Pending |
| Fontes superiores | {{REQ/ADR/UC/contrato}} | Pending |
| Assumptions/Open Questions | {{nenhuma pendente}} | Pending |
| Granularidade | {{justificativa atomica ou filhos}} | Pending |

### Acceptance Tests

| AC | Teste/comando/evidência | Resultado esperado |
| --- | --- | --- |
| REQ-NNNNN/AC-01 | {{evidencia}} | {{binario}} |

### Prohibited

- {{fora de escopo, inferencia e efeitos vedados}}

### Mandatory

- {{preconditions, standards, approvals e gates}}

### Definition of Done

- [ ] {{condicao binaria e evidencia}}

### Result

- Estado: BLOCKED
- Auditor/data: {{auditor}} / YYYY-MM-DD
- Task ID, versões e paths: {{recorte exato}}
- Blocker/owner: {{causa real e owner}}

## Tracking e handoff

Atualize estado somente após o Gate Audit. Registre comandos, resultados, skips,
falhas, decisões, pendências e próximo owner.
```

