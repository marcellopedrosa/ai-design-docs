# Tooling Determinístico do Harness

Este diretório contém ferramentas determinísticas portáteis, entrypoints de validação estrutural e sincronizadores do harness agnóstico.

## Posicionamento Arquitetural

- `docs/automation/`: Define os **contratos normativos e manuais** de automação legíveis por pessoas e agentes.
- `tooling/`: Contém as **implementações executáveis determinísticas** do próprio harness.
- Nenhuma ferramenta introduz política nova; toda regra executável implementa um standard ou contrato formal.

## Ferramentas

- [`harness-doctor/index.mjs`](harness-doctor/index.mjs): Diagnóstico estrutural unificado do harness (registry, contracts, skills, adapters, evals e detecção de drift).
- [`adapters/sync-adapters.mjs`](adapters/sync-adapters.mjs): Sincronizador determinístico e verificador de paridade entre a fonte canônica `skills/` e as distribuições `.agents/` e `.claude/`.

## Execução

```bash
# Diagnóstico estrutural completo
node tooling/harness-doctor/index.mjs

# Verificar paridade de adapters
node tooling/adapters/sync-adapters.mjs --check

# Sincronizar adapters
node tooling/adapters/sync-adapters.mjs
```
