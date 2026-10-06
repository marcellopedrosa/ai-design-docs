---
document_id: "ADR-0020"
primary_nature: "Decisao"
objective: "Registrar a decisão arquitetural “Centralized Authentication Portal & Realm-per-Tenant Discovery”, seus motivadores, alternativas e consequências."
scope: "Decisão, componentes, integrações e limites explicitamente descritos em “Centralized Authentication Portal & Realm-per-Tenant Discovery”."
non_objectives: "Não implementar a decisão, substituir requisitos relacionados nem atestar capabilities ou ambientes sem evidência explícita."
owner: "@SecurityOAuth, @AgentOrchestrator"
status: "Proposed"
date: "2026-07-24"
version: "1.0"
keywords: "adr, decisao, arquitetura, centralized, authentication, portal, realm, per, tenant, discovery"
related_files: "docs/adrs/README.md, docs/adrs/ADR-0005-multi-tenancy-architecture.md, docs/adrs/ADR-0018-keycloak-realm-provisioning-automation.md, docs/adrs/ADR-0019-database-per-tenant.md"
code_references: "TenantOnboardingUseCase, TenantContextFilter, TenantContext, TenantDiscoveryController, DiscoverTenantsUseCase"
principal_statement: "O portal central usa descoberta por e-mail, seleção explícita do workspace e redirecionamento OIDC para o realm Keycloak do tenant escolhido, preservando realm-per-tenant e proteção contra enumeração."
---

# ADR-0020 - Centralized Authentication Portal & Realm-per-Tenant Discovery

- Date: 2026-07-24
- Status: Proposed
- Version: 1.0
- Authors / Owners: @SecurityOAuth, @AgentOrchestrator
- Reviewers: @CleanArchitecture, @MultiTenantEng, @DevOps-Agent, @FrontendEng
- Stakeholders: Engineering Team, Product Owner, Customer Onboarding Team, LGPD Compliance
- Supersedes: ADR-0005 (Parcialmente: Altera o fluxo de descoberta do Realm de autenticação, mantendo isolamento por Realm)
- Depends on: ADR-0018 (Keycloak Realm Provisioning), ADR-0019 (Database-per-Tenant)

---

# 1. Context

Os ADRs ADR-0018 e ADR-0019 estabeleceram, respectivamente:
- **1 Realm Keycloak por escritório** (isolamento total de identidade).
- **1 Banco de Dados PostgreSQL por escritório** (isolamento total de dados).

Ambas as decisões foram tomadas pressupondo originalmente que cada escritório teria **sua própria URL de acesso** (subdomínio) — ex: `escritoriojoao.agentefiscal.com.br`. Nesse modelo, a URL já é a "âncora" que resolve qual Realm usar no Keycloak, tornando o fluxo de login trivial: o Frontend lê o subdomínio e aponta para o Realm correspondente.

**Nova Definição de Produto:** A aplicação utilizará um **único domínio central** `app.agentefiscal.com.br` como ponto de entrada para todos os escritórios. Não haverá subdomínios dinâmicos por cliente. Este é o modelo adotado por ferramentas como Notion, Linear e Figma.

**O Problema Arquitetural Resultante:** Com um domínio único, o Frontend não tem como inferir em qual Realm do Keycloak o usuário deve se autenticar apenas pela URL. Precisamos de um mecanismo que, dado o e-mail do usuário, retorne a lista de escritórios (Realms) associados a ele. Esse mecanismo é o **Tenant Discovery**.

---

# 2. Decision Statement

O sistema adotará um fluxo de autenticação em **3 etapas** no portal central `app.agentefiscal.com.br`:

1. **Etapa de Descoberta (Discovery):** O usuário informa apenas o seu **e-mail**. O Frontend chama uma API pública do Backend (`GET /api/public/tenant-discovery?email=...`) que consulta o banco de dados global da plataforma (`saas_platform`) e retorna a lista de escritórios aos quais aquele e-mail está vinculado.

2. **Etapa de Seleção (Workspace Selection):** O Frontend renderiza os escritórios encontrados em **Cards visuais** (com nome e logo do escritório). O usuário seleciona em qual escritório deseja entrar.

3. **Etapa de Autenticação (Keycloak OIDC):** O Frontend redireciona o navegador para o endpoint de autenticação do Keycloak no **Realm específico** do escritório selecionado: `https://auth.agentefiscal.com.br/realms/saas_{slug}/protocol/openid-connect/auth`. O Keycloak exibe sua própria tela de login (com o tema do escritório), o usuário insere a senha e o fluxo OIDC padrão se completa.

---

# 3. Decision Drivers

- **Domínio Único:** Produto decidiu que todo acesso se dá por `app.agentefiscal.com.br`.
- **Compatibilidade com Realm-per-Tenant:** A decisão de isolamento de identidade via Realms (ADR-0018) é mantida sem alterações.
- **Experiência de Uso Limpa (UX):** O usuário não precisa memorizar uma URL específica por escritório. Basta o e-mail.
- **Multi-Workspace:** Um contador que trabalha para múltiplos escritórios pode ver todos os seus "workspaces" na tela de seleção e alternar entre eles sem fazer logout completo do portal.
- **Segurança:** O endpoint de Discovery deve ser público, mas protegido de enumeração em massa (rate limiting por IP).
- **LGPD:** O Discovery Endpoint não expõe dados sensíveis — retorna apenas nome do escritório, logo e slug (informações de apresentação). Não há vazamento de informação crítica.

---

# 4. Considered Options

## Option A: Subdomínio por Escritório (Descartada)
**Descrição:** Cada escritório acessa o sistema por uma URL própria (ex: `escritoriojoao.agentefiscal.com.br`). O Frontend lê o subdomínio e já sabe qual Realm chamar.

**Prós:**
- Simples de implementar. Sem necessidade de Discovery Endpoint.
- URL "branding" para o cliente (pode parecer mais profissional para alguns perfis).

**Contras:**
- Requer wildcard DNS (`*.agentefiscal.com.br`) e wildcard TLS certificado.
- O usuário precisa memorizar e guardar uma URL específica.
- Impossibilita um portal centralizado de "My Workspaces" (ver todos os escritórios em um só lugar).
- **Decisão de produto rejeitou esta opção.**

---

## Option B: Tenant Discovery por E-mail com Redirectionamento OIDC (Selecionada)
**Descrição:** Portal único com fluxo em 3 etapas: Discovery → Seleção de Workspace → Keycloak OIDC.

**Prós:**
- Domínio único. Experiência centralizada.
- Totalmente compatível com ADR-0018 e ADR-0019 sem necessidade de refatoração deles.
- Permite tela de "Meus Escritórios" com múltiplos workspaces ativos.

**Contras:**
- Adiciona uma etapa ao fluxo de login (Discovery + Seleção antes de inserir a senha).
- Requer construção e proteção de um endpoint público de Discovery.

---

## Option C: Realm Master Centralizado com Identity Brokering (Futura Evolução)
**Descrição:** Criar um Realm master no Keycloak onde todos os usuários existem centralmente. Os Realms dos escritórios delegam autenticação ao Realm master via Identity Brokering. O usuário teria **uma única senha** para todos os escritórios.

**Prós:**
- Experiência Single Sign-On global (uma senha para tudo).
- Login mais direto (não precisa da tela de seleção).

**Contras:**
- Extremamente complexo de configurar e manter no Keycloak.
- Cria um ponto único de falha: se o Realm master cair, todos os escritórios ficam sem acesso.
- Aumento de custo operacional de infraestrutura significativo.
- **Reservada como evolução arquitetural futura (V2).**

---

# 5. Decision Outcome

**Option B (Tenant Discovery por E-mail)** foi selecionada para a V1 do produto.

A abordagem é pragmática, mantém a compatibilidade total com os ADRs existentes (ADR-0018 e ADR-0019) e entrega uma experiência de produto coesa com o modelo de "Hub Central" desejado pela liderança de produto.

A **Option C** (Identity Brokering) é formalmente reservada como evolução arquitetural futura e pode ser adicionada sobre essa base sem quebrar o contrato atual.

---

# 6. Architecture Deep Dive: Fluxo Completo de Login

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          app.agentefiscal.com.br                                    │
└─────────────────────────────────────────────────────────────────────────────────────┘

ETAPA 1 — DISCOVERY
─────────────────────────────────────────────────────────────────────────────────────

  ┌──────────────┐    1a. GET /api/public/tenant-discovery?email=joao@email.com
  │   Frontend   │ ──────────────────────────────────────────────────────────────────►
  │   (Next.js)  │
  │  [Tela:      │ ◄──────────────────────────────────────────────────────────────────
  │  "Qual seu   │    1b. HTTP 200 JSON: [ { slug: "escritorioa", name: "Escritório A",
  │  e-mail?"]   │             logoUrl: "https://cdn.../a.png" },
  └──────────────┘             { slug: "escritoriob", name: "Escritório B" } ]


ETAPA 2 — SELEÇÃO DE WORKSPACE
─────────────────────────────────────────────────────────────────────────────────────

  ┌──────────────┐
  │   Frontend   │    Renderiza cards para cada escritório retornado.
  │  [Tela:      │    Usuário clica em "Escritório A".
  │  "Escolha    │
  │  o workspace"]
  └──────────────┘


ETAPA 3 — REDIRECIONAMENTO OIDC PARA REALM ESPECÍFICO
─────────────────────────────────────────────────────────────────────────────────────

  ┌──────────────┐    2. Browser redirect para:
  │   Frontend   │ ──────────────────────────────────────────────────────────────────►
  └──────────────┘    https://auth.agentefiscal.com.br
                          /realms/saas_escritorioa
                          /protocol/openid-connect/auth
                          ?client_id=saas-frontend
                          &redirect_uri=https://app.agentefiscal.com.br/callback
                          &response_type=code
                          &scope=openid profile email
                          &state={csrf_state}

  ┌──────────────┐    3. Keycloak renderiza sua tela de Login (tema do escritório A)
  │   Keycloak   │
  │  Realm:      │    4. Usuário insere senha. Keycloak valida e retorna:
  │  saas_       │       HTTP 302 → https://app.agentefiscal.com.br/callback?code=AUTH_CODE
  │  escritorioa │
  └──────────────┘

ETAPA 4 — TOKEN EXCHANGE (Backend-to-Keycloak)
─────────────────────────────────────────────────────────────────────────────────────

  ┌──────────────┐    5. Frontend envia code para o Backend:
  │   Frontend   │       POST /api/auth/token { code, realm: "saas_escritorioa" }
  └──────────────┘

  ┌──────────────┐    6. Backend troca o code por Access Token + Refresh Token no Keycloak.
  │   Backend    │       POST auth.agentefiscal.com.br/realms/saas_escritorioa
  │  (Spring)    │            /protocol/openid-connect/token
  └──────────────┘

  JWT gerado contém:
  {
    "sub": "uuid-do-usuario",
    "realm_access": { "roles": ["ROLE_ADMIN"] },
    "tenant_id": "uuid-do-escritorio-a",   ← Claim customizado
    "email": "joao@email.com",
    "iss": "https://auth.agentefiscal.com.br/realms/saas_escritorioa"
  }

  7. TenantContextFilter (Spring) extrai o tenant_id do JWT e popula o ThreadLocal.
  8. TenantRoutingDataSource roteia todas as queries JPA para o banco "saas_escritorioa".
```

---

# 7. Architecture Deep Dive: Discovery Endpoint

## 7.1. Contrato da API

```
GET /api/public/tenant-discovery?email={email}
Content-Type: application/json
Authorization: NENHUMA (endpoint público)

HTTP 200 — E-mail encontrado em um ou mais escritórios
[
  {
    "tenantId": "uuid-do-escritorio",
    "slug": "escritorioa",
    "companyName": "Escritório A Contabilidade",
    "logoUrl": "https://cdn.agentefiscal.com.br/logos/escritorioa.png"
  }
]

HTTP 200 — E-mail não encontrado (resposta intencionalmente vazia, não 404)
[]

HTTP 422 — E-mail inválido (sem @, sem domínio, etc.)
{ "error": "INVALID_EMAIL", "message": "The provided email is not a valid format." }

HTTP 429 — Rate limit excedido
{ "error": "RATE_LIMIT_EXCEEDED" }
```

> **Nota de Segurança:** O endpoint retorna HTTP 200 com lista vazia (e não HTTP 404) quando o e-mail não existe. Isso é intencional para impedir que atacantes usem o endpoint para confirmar se um e-mail está cadastrado na plataforma (account enumeration attack).

## 7.2. Dados Consultados

O Discovery Endpoint consulta exclusivamente a tabela `tenant_users` no banco `saas_platform` (banco global da plataforma). Este banco **não é roteado** pelo `TenantRoutingDataSource` — ele é a fonte estática que guarda o catálogo global de todos os escritórios e seus usuários.

```sql
-- Consulta executada pelo Discovery
SELECT
    t.id              AS tenant_id,
    t.database_slug   AS slug,
    t.company_name    AS company_name,
    t.logo_url        AS logo_url
FROM tenant_users tu
JOIN tenants t ON t.id = tu.tenant_id
WHERE tu.email = :email
  AND tu.status = 'ATIVO'
  AND t.status = 'ATIVO'
  AND t.database_provisioned = true;
```

## 7.3. Proteção do Endpoint

| Mecanismo | Implementação |
|-----------|--------------|
| **Rate Limiting** | Bucket4J com limite de 10 requisições/min por IP |
| **Validação de Input** | Bean Validation (`@Email`) + regex de domínio mínimo |
| **Sem autenticação** | Intencional — a autenticação ocorre no Realm do Keycloak |
| **CORS** | Restrito apenas ao domínio `app.agentefiscal.com.br` |
| **Sem dado sensível** | Retorna apenas nome, slug e logo. Nunca e-mails, CPFs, etc. |

---

# 8. Architecture Deep Dive: Frontend — Telas e Componentes

## 8.1. Rota: `/login` — Tela de E-mail

```
┌─────────────────────────────────────┐
│  ♦ AgenteFiscal                     │
│                                     │
│  Bem-vindo de volta                 │
│                                     │
│  ┌─────────────────────────────┐    │
│  │  seu@email.com              │    │
│  └─────────────────────────────┘    │
│                                     │
│  [ Continuar → ]                    │
│                                     │
│  Novo por aqui? Contrate agora      │
└─────────────────────────────────────┘
```

- Ao clicar em "Continuar", chama `GET /api/public/tenant-discovery?email=...`.
- Se retornar 1 escritório → pula a tela de seleção e vai direto para o Keycloak.
- Se retornar múltiplos → navega para `/login/workspaces`.
- Se retornar vazio → exibe: *"Nenhum escritório encontrado com esse e-mail. Você foi convidado?"*.

## 8.2. Rota: `/login/workspaces` — Tela de Seleção de Workspace

```
┌─────────────────────────────────────┐
│  Olá, joao@email.com!               │
│  Escolha o escritório para entrar:  │
│                                     │
│  ┌─────────────────┐                │
│  │ [Logo] Escritório A              │
│  │ escritorioa.ag..│                │
│  └─────────────────┘                │
│                                     │
│  ┌─────────────────┐                │
│  │ [Logo] Escritório B              │
│  │ escritoriob.ag..│                │
│  └─────────────────┘                │
│                                     │
│  Trocar de e-mail                   │
└─────────────────────────────────────┘
```

- Cada card é um link que dispara o OIDC redirect para o Realm correspondente.
- O `state` da requisição OIDC carrega `{ slug, email }` para uso no callback.

## 8.3. Rota: `/callback` — Retorno do Keycloak

- O Backend troca o Authorization Code pelo Access Token e Refresh Token.
- Tokens são armazenados como **HTTP-Only cookies** (jamais em localStorage).
- O Frontend redireciona para `/dashboard` da aplicação.

---

# 9. Architecture Deep Dive: Keycloak & Realm Naming Convention

## 9.1. Convenção de Nomenclatura

Todos os Realms do Keycloak seguirão a convenção:

```
saas_{slug}
```

Onde `{slug}` é o mesmo slug gerado pelo `TenantOnboardingUseCase` (alphanumeric, lowercase, max 30 chars).

Exemplos:
- Escritório "Contabilidade João e Silva Ltda" → `saas_contabilidadejoaosilva`
- Escritório "ABC Assessoria Fiscal" → `saas_abcassessoriafiscal`

> **REGRA:** O Realm Name no Keycloak e o nome do banco de dados no PostgreSQL **devem ser sempre derivados do mesmo `database_slug`** armazenado na tabela `tenants`. Isso garante que o roteamento de banco funcione a partir do JWT (claim `iss` ou `tenant_id`) sem mapeamentos extras.

## 9.2. Claim Customizado no JWT: `tenant_id`

O Realm de cada escritório deve ter um **Protocol Mapper** que adiciona ao Access Token o `tenant_id` (UUID do escritório armazenado no banco Platform):

```json
{
  "name": "tenant_id",
  "protocol": "openid-connect",
  "protocolMapper": "oidc-hardcoded-claim-mapper",
  "config": {
    "claim.name": "tenant_id",
    "claim.value": "{uuid-do-tenant}",
    "jsonType.label": "String",
    "access.token.claim": "true"
  }
}
```

Este claim é o que o `TenantContextFilter` do Spring Boot extrai para popular o `TenantContext` (ThreadLocal) e o `TenantRoutingDataSource` usa para rotear as queries JPA para o banco correto.

## 9.3. Client do Frontend no Keycloak

Cada Realm deve ter um Client configurado:

| Propriedade | Valor |
|-------------|-------|
| **Client ID** | `saas-frontend` |
| **Access Type** | `public` (PKCE) |
| **Valid Redirect URIs** | `https://app.agentefiscal.com.br/callback` |
| **Web Origins** | `https://app.agentefiscal.com.br` |

> O Client é **idêntico em todos os Realms** — o que muda é apenas o Realm em si. Isso é configurado automaticamente pelo `tenant-template.json` (ADR-0018).

---

# 10. Consequences

## Positive Consequences
- **Domínio Único:** Toda a frota de clientes acessa o produto por uma URL memorável.
- **Sem refatoração de ADR-0018/ADR-0019:** O isolamento de Realm e de Banco permanece intacto.
- **Multi-Workspace Nativo:** A tela de seleção abre espaço para o usuário gerenciar múltiplos contextos de trabalho.
- **Evolução para SSO:** A arquitetura é compatível com a futura adição de Identity Brokering (Option C) sem quebrar o contrato do Discovery Endpoint.

## Negative Consequences
- **Login em Duas Etapas:** O usuário insere o e-mail → seleciona escritório → insere senha (3 cliques vs. 2 cliques no modelo de subdomínio). Pode ser mitigado com **remember the workspace** via cookie de 30 dias.
- **Endpoint Público Sensível:** O Discovery Endpoint é um vetor de ataque se não houver rate limiting adequado. A segurança deve ser rigorosa.
- **Senhas Independentes por Workspace:** Na V1, um usuário que trabalha em 2 escritórios pode ter senhas diferentes para cada um (pois são 2 contas no Keycloak distintas). Mitigação futura: Identity Brokering (ADR futuro).

---

# 11. Impact

| Domínio | Impacto |
|---------|---------|
| **Frontend (Next.js)** | Criar 3 novas rotas: `/login`, `/login/workspaces`, `/callback`. Implementar OIDC PKCE flow. |
| **Backend (Spring Boot)** | Criar `TenantDiscoveryController` + `DiscoverTenantsUseCase`. Proteger com Rate Limiting (Bucket4J). |
| **Keycloak (Infra)** | Garantir que a `RealmRepresentation` programatica (ADR-0018) inclua o Protocol Mapper de `tenant_id` e o client `saas-frontend-spa` configurado. |
| **TenantOnboardingUseCase** | Ao finalizar o provisioning, retornar o `slug` para que o Frontend possa exibir a URL de acesso ao novo escritório. |
| **DNS** | Configurar apenas `app.agentefiscal.com.br` e `auth.agentefiscal.com.br` (sem wildcard). |
| **TLS** | 2 certificados fixos (não wildcard). |

---

# 12. Related ADRs

- [ADR-0005 - Multi-Tenancy Architecture](./ADR-0005-multi-tenancy-architecture.md) — Arquitetura base de multi-tenancy
- [ADR-0018 - Keycloak Realm Provisioning](./ADR-0018-keycloak-realm-provisioning-automation.md) — Criação automática de Realms
- [ADR-0019 - Database-per-Tenant](./ADR-0019-database-per-tenant.md) — Isolamento físico de banco de dados

---

# 13. Implementation Plan

**Phase 1 — Backend: Discovery Endpoint**
1. Criar `DiscoverTenantsUseCase` com query no `TenantUserRepositoryPort.findByEmail()`.
2. Criar `TenantDiscoveryController` com endpoint público e Bucket4J rate limiting.
3. Criar `DiscoveredTenantResponse` DTO.
4. Garantir que `tenants` no banco Platform tenha coluna `logo_url` e `status`.

**Phase 2 — Keycloak: Template Update**
1. Atualizar a factory de `RealmRepresentation` (ADR-0018) incluindo:
   - Protocol Mapper para o claim `tenant_id`.
   - Client `saas-frontend` com redirect para `app.agentefiscal.com.br/callback`.
2. Atualizar `TenantOnboardingUseCase` para injetar o UUID do tenant no Protocol Mapper ao criar o Realm.

**Phase 3 — Frontend: Login Flow**
1. Implementar rota `/login` com campo de e-mail e chamada ao Discovery Endpoint.
2. Implementar rota `/login/workspaces` com Cards de workspace.
3. Implementar rota `/callback` com troca do Authorization Code por tokens.
4. Armazenar tokens em HTTP-Only cookies.

---

# 14. Validation

**Success Criteria:**
- Dado um e-mail com vínculo em 2 escritórios: a tela de seleção renderiza 2 cards.
- Dado um e-mail com vínculo em 1 escritório: o sistema redireciona diretamente para o Keycloak daquele Realm.
- Dado um e-mail inexistente: o sistema retorna lista vazia e exibe mensagem amigável.
- O JWT emitido pelo Keycloak contém o claim `tenant_id` e o Spring Boot roteia corretamente para o banco dedicado do escritório.

**Automated Tests:**
- Teste unitário: `DiscoverTenantsUseCase` com 0, 1 e N tenants.
- Teste de segurança: Rate limiting com 11 requisições no mesmo IP (deve retornar HTTP 429 na 11ª).
- Teste de integração: Fluxo OIDC completo com Testcontainers (Keycloak).

---

# 15. Risks and Mitigations

| Risco | Severidade | Mitigação |
|-------|-----------|-----------|
| Discovery Endpoint usado para confirmar e-mails cadastrados | Alta | Sempre retornar HTTP 200 (lista vazia) mesmo quando e-mail não existe |
| Usuário confuso com múltiplas senhas por escritório | Média | Implementar "lembrar workspace" via cookie + documentação clara no onboarding |
| Realm criado sem o Protocol Mapper `tenant_id` | Alta | Validar o claim no `TenantContextFilter`: se ausente, retornar HTTP 401 com mensagem específica |
| Keycloak OIDC callback interceptado | Alta | Sempre usar PKCE (Proof Key for Code Exchange) no fluxo de autorização |
| Race condition: banco criado mas Realm ainda não provisionado | Média | Evento assíncrono com retry + status `PROVISIONING` no `tenants.status` |

---

# 16. Decision Lifecycle

Status: **Proposed**

---

# 17. Change Log

| Versão | Data | Autor | Mudança |
|--------|------|-------|---------|
| 1.0 | 2026-07-24 | @SecurityOAuth, @AgentOrchestrator | Criação inicial do ADR |

---

# 18. Repository Structure

Stored in: `docs/adrs/ADR-0020-centralized-tenant-discovery.md`
