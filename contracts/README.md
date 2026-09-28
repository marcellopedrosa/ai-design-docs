# Contratos Estruturados do Harness

Este diretório contém os schemas JSON formais que governam a troca de mensagens, evidências, resultados de gates e handoffs entre agentes, capacidades e ferramentas do harness agnóstico.

## Finalidade dos Schemas

Os schemas formais estabelecem garantias estruturais para a operação de agentes e ferramentas:
1. **Vinculação de Escopo e Frescor**: Todo resultado de gate referencia o identificador da tarefa e o fingerprint exato do escopo auditado, prevenindo o uso de evidências obsoletas (*stale evidence*).
2. **Fechamento Rígido de Bloqueios**: Qualquer resultado `BLOCKED` exige a especificação da causa raiz, do owner responsável e da condição objetiva para retomada do fluxo.
3. **Comprovação Quádrupla de Segurança**: Findings de segurança exigem demonstração inequívoca de Evidência, Alcance (*Reachability*), Lacuna de Controle e Impacto Plausível antes de qualquer confirmação.
4. **Handoffs Auditáveis por Máquina**: A transição de responsabilidade entre orquestrador, capacidades e gates é estruturada em dados serializáveis, permitindo verificação determinística por ferramentas e pipelines.

## Schemas Disponíveis

- [`capability-request.schema.json`](capability-request.schema.json): Solicitação de execução de capacidade ou skill.
- [`readiness-result.schema.json`](readiness-result.schema.json): Resultado estruturado do Implementation Readiness Gate (`READY` ou `BLOCKED`).
- [`gate-result.schema.json`](gate-result.schema.json): Resultado estruturado de gates e subgates (`PASS`, `FAIL` ou `BLOCKED`).
- [`evidence.schema.json`](evidence.schema.json): Registro formal de evidência de execução de comando, teste ou inspeção.
- [`security-finding.schema.json`](security-finding.schema.json): Registro de vulnerabilidade ou finding de segurança com exigência de comprovação quádrupla.
- [`handoff.schema.json`](handoff.schema.json): Registro de transição de responsabilidade entre agentes e capacidades.

## Validação

Todos os schemas seguem a especificação JSON Schema Draft-07 / 2020-12 e são verificados deterministicamente pelo `harness doctor`.
