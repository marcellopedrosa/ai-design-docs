---
document_id: HARNESS-ENTRY
document_scope: harness
primary_nature: Contexto
objective: Ser a entrada canônica do control plane de engenharia assistida do harness.
scope: Governança, adapters, registry, contratos, skills, evals, tooling, templates e atualização.
non_objectives: Definir produto, stack, credenciais, comandos de projeto ou autorizar release.
owner: Mantenedores do harness
status: Active
version: 2.0.0
date: 2026-09-30
last_reviewed: 2026-09-30
keywords: harness, v5, governance, registry, skills, tooling, segurança
related_files: governance/README.md, governance/decisions/README.md, adapters/README.md, registry/README.md, contracts/README.md, skills/README.md, evals/README.md, tooling/README.md, tooling/validators/README.md, templates/README.md, examples/harness.project.example.yaml, UPGRADING.md, ../docs/README.md
code_references: tooling/harness.mjs, tooling/harness-doctor/index.mjs, tooling/adapters/sync-adapters.mjs, ../.agents/skills/, ../.claude/skills/
principal_statement: harness/ é a única fonte canônica do control plane; docs/ pertence à documentação do projeto e runtimes recebem adapters derivados.
---

# AI Engineering Harness

## Propósito e não objetivos

Este diretório contém o control plane portátil de engenharia assistida. Ele
coordena `governance → capability → tooling → evidence → gate → handoff` com
fontes auditáveis. Não implementa produto, não escolhe stack, não autoriza
produção ou release e não substitui decisões humanas.

## Bootstrap e descoberta

1. Leia [AGENTS.md](../AGENTS.md) e este índice; em Claude/Gemini leia também
   [CLAUDE.md](../CLAUDE.md) ou [GEMINI.md](../GEMINI.md), conforme o runtime.
2. Se existir `harness.project.yaml` na raiz, use-o como configuração do projeto;
   o [exemplo](examples/harness.project.example.yaml) não ativa capabilities.
3. Consulte [docs/README.md](../docs/README.md) para produto, módulos e owners.
4. Carregue o [manual de governança](governance/README.md), o
   [ADR aplicável](governance/decisions/README.md), o
   [Registry](registry/README.md) e somente os standards/skills exigidos pelo
   risco e pelo profile ativado. `AgentOrchestrator` é o único agente inicial.

## Estrutura e ownership

| Boundary | Conteúdo canônico |
| --- | --- |
| [governance/](governance/README.md) | Agentes de controle, policies e decisões do harness; standards locais ficam em `docs/agents/standards/` |
| [adapters/](adapters/README.md) | Mapeamentos para Codex, Claude Code e Google |
| [registry/](registry/README.md) | Inventário e paths ativos |
| [contracts/](contracts/README.md) | Schemas de mensagens, evidências, gates e handoffs |
| [skills/](skills/README.md) | Capability packages canônicos |
| [evals/](evals/README.md) | Casos H0/H1 e níveis futuros explícitos |
| [tooling/](tooling/README.md) | Doctor, sync, runner, contratos e [validadores](tooling/validators/README.md) |
| [templates/](templates/README.md) | Moldes documentais do harness |
| [examples/](examples/harness.project.example.yaml) | Perfis de exemplo, não configuração ativa |

`docs/` contém apenas a documentação deste projeto. `.agents/skills/` e
`.claude/skills/` são derivados de `harness/skills/`, não fontes independentes.
`.claude/settings.json` conserva as permissões `deny`/`ask` e o hook ativo
`guard-paths`; sua presença não comprova um handoff automático.

## Modelo operacional e gates

O lifecycle C.L.E.A.R. e o [Implementation Readiness](../docs/agents/standards/global/implementation-readiness-standard.md)
exigem `READY` antes da edição executável. O [quality-gate](skills/quality-gate/SKILL.md)
agrega A1 Test, A2 Quality e A3 Security/Compliance de modo independente;
[security-gate](skills/security-gate/SKILL.md) é somente executor especializado de
A3. Resultado `PASS` exige evidência atual; falha observada é `FAIL`, falta de
fonte, ferramenta ou autorização obrigatória é `BLOCKED`. O
[validador de rastreabilidade](tooling/contracts/trace.mjs) liga evidência, gate
e handoff; ele não executa os gates por conta própria.

Profiles específicos não integram o baseline: Spring MVC exige
`--profile java-spring`; Google Runtime exige `--profile google-runtime` e os
pacotes ativos devem ser declarados. Sem profile, o resultado é `SKIP`, não
`PASS` de cobertura. O H1 executa somente casos determinísticos elegíveis;
H2 retorna `NOT_IMPLEMENTED` e não usa H1 como substituto.

## Matriz de ativação

| Capability | Estado no baseline | Evidência |
| --- | --- | --- |
| `.agents/skills/` e `.claude/skills/` | Conformant quando pareados | `node harness/tooling/harness.mjs sync` |
| `governanca-documental`, `implementation-readiness`, `quality-gate` | Disponíveis; ativação pelo gatilho | [catálogo](skills/README.md) |
| `.claude/settings.json` | Configuração local efetiva; outros runtimes Not applicable quando ausentes | [adapter Claude](adapters/claude-code.md) |
| `.agents/rules/documentation-governance.md` | Adapter de workspace | [política canônica](governance/policies/documentation-governance.md) |
| `.gemini/settings.json` | Not applicable no baseline quando ausente | [adapter Google](adapters/google-gemini.md) |
| Validadores de projeto | Not applicable sem configuração explícita | [catálogo](tooling/validators/README.md) |

## Tooling e diagnóstico

Execute da raiz do repositório:

```bash
node harness/tooling/harness.mjs doctor
node harness/tooling/harness.mjs check
node harness/tooling/harness.mjs eval
node harness/tooling/harness.mjs sync
node --test
```

`sync` nessa fachada é somente verificação. Para sincronizar após editar uma
skill canônica, revise o diff e execute
`node harness/tooling/adapters/sync-adapters.mjs` sem `--prune`.
O Doctor valida integridade estrutural, não substitui A1/A2/A3 nem aprova
release. O validador documental ainda é `Partial` como gate universal para
projetos adotantes; sem wrapper local, reporte `Automação não configurada`.

## Atualização e limites de portabilidade

O [guia de upgrade](UPGRADING.md) descreve a migração V4→V5 e a separação entre
arquivos harness-owned e project-owned. Não sobrescreva documentação do projeto,
não mantenha cópias canônicas nos adapters e não interprete scaffolds como módulos
implementados. Git segue a [política local](governance/policies/git-delivery-policy.md),
com proteção da `main` e gates aplicáveis.
