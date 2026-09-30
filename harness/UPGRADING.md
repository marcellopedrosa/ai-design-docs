---
document_id: HARNESS-UPGRADING
document_scope: harness
primary_nature: Contexto
objective: Orientar a adoção e a migração de layouts V4 para o boundary V5.
scope: Ownership, paths canônicos, adapters, Registry, validação e rollback.
non_objectives: Sobrescrever conteúdo project-owned, alterar semântica dos gates ou executar rede.
owner: Mantenedores do harness
status: Active
version: 1.0
date: 2026-09-30
last_reviewed: 2026-09-30
keywords: upgrade, v5, migração, compatibilidade, rollback
related_files: README.md, governance/decisions/ADR-0001-boundary-harness-v5.md, ../docs/README.md, ../docs/architecture/module-registry.md
code_references: tooling/harness.mjs, tooling/harness-doctor/index.mjs, tooling/adapters/sync-adapters.mjs
principal_statement: Migre fonte canônica e consumidores juntos; só remova paths V4 após Doctor, testes, links e adapters passarem.
---

# Atualização para o boundary V5

## Classificação e ownership

Classifique cada arquivo antes de mover: `ROOT-SHIM`, `PLATFORM-CONVENTION`,
`HARNESS-GOVERNANCE`, `HARNESS-CAPABILITY`, `RUNTIME-ADAPTER`,
`PROJECT-PRODUCT`, `PROJECT-ARCHITECTURE`, `PROJECT-DOMAIN`,
`PROJECT-DELIVERY`, `PROJECT-HISTORY`, `SOURCE-ONLY` ou
`AMBIGUOUS-BLOCKED`. Conteúdo project-owned nunca é sobrescrito
automaticamente. Em destino existente, compare, faça merge semântico, valide
e só então remova a duplicata. Ambiguidade material bloqueia a movimentação.

## Mapeamento principal

| V4 | V5 |
| --- | --- |
| `registry/`, `contracts/`, `skills/`, `evals/`, `tooling/`, `adapters/` | `harness/<mesmo-nome>/` |
| `docs/scripts/` | `harness/tooling/validators/` |
| `docs/agents/standards/` | `docs/agents/standards/` (V6: conteúdo do projeto, não da governança do harness) |
| `docs/agents/` e `docs/settings/` | `harness/governance/agents/`, `harness/governance/policies/` e `harness/adapters/` conforme ownership |
| `docs/adrs/` de governança do harness | `harness/governance/decisions/` |
| `docs/templates/` | `harness/templates/` |
| `docs/business/`, `docs/requirements/`, `docs/task_plans/` | `docs/product/` e `docs/delivery/` conforme natureza |

`.agents/skills/` e `.claude/skills/` continuam nas localizações exigidas
pelos runtimes, mas são derivados da fonte `harness/skills/`. Na raiz,
`AGENTS.md`, `CLAUDE.md` e `GEMINI.md` permanecem como shims. O manifesto
`harness.project.yaml` é opcional e pertence ao projeto adotante; o exemplo
fica em [examples/](examples/harness.project.example.yaml).

## Procedimento de migração

1. Registre branch, baseline de testes e Doctor, paths e falhas preexistentes.
2. Classifique cada grupo e registre destino, ação e reason code no relatório de
   migração do projeto.
3. Mova fontes canônicas e atualize, no mesmo lote, Registry, imports, scripts,
   CI, links, metadados e índices imediatos.
4. Sincronize adapters somente a partir das skills canônicas; não edite um
   runtime como fonte independente.
5. Reclassifique `docs/` sem criar domínios ou módulos fictícios. Registre
   módulos reais no [manifesto](../docs/architecture/module-registry.md).
6. Execute `node harness/tooling/harness.mjs doctor`, `check`, `eval`, `sync`,
   `node --test` e os gates de stack aplicáveis. Um `SKIP` não é PASS.
7. Remova paths legados apenas depois de provar que não há consumidor ativo.

## Rollback

Se um lote falhar, preserve o trabalho local e volte o lote inteiro para os
paths anteriores usando o inventário e a branch de trabalho. Não deixe Registry
V5 apontando para tooling V4 nem adapters de versões diferentes. Reexecute os
mesmos checks e registre causa, owner e condição de retomada. A migração não
autoriza force-push, produção, dados reais ou bypass de segurança.
