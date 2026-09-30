---
document_id: AGENT-PROHIBITIONS
document_scope: harness
primary_nature: Restrição
objective: Definir ações proibidas para qualquer agente.
scope: Agentes operando sob o harness.
owner: Mantenedores do harness
status: Active
version: 1.0
date: 2026-09-30
last_reviewed: 2026-09-30
keywords: prohibitions, scope, gates, canonical-source
related_files: ../README.md, ../policies/agent-behavior-policy.md
code_references: ../../tooling/harness-doctor/index.mjs
principal_statement: Proibições universais não podem ser relaxadas por runtime, stack ou projeto.
---

# Agent Prohibitions

## Purpose

Definir ações proibidas para qualquer agente operando sob este harness.

## Scope

Estas proibições são universais e se aplicam independentemente de runtime, stack ou projeto.

## The Agent Must Not

### Scope

- alterar arquivos fora do escopo da tarefa sem necessidade explícita;
- transformar uma correção localizada em refatoração ampla;
- introduzir funcionalidades não solicitadas;
- alterar decisões arquiteturais do projeto sem evidência ou autorização apropriada.

### Canonical Sources

- editar artefato derivado quando existir fonte canônica;
- duplicar regras já existentes em outro arquivo;
- criar uma segunda fonte de verdade para a mesma informação.

### Gates and Evidence

- ignorar gate obrigatório com falha;
- declarar PASS sem evidência correspondente;
- omitir falha de validação relevante;
- modificar regra ou threshold apenas para obter PASS.

### Runtime Independence

- criar comportamento exclusivo para um runtime quando houver mecanismo comum no harness;
- criar paths hardcoded específicos de Claude, Codex, Gemini ou outro runtime;
- duplicar governança em arquivos específicos de runtime.

### Architecture

- adicionar framework, serviço ou abstração sem necessidade comprovada;
- criar workflow engine para resolver um fluxo simples;
- adicionar persistência quando arquivo/estado temporário for suficiente;
- introduzir dependência externa desnecessária.

## Exceptions

Uma exceção somente pode ocorrer quando:

1. for explicitamente necessária para a tarefa;
2. estiver documentada;
3. não violar uma restrição de segurança;
4. estiver incluída no handoff.
