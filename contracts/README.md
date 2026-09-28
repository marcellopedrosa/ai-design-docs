# Contratos Estruturados do Harness v2

Este diretório contém os schemas JSON formais que governam a troca de mensagens, evidências, resultados de gates e handoffs entre agentes, capacidades e ferramentas do harness agnóstico.

## Por que Schemas Formais?

O harness v1 definia contratos operacionais apenas em texto Markdown. Isso era adequado para consumo humano, mas insuficiente para garantir que:
1. Um resultado de gate esteja amarrado ao `READY` e ao escopo exato que o originou (prevenção de evidência stale).
2. Resultados `BLOCKED` contenham obrigatoriamente a causa raiz, o owner responsável e a condição objetiva de retomada.
3. Findings de segurança exijam comprovação simultânea de evidência, alcance (reachability), lacuna de controle e impacto plausível antes de confirmação.
4. Handoffs entre agentes e orquestrador sejam estruturados e auditáveis por máquinas.

## Schemas Disponíveis

- [`capability-request.schema.json`](capability-request.schema.json): Solicitação de execução de capacidade ou skill.
- [`readiness-result.schema.json`](readiness-result.schema.json): Resultado estruturado do Implementation Readiness Gate (`READY` ou `BLOCKED`).
- [`gate-result.schema.json`](gate-result.schema.json): Resultado estruturado de gates e subgates (`PASS`, `FAIL` ou `BLOCKED`).
- [`evidence.schema.json`](evidence.schema.json): Registro formal de evidência de execução de comando, teste ou inspeção.
- [`security-finding.schema.json`](security-finding.schema.json): Registro de vulnerabilidade ou finding de segurança com exigência de comprovação quádrupla.
- [`handoff.schema.json`](handoff.schema.json): Registro de transição de responsabilidade entre agentes e capacidades.

## Validação

Todos os schemas seguem a especificação JSON Schema Draft-07 / 2020-12 e são verificados deterministicamente pelo `harness doctor`.
