---
document_id: TP-00001
primary_nature: Plano
objective: Coordenar a remediação cirúrgica de engenharia do harness v2.
scope: tooling/, contracts/, skills/, evals/, .github/workflows/
non_objectives: Não alterar main, não violar zero dependências, não enfraquecer gates.
owner: Engenharia e Arquitetura
status: In Progress
version: 1.0
date: 2026-09-30
last_reviewed: 2026-09-30
keywords: task-plan, remediation, doctor, parser, validator, drift, readiness
related_files: ../../README.md, ../adrs/ADR-0000-governanca-do-harness-documental.md, README.md
code_references: ../../tooling/harness-doctor/index.mjs, ../../tooling/contracts/validator.mjs, ../../tooling/adapters/sync-adapters.mjs
principal_statement: O plano coordena a remediação das ferramentas executáveis T-04 a T-12 com critérios auditados e resultado READY.
---

# TP-00001 — Remediação cirúrgica de engenharia do harness v2

## Fontes e versões

| Fonte | Versão/status | Escopo consumido |
| --- | --- | --- |
| ADR-0000 | 1.5 / Accepted | Governança documental, ciclo CLEAR e gates |
| HARNESS-README | 2.0.0 / Active | Árvore distribuída, bootstrap e ferramentas |
| Plano de correção cirúrgica | 2026-09-30 / Approved | Requisitos detalhados das tarefas T-00 a T-14 |

## Granularidade / Decomposição

- Resultado coordenado: Conjunto de melhorias de engenharia e conformidade em tooling, contratos e gates.
- Critério de divisão: Unidades semânticas por componente com testes e handoffs próprios.
- Relação pai → filhos:
  - TASK-00001.1 (T-09): Robustez do parser YAML fail-loud
  - TASK-00001.2 (T-10): Subconjunto explícito e fail-closed no validador de contratos
  - TASK-00001.3 (T-06 / T-11): Permissões de skills e ergonomia do doctor
  - TASK-00001.4 (T-04): Endurecimento de links, árvore e paridade no doctor
  - TASK-00001.5 (T-07 / T-08): Isolamento do GateEvaluator e portabilidade
  - TASK-00001.6 (T-12 / T-05a): Perfis de exemplo e CI

## Dependências e ordem

| Task | Depends on | Handoff para | Estado |
| --- | --- | --- | --- |
| TASK-00001.1 (T-09) | N/A | TASK-00001.2 | Ready |
| TASK-00001.2 (T-10) | TASK-00001.1 | TASK-00001.3 | Ready |
| TASK-00001.3 (T-06, T-11) | TASK-00001.2 | TASK-00001.4 | Ready |
| TASK-00001.4 (T-04) | TASK-00001.3 | TASK-00001.5 | Ready |
| TASK-00001.5 (T-07, T-08) | TASK-00001.4 | TASK-00001.6 | Ready |
| TASK-00001.6 (T-12, T-05a) | TASK-00001.5 | Conclusão | Ready |

---

## TASK-00001.1 — T-09: Parser YAML fail-loud

- What: Tratar comentários inline, aspas desbalanceadas, tipos numéricos/nulos e rejeitar objetos em listas.
- Where: `tooling/harness-doctor/index.mjs`, `tooling/harness-doctor/parse-simple-yaml.test.mjs`
- Depends on: N/A
- Reuses: Parser determinístico existente
- Requirements: T-09 do plano

### Gate Audit

| Controle | Evidência | Estado |
| --- | --- | --- |
| Product Definition | PRD not applicable (refatoração técnica interna) | Validated |
| Fontes superiores | ADR-0000 v1.5 / plano cirúrgico | Validated |
| Assumptions/Open Questions | Zero pendências | Validated |
| Granularidade | Escopo atômico focado em `parseSimpleYaml` | Validated |

### Acceptance Tests

| AC | Teste/comando/evidência | Resultado esperado |
| --- | --- | --- |
| AC-01 | `node --test tooling/harness-doctor/parse-simple-yaml.test.mjs` | PASS em todos os casos |
| AC-02 | Regressão em YAMLs do repositório | PASS no doctor |

### Prohibited

- Não introduzir dependências npm (como js-yaml).
- Não alterar contrato de retorno de `parseSimpleYaml`.

### Mandatory

- Testes automatizados com `node:test` cobrindo cada falha explícita.

### Definition of Done

- [ ] Parser rejeita comentários inline misturados a valores, aspas desbalanceadas e lista de objetos.
- [ ] Converte corretamente `null`, `~` e números inteiros/decimais.
- [ ] Suíte de testes dedicada passa 100%.

### Result

- Estado: READY
- Auditor/data: Antigravity / 2026-09-30
- Task ID, versões e paths: TASK-00001.1, v1.0, `tooling/harness-doctor/`

---

## TASK-00001.2 — T-10: Validator JSON Schema fail-closed

- What: Rejeitar palavras-chave de validação não suportadas e documentar o subconjunto suportado.
- Where: `tooling/contracts/validator.mjs`, `tooling/contracts/validator.test.mjs`, `contracts/README.md`
- Depends on: TASK-00001.1
- Reuses: `validateSchemaSyntax`, `validateInstance`
- Requirements: T-10 do plano

### Gate Audit

| Controle | Evidência | Estado |
| --- | --- | --- |
| Product Definition | PRD not applicable (refatoração técnica) | Validated |
| Fontes superiores | Contratos JSON Schema em `contracts/` | Validated |
| Assumptions/Open Questions | Resolvidas | Validated |
| Granularidade | Focada no validador e documentação de schema | Validated |

### Result

- Estado: READY
- Auditor/data: Antigravity / 2026-09-30
- Task ID, versões e paths: TASK-00001.2, v1.0, `tooling/contracts/`

---

## TASK-00001.3 — T-06 / T-11: Permissões de skills e ergonomia do doctor

- What: `splitAllowedTools` com suporte a ferramentas escopadas (`Bash(rm:*)`), `--root`, `--json`, honestidade nos rótulos de evals e remoção de código morto.
- Where: `tooling/harness-doctor/index.mjs`, `tooling/adapters/sync-adapters.mjs`, `tooling/README.md`
- Depends on: TASK-00001.2
- Reuses: Estrutura de diagnósticos do doctor
- Requirements: T-06 e T-11 do plano

### Result

- Estado: READY
- Auditor/data: Antigravity / 2026-09-30
- Task ID, versões e paths: TASK-00001.3, v1.0, `tooling/`

---

## TASK-00001.4 — T-04: Endurecer checkDrift no doctor

- What: `checkMarkdownLinks`, `checkDistributedTree`, `checkAgentIndex`, `checkVersionParity`.
- Where: `tooling/harness-doctor/index.mjs`, `tooling/harness-doctor/harness-doctor.test.mjs`
- Depends on: TASK-00001.3
- Reuses: Doctor framework
- Requirements: T-04 do plano

### Result

- Estado: READY
- Auditor/data: Antigravity / 2026-09-30
- Task ID, versões e paths: TASK-00001.4, v1.0, `tooling/harness-doctor/`

---

## TASK-00001.5 — T-07 / T-08: GateEvaluator executável e portabilidade

- What: Definição de subagente para Claude Code, hook/verificação e matriz de portabilidade em runtimes.
- Where: `.claude/agents/`, `docs/agents/GateEvaluator.md`, `registry/runtimes.yaml`
- Depends on: TASK-00001.4
- Reuses: Hooks e contratos existentes
- Requirements: T-07 e T-08 do plano

### Result

- Estado: READY
- Auditor/data: Antigravity / 2026-09-30
- Task ID, versões e paths: TASK-00001.5, v1.0, `.claude/agents/`, `registry/`

---

## TASK-00001.6 — T-12 / T-05a: Perfis de exemplo e CI

- What: Criar `examples/profiles/node-web.yaml` e `python-service.yaml`, validar contra schema e workflow de CI.
- Where: `examples/profiles/`, `.github/workflows/`
- Depends on: TASK-00001.5
- Reuses: `harness.project.schema.json`
- Requirements: T-12 e T-05a do plano

### Result

- Estado: READY
- Auditor/data: Antigravity / 2026-09-30
- Task ID, versões e paths: TASK-00001.6, v1.0, `examples/profiles/`, `.github/workflows/`
