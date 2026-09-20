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
related_files: settings.md, ../ai/README.md, ../agents/skills/README.md
code_references: ../../CLAUDE.md, ../../.claude/skills/governanca-documental/SKILL.md, ../../.claude/skills/implementation-readiness/SKILL.md, ../../.claude/skills/quality-gate/SKILL.md
principal_statement: O Claude Code usa adaptadores equivalentes aos do harness e so entrega Git depois de certificacao integral quando essa capacidade estiver adotada.
---

# Mapeamento do Claude Code

## Configuracao efetiva

- O adaptador global versionado e `CLAUDE.md` na raiz.
- Adaptadores locais devem existir apenas quando houver especializacao de pacote e
  devem permanecer semanticamente equivalentes ao respectivo `AGENTS.md`.
- `CLAUDE.local.md` e settings locais sao pessoais e devem ficar fora do Git.
- Skills compartilhadas do Claude Code usam `.claude/skills/<nome>/SKILL.md` e
  espelham as capacidades adotadas em `.agents/skills/`.

## Precedencia e validacao

Imports locais podem reutilizar o adaptador do mesmo pacote, mas nao devem carregar
documentacao extensa por padrao. Mudanca de adaptador deve reexecutar o validador
documental local e confirmar a cadeia em uma sessao nova.

A configuracao efetiva deve permitir somente operacoes Git expressamente adotadas
pelo projeto: branch/commit no escopo e push da branch certificada. Integracao,
alteracao de historico, branches protegidas, credenciais e remotes continuam
negados conforme a politica do harness.

## Change log

| Versao | Data | Mudanca |
| --- | --- | --- |
| 1.0 | 2026-09-13 | Adiciona mapeamento portavel do Claude Code para o harness agnostico. |
