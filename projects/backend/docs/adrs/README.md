---
document_id: ADRS-INDEX
primary_nature: Contexto
objective: Permitir seleção semântica de decisões do backend antes da leitura integral.
scope: ADRs propostos, aceitos e históricos em projects/backend/docs/adrs/.
non_objectives: Nao duplicar o conteúdo integral nem criar decisão por meio do índice.
owner: Arquitetura
status: Active
version: 6.55
date: 2026-08-29
last_reviewed: 2026-09-12
keywords: adr, decisoes, arquitetura, indice, openapi, api-contract, gemini, antigravity
principal_statement: Consulte este índice e abra somente os ADRs relacionados; decisões sobre API HTTP vinculam o contrato OpenAPI canônico aplicável.
---

# ADR Index — Backend

## Contrato da coleção

- Conteúdo aceito: decisões arquiteturais propostas, aceitas e históricas, com contexto, alternativas, decisão, consequências e rastreabilidade.
- Owner: Arquitetura.
- Nomes: `ADR-NNNN-short-title.md`; o mesmo `ADR-NNNN` identifica arquivo, metadados, H1 e entrada de catálogo.
- Estados permitidos: `Proposed`, `Accepted`, `Rejected`, `Superseded` e `Deprecated`; `Partially Superseded` exige sucessores explicitamente relacionados.
- Critério de granularidade: separar uma decisão quando alternativas, owner, vigência, consequências ou ciclo de revisão puderem evoluir de forma independente.
- Inventário: todo ADR do diretório possui entrada e link individuais na visão geral; as rotas temáticas apenas ajudam a selecionar a fonte relevante.
- Contrato de API: ADR que cria, altera, restringe ou deprecia API HTTP do backend
  deve referenciar o OpenAPI canônico em `docs/api_contracts/`, `info.version`, status,
  `operationId`s, compatibilidade e a decisão que o restringe. Sem impacto, declara
  `API Contract: N/A` com justificativa objetiva.

> **Propósito:** Este índice semântico serve como ponto de entrada para LLMs e agentes IA pesquisarem decisões arquiteturais **antes** de carregar os documentos completos. Consulte este índice para identificar qual(is) ADR(s) são relevantes para o contexto da tarefa. Abra o ADR completo apenas quando necessário.

---

## Visão Geral Rápida

| ADR | Título | Status | Data | Domínio Principal |
|-----|--------|--------|------|-------------------|
| [ADR-0001](ADR-0001-technology-stack-and-architecture.md) | Technology Stack and Architecture Foundation | Partially Superseded | 2026-03-06 / Java target superseded 2026-08-28 | Fundação |
| [ADR-0002](ADR-0002-separacao-banco-por-contexto-multitenancy.md) | Multi-Tenant Database Isolation Strategy | Partially Superseded | 2026-03-08 | Banco de Dados / Multi-Tenancy |
| [ADR-0003](ADR-0003-multitenancy-schema-vs-tenant-id.md) | Multi-Tenancy Schema vs tenant_id | Accepted | 2026-03-08 | Multi-Tenancy |
| [ADR-0004](ADR-0004-whatsapp-integration-architecture.md) | WhatsApp Integration Architecture | Accepted | 2026-03-11 | Integração WhatsApp |
| [ADR-0005](ADR-0005-multi-tenancy-architecture.md) | Multi-Tenancy Architecture (Completa) | Accepted | 2026-03-08 | Multi-Tenancy / Segurança |
| [ADR-0006](ADR-0006-audit-compliance.md) | Audit and Compliance Strategy | Proposed | 2026-03-09 | Auditoria / LGPD |
| [ADR-0007](ADR-0007-multi-provider-llm-integration.md) | Multi-Provider LLM Integration Architecture | Accepted | 2026-03-11 | Integração LLM / IA |
| [ADR-0008](ADR-0008-stripe-billing-subscription.md) | Stripe Billing & Subscription Management | Superseded | 2026-03-11 | Billing / Pagamentos / Histórico |
| [ADR-0009](ADR-0009-dynamic-rbac-evolution.md) | Dynamic RBAC Evolution Strategy | Accepted | 2026-03-12 | Segurança / RBAC |
| [ADR-0010](ADR-0010-tenant-plan-parametrization.md) | Tenant Plan Parametrization & Resource Limits | Accepted | 2026-04-05 | Billing / Limites de Plano |
| [ADR-0011](ADR-0011-resilience-retry-circuit-breaker.md) | Resilience: Retry, Circuit Breaker & Fault Tolerance | Accepted | 2026-04-17 | Resiliência / Integrações Externas |
| [ADR-0012](ADR-0012-error-handling-observability.md) | Error Handling & Observability (Logs, Trace, Metrics) | Accepted | 2026-04-17 | Erros / Observabilidade |
| [ADR-0014](ADR-0014-CNPJ-changed.md) | Transição para Documento Alfanumérico | Proposed | 2026-04-27 | Regras de Negócio / Domínio |
| [ADR-0015](ADR-0015-telegram-integration.md) | Telegram Integration Architecture | Accepted | 2026-05-30 | Integração Telegram / Omnichannel |
| [ADR-0016](ADR-0016-infrastructure-environment-provisioning.md) | Infrastructure Environment Provisioning — bootstrap, reset-to-ready e preflight incremental não disruptivo; VPS histórica superseded | Partially Superseded | 2026-06-12 / local reconciled 2026-09-05 | Infraestrutura / DevOps / Deploy |
| [ADR-0056](ADR-0056-global-docker-development-reset.md) | Reset Docker global DEV aprovado, limitado ao daemon local e confirmado no terminal | Accepted | 2026-10-02 | Infraestrutura / DevOps / Segurança |
| [ADR-0017](ADR-0017-spring-ai-chatclient-abstraction.md) | Uso do Spring AI e ChatClient como Abstração para LLMs | Proposed (reconstructed) | 2026-07-16 | Integração LLM / IA / Abstração |
| [ADR-0018](ADR-0018-keycloak-realm-provisioning-automation.md) | Keycloak Realm Provisioning Automation; v4.1 usa `RealmRepresentation` programático no onboarding tenant | Accepted | 2026-07-24 / emenda 2026-09-24 | Segurança / IAM / Automação |
| [ADR-0019](ADR-0019-database-per-tenant.md) | Estratégia de Single Database-per-Tenant | Partially Superseded | 2026-07-24 | Banco de Dados / Isolamento LGPD |
| [ADR-0020](ADR-0020-centralized-tenant-discovery.md) | Centralized Authentication Portal & Realm-per-Tenant Discovery | Proposed | 2026-07-24 | Autenticação / IAM / UX / Multi-Tenancy |
| [ADR-0021](ADR-0021-llm-resilience-fallback-strategy.md) | LLM Resilience and Fallback Strategy | Accepted | 2026-07-27 | Integração LLM / Resiliência |
| [ADR-0022](ADR-0022-notification-center-architecture.md) | Notification Center Architecture | Accepted | 2026-07-12 | Notificações / Omnichannel |
| [ADR-0023](ADR-0023-agnostic-payment-provider-integration.md) | Integração agnóstica de provedores de pagamento | Accepted | 2026-08-21 | Billing / Pagamentos / Providers |
| [ADR-0024](ADR-0024-seguranca-tokenizacao-cartao-recorrente.md) | Segurança e tokenização de cartão para cobrança recorrente | Accepted | 2026-08-22 | Billing / Segurança / PCI |
| [ADR-0025](ADR-0025-suspensao-tenant-inadimplencia-recuperacao.md) | Suspensão de tenant por inadimplência e recuperação segura | Accepted | 2026-08-22 | Billing / Dunning / Acesso financeiro |
| [ADR-0026](ADR-0026-billing-api-tenant-admin-cutover.md) | Separa APIs de Billing tenant/admin e define cutover sem aliases globais ou MSW em runtime | Accepted | 2026-08-23 | Billing / API / Multitenancy |
| [ADR-0027](ADR-0027-catalogo-global-faturamento-local.md) | Catálogo global da GV Software no control plane e faturamento isolado no banco de cada tenant | Accepted | 2026-08-23 | Billing / Dados / Multitenancy |
| [ADR-0028](ADR-0028-entitlements-versionados-tenant-local.md) | Entitlements globais versionados com snapshot contratual e projeção tenant-local | Accepted | 2026-08-23 | Billing / Entitlements / Multitenancy |
| [ADR-0029](ADR-0029-taxonomia-tipificada-entitlements.md) | Taxonomia tipada de direitos, add-ons, promoções, exceções e restrições de entitlement | Accepted | 2026-08-23 | Billing / Entitlements / Segurança |
| [ADR-0030](ADR-0030-composicao-deterministica-enforcement-entitlements.md) | Composição determinística, precedência e enforcement de entitlements | Accepted | 2026-08-23 | Billing / Entitlements / Quotas |
| [ADR-0031](ADR-0031-governanca-topologia-infraestrutura.md) | Governança e topologia do pacote de infraestrutura | Accepted | 2026-08-23 | Infraestrutura / DevOps / Governança |
| [ADR-0032](ADR-0032-adocao-versionada-grandfathering-entitlements.md) | Adoção versionada e grandfathering de entitlements por contrato | Accepted | 2026-08-23 | Billing / Contratos / Entitlements |
| [ADR-0033](ADR-0033-arquitetura-alvo-iac-segura.md) | Arquitetura-alvo segura e incremental de IaC | Accepted | 2026-08-23 | Infraestrutura / IaC / Segurança |
| [ADR-0034](ADR-0034-efeitos-transicao-nao-destrutiva-entitlements.md) | Efeitos não destrutivos de upgrade/downgrade de entitlements | Accepted | 2026-08-23 | Billing / Entitlements / Dados |
| [ADR-0035](ADR-0035-migracao-evidence-first-entitlements-legados.md) | Migração evidence-first de entitlements legados por tenant | Accepted | 2026-08-23 | Billing / Entitlements / Migração |
| [ADR-0036](ADR-0036-cache-lkg-fail-safe-entitlements.md) | Cache derivado, LKG limitado e fail-safe de entitlements | Accepted | 2026-08-23 | Billing / Entitlements / Resiliência |
| [ADR-0037](ADR-0037-boundary-fisico-entitlements-billing.md) | Boundary físico e ownership de entitlements dentro do módulo Billing | Accepted | 2026-08-24 | Billing / Entitlements / Arquitetura |
| [ADR-0038](ADR-0038-pricing-tipado-moeda-cadencia.md) | Pricing tipado, moeda e cadência do primeiro slice | Accepted | 2026-08-25 | Billing / Pricing / Catálogo |
| [ADR-0039](ADR-0039-taxonomia-beneficios-promocionais.md) | Taxonomia tipada de benefícios promocionais | Accepted | 2026-08-24 | Billing / Promoções / Pricing / Entitlements |
| [ADR-0040](ADR-0040-elegibilidade-promocional-seguranca-cupons.md) | Elegibilidade promocional e segurança de cupons | Accepted | 2026-08-24 | Billing / Promoções / Segurança / Multitenancy |
| [ADR-0041](ADR-0041-stacking-waterfall-promocional-deterministico.md) | Stacking e waterfall promocional determinísticos | Accepted | 2026-08-24 | Billing / Promoções / Pricing / Determinismo |
| [ADR-0042](ADR-0042-capacidade-redemption-promocional-concorrente.md) | Capacidade e redemption promocional concorrente | Accepted | 2026-08-25 | Billing / Promoções / Concorrência |
| [ADR-0043](ADR-0043-governanca-lifecycle-promocional.md) | Governança e lifecycle operacional promocional | Accepted | 2026-08-25 | Billing / Promoções / Governança |
| [ADR-0044](ADR-0044-lifecycle-contratual-proration-assinaturas.md) | Lifecycle contratual, proration e assinaturas | Accepted | 2026-08-25 | Billing / Contratos / Assinaturas |
| [ADR-0045](ADR-0045-metering-rating-fechamento-fatura.md) | Metering, rating e fechamento de fatura comercial | Accepted | 2026-08-25 | Billing / Uso / Rating / Invoice |
| [ADR-0046](ADR-0046-correcao-cancelamento-reemissao-fatura.md) | Correção, cancelamento e reemissão de fatura comercial | Accepted | 2026-08-25 | Billing / Invoice / Correções |
| [ADR-0047](ADR-0047-ledger-creditos-refunds-disputas-writeoff.md) | Ledger de créditos, refunds, disputas e write-off | Accepted | 2026-08-25 | Billing / Créditos / Refunds / Disputas |
| [ADR-0048](ADR-0048-separacao-fatura-comercial-documento-fiscal-nfse.md) | Separação entre fatura comercial e documento fiscal NFS-e | Accepted | 2026-08-25 | Billing / Fiscal / NFS-e |
| [ADR-0049](ADR-0049-subledger-tenant-local-mrr-normalizado.md) | Subledger tenant-local e MRR normalizado | Accepted | 2026-08-25 | Billing / Subledger / Analytics |
| [ADR-0050](ADR-0050-rbac-sod-aprovacoes-financeiras.md) | RBAC e operações financeiras; v1.10/D-13.3–13.5 remove segundo aprovador para SUPER_ADMIN e MFA de todas as roles em DEV/HML/PRD, preservando RBAC e auditoria | Accepted | 2026-08-25 / emenda 2026-09-10 | Billing / Segurança / Auditoria |
| [ADR-0051](ADR-0051-slo-capacidade-rollout-billing.md) | SLO, capacidade e rollout seguro de Billing | Accepted | 2026-08-25 | Billing / SRE / Rollout |
| [ADR-0052](ADR-0052-parametros-pool-conexao-por-tenant.md) | Pools de conexão exclusivos e configuráveis por tenant | Accepted v1.12 — REQ-00052 aprovado e IP HML criado somente em `Proposed`; sem deploy, acesso ambiental ou sizing | 2026-08-26 | Banco de Dados / Multitenancy / Capacidade |
| [ADR-0053](ADR-0053-adocao-java-25-backend.md) | Adoção de Java 25, virtual threads e eficiência do backend | Accepted | 2026-08-28 | Fundação / Backend / Performance |
| [ADR-0054](ADR-0054-omnichannel-tenant-local-durable-inbox.md) | Inbox durável omnichannel no banco do tenant | Accepted | 2026-08-29 | Omnichannel / Persistência / Resiliência |
| [ADR-0055](ADR-0055-payment-provider-operational-control-plane.md) | Control plane operacional de provedores de pagamento; v1.8 aplica a dispensa temporaria de MFA em DEV/HML/PRD e preserva as mutações Super Admin por RBAC | Accepted | 2026-09-06 / emenda 2026-09-11 | Billing / Pagamentos / Observabilidade |

## Rotas temáticas

| Tema | ADRs para selecionar |
| --- | --- |
| Fundação arquitetural, runtime Java e concorrência | [ADR-0001](ADR-0001-technology-stack-and-architecture.md), [ADR-0053](ADR-0053-adocao-java-25-backend.md) |
| Multitenancy e isolamento de dados | [ADR-0002](ADR-0002-separacao-banco-por-contexto-multitenancy.md), [ADR-0003](ADR-0003-multitenancy-schema-vs-tenant-id.md), [ADR-0005](ADR-0005-multi-tenancy-architecture.md), [ADR-0019](ADR-0019-database-per-tenant.md), [ADR-0052](ADR-0052-parametros-pool-conexao-por-tenant.md), [ADR-0054](ADR-0054-omnichannel-tenant-local-durable-inbox.md) |
| Omnichannel e notificações | [ADR-0004](ADR-0004-whatsapp-integration-architecture.md), [ADR-0015](ADR-0015-telegram-integration.md), [ADR-0022](ADR-0022-notification-center-architecture.md), [ADR-0054](ADR-0054-omnichannel-tenant-local-durable-inbox.md) |
| Segurança, auditoria, IAM e RBAC | [ADR-0006](ADR-0006-audit-compliance.md), [ADR-0009](ADR-0009-dynamic-rbac-evolution.md), [ADR-0018](ADR-0018-keycloak-realm-provisioning-automation.md), [ADR-0020](ADR-0020-centralized-tenant-discovery.md), [ADR-0050](ADR-0050-rbac-sod-aprovacoes-financeiras.md), [ADR-0052](ADR-0052-parametros-pool-conexao-por-tenant.md) |
| LLM e resiliência de IA | [ADR-0007](ADR-0007-multi-provider-llm-integration.md), [ADR-0017](ADR-0017-spring-ai-chatclient-abstraction.md), [ADR-0021](ADR-0021-llm-resilience-fallback-strategy.md) |
| Resiliência e observabilidade | [ADR-0011](ADR-0011-resilience-retry-circuit-breaker.md), [ADR-0012](ADR-0012-error-handling-observability.md), [ADR-0052](ADR-0052-parametros-pool-conexao-por-tenant.md), [ADR-0054](ADR-0054-omnichannel-tenant-local-durable-inbox.md), [ADR-0055](ADR-0055-payment-provider-operational-control-plane.md) |
| Identidade de documento | [ADR-0014](ADR-0014-CNPJ-changed.md) |
| Infraestrutura, deploy e IaC | [ADR-0016](ADR-0016-infrastructure-environment-provisioning.md), [ADR-0031](ADR-0031-governanca-topologia-infraestrutura.md), [ADR-0033](ADR-0033-arquitetura-alvo-iac-segura.md) |
| Billing legado, pagamentos, dunning e APIs | [ADR-0008](ADR-0008-stripe-billing-subscription.md), [ADR-0023](ADR-0023-agnostic-payment-provider-integration.md), [ADR-0024](ADR-0024-seguranca-tokenizacao-cartao-recorrente.md), [ADR-0025](ADR-0025-suspensao-tenant-inadimplencia-recuperacao.md), [ADR-0026](ADR-0026-billing-api-tenant-admin-cutover.md), [ADR-0055](ADR-0055-payment-provider-operational-control-plane.md) |
| Catálogo, entitlements e transições | [ADR-0010](ADR-0010-tenant-plan-parametrization.md), [ADR-0027](ADR-0027-catalogo-global-faturamento-local.md), [ADR-0028](ADR-0028-entitlements-versionados-tenant-local.md), [ADR-0029](ADR-0029-taxonomia-tipificada-entitlements.md), [ADR-0030](ADR-0030-composicao-deterministica-enforcement-entitlements.md), [ADR-0032](ADR-0032-adocao-versionada-grandfathering-entitlements.md), [ADR-0034](ADR-0034-efeitos-transicao-nao-destrutiva-entitlements.md), [ADR-0035](ADR-0035-migracao-evidence-first-entitlements-legados.md), [ADR-0036](ADR-0036-cache-lkg-fail-safe-entitlements.md), [ADR-0037](ADR-0037-boundary-fisico-entitlements-billing.md) |
| Pricing e promoções | [ADR-0038](ADR-0038-pricing-tipado-moeda-cadencia.md), [ADR-0039](ADR-0039-taxonomia-beneficios-promocionais.md), [ADR-0040](ADR-0040-elegibilidade-promocional-seguranca-cupons.md), [ADR-0041](ADR-0041-stacking-waterfall-promocional-deterministico.md), [ADR-0042](ADR-0042-capacidade-redemption-promocional-concorrente.md), [ADR-0043](ADR-0043-governanca-lifecycle-promocional.md) |
| Contratos, medição e fatura comercial | [ADR-0044](ADR-0044-lifecycle-contratual-proration-assinaturas.md), [ADR-0045](ADR-0045-metering-rating-fechamento-fatura.md), [ADR-0046](ADR-0046-correcao-cancelamento-reemissao-fatura.md) |
| Créditos, fiscal, subledger e analytics | [ADR-0047](ADR-0047-ledger-creditos-refunds-disputas-writeoff.md), [ADR-0048](ADR-0048-separacao-fatura-comercial-documento-fiscal-nfse.md), [ADR-0049](ADR-0049-subledger-tenant-local-mrr-normalizado.md) |
| SLO, capacidade e rollout de Billing | [ADR-0051](ADR-0051-slo-capacidade-rollout-billing.md) |

## Convenções

- **Nomenclatura dos arquivos:** `ADR-NNNN-short-title.md`.
- **Estados possíveis:** `Proposed`, `Accepted`, `Rejected`, `Superseded`, `Partially Superseded` e `Deprecated`.
- **Idioma:** preserva o idioma adotado por cada ADR; títulos e identificadores permanecem estáveis.
- **Localização:** `docs/adrs/`.

## Change Log

| Version | Date | Changes |
| --- | --- | --- |
| 6.55 | 2026-10-02 | Indexa ADR-0056 e registra a sucessão do reset limitado ao projeto no ADR-0016 §7.2. |
| 6.54 | 2026-09-13 | Atualiza ADR-0000 para v4.25 e torna autônoma a criação/troca para branch governada antes do commit. |
| 6.53 | 2026-09-13 | Atualiza ADR-0000 para v4.24 e institui hook `commit-msg` obrigatório por worktree. |
| 6.52 | 2026-09-13 | Atualiza ADR-0000 para v4.23 e deriva o escopo de commit da branch do worktree. |
| 6.51 | 2026-09-13 | Atualiza ADR-0000 para v4.22 e exige o número puro da task no escopo de Conventional Commits. |
| 6.50 | 2026-09-12 | Atualiza ADR-0000 para v4.21 e torna `clean verify` obrigatório no backend/pr contra dados JaCoCo e XML históricos. |
| 6.49 | 2026-09-11 | Atualiza ADR-0000 para v4.20 e incorpora Gemini CLI e Google Antigravity à governança documental agnóstica. |
| 6.48 | 2026-09-11 | Atualiza ADR-0055 para v1.8 e reconcilia a dispensa temporária de MFA em DEV/HML/PRD sem ampliar autorização das mutações. |
| 6.47 | 2026-09-11 | Atualiza ADR-0018 para v3.7: dispensa temporaria de MFA para todas as roles em DEV/HML/PRD, com reativacao humana e evidencia DEV explicitamente historica. |
| 6.46 | 2026-09-10 | Atualiza ADR-0050 para v1.10/D-13.5: dispensa MFA de todas as roles nos três ambientes, preservando RBAC e auditoria. |
| 6.45 | 2026-09-10 | Atualiza ADR-0050 para v1.9/D-13.4: dispensa MFA somente para `SUPER_ADMIN` nos três ambientes e preserva RBAC e demais controles. |
| 6.44 | 2026-09-10 | Atualiza ADR-0000 v4.19 com medição/revisão executável de TP/IP e delimitação do fluxo Git à publicação da branch para PR. |
| 6.43 | 2026-09-10 | Atualiza ADR-0000 v4.18 com quality profile portátil, correção iterativa e branch/commit/push governados depois de A1/A2/A3 em PASS. |
| 6.42 | 2026-09-10 | Atualiza ADR-0000 v4.17 com decomposição automática no IRG, retorno processual do Quality Gate à Phase 7 e corpo integral do teste portátil. |
| 6.41 | 2026-09-10 | Atualiza ADR-0050 para v1.8/D-13.3: remove definitivamente segundo aprovador de operações SUPER_ADMIN em DEV/HML/PRD e preserva drafts, histórico e publicação explícita. |
| 6.40 | 2026-09-10 | Atualiza ADR-0000 v4.16 para permitir métrica `Not applicable` em PRD pre-market com justificativa e gatilho de reativação. |
| 6.39 | 2026-09-10 | Atualiza ADR-0050 para v1.7/D-13.3: aprovação independente configurável e inicialmente desativada para SUPER_ADMIN em DEV/HML/PRD, preservando alçada e auditoria. |
| 6.38 | 2026-09-10 | Atualiza ADR-0000 v4.15: PRDs inventariam features e referenciam IDs/seções canônicas de aceite sem duplicar seu conteúdo. |
| 6.37 | 2026-09-09 | Torna obrigatório o binding entre ADRs com impacto HTTP e o contrato OpenAPI canônico, versionado e identificado por operações. |
| 6.36 | 2026-09-09 | Atualiza ADR-0000 v4.14 com coleção canônica de PRDs, TPL-00012 e Product Definition Gate integrado ao readiness. |
| 6.35 | 2026-09-09 | Atualiza ADR-0018 v3.6 com a invalidação obrigatória de uma authentication session já posicionada em `login-actions` antes do novo login. |
| 6.34 | 2026-09-09 | Atualiza ADR-0018 v3.5 com toggle DEV-only do provider `CONFIGURE_TOTP` nos realms tenant allowlisted. |
| 6.33 | 2026-09-09 | Atualiza ADR-0018 v3.4 com a ordem canônica `CONFIGURE_TOTP → OTP → pai` no rollback. |
| 6.32 | 2026-09-09 | Atualiza ADR-0018 v3.3 com a topologia segura do toggle Keycloak e ADR-0000 v4.13 com a remoção de log de autenticação inserido acidentalmente, sem alterar sua decisão normativa. |
| 6.31 | 2026-09-09 | Atualiza ADR-0018 v3.2, ADR-0050 v1.6/D-13.2 e ADR-0055 v1.7 com o desligamento temporário, reversível e sem remoção do MFA para Super Admin em DEV, preservando os demais controles e excluindo reconciliação stateful. |
| 6.30 | 2026-09-08 | Atualiza ADR-0000 v4.12 com cobertura obrigatória AC → fluxo → teste/evidência nos casos de uso. |
| 6.29 | 2026-09-08 | Atualiza ADR-0000 v4.11 com User Story View, hard gate de assumptions/Open Questions, task contract finito e skill de implementation readiness. |
| 6.28 | 2026-09-08 | Atualiza ADR-0000 v4.10 com o scaffold portátil do Quality Gate C.L.E.A.R., incluindo standard, skills pareadas, executor, teste e gaps fail-closed. |
| 6.27 | 2026-09-07 | Atualiza ADR-0018 v3.1 com SMTP por realm e ADR-0022 v1.1 com o boundary que mantém links/tokens de credencial fora da Central de Notificações. |
| 6.26 | 2026-09-07 | Atualiza ADR-0053 para v1.2 com evidência final do cutover Java 25, mantendo virtual threads e performance como etapas posteriores. |
| 6.25 | 2026-09-06 | Atualiza ADR-0055 para v1.6: fecha gaps/links e navegação por audiência, metadata segura, mutation switch default OFF, envelope HTTP e custódia de `seal_key_id` enquanto houver referência persistida. |
| 6.24 | 2026-09-06 | Atualiza ADR-0055 para v1.5: torna exact replay concorrente obrigatório, com fence bounded, resultado terminal original, conflito divergente e timeout fail-closed. |
| 6.23 | 2026-09-06 | Atualiza ADR-0055 para v1.4: decide evento efetivo monotônico, ordem de chegada, quarentena mínima, freshness tenant conservadora, authority fina e retenção de replay sem pinning. |
| 6.22 | 2026-09-06 | Atualiza ADR-0055 para v1.3: referências catalogadas fecham URI/path/SSRF e ApprovalSeal congela o baseline ativo/versionado contra drift concorrente. |
| 6.21 | 2026-09-06 | Atualiza ADR-0055 para v1.2: quarentena admin pode permanecer sem tenant resolvido e pausa/retomada passam pelo workflow completo de revisão, sem atalho ou seal órfão. |
| 6.20 | 2026-09-06 | Indexa o ADR-0055 aceito para o control plane global sem segredos e a projeção operacional sanitizada de provedores de pagamento. |
| 6.19 | 2026-09-06 | Atualiza ADR-0050 para v1.5, distinguindo a decisão documental histórica das suítes que materializam e validam `D-13.1` no TP-00038. |
| 6.18 | 2026-09-06 | Atualiza ADR-0050 para v1.4 com `D-13.1 = HUMAN_EXPLICIT`: somente o POST administrativo emite o waiver, cujo uso fica restrito às cinco authorities contratuais, inclusive `ACCEPT_VALIDATE`, sem remover SoD/approval. |
| 6.17 | 2026-09-05 | Atualiza ADR-0016 v1.5 com o lifecycle incremental Prepare/Commit/Verify/Cleanup, credenciais stateful comprovadas e cutover restrito a componentes stateless. |
| 6.16 | 2026-09-04 | Atualiza ADR-0050 para v1.3 com `D-01.1 = HUMAN_EXPLICIT`, distinção entre Super Admin global/personificado e referência à matriz central AS-IS de RBAC frontend. |
| 6.15 | 2026-09-03 | Atualiza o ADR-0054 v1.5 com progresso transitório no ledger e sem persistência concorrente do aggregate. |
| 6.14 | 2026-09-03 | Atualiza o ADR-0054 v1.4 com a invariante transacional pai/filho do ledger outbound e a distinção entre ownership e progresso. |
| 6.13 | 2026-09-02 | Atualiza a rastreabilidade do ADR-0054 v1.3 após comprovação PostgreSQL do heartbeat e FIFO pós-quarentena em Telegram e WhatsApp. |
| 6.12 | 2026-09-02 | Atualiza o ADR-0000 v4.9 com a seção técnica e o código mínimo para criar o wrapper canônico em repositórios portados. |
| 6.11 | 2026-09-02 | Atualiza o ADR-0000 v4.8: o wrapper agregado torna-se o entrypoint canônico e a skill `governanca-documental` é ativada com paridade Codex/Claude. |
| 6.10 | 2026-09-02 | Atualiza ADR-0052 v1.12 com REQ-00052 como quinto componente operacional e TP-00030; registra o IP HML criado somente em `Proposed`, mantendo aprovacao, inicio, deploy, acesso HML/PRD e sizing bloqueados. |
| 6.9 | 2026-09-01 | Atualiza ADR-0052 v1.11 com REQ-00051: runtime gerenciado sem restart, autoridade renovável, bootstrap committed e contrato DEV/HML/PRD fail-closed. |
| 6.8 | 2026-08-31 | Atualiza a rastreabilidade do ADR-0052 v1.10 após routing `8/8`, isolation gate `30/30` e control-plane PostgreSQL `5/5`; preserva rollout ambiental como não autorizado. |
| 6.7 | 2026-08-29 | Indexa o ADR-0054 aceito: inbox tenant-local, ACK-after-commit, FIFO por conversa, lease/fencing e retry somente antes de efeito incerto. |
| 6.6 | 2026-08-28 | Atualiza a rastreabilidade do ADR-0052 v1.9 para backend local implementado, preservando o rehearsal Docker e qualquer rollout ambiental como pendentes. |
| 6.5 | 2026-08-28 | Atualiza o ADR-0052 v1.8 com o componente REQ-00049: profile local opt-in, A mutável/B controle, teto 10, envelope `60 <= 80`, guardas fail-closed e rollout externo apenas planejado. |
| 6.4 | 2026-08-28 | Indexa o ADR-0053 aceito para Java 25, virtual threads por lane e eficiência medida; marca o ADR-0001 parcialmente superseded somente no recorte Java 21/runtime e reconcilia o versionamento do índice. |
| 6.3 | 2026-08-27 | Atualiza ADR-0052 v1.7: wireframe textual aprovado e decisões locais de bounds/seeds Hikari, rollback, admission, topologia e retenção/legal hold fechadas; efeitos externos seguem default-off. |
| 6.2 | 2026-08-27 | Registra no ADR-0052 a autorização humana posterior para planejamento e implementação frontend local; o primeiro recorte é não visual e componentes React/Tailwind permanecem condicionados a wireframe aprovado. |
| 6.1 | 2026-08-27 | Registra no ADR-0052 a política selecionada do NFR REQ-00048: Redis compartilhado sem L1, uma revisão committed por tenant/chave exata, TTL global bounded, eviction isolada, rebuild/breaker limitados e default-off; porte do escritório continua afetando apenas o pool Hikari. |
| 6.0 | 2026-08-27 | Mantém o ADR-0052 como decisão única de política de pool e registra seus componentes normativos RF REQ-00047 e NFR REQ-00048; o cache coberto é somente a projeção tenant-scoped da política, sem governança geral de Redis ou parametrização de caches funcionais por porte. |
| 5.9 | 2026-08-27 | Promove o ADR-0052 a `Accepted` sob autorização humana limitada a planejamento e backend local; marca ADR-0002 parcialmente superseded somente no sizing uniforme de pools dedicados por tenant e ADR-0019 somente no fallback legado do §7. UI, infraestrutura externa, deploy e produção permanecem excluídos. |
| 5.8 | 2026-08-26 | Indexa o ADR-0052, proposta de políticas e gerações Hikari exclusivas por tenant, administradas por Super Admin com orçamento global, swap atômico, drain e fail-closed. |
| 5.7 | 2026-08-26 | Alinha a data catalogada do ADR-0018 à data original declarada pela própria decisão. |
| 5.6 | 2026-08-26 | Compacta o catálogo em inventário completo e rotas temáticas, removendo decisões, proveniência, grafo e resumos duplicados já preservados nos ADRs. |
| 5.3 | 2026-08-26 | Reconcilia o ADR-0016 com o reset-to-ready local, preservando a classificação Partially Superseded e separando o ciclo repo-only da execução destrutiva real. |
| 5.2 | 2026-08-25 | Sincroniza a data canônica e a evidência executável do ADR-0038 após o S6 `STAIRSTEP`; a decisão original humana `D-04.3` e a proveniência AI dos incrementos locais permanecem distinguíveis. |
| 5.1 | 2026-08-25 | Registra `D-00 = RELEASED_WITH_SCOPE — HUMAN_EXPLICIT — TP-00013 local-only`: backend/frontend/DDL/migrations/testes herméticos locais autorizados; chamadas externas, Sandbox ASAAS, piloto BP Farias, produção, flags `ON` e efeitos reais permanecem `OFF`/evidence-gated. |
| 5.0 | 2026-08-25 | Indexa individualmente ADR-0042 a ADR-0051, reconcilia `D-08`/ADR-0023/ADR-0024 e `D-09`/ADR-0025 aceitas, corrige `FINANCIAL_ACCESS_RESTRICTION` como eixo distinto de risco e `PromotionCombinationResult` como cálculo efêmero, acrescenta seções semânticas, tópicos, grafo e proveniência humana/IA explícita e preserva capabilities/evidências bloqueadas e `D-00` ativo. |
| 4.5 | 2026-08-24 | Indexa o ADR-0041 e adiciona grafo, rotas semânticas e tópicos de busca para stacking, exclusividade, best price, waterfall, caps stateless e allocation determinísticos aceitos em `D-04.4-C`; preserva `D-04.4-D`, `D-04.4-E` e `D-00` abertos. |
| 4.4 | 2026-08-24 | Indexa o ADR-0040 e adiciona grafo, rotas semânticas e tópicos de busca para eligibility promocional versionada, tri-state fail-closed e segurança de cupons aceita em `D-04.4-B`. |
| 4.3 | 2026-08-24 | Indexa o ADR-0039 e adiciona grafo, rotas semânticas e tópicos de busca para a taxonomia tipada de benefícios promocionais aceita em `D-04.4-A`. |
| 4.2 | 2026-08-24 | Indexa o ADR-0038 e adiciona suas rotas semânticas, dependências e tópicos de busca para pricing tipado, moeda e cadência. |

Abra somente os ADRs selecionados pelo tema e pelo inventário; não carregue a coleção inteira por padrão.
