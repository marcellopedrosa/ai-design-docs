---
document_id: AGENTS-INDEX
primary_nature: Contexto
objective: Catalogar o agente inicial, papéis futuros e suas fontes operacionais.
scope: Agentes ativos, gatilhos, owners, standards, skills e handoffs.
non_objectives: Não registrar personas decorativas, ativar agentes por tecnologia ou duplicar instruções dos runtimes.
owner: Arquitetura e Plataforma de IA
status: Active
version: 1.3
date: 2026-09-10
last_reviewed: 2026-09-29
keywords: agentes, orquestrador, bootstrap, papeis, catalogo, handoff, entrega-git, gate-evaluator, subagente
related_files: AgentOrchestrator.md, GateEvaluator.md, ../../skills/README.md, ../../../docs/agents/standards/README.md, ../policies/ai-environment-policy.md, ../../templates/TPL-00011-agent.md
code_references: ../../../AGENTS.md, ../../../CLAUDE.md, ../../../GEMINI.md
principal_statement: O AgentOrchestrator coordena a execução; subagentes especializados como GateEvaluator operam sob isolamento estrito de menor privilégio.
---

# Agentes

## Contrato da coleção

- Conteúdo aceito: papel, gatilhos, entradas, saídas, limites, tools e handoffs de
  agentes especializados.
- Nomes: RoleName.md.
- Estados: Draft, Active, Deprecated.
- Critério de granularidade: um papel por responsabilidade e autoridade
  independentes; não criar agente apenas por tecnologia ou etapa nominal.

## Agentes catalogados

| Agente | Responsabilidade | Ativação | Status |
| --- | --- | --- | --- |
| [AgentOrchestrator](AgentOrchestrator.md) | Descoberta, planejamento, seleção de standards, readiness, coordenação de execução e assurance | Sempre no bootstrap | Active |
| [GateEvaluator](GateEvaluator.md) | Subagente avaliador isolado para execução de gates e subgates (A1, A2, A3) com ferramentas de escrita vedadas | Sob demanda de assurance | Active |

O AgentOrchestrator atua como coordenador central. Quando gates de assurance exigirem
isolamento de privilégios para evitar que o implementador avalie o próprio código,
o subagente [GateEvaluator](GateEvaluator.md) deve ser acionado com permissões
estritas de leitura e execução de testes.

## Subcoleções

- [Standards](../../../docs/agents/standards/README.md)
- [Skills operacionais](../../skills/README.md)

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.3 | 2026-09-29 | Registra o subagente especializado GateEvaluator com ferramentas restritas para isolamento de gates. |
| 1.2 | 2026-09-13 | Registra o roteamento condicional de entrega Git pelo agente inicial. |
| 1.1 | 2026-09-11 | Define AgentOrchestrator como único agente inicial e mantém papéis especializados sob ativação explícita. |
