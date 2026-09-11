---
document_id: AUTOMATION-CONTRACT
primary_nature: Contexto
objective: Definir contratos para validadores que o projeto de destino deve implementar.
scope: Governanca documental, readiness verificavel, quality gates e evidencias.
non_objectives: Nao fornecer scripts, escolher stack, executar comandos ou simular automacao ausente.
owner: Plataforma, Arquitetura e Qualidade
status: Active
version: 1.2
date: 2026-09-10
last_reviewed: 2026-09-11
keywords: automacao, validadores, contratos, quality-gate, agentes, standards, gemini, antigravity
related_files: ../adrs/ADR-0000-governanca-do-harness-documental.md, ../agents/AgentOrchestrator.md, ../agents/standards/README.md, ../agents/standards/software-quality-standard.md, ../settings/google-gemini.md
code_references: N/A - implementacao intencionalmente excluida deste pacote documental.
principal_statement: Automacao deve falhar de forma fechada e publicar evidencia estruturada; ausencia nunca equivale a PASS.
---

# Contratos de automação

Este pacote é exclusivamente documental. O projeto adotante deve implementar os
entrypoints abaixo na linguagem e no local compatíveis com sua stack.

## Validador documental

Deve validar, no mínimo:

- presença dos artefatos obrigatórios e `README.md` de cada coleção ativa;
- frontmatter/contrato mínimo, IDs, nomes, estados e owners;
- inventário individual e links relativos;
- AgentOrchestrator presente e indexado como único agente inicial;
- inventário individual da biblioteca de standards e ativação diferenciada de
  disponibilidade;
- paridade semântica e nomes das skills pareadas;
- equivalência dos adaptadores globais, import de `AGENTS.md` por `GEMINI.md` e
  presença/limite da regra Antigravity;
- ausência de segredos e referências específicas indevidas;
- manifesto coerente com os módulos ativos;
- idempotência do bootstrap.

## Implementation Readiness

A presença estrutural dos campos pode ser automatizada, mas a decisão `READY`
permanece uma auditoria semântica. Regex não deve encerrar assumption, aprovar
fonte, decidir produto ou emitir falso `READY`. O plano deve registrar auditor,
data, versões, paths, controles e resultado.

## Executor de Quality Gate

A interface deve receber explicitamente:

- `scope`: pacote ou união de pacotes;
- `level`: `focused`, `pr` ou `release`;
- `target`: um ou mais paths alterados;
- `focus`: seletor obrigatório no nível `focused`, quando aplicável;
- referência ao `READY` vigente.

O executor não deve depender de descoberta implícita por Git. Deve produzir saída
humana e, quando possível, resultado estruturado com `PASS`, `FAIL` ou `BLOCKED`,
comandos executados, códigos de saída e causas.

## Comportamento fail-closed

- Ferramenta, configuração, relatório ou ambiente obrigatório ausente → `BLOCKED`.
- Violação observada → `FAIL`.
- Todos os controles aplicáveis executados e aprovados → `PASS`.
- Arquivo de ambiente local potencialmente sensível → não ler; interromper o build
  e usar fixture isolada ou variáveis sintéticas autorizadas.
- Teste de contrato do executor deve cobrir ajuda, argumentos inválidos, seleção de
  comandos, sucesso, falha, configuração ausente e proteção de segredo.

## Estado deste pacote

`Automação não configurada`. Isso é deliberado: somente documentação agnóstica foi
transportada. O bootstrap no projeto de destino deve registrar paths, comandos,
dependências, testes do validador e integração com CI antes de declarar automação
ativa.

Ativação `Always On`, Project folders, Agent Settings e Permissions do
Antigravity exigem verificação no runtime. O validador do repositório só pode
comprovar os arquivos versionados e deve reportar essa fronteira.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.2 | 2026-09-11 | Acrescenta validação do agente inicial e do catálogo portátil de standards. |
| 1.1 | 2026-09-11 | Inclui o contrato de validação dos adapters Google e separa estado versionado de verificação no runtime. |
