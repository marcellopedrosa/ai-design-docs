---
document_id: SETTINGS-INDEX
primary_nature: Contexto
objective: Indexar regras agnosticas de ambiente, permissao e seguranca.
scope: Politicas compartilhadas por runtimes de agentes.
non_objectives: Nao definir requisito de produto, arquitetura ou preferencia pessoal.
owner: Plataforma de IA e DevOps
status: Active
version: 1.4
date: 2026-09-10
last_reviewed: 2026-09-13
keywords: settings, seguranca, permissoes, entrega-git, runtime, codex, claude-code, gemini, antigravity
related_files: settings.md, git-delivery.md, codex.md, claude-code.md, google-gemini.md, ../adrs/ADR-0000-governanca-do-harness-documental.md
code_references: ../../AGENTS.md, ../../CLAUDE.md, ../../GEMINI.md, ../../.agents/rules/documentation-governance.md
principal_statement: Configuracoes inferiores nao podem enfraquecer politicas organizacionais ou ADRs aceitos.
---

# Settings

## Contrato da coleção

- Conteúdo aceito: política agnóstica de ambiente, permissão e segurança.
- Nomes: `<assunto>.md`.
- Estados: `Draft`, `Active`, `Deprecated`.
- Critério de granularidade: separar quando runtime, owner ou ciclo de revisão forem
  independentes.

## Índice

- [Política do ambiente e do assistente](settings.md) - matriz agnóstica de menor privilégio para ambiente e permissões.
- [Política de entrega Git](git-delivery.md) - integração de branches de trabalho com proteção da `main`.
- [Mapeamento do Codex](codex.md) - descoberta por `AGENTS.md`, cadeia de adaptadores e skills versionadas.
- [Mapeamento do Claude Code](claude-code.md) - descoberta por `CLAUDE.md`, imports e skills equivalentes.
- [Mapeamento do Google Gemini e Antigravity](google-gemini.md) - `GEMINI.md`, regras Antigravity, sandbox e skills interoperaveis.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.4 | 2026-09-23 | Indexa a política local de integração Git e proteção da `main`. |
| 1.3 | 2026-09-13 | Inclui mapeamentos Codex e Claude Code e alinha o indice a autonomia Git governada. |
| 1.2 | 2026-09-13 | Indexa a política de ativação explícita para entrega Git governada. |
| 1.1 | 2026-09-11 | Indexa o adaptador portátil dos runtimes Google. |
