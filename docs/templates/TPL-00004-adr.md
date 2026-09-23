---
document_id: TPL-00004
primary_nature: Template
objective: Fornecer o molde de uma decisao arquitetural rastreavel.
scope: Contexto, drivers, opcoes, decisao, consequencias, validacao e lifecycle.
non_objectives: Nao escolher alternativa ou approval sem evidencia e owner.
owner: Arquitetura e Documentacao
status: Active
version: 1.0
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: template, adr, arquitetura, decisao
related_files: README.md, ../adrs/README.md
code_references: N/A - template documental.
principal_statement: ADR registra uma escolha material e somente se torna normativo em Accepted.
---

# Template — ADR

Crie em `docs/adrs/ADR-NNNN-short-title.md` e atualize `docs/adrs/README.md` na
mesma mudança.

```markdown
---
document_id: ADR-NNNN
primary_nature: Decisao
objective: Decidir {{pergunta unica}}.
scope: {{boundaries e cenarios}}
non_objectives: {{decisoes excluidas}}
owner: {{owner}}
status: Proposed
version: 0.1
date: YYYY-MM-DD
last_reviewed: YYYY-MM-DD
keywords: {{termos}}
related_files: {{PRD, REQ, analises, contratos e ADRs}}
code_references: {{paths/simbolos ou destinos planejados}}
principal_statement: {{decisao proposta em uma frase}}
---

# ADR-NNNN — {{titulo}}

## Contexto

{{problema, restricoes e evidencia}}

## Decision drivers

- {{driver verificavel}}

## Opções consideradas

### Opção 1 — {{nome}}

- Benefícios: {{lista}}
- Custos/riscos: {{lista}}

### Opção 2 — {{nome}}

- Benefícios: {{lista}}
- Custos/riscos: {{lista}}

## Decisão

{{opcao escolhida, limites e motivos}}

## Consequências

- Positivas: {{efeitos}}
- Negativas: {{trade-offs}}
- Neutras: {{mudancas operacionais}}

## Impactos

- Contratos/interfaces: {{versoes e operacoes ou N/A justificado}}
- Segurança/compliance: {{impacto ou N/A}}
- Migração/compatibilidade: {{estrategia ou N/A}}
- Operação/rollback: {{controles}}

## Validação

| Controle | Evidência esperada | Owner |
| --- | --- | --- |
| {{controle}} | {{artefato/comando}} | {{owner}} |

## Lifecycle

- Approvers: {{owners humanos}}
- Supersedes: N/A
- Superseded by: N/A
- Decisão/data: Pending
```

