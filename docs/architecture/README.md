---
document_id: ARCHITECTURE-INDEX
primary_nature: Contexto
objective: Indexar a arquitetura vigente e seus pontos de entrada.
scope: Modulos, dependencias, owners, interfaces e comandos do projeto de destino.
non_objectives: Nao decidir arquitetura futura nem substituir ADRs.
owner: Arquitetura
status: Active
version: 1.0
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: arquitetura, modulos, dependencias, manifesto
related_files: module-registry.md, ../adrs/README.md
code_references: N/A - manifesto ainda nao preenchido no baseline.
principal_statement: O manifesto e a rota canonica entre responsabilidade, path, owner, dependencia, instrucao e comando.
---

# Arquitetura

## Contrato da coleção

- Conteúdo aceito: estado arquitetural atual, módulos, fronteiras, dependências e
  pontos de entrada.
- Nomes: nomes descritivos em kebab-case; `module-registry.md` é reservado ao
  manifesto global.
- Estados: `Draft`, `Active`, `Deprecated`.
- Critério de granularidade: separar por visão ou boundary com audiência e ciclo de
  revisão próprios.

## Índice

- [Manifesto de módulos](module-registry.md)

