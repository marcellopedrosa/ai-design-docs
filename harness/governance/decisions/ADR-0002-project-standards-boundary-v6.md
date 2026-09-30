---
document_id: ADR-0002
document_scope: harness
primary_nature: Decisao
objective: Separar regras de operação do harness do conteúdo dos standards do projeto.
scope: Ownership e localização de agentes e standards locais na evolução .
non_objectives: Enfraquecer readiness, quality ou security gates; criar stack ou conteúdo técnico não aprovado.
owner: Mantenedores do harness
status: Accepted
version: 1.0
date: 2026-09-30
last_reviewed: 2026-09-30
keywords: , ownership, standards, projeto, harness
related_files: README.md, ADR-0000-governanca-do-harness-documental.md, ADR-0001-boundary-harness-v5.md, ../../../docs/agents/README.md, ../../../docs/agents/standards/README.md
code_references: ../../registry/standards.yaml, ../../tooling/validators/validate-documentation-governance.mjs
principal_statement: O harness define metamodelo, descoberta e gates; o projeto assume o conteúdo e a vigência dos seus standards e agentes especializados.
---

# ADR-0002 — Boundary dos standards do projeto na

## Contexto

O ADR-0001 separou `harness/` de `docs/`, mas a migração  classificou os
standards globais do projeto como `harness/governance/standards/`. O plano  e a
instrução explícita do mantenedor esclarecem que o harness determina estrutura,
descoberta e roteamento; a squad mantém o conteúdo final de seus standards.

## Decisão

- Mover os cinco standards globais existentes para `docs/agents/standards/global/`
  e seu catálogo para `docs/agents/standards/README.md`, sem descartar conteúdo.
- Manter `AgentOrchestrator`, `GateEvaluator`, as políticas gerais e os ADRs do
  harness em `harness/governance/`.
- Fazer o Registry apontar para os caminhos reais do projeto. A localização não
  transforma um standard em política intrínseca do harness.
- Exigir índices e links locais coerentes; nenhum agente de stack, threshold ou
  standard condicional é presumido apenas por aparecer como exemplo no catálogo.

Esta decisão especializa somente as cláusulas de *path* e ownership dos ADRs
0000 e 0001. Precedência, readiness, A1/A2/A3, proteção de dados e permissões
continuam vigentes. A implantação completa da cadeia  de manifesto, profiles,
routes, templates e scaffold é uma entrega separada; este ADR não a declara pronta.

## Alternativas e consequências

Manter os standards em `harness/governance/` preservaria links , mas confundiria
responsabilidade pelo conteúdo local. Duplicá-los criaria duas fontes normativas.
O movimento único preserva conteúdo e exige atualização conjunta de Registry,
índices, links, validadores e adapters derivados.

## Aprovação

Accepted por instrução explícita do mantenedor em 2026-09-30 para mover os
documentos erroneamente classificados como escopo do harness conforme o plano .
