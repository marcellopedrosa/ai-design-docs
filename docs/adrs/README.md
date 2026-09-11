---
document_id: ADRS-INDEX
primary_nature: Contexto
objective: Permitir selecao semantica de decisoes antes da leitura integral.
scope: ADRs propostos, aceitos e historicos.
non_objectives: Nao duplicar decisoes nem criar decisao por meio do indice.
owner: Arquitetura
status: Active
version: 1.1
date: 2026-09-10
last_reviewed: 2026-09-11
keywords: adr, decisoes, arquitetura, indice, gemini, antigravity
related_files: ADR-0000-governanca-do-harness-documental.md, ../settings/google-gemini.md, ../templates/TPL-00004-adr.md
code_references: N/A - indice documental.
principal_statement: Consulte este indice e abra somente os ADRs relacionados a tarefa.
---

# Índice de ADRs

## Contrato da coleção

- Conteúdo aceito: decisões com contexto, alternativas, decisão, consequências e
  rastreabilidade.
- Nomes: `ADR-NNNN-short-title.md`.
- Estados: `Proposed`, `Accepted`, `Rejected`, `Superseded`, `Deprecated`.
- Critério de granularidade: separar decisões com alternativas, owner, vigência ou
  consequências independentes.

## Visão geral

| ADR | Título | Status | Tema |
| --- | --- | --- | --- |
| [ADR-0000](ADR-0000-governanca-do-harness-documental.md) | `v1.1`: governança do harness, incluindo adapters Google interoperáveis | Accepted | Governança |

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.1 | 2026-09-11 | Registra a decisão v1.1 de suporte a Gemini CLI e Antigravity. |
