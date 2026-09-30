---
document_id: HARNESS-SKILLS-INDEX
document_scope: harness
primary_nature: Contexto
objective: Catalogar as skills canônicas e seus adapters derivados.
scope: Skills do harness, gatilhos, owners, riscos e paths de runtime.
non_objectives: Duplicar os procedimentos de cada SKILL.md ou ativar capability sem contexto.
owner: Plataforma de IA
status: Active
version: 1.0
date: 2026-09-30
last_reviewed: 2026-09-30
keywords: skills, harness, codex, claude, google, registry
related_files: ../registry/skills.yaml, ../tooling/adapters/sync-adapters.mjs, ../governance/agents/AgentOrchestrator.md
code_references: ../../.agents/skills/, ../../.claude/skills/
principal_statement: harness/skills é a única fonte canônica; diretórios de runtime são derivados e pareados.
---

# Skills operacionais

Cada skill é um capability package em `harness/skills/<nome>/`, com `SKILL.md`,
`contract.yaml`, referências, fixtures e evals. O nome da pasta, o `name` do
frontmatter e a entrada no [Registry](../registry/skills.yaml) devem coincidir.

| Skill | Gatilho | Owner | Risco | Fonte | Codex / Google | Claude |
| --- | --- | --- | --- | --- | --- | --- |
| governanca-documental | Mudança ou revisão documental | Arquitetura e Documentação | R1 | [SKILL.md](governanca-documental/SKILL.md) | [.agents/skills/governanca-documental/SKILL.md](../../.agents/skills/governanca-documental/SKILL.md) | [.claude/skills/governanca-documental/SKILL.md](../../.claude/skills/governanca-documental/SKILL.md) |
| implementation-readiness | Antes de handoff ou edição executável | Arquitetura, Produto e Qualidade | R0 | [SKILL.md](implementation-readiness/SKILL.md) | [.agents/skills/implementation-readiness/SKILL.md](../../.agents/skills/implementation-readiness/SKILL.md) | [.claude/skills/implementation-readiness/SKILL.md](../../.claude/skills/implementation-readiness/SKILL.md) |
| quality-gate | Mudança de software, PR ou release; agrega A1/A2/A3 | Arquitetura e Qualidade | R2 | [SKILL.md](quality-gate/SKILL.md) | [.agents/skills/quality-gate/SKILL.md](../../.agents/skills/quality-gate/SKILL.md) | [.claude/skills/quality-gate/SKILL.md](../../.claude/skills/quality-gate/SKILL.md) |
| security-gate | A3 de aplicação web, API, auth/authz ou risco AppSec | Segurança e Engenharia | R2 | [SKILL.md](security-gate/SKILL.md) | [.agents/skills/security-gate/SKILL.md](../../.agents/skills/security-gate/SKILL.md) | [.claude/skills/security-gate/SKILL.md](../../.claude/skills/security-gate/SKILL.md) |
| git-delivery | Entrega Git solicitada conforme política local | Arquitetura e Qualidade | R3 | [SKILL.md](git-delivery/SKILL.md) | [.agents/skills/git-delivery/SKILL.md](../../.agents/skills/git-delivery/SKILL.md) | [.claude/skills/git-delivery/SKILL.md](../../.claude/skills/git-delivery/SKILL.md) |
| antigravity-permissions | Ajuste de confirmações no Antigravity | Plataforma de IA e Segurança | R1 | [SKILL.md](antigravity-permissions/SKILL.md) | [.agents/skills/antigravity-permissions/SKILL.md](../../.agents/skills/antigravity-permissions/SKILL.md) | [.claude/skills/antigravity-permissions/SKILL.md](../../.claude/skills/antigravity-permissions/SKILL.md) |

`.agents/skills/` é compartilhado por Codex, Gemini CLI e Antigravity;
`.claude/skills/` serve Claude Code. Não edite os adapters diretamente:
`node harness/tooling/adapters/sync-adapters.mjs --check` verifica paridade e
o comando sem `--check` sincroniza após revisão do diff.

O `security-gate` executa somente a verificação especializada A3 e retorna ao
`quality-gate`, que permanece agregador A1+A2+A3. `git-delivery` é opt-in e segue
[git-delivery-policy.md](../governance/policies/git-delivery-policy.md); push,
merge e proteção da `main` exigem os controles locais vigentes. A skill
`antigravity-permissions` pode simplificar operações rotineiras no escopo
`Project`, mas mantém confirmação `Ask` para remoção e comandos destrutivos.
