---
document_id: API-SECURITY-STANDARD
primary_nature: Regra
objective: Definir controles verificáveis de segurança para APIs e serviços HTTP expostos ou consumidos.
scope: Autenticação, autorização de objeto/função/propriedade, schemas, rate control, business flows, SSRF, inventário, configuração, consumo de terceiros e evidência.
non_objectives: Não substituir contrato OpenAPI, API Client Standard, política de identidade, WAF, pentest ou configuração específica de gateway.
owner: Segurança, Arquitetura e Engenharia de Integração
status: Active
version: 1.0
date: 2026-09-28
last_reviewed: 2026-09-28
keywords: api-security, owasp-api, bola, idor, bfla, mass-assignment, ssrf, oauth2, a3
related_files: README.md, security-standard.md, application-security-standard.md, api-client-standard.md, software-quality-standard.md, iac-supply-chain-standard.md
code_references: N/A - gateway, identidade, contrato e comandos pertencem ao projeto adotante.
principal_statement: Toda API valida identidade, autorização, contrato e consumo de recursos no servidor, com testes negativos por objeto, função e propriedade e sem confiar no cliente como boundary de segurança.
---
# API Security Standard

## Ativação

Condicional à criação, alteração, publicação ou consumo de API HTTP/REST, GraphQL ou
serviço equivalente com boundary de rede.

## Referências de benchmark

Usar OWASP API Security Top 10 2023 para mapeamento de risco e OWASP ASVS 5.0.0
para requisitos verificáveis. Considerar explicitamente BOLA, broken authentication,
property-level authorization, resource consumption, function-level authorization,
sensitive business flows, SSRF, misconfiguration, inventory e unsafe consumption.
Referência externa: `https://api-security.owasp.org/editions/2023/en/0x11-t10/`.

## Regras

- Autorizar cada acesso a objeto por identidade, ownership, tenant, escopo ou regra
  de domínio aplicável; identificador recebido do cliente nunca prova autorização.
- Autorizar funções e operações privilegiadas independentemente da visibilidade da
  rota no frontend ou da presença de role no cliente.
- Aplicar allowlist de propriedades de entrada e saída. DTO/schema deve impedir mass
  assignment, over-posting e exposição de campo sensível.
- Validar token/sessão no boundary responsável: issuer, assinatura, expiração,
  audience quando aplicável e semântica de scopes/roles/capabilities.
- Definir limites de tamanho, paginação, frequência, concorrência, timeout e custo
  para proteger recursos e evitar consumo irrestrito.
- Proteger fluxos de negócio sensíveis contra automação e abuso conforme risco, sem
  depender apenas de rate limit genérico.
- Restringir URLs e destinos controláveis antes de chamadas server-side; proteger
  contra SSRF, redirects inesperados e resolução para destinos internos proibidos.
- Manter inventário de versões, hosts, operações e ambientes; remover ou isolar API
  obsoleta, debug, documentação e endpoint administrativo não intencional.
- Validar respostas de APIs de terceiros como entrada não confiável; aplicar timeout,
  limites, parsing seguro e política explícita de retry/idempotência.
- Diferenciar `401`, `403`, `404` e erros de domínio conforme contrato sem revelar
  existência ou detalhe sensível desnecessário.
- Não usar CORS como autorização e não aceitar origem, header ou claim do cliente
  como prova de privilégio.
- Mudança incompatível de contrato segue versionamento e migração do API Client Standard.

## Evidência e testes

Para operações sensíveis, manter testes negativos ao menos para:

- recurso pertencente a outra identidade/tenant;
- função administrativa por usuário sem privilégio;
- propriedades somente-servidor enviadas pelo cliente;
- token ausente, expirado, issuer/audience inválidos quando aplicável;
- limites de payload/paginação/consumo;
- destino externo proibido em chamada server-side;
- versão ou endpoint obsoleto quando parte do escopo.

Registrar contrato, operação, identidade, recurso, decisão de autorização e resultado.

## Resultado A3

Violação confirmada é `FAIL`; impossibilidade de comprovar controle obrigatório é
`BLOCKED`; ausência de finding confirmado com evidência completa é `PASS`.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.0 | 2026-09-28 | Cria standard especializado de segurança de APIs para o A3. |
