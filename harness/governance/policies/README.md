---
document_id: POLICIES-INDEX
document_scope: harness
primary_nature: Contexto
objective: Indexar regras agnosticas de ambiente, permissao e seguranca.
scope: Politicas compartilhadas por runtimes de agentes.
non_objectives: Nao definir requisito de produto, arquitetura ou preferencia pessoal.
owner: Plataforma de IA e DevOps
status: Active
version: 1.6
date: 2026-09-10
last_reviewed: 2026-09-29
keywords: settings, seguranca, permissoes, entrega-git, runtime, codex, claude-code, gemini, antigravity
related_files: ai-environment-policy.md, git-delivery-policy.md, documentation-governance.md, artifact-placement-policy.md, ../../adapters/README.md, ../decisions/ADR-0000-governanca-do-harness-documental.md
code_references: ../../../AGENTS.md, ../../../CLAUDE.md, ../../../GEMINI.md, ../../../.agents/rules/documentation-governance.md
principal_statement: Configuracoes inferiores nao podem enfraquecer politicas organizacionais ou ADRs aceitos.
---

# Policies

## Contrato da coleção

- Conteúdo aceito: política agnóstica de ambiente, permissão e segurança.
- Nomes: `<assunto>.md`.
- Estados: `Draft`, `Active`, `Deprecated`.
- Critério de granularidade: separar quando runtime, owner ou ciclo de revisão forem
  independentes.

## Índice

- [Política do ambiente e do assistente](ai-environment-policy.md) - matriz agnóstica de menor privilégio para ambiente e permissões.
- [Política de entrega Git](git-delivery-policy.md) - exige push de commits solicitados na branch de trabalho e protege a `main`.
- [Governança documental](documentation-governance.md) - contratos, índices e
  atualização de coleções. Mapeamentos específicos estão em
  [adapters/](../../adapters/README.md).
- [Artifact Placement](artifact-placement-policy.md) - rota humana dos artefatos;
  fonte executável em `harness/registry/artifact-routes.yaml`.
- [Agent Behavior](agent-behavior-policy.md) - comportamento operacional mínimo esperado.

## Restrictions

- [Agent Prohibitions](../restrictions/agent-prohibitions.md) - proibições universais.
- [Security Restrictions](../restrictions/security-restrictions.md) - restrições mínimas de segurança.
- [Filesystem Restrictions](../restrictions/filesystem-restrictions.md) - controles de filesystem.

## Precedence

```text
HARNESS RESTRICTIONS
        ↓
HARNESS POLICIES
        ↓
PROJECT STANDARDS
        ↓
AGENT DEFINITION
```

Restrições do harness não podem ser relaxadas pelo projeto; policies definem
comportamento operacional comum; standards especializam o projeto; e a definição
do agente especializa responsabilidades sem contrariar as camadas superiores.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.7 | 2026-09-30 | Adiciona a policy de comportamento do agente e as restrictions universais V7. |
| 1.6 | 2026-09-29 | Registra o mapeamento de .claude/settings.json e hooks determinísticos de enforcement. |
| 1.5 | 2026-09-23 | Torna obrigatório publicar na branch de trabalho definida todo commit solicitado. |
| 1.4 | 2026-09-23 | Indexa a política local de integração Git e proteção da `main`. |
| 1.3 | 2026-09-13 | Inclui mapeamentos Codex e Claude Code e alinha o indice a autonomia Git governada. |
| 1.2 | 2026-09-13 | Indexa a política de ativação explícita para entrega Git governada. |
| 1.1 | 2026-09-11 | Indexa o adaptador portátil dos runtimes Google. |
