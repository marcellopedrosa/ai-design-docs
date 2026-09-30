---
document_id: HARNESS-MIGRATION-V5
document_scope: project
primary_nature: Historico
objective: Registrar a migração do repositório mantenedor para o boundary .
scope: Estrutura, fontes canônicas, adapters e validações da migração .
non_objectives: Estabelecer política vigente ou transportar histórico para projetos adotantes.
owner: Mantenedores do harness
status: Final
version: 1.0
date: 2026-09-30
last_reviewed: 2026-09-30
keywords: harness, migração, , evidência
related_files: ../../../harness/governance/decisions/ADR-0001-boundary-harness-v5.md, ../../../harness/UPGRADING.md
code_references: ../../../harness/tooling/harness.mjs, ../../../harness/registry/
principal_statement: A fonte canônica do control plane reside em harness/; docs/ contém a documentação do projeto mantenedor.
---

# Migração  do repositório mantenedor

## Decision trace

| Origem  | Destino  | Classificação | Decisão |
| --- | --- | --- | --- |
| `contracts/`, `registry/`, `skills/`, `evals/`, `tooling/`, `examples/` | `harness/` | Harness-owned | Fonte canônica movida, com importações, CLI e CI atualizados. |
| `docs/agents/`, `docs/adrs/`, `docs/settings/`, `docs/templates/` | `harness/governance/`, `harness/adapters/`, `harness/templates/` | Harness-owned | Governança, políticas e templates passam a compor o control plane. |
| `.agents/`, `.claude/` | Mesmos diretórios | Runtime adapter/cache | Preservados; skills derivadas são sincronizadas da fonte canônica. |
| `docs/business/`, `docs/product_requirements/`, `docs/requirements/`, `docs/use_cases/` | `docs/product/` | Project-owned | Conteúdo do projeto mantenedor preservado; não é fonte de política do harness. |
| `docs/task_plans/`, `docs/reports/`, `docs/lessons_learned/`, `docs/pocs/` | `docs/delivery/` | Project-owned | Coleções reorganizadas; plano temporário de migração não integra o baseline. |
| `docs/backend/`, `docs/frontend/`, `docs/website/`, `docs/infra/` | Nenhum domínio fictício | Scaffold vazio | Apenas README de scaffold removidos; restauráveis pelo Git. |

## Verificação e limites

Baseline pré-migração: 123 testes aprovados e Doctor PASS. A validação final deve executar a suíte, Doctor, sincronização dos adapters em modo de verificação, validador documental, validação dos links e `git diff --check`. Este relatório documenta evidência temporal e não substitui a execução atual dos gates.

Não houve operação de rede, publicação nem acesso a segredos. O estado anterior é recuperável pelo Git; nenhuma substituição de conteúdo project-owned foi autorizada. Para projetos adotantes, copiar o control plane `harness/` e gerar adapters conforme [guia de upgrade](../../../harness/UPGRADING.md), sem copiar este histórico do mantenedor.
