---
document_id: SPRING-SECURITY-STANDARD
primary_nature: Regra
objective: Definir controles portáteis de segurança para aplicações Java que adotem Spring Boot e Spring Security.
scope: SecurityFilterChain, autorização, method security, OAuth2/OIDC/JWT, sessão, CSRF, CORS, headers, Actuator, persistência, DTOs, outbound HTTP, upload, configuração e testes.
non_objectives: Não ativar Spring, escolher versão, IdP, política de roles, build tool, banco, scanner ou arquitetura do projeto.
owner: Segurança, Engenharia Java e Arquitetura
status: Active
version: 1.0
date: 2026-09-28
last_reviewed: 2026-09-28
keywords: spring-security, spring-boot, java, oauth2, oidc, jwt, authorization, csrf, actuator, a3
related_files: README.md, security-standard.md, application-security-standard.md, api-security-standard.md, java-standard.md, backend-testing-standard.md, api-client-standard.md
code_references: N/A - versões, beans, endpoints, issuer e comandos pertencem ao projeto adotante.
principal_statement: Quando Spring Security estiver ativo, regras HTTP e de método são explícitas, deny-by-default e coerentes com o modelo de identidade, enquanto autorização de recurso permanece no boundary de domínio/serviço que possui o dado.
---
# Spring Security Standard

## Ativação

Condicional a módulo Spring Boot/Spring Security registrado no manifesto, ADR ou
configuração do projeto.

## Regras

- Manter configuração de `SecurityFilterChain` explícita e testável. Rotas públicas
  são allowlist estreita; regra final deve negar ou autenticar por padrão conforme o
  contrato, nunca liberar por ausência de matcher.
- Tratar autenticação e autorização separadamente. Endpoint autenticado ainda exige
  autorização de função, recurso, tenant e propriedade quando aplicável.
- Usar method security (`@PreAuthorize` ou mecanismo equivalente) somente onde
  apropriado e testar bypass por chamadas internas/alternativas; autorização não
  pode depender apenas do controller.
- Para Resource Server/OAuth2/OIDC/JWT, validar criptograficamente o token e os
  metadados exigidos pelo contrato, incluindo issuer, expiração e audience quando
  aplicável. Decodificar JWT não equivale a validar JWT.
- Mapear scopes, roles e claims para capabilities do domínio de forma centralizada,
  explícita e deny-by-default; claim desconhecida não concede autoridade.
- Configurar sessão, cookie, CSRF e logout conforme o modelo real. Desabilitar CSRF
  requer evidência de API stateless sem credencial ambiente do browser ou outra
  justificativa equivalente.
- Configurar CORS como política de browser com allowlist necessária; CORS nunca é
  substituto de autorização.
- Não desabilitar headers de segurança globalmente sem requisito e controle
  compensatório documentados.
- Restringir Actuator, debug, Swagger/OpenAPI UI e endpoints administrativos por
  ambiente e privilégio; não expor detalhes internos desnecessários.
- Persistência usa parâmetros/bindings seguros. Uso de repository/JPA não prova
  segurança quando JPQL/HQL/SQL é montado dinamicamente com entrada controlável.
- DTOs de entrada aplicam allowlist de campos e validação no servidor; não bindar
  diretamente entidade persistente em operação sensível quando isso permitir
  mass assignment ou alteração de campo controlado pelo servidor.
- `WebClient`, `RestClient` ou cliente equivalente valida destinos controláveis,
  timeout, redirects, tamanho e resposta conforme o API Security Standard.
- Upload multipart valida autorização, tamanho, tipo, nome/path e armazenamento;
  conteúdo do usuário não define caminho executável ou arbitrário do servidor.
- Deserialização, SpEL, templates, reflection e execução dinâmica não recebem dado
  não confiável sem controle específico e justificativa.
- Segredos e credenciais vêm do mecanismo aprovado do projeto e nunca aparecem em
  source, log, exception, fixture ou configuração versionada.
- Erros de autenticação/autorização preservam semântica segura e não expõem stack,
  token, claim sensível ou internals.

## Evidência e testes

Usar o stack de testes registrado pelo projeto e demonstrar, quando aplicável:

- rota pública versus protegida e fallback deny-by-default;
- usuário autenticado sem autoridade;
- acesso cross-user/cross-tenant;
- token ausente, expirado e claims/metadados inválidos;
- método protegido por caminho alternativo;
- CSRF conforme o modelo de sessão;
- CORS sem confundir compartilhamento com autorização;
- Actuator/admin sem privilégio;
- query dinâmica, mass assignment, SSRF e upload em paths afetados.

Não exigir annotation, biblioteca ou padrão específico quando outra implementação
provar o mesmo controle de forma verificável.

## Resultado A3

Violação confirmada é `FAIL`; falta de evidência necessária é `BLOCKED`; controles
aplicáveis demonstrados sem finding confirmado resultam em `PASS`.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.0 | 2026-09-28 | Cria standard Spring Security condicional e agnóstico de versão. |
