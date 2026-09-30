# Tooling Determinístico do Harness

Este diretório contém ferramentas determinísticas portáteis, entrypoints de validação estrutural e sincronizadores do harness agnóstico.

## Posicionamento Arquitetural

- `docs/automation/`: Define os **contratos normativos e manuais** de automação legíveis por pessoas e agentes.
- `tooling/`: Contém as **implementações executáveis determinísticas** do próprio harness.
- Nenhuma ferramenta introduz política nova; toda regra executável implementa um standard ou contrato formal.

## Ferramentas

- [`harness-doctor/index.mjs`](harness-doctor/index.mjs): Diagnóstico estrutural unificado do harness (registry, contracts, skills, adapters, evals e detecção de drift).
- [`adapters/sync-adapters.mjs`](adapters/sync-adapters.mjs): Sincronizador determinístico e verificador de paridade entre a fonte canônica `skills/` e as distribuições `.agents/` e `.claude/`.
- [`contracts/validator.mjs`](contracts/validator.mjs): Validador estrutural e sintático fail-closed para JSON Schema (Draft-07) e instâncias.
- [`eval-runner/index.mjs`](eval-runner/index.mjs): Runner determinístico de evals do harness (H0 e H1).
- [`hooks/`](hooks/): Hooks de ciclo de vida e guardrails de execução (ex.: `guard-paths.mjs`, `require-handoff.mjs`).

## Execução

```bash
# Diagnóstico estrutural completo
node tooling/harness-doctor/index.mjs

# Diagnóstico com saída estruturada JSON (validada contra doctor-result.schema.json)
node tooling/harness-doctor/index.mjs --json

# Diagnóstico especificando explicitamente a raiz do repositório
node tooling/harness-doctor/index.mjs --root /caminho/do/repo

# Verificar paridade de adapters
node tooling/adapters/sync-adapters.mjs --check

# Sincronizar adapters
node tooling/adapters/sync-adapters.mjs
```
