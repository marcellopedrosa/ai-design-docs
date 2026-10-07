---
document_id: TP-00046
primary_nature: Plano
objective: Materializar no C.L.E.A.R. um gate obrigatório de prontidão que impeça implementação baseada em suposições não validadas, perguntas abertas ou tarefas sem contrato finito.
scope: ADR-0000, lifecycle, standards de prontidão e qualidade, templates de requisito, caso de uso, task plan e implementation plan, AgentOrchestrator, RequirementAgent, CodeGuardian, skills nativas, adaptadores, validação documental e portabilidade do teste de contrato do Quality Gate.
non_objectives: Migrar em massa artefatos legados, responder decisões de produto pelo humano, alterar código funcional ou criar uma coleção autônoma de User Stories.
owner: Arquitetura, Produto e Qualidade
status: In Progress
date: 2026-09-08
version: 1.2
keywords: clear, definition-of-ready, assumptions, open-questions, user-story, task-contract, hard-gate, decomposicao-semantica, portabilidade
related_files: harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md, do../../agents/standards/software-engineering-lifecycle.md, do../../agents/standards/implementation-readiness-standard.md, do../../agents/standards/software-quality-standard.md, harne../../../harness/templates/TPL-00003-requirement.md, harne../../../harness/templates/TPL-00004-use-case.md, harne../../../harness/templates/TPL-00005-task-plan.md, harne../../../harness/templates/TPL-00006-implementation-plan.md
code_references: AGENTS.md, CLAUDE.md, .agents/skills/implementation-readiness/SKILL.md, .claude/skills/implementation-readiness/SKILL.md, .agents/skills/quality-gate/SKILL.md, .claude/skills/quality-gate/SKILL.md, infra/scripts/validate-docs.sh, validate-documentation-governance.test.mjs, infra/scripts/validate-quality-gates.sh, infra/scripts/tests/validate-quality-gates-test.sh
principal_statement: Nenhuma codificação ou mudança executável começa enquanto o gate de prontidão não corrigir automaticamente a granularidade, reauditar cada unidade e comprovar fontes aprovadas, suposições validadas, perguntas resolvidas, testes mapeados, proibições, obrigações e Definition of Done finita.
---

# TP-00046 — Governança de prontidão para implementação

## Fontes superiores

- [ADR-0000](../../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md).
- [Software Engineering Lifecycle](../../agents/standards/software-engineering-lifecycle.md).
- [Templates](../../../harness/templates/README.md) e [catálogo de agentes](../../agents/README.md).

## Avaliação e decisão

1. User Story é uma visão concisa de ator, capacidade e valor; não substitui
   requisito aprovado, regras, critérios de aceite ou fluxo detalhado.
2. O caso de uso cobre mais detalhes que uma User Story, mas o template atual não
   torna explícita a narrativa de valor e contém referências `US-NNN` sem coleção
   canônica. A visão será incorporada ao requisito e ao caso de uso, sem criar
   artefato autônomo duplicado.
3. Preconditions descrevem fatos necessários à execução. Assumptions são
   proposições ainda não provadas; Open Questions são decisões ausentes. As duas
   últimas classes bloqueiam implementação até validação/resolução materializada.
4. RequirementAgent resolve ou escala; AgentOrchestrator executa sempre a auditoria
   de prontidão antes do handoff; CodeGuardian rejeita auditoria de código sem a
   evidência `READY`. Nenhum desses agentes responde decisão humana por inferência.

## Entregas

- Criar `implementation-readiness-standard.md` como fonte normativa.
- Criar e catalogar a skill pareada `implementation-readiness`.
- Memorizar no ADR-0000 sua obrigatoriedade, scaffold e contrato mínimo.
- Endurecer lifecycle, agentes e adaptadores globais.
- Atualizar TPL-00003 e TPL-00004 com User Story View, assumptions, questions e readiness.
- Atualizar TPL-00005 e TPL-00006 com tarefas contendo What, Where, Depends on, Reuses,
  Requirements, auditoria, testes, Prohibited, Mandatory e Definition of Done.
- Fazer o validador documental proteger o novo contrato.

## Extensão v1.2 — decomposição no ciclo e portabilidade

### Atomic Task Contract

| Campo | Conteúdo |
| --- | --- |
| **What** | Reconciliar a regra de decomposição semântica automática e a portabilidade do Quality Gate entre ADR, lifecycle, standards, skills e validação documental. |
| **Where** | ADR-0000; standards de readiness, lifecycle e qualidade; skills pareadas; seus índices; validador e teste documental; baseline portátil do teste do Quality Gate. |
| **Depends on** | ADR-0000 `Accepted` v4.16 e Implementation Readiness Standard `Active` v1.4. |
| **Reuses** | Regra já materializada no standard, TPL-00005, TPL-00006 e skill `implementation-readiness`; teste hermético existente do Quality Gate. |
| **Requirements** | ADR-0000 Sections 10.12 e 10.13, Implementation Readiness Standard e Software Quality Standard. |

### Gate Audit

| Controle | Evidência observada | Resultado |
| --- | --- | --- |
| Product Definition | `PRD not applicable`: mudança de governança sem alteração de comportamento, público, valor ou métrica do produto. | `N/A` |
| Fontes superiores | ADR-0000 `Accepted` v4.16; standards aplicáveis `Active`. | `PASS` |
| Assumptions / Open Questions | Nenhuma hipótese ou decisão de produto aberta; os sete passos foram autorizados explicitamente pelo mantenedor. | `PASS` |
| Dependências | Standard, templates, skills e scripts referenciados existem. | `PASS` |
| API Contract | `N/A`: nenhum endpoint HTTP é criado, alterado ou consumido. | `N/A` |
| Granularity / Decomposition | Uma entrega observável: o mesmo invariante portátil e validável em todo o ciclo; documentação, skill e teste são evidências inseparáveis dessa entrega. | `PASS` |

### Acceptance Tests

| Critério | Teste/evidência planejada | Resultado esperado |
| --- | --- | --- |
| ADR transporta a regra completa | Marcadores normativos exigidos pelo validador e teste documental. | Ausência de qualquer marcador falha de forma fechada. |
| Quality Gate respeita o IRG | Standard e skill exigem `READY` vigente e devolvem divergência à Phase 7. | Quality Gate não decompõe retrospectivamente. |
| Teste do executor é reconstruível | Corpo integral do baseline hermético publicado no ADR. | Port consegue materializar o teste sem inventar comportamento. |

### Prohibited

- Não transformar o Quality Gate em owner da decomposição.
- Não usar quantidade de linhas, arquivos, camadas ou testes como regra isolada de divisão.
- Não declarar validações como executadas nesta extensão enquanto o passo 8 estiver explicitamente adiado.

### Mandatory

- Preservar requisito, aceite, autorização e non-objectives na decomposição.
- Atualizar as duas skills nativas com paridade semântica e byte a byte.
- Atualizar índices, versões e changelogs dos artefatos documentais modificados.
- Atualizar o teste do validador junto com seu contrato executável.

### Definition of Done

- [x] ADR-0000 contém decomposição automática, reauditoria dos filhos e scaffold portátil equivalente.
- [x] Lifecycle posiciona a decomposição na Phase 7 e o retorno processual do Quality Gate para essa fase.
- [x] Software Quality Standard e skill pareada exigem readiness vigente sem assumir a decomposição.
- [x] Validador e teste protegem os novos marcadores.
- [x] ADR contém o corpo integral do baseline portátil do teste do Quality Gate.
- [x] Índices, versões e changelogs afetados estão atualizados.
- [x] Validações adiadas pelo mantenedor permanecem registradas como pendência, sem falso `PASS`.

### Result

| Campo | Valor |
| --- | --- |
| **Readiness Result** | `READY` |
| **Auditor** | `@AgentOrchestrator using implementation-readiness` |
| **Source Versions** | ADR-0000 v4.16; Implementation Readiness Standard v1.4; Software Quality Standard v1.0; Lifecycle v1.9. |
| **Scope Authorized** | TP-00046 v1.2 e paths declarados no Atomic Task Contract. |
| **Decomposition** | `N/A — atomic`: uma reconciliação normativa observável com evidências inseparáveis. |
| **Blockers / Decision Owner** | `N/A` |

### Handoff da extensão v1.2

- A decomposição automática pertence à Phase 7/IRG; o Quality Gate apenas verifica
  a correspondência do `READY` e devolve divergência ao planejamento.
- O ADR-0000 contém o baseline integral do teste hermético e a opção `--root`
  reservada às fixtures, mantendo o executor reconstruível.
- O validador e sua regressão foram atualizados, mas não executados porque o
  mantenedor solicitou ignorar inicialmente o passo 8.

| Reauditoria pós-edição | Evidência |
| --- | --- |
| Resultado | `READY` para eventual execução das validações adiadas; nenhuma implementação adicional está autorizada fora dos paths deste plano. |
| Fontes | ADR-0000 v4.17; Implementation Readiness Standard v1.5; Software Quality Standard v1.1; Lifecycle v1.10; TP-00046 v1.2. |
| Granularidade | `PASS — atomic`: reconciliação normativa única; nenhuma unidade filha semanticamente independente foi revelada. |
| Blockers | `N/A` para prontidão; Assurance permanece pendente exclusivamente pelo skip explícito do passo 8. |

| Comando planejado | Estado nesta extensão |
| --- | --- |
| `bash -n infra/scripts/validate-quality-gates.sh` | `SKIPPED — passo 8 adiado pelo mantenedor` |
| `bash -n infra/scripts/tests/validate-quality-gates-test.sh` | `SKIPPED — passo 8 adiado pelo mantenedor` |
| `bash infra/scripts/tests/validate-quality-gates-test.sh` | `SKIPPED — passo 8 adiado pelo mantenedor` |
| `node --test validate-documentation-governance.test.mjs` | `SKIPPED — passo 8 adiado pelo mantenedor` |
| `./infra/scripts/validate-docs.sh` | `SKIPPED — passo 8 adiado pelo mantenedor` |

## Critérios de aceite

- Nenhuma pergunta `Open` ou assumption não validada pode coexistir com resultado
  `READY`; não há waiver para iniciar código nessas condições.
- Resposta humana ou evidência autoritativa é registrada no artefato canônico antes
  da retomada.
- O Orchestrator deve invocar a skill antes de todo handoff de implementação, e o
  agente executor deve conferir a evidência.
- User Story não possui ID ou coleção fantasma; sua visão é rastreável ao requisito.
- Cada tarefa possui contrato finito e Definition of Done binária e verificável.
- Skills pareadas são válidas e idênticas; `./infra/scripts/validate-docs.sh`
  retorna código `0`.

## Validação

- Validação das duas skills com `quick_validate.py` e comparação byte a byte.
- `node --check` e suíte focal do validador documental.
- `./infra/scripts/validate-docs.sh` como evidência final agregada.

## Handoff e evidência

### Decisões entregues

- User Story permanece uma view interna ao Requirement e ao Use Case; não foi
  criada coleção paralela. O Requirement é a fonte do comportamento/aceite e o Use
  Case detalha fluxos e mapeia AC → fluxo → teste/evidência.
- O IRG é obrigatório e binário. Assumption `Proposed`, Open Question, decisão
  humana ausente, conflito, dependência incompleta ou DoD subjetiva resulta em
  `BLOCKED`, sem waiver e sem implementação parcial.
- RequirementAgent mantém incertezas e casos de uso; AgentOrchestrator sempre chama
  a skill antes do handoff; executor recusa evidência inválida; CodeGuardian
  verifica o processo antes da auditoria de código.
- Tasks executáveis publicam os dez campos normativos e encerram quando a DoD
  binária está comprovada. Descoberta fora do escopo cria blocker ou nova task.

### Evidência reproduzível

| Comando | Resultado |
| --- | --- |
| `node --check infra/scripts/validate-docs.sh` | `PASS` |
| `node validate-documentation-governance.test.mjs` | `PASS`, 24/24 testes |
| `quick_validate.py .agents/skills/implementation-readiness` | `PASS` |
| `quick_validate.py .claude/skills/implementation-readiness` | `PASS` |
| `cmp -s .agents/skills/implementation-readiness/SKILL.md .claude/skills/implementation-readiness/SKILL.md` | `PASS`, paridade byte a byte |
| `perl infra/scripts/validate-doc-reference-identifiers.pl docs` | `PASS` |
| `./infra/scripts/validate-docs.sh` | `PASS`: 747 Markdown, 30 diretórios, 728 artefatos indexados; 7 cenários do Quality Gate e estrutura documental aprovados |

A primeira execução agregada encontrou duas referências compactas a templates no
próprio plano; ambas foram expandidas para IDs canônicos e o gate subsequente
passou. Não houve mudança funcional, instalação, rede, Git, ambiente externo ou
execução de testes do produto. Artefatos legados não foram migrados em massa; ao
entrarem novamente em escopo executável, aplicam o IRG fail-closed.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.2 | 2026-09-10 | Reabre de forma limitada a governança para reconciliar decomposição automática, precondição de readiness no Quality Gate, enforcement documental e baseline portátil do teste; validações permanecem adiadas por solicitação humana. |
| 1.1 | 2026-09-08 | Conclui standard, templates, agentes, skill pareada, adaptadores e validação do hard gate de prontidão. |
| 1.0 | 2026-09-08 | Persiste avaliação, decisão e plano transversal antes das mudanças de governança. |
