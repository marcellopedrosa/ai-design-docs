---
document_id: REQ-00003
primary_nature: Requisito
objective: Detectar entrypoint ativo ausente ou quebrado antes de declarar integridade estrutural.
scope: Doctor, ferramentas ativas do Registry e referencias de codigo internas seguras.
non_objectives: Executar builds, rede, ferramentas com efeitos colaterais ou suite completa no Doctor.
owner: Mantenedores do harness
status: Approved
version: 0.1
date: 2026-09-30
last_reviewed: 2026-09-30
keywords: doctor, tooling, registry, integridade
related_files: ../../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md
code_references: ../../../harness/tooling/harness-doctor/index.mjs, ../../../harness/tooling/harness-doctor/harness-doctor.test.mjs, ../../../harness/registry/tooling.yaml
principal_statement: O Doctor deve falhar quando uma ferramenta ativa declarada no Registry nao tiver entrypoint existente e sintaticamente valido.
---

# REQ-00003 — Integridade de tooling ativo

## Origem

FIX-003 do plano V4 fornecido pelo usuário; PRD não aplicável por ser integridade do harness. ADR-0000 Accepted.

## User Story View

Como operador, quero que o Doctor detecte ferramenta ativa quebrada, para não receber diagnóstico verde enganoso.

## Comportamento e regras

Ferramenta `active` requer entrypoint local existente, arquivo sintaticamente válido e referências de import relativas existentes. Ferramenta experimental/inativa não é controle obrigatório. A checagem não executa o entrypoint, não acessa rede nem altera arquivos.

## Acceptance Criteria

- AC-01 — Dada ferramenta ativa válida, o Doctor passa sem executar seu `main`.
- AC-02 — Dado entrypoint ativo ausente ou com sintaxe inválida, o Doctor falha com path e ID.
- AC-03 — Dada entrada experimental com arquivo ausente, o Doctor não a apresenta como controle ativo.
- AC-04 — Dado import relativo ausente em entrypoint ativo, o Doctor falha com referência identificável.

## Contrato, incertezas e aprovação

Contrato consumido: `harness/registry/tooling.yaml` v1; nenhum schema novo. Nenhuma assumption ou pergunta aberta. Aprovado pelo mantenedor em 2026-09-30 ao solicitar explicitamente “aplique o v4”, que inclui FIX-003; o aceite acima não amplia o plano.
