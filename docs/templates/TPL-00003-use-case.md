---
document_id: TPL-00003
primary_nature: Template
objective: Fornecer o molde de um fluxo complexo ligado a acceptance criteria aprovados.
scope: Atores, preconditions, fluxos, excecoes, postconditions e mapeamento de evidencia.
non_objectives: Nao criar requisito novo nem tratar assumption como precondition.
owner: Produto e Documentacao
status: Active
version: 1.0
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: template, use-case, fluxo, atores
related_files: README.md, ../use_cases/README.md
code_references: N/A - template documental.
principal_statement: Use case detalha como criterios aprovados sao percorridos sem redefinir o comportamento.
---

# Template — Use Case

Crie em `docs/use_cases/UC-NNNNN-<short-title>.md` e atualize o `README.md` da
coleção na mesma mudança.

```markdown
---
document_id: UC-NNNNN
primary_nature: Requisito
objective: Detalhar como {{ator}} alcanca {{objetivo}}.
scope: {{inicio, fim e boundaries}}
non_objectives: {{exclusoes}}
owner: {{owner}}
status: Draft
version: 0.1
date: YYYY-MM-DD
last_reviewed: YYYY-MM-DD
keywords: {{termos}}
related_files: {{REQ, PRD, ADRs e contratos}}
code_references: {{destinos planejados ou N/A}}
principal_statement: O fluxo demonstra {{ACs do requirement}}.
---

# UC-NNNNN — {{titulo}}

## User Goal

Como {{ator}}, quero {{capacidade}}, para {{valor}}.

## Atores e trigger

- Ator primário: {{ator}}
- Atores secundários: {{atores ou N/A}}
- Trigger: {{evento observável}}

## Preconditions

1. {{estado verificável, não uma suposição}}

## Fluxo principal

1. O ator {{acao}}.
2. O sistema {{resposta}}.

## Fluxos alternativos

- AF-01, a partir do passo {{N}}: {{fluxo}}.

## Exceções

- EF-01, a partir do passo {{N}}: {{erro e resultado}}.

## Postconditions

- Sucesso: {{estado}}
- Falha: {{estado seguro}}

## Matriz AC → fluxo → evidência

| AC | Fluxo/passos | Teste ou evidência |
| --- | --- | --- |
| REQ-NNNNN/AC-01 | Principal 1-2 | {{teste planejado}} |

Comportamento descoberto sem AC retorna ao requirement para aprovação.

## Assumptions e Open Questions

| ID | Tipo | Texto | Estado | Evidência/resposta | Owner |
| --- | --- | --- | --- | --- | --- |
| Q-01 | Open Question | {{pergunta}} | Open | N/A | {{owner}} |

## Approval e readiness

- Approver: {{owner humano}}
- Decisão: Pending
- Resultado: BLOCKED enquanto qualquer fonte ou incerteza estiver pendente.
```

