# Suíte de Avaliações (Evals) do Harness

Este diretório contém os conjuntos de avaliação do harness como um sistema integrado (Orchestrator + Skills + Standards + Gates + Adapters).

## O que os Evals do Harness Provam

Diferente dos testes de software tradicionais (que testam lógica estática ou APIs), os evals avaliam o comportamento e a conformidade do sistema de engenharia assistido por IA:

1. **Lifecycle**: Prova que a cadeia C.L.E.A.R. é respeitada (nenhuma implementação sem READY, nenhum release com gate falho).
2. **Orchestration**: Prova que o AgentOrchestrator atua como coordenador único, seleciona fontes relevantes sob demanda e roteia remediação sem criar papéis desnecessários.
3. **Permissions**: Prova que o princípio do menor privilégio é preservado (sem acesso a produção, dados reais, segredos ou comandos destrutivos sem aprovação).
4. **Portability**: Prova que os invariantes produzem os mesmos resultados estruturais entre runtimes distintos (Codex, Claude Code, Gemini CLI, Antigravity).
5. **Regression**: Protege o harness contra regressões silenciosas de governança.

## Estrutura

- [`schema/harness-eval.schema.json`](schema/harness-eval.schema.json): Schema JSON formal para casos de eval.
- [`lifecycle/`](lifecycle/): Casos de avaliação do fluxo C.L.E.A.R. e gates.
- [`orchestration/`](orchestration/): Casos de roteamento, seleção seletiva e handoffs.
- [`permissions/`](permissions/): Casos de limites de segurança, permissões e fail-closed.
- [`portability/`](portability/): Matriz de invariantes cross-runtime.
- [`regression/`](regression/): Casos de proteção contra regressões conhecidas.

## Níveis de Avaliação

- **H0 — Estrutural**: Validação estática de arquivos, esquemas, paridade e ausência de órfãos (executado pelo `harness doctor`).
- **H1 — Comportamento Determinístico**: Validação de fixtures e saídas contra contratos de gates.
- **H2 — Roteamento Semântico**: Avaliação de precisão e revocação na seleção de skills e standards.
- **H3 — Capacidade em Execução (Live)**: Execução assistida com verificação de Skill Lift.
- **H4 — Portabilidade Cross-Runtime**: Execução paralela em múltiplos runtimes comprovando convergência de decisões.
