---
document_id: IMPLEMENTATION-READINESS-STANDARD
primary_nature: Regra
objective: Definir o gate que transforma fontes aprovadas e plano finito em autorizacao documental para implementacao.
scope: Incertezas, dependencias, contrato de task, decomposicao semantica e evidencia READY/BLOCKED.
non_objectives: Nao aprovar decisoes pelo humano, substituir requisitos ou auditar codigo pronto.
owner: Arquitetura, Produto e Qualidade
status: Active
version: 1.0
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: readiness, definition-of-ready, assumptions, decomposicao, blocked
related_files: software-engineering-lifecycle.md, ../../templates/TPL-00005-task-plan.md, ../../templates/TPL-00006-implementation-plan.md
code_references: ../../../.agents/skills/implementation-readiness/SKILL.md, ../../../.claude/skills/implementation-readiness/SKILL.md
principal_statement: Somente uma task atomica, decidida, aprovada e verificavel recebe READY; toda incerteza material remanescente produz BLOCKED.
---

# Implementation Readiness Standard

## Resultados permitidos

| Resultado | Significado | Efeito |
| --- | --- | --- |
| `READY` | Fontes, decisões, dependências, escopo e DoD estão comprovados. | O executor pode atuar somente no recorte auditado. |
| `BLOCKED` | Existe causa material pendente. | Proibir implementação e acionar o owner da causa. |

Não existe `READY WITH ASSUMPTIONS`, waiver, aceite tácito ou encerramento por prazo.

## Fontes e estados

- **PRD:** explica por que, para quem e com quais outcomes; quando aplicável, deve
  estar `Validated`.
- **Requirement:** define comportamento e acceptance criteria; deve estar
  `Approved`.
- **Use case:** detalha interação complexa; não cria comportamento novo.
- **ADR:** decide alternativa material; somente `Accepted` é normativo.
- **Contrato:** define interface versionada; deve estar no estado exigido pelo
  projeto antes da implementação.
- **Fact:** afirmação comprovada por fonte canônica.
- **Precondition:** estado verificável necessário durante a execução.
- **Assumption/Hypothesis:** somente `Validated` ou `Rejected` encerra a incerteza.
- **Open Question:** somente `Resolved`, com resposta, owner, data e evidência,
  encerra a pergunta.

Conversa transitória, comentário de código ou decisão apenas no plano não substitui
atualização e aprovação da fonte canônica.

## Gate Audit

Audite nesta ordem:

| Controle | Evidência |
| --- | --- |
| Product Definition | PRD `Validated` com versão ou `not applicable` justificado |
| Fontes superiores | Requirement `Approved`, ADRs `Accepted`, use case/contrato aplicáveis |
| User Story View | Ator, capacidade e valor ligados a acceptance criteria, ou N/A justificado |
| Incertezas | Nenhum estado pendente, `TBD` ou placeholder |
| Dependências | Upstreams concluídos ou disponíveis |
| Escopo | `What` e `Where` inequívocos; non-objectives explícitos |
| Granularidade | Uma entrega observável e um handoff por unidade |
| Tarefa | Reuses, Requirements, tests, Prohibited, Mandatory e DoD verificáveis |

## Contrato obrigatório da task

1. `What`: resultado observável único.
2. `Where`: paths e boundaries exatos.
3. `Depends on`: pré-requisitos ordenados.
4. `Reuses`: componentes e contratos existentes.
5. `Requirements`: IDs e versões das fontes.
6. `Gate Audit`: controles e evidências.
7. `Acceptance Tests`: AC → teste/comando/evidência.
8. `Prohibited`: efeitos e escopo vedados.
9. `Mandatory`: preconditions, approvals, standards e gates.
10. `Definition of Done`: condições finitas, binárias e observáveis.
11. `Result`: estado, auditor, data, versões e paths.

Expressões abertas como “melhorar”, “quando possível” ou “até ficar bom” não são DoD.

## Decomposição semântica

Antes do resultado, decomponha toda task com resultados, owners, dependências,
riscos, autorizações, áreas, handoffs ou ciclos independentemente aceitáveis,
executáveis, reversíveis ou replanejáveis.

Cada filho preserva requisito e aceite, mantém implementação/teste/evidência do
mesmo resultado, recebe ID/What/Where/DoD próprios, atualiza relação pai → filhos e
passa por nova auditoria. Tamanho isolado apenas aciona revisão; não determine a
divisão por quantidade de arquivos, linhas, camadas ou testes.

Granularidade inadequada não é `BLOCKED` final. Decisão, autorização, fonte ou
dependência ausente descoberta durante a divisão continua `BLOCKED` pela causa real.

## Handoff e validade

`READY` vale somente para task ID, versões, escopo e paths registrados. O executor
recusa evidência ausente, stale ou divergente. Mudança em qualquer fonte ou recorte
exige nova auditoria. O relatório registra blockers, decision owner e condição de
retomada.

