---
document_id: AI-ENTRY
primary_nature: Contexto
objective: Orientar pessoas e agentes a carregar somente a documentacao relevante para cada tarefa.
scope: Navegacao, ordem de leitura, relevancia e conflitos.
non_objectives: Nao republicar regras, requisitos, decisoes, arquitetura ou configuracao de runtime.
owner: Arquitetura
status: Active
version: 1.5
date: 2026-09-10
last_reviewed: 2026-09-13
keywords: agentes, orquestrador, standards, skills, entrega-git, navegacao, contexto-progressivo, codex, claude-code, gemini, antigravity
related_files: ../README.md, ../adrs/README.md, ../architecture/module-registry.md, ../agents/AgentOrchestrator.md, ../agents/standards/README.md, ../agents/skills/README.md, ../automation/README.md, ../scripts/README.md, ../settings/settings.md, ../settings/codex.md, ../settings/claude-code.md, ../settings/google-gemini.md
code_references: ../../AGENTS.md, ../../CLAUDE.md, ../../GEMINI.md, ../../.agents/rules/documentation-governance.md
principal_statement: Carregue primeiro as fontes diretamente relacionadas e expanda o contexto somente por referencias ou lacunas comprovadas.
---

# Manual de entrada para agentes

## Ordem de autoridade

1. Políticas organizacionais gerenciadas de segurança e compliance.
2. ADRs aceitos.
3. Standards e settings globais versionados.
4. Adaptadores globais de runtime.
5. Instruções e configurações específicas do pacote.
6. Plano e critérios de aceite da tarefa.
7. Preferências locais do usuário.

Uma camada inferior pode especializar seu escopo, mas não enfraquecer fonte
superior. Em conflito não resolvido, aplique a regra mais restritiva, registre a
lacuna e consulte o owner.

## Ponto de início

| Tarefa | Primeira fonte |
| --- | --- |
| Iniciativa ou mudança de produto | [`product_requirements/`](../product_requirements/README.md) |
| Comportamento observável | [`requirements/`](../requirements/README.md) |
| Decisão técnica | [`adrs/`](../adrs/README.md) |
| Estrutura, módulo ou comando | [`architecture/module-registry.md`](../architecture/module-registry.md) |
| API, evento ou schema | [`contracts/`](../contracts/README.md) |
| Execução planejada | [`task_plans/`](../task_plans/README.md) |
| Coordenação, decomposição ou handoff | [`AgentOrchestrator.md`](../agents/AgentOrchestrator.md) |
| Regra técnica | [`agents/standards/`](../agents/standards/README.md) |
| Commit ou publicação Git solicitados | [`agents/skills/`](../agents/skills/README.md), política de ambiente e ADR-0000 |
| Adaptar ou executar validadores do harness | [`scripts/`](../scripts/README.md) e [`automation/`](../automation/README.md) |
| Operação e segurança do agente | [`settings/`](../settings/README.md), incluindo o runtime ativo quando houver mapeamento próprio |

## Ordem para mudanças

1. Adaptadores ativos, este manual e o [AgentOrchestrator](../agents/AgentOrchestrator.md).
2. PRD aplicável `Validated`, ou `not applicable` justificado.
3. Requirement diretamente relacionado e seus critérios de aceite.
4. Índice de ADRs e somente os ADRs selecionados.
5. Manifesto de módulos e arquitetura da área.
6. Contrato de interface aplicável.
7. Planos relacionados.
8. Baseline e somente standards condicionais ativados pelas fontes e pelo risco.
9. Gate `implementation-readiness` para qualquer mudança executável.
10. Código, testes e configuração afetados somente após `READY`.

Não leia por padrão documentos de negócio, use cases, relatórios, lições,
templates, ADRs não selecionados ou pacotes fora do escopo. Eles entram somente por
relação explícita ou lacuna comprovada.

Os adapters ativos são `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` e a regra de workspace
Antigravity, quando o projeto adotante suportar esses runtimes. Os mapeamentos em
[`settings/`](../settings/README.md) definem como validar essas fontes sem
transformar este manual em configuração de runtime.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.5 | 2026-09-13 | Inclui rotas para os mapeamentos portateis de Codex e Claude Code. |
| 1.4 | 2026-09-13 | Acrescenta a rota condicional para os scripts executáveis de governança. |
| 1.3 | 2026-09-13 | Acrescenta a rota condicional para entrega Git governada. |
| 1.2 | 2026-09-11 | Torna o AgentOrchestrator a entrada operacional e referencia o catálogo portátil de standards. |
| 1.1 | 2026-09-11 | Acrescenta a rota de descoberta para Gemini CLI e Antigravity. |
