---
document_id: AGENTS-INDEX
primary_nature: Contexto
objective: Catalogar o agente inicial, papéis futuros e suas fontes operacionais.
scope: Agentes ativos, gatilhos, owners, standards, skills e handoffs.
non_objectives: Não registrar personas decorativas, ativar agentes por tecnologia ou duplicar instruções dos runtimes.
owner: Arquitetura e Plataforma de IA
status: Active
version: 1.2
date: 2026-09-10
last_reviewed: 2026-09-13
keywords: agentes, orquestrador, bootstrap, papeis, catalogo, handoff, entrega-git
related_files: AgentOrchestrator.md, skills/README.md, standards/README.md, ../settings/settings.md, ../templates/TPL-00011-agent.md
code_references: ../../AGENTS.md, ../../CLAUDE.md, ../../GEMINI.md
principal_statement: O AgentOrchestrator é o único agente inicial; papéis adicionais exigem responsabilidade, autoridade e handoff independentes.
---

# Agentes

## Contrato da coleção

- Conteúdo aceito: papel, gatilhos, entradas, saídas, limites, tools e handoffs de
  agentes especializados.
- Nomes: RoleName.md.
- Estados: Draft, Active, Deprecated.
- Critério de granularidade: um papel por responsabilidade e autoridade
  independentes; não criar agente apenas por tecnologia ou etapa nominal.

## Agente inicial

| Agente | Responsabilidade | Ativação | Status |
| --- | --- | --- | --- |
| [AgentOrchestrator](AgentOrchestrator.md) | Descoberta, planejamento, seleção de standards, readiness, coordenação de execução e assurance | Sempre no bootstrap | Active |

Nenhum outro agente especializado integra o baseline. O AgentOrchestrator pode
rotear uma tarefa por capacidade e o agente principal do runtime pode exercê-la
diretamente. Um novo papel persistente só é criado com owner, limites, entradas,
saídas e handoffs próprios, usando o
[template de agente](../templates/TPL-00011-agent.md), e entra neste índice na mesma
mudança.

## Subcoleções

- [Standards](standards/README.md)
- [Skills operacionais](skills/README.md)

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.2 | 2026-09-13 | Registra o roteamento condicional de entrega Git pelo agente inicial. |
| 1.1 | 2026-09-11 | Define AgentOrchestrator como único agente inicial e mantém papéis especializados sob ativação explícita. |
