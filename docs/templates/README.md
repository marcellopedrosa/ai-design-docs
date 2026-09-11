---
document_id: TEMPLATES-INDEX
primary_nature: Contexto
objective: Catalogar os moldes dos tipos documentais recorrentes.
scope: Estruturas AI-safe para criar artefatos sem inventar conteudo ou aprovacao.
non_objectives: Nao fornecer requisito, decisao, evidencia, owner ou status concreto.
owner: Arquitetura e Documentacao
status: Active
version: 1.0
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: templates, documentos, prd, requirement, adr, planos
related_files: ../adrs/ADR-0000-governanca-do-harness-documental.md
code_references: N/A - catalogo documental.
principal_statement: Templates padronizam forma e bloqueiam invencao; cada instancia exige fatos, owners e approvals reais.
---

# Templates

## Contrato da coleção

- Conteúdo aceito: estrutura e instruções de preenchimento de um tipo documental.
- Nomes: `TPL-NNNNN-short-title.md`.
- Estados: `Draft`, `Active`, `Deprecated`.
- Critério de granularidade: um tipo e contrato de criação por template.

Marcadores entre `{{chaves}}` devem ser substituídos por dados verificáveis na
instância. Valor desconhecido vira Open Question; nunca invente evidência, owner,
target, aprovação ou decisão para remover marcador.

## Índice

| ID | Template | Uso |
| --- | --- | --- |
| TPL-00001 | [PRD](TPL-00001-prd.md) | Definição de iniciativa e Product Definition Gate |
| TPL-00002 | [Requirement](TPL-00002-requirement.md) | Comportamento e acceptance criteria |
| TPL-00003 | [Use Case](TPL-00003-use-case.md) | Fluxo complexo ligado ao requirement |
| TPL-00004 | [ADR](TPL-00004-adr.md) | Decisão arquitetural |
| TPL-00005 | [Task Plan](TPL-00005-task-plan.md) | Coordenação e decomposição semântica |
| TPL-00006 | [Implementation Plan](TPL-00006-implementation-plan.md) | Unidade técnica executável |
| TPL-00007 | [Lesson Learned](TPL-00007-lesson-learned.md) | Aprendizado transferível |
| TPL-00008 | [Report](TPL-00008-report.md) | Evidência histórica |
| TPL-00009 | [Operational Skill](TPL-00009-skill-operacional.md) | Procedimento de runtime |
| TPL-00010 | [Collection README](TPL-00010-collection-readme.md) | Contrato e índice de coleção |
| TPL-00011 | [Agent](TPL-00011-agent.md) | Papel especializado |
| TPL-00012 | [Interface Contract](TPL-00012-interface-contract.md) | Contrato versionado entre boundaries |

