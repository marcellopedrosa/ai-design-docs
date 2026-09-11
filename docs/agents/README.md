---
document_id: AGENTS-INDEX
primary_nature: Contexto
objective: Catalogar papeis de agentes e suas fontes operacionais.
scope: Agentes ativos, gatilhos, owners, standards, skills e handoffs.
non_objectives: Nao registrar personas de produto nem duplicar instrucoes dos runtimes.
owner: Arquitetura e Plataforma de IA
status: Active
version: 1.0
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: agentes, papeis, catalogo, handoff
related_files: skills/README.md, standards/README.md, ../templates/TPL-00009-skill-operacional.md
code_references: ../../AGENTS.md, ../../CLAUDE.md
principal_statement: Papeis especializados somente sao criados quando possuem responsabilidade, gatilho e handoff independentes.
---

# Agentes

## Contrato da coleção

- Conteúdo aceito: papel, gatilhos, entradas, saídas, limites, tools e handoffs de
  agentes especializados.
- Nomes: `<RoleName>.md`.
- Estados: `Draft`, `Active`, `Deprecated`.
- Critério de granularidade: um papel por responsabilidade e autoridade
  independentes; não criar um agente por tecnologia sem necessidade operacional.

## Subcoleções

- [Standards](standards/README.md)
- [Skills operacionais](skills/README.md)

## Agentes especializados

Nenhum agente especializado ativo no baseline. O agente principal do runtime aplica
os standards e skills catalogados até o projeto demonstrar a necessidade de um papel
com owner e handoff próprios.

