---
document_id: AGENT-BEHAVIOR-POLICY
document_scope: harness
primary_nature: Regra
objective: Definir o comportamento operacional mínimo esperado de qualquer agente.
scope: Agentes operando sob o harness.
owner: Mantenedores do harness
status: Active
version: 1.0
date: 2026-09-30
last_reviewed: 2026-09-30
keywords: agents, behavior, validation, evidence, handoff
related_files: README.md, ../README.md, ../restrictions/agent-prohibitions.md
code_references: ../../tooling/harness-doctor/index.mjs
principal_statement: Agentes devem trabalhar dentro do escopo, validar mudanças e entregar evidência verificável.
---

# Agent Behavior Policy

## Purpose

Definir o comportamento operacional mínimo esperado de qualquer agente executado sob este harness.

## Before Making Changes

O agente deve:

1. identificar o escopo da tarefa;
2. identificar os arquivos diretamente afetados;
3. identificar a fonte canônica quando houver arquivos derivados;
4. verificar standards aplicáveis;
5. verificar gates aplicáveis;
6. evitar alterações fora do escopo.

## During Changes

O agente deve:

1. realizar a menor alteração capaz de cumprir o objetivo;
2. preservar comportamento existente não relacionado;
3. evitar refatorações cosméticas fora do escopo;
4. manter compatibilidade sempre que possível;
5. registrar desvios relevantes quando necessários.

## Validation

Após a alteração, o agente deve:

1. executar validações aplicáveis;
2. executar testes aplicáveis;
3. executar gates aplicáveis;
4. registrar falhas não resolvidas;
5. não declarar sucesso quando uma validação obrigatória falhar.

## Evidence

Quando uma validação ou gate for executado, o agente deve registrar evidência suficiente para identificar:

- ferramenta executada;
- resultado;
- arquivos ou escopo avaliados;
- falhas encontradas;
- limitações conhecidas.

## Handoff

Ao concluir a tarefa, o agente deve informar:

- arquivos alterados;
- validações executadas;
- resultado das validações;
- restrições ou limitações;
- pendências conhecidas.
