---
document_id: PROJECT-IMPLEMENTATION-READINESS-STANDARD
primary_nature: Regra
objective: Definir o gate obrigatório que transforma PRDs validados, requisitos e planos aprovados em autorização documental segura e finita para implementação.
scope: Product Definition Gate, User Story View, suposições, perguntas abertas, fontes superiores, contrato de tarefa, decomposição semântica automática, auditoria de prontidão, responsabilidades e evidência READY/BLOCKED.
non_objectives: Aprovar decisões em nome do humano, substituir requisitos ou casos de uso, auditar qualidade de código já produzido ou autorizar ambiente externo.
owner: Arquitetura, Produto e Qualidade
status: Active
date: 2026-09-08
last_reviewed: 2026-09-10
version: 1.7
keywords: implementation-readiness, product-definition-gate, prd, definition-of-ready, assumptions, open-questions, task-contract, decomposicao-semantica, openapi, api-contract, clear
related_files: harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md, docs/product/requirements/README.md, ./software-engineering-lifecycle.md, ./software-quality-standard.md, api-client-standard.md, docs/api_contracts/README.md, harness/templates/TPL-00011-api-contract.md, harness/templates/TPL-00012-prd.md, harness/templates/TPL-00003-requirement.md, harness/templates/TPL-00004-use-case.md, harness/templates/TPL-00005-task-plan.md, harness/templates/TPL-00006-implementation-plan.md, ../AgentOrchestrator.md, ../RequirementAgent.md, ../CodeGuardian.md
code_references: AGENTS.md, CLAUDE.md, docs/api_contracts/, .agents/skills/implementation-readiness/SKILL.md, .claude/skills/implementation-readiness/SKILL.md
principal_statement: PRD aplicável Validated e Requirement Approved são necessários, mas insuficientes; granularidade inadequada é corrigida automaticamente antes do resultado, trabalho com API HTTP exige OpenAPI canônico completo e causas pendentes reais produzem BLOCKED.
---

# Implementation Readiness Standard

## 1. Decisão e posição no C.L.E.A.R.

O **Implementation Readiness Gate (IRG)** encerra `[L] Logic & Layout` e antecede
`[E] Execution`. Ele é uma auditoria documental obrigatória, executada novamente
antes de cada handoff que autorize escrita de código, configuração executável,
migration, IaC ou geração de artefato de runtime.

O resultado possui somente dois estados:

| Resultado | Significado | Efeito obrigatório |
| --- | --- | --- |
| `READY` | Todas as fontes, decisões, dependências e condições da tarefa estão comprovadas. | O Orchestrator pode entregar a tarefa ao agente executor dentro do escopo auditado. |
| `BLOCKED` | Existe pergunta aberta, suposição não validada, fonte sem aprovação, conflito, dependência ausente ou critério não verificável. | Proibir implementação; registrar o blocker e solicitar decisão ao owner competente. |

Não existe `READY WITH ASSUMPTIONS`, waiver, aceite tácito, prazo expirado ou
classificação “não bloqueante” para pergunta ainda aberta. Se uma pergunta não
afeta o escopo, ela deve ser encerrada como `Resolved` com justificativa antes do
gate.

## 2. PRD, User Story, requisito e caso de uso

PRD, User Story, requisito e caso de uso têm funções diferentes:

| Artefato | Pergunta | Autoridade |
| --- | --- | --- |
| **PRD** | Qual problema, público, resultado, limite e métrica justificam a iniciativa? | Fonte de intenção de produto; precisa estar `Validated` quando aplicável e agrega requisitos sem copiar seus critérios. |
| **User Story View** | Quem precisa de qual capacidade e para obter qual valor? | Visão narrativa dentro do requisito e do caso de uso; não recebe ID ou coleção próprios nesta instalação. |
| **Requirement** | Qual comportamento observável, regra, restrição e critério devem ser satisfeitos? | Fonte funcional aprovada e obrigatória. |
| **Use Case** | Como atores e sistema percorrem fluxo principal, alternativas e exceções? | Detalhamento condicional ligado ao requisito; obrigatório para interação complexa. |

A forma normativa da visão é:

> Como `<ator/persona>`, quero `<capacidade observável>`, para `<resultado/valor>`.

Ela deve apontar para critérios de aceite do requisito. O caso de uso detalha mais
que a User Story, mas não substitui o requisito aprovado. Criar `US-NNN` separado
duplicaria owner, estado e critérios sem um ciclo autônomo demonstrado; um novo
tipo documental somente pode ser ativado por decisão sucessora.

PRD possui ciclo autônomo porque governa problema, público, outcomes, métricas e
hipóteses anteriores à especificação funcional. Ele não substitui Requirement ou
Use Case. `Draft`, `In Review`, `Deprecated`, Product Hypothesis `Proposed`, Open
Question ou aprovação ausente no PRD aplicável tornam o fluxo `BLOCKED`. Trabalho
puramente técnico pode registrar `PRD not applicable` somente com justificativa
específica e auditável.

## 3. Fatos, preconditions, suposições e perguntas

- **Fact:** afirmação comprovada por fonte canônica identificada.
- **Precondition:** estado verificável que precisa existir quando o comportamento
  for executado; não representa incerteza de análise.
- **Assumption:** proposição usada para avançar análise enquanto ainda não foi
  provada. Estados permitidos: `Proposed`, `Validated` ou `Rejected`.
- **Open Question:** decisão ou informação ausente. Estados permitidos: `Open` ou
  `Resolved`.
- **Product Hypothesis:** crença testável sobre problema, público, valor, adoção ou
  resultado. Possui estados `Proposed`, `Validated` ou `Rejected` dentro do PRD; um
  PRD não pode ser `Validated` enquanto alguma hipótese estiver `Proposed`.

Somente `Validated` ou `Rejected` encerram uma assumption. Somente `Resolved`
encerra uma pergunta. Cada encerramento registra resposta, owner, data e evidência
canônica ou decisão humana. Assumption `Proposed`, pergunta `Open`, placeholder,
`TBD`, escolha implícita ou respostas contraditórias tornam o IRG `BLOCKED`.

O agente pode validar uma assumption usando fonte superior inequívoca. Quando a
resposta exige preferência, escopo, risco, valor de negócio ou decisão ainda não
materializada, `RequirementAgent` ou `AgentOrchestrator` deve perguntar ao humano.
A resposta é primeiro gravada no requisito/caso de uso e somente depois o gate é
reexecutado. Conversa transitória, comentário de código ou decisão apenas no plano
não substituem essa materialização.

## 4. Contrato obrigatório de auditoria

O relatório de prontidão aparece no Task Plan e no Implementation Plan nesta ordem:

### 4.1 Gate Audit

| Controle | Evidência exigida |
| --- | --- |
| Product Definition | PRD aplicável em `Validated`, com versão, escopo, owner e evidência de aprovação; ou `not applicable` justificado para trabalho sem impacto de produto. |
| Fontes superiores | Requisito `Approved`; ADRs aplicáveis `Accepted`; use case `Approved` quando aplicável; análise de aderência aprovada ou resultado equivalente governado. |
| User Story View | Ator, capacidade e valor ligados aos IDs de aceite; `N/A` somente para trabalho puramente técnico com justificativa. |
| Use Case aplicável | Cada AC em escopo está ligado ao fluxo que o demonstra e ao teste/evidência planejado; comportamento novo retorna ao Requirement. |
| API Contract | Para toda criação, alteração ou integração com API HTTP do backend: contrato canônico em `docs/api_contracts/`, `info.version` exata e `operationId`s em escopo. O agente cria/corrige e autoaprova (`Active`/`Auto-approved`) conforme o API Client Standard. Ausência ou divergência é reparada automaticamente e nunca produz `BLOCKED`; somente decisão de produto/arquitetura descoberta no reparo pode bloquear. |
| Assumptions | Nenhuma em `Proposed`; todas `Validated` ou `Rejected` com evidência. |
| Open Questions | Nenhuma em `Open`; todas `Resolved` com resposta e owner. |
| Dependências | Upstream concluído ou disponível; conflitos e decisões humanas encerrados. |
| Escopo | What e Where inequívocos; non-objectives e fronteiras explícitos. |
| Granularidade / Decomposição | Uma entrega observável e um handoff por task/IP; partes independentemente aceitáveis, executáveis, reversíveis, autorizáveis ou replanejáveis foram separadas e encadeadas. |
| Tarefa | Reuses, Requirements e Definition of Done preenchidos e verificáveis. |

### 4.2 Acceptance Tests

Cada critério de aceite relevante aponta para teste planejado, comando ou evidência
manual autorizada. Ausência de estratégia de teste para comportamento alterado
produz `BLOCKED`. Quando o Use Case detalha a interação, ele mapeia AC → fluxo →
teste/evidência. Se um fluxo revelar comportamento sem AC, o Requirement é
atualizado, aprovado e auditado novamente antes de implementação.

### 4.3 Prohibited

Lista explícita do que a tarefa não pode fazer: fora de escopo, bypass, decisão não
autorizada, acesso externo, leitura de segredo, alteração destrutiva ou relaxamento
de gate aplicável. `N/A` exige justificativa específica.

### 4.4 Mandatory

Lista explícita de tudo que deve existir antes e durante a execução: fontes,
aprovações, dependências, teste focal, suite impactada, standards e owners. Em
trabalho de API, inclui o link e a versão do contrato OpenAPI, operações exatas e
testes de paridade/drift. Item contratual ausente aciona correção automática; os
demais itens continuam sujeitos ao gate normal.

### 4.5 Result

Registra `READY` ou `BLOCKED`, auditor, data, escopo exato, blockers e próximo
owner. Resultado vale somente para a versão e o escopo auditados; mudança em PRD,
requisito, UC, ADR, tarefa ou assumption invalida o `READY` e exige nova auditoria.

## 5. Contrato atômico de tarefa

Cada tarefa executável de Task Plan e Implementation Plan deve conter:

| Campo | Conteúdo obrigatório |
| --- | --- |
| **What** | Resultado observável único da tarefa. |
| **Where** | Pacotes, módulos, símbolos e paths autorizados. |
| **Depends on** | IDs de tarefas e artefatos que precisam estar concluídos. |
| **Reuses** | Código, componente, contrato, padrão ou fixture existente; `N/A` com busca e justificativa quando não houver. |
| **Requirements** | Requisitos, casos de uso, ADRs, standards, contratos e planos aplicáveis com links. |
| **Gate Audit** | Evidência do IRG para a versão exata das fontes. |
| **Acceptance Tests** | Mapeamento critério → teste/comando/evidência esperada. |
| **Prohibited** | Ações e resultados que não podem ocorrer. |
| **Mandatory** | Preconditions e entregas indispensáveis. |
| **Definition of Done** | Lista finita de condições binárias e evidências de encerramento. |

Definition of Done não pode usar termos abertos como “melhorar”, “quando possível”
ou “até ficar bom”. Cada item precisa de condição binária, evidência e comando ou
artefato. Quando todos os itens passam, a tarefa termina; achado novo fora do escopo
vira blocker ou tarefa futura, sem ampliar silenciosamente a execução nem criar
loop infinito.

### 5.1 Decomposição semântica automática

Falha de granularidade nunca é motivo final para encerrar a auditoria em `BLOCKED`
nem para solicitar ao humano uma estratégia de divisão. Mesmo quando existirem
outros controles pendentes, antes de emitir o resultado o `AgentOrchestrator` deve
decompor semanticamente a unidade e reexecutar o gate sobre cada task ou
Implementation Plan resultante.

A decomposição é obrigatória quando houver mais de um resultado observável que
possa ser aceito, executado, revertido, autorizado ou replanejado de forma
independente, ou quando entrega, owner, dependência, risco, área tecnológica,
handoff ou ciclo de execução forem independentes. Ela deve:

1. preservar requisito, critérios de aceite, escopo autorizado e non-objectives;
2. criar unidades verticais com um resultado e um handoff cada, mantendo código,
   teste e evidência inseparáveis na mesma unidade;
3. atribuir IDs inequívocos, `What`/`Where`, dependências e DoD próprios;
4. manter o Task Plan como coordenador e registrar ordem, handoffs e links para os
   Implementation Plans filhos;
5. atualizar os índices imediatos quando novos artefatos forem criados; e
6. reexecutar o IRG separadamente para cada unidade antes de qualquer handoff.

Quantidade de arquivos, linhas, camadas técnicas ou itens de teste isoladamente não
obriga divisão. TP/IP acima de 500 linhas ou 64 KiB exige a seção estruturada
`Granularity / Decomposition Review` definida pelo Software Quality Standard. O
resultado `Decomposed` registra ao menos dois IDs filhos; `Semantically indivisible`
registra justificativa e `Children: N/A`. O Quality Gate mede esse contrato nos
targets explícitos e uma evidência ausente ou inválida retorna `FAIL` ao IRG para
esta correção automática e nova auditoria, não `BLOCKED` final pelo tamanho.

A decomposição não pode inventar comportamento, escolher preferência de produto,
ampliar autorização nem contornar gate de alocação de identificador. Se ela revelar
assumption, Open Question, conflito ou autorização ausente, o resultado passa a ser
`BLOCKED` por essa causa real. Em coleções como `IP-INFRA`, novos IDs ou arquivos
continuam sujeitos ao gate humano específico; dentro da identidade já autorizada,
work packages e tasks devem ser granularizados automaticamente até ficarem
atômicos.

## 6. Responsabilidades e chamada obrigatória

| Papel | Responsabilidade |
| --- | --- |
| `RequirementAgent` | Estruturar PRD e requisitos, classificar hipóteses/incertezas, buscar fonte canônica e solicitar decisão humana; não validar o próprio PRD nem aprovar a própria resposta. |
| `AgentOrchestrator` | Invocar sempre a skill `implementation-readiness`; corrigir automaticamente toda falha de granularidade; reauditar cada unidade resultante; registrar o resultado no ledger/plano e não despachar implementação em `BLOCKED`. |
| Agente executor | Conferir `READY` válido antes de editar código/configuração; recusar handoff ausente, vencido ou divergente. |
| `CodeGuardian` | Na auditoria de código, verificar a evidência de prontidão; ausência é finding processual bloqueante e retorna ao Orchestrator. Não decide requisito. |
| Humano/owner | Responder decisões de produto, risco ou escopo e aprovar requisitos; sua resposta deve ser materializada. |

O auditor de prontidão é o `AgentOrchestrator` operando a skill pareada. Isso é
obrigatório mesmo quando o mesmo agente acabou de criar o plano: criação e auditoria
são passos distintos, com resultado explícito. CodeGuardian não substitui esse gate
porque atua no Assurance depois que código existe.

Assurance exige o `READY` desta etapa para o mesmo task ID, versões, escopo e paths.
Se CodeGuardian ou a skill `quality-gate` encontrar evidência ausente, stale,
divergente ou múltiplos resultados independentes sob uma única unidade auditada,
registra `BLOCKED` processual e devolve o fluxo à Phase 7. Quality Gate não
decompõe retrospectivamente código já produzido; o Orchestrator corrige o plano e
reaudita os filhos antes de uma nova execução.

## 7. Aplicação a legado e mudança corrente

Não é necessário reformatar em massa documentos históricos. Porém, ao selecionar
um requisito, caso de uso ou plano legado para nova implementação, o PRD aplicável
deve estar `Validated` e qualquer assumption ou Open Question ainda aberta bloqueia
imediatamente o novo handoff. O artefato deve ser atualizado, aprovado quando
necessário e auditado antes da primeira edição executável. O estado histórico da
implementação não é reclassificado retroativamente.

Se a mudança cria, altera ou consome API HTTP do backend, a mesma adoção progressiva
exige criar ou atualizar primeiro o contrato em `docs/api_contracts/` e referenciar sua
versão e operações em cada documento oficial afetado. Um controller existente não
autoriza nova mudança contratual sem esse baseline.

Trabalho exclusivamente documental pode continuar para resolver e materializar o
blocker. O estado `BLOCKED` impede implementação, não impede análise, pergunta ao
humano ou correção dos próprios documentos de prontidão.

## 8. Evidência mínima de handoff

O handoff publica: task ID; PRD aplicável e versão ou justificativa `not applicable`;
versões das fontes; contrato OpenAPI, versão e `operationId`s quando aplicável; resultado IRG; assumptions e
questions encerradas; What/Where/Depends on/Reuses/Requirements; testes;
Prohibited; Mandatory; DoD; auditor; data; mapeamento pai → filhos quando houver
decomposição; e blockers remanescentes. Sem essa evidência, o receptor deve recusar
a tarefa.

## 9. Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.6 | 2026-09-10 | Vincula a decomposição automática à medição executável de TP/IP e à revisão estruturada exigida pelo Quality Gate acima de 500 linhas/64 KiB. |
| 1.5 | 2026-09-10 | Fecha o feedback de Assurance: readiness ausente ou divergente retorna à Phase 7, e o Quality Gate não assume decomposição retrospectiva. |
| 1.7 | 2026-09-18 | Define contratos de API como artefatos agent-owned, autoaprovados e não bloqueantes; falhas posteriores entram no loop automático de correção. |
| 1.4 | 2026-09-09 | Torna contrato OpenAPI canônico e completo um controle bloqueante do readiness para toda criação, alteração ou integração com API HTTP do backend. |
| 1.3 | 2026-09-09 | Converte toda falha de granularidade em decomposição semântica automática seguida de reauditoria, sem inferir produto, ampliar escopo ou contornar gates de autorização. |
| 1.2 | 2026-09-09 | Integra PRD `Validated` e Product Definition Gate ao IRG, sem confundir implementação técnica com validação de produto. |
| 1.1 | 2026-09-08 | Exige cobertura AC → fluxo → teste/evidência no Use Case sem deslocar a autoridade do Requirement. |
| 1.0 | 2026-09-08 | Define User Story View sem coleção duplicada, hard gate de incertezas e contrato finito de tarefa. |
