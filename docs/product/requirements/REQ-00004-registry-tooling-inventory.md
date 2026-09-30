---
document_id: REQ-00004
primary_nature: Requisito
objective: Inventariar todos os executores operacionais ativos do harness no Registry.
scope: Entradas de tooling para runner, validadores, hooks ativos e controles existentes.
non_objectives: Criar DSL, workflow engine ou configuração universal.
owner: Mantenedores do harness
status: Approved
version: 0.1
date: 2026-09-30
last_reviewed: 2026-09-30
keywords: registry, tooling, inventario
related_files: ../../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md
code_references: ../../../harness/registry/tooling.yaml, ../../../harness/tooling/harness-doctor/index.mjs, ../../../harness/tooling/harness-doctor/harness-doctor.test.mjs
principal_statement: Toda ferramenta operacional ativa relevante deve ser descoberta pelo Registry e validada pelo Doctor.
---

# REQ-00004 — Inventário de tooling operacional

## Origem

FIX-004 do plano V4 fornecido pelo usuário; PRD não aplicável por tratar da descoberta de tooling do harness. ADR-0000 Accepted.

## User Story View

Como operador, quero descobrir as ferramentas ativas pelo Registry para não depender de conhecimento implícito de paths.

## Comportamento e critérios de aceite

- AC-01 — Runner de eval, validador de contratos, validador de política de qualidade e hook ativo constam de `harness/registry/tooling.yaml` com entrypoint e status reais.
- AC-02 — Cada entrada ativa tem entrypoint existente e passa a checagem estrutural do Doctor.
- AC-03 — O hook `require-handoff` removido não aparece como controle ativo.
- AC-04 — Um teste protege a presença dos executores operacionais centrais sem exigir inventário de cada arquivo documental.

## Contrato, incertezas e aprovação

Contrato consumido: `harness/registry/tooling.yaml` v1; sem schema novo. Nenhuma assumption ou pergunta aberta. Aprovado pelo mantenedor em 2026-09-30 ao solicitar explicitamente “aplique o v4”, incluindo FIX-004.
