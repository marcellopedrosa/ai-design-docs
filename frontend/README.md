---
document_id: BASE-FRONTEND
primary_nature: Contexto
objective: Definir a fronteira base para a interface interativa principal do produto.
scope: Codigo, assets e testes de uma aplicacao cliente, independentemente de framework ou plataforma.
non_objectives: Nao escolher stack, design system, gerenciamento de estado ou estrategia de renderizacao.
owner: Equipe de Frontend ou Experiencia do projeto de destino
status: Active
version: 1.0
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: frontend, aplicacao-cliente, interface, scaffold
related_files: ../README.md, ../docs/architecture/module-registry.md, ../docs/agents/standards/README.md
code_references: N/A - pasta base sem implementacao.
principal_statement: A pasta frontend e um scaffold opcional para a experiencia interativa e deve receber stack, comandos e limites somente depois de decisoes reais.
---

# Frontend

Esta pasta reserva a fronteira da aplicação cliente interativa. Ela pode representar
web, desktop, mobile ou outra plataforma escolhida pelo projeto de destino.

## Estado do scaffold

- Implementação: nenhuma.
- Comando de desenvolvimento/build: não configurado.
- Teste focalizado e suíte: não configurados.
- Quality gate e acessibilidade: não configurados.
- Adaptador local de agente: criar somente quando houver especialização real.

## Contrato da pasta

- UI nova exige fonte visual ou critérios de interação aprovados quando aplicável.
- Componentes, estado, acessibilidade, internacionalização e testes seguem standards
  ativados pelo projeto; este baseline não escolhe ferramentas.
- Consumo de API/evento deve referenciar contrato canônico e versão exata.
- Assets, código e testes devem permanecer juntos da responsabilidade que atendem,
  sem antecipar uma árvore técnica vazia.
- Comandos, entrypoints, owner e dependências devem ser registrados no manifesto.
- Segredos, builds, caches e dependências baixadas não pertencem ao versionamento.

## Índice

Nenhum artefato de implementação ativo.

