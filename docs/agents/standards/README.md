---
document_id: STANDARDS-INDEX
primary_nature: Contexto
objective: Permitir selecao semantica de standards sem carregar a colecao inteira.
scope: Regras reutilizaveis do lifecycle, readiness e qualidade.
non_objectives: Nao duplicar o conteudo normativo dos standards.
owner: Arquitetura e Qualidade
status: Active
version: 1.0
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: standards, lifecycle, readiness, qualidade
related_files: software-engineering-lifecycle.md, implementation-readiness-standard.md, software-quality-standard.md
code_references: N/A - standards documentais.
principal_statement: Carregue somente os standards ativados pelo escopo, risco ou fonte superior da tarefa.
---

# Standards

## Contrato da coleção

- Conteúdo aceito: regra técnica reutilizável, verificável e com aplicabilidade
  explícita.
- Nomes: `<assunto>-standard.md`, salvo nomes estáveis do baseline.
- Estados: `Draft`, `Active`, `Deprecated`.
- Critério de granularidade: separar quando regra, owner, consumidores ou ciclo de
  revisão forem independentes.

## Catálogo

| Standard | Escopo | Consumidores | Status |
| --- | --- | --- | --- |
| [Software Engineering Lifecycle](software-engineering-lifecycle.md) | Sequência C.L.E.A.R. e gates | Todas as mudanças de software | Active |
| [Implementation Readiness](implementation-readiness-standard.md) | Gate anterior à escrita executável | Planejadores e executores | Active |
| [Software Quality](software-quality-standard.md) | Test, Quality e Security/Compliance gates | Implementadores e revisores | Active |

Standards de stack, acessibilidade, segurança, arquitetura, testes ou compliance
devem ser adicionados somente quando o projeto de destino ativar esses riscos.

