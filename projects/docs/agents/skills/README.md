---
document_id: OPERATIONAL-SKILLS-INDEX
primary_nature: Contexto
objective: Catalogar skills operacionais instaladas nos runtimes suportados.
scope: Nome, gatilho, owner, estado e caminhos nativos das skills.
non_objectives: Nao armazenar SKILL.md nem duplicar seu procedimento.
owner: Plataforma de IA
status: Active
version: 1.8
date: 2026-09-10
last_reviewed: 2026-09-28
keywords: skills, catalogo, codex, claude-code, gemini-cli, antigravity, appsec, security, permissoes, registry, canonica
related_files: ../AgentOrchestrator.md, ../standards/README.md, ../../../../corporate-presets/skills/
code_references: ../../../../corporate-presets/skills/, ../../../.agents/skills/, ../../../.claude/skills/
principal_statement: Cada skill catalogada resolve para um descritor nativo e semanticamente equivalente em todo runtime suportado.
---

# Skills operacionais

## Contrato da coleção

- Nomes: `<skill-name>/SKILL.md` nos diretórios nativos documentados.
- Estados: `Draft`, `Active`, `Deprecated`; `opt-in` descreve ativação, não um estado.
- Critério de granularidade: separar capacidades com gatilhos, owner ou handoff
  independentes.

Este diretório contém somente o catálogo. A fonte canônica única de evolução de
skills reside em `corporate-presets/skills/<skill-name>/`,
sendo sincronizada determinística e automaticamente para os diretórios nativos
`.agents/skills/` e `.claude/skills/` pelo sincronizador `tooling/adapters/sync-adapters.mjs`.
Nome do diretório, `name` do frontmatter e nome do catálogo devem coincidir.

## Catálogo

| Skill | Gatilho | Owner | Status | Codex / Google | Claude Code |
| --- | --- | --- | --- | --- | --- |
| documentation-governance | Mudança ou revisão documental | Arquitetura e Documentação | Active | [SKILL.md](../../../../corporate-presets/skills/documentation-governance/SKILL.md) | [SKILL.md](../../../../corporate-presets/skills/documentation-governance/SKILL.md) |
| implementation-readiness | Antes de handoff ou edição executável | Arquitetura, Produto e Qualidade | Active | [SKILL.md](../../../.agents/skills/implementation-readiness/SKILL.md) | [SKILL.md](../../../.claude/skills/implementation-readiness/SKILL.md) |
| security-gate | A3 de aplicação web, API, auth/authz, dado sensível ou risco AppSec | Segurança e Engenharia | Active | [SKILL.md](../../../../corporate-presets/skills/security-gate/SKILL.md) | [SKILL.md](../../../../corporate-presets/skills/security-gate/SKILL.md) |
| git-delivery | Commit, publicação ou integração solicitados conforme política local | Arquitetura e Qualidade | Active | [SKILL.md](../../../../corporate-presets/skills/git-delivery/SKILL.md) | [SKILL.md](../../../../corporate-presets/skills/git-delivery/SKILL.md) |

Skills adicionais exigem procedimento reutilizável real, owner, descrição
discriminante, limites de segurança e entrada neste catálogo e no registry machine-readable.

`.agents/skills/` é o caminho interoperável compartilhado por Codex, Gemini CLI e
Antigravity. Não crie `.gemini/skills/` com o mesmo conteúdo.

O agente coordenador seleciona e aciona essas skills; a
skill executa um procedimento e não cria um novo papel de agente.

`security-gate` é o subgate/executor especializado do A3 Security/Compliance. Seu
resultado retorna ao `quality-gate`; apesar do nome, ele não é um Assurance Gate
paralelo e não agrega A1/A2.

`antigravity-permissions` orienta a configuração de bypass de operações de rotina
(`read_file`, `list_directory`, `command`) no escopo exclusivo `Project` do
Antigravity no VS Code, preservando confirmação obrigatória (`Ask`) para remoção e
comandos destrutivos conforme `settings/google-gemini.md`.

`git-delivery` segue a política local registrada em
`corporate-presets/policies/git-delivery-policy.md`. Cada projeto define
suas convenções e proteções; branches de trabalho podem ser integradas sem escrita
direta ou force-push na branch principal.

Todo commit solicitado como entrega deve ser seguido obrigatoriamente de push para
a branch de trabalho definida. Falhas de publicação são reportadas como `BLOCKED`
sem mudar o destino ou alterar o remote.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.8 | 2026-09-28 | Conecta o catálogo à fonte canônica neutra em skills/ e ao registry machine-readable. |
| 1.7 | 2026-09-28 | Registra a skill antigravity-permissions para controle de permissões no escopo de projeto. |
| 1.6 | 2026-09-28 | Adiciona `security-gate` como executor especializado subordinado ao A3 do `quality-gate`. |
| 1.5 | 2026-09-28 | Registra a revisão AppSec especializada do A3, pareada nos runtimes. |
| 1.4 | 2026-09-23 | Esclarece que commit solicitado exige push da branch de trabalho definida. |
| 1.3 | 2026-09-13 | Cataloga `git-delivery` como capacidade opt-in de entrega governada. |
| 1.2 | 2026-09-11 | Relaciona o catálogo ao AgentOrchestrator sem transformar skills em agentes. |
| 1.1 | 2026-09-11 | Registra o reuso das skills `.agents` pelos runtimes Google. |
