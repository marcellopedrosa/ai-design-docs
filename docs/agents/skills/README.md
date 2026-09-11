---
document_id: OPERATIONAL-SKILLS-INDEX
primary_nature: Contexto
objective: Catalogar skills operacionais instaladas nos runtimes suportados.
scope: Nome, gatilho, owner, estado e caminhos nativos das skills.
non_objectives: Nao armazenar SKILL.md nem duplicar seu procedimento.
owner: Plataforma de IA
status: Active
version: 1.0
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: skills, catalogo, codex, claude-code
related_files: ../../adrs/ADR-0000-governanca-do-harness-documental.md, ../../templates/TPL-00009-skill-operacional.md
code_references: ../../../.agents/skills/, ../../../.claude/skills/
principal_statement: Cada skill catalogada resolve para um descritor nativo e semanticamente equivalente em todo runtime suportado.
---

# Skills operacionais

## Contrato da coleção

Este diretório contém somente o catálogo. Skills instaláveis residem nos caminhos
nativos do runtime. Nome do diretório, `name` do frontmatter e nome do catálogo
devem coincidir.

## Catálogo

| Skill | Gatilho | Owner | Status | Codex | Claude Code |
| --- | --- | --- | --- | --- | --- |
| governanca-documental | Mudança ou revisão documental | Arquitetura e Documentação | Active | [SKILL.md](../../../.agents/skills/governanca-documental/SKILL.md) | [SKILL.md](../../../.claude/skills/governanca-documental/SKILL.md) |
| implementation-readiness | Antes de handoff ou edição executável | Arquitetura, Produto e Qualidade | Active | [SKILL.md](../../../.agents/skills/implementation-readiness/SKILL.md) | [SKILL.md](../../../.claude/skills/implementation-readiness/SKILL.md) |
| quality-gate | Mudança de software, PR ou release | Arquitetura e Qualidade | Active | [SKILL.md](../../../.agents/skills/quality-gate/SKILL.md) | [SKILL.md](../../../.claude/skills/quality-gate/SKILL.md) |

Skills adicionais exigem procedimento reutilizável real, owner, descrição
discriminante, limites de segurança e entrada neste catálogo.

