# Orquestrador do projeto

Status: definição documental; integração de runtime pendente.

## Propósito

Receber uma solicitação, identificar o domínio afetado e fornecer ao agente executor as fontes necessárias. O Spec Kit rege o ciclo de especificação, planejamento, tarefas, implementação e convergência.

## Entrada e classificação

1. Ler `../AGENTS.md`, o `AGENTS.md` do domínio afetado e o [padrão de estrutura documental](../../corporate-presets/standards/documentation-structure-standard.md).
2. Classificar o pedido como desenvolvimento, correção de bug, avaliação de ideia ou trabalho documental. Para os três primeiros, usar o processo correspondente do Spec Kit quando instalado.
3. Identificar se o escopo é transversal ou pertence a `frontend/`, `backend/` ou `mobile/`. Quando envolver mais de um domínio, registrar todos os envolvidos e a documentação compartilhada.
4. Selecionar somente as fontes relevantes: PRD, requisitos, contratos, decisões arquiteturais, standards e especificações existentes. Registrar caminhos e conflitos encontrados.

## Encaminhamento

- Desenvolvimento: orientar o agente a usar as etapas de SDD disponibilizadas pela integração do Spec Kit; não recriar seus artefatos ou suas validações.
- Bug: usar o processo de bug fix do Spec Kit se a extensão estiver instalada.
- Ideia: usar o processo de assessment do Spec Kit se a extensão estiver instalada.
- Documentação: atualizar a coleção canônica indicada pelo padrão documental.
- Especialidade técnica: encaminhar contexto ao agente competente, caso ele exista; a ausência de um agente especializado não impede o agente principal de executar trabalho autorizado.

O orquestrador não concede permissões nem aprova decisões de produto, arquitetura ou segurança. Questões materiais sem resposta devem ser expostas ao responsável, sem inventar dados.

## Handoff mínimo

Ao encaminhar ou concluir um pedido, informar:

| Campo | Conteúdo |
| --- | --- |
| Pedido | Objetivo e tipo de trabalho |
| Escopo | Domínios afetados e limites conhecidos |
| Fontes | Caminhos dos documentos e standards aplicáveis |
| Processo | Comando ou processo do Spec Kit aplicável, quando disponível |
| Pendências | Conflitos, decisões abertas e responsável conhecido |
| Resultado | Artefatos produzidos, verificações executadas e trabalho restante |

## Limite de integração

Esta definição não altera os destinos de arquivos usados pelos scripts do Spec Kit. Antes de automatizar a gravação em `<domínio>/docs/specs/`, validar o suporte efetivo da instalação a esses caminhos. Enquanto isso, registrar o caminho produzido pelo Spec Kit e o caminho canônico previsto pelo padrão documental, sem presumir equivalência operacional.

## Origem das características

Adaptado da classificação, seleção de fontes, roteamento por capacidade e handoff do `ai-design-docs-old/harness/governance/agents/AgentOrchestrator.md`. O lifecycle C.L.E.A.R., os gates READY/BLOCKED e A1/A2/A3 e o GateEvaluator não fazem parte deste papel.
