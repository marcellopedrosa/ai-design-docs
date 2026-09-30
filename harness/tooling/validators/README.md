---
document_id: HARNESS-VALIDATORS
document_scope: harness
primary_nature: Contexto
objective: Catalogar os validadores determinísticos do control plane .
scope: Validadores e testes em harness/tooling/validators/.
non_objectives: Ativar comandos de projeto adotante sem configuração própria.
owner: Arquitetura e Qualidade
status: Active
version: 0.1
date: 2026-09-30
last_reviewed: 2026-09-30
keywords: harness, tooling, validators,
related_files: ../README.md, automation-contract.md
code_references: validate-documentation-governance.mjs, validate-quality-policy.mjs, validate-quality-metrics.mjs, validate-plan-granularity.mjs, validate-api-contract-coverage.mjs, validate-google-runtime-governance.mjs
principal_statement: Os validadores do harness residem no control plane e somente verificações aplicáveis ao projeto são ativadas.
---

# Validadores do harness

Os executáveis e testes pertencem ao control plane. O
[contrato de automação](automation-contract.md) define a seleção; a presença de
um validador não ativa automaticamente uma capability em projeto adotante.

## Catálogo

- [Governança documental](validate-documentation-governance.mjs) e
  [testes](validate-documentation-governance.test.mjs): metadados, índices, links,
  referências, templates e paridade de adapters.
- [Política de qualidade](validate-quality-policy.mjs) e
  [testes](validate-quality-policy.test.mjs): A1/A2/A3, fontes, política Git e
  controles sem descoberta Git implícita.
- [Métricas](validate-quality-metrics.mjs) e
  [testes](validate-quality-metrics.test.mjs): targets explícitos; cobertura só
  com policy e relatório configurados.
- [Granularidade](validate-plan-granularity.mjs) e
  [testes](validate-plan-granularity.test.mjs): revisão semântica de TP/IP acima
  dos limites documentados.
- [Contrato HTTP Spring](validate-api-contract-coverage.mjs) e
  [testes](validate-api-contract-coverage.test.mjs): somente com
  `--profile java-spring`; caso contrário `SKIP`.
- [Governança Google](validate-google-runtime-governance.mjs) e
  [testes](validate-google-runtime-governance.test.mjs): somente com
  `--profile google-runtime`; pacotes ativos declarados explicitamente.

## Execução

Execute `node --test "harness/tooling/validators/*.test.mjs"` e
`node harness/tooling/validators/validate-documentation-governance.mjs --root .`.
Sem configuração no projeto adotante, registre `Automação não configurada`.
Não existe wrapper universal de projeto, nem `validate-implementation-readiness.sh`:
o `READY` exige auditoria semântica e aprovação das fontes aplicáveis.
