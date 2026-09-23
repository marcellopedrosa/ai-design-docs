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

## Gatilhos e não-gatilhos

- Gatilhos: antes de handoff ou edição executável, migration ou IaC.
- Não-gatilhos: auditoria de código pronto ou alteração exclusivamente documental.

## Escopo e não-objetivos

- Escopo: task ID, fontes, versões, paths, incertezas, dependências, granularidade
  e Definition of Done.
- Não-objetivos: decidir produto/arquitetura pelo humano ou aprovar código pronto.

## Entradas

Task Plan, PRD aplicável ou justificativa `PRD not applicable`, requirements, ADRs,
contratos, approvals, dependências e paths propostos.

## Pré-condições

1. Leia o `implementation-readiness-standard.md` e confirme a versão das fontes.
2. Confirme que o owner e a autorização de cada decisão material estão identificados.

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

O ADR-0000, Section 10.13, e o `implementation-readiness-standard.md` são fontes
normativas. Product Hypothesis, AC aplicável e teste/evidência devem estar
rastreáveis. Granularidade / Decomposição inadequada exige perguntar ao humano
quando a decisão não estiver nas fontes; decomponha semanticamente, relacione pai →
filhos e reexecute o gate para cada unidade. Não existe waiver para incerteza material.

## Registro da auditoria

Publique as seções nesta ordem:

1. Gate Audit
2. Acceptance Tests
3. Prohibited
4. Mandatory
5. Definition of Done

## Regra dura

PRD aplicável não `Validated`, estado `Proposed` relevante, pergunta `Open`, `TBD`,
placeholder, conflito, dependência ausente ou DoD subjetiva sempre é `BLOCKED`.
Não existe waiver nem `READY WITH ASSUMPTIONS`. Granularidade inadequada aciona
decomposição antes do resultado; somente causa real remanescente mantém `BLOCKED`.

## Limites e conclusão

Não executar Git, instalar, acessar rede/produção/dados reais/segredos nem responder
decisão humana por inferência. Termine com `READY` verificável ou `BLOCKED`
acionável; em `BLOCKED`, encerre qualquer implementação até nova auditoria.

## Limites de segurança

Não execute Git, não instale dependências, não acesse rede, produção, dados reais,
segredos ou credenciais e não escolha defaults para resolver incerteza.

## Saídas e evidências

A saída é `READY` ou `BLOCKED` com task ID, fontes, versão, paths, evidências,
owner e condição de retomada.

## Critério de conclusão

Conclua com auditoria reproduzível: `READY` autoriza somente o recorte registrado;
`BLOCKED` interrompe a implementação até que a causa seja resolvida e o gate repetido.

