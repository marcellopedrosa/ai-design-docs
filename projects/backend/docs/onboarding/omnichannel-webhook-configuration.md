---
document_id: "ONBOARD-OMNICHANNEL-WEBHOOK"
primary_nature: "Regra"
objective: "Governar a configuração, validação e operação dos webhooks omnichannel em DEV, HML e PRD."
scope: "Endpoints Telegram e WhatsApp, proxy por ambiente, TLS, DNS, egress, autenticação e diagnóstico 401/429/503."
non_objectives: "Não utilizar ngrok em ambientes remotos (HML/PRD), não expor portas HTTP/8080 desprotegidas à internet e não alterar contratos de controllers."
owner: "DevOps e Integrações"
status: "Active"
date: "2026-09-29"
version: "1.4"
last_reviewed: "2026-10-02"
keywords: "onboarding, runbook, webhook, telegram, whatsapp, omnichannel, nginx, host-nginx, tls, producao, homologacao"
related_files: "docs/onboarding/production-vps-deployment.md, docs/adrs/ADR-0016-infrastructure-environment-provisioning.md, projects/backend/docs/prds/PRD-00002-omnichannel-experience.md, docs/onboarding/conversation-audit-keyring-provisioning.md, docs/onboarding/conversation-audit-hml-prd-onboarding.md, docs/delivery/plans/TP-00072-production-keyring-infra-request.txt"
code_references: "backend/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/presentation/rest/TelegramWebhookController.java, backend/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/application/usecase/RegisterTelegramWebhookUseCase.java, backend/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/application/usecase/AcceptInboundMessageUseCase.java, infra/proxy/nginx.prd.conf, infra/proxy/nginx.hml.conf, start-dev-bot.sh"
principal_statement: "DEV usa start-dev-bot.sh e túnel transitório quando necessário; HML e PRD usam exclusivamente o proxy Docker canônico, TLS público, autenticação de webhook e egress liberado."
---

# Configuração de webhooks omnichannel (DEV, HML e PRD)

Este runbook orienta engenheiros e agentes de infraestrutura na configuração, validação e resolução de problemas dos webhooks omnichannel (**Telegram** e **WhatsApp Cloud API**) nos ambientes de **Homologação (HML)** e **Produção (PRD)**, considerando o proxy Docker canônico definido pelos Compose e scripts de deploy.

---

## 1. Topologia e separação estrita de ambientes

Em desenvolvimento local (`./start-dev-bot.sh`), túneis como o `ngrok` são tolerados exclusivamente para expor portas locais transitórias. Em **Homologação** e **Produção**, **o uso de ngrok é terminantemente proibido**. A comunicação externa dos canais é roteada através do Nginx sob domínio público próprio com terminação TLS válida.

| Parâmetro | Desenvolvimento (DEV) | Homologação (HML) | Produção (PRD) |
| :--- | :--- | :--- | :--- |
| **Ingress de Webhook** | Túnel transitório (`ngrok`) | Nginx público com TLS | Nginx público com TLS |
| **FQDN Base da API** | Subdomínio dinâmico ngrok | `https://api-hml.contadorfiscal.com.br` | `https://api.contadorfiscal.com.br` |
| **Certificado TLS** | Gerido pelo ngrok | Let's Encrypt (Certbot) | Let's Encrypt (Certbot) |
| **Porta de Ingress** | Porta dinâmica ou 443 | `443/TCP` (proxy Docker canônico) | `443/TCP` (proxy Docker canônico) |
| **Encaminhamento** | `host.docker.internal:8080` | `http://backend:8080` (Docker bridge) | `http://backend:8080` (Docker bridge) |

---

## 2. Contratos de endpoints e autenticação

O backend expõe endpoints específicos implementados em [`TelegramWebhookController.java`](../../backend/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/presentation/rest/TelegramWebhookController.java) e [`WhatsAppWebhookController.java`](../../backend/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/presentation/rest/WhatsAppWebhookController.java):

### 2.1 Telegram Bot Webhook
- **Endpoint**: `POST /api/v1/telegram/webhook/{tenantId}/{botConfigId}`
- **Registro do Webhook**: Realizado pelo backend via API do Telegram (`https://api.telegram.org/bot<TOKEN>/setWebhook`).
- **Construção da URL**: Concatena `${APP_BASE_URL}/api/v1/telegram/webhook/${tenantId}/${botConfigId}`.
- **Autenticação**: O backend registra `secret_token` junto ao Telegram e exige `X-Telegram-Bot-Api-Secret-Token` com o mesmo valor. O `botConfigId` também deve pertencer ao tenant da URL.

### 2.2 WhatsApp Cloud API (Meta) Webhook
- **Handshake de Verificação**: `GET /api/v1/whatsapp/webhook`
  - A Meta envia: `hub.mode=subscribe`, `hub.challenge=<VALOR>` e `hub.verify_token=<TOKEN>`.
  - O backend compara `hub.verify_token` com `WHATSAPP_WEBHOOK_VERIFY_TOKEN`. Se coincidir, retorna status `200` com o body contendo exatamente o `hub.challenge`.
- **Recepção de Notificações**: `POST /api/v1/whatsapp/webhook`
  - A Meta envia o payload JSON assinado via HMAC-SHA256 no header `X-Hub-Signature-256`.
  - O backend valida a assinatura utilizando `WHATSAPP_WEBHOOK_APP_SECRET`. Assinatura divergente ou ausente é rejeitada com `401 Unauthorized`.

---

### 2.3 Pré-requisito criptográfico para Telegram em HML/PRD

Antes de registrar ou testar qualquer webhook Telegram remoto, a infraestrutura DEVE provisionar os três keyrings do Conversation Audit, montar os arquivos em `/run/saas-secrets` somente leitura e configurar as seis variáveis `CONVERSATION_*` no ambiente do backend. Sem esse gate, o endpoint pode responder `503` com `PERSISTENCE_UNAVAILABLE` antes de gravar o inbound; o Telegram então acumula updates e o Traffic Inspector não registra uma mensagem aceita.

A especificação canônica de geração, permissões, backup, rotação e montagem está em [conversation-audit-keyring-provisioning.md](conversation-audit-keyring-provisioning.md). O pedido operacional copiável para a Infra está em [TP-00072-production-keyring-infra-request.txt](../delivery/plans/TP-00072-production-keyring-infra-request.txt). Os IDs e caminhos esperados são:

```text
CONVERSATION_AUDIT_AES_ACTIVE_KEY_ID
CONVERSATION_AUDIT_AES_KEYRING_FILE=/run/saas-secrets/conversation-audit-aes-keyring.json
CONVERSATION_AUDIT_HMAC_ACTIVE_KEY_ID
CONVERSATION_AUDIT_HMAC_KEYRING_FILE=/run/saas-secrets/conversation-audit-hmac-keyring.json
CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID
CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE=/run/saas-secrets/conversation-outbound-attempt-hmac-keyring.json
```

O deploy só pode prosseguir quando os init services do Compose concluírem, o backend estiver saudável e os três arquivos forem legíveis pelo usuário do runtime. A perda da chave AES torna conversas cifradas ilegíveis; backup e rotação são responsabilidade da Infra.

## 3. Diagnóstico: Por que o webhook funcionou em DEV e falhou em Produção?

1. **Em DEV**: O `ngrok` ignora qualquer proxy do host e abre um túnel direto para a porta interna do container, terminando TLS por conta própria.
2. **Em PRD/HML (Nginx Pré-existente no Host)**:
   - Se a VPS já possuía um Nginx ativo nativamente (`systemctl status nginx`), as portas `80` e `443` pertencem ao processo do sistema operacional da VPS, não ao Docker.
   - Requisições externas da Meta e do Telegram bateram no **Nginx do Host**, que descartou a rota com `404`, `502` ou página padrão do Nginx, pois o host não possuía o virtual host de `api.contadorfiscal.com.br` configurado para encaminhar o tráfego ao backend da aplicação.
3. **`APP_BASE_URL` incorreto**: Use a origem pública canônica, sem `/api` e preferencialmente sem barra final. A aplicação normaliza a barra, portanto ela isoladamente não é causa suficiente de falha.
4. **Cadeia TLS incompleta**: O Certbot precisa fornecer `fullchain.pem`. Certificados intermediários ausentes são rejeitados pelas plataformas.
5. **Egress bloqueado**: O container backend necessita de saída HTTPS (porta 443) para `api.telegram.org` e `graph.facebook.com`.

---

## 4. Arquitetura do proxy por ambiente

O agente de infraestrutura deve seguir o proxy canônico do ambiente. A implantação oficial de HML/PRD usa o serviço `proxy` dos Compose e valida o container antes do tráfego externo.

### 4.1 Verificação de conflito de portas

Execute na VPS para inspecionar qual processo controla as portas `80` e `443`:

```bash
# Verificar processos escutando nas portas web
sudo ss -tulpn | grep -E ":80|:443"

# Verificar se o Nginx nativo do sistema está ativo
sudo systemctl status nginx
```

---

### 4.2 Compose e proxy por ambiente

- HML: `docker-compose.hml.yml` cria `saas-proxy-hml` com `infra/proxy/nginx.hml.conf`.
- PRD: `docker-compose.prd.yml` cria `saas-proxy-prd` com `infra/proxy/nginx.prd.conf`; `deploy-production.sh` recria, testa e recarrega o proxy.
- DEV: `./start-dev-bot.sh` sobe o backend local; para Telegram externo, use somente `start-dev-bot-exposed-ngrok.sh`.

Nginx nativo no host ocupando 80/443 bloqueia o rollout canônico. Não desabilite nem reconfigure o host automaticamente; escale o conflito ao owner de infraestrutura.

---

## 5. Diretivas críticas do Nginx para Webhooks

No proxy Docker canônico, as seguintes diretivas são obrigatórias:

1. **Preservação de `X-Hub-Signature-256`**:
   - A Meta envia a assinatura HMAC no header `X-Hub-Signature-256`. O Nginx não pode filtrar ou anular esse cabeçalho.
2. **Integridade Absoluta do Raw Body**:
   - A assinatura do WhatsApp é verificada contra o stream de bytes brutos do corpo da requisição. Qualquer alteração ou descompressão causa `401 Unauthorized`.
3. **Preservação de Query Parameters no Handshake (`GET`)**:
   - `hub.mode`, `hub.challenge` e `hub.verify_token` devem passar intactos para o backend.
4. **Dimensionamento de `client_max_body_size`**:
   - Deve ser de no mínimo `6m` para suportar metadados e payloads volumosos sem erro `413`.
5. **Calibração de Rate Limiting com `burst`**:
   - Manter `burst=60 nodelay`. Quando o limite de requisições ou conexões é excedido, o Nginx pode responder `503` por padrão. Só documente `429` se `limit_req_status`/`limit_conn_status` estiverem configurados explicitamente.
6. **Redirecionamento com HTTP 308 (não 301)**:
   - Preserva o método `POST` e o corpo caso o emissor faça a requisição inicial em HTTP puro.
7. **Cadeia Completa TLS (`fullchain.pem`)**:
   - O arquivo de certificado deve conter a cadeia completa com certificados intermediários.

---

## 6. Procedimento de ativação passo a passo

### Passo 0: Gate obrigatório de persistência durável

1. Provisionar os três keyrings e seus backups conforme o runbook de criptografia.
2. Injetar as seis variáveis `CONVERSATION_*` no ambiente HML/PRD; não usar valores vazios, defaults ou material em imagem.
3. Executar o fluxo canônico (`docker-compose.hml.yml`/`docker-compose.prd.yml` com os init services e `deploy-production.sh`). Um `docker run` direto que não monte `/run/saas-secrets` é não-conforme e bloqueia o onboarding.
4. Confirmar health do backend e ausência de `PERSISTENCE_UNAVAILABLE`, `Inbound durable acceptance unavailable`, `HikariPool` e `CannotCreateTransactionException`.

Somente após esse gate devem ser configurados DNS/TLS, reconciliado o webhook pelo backend e enviados testes externos.

### Passo 1: Variáveis de ambiente na VPS
No arquivo de ambiente (`/opt/saas-service/.env` ou arquivo de override correspondente):

```bash
# PRD
APP_BASE_URL=https://api.contadorfiscal.com.br
WHATSAPP_WEBHOOK_VERIFY_TOKEN=seu_verify_token_seguro_producao
WHATSAPP_WEBHOOK_APP_SECRET=seu_app_secret_meta_producao

# HML
APP_BASE_URL=https://api-hml.contadorfiscal.com.br
WHATSAPP_WEBHOOK_VERIFY_TOKEN=seu_verify_token_seguro_homologacao
WHATSAPP_WEBHOOK_APP_SECRET=seu_app_secret_meta_homologacao
```

> **Atenção**: `APP_BASE_URL` não pode ter barra no final (`/`) e nem paths como `/api`.

### Passo 2: Configuração do WhatsApp no Meta Developers Dashboard
1. Acesse **Meta for Developers** > Seu Aplicativo > **WhatsApp** > **Configuration**.
2. No bloco **Webhook**, clique em **Edit**:
   - **Callback URL**: `https://api.contadorfiscal.com.br/api/v1/whatsapp/webhook`
   - **Verify Token**: O valor de `WHATSAPP_WEBHOOK_VERIFY_TOKEN`.
3. Clique em **Verify and Save**. A Meta fará um handshake `GET` imediato (espera retorno `200` com o body do challenge).
4. Em **Webhook fields**, assine `messages`.

### Passo 3: Registro do Telegram Bot
O backend registra e reconcilia o webhook automaticamente, incluindo `secret_token`. Não use `setWebhook` manual para operação normal: isso pode sobrescrever o segredo e causar `401`. Para uma exceção aprovada, execute a reconciliação pela API do próprio backend.

Nunca exponha o token do bot em linha de comando, histórico ou logs. Se uma consulta direta for indispensável, use um mecanismo de segredo fora do histórico e remova o valor da memória ao terminar.

---

## 7. Roteiro de testes e validação

### 7.1 Teste do Handshake do WhatsApp (GET)
Execute a partir de uma máquina externa:

```bash
CHALLENGE_TEST="test_challenge_12345"
VERIFY_TOKEN="seu_verify_token_seguro_producao"

curl -i -X GET "https://api.contadorfiscal.com.br/api/v1/whatsapp/webhook?hub.mode=subscribe&hub.challenge=${CHALLENGE_TEST}&hub.verify_token=${VERIFY_TOKEN}"
```

**Resultado esperado**:
- HTTP Status: `200 OK`
- Response Body: `test_challenge_12345`

### 7.2 Teste de Conexão com Telegram
A consulta deve ser feita pela interface ou procedimento seguro de operação; não coloque o token literal no histórico do shell.

**Resultado esperado**:
- `"url"`: `https://api.contadorfiscal.com.br/api/v1/telegram/webhook/...`
- `"has_custom_certificate"`: `false`
- `"last_error_message"`: ausente ou nulo

---

## 8. Diagnóstico e logs operacionais

1. **Logs do proxy Docker**:
   ```bash
   sudo docker logs --timestamps --since "<inicio>" --until "<fim>" saas-proxy-hml 2>&1 | grep -E -i -C 5 "webhook|limiting requests|limiting connections|upstream|503"
   sudo docker logs --timestamps --since "<inicio>" --until "<fim>" saas-proxy-prd 2>&1 | grep -E -i -C 5 "webhook|limiting requests|limiting connections|upstream|503"
   ```

2. **Logs do backend**:
   ```bash
   sudo docker logs --timestamps --since "<inicio>" --until "<fim>" saas-backend 2>&1 | grep -E -i -C 8 "Inbound durable acceptance unavailable|PERSISTENCE_UNAVAILABLE|HikariPool|SQLTransientConnectionException|CannotCreateTransactionException|InboundInboxBusyException|omnichannel_inbound_events"
   ```
   `PERSISTENCE_UNAVAILABLE`, Hikari, lock ou transação indicam falha de persistência do inbox durável; `limiting requests/connections` no proxy indica rejeição antes do backend. Em ambos os casos, preserve o intervalo de tempo e o `errorId`.

3. **Auditoria de Webhook via API**:
   - `GET /api/v1/tenant/chatbot/webhook-logs`

---

## 10. Plano de correção e aceite por ambiente

| Ambiente | Correção | Evidência de aceite |
| :--- | :--- | :--- |
| DEV | Subir com `./start-dev-bot.sh`; usar ngrok somente pelo launcher exposto e manter a URL transitória isolada. | `getWebhookInfo` aponta para a URL DEV atual; mensagem de teste chega e o backend registra o aceite durável. |
| HML | Usar `docker-compose.hml.yml` e `saas-proxy-hml`; validar TLS, DNS, egress, `X-Telegram-Bot-Api-Secret-Token` e handshake Meta. | Smoke POST/GET retorna status esperado; proxy e backend não registram 503; `pending_update_count` permanece controlado. |
| PRD | Usar `docker-compose.prd.yml` e `deploy-production.sh`; não usar Nginx host nem ngrok; registrar webhook somente pelo backend. | Smoke do deploy passa, `getWebhookInfo` sem erro recente, logs sem rejeição do proxy e inbox durável processando mensagens. |

A mudança é considerada concluída somente quando os três ambientes possuem o mesmo contrato de autenticação e diagnóstico, sem token exposto e sem procedimento manual que sobrescreva `secret_token`.

## 9. Checklist de prontidão (Go-Live)

- [ ] DEV iniciado por `./start-dev-bot.sh`; túnel externo somente pelo launcher governado.
- [ ] HML/PRD usam o proxy Docker canônico, sem conflito de portas com Nginx nativo.
- [ ] Gate criptográfico concluído: três keyrings montados em `/run/saas-secrets`, seis `CONVERSATION_*` configuradas, init services concluídos e backup confirmado.
- [ ] Telegram registrado pelo backend com `secret_token` e header validado.
- [ ] Portas 80 e 443 sem conflito entre Host Nginx e Docker.
- [ ] Bloco `api.contadorfiscal.com.br` no Nginx configurado com `proxy_set_header X-Forwarded-Proto https`.
- [ ] Rate limit com `burst=60 nodelay` configurado; `limit_req_status 429` e `limit_conn_status 429` estão presentes; 503 é tratado como falha de upstream/backend.
- [ ] Header `X-Hub-Signature-256` e Raw Body repassados sem alteração.
- [ ] `APP_BASE_URL` canônica configurada sem barra final.
- [ ] Certificado Let's Encrypt ativo e válido (`fullchain.pem`).
- [ ] Egress liberado do container para `api.telegram.org:443` e `graph.facebook.com:443`.
- [ ] Handshake do WhatsApp aprovado no Meta App Dashboard.
- [ ] `getWebhookInfo` do Telegram aponta para a URL canônica, sem erro recente e com `pending_update_count` acompanhado.
- [ ] Em caso de 503, foram diferenciados proxy (limiting/upstream) e backend (PERSISTENCE_UNAVAILABLE/Hikari/lock).
- [ ] Token do bot não foi exposto; se exposto, foi rotacionado no BotFather.
