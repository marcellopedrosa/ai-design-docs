---
document_id: DOCS-INDEX
document_scope: project
primary_nature: Contexto
objective: Mapear somente a documentação do projeto mantida em docs/.
scope: Produto, arquitetura, domínios reais, contratos, compliance, análise, delivery e onboarding.
non_objectives: Duplicar as regras, skills, adapters, templates ou tooling do harness.
owner: Arquitetura e owners das coleções
status: Active
version: 2.0
date: 2026-09-30
last_reviewed: 2026-09-30
keywords: projeto, produto, documentação, índice
related_files: ../harness/README.md, project-manifest.yaml, agents/README.md, product/README.md, architecture/README.md, domains/README.md, contracts/README.md, compliance/README.md, analysis/README.md, delivery/README.md, onboarding/README.md
code_references: ../AGENTS.md, ../harness/tooling/validators/validate-documentation-governance.mjs
principal_statement: docs/ pertence à documentação do projeto; a governança e o tooling do harness pertencem a harness/.
---

# Documentação do projeto

O [manifesto ](project-manifest.yaml) declara o contexto e os profiles deste
projeto. Ele não contém regras de stack ou critérios técnicos; esses pertencem
aos standards e à arquitetura locais.

Esta árvore contém a documentação do projeto-fonte, inclusive seus standards.
O metamodelo, as políticas e as ferramentas de engenharia assistida estão no
[harness](../harness/README.md).

| Coleção | Finalidade |
| --- | --- |
| [Agentes e standards](agents/README.md) | Definições e regras sob responsabilidade do projeto |
| [Produto](product/README.md) | Negócio, PRDs, requisitos, use cases e capabilities de negócio |
| [Arquitetura](architecture/README.md) | Módulos, owners e decisões do projeto |
| [Domínios](domains/README.md) | Apenas domínios realmente implementados |
| [Contratos](contracts/README.md) | Interfaces do produto; schemas do harness ficam em `harness/contracts/` |
| [Compliance](compliance/README.md) | Obrigações específicas do projeto |
| [Análises](analysis/README.md) | Análises atuais quando houver |
| [Delivery](delivery/README.md) | Planos ativos, relatórios e lições do projeto |
| [Onboarding](onboarding/README.md) | Entrada de pessoas no projeto |

Cada coleção indexa seus próprios artefatos. Nenhum módulo de aplicação é
presumido pelo baseline; veja o [manifesto de módulos](architecture/module-registry.md).
