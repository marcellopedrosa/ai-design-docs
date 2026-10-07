---
document_id: "TP-00010"
primary_nature: "Plano"
objective: "Coordenar a aplicação da mesma identidade visual na apresentação lateral dos logins do frontend e do Keycloak."
scope: "frontend/src/app/(public)/login, componente visual compartilhado por referência e tema infra/keycloak/themes/saas-theme/login."
non_objectives: "Alterar formulários, credenciais, fluxo OIDC, realms, clientes, callbacks ou comportamento de autenticação."
owner: "Codex / Engenharia"
status: "Completed"
date: "2026-08-21"
version: "1.0"
keywords: "plano, coordenacao, login, visual, alignment, keycloak"
related_files: "docs/delivery/plans/README.md"
code_references: "Plano, infra/keycloak/themes/saas-theme/login, frontend/src/features/auth/components/LoginBrandPanel.tsx, infra/keycloak/themes/saas-theme/login/template.ftl, infra/keycloak/themes/saas-theme/login/resources/css/styles.css, keycloak-login-theme-visual-test.sh, infra/scripts/tests/keycloak-login-theme-visual-test.sh, DARFs, infra/scripts/validate-docs.sh"
principal_statement: "A apresentação institucional dos dois estágios do login deve usar a mesma linguagem visual, preservando integralmente os formulários e o fluxo de autenticação de cada aplicação."
---

# TP-00010 — Alinhamento visual do login entre frontend e Keycloak

**Document ID:** `TP-00010`  
**Primary Nature:** `Plano`  
**Objective:** Coordenar a aplicação da mesma identidade visual na apresentação lateral dos logins do frontend e do Keycloak.  
**Scope:** `frontend/src/app/(public)/login`, componente visual compartilhado por referência e tema `infra/keycloak/themes/saas-theme/login`.  
**Non-objectives:** Alterar formulários, credenciais, fluxo OIDC, realms, clientes, callbacks ou comportamento de autenticação.  
**Project:** SaaS Service  
**Date:** 2026-08-21 (v1.3)
**Status:** Completed
**Author / Owner:** Codex / Engenharia  
**Keywords:** login, Keycloak, tema, identidade visual, gráfico, tipografia, autenticação  
**Related Files:** `../../backend/docs/adrs/ADR-0020-centralized-tenant-discovery.md`, `docs/architecture/module-registry.md`  
**Code References:** `frontend/src/features/auth/components/LoginBrandPanel.tsx`, `infra/keycloak/themes/saas-theme/login/template.ftl`, `infra/keycloak/themes/saas-theme/login/resources/css/styles.css`  
**Principal Statement:** A apresentação institucional dos dois estágios do login deve usar a mesma linguagem visual, preservando integralmente os formulários e o fluxo de autenticação de cada aplicação.

---

## 1. Overview

O login inicia no frontend e continua no Keycloak após a seleção do workspace. A
lateral institucional dos dois estágios será alinhada com tipografia sem serifa,
ícone vetorial e gráfico fiscal ilustrativo, sem compartilhar runtime, JavaScript
ou dados entre as aplicações.

## 2. Execution Tracking Matrix

| # | Activity | Status | Evidence |
|---|---|:---:|---|
| 1 | Identificar os limites dos templates e preservar os formulários | ✅ | Componentes da lateral direita delimitados por marcadores e hash local |
| 2 | Atualizar somente a lateral institucional do tema Keycloak | ✅ | `template.ftl` e regras CSS exclusivas da lateral esquerda |
| 3 | Criar regressão focalizada do contrato visual do tema | ✅ | `keycloak-login-theme-visual-test.sh` protege o novo painel e os hashes da lateral direita |
| 4 | Validar documentação, composição, responsividade e handoff | ✅ | Tema renderizado pelo endpoint OIDC real em 1300×655 e 1440×900; gates finais aprovados |
| 5 | Incluir a lista de benefícios nas duas apresentações laterais | ✅ | Três textos equivalentes no frontend e no tema Keycloak, com os formulários preservados |
| 6 | Alinhar as séries do gráfico fiscal nas duas telas | ✅ | Consultas, DAS e Situação Fiscal renderizadas e validadas no frontend e no tema Keycloak |

## 3. Constraints and Decisions

- O formulário e os blocos informativos à direita do Keycloak permanecem
  inalterados.
- O gráfico é SVG estático e explicitamente identificado como ilustrativo; não
  representa métricas reais nem exige API.
- O gráfico usa somente SVG e CSS do próprio tema, sem dependência do bundle
  Next.js.
- A lateral continua oculta abaixo do breakpoint já adotado pelo tema.
- Nenhuma configuração de realm, cliente OIDC, token, senha ou callback será
  alterada.

## 4. Verification

- `bash -n infra/scripts/tests/keycloak-login-theme-visual-test.sh`: aprovado.
- `./infra/scripts/tests/keycloak-login-theme-visual-test.sh`: aprovado; valida o
  painel, a tipografia, o gráfico ilustrativo e os hashes exatos do HTML e CSS da
  lateral direita.
- `npm test -- src/features/auth/components/__tests__/LoginBrandPanel.test.tsx`:
  1 arquivo e 2 testes aprovados, incluindo acessibilidade.
- `npm test -- src/features/auth src/components/auth`: 6 arquivos e 24 testes
  aprovados.
- `NEXT_DIST_DIR=.next-login-benefits-check npm run build -- --webpack`: build de
  produção aprovado; o diretório temporário foi removido após a validação.
- Endpoint OIDC público local do realm `saas-admin`: renderização aprovada em
  1300×655 e 1440×900, sem autenticação, credenciais ou dados reais.
- Frontend local: renderização aprovada nas mesmas duas resoluções. Na viewport
  compacta, a última informação mantém 73 px de separação do gráfico no frontend
  e 89 px no Keycloak.
- Ajuste v1.3: `npm test -- src/features/auth src/components/auth` aprovado com
  6 arquivos e 24 testes; teste focalizado do painel aprovado com 2 testes.
- Ajuste v1.3: build Webpack de produção aprovado com 39 rotas, usando o diretório
  de validação `.next-security-audit` e endpoints locais deliberadamente inválidos.
- Ajuste v1.3: Consultas, DAS e Situação Fiscal conferidos no frontend e no
  endpoint OIDC local em 1300×655 e 1440×900; as três legendas permaneceram
  contidas no cartão e `DARFs` não foi renderizado.
- `git diff --check`: aprovado.
- `./infra/scripts/validate-docs.sh`: aprovado após a criação do plano; repetido
  no fechamento desta execução.
- O login autenticado completo não foi executado por depender do provisionamento
  de uma identidade de teste; o formulário e seu CSS permanecem protegidos por
  hashes sem qualquer alteração.

## 5. Handoff

Registrar arquivos alterados, comandos, resultados, skips e qualquer dependência
local indisponível. Não acessar produção, identidades reais ou segredos.

## 6. Change Log

| Version | Date | Author | Changes |
|---|---|---|---|
| `1.0` | `2026-08-21` | Codex | Plano transversal persistido antes da edição do tema Keycloak. |
| `1.1` | `2026-08-21` | Codex | Implementação concluída, regressão adicionada e tema validado no endpoint OIDC local. |
| `1.2` | `2026-08-21` | Codex | Três benefícios incluídos e validados nas duas laterais institucionais. |
| `1.3` | `2026-08-21` | Codex | Consultas, DAS e Situação Fiscal alinhadas e validadas nas duas telas. |
