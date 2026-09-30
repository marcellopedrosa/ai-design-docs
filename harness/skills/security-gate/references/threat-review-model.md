# Modelo de Revisão de Ameaças e Superfície de Ataque

Este documento orienta a análise agnóstica de superfícies expostas, fronteiras de confiança e fluxos de dados durante o subgate A3.

## 1. Delimitação de Trust Boundaries (Fronteiras de Confiança)

Em qualquer arquitetura (monolítica, modular, microsserviços, serverless), identifique:
1. **Entrada de dados não confiável**:
   - Parâmetros de query, body JSON/XML, headers HTTP, cookies, payloads de webhook, mensagens de filas/tópicos (Kafka, RabbitMQ), uploads de arquivos.
2. **Ponto de entrada (Source)**:
   - Controller web, handler de função, listener de mensageria, endpoint GraphQL/REST.
3. **Ponto crítico de consumo (Sink)**:
   - Queries SQL/NoSQL, renderização HTML/DOM, comandos de sistema operacional (`exec`, `spawn`), desserialização de objetos, redirecionamentos HTTP, envio de e-mails, chamadas HTTP externas (SSRF).
4. **Camada intermediária de validação**:
   - DTOs com Bean Validation, schemas Zod/Joi, sanitizers, camadas de serviço de autorização.

## 2. Ações Privilegiadas e Autorização

Para toda ação modificadora (POST, PUT, DELETE, PATCH):
1. **Identidade**: Quem executa a requisição? Token JWT válido, sessão ativa ou anônimo?
2. **Autorização Funcional**: O papel (Role) ou escopo do usuário tem autorização para disparar este comando?
3. **Autorização de Recurso**: O identificador do recurso alvo (ex: `/api/orders/{id}`) pertence de fato ao usuário autenticado ou à sua organização/tenant?
4. **Mutação em Massa**: O endpoint aceita campos que o usuário não deveria poder alterar (ex: `role=ADMIN`, `isVerified=true`) por falta de DTO restritivo?

## 3. Dados Sensíveis e Proteção

1. Segredos nunca residem no código-fonte, nos arquivos de configuração versionados ou nos logs da aplicação.
2. Dados protegidos por privacidade (PII, tokens, senhas, chaves) devem ser mascarados ao trafegar ou serem gravados em traces de telemetria.
3. Validação de transporte seguro (HTTPS/TLS) e cookies com atributos `Secure`, `HttpOnly` e `SameSite`.
