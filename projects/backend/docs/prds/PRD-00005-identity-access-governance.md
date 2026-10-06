---
document_id: PRD-00005
primary_nature: Requisito
objective: Definir a intenção, os resultados e o gate de validação de Identidade, Acesso e Governança.
scope: Perfis, autenticação, autori
ação, descoberta de workspace, convites, personificação, recuperação, acesso administrativo e proteção de capacidades sensíveis.
non_objectives: Repetir acceptance criteria, detalhar login ou autorização, decidir IAM/arquitetura, transformar waiver temporário em produto ou autorizar acesso ambiental.
owner: Produto de Identidade, Segurança e Operações
status: Validated
version: 1.37
date: 2026-09-10
last_reviewed: 2026-09-12
keywords: prd, identidade, acesso, autenticacao, autorizacao, rbac, mfa, convite, impersonation
related_files: docs/product/requirements/README.md, projects/backend/docs/prds/PRD-00002-omnichannel-experience.md, projects/backend/docs/prds/PRD-00004-fiscal-operations.md, projects/backend/docs/prds/PRD-00006-conversation-audit-retention-administration.md, docs/product/business/product-vision.md, docs/product/requirements/REQ-00004-rbac-security-mapping.md, docs/product/requirements/REQ-00059-temporary-all-roles-mfa-disablement.md, docs/product/requirements/REQ-00061-temporary-tenant-first-login-mfa-disablement.md, docs/adrs/ADR-0018-keycloak-realm-provisioning-automation.md, docs/product/use-cases/UC-00016-cadastro-convite-usuarios-escritorio.md, docs/product/use-cases/UC-00028-phase2-tenant-lifecycle-and-user-management.md, docs/delivery/plans/implementation_plans/frontend/IP-FE-1.5.5-settings-serpro-route-boundary.md
code_references: backend/src/main/java/br/com/duoset/saas_service/infrastructure/security/, backend/src/main/java/br/com/duoset/saas_service/contexts/tenant/internal/infrastructure/iam/, frontend/, infra/keycloak/
principal_statement: Cada pessoa deve chegar ao workspace e às capacidades corretas com o menor atrito compatível com isolamento, responsabilidade e evidência de acesso.
---

# PRD-00005 — Identidade, Acesso e Governança

## 1. Executive summary

A proposta multitenant exige reconhecer pessoas, descobrir o workspace,
aplicar perfis e proteger capacidades administrativas e sensíveis. O acervo cobre
RBAC, limites por plano, convites, lifecycle de usuário, personificação, recuperação
de senha, auditoria e operações privilegiadas.

Há requisitos aprovados e partes implementadas localmente. Durante o waiver
temporário, o produto não exige MFA de nenhuma role em DEV, HML ou PRD; RBAC,
escopo, transição explícita e auditoria permanecem obrigatórios. A dispensa não é
permanente e termina somente por decisão humana explícita dos owners de Produto e
Segurança, conforme o amadurecimento do uso da ferramenta. Para operações de
`SUPER_ADMIN`, também não há separação entre maker e checker.
Métricas de sucesso não se aplicam a este ciclo sem observação operacional
autorizada. Produto, Compliance e owners de Billing/Tenant aprovaram as decisões
aplicáveis; o Product Definition Gate está fechado para esta versão.

## Problema e evidência

### Problem statement

Usuários precisam acessar somente a organização e as capacidades que
lhes pertencem, sem barreiras desnecessárias. Para o SaaS e o escritório, qualquer
erro de descoberta, autorização, personificação ou recuperação pode produzir
exposição entre tenants, bloqueio de trabalho, fraude ou ausência de responsabilização.

**Decision:** definição do problema aprovada pelo owner em 2026-09-10.

### Evidence currently available

| Evidence | What it supports | Limitation |
| --- | --- | --- |
| [Visão do produto](../business/product-vision.md) | Autorização prévia e isolamento são princípios do produto. | Não contém pesquisa de acesso ou tolerância a atrito. |
| [REQ-00003](../requirements/REQ-00003-rbac-profile-responsibility-matrix.md) e [REQ-00004](../requirements/REQ-00004-rbac-security-mapping.md) | Perfis e mapeamento de segurança estão definidos. | Definição funcional não prova compreensão pelo usuário. |
| [REQ-00031](../requirements/REQ-00031-phase2-tenant-lifecycle-and-access.md) | Convite, descoberta, usuário e personificação possuem baseline aprovada. | Não há funil de ativação ou evidência de suporte. |
| [REQ-00041](../requirements/REQ-00041-chatbot-conversation-audit.md) e [REQ-00043](../requirements/REQ-00043-conversation-audit-data-governance.md) | Acesso e retenção de auditoria são governados. | Operação ambiental e utilidade não estão demonstradas. |
| [REQ-00058](../requirements/REQ-00058-keycloak-password-recovery-smtp.md), [REQ-00059](../requirements/REQ-00059-temporary-all-roles-mfa-disablement.md) e [REQ-00061](../requirements/REQ-00061-temporary-tenant-first-login-mfa-disablement.md) | Recuperação e exceções temporárias possuem controles explícitos. | A abrangência DEV/HML/PRD está reconciliada; execução ambiental completa ainda não foi comprovada. |
| [IP-FE-1.5.5-settings-serpro-route-boundary](../../delivery/plans/implementation_plans/frontend/IP-FE-1.5.5-settings-serpro-route-boundary.md) | A rota `/settings/serpro` aplica Tenant Admin efetiva, nega Super Admin global antes de request e preserva personificação válida; Vitest `18/18`, Playwright `3/3`, build `54/54` e Quality Gate `18/18` passaram em fixture sem `.env*`. | Evidência repository-local/DEV; não certifica provider, credencial ou IAM ambiental e não promove toda F-IAM-002. |

Não existe observação operacional autorizada para validar uso ou experiência. Esta
ausência não cria metas artificiais neste ciclo e não substitui a evidência funcional
dos requisitos e testes.

## Público e contexto

| Audience | Need / job | Expected value |
| --- | --- | --- |
| Usuário do escritório | Descobrir o workspace, entrar e recuperar acesso. | Continuidade com segurança compreensível. |
| Tenant Admin | Convidar usuários e atribuir responsabilidades. | Autonomia com menor risco de privilégio indevido. |
| Super Admin | Administrar tenants e operar personificação autorizada. | Suporte e controle com evidência e limites claros. |

**Decision:** públicos `Usuário do escritório`, `Tenant Admin` e `Super Admin`
aprovados pelo owner em 2026-09-10.

## Outcomes e não-objetivos

> Outcomes quantitativos de tempo, qualidade, cobertura e garantia não são aplicáveis ao escopo MVP.


1. Aumentar a conclusão segura de login, convite, primeiro acesso e recuperação.
2. Reduzir acesso indevido e falsos bloqueios entre tenants, perfis e capacidades.
3. Tornar responsabilidades e restrições administrativas compreensíveis.
4. Conter personificação e ações sensíveis em contexto explícito e auditável.

**Decision:** objetivos aprovados pelo owner em 2026-09-11.

### Non-goals

- Escolher realm, token, claim, protocolo, provider ou implementação de MFA.
- Remover RBAC, isolamento, escopo efetivo ou auditoria em razão da dispensa de MFA.
- Transformar a dispensa temporária de MFA em comportamento permanente.
- Redefinir regras de Billing, Fiscal, Omnichannel ou Tenant.
- Autorizar credenciais, acesso ambiental ou uso de dados reais.
- Recontar fluxos de autenticação, convite, personificação ou recuperação.

## 5. Product scope and limits

### In scope

- perfis, responsabilidades e capacidades disponíveis;
- autenticação e contexto de sessão percebido;
- descoberta de workspace e primeiro acesso;
- convite, ativação, edição, suspensão e remoção de usuário;
- autonomia do Tenant Admin, restrita ao próprio tenant, para gerir usuários,
  clientes e telefones autorizados em `/clients`, credenciais SERPRO em
  `/settings/serpro` e certificados em `/certificates`;
- personificação de tenant e saída segura do contexto;
- acesso a auditoria e dados sujeitos a retenção;
- autorização de operações administrativas e financeiras sensíveis;
- atuação do mesmo `SUPER_ADMIN` como maker e checker nas operações autorizadas;
- recuperação de senha;
- dispensa temporária de MFA para todas as roles em DEV, HML e PRD, preservando
  RBAC, isolamento e auditoria, até decisão humana explícita de Produto e Segurança
  baseada no amadurecimento do uso da ferramenta.

**Decision:** escopo incluído aprovado integralmente pelo owner em 2026-09-11.

### Out of scope for this validation cycle

- desenho técnico de IAM, RBAC, token, sessão ou MFA;
- definição funcional das capacidades protegidas;
- descoberta e autorização por Telegram, governadas pelo `PRD-00002` no contexto
  Omnichannel;
- configurações e comportamento do Chatbot/Omnichannel, governados pelo
  `PRD-00002`;
- consultas e comportamento Fiscal/DAS, governados pelo `PRD-00004`;
- concessão de acesso em DEV/HML/PRD;
- migração de identidades ou dados reais;
- permanência dos waivers descritos por REQ-00059 e REQ-00061.

**Decision:** limites, non-goals e exclusões deste ciclo aprovados pelo owner em
2026-09-11.

## 6. Product validation criteria

O PRD somente pode mudar para `Validated` quando Produto de Identidade e Segurança
registrarem evidência versionada de:

- públicos e jornadas de acesso prioritários;
- modelo-alvo de primeiro acesso, recuperação e MFA após os waivers;
- definição de acesso correto, falso bloqueio e incidente;
- decisão explícita sobre aplicabilidade de métricas neste ciclo;
- validação ou rejeição das hipóteses `H-IAM-*`;
- resolução das perguntas `OQ-IAM-*`;
- aprovação humana de Segurança/Compliance e owners das áreas sensíveis.

Essas condições validam o produto; os critérios funcionais permanecem nos REQs.

zada.

**Decision owner:** Produto de Identidade, Segurança e Operações.

**Date:** 2026-09-10.

**Justification:** nenhuma métrica de sucesso foi solicitada pelo owner. Todas as
metas candidatas foram expurgadas por decisão humana, sem baseline ou target
artificial. O comportamento continua verificável pelos critérios de aceite e testes
das fontes funcionais.

**Reactivation trigger:** nova decisão explícita de Produto que introduza KPI de
produto ou autorize observação operacional para este escopo.

## Métricas

Não aplicável ao escopo MVP; métricas de tempo, qualidade, cobertura e garantia ficam fora desta fase.

## Product Hypotheses

| ID | Hypothesis | Validation method | Evidence | Owner | State |
| --- | --- | --- | --- | --- | --- |
| `H-IAM-001` | Na recuperação iniciada por e-mail, a seleção explícita do tenant evita ambiguidade quando o endereço está associado a mais de um workspace. | Revisão da jornada multi-tenant e de suas fontes funcionais. | O primeiro acesso continua tenant-bound pelo link; na recuperação, o usuário informa o e-mail e seleciona o tenant quando houver mais de um vínculo. Decisão humana de 2026-09-10, sustentada pela descoberta de `REQ-00031` e pelo fluxo de seleção de `UC-00028`; validação reconfirmada pelo owner em 2026-09-11. | Produto | Validated |
| `H-IAM-004` | Personificação explícita melhora suporte mantendo responsabilidade. | Validação humana do valor para suporte e revisão dos controles funcionais aplicáveis. | Validated: o owner confirmou em 2026-09-10 que a personificação melhora significativamente o suporte; responsabilidade, contexto explícito e auditoria permanecem governados por `REQ-00031`. A decisão não cria meta quantitativa e foi reconfirmada em 2026-09-11. | Operações e Segurança | Validated |

## Features e mapa de requirements

| Requirement | Contribution | Current documentary state |
| --- | --- | --- |
| [REQ-00003](../requirements/REQ-00003-rbac-profile-responsibility-matrix.md) | Perfis, responsabilidades e autogestão. | Implemented — autogestão sem restrição de role. |
| [REQ-00004](../requirements/REQ-00004-rbac-security-mapping.md) | Mapeamento e enforcement de segurança. | Approved. |
| [REQ-00005](../requirements/REQ-00005-plan-feature-matrix.md) | Acesso a funcionalidades por plano e perfil. | Approved. |
| [REQ-00030](../requirements/REQ-00030-multitenancy-isolation-verification.md) | Gate de isolamento de acesso. | Approved. |
| [REQ-00031](../requirements/REQ-00031-phase2-tenant-lifecycle-and-access.md) | Convites, usuários, descoberta, acesso e personificação. | Approved. |
| [REQ-00032](../requirements/REQ-00032-phase2-certificate-lifecycle-security.md) | Custódia autorizada de certificado sensível. | Approved. |
| [REQ-00041](../requirements/REQ-00041-chatbot-conversation-audit.md) e [REQ-00043](../requirements/REQ-00043-conversation-audit-data-governance.md) | Autorização e retenção de auditoria conversacional. | Approved. |
| [REQ-00047](../requirements/REQ-00047-super-admin-tenant-pool-policy-administration.md) | Acesso Super Admin a política por tenant. | Implemented. |
| [REQ-00054](../requirements/REQ-00054-super-admin-unified-billing-price-version.md) | Operações privilegiadas de Billing. | Approved. |
| [REQ-00056](../requirements/REQ-00056-payment-provider-management-observability.md) | Operações privilegiadas de provider. | Approved. |
| [REQ-00058](../requirements/REQ-00058-keycloak-password-recovery-smtp.md) | Recuperação de senha. | Implemented repository-local; rollout pendente. |
| [REQ-00059](../requirements/REQ-00059-temporary-all-roles-mfa-disablement.md) | Dispensa temporária de MFA para todas as roles em DEV, HML e PRD, preservando RBAC. | Approved v1.10 — política multiambiente aprovada e elegível para readiness; execução ambiental possui gates próprios. |
| [REQ-00061](../requirements/REQ-00061-temporary-tenant-first-login-mfa-disablement.md) | Waiver temporário no primeiro acesso tenant em DEV, HML e PRD. | Approved v1.5 — elegível para readiness; somente DEV possui evidência histórica de execução. |

Os acceptance criteria permanecem exclusivamente nesses requisitos.

### 9.1 Feature inventory and acceptance coverage

| Feature ID | Product feature / audience outcome | Requirements | Canonical acceptance coverage | Documentary state |
| --- | --- | --- | --- | --- |
| `F-01` | Associar perfis a responsabilidades e capacidades compreensíveis. | [REQ-00003](../requirements/REQ-00003-rbac-profile-responsibility-matrix.md) | [REQ-00003 AC-001–AC-016](../requirements/REQ-00003-rbac-profile-responsibility-matrix.md#8-acceptance-criteria) | Implemented; autogestão sem restrição de role registrada. |
| `F-02` | Aplicar autorização coerente entre interface, API e contexto. | [REQ-00004](../requirements/REQ-00004-rbac-security-mapping.md) | [REQ-00004 AC-001–AC-023](../requirements/REQ-00004-rbac-security-mapping.md#8-acceptance-criteria) | Approved v1.21; AC-023 da rota SERPRO está implementado/testado repository-local/DEV, e os demais critérios preservam seus estados próprios. |
| `F-03` | Restringir funcionalidades conforme plano e perfil do usuário. | [REQ-00005](../requirements/REQ-00005-plan-feature-matrix.md) | [REQ-00005 AC-001–AC-030](../requirements/REQ-00005-plan-feature-matrix.md#7-acceptance-criteria) | Approved. |
| `F-04` | Descobrir workspace e administrar convite/lifecycle do usuário do escritório. | [REQ-00031](../requirements/REQ-00031-phase2-tenant-lifecycle-and-access.md) | [REQ-00031 AC-TEN-001–AC-TEN-027](../requirements/REQ-00031-phase2-tenant-lifecycle-and-access.md#16-acceptance-criteria) | Approved. |
| `F-05` | Impedir acesso cruzado entre tenants em todas as camadas verificadas. | [REQ-00030](../requirements/REQ-00030-multitenancy-isolation-verification.md) | [REQ-00030 AC-001–AC-015](../requirements/REQ-00030-multitenancy-isolation-verification.md#7-acceptance-criteria) | Approved. |
| `F-06` | Autorizar consulta e administração de auditoria conversacional e retenção. | [REQ-00041](../requirements/REQ-00041-chatbot-conversation-audit.md), [REQ-00043](../requirements/REQ-00043-conversation-audit-data-governance.md) | [REQ-00041 AC-AUD-001–AC-AUD-073](../requirements/REQ-00041-chatbot-conversation-audit.md#12-acceptance-criteria); [REQ-00043 AC-AUD-GOV-001–AC-AUD-GOV-066](../requirements/REQ-00043-conversation-audit-data-governance.md#15-acceptance-criteria) | Administração da retenção delegada ao [PRD-00006 Validated](PRD-00006-conversation-audit-retention-administration.md); restante de IAM integra este PRD `Validated`. |
| `F-07` | Restringir custódia e operação de certificados a responsáveis autorizados. | [REQ-00032](../requirements/REQ-00032-phase2-certificate-lifecycle-security.md) | [REQ-00032 AC-CERT-001–AC-CERT-032](../requirements/REQ-00032-phase2-certificate-lifecycle-security.md#7-acceptance-criteria) | Approved. |
| `F-08` | Administrar política de tenant somente por Super Admin autorizado. | [REQ-00047](../requirements/REQ-00047-super-admin-tenant-pool-policy-administration.md) | [REQ-00047 AC-001–AC-033](../requirements/REQ-00047-super-admin-tenant-pool-policy-administration.md#7-acceptance-criteria) | Implemented. |
| `F-09` | Proteger gestão de catálogo, contratos e faturamento privilegiado. | [REQ-00054](../requirements/REQ-00054-super-admin-unified-billing-price-version.md) | [REQ-00054 AC-001–AC-064](../requirements/REQ-00054-super-admin-unified-billing-price-version.md#7-acceptance-criteria) | Approved; implementação repository-local autorizada. |
| `F-10` | Proteger configuração e operação de provedores de pagamento. | [REQ-00056](../requirements/REQ-00056-payment-provider-management-observability.md) | [REQ-00056 AC-PPM-001–AC-PPM-034](../requirements/REQ-00056-payment-provider-management-observability.md#9-acceptance-criteria) | Approved; efeitos externos excluídos. |
| `F-11` | Recuperar senha em ambiente suportado sem expor identidade ou segredo. | [REQ-00058](../requirements/REQ-00058-keycloak-password-recovery-smtp.md) | [REQ-00058 AC-001–AC-009](../requirements/REQ-00058-keycloak-password-recovery-smtp.md#4-critérios-de-aceite) | Implemented repository-local; rollout e entrega real pendentes. |
| `F-12` | Entrar e sair de personificação explícita para suporte autorizado. | [REQ-00031](../requirements/REQ-00031-phase2-tenant-lifecycle-and-access.md) | [REQ-00031 AC-TEN-001–AC-TEN-027](../requirements/REQ-00031-phase2-tenant-lifecycle-and-access.md#16-acceptance-criteria) | Approved. |
| `F-13` | Permitir temporariamente que todas as roles operem sem MFA em DEV, HML e PRD, preservando RBAC e auditoria; `SUPER_ADMIN` também opera sem checker distinto. | [REQ-00059](../requirements/REQ-00059-temporary-all-roles-mfa-disablement.md), [REQ-00054](../requirements/REQ-00054-super-admin-unified-billing-price-version.md) | [REQ-00059 AC-59-001–AC-59-010](../requirements/REQ-00059-temporary-all-roles-mfa-disablement.md#7-acceptance-criteria); [REQ-00054 AC-004/015/051](../requirements/REQ-00054-super-admin-unified-billing-price-version.md#7-acceptance-criteria) | Maker/checker, abrangência, temporariedade e encerramento humano decididos; REQ-00059 Approved v1.10 e elegível para readiness. |
| `F-14` | Permitir primeiro acesso tenant em DEV, HML e PRD durante o waiver temporário de MFA. | [REQ-00061](../requirements/REQ-00061-temporary-tenant-first-login-mfa-disablement.md) | [REQ-00061 AC-61-001–AC-61-008](../requirements/REQ-00061-temporary-tenant-first-login-mfa-disablement.md#3-acceptance-criteria) | REQ-00061 Approved v1.5 e elegível para readiness; DEV possui evidência histórica e HML/PRD dependem de implementação e evidência ambiental próprias. |

As faixas indicam cobertura documental. REQ-00059 e REQ-00061 não definem o modelo
de produto permanente; sua remoção/saída deve ser decidida nas fontes próprias.

## 10. Use cases and decisions by reference

- Usuários e lifecycle: [UC-00016](../use-cases/UC-00016-cadastro-convite-usuarios-escritorio.md),
  [UC-00028](../use-cases/UC-00028-phase2-tenant-lifecycle-and-user-management.md)
  e [UC-00036](../use-cases/UC-00036-user-profile.md).
- Troca/descoberta de tenant: [UC-00014](../use-cases/UC-00014-multi-tenant-seamless-switch.md).
- Super Admin: [UC-00018](../use-cases/UC-00018-gestao-super-admin.md).
- Auditoria: [UC-00035](../use-cases/UC-00035-chatbot-conversation-audit.md).
- Decisões: selecionar Segurança/IAM, Multitenancy e RBAC pelo
  [índice de ADRs](../../adrs/README.md); este PRD não as redefine.

## 11. Current phase assessment

| Dimension | Observed state | Product implication |
| --- | --- | --- |
| Product vision | Isolamento e acesso autorizado são princípios explícitos; o link de primeiro acesso identifica o tenant, enquanto a recuperação por e-mail permite selecionar o workspace quando houver múltiplos vínculos. | As jornadas tenant-bound e multi-tenant estão distinguidas sem criar meta quantitativa. |
| Functional definition | RBAC, lifecycle e controles sensíveis deste ciclo possuem fontes aprovadas ou implementadas. Chatbot/Omnichannel e Fiscal/DAS pertencem, respectivamente, aos ciclos do `PRD-00002` e do `PRD-00004`. | REQ-00059 v1.10 e REQ-00061 v1.5 estão aprovados e elegíveis para readiness; não resta pendência de definição funcional identificada. |
| Repository implementation | Perfil, recuperação, waivers e a fronteira `/settings/serpro` possuem evidência local; esta última passou `18/18` Vitest, `3/3` Playwright, build `54/54` e Quality Gate `18/18`. | Não comprova segurança ou experiência em rollout real nem operação SERPRO/IAM externa. |
| External operation | SMTP, IAM ambiental e acessos reais não foram validados neste PRD. | Funis e incidentes reais permanecem desconhecidos. |
| Product evidence | Métricas foram declaradas `Not applicable` neste ciclo sem observação operacional autorizada. | Não bloqueia a definição de produto enquanto o gatilho de reativação não ocorrer. |

## 12. Dependencies and product risks

`REQ-00059` v1.10, `REQ-00061` v1.5 e `ADR-0018` v3.7 estão semanticamente
reconciliados com a dispensa temporária de MFA em DEV, HML e PRD. A evidência
executada somente em DEV não reduz esse alvo: HML e PRD exigem implementação,
plano e autorização ambiental próprios. Chatbot/Omnichannel e Fiscal/DAS foram
delegados aos `PRD-00002` e `PRD-00004` e não condicionam a validação do
`PRD-00005`.

## Assumptions e Open Questions

| ID | Question / decision needed | Decision owner | Resolution / evidence | Date | State |
| --- | --- | --- | --- | --- | --- |
| `OQ-IAM-001` | Qual público e jornada definem o primeiro ciclo: convite, primeiro acesso, recuperação ou administração? | Produto | No primeiro acesso, o Tenant Admin cadastra o usuário do escritório; a plataforma envia o e-mail pelo template previamente cadastrado e pelo SMTP da plataforma; o link já identifica o tenant pela política do Keycloak; o usuário define a senha e é redirecionado ao login. Na recuperação iniciada fora desse link, o usuário informa o e-mail e seleciona o tenant quando o endereço possuir mais de um vínculo. Decisão humana materializada nesta revisão; comportamento funcional permanece em `REQ-00031`, `REQ-00058`, `UC-00016` e `UC-00028`. | 2026-09-10 | Resolved |
| `OQ-IAM-002` | Qual é a abrangência e o critério de encerramento da dispensa temporária de MFA? | Segurança e Produto | Todas as roles operam temporariamente sem MFA em DEV, HML e PRD, preservando RBAC e os demais controles. A dispensa termina quando os owners humanos de Produto e Segurança decidirem explicitamente que o amadurecimento do uso da ferramenta permite reativar o MFA; não há prazo nem ativação automática. Nas operações de `SUPER_ADMIN`, o mesmo ator pode ser maker e checker, regra aprovada explicitamente pelo owner em 2026-09-11. A decisão foi reconciliada e aprovada em `REQ-00059` v1.9, `REQ-00061` v1.4 e `ADR-0018` v3.7. | 2026-09-11 | Resolved |
| `OQ-IAM-003` | Quais tarefas e perfis compõem a validação de autonomia do Tenant Admin? | Produto e Segurança | O `ROLE_TENANT_ADMIN`, sempre limitado ao próprio tenant, deve cadastrar/convidar usuários; reenviar primeiro acesso; listar e consultar status; editar nome e perfil; inativar, reativar e remover; atribuir somente `TENANT_USER`, `TENANT_AUDIT` ou `TENANT_ADMIN`; gerir clientes e seus telefones autorizados em `/clients`; gerir credenciais SERPRO em `/settings/serpro`; e gerir certificados em `/certificates`. `SUPER_ADMIN` não pode ser atribuído por esse fluxo. Chatbot/Omnichannel e Fiscal/DAS pertencem aos `PRD-00002` e `PRD-00004`. Decisão humana desta revisão, coerente com `REQ-00003`, `REQ-00004`, `REQ-00031` e `REQ-00032`. | 2026-09-10 | Resolved |
| `OQ-IAM-004` | Como distinguir falso bloqueio, negação correta e incidente de privilégio? | Segurança | Falso bloqueio é a recusa sofrida por usuário autorizado, no tenant correto e com preconditions válidas. Negação correta é a recusa, antes de consulta ou efeito, de tentativa sem perfil, capability ou contexto de tenant válido. Incidente de privilégio é qualquer acesso a dados ou ação além do perfil/tenant permitido, inclusive elevação indevida, personificação inválida ou exposição de credencial. Não há medição de produto neste ciclo; a verificação permanece nos critérios de aceite e testes. Decisão humana desta revisão. | 2026-09-10 | Resolved |
| `OQ-IAM-005` | Quais capacidades sensíveis entram no primeiro ciclo de validação? | Produto e owners de domínio | O primeiro ciclo inclui atribuição e lifecycle de perfis tenant, vínculo de telefone autorizado a cliente, credenciais SERPRO e certificados digitais. O comportamento de domínio e seus efeitos externos continuam governados pelos respectivos requisitos e não são redefinidos neste PRD. Decisão humana desta revisão. | 2026-09-10 | Resolved |
| `OQ-IAM-006` | Qual identificador deve substituir a duplicidade `AC-017` em REQ-00004? | Segurança e Documentação | O critério já implementado do Dashboard permanece `AC-017`; o segundo critério, sobre restrições do Tenant Admin na Auditoria, passa a `AC-021`. A decisão preserva `AC-018`–`AC-020` e foi materializada no `REQ-00004` v1.18. Decisão humana desta revisão. | 2026-09-10 | Resolved |

**Decision:** conjunto consolidado de decisões `OQ-IAM-001`–`OQ-IAM-006`
aprovado pelo owner em 2026-09-11.

## Approval

| Role | Accountable party | Decision | Date | Evidence |
| --- | --- | --- | --- | --- |
| Owner | Produto de Identidade, Segurança e Operações | Validated. | 2026-09-11 | Problema, públicos, objetivos, escopo, limites, hipóteses, métricas não aplicáveis e decisões aprovados; REQ-00059 e REQ-00061 aprovados. |
| Required reviewer | Compliance | Approved. | 2026-09-11 | Mantém-se como reviewer e aceita temporariamente MFA desabilitado para todas as roles nos três ambientes, o mesmo `SUPER_ADMIN` como maker/checker e as mitigações por RBAC, isolamento, auditoria e transições explícitas. |
| Required reviewer | Owner de Billing | Approved. | 2026-09-11 | Aceita operações privilegiadas sem MFA nos três ambientes, exclusivas do `SUPER_ADMIN` por RBAC, que pode preparar e concluir a operação. |
| Required reviewer | Owner de Tenant | Approved. | 2026-09-11 | Aceita primeiro acesso tenant sem OTP nos três ambientes, gestão tenant-local pelo `TENANT_ADMIN` e personificação exclusiva do `SUPER_ADMIN`. |

## Product Definition Gate

**Product Definition Gate:** `PASS` para o PRD-00005 v1.37.

As aprovações obrigatórias foram registradas por decisão humana explícita em
2026-09-11. A validação libera progressão documental para os demais gates; não
autoriza implementação, deploy, credenciais ou rollout ambiental por si só.
