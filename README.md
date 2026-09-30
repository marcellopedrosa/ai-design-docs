---
document_id: REPOSITORY-ENTRY
document_scope: source-only
primary_nature: Contexto
objective: Apresentar o repositório-fonte do AI Engineering Harness.
scope: Identidade, navegação e comandos iniciais.
non_objectives: Duplicar governança, standards, skills ou documentação de produto.
owner: Mantenedores do harness
status: Active
version: 2.0.0
date: 2026-09-30
last_reviewed: 2026-09-30
keywords: repositório, harness, v5, documentação
related_files: AGENTS.md, CLAUDE.md, GEMINI.md, harness/README.md, docs/README.md
code_references: harness/tooling/harness.mjs, .github/workflows/harness.yml
principal_statement: Este repositório desenvolve o harness; o control plane está em harness/ e a documentação do projeto está em docs/.
---

# AI Engineering Harness

Este é o repositório-fonte de um harness portátil de engenharia assistida por
agentes. O [manual do harness](harness/README.md) descreve governança, skills,
contratos, adapters e comandos. A [documentação do projeto](docs/README.md)
registra requisitos, arquitetura, domínios e delivery deste repositório.

`harness/` é infraestrutura de engenharia, não documentação de negócio.
Arquivos da raiz exigidos por runtimes são pontos de descoberta; as fontes
canônicas ficam sob `harness/`. Para diagnosticar a integridade:

```bash
node harness/tooling/harness.mjs doctor
node --test
```

Para adotar ou atualizar o harness em outro projeto, consulte o
[guia de upgrade](harness/UPGRADING.md) e preserve os arquivos project-owned.
