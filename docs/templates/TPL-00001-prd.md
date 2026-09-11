---
document_id: TPL-00001
primary_nature: Template
objective: Fornecer o molde de um Product Requirements Document validavel.
scope: Problema, evidencia, publico, outcomes, limites, metricas, hipoteses, features e approval.
non_objectives: Nao inventar evidencia, target, acceptance criterion, arquitetura ou validacao.
owner: Produto e Documentacao
status: Active
version: 1.0
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: template, prd, produto, metricas, hipoteses
related_files: README.md, ../product_requirements/README.md
code_references: N/A - template documental.
principal_statement: Um PRD so recebe Validated quando problema, outcomes, metricas, hipoteses, perguntas e approval estao encerrados por evidencia real.
---

# Template — PRD

Copie o bloco abaixo para `docs/product_requirements/PRD-NNNNN-short-title.md`.

```markdown
---
document_id: PRD-NNNNN
primary_nature: Requisito
objective: {{pergunta de produto respondida}}
scope: {{iniciativa, publico e fronteiras}}
non_objectives: {{exclusoes}}
owner: {{owner humano}}
status: Draft
version: 0.1
date: YYYY-MM-DD
last_reviewed: YYYY-MM-DD
keywords: {{termos de descoberta}}
related_files: {{requirements, negocio e analises}}
code_references: N/A - PRD nao descreve implementacao; use destinos planejados apenas quando necessario.
principal_statement: {{problema e resultado principal}}
---

# PRD-NNNNN — {{titulo}}

## Problema e evidência

- Problema: {{descricao observavel}}
- Evidência: {{fonte verificavel ou lacuna}}
- Por que agora: {{gatilho real}}

## Público e contexto

| Público/persona | Necessidade | Evidência |
| --- | --- | --- |
| {{publico}} | {{necessidade}} | {{fonte}} |

## Outcomes e não-objetivos

- Outcome O-01: {{resultado mensuravel}}
- Não-objetivo: {{limite}}

## Métricas

| ID | Definição | Baseline | Target | Fonte | Owner | Frequência |
| --- | --- | --- | --- | --- | --- | --- |
| M-01 | {{metrica}} | {{valor ou desconhecido}} | {{target decidido}} | {{fonte}} | {{owner}} | {{cadencia}} |

`Not applicable` exige justificativa, owner, data e gatilho objetivo de reativação.

## Product Hypotheses

| ID | Hipótese | Estado | Evidência | Owner |
| --- | --- | --- | --- | --- |
| H-01 | {{crenca testavel}} | Proposed | {{evidencia planejada}} | {{owner}} |

## Features e mapa de requirements

| Feature | Outcome | Requirements | Acceptance criteria canônicos | Estado |
| --- | --- | --- | --- | --- |
| F-01 | O-01 | REQ-NNNNN | REQ-NNNNN/AC-01, AC-02 | Planned |

Não copie ou parafraseie acceptance criteria no PRD.

## Assumptions e Open Questions

| ID | Tipo | Texto | Estado | Resposta/evidência | Owner |
| --- | --- | --- | --- | --- | --- |
| Q-01 | Open Question | {{pergunta}} | Open | N/A | {{owner}} |

## Approval

| Papel | Nome | Decisão | Data | Evidência |
| --- | --- | --- | --- | --- |
| Product Owner | {{nome}} | Pending | N/A | N/A |

## Product Definition Gate

- [ ] Problema e público possuem evidência.
- [ ] Outcomes, limites e métricas estão decididos.
- [ ] Hypotheses estão Validated ou Rejected.
- [ ] Open Questions estão Resolved.
- [ ] Features apontam para requirements e ACs canônicos.
- [ ] Approval humano está registrado.

Resultado: BLOCKED
```

