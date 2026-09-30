---
document_id: SETTINGS-CLAUDE-CODE
primary_nature: Regra
objective: Mapear a politica agnostica do harness para descoberta e adaptadores versionados do Claude Code.
scope: CLAUDE.md raiz e locais, imports, configuracao compartilhada e catalogo de skills Claude Code.
non_objectives: Nao duplicar ADRs, standards, requisitos nem versionar preferencias pessoais ou segredos.
owner: Plataforma de IA e DevOps
status: Active
date: 2026-09-13
version: 1.0
keywords: claude-code, CLAUDE.md, imports, settings, skills, quality-metrics, git, push
related_files: ../governance/policies/ai-environment-policy.md, ../governance/README.md, ../skills/README.md
code_references: ../../CLAUDE.md, ../../.claude/settings.json, ../../.claude/skills/governanca-documental/SKILL.md, ../../.claude/skills/implementation-readiness/SKILL.md, ../../.claude/skills/quality-gate/SKILL.md, ../tooling/hooks/
principal_statement: O Claude Code usa adaptadores equivalentes aos do harness e so entrega Git depois de certificacao integral quando essa capacidade estiver adotada.
---

# Mapeamento do Claude Code

## Configuracao efetiva

- O adaptador global versionado e `CLAUDE.md` na raiz (importando `@AGENTS.md`).
- A configuracao compartilhada versionada reside em `.claude/settings.json`, impondo politicas conservadoras de permissao (`deny` para segredos `.env*` e escritas destrutivas na `main`) e o hook de pre-edicao `guard-paths` em `harness/tooling/hooks/`. A obrigacao de handoff e documental; nao ha enforcement automatico de parada sem evidencia deterministica.
- Adaptadores locais devem existir apenas quando houver especializacao de pacote e
  devem permanecer semanticamente equivalentes ao respectivo `AGENTS.md`.
- `CLAUDE.local.md` e settings locais (`.claude/settings.local.json`) sao pessoais e devem ficar fora do Git.
- Skills compartilhadas do Claude Code usam `.claude/skills/<nome>/SKILL.md` e
  espelham as capacidades adotadas em `.agents/skills/`.

## Precedencia e validacao

Imports locais podem reutilizar o adaptador do mesmo pacote, mas nao devem carregar
documentacao extensa por padrao. Mudanca de adaptador deve reexecutar o validador
documental local e confirmar a cadeia em uma sessao nova.

A configuracao efetiva deve permitir as operacoes Git descritas em
[`git-delivery.md`](../governance/policies/git-delivery-policy.md). Trabalho em branches separadas e sua
integracao por PR, merge, rebase ou push sao permitidos conforme os gates. Escrita
direta e force-push na branch principal sao proibidos; credenciais nao podem ser
acessadas.

## Change log

| Versao | Data | Mudanca |
| --- | --- | --- |
| 1.2 | 2026-09-30 | Remove o falso enforcement de handoff; mantem o hook de pre-edicao. |
| 1.1 | 2026-09-29 | Materializa .claude/settings.json com permissoes conservadoras e hooks deterministicos. |
| 1.0 | 2026-09-13 | Adiciona mapeamento portavel do Claude Code para o harness agnostico. |
