---
document_id: TPL-00006
primary_nature: Template
objective: Fornecer o molde de uma unidade tecnica vertical e auditavel.
scope: Paths, abordagem, testes, riscos, gates, DoD e readiness.
non_objectives: Nao criar comportamento, ampliar Task Plan ou autorizar escopo nao auditado.
owner: Engenharia e Arquitetura
status: Active
version: 1.0
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: template, implementation-plan, execucao, testes
related_files: README.md, ../task_plans/implementation_plans/README.md
code_references: N/A - template documental.
principal_statement: Implementation Plan mantem codigo, teste e evidencia do mesmo resultado em uma unidade com READY proprio.
---

# Template — Implementation Plan

```markdown
---
document_id: IP-AREA-NNNNN
primary_nature: Plano
objective: Implementar {{resultado observavel unico}}.
scope: {{paths e comportamento}}
non_objectives: {{exclusoes}}
owner: {{owner tecnico}}
status: Draft
version: 0.1
date: YYYY-MM-DD
last_reviewed: YYYY-MM-DD
keywords: {{termos}}
related_files: {{TP, PRD, REQ, UC, ADRs, contratos}}
code_references: {{paths exatos planejados}}
principal_statement: A unidade entrega {{resultado}} e sua evidencia.
---

# IP-AREA-NNNNN — {{titulo}}

## What / Where

- What: {{um resultado}}
- Where: {{paths e simbolos}}
- Depends on: {{IDs/estado}}
- Reuses: {{componentes e contratos}}
- Requirements: {{IDs, versões e ACs}}

## Abordagem

1. {{passo técnico finito}}
2. {{teste/evidência do mesmo resultado}}

## Arquivos

| Path | Ação | Responsabilidade |
| --- | --- | --- |
| {{path}} | Create/Modify | {{motivo}} |

## Testes e assurance

| Gate | Teste/comando | Critério |
| --- | --- | --- |
| A1 | {{focal e suite impactada}} | {{resultado}} |
| A2 | {{lint/typecheck/build/arquitetura}} | {{resultado}} |
| A3 | {{seguranca/compliance ou N/A justificado}} | {{resultado}} |

## Gate Audit

| Controle | Evidência | Estado |
| --- | --- | --- |
| Fontes/versões | {{links}} | Pending |
| Dependências | {{evidencia}} | Pending |
| Incertezas | Nenhuma pendente | Pending |
| Granularidade | {{um resultado/handoff ou filhos}} | Pending |

## Acceptance Tests

| AC | Evidência | Resultado binário |
| --- | --- | --- |
| REQ-NNNNN/AC-01 | {{teste}} | {{esperado}} |

## Prohibited

- {{paths, efeitos, bypass e inferencias vedados}}

## Mandatory

- {{preconditions, standards, approvals, testes e reviews}}

## Definition of Done

- [ ] {{condicao binaria}}
- [ ] A1, A2 e A3 aplicáveis possuem evidência atual.

## Result

- Estado: BLOCKED
- Auditor/data: {{auditor}} / YYYY-MM-DD
- Task ID/fontes/paths: {{recorte exato}}
- Blocker/owner: {{causa real e owner}}

## Granularity / Decomposition Review

Preencha quando o plano ultrapassar 500 linhas ou 64 KiB.

- Outcome: {{Decomposed ou Semantically indivisible}}
- Rationale: {{justificativa semantica}}
- Children: {{ao menos dois IDs ou N/A}}
- Reviewed on: YYYY-MM-DD
```

