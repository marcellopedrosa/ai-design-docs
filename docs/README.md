---
document_id: DOCS-INDEX
primary_nature: Contexto
objective: Mapear as colecoes documentais e fornecer a rota inicial de descoberta.
scope: Documentacao versionada sob docs/.
non_objectives: Nao duplicar requisitos, decisoes, standards ou configuracao operacional.
owner: Arquitetura e owners das colecoes
status: Active
version: 1.2
date: 2026-09-10
last_reviewed: 2026-09-11
keywords: documentacao, indice, descoberta-progressiva, governanca, orquestrador, standards, gemini, antigravity
related_files: ai/README.md, adrs/ADR-0000-governanca-do-harness-documental.md, agents/AgentOrchestrator.md, agents/standards/README.md, settings/google-gemini.md
code_references: ../AGENTS.md, ../CLAUDE.md, ../GEMINI.md, ../.agents/rules/documentation-governance.md; a topologia do projeto de destino deve ser registrada no manifesto.
principal_statement: Cada tipo de informacao possui uma fonte canonica e deve ser carregado somente quando relevante.
---

# Mapa documental

## Três camadas

| Camada | Fonte | Finalidade |
| --- | --- | --- |
| Regras de ambiente e do assistente | [`settings/`](settings/README.md) | Segurança, permissões, limites e invariantes globais. |
| Documentação funcional e técnica | Coleções tipadas abaixo | Produto, requisitos, decisões, arquitetura, planos e histórico. |
| Operação do runtime | `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.agents/rules/` e adaptadores locais | Descoberta, comandos essenciais e diferenças por pacote. |

[`ai/README.md`](ai/README.md) é navegação entre as camadas, não uma quarta fonte
de verdade.

## Coleções

| Coleção | Natureza | Estado inicial | Índice |
| --- | --- | --- | --- |
| Navegação de IA | Contexto | Active | [ai/README.md](ai/README.md) |
| Settings | Regra | Active | [settings/README.md](settings/README.md) |
| ADRs | Decisão | Active | [adrs/README.md](adrs/README.md) |
| Arquitetura | Contexto | Active | [architecture/README.md](architecture/README.md) |
| Agentes | Regra | AgentOrchestrator active | [agents/README.md](agents/README.md) |
| Standards | Regra | Biblioteca active; seleção por aplicabilidade | [agents/standards/README.md](agents/standards/README.md) |
| Skills operacionais | Contexto | Active | [agents/skills/README.md](agents/skills/README.md) |
| Templates | Template | Active | [templates/README.md](templates/README.md) |
| Automação documental | Contexto | Active | [automation/README.md](automation/README.md) |
| Negócio | Contexto | Empty baseline | [business/README.md](business/README.md) |
| Skills de negócio | Contexto | Empty baseline | [business/skills/README.md](business/skills/README.md) |
| Product requirements | Requisito | Empty baseline | [product_requirements/README.md](product_requirements/README.md) |
| Requirements | Requisito | Empty baseline | [requirements/README.md](requirements/README.md) |
| Use cases | Requisito | Empty baseline | [use_cases/README.md](use_cases/README.md) |
| Contratos | Contexto | Empty baseline | [contracts/README.md](contracts/README.md) |
| Task plans | Plano | Empty baseline | [task_plans/README.md](task_plans/README.md) |
| Análises | Contexto | Empty baseline | [analysis/README.md](analysis/README.md) |
| Lições aprendidas | Histórico | Empty baseline | [lessons_learned/README.md](lessons_learned/README.md) |
| Relatórios | Histórico | Empty baseline | [reports/README.md](reports/README.md) |
| Compliance | Contexto | Empty baseline | [compliance/README.md](compliance/README.md) |
| Onboarding | Contexto | Empty baseline | [onboard/README.md](onboard/README.md) |
| Provas de conceito | Histórico | Empty baseline | [pocs/README.md](pocs/README.md) |

`Empty baseline` significa que somente o contrato da coleção existe. O primeiro
artefato real ativa o inventário e exige owner e estado próprios.

O [AgentOrchestrator](agents/AgentOrchestrator.md) é o único agente inicial. A
presença de um standard no catálogo o torna disponível, não automaticamente
aplicável; o plano registra quais regras foram ativadas.

## Regra de leitura

1. Comece em [ai/README.md](ai/README.md).
2. Selecione PRD aplicável ou justifique `PRD not applicable` para trabalho sem
   impacto de produto.
3. Abra o requirement diretamente relacionado.
4. Consulte [adrs/README.md](adrs/README.md) e apenas as decisões selecionadas.
5. Consulte [architecture/module-registry.md](architecture/module-registry.md).
6. Abra contratos, casos de uso, planos e standards somente quando referenciados
   pelas fontes anteriores ou necessários para resolver uma lacuna.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.2 | 2026-09-11 | Registra o orquestrador inicial e a biblioteca portátil de standards condicionais. |
| 1.1 | 2026-09-11 | Inclui Gemini CLI e Antigravity na camada operacional do harness. |
