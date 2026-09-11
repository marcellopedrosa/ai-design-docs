---
document_id: AI-ENTRY
primary_nature: Contexto
objective: Orientar pessoas e agentes a carregar somente a documentacao relevante para cada tarefa.
scope: Navegacao, ordem de leitura, relevancia e conflitos.
non_objectives: Nao republicar regras, requisitos, decisoes, arquitetura ou configuracao de runtime.
owner: Arquitetura
status: Active
version: 1.1
date: 2026-09-10
last_reviewed: 2026-09-11
keywords: agentes, navegacao, contexto-progressivo, ordem-de-leitura, gemini, antigravity
related_files: ../README.md, ../adrs/README.md, ../architecture/module-registry.md, ../settings/google-gemini.md
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
| Regra técnica | [`agents/standards/`](../agents/standards/README.md) |
| Operação e segurança do agente | [`settings/`](../settings/README.md) |

## Ordem para mudanças

1. Adaptadores ativos e este manual.
2. PRD aplicável `Validated`, ou `not applicable` justificado.
3. Requirement diretamente relacionado e seus critérios de aceite.
4. Índice de ADRs e somente os ADRs selecionados.
5. Manifesto de módulos e arquitetura da área.
6. Contrato de interface aplicável.
7. Planos relacionados.
8. Somente standards referenciados pelas fontes anteriores.
9. Gate `implementation-readiness` para qualquer mudança executável.
10. Código, testes e configuração afetados somente após `READY`.

Não leia por padrão documentos de negócio, use cases, relatórios, lições,
templates, ADRs não selecionados ou pacotes fora do escopo. Eles entram somente por
relação explícita ou lacuna comprovada.

Os adapters ativos são `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` e a regra de workspace
Antigravity. O [mapeamento Google](../settings/google-gemini.md) define como validar
essas fontes sem transformar este manual em configuração de runtime.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.1 | 2026-09-11 | Acrescenta a rota de descoberta para Gemini CLI e Antigravity. |
