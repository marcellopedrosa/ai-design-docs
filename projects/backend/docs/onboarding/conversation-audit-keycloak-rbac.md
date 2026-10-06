---
document_id: "ONBOARD-CONVERSATION-AUDIT-KEYCLOAK"
primary_nature: "Regra"
objective: "Orientar o agente de IA de infraestrutura no provisionamento da role ROLE_TENANT_AUDIT, configuração de client scopes no SPA, mapeamento de usuários e regras de personificação no Keycloak em HML e PRD."
scope: "Configuração do Keycloak para controle de acesso do Conversation Audit nos ambientes HML e PRD, abrangendo realm administrativo saas-admin e realms de tenants."
non_objectives: "Não criar usuários fictícios ou de teste em HML ou PRD; não habilitar Full Scope no client SPA; não conceder permissões administrativas implícitas para auditoria."
owner: "Segurança e DevOps"
status: "Active"
date: "2026-09-29"
version: "1.0"
keywords: "onboarding, keycloak, rbac, role-tenant-audit, impersonation, jwt, hml, prd"
related_files: "docs/onboarding/README.md, docs/onboarding/conversation-audit-hml-prd-onboarding.md, docs/onboarding/conversation-audit-api-activation.md, docs/onboarding/keycloak-provisioning-identity.md, docs/product/requirements/REQ-00003-rbac-profile-responsibility-matrix.md, docs/product/requirements/REQ-00004-rbac-security-mapping.md"
code_references: "infra/keycloak/provision/production.sh, infra/keycloak/provision/hml.sh, infra/keycloak/realm-template.json, backend/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/infrastructure/security/ConversationAuditSecurityFilter.java, frontend/src/lib/permissions.ts"
principal_statement: "O acesso à auditoria exige exclusivamente a authority ROLE_TENANT_AUDIT direta e não composta, escopo explícito no SPA com fullScopeAllowed=false e coerência estrita de tenant boundary."
---

# Provisionamento de RBAC e Controle de Acesso no Keycloak — Conversation Audit

**Document ID:** `ONBOARD-CONVERSATION-AUDIT-KEYCLOAK`  
**Owner:** Segurança e DevOps  
**Status:** `Active`  
**Date:** 2026-09-29  
**Version:** 1.0  
**Ambientes Alvo:** HML e PRD  
**Documento Pai:** [Onboarding Geral de Conversation Audit em HML e PRD](conversation-audit-hml-prd-onboarding.md)

---

## 1. Responsabilidade da Feature

Esta especificação governa o provisionamento da role **`ROLE_TENANT_AUDIT`**, a amarração de escopos de cliente no OpenID Connect do frontend e a governança de personificação no **Keycloak** para os ambientes de Homologação (`HML`) e Produção (`PRD`).

### 1.1 Matriz de Acesso a `/audit`

Nenhuma role administrativa tradicional concede acesso implícito à auditoria. A autorização é cumulativa e estritamente tipada:

| Identidade / Perfil | Contexto da Requisição | Resultado para `/audit` | Código HTTP |
|---|---|---|:---:|
| Usuário com `ROLE_TENANT_ADMIN` sem Audit | Qualquer tenant | **Negado:** `ROLE_TENANT_ADMIN` não tem prerrogativa de auditoria. | `403 Forbidden` (`AUD-403-FORBIDDEN`) |
| Usuário com `ROLE_TENANT_AUDIT` | Tenant do próprio usuário | **Permitido:** Consulta conversas do tenant vinculado. | `200 OK` |
| Usuário com `ROLE_TENANT_AUDIT` | Tenant de outro tenant (URL divergente) | **Negado:** Violação de fronteira de tenant (*Tenant Boundary*). | `403 Forbidden` (`AUD-403-TENANT_BOUNDARY`) |
| Super Admin com `ROLE_SUPER_ADMIN` sem Audit | Qualquer tenant | **Negado:** Super Admin não audita conversas sem a role específica. | `403 Forbidden` (`AUD-403-FORBIDDEN`) |
| Super Admin (`ROLE_SUPER_ADMIN + ROLE_TENANT_AUDIT`) | Sem personificação ativa (`X-Tenant-ID` ausente) | **Negado:** A role de auditoria não cria tenantContext implícito. | `403 Forbidden` (`AUD-403-FORBIDDEN`) |
| Super Admin (`ROLE_SUPER_ADMIN + ROLE_TENANT_AUDIT`) | Com personificação ativa (`X-Tenant-ID` de tenant ativo) | **Permitido:** Audita conversas do tenant personificado. | `200 OK` |

---

## 2. Invariantes de Configuração no Keycloak

O agente de infraestrutura DEVE assegurar as seguintes regras estruturais no Keycloak:

1. **Role Simples (`composite=false`):** A role `ROLE_TENANT_AUDIT` DEVE ser uma *realm role* simples. É expressamente proibido torná-la composta ou colocá-la como filha de `ROLE_TENANT_ADMIN`, `ROLE_TENANT_USER` ou `ROLE_SUPER_ADMIN`.
2. **Escopo Explícito no SPA:** O client `saas-frontend-spa` opera com **`fullScopeAllowed=false`**. Logo, para que a role seja emitida no token JWT de acesso, ela DEVE ser adicionada explicitamente ao *dedicated scope* ou *role scope mappings* do client.
3. **Zero Usuários de Teste em HML/PRD:** Ao contrário de DEV (onde scripts semeiam usuários mockados), os scripts de provisionamento de HML e PRD (`infra/keycloak/provision/hml.sh` e `production.sh`) preservam o array `.users` estritamente vazio. Apenas contas humanas reais autorizadas ou a conta do Super Admin oficial recebem as atribuições.
4. **Ausência de `tenant_id` no Realm Administrativo:** O realm `saas-admin` não pode conter mappers que injetem a claim `tenant_id` no token. O contexto de tenant para o Super Admin provém unicamente da personificação via header HTTP validado pelo backend.

---

## 3. Procedimento Operacional no Keycloak

### 3.1 Execução da Reconciliação Versionada

Execute o script de provisionamento correspondente ao ambiente a partir da raiz do repositório:

- Em **HML**:
  ```bash
  bash infra/keycloak/provision/hml.sh
  ```
- Em **PRD**:
  ```bash
  bash infra/keycloak/provision/production.sh
  ```

O script assegura:
- Criação idempotente da role `ROLE_TENANT_AUDIT` nos realms gerenciados;
- Associação correta no client scope de `saas-frontend-spa`.

### 3.2 Atribuição da Role ao Usuário Auditor (Realm do Tenant)

Para conceder acesso de auditor a um operador específico dentro do realm de um tenant:

1. Acesse o console administrativo do Keycloak (`https://auth.agentefiscal.com.br` ou `https://auth-hml.agentefiscal.com.br`).
2. Selecione o realm do tenant: `saas-<slug-do-tenant>`.
3. Navegue até **Users** e localize a conta do operador designado.
4. Na aba **Role mapping**, clique em **Assign role**.
5. Selecione a role `ROLE_TENANT_AUDIT` e confirme.
6. **Obrigatório:** Vá até a aba **Sessions** do usuário e clique em **Revoke** (ou instrua o usuário a efetuar logout e login novamente para renovar o access token JWT).

### 3.3 Atribuição ao Super Admin (Realm `saas-admin`)

Para permitir que o administrador global audite conversas de qualquer tenant sob personificação:

1. No console administrativo, selecione o realm `saas-admin`.
2. Em **Users**, localize a conta do Super Admin.
3. Na aba **Role mapping**, garanta que o usuário possui:
   - `ROLE_SUPER_ADMIN`
   - `ROLE_TENANT_AUDIT`
4. Na aba **Sessions**, encerre as sessões ativas para que o próximo login emita ambas as roles no JWT.

---

## 4. Validação da Estrutura do Token JWT

O agente de infraestrutura pode validar se o token emitido para o usuário atende ao contrato de segurança decodificando o payload do JWT (usando `jwt.io` ou linha de comando segura):

```json
{
  "exp": 1727610000,
  "iat": 1727606400,
  "iss": "https://auth.agentefiscal.com.br/realms/saas-exemplo",
  "sub": "user-uuid",
  "realm_access": {
    "roles": [
      "ROLE_TENANT_USER",
      "ROLE_TENANT_AUDIT"
    ]
  },
  "tenant_id": "11111111-2222-3333-4444-555555555555"
}
```

### 4.1 Checagens de Aceite do Token

- [ ] `realm_access.roles` contém `"ROLE_TENANT_AUDIT"`.
- [ ] No realm do tenant, a claim `"tenant_id"` está presente e possui valor UUID canônico válido.
- [ ] No realm `saas-admin`, a claim `"tenant_id"` **não existe** (ela não deve ser emitida pelo realm administrativo).

---

## 5. Próximo Passo

Com o Keycloak e as identidades devidamente mapeadas:
- Prossiga para a [Ativação de Exposição de API e Governança de Tenants](conversation-audit-api-activation.md).
