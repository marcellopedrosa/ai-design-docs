---
document_id: PROJECT-MANIFEST-EXAMPLES-INDEX
document_scope: harness
primary_nature: Contexto
objective: Indexar manifestos sintéticos  para adoção.
scope: Frontend, backend e fullstack.
non_objectives: Inferir stack ou owner de projeto real.
owner: Mantenedores do harness
status: Active
version: 1.0
date: 2026-09-30
keywords: manifest, frontend, backend, fullstack
related_files: ../README.md, frontend-project.yaml, backend-project.yaml, fullstack-project.yaml
code_references: ../../tooling/scaffold/index.mjs
principal_statement: Cada manifesto de exemplo precisa de revisão antes de se tornar contexto ativo de um projeto.
---

# Exemplos de manifesto

- [Frontend](frontend-project.yaml): frontend e security; exige agente frontend e standards correspondentes.
- [Backend](backend-project.yaml): backend e security; não exige artefatos frontend.
- [Fullstack](fullstack-project.yaml): combina frontend, backend e security sem duplicar a base.

São exemplos sintéticos. Um projeto adotante valida seu próprio contexto e owner
antes de copiar um manifesto para `docs/project-manifest.yaml`.
