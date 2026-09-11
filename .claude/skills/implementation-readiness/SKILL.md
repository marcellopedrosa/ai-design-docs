---
name: implementation-readiness
description: Audita prontidao, decompoe semanticamente tarefas nao atomicas e bloqueia implementacao quando fontes, incertezas, dependencias ou Definition of Done nao estao resolvidas. Use antes de handoff ou edicao executavel; nao use para auditar codigo pronto.
---

# Implementation Readiness Gate

- Owner: Arquitetura, Produto e Qualidade
- Status: Active

## Objetivo

Produzir `READY` ou `BLOCKED` antes de Execution conforme o
`implementation-readiness-standard.md`.

## Procedimento

1. Identifique task ID, `What`, `Where` e versões das fontes.
2. Verifique PRD `Validated` ou `not applicable` justificado, requirement/ADR/UC
   aplicáveis, contratos e dependências.
3. Exija hipóteses e assumptions `Validated`/`Rejected` e Open Questions
   `Resolved`, sempre com owner e evidência.
4. Audite granularidade. Quando faltar atomicidade, decomponha semanticamente,
   atualize IDs, dependências, índices e relação pai → filhos e reaudite cada unidade.
5. Em decisão, fonte, dependência ou autorização pendente, registre `BLOCKED`; não
   implemente nem escolha default.
6. Materialize a resposta na fonte canônica, obtenha aprovação e reaudite.
7. Publique Gate Audit, Acceptance Tests, Prohibited, Mandatory, DoD e Result.

## Regra dura

PRD aplicável não `Validated`, estado `Proposed` relevante, pergunta `Open`, `TBD`,
placeholder, conflito, dependência ausente ou DoD subjetiva sempre é `BLOCKED`.
Não existe waiver nem `READY WITH ASSUMPTIONS`. Granularidade inadequada aciona
decomposição antes do resultado; somente causa real remanescente mantém `BLOCKED`.

## Limites e conclusão

Não executar Git, instalar, acessar rede/produção/dados reais/segredos nem responder
decisão humana por inferência. Termine com `READY` verificável ou `BLOCKED`
acionável; em `BLOCKED`, encerre qualquer implementação até nova auditoria.

