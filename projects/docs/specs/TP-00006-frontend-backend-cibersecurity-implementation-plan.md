---
document_id: "TP-00006"
primary_nature: "Plano"
objective: "Reduzir de forma verificável a superfície de ataque do frontend, backend, identidade, persistência, integrações, containers e pipeline de entrega. O plano traduz os achados do RPT-0004 em controles implementáveis, critérios de aceite, sequência de rollout e rollback."
scope: "Coordenacao de Implementation Plan de Cibersegurança Frontend e Backend nos componentes, fases, dependencias e verificacoes explicitamente descritos no plano."
non_objectives: "N/A - o documento original nao explicita nao-objetivos adicionais."
owner: "Engenharia"
status: "In Progress"
date: "2026-08-13"
version: "1.0"
keywords: "plano, coordenacao, frontend, backend, cibersecurity"
related_files: "docs/delivery/plans/README.md"
code_references: "backend/src/main, frontend/src, OutboundUrlPolicy, TenantContext, /api/v1/tenants/{uuid}, validate-realm-token-contracts.sh, DebugQueryController, DebugRunner, shared/crypto/secure, String, System.out, TenantContextHolder"
principal_statement: "Coordena controles e remediações de cibersegurança cross-stack."
---

# TP-00006 — Implementation Plan de Cibersegurança Frontend e Backend

**Document ID:** `TP-00006`  

**Estado:** implementado no repositório e validado localmente; ações operacionais externas em andamento
**Data:** 13/08/2026  
**Ultima atualizacao:** 14/08/2026
**Relatório associado:** `docs/delivery/reports/RPT-0004-frontend-backend-cibersecurity.md`
**Responsáveis sugeridos:** Security Agent, Backend Agent, Frontend Agent, DevOps/SRE e responsável por risco  
**Criticidade da mudança:** alta; contém migrations, mudança de chaves, Keycloak e fronteiras de autorização

## 1. Objetivo

Reduzir de forma verificável a superfície de ataque do frontend, backend, identidade, persistência, integrações, containers e pipeline de entrega. O plano traduz os achados do RPT-0004 em controles implementáveis, critérios de aceite, sequência de rollout e rollback.

Os mesmos IDs `SEC-001` a `SEC-024` são usados neste documento e na tabela do relatório. Nenhum item pode ser marcado como concluído apenas por alteração de código: os critérios de aceite e, quando aplicável, as ações operacionais também precisam de evidência.

## 2. Referenciais E Meta De Controle

- OWASP Top 10:2025 para riscos de aplicação web.
- OWASP API Security Top 10:2023 para BOLA, autenticação, consumo de recursos, SSRF e inventário.
- OWASP ASVS 5.0.0 como catálogo de requisitos verificáveis.
- NIST SSDF 1.1 para desenvolvimento, build, dependências, revisão e resposta a vulnerabilidades.
- NIST CSF 2.0 para governança, proteção, detecção e recuperação.
- LGPD para minimização, confidencialidade, rastreabilidade e descarte de dados pessoais.

Meta: zero achado crítico ou alto aberto antes de produção. Exceções operacionais exigem aceite formal, prazo, owner e controle compensatório.

## 3. Escopo

Incluído:

- `backend/src/main`, migrations e testes de segurança.
- `frontend/src`, configuração Next.js, testes e dependências.
- Keycloak realms e provisionamento dinâmico.
- Dockerfiles, Docker Compose, NGINX e observabilidade.
- GitHub Actions, SBOM, scanners e deploy.
- Backup lógico criptografado e restore drill.

Não incluído nesta execução local:

- Contas, IAM, firewall e KMS do provedor cloud.
- Pentest ativo contra produção.
- Configuração real de DNS, certificados e WAF.
- Reescrita destrutiva do histórico Git.
- Rotação de credenciais em provedores externos.
- Execução de restore em banco real.

## 4. Princípios Arquiteturais

1. **Deny by default:** ausência de tenant, secret, issuer, assinatura ou allowlist resulta em falha, nunca em fallback permissivo.
2. **Defense in depth:** RBAC em controller, filtro transversal de tenant, validação JWT e roteamento de datasource são controles independentes.
3. **Clean Architecture:** regras de idempotência e autorização ficam em ports/use cases; Redis, JPA, HTTP e Keycloak ficam em adapters de infraestrutura.
4. **Single Responsibility:** criptografia, SSRF, rate limit, body limit, redaction e tenant boundary possuem componentes dedicados.
5. **Open/Closed:** novas integrações reutilizam `OutboundUrlPolicy`, converters e filtros sem duplicar validações frágeis.
6. **Interface Segregation:** idempotência Stripe e criptografia de certificado/tenant usam ports específicos.
7. **Least privilege:** cada papel, client OIDC, container e workflow recebe somente a permissão necessária.
8. **No secret in source/log/URL:** segredo vem de secret manager/arquivo protegido e nunca de query string.
9. **Authenticated encryption:** dados confidenciais usam AES-GCM versionado com nonce aleatório e key ID.
10. **Immutable delivery:** build produz imagem identificada por digest, SBOM e provenance; produção não recompila código.

## 5. Matriz Mestra

| ID | Frente principal | Correção planejada e executada | Estado no repositório | Dependência externa |
|---|---|---|---|---|
| SEC-001 | Backend | Bloquear BOLA por comparação de tenant da rota com claim autenticada. | Concluído | Teste DAST multi-tenant |
| SEC-002 | Backend/Auth | Restringir issuer, audience, authorized party, roles e cache JWT; separar token global sem tenant de token tenant com UUID. | Concluído e validado no dev local | Migrar realms e renovar sessões em HML/PRD |
| SEC-003 | Backend | Remover debug e aplicar RBAC/Actuator mínimo. | Concluído | Validar dashboards em HML |
| SEC-004 | Plataforma | Retirar segredos/fallbacks e artefatos do Git. | Concluído no HEAD | Rotação e saneamento do histórico |
| SEC-005 | Backend | Migrar criptografia para AES-256-GCM versionado e chaves separadas. | Concluído | Provisionar chaves novas/legadas |
| SEC-006 | Backend/Data | Criptografar PII, mensagens, contexto, notificações e PDFs em repouso. | Concluído | Backup e observar migration runner |
| SEC-007 | Backend/Identity | Hash, expiração, uso único e política de senha para convites. | Concluído | Invalidar convites antigos |
| SEC-008 | Keycloak | PKCE, bearer-only, origins minimas, sem users/secrets, Service Account por Client Credentials e onboarding com compensacao integral. | Concluido no repositorio e no dev local | Backup e rollout HML/PRD |
| SEC-009 | Backend | Allowlist central para URLs de provedores e bloqueio SSRF. | Concluído | Configurar origins privadas autorizadas, se houver |
| SEC-010 | Backend/Webhooks | Assinaturas obrigatórias, secrets fora da URL e masking. | Concluído | Re-registrar webhooks Telegram |
| SEC-011 | Backend/Stripe | Assinatura fail-closed e idempotência Redis. | Concluído | Teste com Stripe CLI/HML |
| SEC-012 | Transporte | Trust store padrão, TLS NGINX, logs sem query e headers confiáveis. | Concluído no repo | Certificados e DNS reais |
| SEC-013 | Backend/Logs | Redaction, error ID, metadados mínimos e purge histórico. | Concluído | Política de retenção no Loki |
| SEC-014 | Backend/DoS | Rate/body/upload/page/header limits e validação PKCS#12. | Concluído | Teste de carga controlado |
| SEC-015 | Frontend/Auth | SSE com Authorization header; nenhum bearer em query. | Concluído | Teste por proxy HML |
| SEC-016 | Frontend/XSS | Escapar notificação e validar cor/estilo. | Concluído | DAST/XSS em HML |
| SEC-017 | Frontend/Nav | Bloquear protocolo/origin perigosa e tabnabbing. | Concluído | Teste Stripe HML |
| SEC-018 | Frontend | Desativar mocks/debug em produção e remover tela de token. | Concluído | Smoke build production |
| SEC-019 | Browser/API | CORS explícito, CSP nonce e security headers. | Concluído | Ajustar CSP somente por necessidade comprovada |
| SEC-020 | Backend/AuthZ | Tenant context fail-closed, usuário por tenant e RBAC mínimo. | Concluído | Matriz de perfis em HML |
| SEC-021 | Supply chain | Atualizar deps, fixar actions/imagens, Gitleaks, SBOM/Trivy e impedir que `.gitignore` oculte source ports. | Concluido | Executar workflow no GitHub |
| SEC-022 | DevSecOps | Containers mínimos e deploy por digest com aprovação. | Concluído no repo | Proteger environment `production` |
| SEC-023 | Observabilidade | Perfil `prd` correto e receiver por Docker secret. | Concluído no repo | Secret real e alerta sintético |
| SEC-024 | Recovery | Backup criptografado, S3/KMS e restore temporário verificável. | Automação concluída | Bucket, KMS, agenda e drill |

## 6. Plano Backend

### SEC-001 - Isolamento Tenant E BOLA

**Problema:** endpoints com UUID de tenant aceitam um identificador controlado pelo cliente. Apenas confiar em `TenantContext` ou em repositories individuais permite regressão quando um controller novo esquece a validação.

**Implementação:**

- Interceptar rotas `/api/v1/tenants/{uuid}` antes do controller.
- Extrair UUID de forma estrita e rejeitar valor inválido.
- Comparar com `tenant_id` canônico do JWT.
- Autorizar bypass apenas quando a autenticação já foi classificada como Super Admin do realm `saas-admin`.
- Nunca aceitar header de tenant como fonte de verdade para usuário tenant.

**Critérios de aceite:** tenant A recebe `403` ao usar UUID do tenant B; UUID inválido recebe erro controlado; Super Admin válido mantém operações administrativas; requisição sem claim tenant falha fechada.

**Rollback:** não remover o filtro. Se uma rota legítima global quebrar, movê-la para namespace administrativo explícito e protegê-la por Super Admin.

### SEC-002 - Cadeia De Confiança JWT

**Problema:** conteúdo do token não verificado não pode decidir livremente qual decoder/issuer será confiado. Claims incompletas permitem token confusion e escalada entre realms.

**Implementação:**

- Decodificar somente o payload mínimo para roteamento, com tamanho máximo.
- Exigir issuer sob origins configuradas e realm com regex estrita.
- Construir decoder apenas para issuer exato e armazená-lo em cache limitado.
- Exigir `aud` da API e `azp` em lista de clients conhecidos.
- Configurar o mapper `oidc-audience-mapper` no cliente SPA de todos os realms e templates para emitir `aud=saas-service-api` no access token.
- Tratar claim `aud` ausente como falha de autenticação controlada, sem exceção não tratada ou resposta HTTP 500.
- Mapear roles somente após validação criptográfica.
- Exigir UUID em `tenant_id` para qualquer role tenant.
- Descartar `ROLE_SUPER_ADMIN` fora do realm administrativo.
- Rejeitar `ROLE_SUPER_ADMIN` quando o token carregar qualquer `tenant_id`.
- Remover mappers de tenant de todos os clients do `saas-admin` e manter exatamente um mapper hardcoded no SPA de cada realm tenant.
- Para Super Admin, criar contexto tenant somente por `X-Tenant-ID` canônico, existente e ativo; nunca usar a claim como fallback.
- Migrar realms persistidos pela Admin API e exigir renovação de sessões após alterar protocol mappers.
- Executar `validate-realm-token-contracts.sh` no Security CI para impedir drift entre os tipos de realm.
- Proibir token por query string.

**Critérios de aceite:** rejeitar issuer parecido, host alternativo, audience ausente, `azp` desconhecido, tenant não UUID, Super Admin de tenant realm e Super Admin com `tenant_id`. A ausência de audience deve resultar em 401, nunca 500. Token real do `saas-admin` deve conter `ROLE_SUPER_ADMIN`, `aud=saas-service-api`, `azp=saas-frontend-spa` e nenhuma claim tenant. Token de realm tenant deve carregar UUID canônico. Impersonação requer header validado.

### SEC-003 - Inventário De Endpoints E RBAC

**Implementação:** remover `DebugQueryController` e `DebugRunner`; proteger configurações globais e logs; publicar somente health sem autenticação; exigir Super Admin para Actuator restante; reduzir dashboards, clientes, fiscal e métricas conforme matriz de papel.

**Critérios de aceite:** varredura de controllers não encontra debug público; usuário anônimo recebe `401` fora da allowlist; Tenant User não altera cliente/certificado/configuração; health continua disponível sem detalhes sensíveis.

### SEC-005 - Criptografia Versionada

**Formato:** prefixo de versão, key ID, nonce aleatório de 96 bits e ciphertext/tag AES-GCM. Chaves precisam de pelo menos 256 bits de entropia e não podem ser compartilhadas entre domínio de convite, notificação, dados gerais, LLM, certificado, tenant e canais.

**Implementação:**

- Centralizar primitivas em `shared/crypto/secure`.
- Validar tamanho/ausência da chave no startup.
- Nunca retornar plaintext quando decrypt falha.
- Reconhecer legado somente por marcador explícito.
- Usar runner de recriptografia idempotente depois das migrations.
- Registrar contagens de migração sem conteúdo sensível.

**Critérios de aceite:** encrypt do mesmo plaintext produz ciphertext diferente; alteração de qualquer byte falha; chave errada falha; novo formato round-trip; fixtures legadas explícitas migram uma única vez.

**Rollout:** definir todas as chaves novas e legadas, executar backup, implantar uma instância, acompanhar runner, verificar ausência de marcadores legados e só então escalar réplicas.

**Rollback:** manter binário anterior e chaves anteriores durante a janela. Depois que dados forem gravados no formato novo, rollback para código incapaz de AES-GCM não é seguro; restaurar backup ou usar release compatível com ambos os formatos.

### SEC-006 - Dados Sensíveis Em Repouso

**Campos cobertos:** conteúdo de mensagem, contexto e documento selecionado da conversa, destinatário/mensagem de notificação, PDF fiscal, resumo de consulta e segredos de provedores/canais/certificados.

**Implementação:** converters separados para `String`, `byte[]` e `Map<String,String>`; migrations marcam plaintext/ciphertext legado; runner percorre banco da plataforma e bancos tenant; migrations de purge removem payloads antigos de tráfego.

**Critérios de aceite:** consultas SQL não mostram conteúdo legível nos campos convertidos; aplicação lê dados após restart; registros novos têm prefixo atual; falha de chave impede startup/leitura silenciosa.

**Observação:** identificadores usados em busca exata permanecem normalizados no banco quando a funcionalidade exige índice. Migração futura deve usar blind index/HMAC antes de criptografar tais colunas.

### SEC-007 - Convites E Senhas

**Implementação:** token de 32 bytes aleatórios; SHA-256 armazenado no atributo gerenciado `invite_token`; payload criptografado inclui token, epoch de expiração e realm; TTL de 1 a 168 horas; busca pelo hash; consumo antes de resetar senha; bloqueio concorrente por hash; remoção do atributo; senha de 12 a 128 caracteres no backend/frontend/Keycloak; redaction em notificação e logs.

**Critérios de aceite:** token expirado, usado, adulterado, de realm inválido ou sem separadores retorna resposta genérica; duas ativações concorrentes têm no máximo um sucesso; banco/Keycloak/logs não contêm token bruto.

**Compatibilidade:** convites emitidos no formato anterior devem ser revogados e reenviados. Não criar fallback para token legado inseguro.

### SEC-009 - SSRF E Consumo De APIs

**Implementação:** validar URL como origin; HTTPS por padrão; host exato em allowlist; bloquear user-info, query de credencial, fragmento, IP literal, loopback, link-local e metadata; aplicar a todos os caminhos LLM; enviar API key Gemini em header; permitir HTTP somente por flag explícita e allowlist para ambiente local isolado.

**Critérios de aceite:** `file:`, `gopher:`, IP privado, `169.254.169.254`, host com sufixo enganoso e credencial na URL são rejeitados; origins oficiais configuradas funcionam.

### SEC-010 - Webhooks De Mensageria

**Telegram:** gerar secret server-side, armazenar cifrado, URL somente com tenant/config UUID, exigir `X-Telegram-Bot-Api-Secret-Token`, comparar em tempo constante, vincular tenant e config, não retornar token/secret completos e re-registrar webhook após mudança.

**WhatsApp:** exigir app secret/verify token sem fallback, tamanho mínimo, assinatura `sha256=` com 64 hex chars, HMAC SHA-256 sobre payload bruto e comparação de bytes constante.

**Critérios de aceite:** segredo ausente/incorreto retorna `401`; config de outro tenant não processa; logs não incluem payload/token; secrets mascarados não sobrescrevem valor existente em updates.

### SEC-011 - Stripe

**Implementação:** webhook secret obrigatório; verificar assinatura antes de parse/processar; não registrar header; adquirir idempotency key Redis por event ID antes dos efeitos; manter TTL de 30 dias; falhar sem executar efeito se Redis/assinatura estiverem indisponíveis conforme política do use case.

**Critérios de aceite:** evento sem assinatura ou repetido não altera estado; mesmo evento concorrente produz um efeito; evento novo válido continua processando.

### SEC-013 - Logging E Erros

**Implementação:** allowlist de headers, metadados de tamanho/status/tempo, nenhuma leitura ou persistência do response body SERPRO, sanitização central, purge por migration, PII masking, mensagem externa genérica e `errorId`; stack trace somente no log interno; remover `System.out`, payload GERARDAS12 e testes manuais com dados reais. No frontend, resolver mensagens de erro em um componente central, priorizar mensagens de negócio controladas e nunca usar o corpo HTTP bruto como texto de interface.

**Critérios de aceite:** busca em logs não encontra bearer, invite token, assinatura, senha, PDF, CPF/CNPJ completo, payload fiscal ou corpo de webhook; cliente não recebe corpo técnico bruto, nome de classe, SQL ou stack trace; `errorId` permite correlação.

### SEC-014 - Rate Limit, Body E Upload

**Implementação:** filtro de rate limit para discovery, invite e webhooks; Redis como coordenador e fallback local com estado limitado; usar IP da conexão e sobrescrever forwarding no proxy; rejeitar `Content-Length` excessivo e stream chunked acima do limite; multipart 5 MB; certificado até limite configurado, extensão permitida, DER/PKCS#12 plausível, alias/senha limitados; paginação máxima 200; header máximo 16 KB.

**Critérios de aceite:** burst excedente recebe `429`; body grande recebe `413`; chunked não burla limite; arquivo inválido é rejeitado antes de persistência; paginação não aloca lista arbitrária.

### SEC-020 - Fail-Closed Multi-Tenant E Least Privilege

**Implementação:** remover caminhos globais implícitos quando `TenantContext` está vazio; controllers devem consumir o tenant pelo `TenantContextHolder`, sem depender de request attributes paralelos; dashboard global só para Super Admin; status de usuário por tenant+e-mail; validar slug/database; remover `TENANT_USER` de mutações de cliente/fiscal; usar somente roles efetivamente provisionadas; manter whitelist de roles convidáveis. Para DAS, emissão e download ficam limitados a `TENANT_ADMIN` e `FISCAL_ADMIN`; Super Admin exige impersonation explícita validada pelo filtro.

**Critérios de aceite:** matriz negativa por perfil cobre cada controller sensível; ausência de tenant não usa banco default; e-mail igual em tenants diferentes não cruza status; role Super Admin não pode ser convidada por tenant; o endpoint DAS não depende de `requestAttribute`, rejeita `TENANT_USER` e usa o tenant resolvido pelo filtro.

## 7. Plano Frontend

### SEC-015 - Transporte De Token

Substituir `EventSource` com token em query por `fetch` streaming autenticado. Renovar token antes de abrir conexão, usar header Authorization, abortar no unmount/logout e tratar reconexão sem imprimir token. Backend não deve aceitar query bearer como compatibilidade.

Aceite: DevTools e access log mostram URL sem token; header existe; logout encerra stream; `401` não cria loop infinito.

### SEC-016 - XSS E CSS Injection

Renderizar mensagem como React text node, sem HTML interpretado. Validar tema apenas com regex hexadecimal e atribuir por `style.setProperty`. Proibir `innerHTML`, `dangerouslySetInnerHTML`, `eval` e URL CSS controlada por API.

Aceite: payload `<img onerror=...>` aparece literalmente; valores `url(javascript:...)`, `;background:` e strings fora da regex são descartados; testes security permanecem verdes.

### SEC-017 - Navegação Segura

Centralizar parsing em `safeNavigation`; usar `new URL` com base same-origin; aceitar somente `http/https` previstos e blob same-origin quando necessário; rejeitar `javascript:`, `data:`, user-info e host não permitido; Stripe somente HTTPS porta 443; novas abas com `noopener,noreferrer` e `opener=null`.

Aceite: testes cobrem esquema, credencial, domínio parecido, porta, same-origin relativo e tabnabbing. Retorno de checkout/portal não aceita URL arbitrária vinda da API.

### SEC-018 - Mocks E Debug

Carregar MSW somente quando `NODE_ENV=development`; remover rota/menu de token; não versionar credenciais E2E; remover relatórios Playwright e `ts_errors.log`; garantir que matcher de rota pública não aceite prefixo parecido.

Aceite: build production não contém inicialização do worker; `/profile/token-info` retorna 404; `/api/v1/publicity` não é tratado como público; artefatos gerados não aparecem em `git status` após testes.

### SEC-019 - Controles De Browser

Backend usa CORS por origin exata, sem wildcard/credentials. Next gera nonce por request e CSP; incluir `default-src`, `script-src`, `style-src`, `img-src`, `connect-src`, `frame-ancestors` e `object-src 'none'` conforme uso real. Aplicar HSTS somente em HTTPS de produção, `nosniff`, referrer policy, permissions policy e `Cache-Control: no-store` em páginas autenticadas.

Aceite: CSP sem `unsafe-eval` em produção, nonce diferente por resposta, frame externo bloqueado, origin não autorizada sem CORS e páginas autenticadas não armazenadas em cache compartilhado.

## 8. Plano De Identidade E Infraestrutura

### SEC-004 - Segredos E Histórico Git

**No repositório:** ignorar `.env*` com exceção de exemplos; remover `.env`, Playwright e logs do índice; eliminar defaults previsíveis em Java/YAML/Compose; exigir secrets no startup; exemplos sem valor.

**Operação obrigatória:** inventariar cada segredo histórico; rotacionar banco, Keycloak, Grafana, Stripe, WhatsApp, Telegram, LLM, certificados e chaves; invalidar tokens; usar `git filter-repo` em clone espelho após aprovação; force-push coordenado; revogar caches de CI; exigir novo clone; executar Gitleaks em todo histórico.

**Aceite:** `git grep` e Gitleaks sem segredo válido; credenciais antigas falham; aplicações sobem somente com secret store; nenhuma senha pessoal é reutilizada.

**Rollback:** rotação não deve ser revertida para segredo exposto. Se houver falha, emitir outro segredo novo.

### SEC-008 - Keycloak

Clients de API ficam bearer-only, sem secret, flow, service account, redirects ou web origins. SPA fica public client, Authorization Code + PKCE S256, sem Direct Grants e com frontend origin exata. Exportações não contêm users. Realms tenant não definem Super Admin. Política de senha tem 12-128 caracteres e bloqueia username/e-mail. `sslRequired=external` em HML/PRD.

Provisionamento dinamico depende de `RealmProvisioningPort` e usa uma Service Account confidencial por `client_credentials`. O backend recebe apenas `KEYCLOAK_PROVISIONING_CLIENT_ID` e `KEYCLOAK_PROVISIONING_CLIENT_SECRET`; usuario e senha de bootstrap ficam restritos ao Keycloak e ao inicializador one-shot. O adapter valida slug/origin, renderiza placeholders como nos JSON em vez de concatenar payload bruto e injeta somente a frontend origin configurada. A imagem Keycloak e fixada em `26.6.3` para incorporar correcoes posteriores a 26.2.

O onboarding trata banco, datasource, metadados e realm como uma saga sincrona: o evento final somente e publicado depois do realm e qualquer falha compensa todos os efeitos anteriores. Exclusao de realm e idempotente e uma tentativa e marcada antes da chamada para cobrir timeout depois da criacao remota. Volumes persistidos sao migrados com `bootstrap-admin` temporario, todos os nodes parados e remocao obrigatoria da identidade temporaria; apagar volume ou voltar ao Password Grant nao e rollback aceito.

Aceite adicional: init tecnico `Exited (0)` antes do backend; backend `healthy` sem credencial humana; falha Keycloak nao deixa documento, slug, banco ou realm orfao; nenhum usuario/client temporario permanece depois da migracao.

Rollout: backup do banco, testar upgrade em clone HML, importar realms, validar PKCE/login/refresh/logout/invite/admin, observar logs, só então produção. Não fazer downgrade do schema Keycloak; rollback é restauração do backup com imagem anterior.

### SEC-012 - TLS E Proxy

Java usa trust manager padrão e mTLS de cliente sem trust-all. NGINX encerra TLS 1.2/1.3, redireciona porta 80, responde 444 no default host, oculta versão, limita request/conexão, usa access log sem query e sobrescreve `X-Forwarded-For` com IP da conexão. Apenas proxy publica portas em HML/PRD.

Aceite: certificado inválido/hostname errado falha; SSL Labs ou equivalente sem protocolo legado; backend/DB/Keycloak inacessíveis externamente; query com token não aparece em access log.

### SEC-021 - Supply Chain

Frontend deve manter `npm ci`, lockfile, `npm audit --audit-level=high`, testes e lint. Backend usa Maven Wrapper e testes. Workflow adicional executa Gitleaks em histórico completo, Dependency Review em PR, SBOM SPDX e Trivy de vulnerabilidade/secret/misconfiguration. Todas as actions usam commit SHA comentado. Imagens usam versão específica; atualização passa por PR e scan.

Regras de build no `.gitignore` devem ser ancoradas nos diretorios reais. A regra global `**/out/` e proibida porque coincide com pacotes Java `application/port/out`. Os workflows backend e security executam um path sentinela com `git check-ignore --no-index` e falham se source ports forem ignorados. Todo arquivo novo de porta deve aparecer em `git status --untracked-files=all` e no conjunto rastreado antes do merge.

Aceite: CI bloqueia vulnerabilidade High/Critical nova, segredo, teste/lint quebrado e Trivy High/Critical corrigível. SBOM fica como artefato por 14 dias.

### SEC-022 - Container E Deploy

Containers de app executam non-root, `cap_drop: ALL`, `no-new-privileges`, filesystem read-only, tmpfs restrito e `pids_limit`. Bancos/Redis não são publicados em HML/PRD. Dev expõe somente loopback. Pipeline constrói uma vez, gera SBOM/provenance, publica tag por commit e propaga o digest ao host. Servidor executa `pull` e `up` sem `--build` e sem `latest`.

Aceite: `docker inspect` confirma user/caps/read-only; scanner sem configuração crítica; digest em execução é igual ao output do build; Environment `production` exige reviewer.

### SEC-023 - Observabilidade

Usar profile `prd` para JSON/Loki. Alertmanager lê `url_file` de `/run/secrets/alert_webhook_url`; não usar URL placeholder ou webhook no Git. Restringir UIs ao proxy/VPN e Actuator por Super Admin.

Aceite: alerta sintético chega ao receiver e resolve; ausência do secret impede inicialização; logs continuam redigidos; acesso anônimo a métricas detalhadas falha.

### SEC-024 - Backup E Restore

`postgres-backup.sh` enumera bancos não-template, exporta globals sem hashes de senha, gera custom dumps, SHA-256, manifesto UTC, tar criptografado com `age` e upload S3 exigindo KMS. Executar separadamente no cluster de aplicação e no cluster Keycloak.

`postgres-restore-drill.sh` baixa/localiza arquivo, decripta, verifica checksums, exige nome seguro, cria banco temporário, restaura com `--exit-on-error`, verifica tabelas e remove o banco de drill.

Controles externos: S3 Block Public Access, versioning, Object Lock, lifecycle, KMS com least privilege, identidade `age` fora do host/bucket, job scheduler, alerta de ausência e evidência trimestral. Meta inicial: RPO até 24 h e RTO até 4 h, sujeita a aprovação do negócio.

Aceite: backup de ambos os clusters concluído, objeto versionado/criptografado, restore drill trimestral verde, tempo medido dentro do RTO e amostra funcional validada pela aplicação.

## 9. Sequência De Rollout

### Fase 0 - Contenção

1. Congelar deploy de produção.
2. Criar inventário de segredos e owners.
3. Rotacionar credenciais externas e invalidar sessões.
4. Preservar evidência e abrir change para saneamento do Git.

### Fase 1 - Homologação De Código

1. Executar suite backend completa.
2. Executar testes, lint, audit e build frontend.
3. Validar JSON Keycloak, scripts shell, Compose e NGINX.
4. Subir dois tenants de teste e todos os papéis.
5. Rodar DAST e testes negativos da matriz de acesso.

### Fase 2 - Backup E Chaves

1. Executar backup app e Keycloak.
2. Confirmar restore drill antes de migration destrutiva.
3. Provisionar chaves novas e chaves legadas separadas.
4. Registrar key IDs, owners, data de ativação e rotação sem registrar material secreto.

### Fase 3 - Identity E Dados

1. Atualizar Keycloak em HML e validar todos os fluxos.
2. Implantar backend em instância única e observar migrations/re-encryption.
3. Validar amostras funcionais de mensagens, notificações, PDFs, certificados e LLM.
4. Escalar backend apenas depois de terminar o runner.

### Fase 4 - Frontend E Proxy

1. Implantar NGINX com certificados válidos.
2. Implantar frontend e validar CSP, SSE, redirects e checkout Stripe.
3. Re-registrar Telegram com a nova URL/header secreto.
4. Rodar alerta sintético e confirmar observabilidade.

### Fase 5 - Produção E Pós-Deploy

1. Aprovar digest exato pelo GitHub Environment.
2. Executar smoke tests e matriz negativa.
3. Monitorar `401/403/429/5xx`, falhas de decrypt, migration e webhook.
4. Revogar chaves legadas somente após consulta comprovar zero legado.
5. Concluir saneamento do histórico Git e exigir novos clones.

## 10. Plano De Testes

| Camada | Comando/gate | Resultado esperado |
|---|---|---|
| Backend compile | `cd backend && ./mvnw -B -DskipTests compile` | `BUILD SUCCESS` |
| Backend tests | `cd backend && ./mvnw -B test` | zero falhas/erros |
| Frontend security | `cd frontend && npm test -- --run ...security...` | todos aprovados |
| Frontend full | `cd frontend && npm test` | zero regressão nova; débitos antigos triados |
| Frontend lint | `cd frontend && npm run lint` | zero erro |
| Frontend dependencies | `cd frontend && npm audit --audit-level=high` | zero High/Critical |
| Keycloak JSON | `jq empty` nos oito JSON | código 0 |
| Shell | `bash -n infra/backup/*.sh infra/keycloak/bootstrap/*.sh start-dev-*.sh` | código 0 |
| Compose | `docker compose ... config --quiet` | código 0 com secrets dummy |
| NGINX | `nginx -t` no container com cert de teste | sintaxe válida |
| Git hygiene | `git diff --check` e Gitleaks | sem whitespace/segredo |
| DAST | OWASP ZAP/Burp em HML | zero Critical/High aberto |
| Recovery | backup + restore drill | checksum e restore válidos dentro do RTO |

## 11. Matriz De Acesso Obrigatória

| Cenário | Anônimo | Tenant User | Tenant Operator | Tenant Admin | Super Admin |
|---|---:|---:|---:|---:|---:|
| Health básico | Permitir | Permitir | Permitir | Permitir | Permitir |
| Actuator detalhado | Negar | Negar | Negar | Negar | Permitir |
| Dados do próprio tenant | Negar | Conforme leitura | Conforme função | Permitir | Somente impersonation explícita |
| Dados de outro tenant por UUID | Negar | Negar | Negar | Negar | Permitir conforme caso administrativo |
| Configuração LLM/WhatsApp global | Negar | Negar | Negar | Negar | Permitir |
| Cliente/certificado/fiscal mutável | Negar | Negar | Conforme política | Permitir | Conforme operação global |
| Configuração de bot tenant | Negar | Negar | Negar | Permitir | Somente contexto explícito |
| Logs/auditoria tenant | Negar | Negar | Negar | Permitir | Conforme escopo global |

## 12. Evidências A Anexar Ao Change

- SHA do commit e digest das imagens.
- Logs resumidos de testes, audit, Gitleaks, Trivy e SBOM.
- Export sanitizado da matriz de acesso.
- Resultado `nginx -t` e relatório TLS.
- Evidência de rotação sem valores secretos.
- Contagem de registros migrados por domínio e zero legado final.
- ID/version do objeto de backup e saída do restore drill.
- Resultado do alerta sintético.
- Relatório DAST/pentest e aceite de risco residual.

## 13. Definition Of Done

O plano somente está totalmente concluído quando:

1. Todos os critérios automáticos estão verdes.
2. Nenhum Critical/High permanece sem aceite formal.
3. Credenciais expostas foram rotacionadas e histórico Git saneado.
4. Keycloak, TLS, CSP, webhooks e matriz multi-tenant foram validados em HML.
5. Migrations e recriptografia terminaram sem plaintext inesperado.
6. Backup de aplicação e Keycloak foi restaurado com sucesso em ambiente isolado.
7. CI/CD usa digest, aprovação e scanners.
8. Owners aceitaram RPO/RTO e risco residual.

## 14. Registro De Execução Local

| Verificação | Estado em 14/08/2026 |
|---|---|
| Auditoria npm | Aprovada, `0 vulnerabilities` |
| Suite completa frontend | Aprovada: `41/41` arquivos e `198/198` testes |
| TypeScript frontend | Aprovado com `npx tsc --noEmit` |
| Lint frontend | Aprovado com `0` erros; `87` warnings não bloqueantes permanecem registrados como débito de qualidade |
| Build de produção frontend | Aprovado: `37` rotas compiladas, sem download externo de fontes |
| Suite completa backend | Aprovada: `680` testes, `0` falhas, `0` erros, `29` ignorados por indisponibilidade de Docker/Testcontainers no processo Maven e `BUILD SUCCESS` |
| JSON Keycloak | Aprovado nos oito templates/exports com `jq empty` |
| Sintaxe scripts backup/restore | Aprovada com `bash -n` |
| Docker Compose base + desenvolvimento | Interpolacao aprovada; stack local executada com PostgreSQL, Redis, Keycloak e backend saudaveis. |
| Identidade tecnica Keycloak local | Aprovada: Service Account permanente autenticou por Client Credentials; init terminou com codigo zero; nenhuma identidade temporaria de recovery permaneceu. |
| Contrato global/tenant do Keycloak | Aprovado: zero mappers tenant no `saas-admin` persistido; exports passaram no gate; token PKCE de Super Admin sem `tenant_id` e endpoint global HTTP `200`. |
| Testes focados de JWT, contexto e onboarding/IAM | Aprovados: `23` testes, `0` falhas e `0` erros. |
| Compensacao de tenant orfao | Aprovada: registro incompleto removido por transacao guardada e verificacao posterior com zero tenants ativos/provisionados sem banco. |
| Smoke onboarding Keycloak | Aprovado: HTTP `201`, tenant `038e2d23-4ef4-46f6-a746-10572118ed91`, banco dedicado com 26 tabelas, realm acessivel, `tenant_id` completo e `aud=saas-service-api`. |
| Higiene do diff | Aprovada com `git diff --check` |
| NGINX em execução | Transferido para CI/HML por indisponibilidade local do daemon Docker e necessidade de certificado de teste |
| Rotação, Git history, TLS, backup e DAST | Ação operacional externa pendente |

A credencial local autorizada foi fornecida somente por entrada mascarada para a elevacao e o smoke PKCE. Ela nao foi persistida nem incluida em arquivos ou evidencias e deve ser rotacionada por ter sido exposta em canal de conversa.
