---
document_id: DOCUMENTATION-GOVERNANCE-POLICY
document_scope: harness
primary_nature: Regra
objective: Preservar a fonte documental canônica e seus índices durante mudanças.
scope: Documentos em harness/ e docs/, metadados, links e adapters derivados.
non_objectives: Aprovar produto, criar regras de stack ou enfraquecer ADRs aceitos.
owner: Arquitetura e Documentação
status: Active
version: 1.0
date: 2026-09-30
last_reviewed: 2026-09-30
keywords: documentação, governança, índices, links
related_files: README.md, ../decisions/ADR-0000-governanca-do-harness-documental.md, ../../tooling/validators/README.md
code_references: ../../../AGENTS.md, ../../../.agents/rules/documentation-governance.md
principal_statement: Um documento criado, movido ou removido atualiza seu índice imediato e mantém links e metadados válidos.
---

# Governança documental

O [ADR-0000](../decisions/ADR-0000-governanca-do-harness-documental.md)
define taxonomia, contrato mínimo e precedência. Toda mudança em documento ou
coleção atualiza o README imediato, preserva uma única fonte canônica e valida
links locais e metadados. `harness/` guarda governança do control plane; `docs/`
guarda documentação do projeto. `.agents/` e `.claude/` são projeções de runtime,
não regras independentes.

Execute `node harness/tooling/validators/validate-documentation-governance.mjs --root .`
e registre lacunas de automação como `Automação não configurada`; inspeção
subjetiva não equivale a PASS automático.
