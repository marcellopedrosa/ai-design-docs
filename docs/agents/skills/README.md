---
document_id: OPERATIONAL-SKILLS-INDEX
primary_nature: Contexto
objective: Catalogar skills operacionais instaladas nos runtimes suportados.
scope: Nome, gatilho, owner, estado e caminhos nativos das skills.
non_objectives: Nao armazenar SKILL.md nem duplicar seu procedimento.
owner: Plataforma de IA
status: Active
version: 1.3
date: 2026-09-10
last_reviewed: 2026-09-13
keywords: skills, catalogo, codex, claude-code, gemini-cli, antigravity
related_files: ../AgentOrchestrator.md, ../standards/README.md, ../../adrs/ADR-0000-governanca-do-harness-documental.md, ../../settings/google-gemini.md, ../../templates/TPL-00009-skill-operacional.md
code_references: ../../../.agents/skills/, ../../../.claude/skills/, ../../../.agents/rules/documentation-governance.md
principal_statement: Cada skill catalogada resolve para um descritor nativo e semanticamente equivalente em todo runtime suportado.
---

# Skills operacionais

## Contrato da coleção

Este diretório contém somente o catálogo. Skills instaláveis residem nos caminhos
nativos do runtime. Nome do diretório, `name` do frontmatter e nome do catálogo
devem coincidir.

## Catálogo

| Skill | Gatilho | Owner | Status | Codex / Google | Claude Code |
| --- | --- | --- | --- | --- | --- |
| governanca-documental | Mudança ou revisão documental | Arquitetura e Documentação | Active | [SKILL.md](../../../.agents/skills/governanca-documental/SKILL.md) | [SKILL.md](../../../.claude/skills/governanca-documental/SKILL.md) |
| implementation-readiness | Antes de handoff ou edição executável | Arquitetura, Produto e Qualidade | Active | [SKILL.md](../../../.agents/skills/implementation-readiness/SKILL.md) | [SKILL.md](../../../.claude/skills/implementation-readiness/SKILL.md) |
| quality-gate | Mudança de software, PR ou release | Arquitetura e Qualidade | Active | [SKILL.md](../../../.agents/skills/quality-gate/SKILL.md) | [SKILL.md](../../../.claude/skills/quality-gate/SKILL.md) |
| git-delivery | Commit ou publicação solicitados, após adoção explícita | Arquitetura e Qualidade | Active, opt-in | [SKILL.md](../../../.agents/skills/git-delivery/SKILL.md) | [SKILL.md](../../../.claude/skills/git-delivery/SKILL.md) |

Skills adicionais exigem procedimento reutilizável real, owner, descrição
discriminante, limites de segurança e entrada neste catálogo.

`.agents/skills/` é o caminho interoperável compartilhado por Codex, Gemini CLI e
Antigravity. Não crie `.gemini/skills/` com o mesmo conteúdo.

O [AgentOrchestrator](../AgentOrchestrator.md) seleciona e aciona essas skills; a
skill executa um procedimento e não cria um novo papel de agente.

`git-delivery` é distribuída para facilitar uma política local verificável, mas não
altera o bloqueio Git do baseline. Ela só é acionável depois que o projeto adotante
registrar sua convenção, enforcement e autoridade no ADR-0000 e nos adaptadores.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.3 | 2026-09-13 | Cataloga `git-delivery` como capacidade opt-in de entrega governada. |
| 1.2 | 2026-09-11 | Relaciona o catálogo ao AgentOrchestrator sem transformar skills em agentes. |
| 1.1 | 2026-09-11 | Registra o reuso das skills `.agents` pelos runtimes Google. |
