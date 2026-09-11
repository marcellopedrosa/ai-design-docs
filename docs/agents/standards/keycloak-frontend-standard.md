---
document_id: KEYCLOAK-FRONTEND-STANDARD
primary_nature: Regra
objective: Definir integração frontend segura com Keycloak por protocolos OIDC/OAuth 2.0.
scope: Authorization Code com PKCE, sessão, tokens, renovação, logout, claims, erros e testes.
non_objectives: Não ativar Keycloak, definir realm, client, roles, fluxo administrativo ou política do provedor.
owner: Identidade, Segurança e Engenharia de Frontend
status: Active
version: 1.0
date: 2026-09-11
last_reviewed: 2026-09-11
keywords: keycloak, oidc, oauth2, pkce, frontend, autenticacao
related_files: README.md, security-standard.md, frontend-standard.md, rbac-frontend-standard.md
code_references: N/A - issuer, clients e adapter dependem do projeto adotante.
principal_statement: Quando Keycloak estiver ativo, o frontend usa fluxo OIDC suportado, valida contexto e não transforma claims locais em autoridade server-side.
---

# Keycloak Frontend Standard

## Ativação

Condicional a ADR e configuração que adotem Keycloak para uma superfície frontend.

## Regras

- Aplicações públicas usam Authorization Code com PKCE, state e nonce; Resource
  Owner Password Credentials e segredo de client no browser são proibidos.
- Issuer, client ID, redirect URIs, post-logout URIs e scopes são explícitos por
  ambiente e usam allowlist estrita.
- Validar issuer, audience, expiração e claims conforme o boundary responsável; o
  frontend não deve aceitar token apenas porque pode decodificá-lo.
- Escolher armazenamento de sessão e tokens por threat model. Evitar persistência
  acessível a script; não registrar token, authorization code ou informação de
  sessão.
- Renovação trata concorrência, rotação, falha e expiração sem loop infinito.
- Logout limpa estado local, cache escopado e sessão do provedor conforme a política
  adotada.
- Roles e groups são traduzidos para o modelo canônico do produto; claims
  desconhecidas resultam em negação por padrão.

## Evidência

Testar login, callback inválido, state/nonce, expiração, renovação concorrente,
logout, acesso negado e limpeza de dados. Configurações reais e secrets não entram
em fixtures ou relatórios.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.0 | 2026-09-11 | Extrai integração Keycloak sem realm, client ou domínio de origem. |
