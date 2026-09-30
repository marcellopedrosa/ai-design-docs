# Tooling Determinístico do Harness

Este diretório contém ferramentas determinísticas portáteis, entrypoints de validação estrutural e sincronizadores do harness agnóstico.

## Posicionamento Arquitetural

- `harness/tooling/validators/`: Define os **contratos normativos e manuais** de automação legíveis por pessoas e agentes.
- `harness/tooling/`: Contém as **implementações executáveis determinísticas** do próprio harness.
- Nenhuma ferramenta introduz política nova; toda regra executável implementa um standard ou contrato formal.

## Adoption Lifecycle

- `node harness/tooling/harness.mjs onboard`
- `node harness/tooling/harness.mjs onboard --source "<path>"`
- `node harness/tooling/harness.mjs bootstrap`
- `node harness/tooling/harness.mjs scaffold --check|--create|--inspect`
- `node harness/tooling/harness.mjs doctor`

## Ferramentas

- [`harness-doctor/index.mjs`](harness-doctor/index.mjs): Diagnóstico estrutural unificado do harness (registry, contracts, skills, adapters, evals e detecção de drift).
- [`adapters/sync-adapters.mjs`](adapters/sync-adapters.mjs): Sincronizador determinístico e verificador de paridade entre a fonte canônica `harness/skills/` e as distribuições `.agents/` e `.claude/`.
- [`contracts/trace.mjs`](contracts/trace.mjs): Verifica que um bundle JSON `{ "evidence": [], "gate": {}, "handoff": {} }` conecta IDs, task e escopo; `node harness/tooling/contracts/trace.mjs --input <arquivo.json>`. Não executa testes nem produz evidências por conta própria.

## Execução

Ponto de entrada único: `node harness/tooling/harness.mjs <doctor|check|eval|sync|scaffold>`.

O [scaffold V6](scaffold/README.md) consome manifesto, profiles, routes e
templates; oferece `--inspect`, `--check` e `--create` sem sobrescrita.
`check` executa a governança documental; `eval` executa somente H1; `sync`
verifica paridade sem escrever. Para sincronização com escrita, use diretamente
`node harness/tooling/adapters/sync-adapters.mjs` após revisão do diff. A fachada preserva
o código de saída da ferramenta; não agrega gates A1/A2/A3.
`node harness/tooling/contracts/trace.mjs --input <arquivo.json>` verifica o vínculo entre
evidências produzidas externamente, gate e handoff; não executa os gates.

```bash
# Diagnóstico estrutural completo
node harness/tooling/harness-doctor/index.mjs

# Verificar paridade de adapters
node harness/tooling/adapters/sync-adapters.mjs --check

# Sincronizar adapters
node harness/tooling/adapters/sync-adapters.mjs
```
