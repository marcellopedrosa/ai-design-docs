---
document_id: TPL-00002
primary_nature: Template
objective: Fornecer o molde de requirement observavel, aprovavel e testavel.
scope: User Story View, comportamento, regras, criterios de aceite, incertezas e approval.
non_objectives: Nao decidir arquitetura, criar plano ou inventar comportamento.
owner: Produto e Documentacao
status: Active
version: 1.0
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: template, requirement, acceptance-criteria, user-story
related_files: README.md, ../requirements/README.md
code_references: N/A - template documental.
principal_statement: Requirement e a fonte canonica de comportamento e so avanca quando criterios e incertezas estao encerrados e aprovados.
---

# Template — Requirement

```markdown
---
document_id: REQ-NNNNN
primary_nature: Requisito
objective: {{comportamento entregue}}
scope: {{atores, sistema e fronteiras}}
non_objectives: {{exclusoes}}
owner: {{owner}}
status: Draft
version: 0.1
date: YYYY-MM-DD
last_reviewed: YYYY-MM-DD
keywords: {{termos}}
related_files: {{PRD, negocio, ADRs, contratos e UCs}}
code_references: {{destinos planejados ou N/A justificado}}
principal_statement: O sistema deve {{comportamento observavel}}.
---

# REQ-NNNNN — {{titulo}}

## Origem e rastreabilidade

- PRD/outcome: {{PRD-NNNNN/O-NN ou not applicable justificado}}
- Regra/decisão superior: {{IDs}}

## User Story View

Como {{ator/persona}}, quero {{capacidade observável}}, para {{valor}}.

Use `N/A` justificado apenas para requirement técnico sem valor autônomo.

## Comportamento e regras

1. O sistema deve {{regra observavel}}.
2. O sistema não deve {{restricao}}.

## Acceptance Criteria

- AC-01 — Given {{estado}}, when {{acao}}, then {{resultado verificavel}}.
- AC-02 — Given {{erro/limite}}, when {{acao}}, then {{resultado verificavel}}.

## Requisitos não funcionais

| ID | Qualidade | Critério verificável | Evidência planejada |
| --- | --- | --- | --- |
| NFR-01 | {{atributo}} | {{limiar ou regra}} | {{teste/relatorio}} |

## Impacto de contrato

- Estado: {{N/A, criar, alterar ou consumir}}
- Contrato/versão/operações: {{referencias exatas}}

## Assumptions

| ID | Assumption | Estado | Evidência | Owner |
| --- | --- | --- | --- | --- |
| A-01 | {{texto}} | Proposed | N/A | {{owner}} |

## Open Questions

| ID | Pergunta | Estado | Resposta/evidência | Owner | Data |
| --- | --- | --- | --- | --- | --- |
| Q-01 | {{pergunta}} | Open | N/A | {{owner}} | N/A |

## Approval

| Approver | Decisão | Data | Evidência |
| --- | --- | --- | --- |
| {{owner humano}} | Pending | N/A | N/A |

## Readiness documental

Resultado: BLOCKED enquanto status, assumptions, questions, contrato ou approval
estiverem pendentes.
```

