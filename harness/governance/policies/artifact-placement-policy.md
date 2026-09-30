---
document_id: ARTIFACT-PLACEMENT-POLICY
document_scope: harness
primary_nature: Regra
objective: Explicar a localização dos artefatos  sem duplicar a fonte executável.
scope: Agentes, standards, arquitetura e requisitos de projetos adotantes.
non_objectives: Definir conteúdo técnico da squad ou realizar migração destrutiva.
owner: Mantenedores do harness
status: Active
version: 1.0
date: 2026-09-30
last_reviewed: 2026-09-30
keywords: placement, routing, artifact,
related_files: README.md, ../../registry/README.md, ../../templates/README.md, ../decisions/ADR-0002-project-standards-boundary-v6.md
code_references: ../../registry/artifact-routes.yaml, ../../tooling/scaffold/index.mjs
principal_statement: O Registry define paths executáveis; esta política apenas explica seu uso humano e proíbe sobrescrita automática.
---

# Artifact Placement Policy

## Purpose

Definir as regras de localização dos artefatos produzidos ou utilizados pelo harness.

## Canonical Routing Source

A fonte executável de roteamento é:

`harness/registry/artifact-routes.yaml`

Este documento existe para orientação humana e não deve ser utilizado como parser de configuração.

## Placement Rules

| Tipo | Destino padrão |
| --- | --- |
| Agent Definition | `docs/agents/{name}-agent.md` |
| Project Standard | `docs/agents/standards/{scope}/{name}.md` |
| Architecture | `docs/architecture/{name}.md` |
| Requirement | `docs/product/requirements/REQ-NNNNN-{nome}.md` |
| Harness Governance | `harness/governance/` |
| Harness Registry | `harness/registry/` |
| Harness Templates | `harness/templates/` |
| Harness Tooling | `harness/tooling/` |

## Rules

1. Artefatos de projeto devem permanecer em `docs/`.
2. Regras do próprio harness devem permanecer em `harness/`.
3. Nenhum runtime deve inventar paths próprios.
4. Nenhum runtime deve criar artefatos fora das rotas registradas.
5. Artefatos existentes não devem ser movidos automaticamente durante scaffold.

O requisito usa a coleção canônica  `docs/product/requirements/`, em vez de abrir
um segundo índice em `docs/requirements/`. A fonte executável destas rotas é
[`artifact-routes.yaml`](../../registry/artifact-routes.yaml); runtimes não devem
parsear este Markdown para decidir paths.

O scaffold cria somente arquivos ausentes, nunca sobrescreve por padrão e não
move arquivos legados automaticamente. `LEGACY_LOCATION` exige revisão humana.
Templates determinam somente forma; a squad define conteúdo, owner e aprovação.
