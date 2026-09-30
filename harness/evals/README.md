# Suíte de Avaliações (Evals) do Harness

Este diretório contém os conjuntos de avaliação do harness como um sistema integrado (Orchestrator + Skills + Standards + Gates + Adapters).

## O que os casos de eval pretendem verificar

Os arquivos desta coleção descrevem cenários de comportamento e conformidade. A presença de um caso não comprova que ele foi executado nem que passou:

1. **Lifecycle**: verificar a cadeia C.L.E.A.R. (nenhuma implementação sem READY, nenhum release com gate falho).
2. **Orchestration**: verificar coordenação, seleção de fontes e roteamento de remediação pelo AgentOrchestrator.
3. **Permissions**: verificar limites de acesso a produção, dados reais, segredos e comandos destrutivos.
4. **Portability**: comparar invariantes entre Codex, Claude Code, Gemini CLI e Antigravity.
5. **Regression**: detectar regressões de governança.

## Estrutura

- [`schema/harness-eval.schema.json`](schema/harness-eval.schema.json): Schema JSON formal para casos de eval.
- [`lifecycle/`](lifecycle/): Casos de avaliação do fluxo C.L.E.A.R. e gates.
- [`orchestration/`](orchestration/): Casos de roteamento, seleção seletiva e handoffs.
- [`permissions/`](permissions/): Casos de limites de segurança, permissões e fail-closed.
- [`portability/`](portability/): Matriz de invariantes cross-runtime.
- [`regression/`](regression/): Casos de proteção contra regressões conhecidas.

## Níveis de Avaliação

- **H0 — Estrutural (parcialmente implementado)**: o `harness doctor` verifica a presença e a forma básica dos casos; a contagem informada não representa casos executados nem validação comportamental.
- **H1 — Comportamento Determinístico (implementado para casos elegíveis)**: `node harness/tooling/eval-runner/index.mjs --level H1` valida fixtures e saídas contra contratos de gates; o resumo separa casos executados de casos ignorados.
- **H2 — Roteamento Semântico (não implementado)**: avaliação de precisão e revocação na seleção de skills e standards. `--level H2` retorna `NOT_IMPLEMENTED` e exit code 2, sem executar H1 como substituto.
- **H3 — Capacidade em Execução (planejado)**: execução assistida com verificação de Skill Lift.
- **H4 — Portabilidade Cross-Runtime (planejado)**: execução paralela em múltiplos runtimes para comparar decisões.
