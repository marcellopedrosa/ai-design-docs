---
document_id: HARNESS-SCAFFOLD
document_scope: harness
primary_nature: Contexto
objective: Explicar o scaffold  seguro e seus modos de execução.
scope: Manifesto, profiles, routes, templates e relatório de artefatos.
non_objectives: Preencher conteúdo técnico, sobrescrever arquivos ou migrar paths legados automaticamente.
owner: Mantenedores do harness
status: Active
version: 1.0
date: 2026-09-30
last_reviewed: 2026-09-30
keywords: , scaffold, inspect, create, check
related_files: ../README.md, ../../registry/README.md, ../../templates/README.md, ../../governance/policies/artifact-placement-policy.md
code_references: index.mjs, engine.mjs, yaml.mjs, scaffold.test.mjs
principal_statement: O scaffold valida a cadeia , cria somente arquivos ausentes e devolve migração legada para revisão humana.
---

# Scaffold

```bash
node harness/tooling/harness.mjs scaffold --inspect
node harness/tooling/harness.mjs scaffold --check
node harness/tooling/harness.mjs scaffold --create
```

`--inspect` é somente leitura, mesmo sem manifesto; relata paths existentes e
candidatos legados. Na ausência de manifesto, sugere profiles/agentes apenas como
candidatos com revisão humana obrigatória. `--check` lê `docs/project-manifest.yaml` e valida schemas,
profiles, herança, routes, templates e artefatos esperados. Retorna 0 quando
todos existem, 1 para artefato ausente/legado ou configuração inválida, e 2
quando o manifesto não existe. `--create` escreve somente arquivos ausentes,
usando criação exclusiva (`wx`); nunca atualiza conteúdo existente nem move
arquivo legado. `--json` fornece relatório estruturado em todos os modos.

`CREATE` indica artefato faltante, `KEEP` indica arquivo existente e
`LEGACY_LOCATION` exige decisão humana antes de uma migração. Após criar um
arquivo, a squad deve preencher o conteúdo Draft e atualizar o README da coleção
imediata. O scaffold não declara o conteúdo aprovado e não edita índices
existentes, para respeitar a regra de não sobrescrita.
Um standard exigido por profile também deve estar catalogado em
`harness/registry/standards.yaml`; o profile não substitui esse inventário.

O manifesto  é opcional para projetos legados: o Doctor emite `WARN` quando
ausente. `harness.project.yaml` continua sendo o contrato  separado para
configuração do harness; não substitui `docs/project-manifest.yaml`.
