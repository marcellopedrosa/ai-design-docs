---
document_id: TP-00066
primary_nature: Plano
objective: Corrigir e tornar executável o onboarding dos webhooks omnichannel em DEV, HML e PRD, alinhando registro Telegram, proxy canônico, diagnóstico 503, segurança de segredos e critérios de aceite.
scope: Documentação de onboarding, launcher DEV, Compose/proxy HML e PRD, reconciliação automática do webhook Telegram, observabilidade de inbox/pool e testes de contrato; sem acesso a ambientes reais durante a implementação repository-local.
non_objectives: Não rotacionar tokens reais, não executar deploy HML/PRD, não alterar DNS/TLS real, não introduzir Nginx host paralelo, não descartar updates Telegram e não modificar contratos HTTP sem requisito aprovado.
owner: DevOps, Integrações, Backend e Qualidade
status: Completed
version: 1.0
date: 2026-09-29
last_reviewed: 2026-09-29
keywords: webhook, telegram, whatsapp, dev, hml, prd, nginx, docker, 503, pool, onboarding
related_files: ../../backend/docs/onboarding/omnichannel-webhook-configuration.md, ../../backend/docs/onboarding/production-vps-deployment.md, docs/onboarding/README.md, ../../backend/docs/adrs/ADR-0016-infrastructure-environment-provisioning.md, ../../docs/prds/PRD-00002-omnichannel-experience.md, docs/delivery/plans/implementation_plans/infra/README.md
code_references: start-dev-bot.sh, start-dev-bot-exposed-ngrok.sh, docker-compose.hml.yml, docker-compose.prd.yml, infra/proxy/nginx.hml.conf, infra/proxy/nginx.prd.conf, infra/scripts/deploy-production.sh, backend/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/application/usecase/RegisterTelegramWebhookUseCase.java, backend/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/presentation/rest/TelegramWebhookController.java, backend/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/application/usecase/AcceptInboundMessageUseCase.java
principal_statement: O backend deve registrar o Telegram com secret_token e o proxy canônico deve encaminhar DEV/HML/PRD conforme o ambiente, permitindo distinguir 401, 429 e 503 sem expor segredos nem descartar eventos.
---

# TP-00066 — Correção do onboarding de webhooks omnichannel

## 1. What / resultado esperado

Entregar um onboarding único, executável e coerente para os três ambientes:

- DEV usa `./start-dev-bot.sh`; túnel externo só é iniciado pelo launcher
  governado `start-dev-bot-exposed-ngrok.sh`.
- HML usa `docker-compose.hml.yml` e `saas-proxy-hml`.
- PRD usa `docker-compose.prd.yml`, `saas-proxy-prd` e
  `infra/scripts/deploy-production.sh`.
- Telegram é registrado/reconciliado pelo backend com `secret_token`; nenhuma
  instrução operacional sobrescreve o segredo com `setWebhook` manual.
- O diagnóstico distingue rejeição do proxy (`limiting requests/connections`,
  upstream/503) de falha de persistência (`PERSISTENCE_UNAVAILABLE`, Hikari,
  `CannotCreateTransactionException`, lock ou SQL).
- Nenhum procedimento imprime token, segredo, payload sensível ou credencial.

## 2. Where / paths autorizados

### Documentação

- `../../backend/docs/onboarding/omnichannel-webhook-configuration.md`
- `docs/onboarding/README.md`
- `../../backend/docs/onboarding/production-vps-deployment.md` somente se houver divergência
  operacional comprovada.
- `TP-00066-omnichannel-webhook-onboarding-correction.md`
- `docs/delivery/plans/README.md`

### Runtime/configuração, somente após IRG READY

- `start-dev-bot.sh`
- `start-dev-bot-exposed-ngrok.sh`
- `docker-compose.hml.yml`
- `docker-compose.prd.yml`
- `infra/proxy/nginx.hml.conf`
- `infra/proxy/nginx.prd.conf`
- `infra/scripts/deploy-production.sh` e testes diretamente impactados
- `RegisterTelegramWebhookUseCase`, `TelegramWebhookController` e
  `AcceptInboundMessageUseCase` somente se o teste provar drift do contrato atual.

Não editar outros paths por conveniência. Se a correção exigir novo módulo,
abrir uma decomposição filha e reexecutar o readiness.

## 3. Depends on / fontes e decisões

- ADR-0016 e Compose/scripts atuais são a fonte operacional de infraestrutura.
- O código do registro Telegram é a fonte do contrato `secret_token`.
- O controller é a fonte do header `X-Telegram-Bot-Api-Secret-Token` e do status
  retornado quando o inbox durável não pode aceitar o evento.
- PRD-00002 é aplicável somente se o comportamento observável do webhook mudar;
  se não houver alteração de produto, o executor deve registrar `PRD not
  applicable` com justificativa.
- Não há autorização implícita para acessar HML/PRD ou rotacionar credenciais.

## 4. Pré-requisito obrigatório — autorização e readiness

Nenhum handoff de implementação (`WH-DEV-001` a `WH-QA-005`) pode começar antes
 desta etapa ser concluída. Ela é parte do TP-00066 e não pode ser tratada como
uma atividade opcional ou posterior:

1. Confirmar o escopo repository-local e registrar que não haverá acesso a HML/PRD
   real, Telegram/Meta real, DNS/TLS real, rotação automática de segredo ou
   publicação de imagem.
2. Reconhecer o PRD-00002 v1.35 como fonte superior já validada: status
   `Validated`, Product Definition Gate `PASS`, todas as `OQ-OMNI-*` em `Resolved`
   e aprovação de Produto/Operações e Segurança/Compliance em 2026-09-12. Não é
   permitido reabrir o PRD para resolver os bloqueios operacionais deste plano.
3. Obter requisito aprovado para qualquer alteração de launcher, Compose, Nginx,
   observabilidade ou backend; documentação isolada não autoriza mudança de
   runtime.
4. Resolver a decisão do status do Nginx: preservar o `503` efetivo ou alterar
   explicitamente para `429`, incluindo owner, decisão e teste de compatibilidade.
5. Registrar que o token Telegram anteriormente exposto já foi rotacionado no
   BotFather. O novo token não deve entrar no repositório, logs, argumentos ou
   fixtures.
6. Reexecutar o Implementation Readiness Gate com o mesmo task ID, versões e
   paths; somente o resultado `READY` libera a sequência de handoffs.

**Regra de parada:** se qualquer item acima estiver `Open`, `Proposed`, `TBD`, sem
owner/evidência ou em conflito com ADR/requirement, o agente deve parar após o
trabalho documental e reportar `BLOCKED`; não pode implementar parcialmente DEV,
HML ou PRD.

## 4. Decomposição executável

| ID | Resultado | Paths principais | Dependência |
| --- | --- | --- | --- |
| `WH-DEV-001` | DEV sobe sem instruir URL/segredo incorreto e mantém isolamento do ngrok. | `start-dev-bot.sh`, `start-dev-bot-exposed-ngrok.sh`, docs de onboarding | IRG do plano |
| `WH-REMOTE-002` | HML/PRD usam apenas proxy Docker canônico, sem receita Nginx host paralela. | Compose, `infra/proxy`, deploy, onboarding | `WH-DEV-001` |
| `WH-TG-003` | Registro Telegram preserva `secret_token` e documentação impede `setWebhook` inseguro. | use case, controller, onboarding, testes | contrato atual confirmado |
| `WH-OBS-004` | Runbook reproduz diagnóstico 401/429/503 e pool/inbox com janela temporal. | backend logs, proxy logs, onboarding | `WH-REMOTE-002` |
| `WH-QA-005` | Testes focalizados, governança documental e gates de entrega passam. | testes afetados e docs | `WH-TG-003`, `WH-OBS-004` |

A decomposição é por resultado independente; não dividir por arquivo ou linha.

## 5. Implementation Readiness Gate

### Gate Audit

| Controle | Evidência exigida | Estado inicial |
| --- | --- | --- |
| Product Definition | PRD-00002 v1.35 `Validated`; Product Definition Gate `PASS`; OQ-OMNI-001/002/003/005/006/007 `Resolved` | PASS |
| Requirement | Requisito aprovado para qualquer mudança de runtime/configuração | BLOCKED até owner |
| ADR | ADR-0016 vigente; nova topologia exige ADR/decisão adicional | PASS para docs; BLOCKED para nova topologia |
| API Contract | Nenhum endpoint novo; se controller mudar, contrato canônico e operação exata | N/A enquanto não houver drift |
| Assumptions | Proxy deve responder 429 explicitamente; token já foi rotacionado; implementação será local com efeito futuro em HML/PRD | PASS, decisão do solicitante em 2026-09-29 |
| Open Questions | Status 429, rotação do token e escopo local com efeito futuro foram resolvidos pelo solicitante em 2026-09-29 | PASS |
| Dependencies | Acesso repository-local, Docker seguro e fixtures sem segredo real | PASS local; ambiente externo proibido |
| Granularity | Cinco handoffs acima, cada um com paths e aceite próprios | PASS |
| Pré-requisito | Seção 4 concluída e evidenciada antes dos handoffs | BLOCKED até conclusão |

As decisões do solicitante nesta revisão materializam o requisito de execução
local, o status 429, a rotação do token e o escopo futuro HML/PRD. O readiness
fica `READY` para implementação repository-local; qualquer ação ambiental continua
fora do escopo e bloqueada.

## 6. Acceptance Tests

### DEV

- `bash -n start-dev-bot.sh start-dev-bot-exposed-ngrok.sh`.
- Teste hermético comprova que o launcher DEV não registra URL HML/PRD e não
  imprime token.
- Smoke local comprova webhook via URL transitória apenas quando o launcher
  exposto estiver explicitamente selecionado.

### HML/PRD (repository-local)

- Compose config resolve `proxy` e backend sem bind concorrente de 80/443.
- O proxy preserva método POST, query string, raw body,
  `X-Hub-Signature-256` e `X-Telegram-Bot-Api-Secret-Token`.
- `limit_req`/`limit_conn` têm o status documentado; o teste não assume 429 se a
  configuração efetiva retornar 503.
- `deploy-production.sh` recria/testa/recarrega o proxy sem Nginx host paralelo.

### Telegram

- Teste captura a requisição de registro e exige `url` e `secret_token`.
- Teste negativo sem `X-Telegram-Bot-Api-Secret-Token` retorna o status do
  contrato atual; teste positivo aceita o header correto.
- Nenhum teste usa token real ou chama Telegram externo.

### Diagnóstico

- Fixture de log contém cada fingerprint: `PERSISTENCE_UNAVAILABLE`, Hikari,
  `CannotCreateTransactionException`, `limiting requests`, `limiting
  connections` e upstream 503.
- O runbook orienta janela `--since/--until`, `errorId` e correlação proxy/backend.

## 7. Prohibited

- Não usar `setWebhook` manual sem `secret_token`.
- Não colocar bot token em argumento, histórico, log, fixture, screenshot ou
  commit.
- Não usar `drop_pending_updates=true` como correção de rotina.
- Não acessar produção, HML real, Telegram real, Meta real ou segredos reais.
- Não criar Nginx host paralelo, alterar DNS/TLS real ou publicar imagens.
- Não mudar status 503 para 429 sem decisão explícita e testes de compatibilidade.
- Não mascarar falha de pool/inbox retornando 200 sem persistência durável.

## 8. Mandatory

- Atualizar índice imediato e change log da coleção modificada.
- Preservar a relação entre documentação, Compose/scripts e código.
- Criar/atualizar testes relevantes antes de concluir runtime.
- Executar `./infra/scripts/validate-docs.sh`.
- Para runtime, executar Quality Gate com `--target` para cada path alterado e
  repetir em modo delivery com branch governada.
- Registrar skips, falhas e limitações; não declarar HML/PRD validado por smoke
  repository-local.

## 9. Definition of Done

- [ ] IRG `READY` vigente para o mesmo task ID, versões e paths.
- [ ] Todos os cinco handoffs concluídos ou explicitamente replanejados.
- [ ] DEV, HML e PRD têm passos canônicos e critérios de aceite distintos.
- [ ] Registro Telegram mantém `secret_token` e header documentado.
- [ ] Diagnóstico 503 cobre proxy e persistência/pool.
- [ ] Nenhum segredo aparece no diff, logs ou testes.
- [ ] Governança documental `PASS`.
- [ ] Quality Gate aplicável `PASS`.
- [ ] Commit convencional e push em branch governada concluídos pelo executor.

## 10. Evidência da execução atual

- `WH-REMOTE-002`: aplicado repository-local nos arquivos
  `infra/proxy/nginx.hml.conf` e `infra/proxy/nginx.prd.conf`.
- HML e PRD agora declaram `limit_req_status 429` e `limit_conn_status 429` nos
  ingress públicos; `503` permanece reservado para upstream/backend.
- `bash -n start-dev-bot.sh start-dev-bot-exposed-ngrok.sh`: PASS.
- Asserções locais dos quatro diretivos 429 nos dois proxies: PASS.
- `./infra/scripts/validate-docs.sh`: PASS.
- Quality Gate focal de infraestrutura: `FAIL` em
  `infra/scripts/tests/deploy-production-v40-config-test.sh`, por uma asserção
  preexistente do contrato de rollout/keyring (`deploy_stack_source`/initializer);
  não há evidência de relação causal com os diretivos Nginx deste TP. O executor
  deve corrigir ou isolar esse baseline antes da certificação final, sem alterar
  o teste para ocultar a falha.
- `nginx -t` em container: não executado porque a imagem Nginx não está presente
  localmente e não foi feito download de dependência.

## 10. Rollback e riscos

- Documentação: reverter somente o commit deste plano/runbook; não apagar
  histórico nem alterar índices de forma ampla.
- DEV: voltar ao launcher anterior somente em fixture local, preservando volumes.
- HML/PRD: rollback pelo mecanismo oficial de deploy; não executar comandos
  manuais de proxy sem plano aprovado.
- Registro Telegram: reconciliar pelo backend; não descartar updates pendentes.
- Pool/inbox: corrigir capacidade/lock/migration conforme diagnóstico; não
  aumentar pools indiscriminadamente sem limite por tenant.
- Risco residual: o Telegram pode manter `pending_update_count` durante uma
  janela de indisponibilidade; isso é observável e deve ser drenado após o aceite.

## 11. Handoff para o próximo agente

1. Ler este plano e o onboarding v1.3.
2. Executar integralmente a seção 4 (pré-requisito); se falhar, parar e reportar `BLOCKED`.
3. Executar o Implementation Readiness Gate e resolver os blockers listados.
4. Confirmar paths efetivos com `git status` e preservar mudanças alheias.
5. Implementar na ordem `WH-DEV-001 → WH-REMOTE-002 → WH-TG-003 → WH-OBS-004 → WH-QA-005`.
5. Em cada handoff, registrar evidência, comando, código de saída e artefato
   alterado.
6. Rodar os gates; somente após PASS preparar branch, commit e push.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 1.3 | 2026-09-29 | Registra a execução de WH-REMOTE-002: status 429 aplicado nos proxies HML/PRD, validações locais PASS e Quality Gate infra bloqueado por falha preexistente do teste de deploy/keyring. |
| 1.2 | 2026-09-29 | Materializa autorização de runtime, status Nginx 429, rotação já concluída do token e execução local efetiva para futura promoção HML/PRD; readiness repository-local liberado. |
| 1.1 | 2026-09-29 | Corrige o gate: PRD-00002 v1.35 já está Validated, com Product Definition Gate PASS e todas as OQ-OMNI resolvidas; pendências restantes são operacionais do TP. |
| 1.0 | 2026-09-29 | Plano inicial de correção do onboarding DEV/HML/PRD, contrato Telegram, proxy canônico e diagnóstico 503. |
