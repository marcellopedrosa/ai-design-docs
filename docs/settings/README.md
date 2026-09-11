---
document_id: SETTINGS-INDEX
primary_nature: Contexto
objective: Indexar regras agnosticas de ambiente, permissao e seguranca.
scope: Politicas compartilhadas por runtimes de agentes.
non_objectives: Nao definir requisito de produto, arquitetura ou preferencia pessoal.
owner: Plataforma de IA e DevOps
status: Active
version: 1.1
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: settings, seguranca, permissoes, runtime, gemini, antigravity
related_files: settings.md, google-gemini.md, ../adrs/ADR-0000-governanca-do-harness-documental.md
code_references: AGENTS.md, CLAUDE.md, GEMINI.md, .agents/rules/documentation-governance.md
principal_statement: Regras compartilhadas usam menor privilegio e preferencias pessoais ficam fora do versionamento.
---

# Settings

## Contrato da coleção

- Conteúdo aceito: política agnóstica de ambiente, permissão e segurança.
- Nomes: `<assunto>.md`.
- Estados: `Draft`, `Active`, `Deprecated`.
- Critério de granularidade: separar quando runtime, owner ou ciclo de revisão forem
  independentes.

## Índice

- [Política do ambiente e do assistente](settings.md)
- [Mapeamento do Google Gemini e Antigravity](google-gemini.md)

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.1 | 2026-09-11 | Indexa o adaptador portátil dos runtimes Google. |
