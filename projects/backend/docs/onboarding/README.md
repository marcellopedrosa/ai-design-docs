---
document_id: ONBOARD-INDEX
primary_nature: Contexto
objective: Orientar a entrada e a operação inicial segura do backend e da infraestrutura.
scope: Setup local, identidade, CI/CD, deploy e runbooks de onboarding do backend.
non_objectives: Nao substituir settings, arquitetura vigente ou procedimentos de produção aprovados.
owner: DevOps e Engenharia
status: Active
version: 1.55
date: 2026-09-29
last_reviewed: 2026-10-05
keywords: onboarding, ambiente, deploy, keycloak, runbook
principal_statement: Procedimentos devem indicar ambiente, pré-requisitos, riscos e owner antes da execução.
---

# Onboarding e runbooks do backend

## Contrato da coleção

- Conteúdo aceito: guias e runbooks de natureza `Regra` para preparação e operação inicial segura, com ambiente, pré-requisitos, riscos e owner explícitos.
- Owner: DevOps e Engenharia.
- Nomes: `<ambiente-ou-capacidade>-<procedimento>.md` em kebab-case.
- Estados permitidos: `Draft`, `Active`, `Historical` e `Deprecated`.
- Critério de granularidade: separar um procedimento quando ambiente, audiência, owner, risco, pré-requisito ou ciclo operacional forem independentes.
- Inventário atual: nenhum guia ou runbook está registrado neste baseline. O
  inventário histórico abaixo não representa artefatos ativos.

Esta coleção contém guias e runbooks operacionais. Convenção:
`<ambiente-ou-capacidade>-<procedimento>.md`. Tipos aceitos: `Guia` para preparação
e `Runbook` para operação repetível. Estados: `Draft`, `Active`, `Historical`,
`Deprecated`.

~~~text
| Documento | Tipo | Descrição curta |
| --- | --- | --- |
| [Bootstrap do host de desenvolvimento local](local-development-host-bootstrap.md) | Guia | Prepara o acesso Docker, governa o start incremental e alerta sobre o reset Docker global aprovado. |
| [DNS local para desenvolvimento](local-dns-development-setup.md) | Guia | Configura resolução de subdomínios, Web Crypto no navegador e inicialização do ambiente local. |
| [Instalação e deploy em VPS](production-vps-deployment.md) | Runbook | v1.8 exige inventário de Keycloak e bancos existentes antes de escolher entre primeira instalação, atualização ou migração. |
| [GitHub Actions e preparação da VPS](github-production-cicd.md) | Runbook | v1.1 configura pipeline de entrega, egress nos domínios contadorfiscal e auth.duoset e pré-requisitos do host. |
| [Identidade de provisionamento do Keycloak](keycloak-provisioning-identity.md) | Runbook | v2.8 documenta provisionamento com saas-theme, identidades sem OTP e isolamento SMTP. |
| [Auditoria conversacional](conversation-audit-operations-runbook.md) | Runbook | v1.80 governa recovery V89/V90, policy exclusiva de Super Admin personificado e guardas server-owned, usando `Policy-Version`/`If-Policy-Version` no PUT. |
| [Onboarding geral de Conversation Audit em HML e PRD](conversation-audit-hml-prd-onboarding.md) | Guia | Orquestra a topologia, pré-requisitos e sequência de features para habilitação do Conversation Audit em HML e PRD. |
| [Provisionamento de keyrings e gestão criptográfica](conversation-audit-keyring-provisioning.md) | Guia | v1.1 governa o gerador canônico do keyring outbound, CSPRNG de 32 bytes, JSON, permissões 0600/0700 e montagem em `/run/saas-secrets`. |
| [Backfill supervisionado e prontidão durável](conversation-audit-backfill-readiness.md) | Runbook | Opera migração unitária 50x1 em duas fases e valida os 5 riscos zerados na tabela de prontidão durável. |
| [Provisionamento de RBAC no Keycloak](conversation-audit-keycloak-rbac.md) | Runbook | Provisiona role simples ROLE_TENANT_AUDIT, escopos SPA, personificação do Super Admin e revogação de sessões. |
| [Ativação de API e governança de tenants](conversation-audit-api-activation.md) | Runbook | Parametriza allowlist, ativa rotas com camuflagem 404 e coordena force-recreate do backend. |
| [Observabilidade, validação sanitizada e rollback](conversation-audit-observability-rollback.md) | Runbook | Executa smoke tests de caixa-preta, monitora métricas Prometheus e define playbook de rollback fail-closed. |
| [Governança da política de retenção](conversation-audit-retention-administration.md) | Runbook | Governa configuração de retenção por Super Admin personificado com preview token de 300s. |
| [Rollout local da política de pool por tenant](tenant-pool-policy-local-rollout-runbook.md) | Runbook | Executa D0–D5 no baseline Java 25 com cache, telemetria, falhas e rollback somente em fixtures locais, mantendo todas as flags desligadas. |
| [Rollout autorizado de teste da política de pool por tenant](tenant-pool-policy-authorized-test-rollout-runbook.md) | Runbook | Registra os gates aprovados e opera o launcher manual local A/B com lease curta e retorno obrigatório ao `DARK`; rollout ambiental permanece não autorizado. |
| [Política de pool gerenciada no DEV](tenant-pool-policy-managed-dev-runbook.md) | Runbook | Inicia o runtime gerenciado normal, valida readiness e testa pela tela alteração A/B e rollback sem restart. |
| [Configuração de webhooks omnichannel](omnichannel-webhook-configuration.md) | Runbook | v1.4 governa DEV/HML/PRD, exige keyrings criptográficos antes do webhook remoto, proxy Docker canônico, autenticação Telegram, TLS e diagnóstico de 429/503. |
| [Configuração de pool por tenant em HML e PRD](tenant-pool-policy-hml-prd-configuration.md) | Guia | Draft: orienta flags, capacidade, autoridade, readiness, canary e rollback sem executar deploy ou ler segredos. |

~~~

## Change Log

| Version | Date | Changes |
| --- | --- | --- |
| 1.55 | 2026-10-05 | Adiciona o runbook de configuração do CAPTCHA do website em HML/PRD na VPS. |
| 1.54 | 2026-10-02 | Distingue PRD nova de Keycloak e bancos existentes e bloqueia adoção implícita de estado não registrado. |
| 1.53 | 2026-10-02 | Consolida o roteiro global da primeira instalação no runbook de VPS, mantendo um único ponto de entrada para PRD. |
| 1.52 | 2026-10-02 | Alerta que o reset DEV aprovado alcança todo o daemon Docker local e não reinicia a stack. |
| 1.51 | 2026-10-02 | Define o gerador canônico de responsabilidade única para o keyring HMAC outbound e esclarece que sua execução é explícita, anterior ao container/backend. |
| 1.50 | 2026-10-02 | Torna os três keyrings e as seis variáveis `CONVERSATION_*` pré-requisito bloqueante do webhook Telegram em HML/PRD; alinha o deploy canônico, o diagnóstico `PERSISTENCE_UNAVAILABLE` e o pedido de provisionamento da Infra. |
| 1.49 | 2026-09-29 | Atualiza o onboarding de webhooks para v1.3 com plano DEV/HML/PRD, proxy Docker canônico, secret header Telegram e diagnóstico de 503. |
| 1.48 | 2026-09-29 | Fecha o plano de execução HML/PRD, a paridade dos keyrings no Compose e a validação correta do smoke POST do Conversation Audit. |
| 1.47 | 2026-09-29 | Adiciona os 7 documentos modulares de onboarding para Conversation Audit em HML e PRD (orquestração, keyrings, backfill, RBAC, ativação de API, observabilidade e retenção). |
| 1.46 | 2026-09-29 | Atualiza o runbook de webhooks para v1.2 com guia arquitetural para Nginx nativo no host vs Docker na VPS. |
| 1.45 | 2026-09-29 | Atualiza o runbook de webhooks para v1.1 com detalhamento técnico das diretivas de Nginx em HML e PRD. |
| 1.44 | 2026-09-29 | Adiciona runbook de configuração de webhooks omnichannel em HML e PRD (omnichannel-webhook-configuration.md). |
| 1.43 | 2026-09-25 | Atualiza os runbooks de VPS (v1.4) e CI/CD (v1.1) para contadorfiscal.com.br e auth.duoset.com.br em PRD, e *.contadorfiscal.com.br em HML. |
| 1.42 | 2026-09-25 | Atualiza o runbook Keycloak para v2.8 com uso do tema saas-theme e dispensa de OTP para usuários estáticos. |
| 1.41 | 2026-09-24 | Atualiza o runbook Keycloak para v2.7 com provisionamento multiambiente por Admin REST API e conciliação de UUID. |
| 1.40 | 2026-09-10 | Atualiza o runbook Keycloak para v2.5 com diagnóstico `user_not_found`, isolamento de identidades por realm e pré-condição de convite/ativação no Tenant. |
| 1.39 | 2026-09-09 | Atualiza o runbook da auditoria para v1.80 e restringe a operação da policy ao Super Admin bruto sob personificação ativa. |
| 1.38 | 2026-09-09 | Atualiza o runbook Keycloak para v2.4 com recuperação operacional do estado 2FA condicional vazio e referência exclusiva à ANL-00053. |
| 1.37 | 2026-09-09 | Atualiza o runbook de Auditoria Conversacional para v1.79 com toggle tenant e guardas operacionais server-owned. |
