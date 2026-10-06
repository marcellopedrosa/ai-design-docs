# Contratos Estruturados do Harness

Este diretório contém os schemas JSON formais que governam a troca de mensagens, evidências, resultados de gates e handoffs entre agentes, capacidades e ferramentas do harness agnóstico.

> [!NOTE] Distinção entre `harness/contracts/` e `docs/contracts/`
> `harness/contracts/` (na raiz) armazena exclusivamente os schemas formais e estruturados da infraestrutura e governança do próprio harness (formatos de mensagens, gates, evidências, handoffs e manifestos). Já `docs/contracts/` é a coleção documental destinada a catalogar as interfaces públicas do produto ou sistema desenvolvido pelo projeto adotante (como especificações OpenAPI, contratos de mensageria AsyncAPI e schemas de dados de negócio).

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
- [`harness-project.schema.json`](harness-project.schema.json): Manifesto estruturado de configuração do projeto adotante (`harness.project.yaml`).
- [`project-manifest.schema.json`](project-manifest.schema.json): Contexto declarativo  em `docs/project-manifest.yaml`.
- [`profile-registry.schema.json`](profile-registry.schema.json): Profiles, herança e artefatos exigidos.
- [`artifact-routes.schema.json`](artifact-routes.schema.json): Rotas físicas e templates por tipo.

## Validação e Exemplos

Todos os schemas seguem a especificação JSON Schema Draft-07 / 2020-12 e são compilados e verificados deterministicamente pelo `harness doctor` através do validador determinístico próprio em `harness/tooling/contracts/validator.mjs` (suportando validação estrita de `type`, `required`, `additionalProperties: false`, `enum`, `items` e objetos aninhados, sem dependências externas).

Exemplos de conformidade e contraexemplos residem em [`examples/`](examples/):
- Instâncias válidas (`*.valid.json`) comprovam conformidade estrutural.
- Instâncias inválidas (`*.invalid.json`) garantem que desvios de contrato são rejeitados fail-closed.
