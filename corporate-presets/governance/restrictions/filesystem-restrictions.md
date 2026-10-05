---
document_id: FILESYSTEM-RESTRICTIONS
document_scope: harness
primary_nature: Restrição
objective: Definir controles mínimos para operações de filesystem.
scope: Agentes e tooling do harness.
owner: Mantenedores do harness
status: Active
version: 1.0
date: 2026-09-30
last_reviewed: 2026-09-30
keywords: filesystem, paths, scaffold, deletion, traversal
related_files: ../README.md, ../policies/artifact-placement-policy.md
code_references: ../../tooling/scaffold/engine.mjs, ../../tooling/hooks/guard-paths.mjs
principal_statement: Operações de filesystem devem permanecer dentro da raiz autorizada e preservar arquivos existentes.
---

# Filesystem Restrictions

## Purpose

Definir restrições para operações de filesystem realizadas por agentes e tooling do harness.

## Existing Files

O agente ou tooling não deve:

- sobrescrever arquivo existente por padrão;
- substituir conteúdo sem necessidade explícita;
- apagar arquivo existente para recriá-lo;
- renomear arquivo sem avaliar referências existentes.

## File Creation

Arquivos novos devem:

1. utilizar uma rota registrada quando aplicável;
2. permanecer dentro da raiz do projeto;
3. utilizar template registrado quando houver;
4. evitar duplicação de artefato existente.

## Directory Creation

Diretórios devem ser criados somente quando forem necessários.

O harness não deve criar antecipadamente diretórios como:

- frontend;
- backend;
- mobile;
- infrastructure;
- data;

quando o projeto não utilizar esses contextos.

## Path Safety

Nenhuma operação deve:

- permitir path traversal;
- escrever fora da raiz autorizada;
- utilizar path absoluto fornecido por conteúdo não confiável;
- aceitar `..` como scope ou artifact name.

## File Movement

Scaffold não deve mover automaticamente arquivos legados.

Quando um arquivo estiver em localização antiga, deve retornar:

`LEGACY_LOCATION`

e informar:

- caminho atual;
- caminho esperado;
- ação recomendada.

## Deletion

Nenhum arquivo deve ser removido automaticamente por scaffold, doctor ou validator.

Remoção deve ser uma operação explícita.
