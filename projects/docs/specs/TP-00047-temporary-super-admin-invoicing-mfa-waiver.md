---
document_id: TP-00047
primary_nature: Plano
objective: Coordenar o desligamento temporário, reversível e fail-closed do MFA em todos os enforcement points atuais do Super Admin humano no ambiente DEV.
scope: Login realm-wide no saas-admin DEV como limitação conhecida, contextos elevados puros de contrato/invoice/provider-read, decisões e execuções do catálogo, mutações da configuração de payment provider, persistência, frontend, configuração, rollback, testes e documentação repository-local.
non_objectives: Não remover TOTP/required action/AMR/evidência/erros/CTA, fabricar MFA, conceder waiver Billing a outro ator ou ambiente, reduzir RBAC/tenant/purpose/TTL/SoD/ApprovalSeal/audit/idempotência/switches, reconciliar volume Keycloak, acessar dados reais, chamar provider, deployar ou produzir efeito ambiental.
owner: Produto, Segurança, Billing, Backend, Frontend e Qualidade
status: Completed — repository-local; runtime activation not executed and broad assurance blockers documented
version: 2.6
date: 2026-09-08
last_reviewed: 2026-09-09
keywords: mfa, super-admin, dev, keycloak, billing, contratos, faturamento, catálogo, payment provider, rollback
related_files: docs/analysis/ANL-00051-super-admin-dev-mfa-usage-inventory.md, docs/analysis/ANL-00053-keycloak-empty-conditional-2fa-flow.md, ../../backend/docs/adrs/ADR-0018-keycloak-realm-provisioning-automation.md, ../../backend/docs/adrs/ADR-0050-rbac-sod-aprovacoes-financeiras.md, ../../backend/docs/adrs/ADR-0055-payment-provider-operational-control-plane.md, do../../product/requirements/REQ-00054-super-admin-unified-billing-price-version.md, do../../product/requirements/REQ-00056-payment-provider-management-observability.md, do../../product/requirements/REQ-00059-temporary-all-roles-mfa-disablement.md, do../../product/use-cases/UC-00048-super-admin-billing-catalog-price-versions.md, do../../product/use-cases/UC-00049-super-admin-tenant-contract-add-ons-discounts.md, do../../product/use-cases/UC-00050-super-admin-billing-preview-invoice-close.md, do../../product/use-cases/UC-00053-manage-payment-provider-configuration.md, do../../product/use-cases/UC-00054-inspect-payment-provider-interactions.md, TP-00038-billing-contract-context-temporary-mfa-disablement.md, TP-00042-temporary-dev-super-admin-login-mfa-disablement.md
code_references: infra/keycloak/bootstrap/, backend/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/, backend/src/main/resources/application.yml, backend/src/main/resources/application-dev.yml, backend/src/main/resources/db/migration/tenant/V88_1__allow_temporary_super_admin_dev_mfa_waivers.sql, frontend/src/components/billing/, frontend/src/schemas/billingManagementSchemas.ts, frontend/src/i18n/messages/pt-BR/billing.json, frontend/e2e/billing/super-admin-invoicing-waiver.spec.ts, docker-compose.yml, docker-compose.override.yml, .env.example, infra/deploy/production.env.example
principal_statement: Em DEV, flags explícitas podem suspender temporariamente o desafio e as verificações MFA do Super Admin humano, mas todo mecanismo permanece no código e toda decisão waived é distinguível, limitada e recusada imediatamente após rollback.
---

# TP-00047 — Desligamento temporário do MFA do Super Admin em DEV

## 1. Contexto e resultado do mapeamento

O relato inicial mostrou `BILLING_MFA_REQUIRED` em
`/admin/billing/tenants` ao selecionar **Faturamento**. A varredura completa
ANL-00051 confirmou que o MFA não está concentrado nesse cartão e classificou
quatro grupos executáveis:

1. login inicial no realm DEV `saas-admin`, governado pelo reconciliador Keycloak;
2. emissão/uso de contextos elevados para famílias puras de contrato, invoice e
   leitura de interações de provider;
3. seis operações do catálogo: `approve`, `reject`, `publishPrice`,
   `retirePrice`, `publishOffer` e `retireOffer`;
4. seis mutações do control plane de provider: `createRevision`, `replaceDraft`,
   `submit`, `approve`, `reject` e `activate`.

O solicitante resolveu explicitamente o alcance em 2026-09-09: todos esses pontos
devem ficar temporariamente sem MFA somente para Super Admin humano em DEV, sem
remoção dos mecanismos. Após selecionar Faturamento, o destino permanece
`/billing/invoices`, seguido pela leitura de `invoice-documents`.

A ANL-00053 fechou também a causa do login ainda falhar após senha válida: a
implementação anterior deixava o pai 2FA `CONDITIONAL` com a folha OTP
`DISABLED`. O estado OFF canônico agora desabilita o pai, mantém a folha
`ALTERNATIVE` e desabilita apenas `CONFIGURE_TOTP`; o estado ON restaura o pai
por último.

## 2. User Story View

> Como Super Admin humano no ambiente DEV, quero autenticar e validar contratos,
> faturamento, catálogo e configuração de providers sem step-up MFA
> temporariamente, para testar os fluxos locais enquanto a proteção continua
> presente e pode ser reativada por configuração.

**Acceptance Criteria:** `AC-59-001` a `AC-59-010`.

## 3. Implementation Readiness Gate

### 3.1 Gate Audit

| Control | Required state | Exact evidence | Result |
| --- | --- | --- | --- |
| Analysis | Inventário e diagnóstico atuais | ANL-00051 v1.0, quatro grupos; ANL-00053 v1.2, causa `KC-DEV-AUTH-001` e estado OFF/ON canônico | PASS |
| ADRs | Decisões compatíveis e Accepted | ADR-0018 v3.4; ADR-0050 v1.6/D-13.2 `HUMAN_EXPLICIT`; ADR-0055 v1.7 | PASS |
| Requirements | Approved para o comportamento exato | REQ-00054 v1.16; REQ-00056 v1.10; REQ-00059 v1.4 | PASS |
| Use Cases | Approved e ligados a fluxos/testes | UC-00048 v1.8; UC-00049 v1.10; UC-00050 v1.5; UC-00053 v1.9; UC-00054 v1.7 | PASS |
| Assumptions | Nenhuma `Proposed` | ASM-47-001/002 validadas por ANL-00051 e ANL-00053, além do código atual | PASS |
| Open Questions | Nenhuma `Open` | OQ-47-001–008 resolvidas pelo solicitante, Produto e guardrails ambientais | PASS |
| Dependencies | Paths e capacidades disponíveis | Código AS-IS mapeado; V88.1 livre; V89/V90 preservadas para IP-BE-8.1.6-conversation-audit-retention-policy-administration-api; TP-00042 v1.6/F01 repository-local completo; IP-BE-47.2.1-temporary-super-admin-dev-mfa-disablement v1.8; IP-FE-47.3.1-temporary-super-admin-dev-mfa-disablement v1.6; testes herméticos disponíveis | PASS |
| Definition of Done | Binária e verificável | Seções 4, 5 e 8 | PASS |

### 3.2 Acceptance Criteria → fluxo → teste

| Criterion | Executable flow | Planned evidence |
| --- | --- | --- |
| AC-59-001/002 | Login `saas-admin` com toggle false/true | OFF: pai `DISABLED`, OTP `ALTERNATIVE`, provider false; ON: provider true, OTP `ALTERNATIVE`, pai `CONDITIONAL`; reparo do legado e nenhum mecanismo removido |
| AC-59-003 | POST/uso de contexto para cada família pura | Unitários, MVC e PostgreSQL; mistos/vazios/desconhecidos recusados |
| AC-59-004 | Seis operações de catálogo | Domínio/use case/adapter/PostgreSQL; authority, SoD e seal preservados |
| AC-59-005 | Seis mutações de provider | Use case/HTTP/store/PostgreSQL; mutation e deployment switches independentes |
| AC-59-006/007 | Persistência e rollback | `mfa_required=false` + evidência nula; contexto/approval não consumido falha após reativação; receipt/journal terminal anterior é replayado sem nova policy ou mutação |
| AC-59-008/009 | Launcher → contexto → `/billing/invoices` → `invoice-documents` | Zod/service/component/boundary/InvoiceTable e E2E autorizado |
| AC-59-010 | Startup/configuração por profile | Base/HML/PRD true; configuração false fora de DEV falha antes de requests |

### 3.3 Prohibited

- remover ou renomear provider TOTP, `CONFIGURE_TOTP`, execução OTP, credential,
  mapper AMR, `BillingMfaEvidence`, erros ou CTA de reautenticação;
- aceitar senha como MFA, inventar `amr=otp` ou criar evidência sintética para um
  waiver;
- aplicar waiver server-side Billing a Tenant Admin, Commercial, service account,
  ator sem `ROLE_SUPER_ADMIN`, HML, PRD, família mista, wildcard ou authority
  desconhecida; o toggle de login continua realm-wide no `saas-admin` DEV como
  efeito conhecido e testado;
- enfraquecer RBAC, identidade humana, tenant/purpose, TTL, revogação,
  maker-checker, `ApprovalSeal`, idempotência, audit, readiness, mutation switch
  ou kill switch;
- editar migrations históricas V77, V78, V81, V82 ou V83;
- executar reconciliação contra volume Keycloak, `compose up`, deploy, provider
  externo, dado real ou credencial nesta autorização repository-local.

### 3.4 Mandatory

- usar policy de waiver afirmativa, enum de scopes fechado e decisão
  `REQUIRED`/`TEMPORARILY_WAIVED`, mantendo fail-closed como default;
- `BILLING_SECURITY_SUPER_ADMIN_MFA_ENABLED=true` no base/HML/PRD e `false`
  somente no DEV; restaurar
  `BILLING_SECURITY_ADMIN_CONTRACT_CONTEXT_MFA_ENABLED=true` no default seguro;
- falhar startup quando qualquer dispensa for configurada fora de profile DEV;
- no login OFF, desabilitar o pai 2FA, preservar `auth-otp-form=ALTERNATIVE` e
  reparar o legado `CONDITIONAL/DISABLED/false` em ordem fail-closed;
- persistir `mfa_required` e evidência opcional coerente, sem apagar histórico;
- reavaliar policy no uso/consumo para invalidar waiver vivo após rollback;
- manter o tratamento frontend de `BILLING_MFA_REQUIRED`;
- executar `quality-gate` nos escopos impactados e
  `./infra/scripts/validate-docs.sh`.

### 3.5 Result

| Field | Value |
| --- | --- |
| **Readiness Result** | `READY` |
| **Auditor** | `@AgentOrchestrator using implementation-readiness` |
| **Date** | `2026-09-09` |
| **Source Versions** | `TP-00042 v1.6; ANL-00051 v1.0; ANL-00053 v1.2; ADR-0018 v3.4; ADR-0050 v1.6; ADR-0055 v1.7; REQ-00054 v1.16; REQ-00056 v1.10; REQ-00059 v1.4; UC-00048 v1.8; UC-00049 v1.10; UC-00050 v1.5; UC-00053 v1.9; UC-00054 v1.7; IP-BE-47.2.1-temporary-super-admin-dev-mfa-disablement v1.8; IP-FE-47.3.1-temporary-super-admin-dev-mfa-disablement v1.6` |
| **Scope Authorized** | `47.2–47.5 repository-local nos paths exatos das Seções 5 e 6, inclusive migration V88_1; nenhuma reconciliação stateful, chamada externa, deploy ou efeito ambiental` |
| **Blockers / Decision Owner** | `N/A` |

Qualquer mudança posterior de fonte, versão, path, assumption ou decisão invalida
este resultado e exige nova aplicação do gate.

## 4. Decisões e perguntas encerradas

### 4.1 Assumptions

| ID | Assumption | Status | Owner | Evidence | Affected ACs |
| --- | --- | --- | --- | --- | --- |
| ASM-47-001 | Os quatro grupos de ANL-00051 cobrem todo uso executável atual de MFA para Super Admin. | Validated | Arquitetura/Segurança | Busca de código/configuração e matriz ANL-00051, 2026-09-09 | AC-59-001 |
| ASM-47-002 | A falha do login após senha válida vem do pai 2FA `CONDITIONAL` com OTP `DISABLED`, não da credencial ou do browser. | Validated | Segurança/Infraestrutura | ANL-00053 v1.2 e contrato do Keycloak 26.6.3, 2026-09-09 | AC-59-002 |

### 4.2 Open Questions

| ID | Question | Status | Decision Owner | Decision / Evidence | Affected ACs |
| --- | --- | --- | --- | --- | --- |
| OQ-47-001 | A dispensa alcança somente entrada ou também funções protegidas? | Resolved | Proprietário do SaaS | Todos os enforcement points atuais do Super Admin em DEV; pedido e REQ-00059 v1.4, 2026-09-09. | AC-59-003–007 |
| OQ-47-002 | Qual destino após selecionar Faturamento? | Resolved | Produto | `/billing/invoices`, seguido de `invoice-documents`; pedido humano, UC-00049 e UC-00050, 2026-09-09. | AC-59-008 |
| OQ-47-003 | A implementação pode alterar o volume Keycloak atual? | Resolved | Engenharia/Operações | Não; somente script/config/testes repository-local, conforme ADR-0018 e REQ-00059, 2026-09-09. | AC-59-002 |
| OQ-47-004 | Como tratar Commercial no login? | Resolved | Produto/Segurança | O toggle é realm-wide no `saas-admin` DEV, inclusive Commercial; o waiver Billing permanece Super Admin-only, conforme ADR-0018 v3.4 e REQ-00059 v1.4, 2026-09-09. | AC-59-002/003/005 |
| OQ-47-005 | Qual precedência e rollback dos toggles Billing? | Resolved | Produto/Segurança/Billing | Global false prevalece; global true + legado false mantém só contrato; rollback completo exige ambas true, conforme REQ-00059 §8.1, 2026-09-09. | AC-59-003/007/010 |
| OQ-47-006 | Como dar ao E2E as authorities Billing sem ampliar a persona Super Admin global? | Resolved | Frontend/Qualidade | Criar `super-admin-billing` somente no catálogo mock DEV e manter `super-admin` inalterada; inspeção do AuthProvider e `frontend/src/mocks/data/user.ts`, 2026-09-09. | AC-59-008/009 |
| OQ-47-007 | Um conjunto misto de authorities financeiras conhecidas é inválido ou MFA-bound? | Resolved | Produto/Segurança/Billing | É request inválido e não emite contexto, assim como vazio, wildcard e desconhecido, conforme REQ-00059 v1.4, REQ-00054 v1.16 e UC-00049 v1.10, 2026-09-09. | AC-59-003 |
| OQ-47-008 | O rollback deve quebrar replay terminal já concluído? | Resolved | Produto/Segurança/Billing | Não; replay terminal continua idempotente e sem novo efeito, enquanto qualquer contexto/approval waived vivo e consumo/ativação pendente revalida a policy, conforme REQ-00059 v1.4 e UC-00053 v1.9, 2026-09-09. | AC-59-007 |

### 4.3 Truth table e rollback

| Profile | Global MFA | Legacy contract MFA | Result |
| --- | ---: | ---: | --- |
| DEV | false | false ou true | Todos os scopes fechados do Super Admin recebem waiver. |
| DEV | true | false | Somente contexto contratual recebe waiver legado. |
| DEV | true | true | MFA em todos os scopes; rollback completo. |
| Fora de DEV ou profile misto | qualquer false | qualquer | Startup falha. |
| Fora de DEV | true | true | MFA em todos os scopes. |

### 4.4 Login Keycloak e rollback

| Effective environment | Login toggle | Pai 2FA | OTP | `CONFIGURE_TOTP` |
| --- | ---: | --- | --- | ---: |
| DEV | false | `DISABLED` | `ALTERNATIVE` | false |
| DEV/HML/PRD | true | `CONDITIONAL` | `ALTERNATIVE` | true |
| Fora de DEV | false | Recusado antes de mutação | Recusado | Recusado |

## 5. Tracking e contratos atômicos

| ID | Atomic activity | Status | Dependency |
| --- | --- | --- | --- |
| 47.1 | Inventariar e materializar ADRs, requisitos e UCs | Done | Decisão humana |
| 47.2 | Implementar policy, decisões, domínio, stores, migration, configuração e testes backend/Keycloak | Done | READY deste plano e IP-BE-47.2.1-temporary-super-admin-dev-mfa-disablement v1.8 |
| 47.3 | Ajustar schema/copy e provar o fluxo frontend | Done | READY deste plano e IP-FE-47.3.1-temporary-super-admin-dev-mfa-disablement v1.6 |
| 47.4 | Executar testes focados e suites impactadas | Done | 47.2–47.3 |
| 47.5 | Varredura final, quality gates e governança documental | Done — blockers de baseline registrados | 47.4 |

### 5.1 Task 47.1 — documentação e decisão

| Field | Required content |
| --- | --- |
| What | Inventariar todo uso MFA e reconciliar ADRs, requisitos, UCs, plano e índices. |
| Where | `docs/analysis/ANL-00051-super-admin-dev-mfa-usage-inventory.md`; ADR-0018, ADR-0050, ADR-0055; REQ-00054, REQ-00056, REQ-00059; UC-00048, UC-00049, UC-00050, UC-00053, UC-00054; este TP e READMEs imediatos. |
| Depends on | Solicitação humana de 2026-09-09. |
| Reuses | ADR-0000 e Implementation Readiness Standard. |
| Requirements | AC-59-001 e decisão `HUMAN_EXPLICIT`. |
| Acceptance Tests | `./infra/scripts/validate-docs.sh` retorna 0 e a varredura classifica quatro grupos. |
| Prohibited | Omitir enforcement point, esconder incerteza ou declarar efeito ambiental. |
| Mandatory | Versões/indexes coerentes, assumptions `Validated` e OQs `Resolved`. |
| Definition of Done | Fontes da Seção 3 existem, estão indexadas e não se contradizem. |
| Gate Audit | Done; sujeita à validação final 47.5. |

### 5.2 Task 47.2 — backend, dados e configuração

| Field | Required content |
| --- | --- |
| What | Introduzir uma decisão MFA explícita e um waiver Super Admin DEV fechado para contextos, catálogo e provider, além de manter/reconciliar o toggle de login por testes. |
| Where | Lista fechada em `../../backend/docs/specs/IP-BE-47.2.1-temporary-super-admin-dev-mfa-disablement.md` §3–4, incluindo a migration exata `backend/src/main/resources/db/migration/tenant/V88_1__allow_temporary_super_admin_dev_mfa_waivers.sql`. |
| Depends on | Fontes congeladas na Seção 3; IP-BE-47.2.1-temporary-super-admin-dev-mfa-disablement v1.8. |
| Reuses | Adapters JWT MFA, `BillingElevatedContext`, approvals/seals de catálogo/provider e reconciliador Keycloak atuais. |
| Requirements | REQ-00059 AC-002–007/010; ADR-0018, ADR-0050 e ADR-0055; UC-00048, UC-00049, UC-00050, UC-00053 e UC-00054. |
| Acceptance Tests | Classes e scripts exatos da Section 6 do IP-BE-47.2.1-temporary-super-admin-dev-mfa-disablement retornam 0 e provam required/waived/rollback. |
| Prohibited | Todos os itens da Seção 3.3 e do IP backend §2.3. |
| Mandatory | Todos os itens da Seção 3.4, truth table §4.3 e IP backend §2.4. |
| Definition of Done | Todos os checkboxes do IP backend §7 têm evidência binária. |
| Gate Audit | READY na Seção 3; sem efeito ambiental. |

### 5.3 Task 47.3 — frontend e jornada de faturamento

| Field | Required content |
| --- | --- |
| What | Aceitar somente respostas waived de famílias puras, atualizar a copy e conservar toda recuperação MFA, provando a navegação e a primeira leitura financeira. |
| Where | Lista fechada em `../../frontend/docs/specs/IP-FE-47.3.1-temporary-super-admin-dev-mfa-disablement.md` §3–4: schema, copy, persona mock dedicada, quatro testes Vitest e spec E2E hermético dedicado. |
| Depends on | Contrato backend de contexto inalterado e IP-FE-47.3.1-temporary-super-admin-dev-mfa-disablement v1.6. |
| Reuses | Launcher, stores em memória, impersonação, boundary e query de `invoice-documents`. |
| Requirements | REQ-00059 AC-003/008/009; UC-00049 e UC-00050. |
| Acceptance Tests | Comando Vitest focal e Playwright hermético do IP frontend §5 retornam 0; backend-real só conta se realmente executado. |
| Prohibited | Remover CTA/erro MFA, aceitar família mista, usar mock como fallback runtime ou fabricar PASS ambiental. |
| Mandatory | Três famílias puras, false/null, rota `/billing/invoices`, headers de `invoice-documents` e rollback preservado. |
| Definition of Done | Todos os checkboxes do IP frontend §7 têm evidência binária. |
| Gate Audit | READY na Seção 3; E2E ambiental não pode ser inventado. |

### 5.4 Task 47.4 — execução de testes e suites impactadas

| Field | Required content |
| --- | --- |
| What | Executar a matriz positiva, negativa, persistência e rollback de backend, frontend e Keycloak. |
| Where | Classes Maven do IP backend §6 e arquivos Vitest/Playwright do IP frontend §5; `infra/scripts/tests/keycloak-runtime-json-validator-test.sh`; `infra/scripts/tests/keycloak-admin-login-mfa-toggle-test.sh`; `infra/scripts/tests/keycloak-billing-mfa-amr-test.sh`; `infra/scripts/tests/keycloak-bootstrap-hardening-test.sh`. |
| Depends on | 47.2 e 47.3 implementadas. |
| Reuses | Backend/Frontend Testing Standards e scripts existentes. |
| Requirements | Todos os AC-59-001–010. |
| Acceptance Tests | Cada comando retorna 0; zero skip obrigatório; Testcontainers/backend-real indisponível é registrado como limitação, não PASS. |
| Prohibited | Omitir falha, usar `-DskipTests`, reduzir suíte para obter verde ou iniciar stack stateful. |
| Mandatory | Registrar comando, exit code, contagem e falha/skip por gate. |
| Definition of Done | Suites focadas e impactadas têm resultado reproduzível. |
| Gate Audit | READY após 47.2/47.3; nenhuma autoridade ambiental adicional. |

### 5.5 Task 47.5 — varredura final, quality gates e handoff

| Field | Required content |
| --- | --- |
| What | Confirmar ausência de enforcement não classificado, executar gates C.L.E.A.R./docs e reconciliar status/evidências. |
| Where | Código/configuração inventariados por ANL-00051; `./infra/scripts/validate-quality-gates.sh`; `./infra/scripts/validate-docs.sh`; ANL-00051; REQ-00059; TP-00047 e READMEs imediatos. |
| Depends on | 47.4 concluída. |
| Reuses | Quality Gate Standard, governança ADR-0000 e busca `rg`. |
| Requirements | AC-59-001 e AC-59-010; DoD §8. |
| Acceptance Tests | Busca final não acha ocorrência executável sem classificação; gates selecionados e docs retornam 0 ou registram blocker real. |
| Prohibited | Declarar 100%, executar Git/deploy/volume, apagar mecanismo MFA ou esconder baseline não relacionado. |
| Mandatory | Atualizar tracking/DoD somente com evidência e informar toda limitação ambiental. |
| Definition of Done | DoD §8 reconciliada e handoff lista arquivos, comandos, resultados, skips e pendências. |
| Gate Audit | READY condicionado às evidências de 47.4. |

## 6. Mudanças implementadas

### 6.1 Backend e domínio

- criar `BillingMfaWaiverScope`, `BillingMfaDecision` e uma policy afirmativa que
  só permite waiver a Super Admin humano no profile DEV;
- adaptar emissão/uso de contexto para três famílias exatas e impedir conjuntos
  mistos;
- substituir as verificações diretas nas seis operações do catálogo e nas seis
  mutações provider pela decisão explícita;
- persistir a decisão nos approvals e reavaliá-la antes de consumir seals;
- devolver receipt/journal terminal anterior antes da policy, sem nova mutação,
  e reavaliar a policy em consumo/activation ainda pendente;
- preservar adapters de extração/validação de evidência real.

### 6.2 Dados

A migration aditiva
`V88_1__allow_temporary_super_admin_dev_mfa_waivers.sql` deve:

- ampliar a constraint de contextos apenas às três famílias puras;
- adicionar `checker_mfa_required` ao catálogo e permitir evidência nula somente
  quando false;
- adicionar `mfa_required` a approvals provider, tornar evidência nullable somente
  para waiver e manter sua tupla imutável no trigger.

`V88_1` é deliberada: V89/V90 já estão congeladas como fases futuras de outro
plano aprovado; a subversão 88.1 está livre, segue precedente Flyway do repositório
e ordena depois de V88 sem ocupar essas versões.

### 6.3 Configuração e login

- base, HML e PRD permanecem MFA-on;
- DEV define os toggles temporários como false;
- Compose/examples refletem defaults seguros;
- o reconciliador mantém provider, required action, execução, credencial e AMR
  mapper; em OFF desabilita o pai 2FA e preserva OTP `ALTERNATIVE`, e em ON
  restaura o pai `CONDITIONAL` somente após provider/folha válidos;
- não há execução contra o volume persistido neste plano.

### 6.4 Frontend

- Zod aceita `mfaRequired=false` somente para contrato puro, invoice puro ou
  provider-read puro;
- conjuntos mistos continuam erro de contrato;
- copy deixa de afirmar que Faturamento é invariavelmente MFA-bound;
- CTA e tratamento de `BILLING_MFA_REQUIRED` permanecem para rollback;
- o happy path continua contexto em memória, impersonação e
  `/billing/invoices` → `invoice-documents`.

## 7. Estratégia de testes e quality gate

### 7.1 Backend

- unitários de decisão/policy/defaults/profile e matrizes required/waived;
- domínio/use cases dos contextos, seis operações de catálogo e seis mutações
  provider;
- controller/HTTP/security para confirmar que errors e authorities permanecem;
- PostgreSQL para fresh/upgrade, constraints e trigger V88.1;
- scripts Keycloak herméticos para toggle false/true e preservação estrutural.

### 7.2 Frontend

- Vitest do schema/service para as três famílias puras e rejeição mista;
- launcher sem CTA no sucesso e com CTA no 403;
- boundary e InvoiceTable para headers, tenant, loading/error/empty/data;
- Playwright hermético dedicado com persona mock Billing; backend-real continua
  opcional e só conta se realmente executado em ambiente autorizado.

### 7.3 Gates

- gate focal por stack;
- suite impactada backend/frontend;
- validators de configuração/Keycloak;
- `./infra/scripts/validate-docs.sh`;
- `./infra/scripts/validate-quality-gates.sh` nos escopos aplicáveis, sem falso
  verde para skip obrigatório.

### 7.4 Evidência de execução

| Área | Resultado repository-local em 2026-09-09 |
| --- | --- |
| Backend focal | `83/83 PASS`, zero failure/error/skip. |
| PostgreSQL/Flyway | `9/9 PASS` em PostgreSQL 16.14; fresh e upgrade V88→V88.1, constraints e triggers cobertos. |
| Arquitetura backend | `29/29 PASS`, zero failure/error/skip. |
| Keycloak/infra | Toggle login `PASS` em 39 invocações, inclusive rollback legado e falha parcial; validator JSON `46 cenários PASS`; Billing AMR, contratos do realm, hardening e validator de deploy `PASS`; gates `infra/focused` e `infra/pr` `PASS`. |
| Frontend focal | Vitest `33/33 PASS`; teste relacionado do provider `4/4 PASS`; typecheck, ESLint e Prettier dos arquivos tocados `PASS`. |
| Jornada Faturamento | Playwright hermético `9/9 PASS` em Chromium, viewport 320 e viewport 768; prova seleção → POST contexto → `/billing/invoices` → GET `invoice-documents`, headers e ausência de CTA no waiver. |
| Quality gate backend PR | `BLOCKED`, `failures=0`, `blocked=2`: baseline do POM não declara `jacoco-maven-plugin` nem o goal `check`. |
| Quality gate frontend PR | Execução ampla encerrada com exit `143` após timeouts de 5 s em suites não relacionadas; o build também é bloqueado com segurança pela existência de `.env.local`, cujo conteúdo não foi lido. Lint global terminou com zero erros e 52 warnings. |
| Formatação frontend global | Exit `2` por dívida ampla preexistente e por `frontend/use-permission-result.json` em codificação incompatível; todos os oito arquivos desta mudança passam no check focal. |
| Governança documental | `./infra/scripts/validate-docs.sh`: exit `0`; 24/24 testes, 762 Markdown, 744 artefatos indexados e estrutura documental válida. |
| Limites ambientais | Nenhuma reconciliação do realm persistido, restart/`compose up`, deploy, provider externo, dado real ou produção foi executado. |

Os bloqueios amplos não foram convertidos em verde. Eles não invalidam as provas
focais da mudança, mas impedem alegar assurance PR integral e deixam a ativação
do login no runtime local como follow-up operacional autorizado separadamente.

## 8. Definition of Done

- [x] Todos os quatro grupos de ANL-00051 têm implementação temporária explícita
  ou evidência de que já estavam cobertos, sem ocorrência executável não
  classificada.
- [x] MFA permanece default-on e configuração false fora de DEV falha startup.
- [x] Super Admin humano DEV percorre as três famílias de contexto, seis operações
  de catálogo e seis mutações provider sem prova MFA quando autorizado.
- [x] Tenant Admin, outro ator, HML/PRD, família mista e authority desconhecida
  continuam fail-closed.
- [x] Contextos e approvals waived persistem boolean false + evidência nula; nenhum
  `otp` ou referência sintética existe.
- [x] Reativação invalida todo contexto/approval waived ainda utilizável antes do
  próximo consumo.
- [x] Após reativação, replay terminal devolve o receipt/journal original sem
  nova policy/mutação, enquanto consumo ou activation pendente falha fechado.
- [x] Faturamento navega a `/billing/invoices` e consulta `invoice-documents` com
  tenant/context/purpose corretos.
- [x] Testes focados, suites impactadas, quality gates e documentação têm
  resultados reproduzíveis registrados.
- [x] Nenhum mecanismo MFA foi removido; reconciliação stateful, deploy, provider
  externo e produção não foram executados.

## 9. Traceability

| Source | Covered work |
| --- | --- |
| ANL-00051 | Inventário AS-IS e varredura final |
| ANL-00053 | Causa KC-DEV-AUTH-001, estado canônico e regressão de rollback/falha parcial |
| ADR-0018 | Login Keycloak temporário e reversível |
| ADR-0050/D-13.2 | Decisão Billing global DEV, SoD e rollback |
| ADR-0055 | Control plane provider e switches preservados |
| REQ-00054, UC-00048, UC-00049 e UC-00050 | Contextos, catálogo, contratos, invoice e fluxo pós-seleção |
| REQ-00056, UC-00053 e UC-00054 | Configuração provider e leitura elevada |
| REQ-00059 | ACs focais AC-59-001–010 |
| TP-00038 e TP-00042 | Precedentes contratuais e login; este plano os sucede no alcance atual |

## 10. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 2.6 | 2026-09-09 | Codex | Conclui o escopo repository-local, incorpora a causa KC-DEV-AUTH-001 e o estado 2FA canônico, e registra provas verdes e blockers reais sem alegar ativação no realm persistido. |
| 2.5 | 2026-09-09 | Codex | Preserva família mista como request inválido, fecha replay terminal após rollback e inclui o port de receipt do catálogo nos IPs versionados. |
| 2.4 | 2026-09-09 | Codex | Inclui OQ-47-006 e congela a persona mock Billing dedicada no IP-FE v1.3, mantendo a persona Super Admin global intacta. |
| 2.3 | 2026-09-09 | Codex | Congela OQ-47-001–005 e as dependências versionadas IP-BE v1.3/IP-FE v1.2 no resultado READY. |
| 2.2 | 2026-09-09 | Codex | Corrige o contrato de validação para apontar ao teste repository-local canônico `keycloak-billing-mfa-amr-test.sh` e às seções de comandos exatas dos IPs backend/frontend. |
| 2.1 | 2026-09-09 | Produto, Segurança, Billing / Codex | Fecha efeito realm-wide do login, truth table/rollback, OQs com owner/data, contratos de dez campos, paths e IPs backend/frontend. |
| 2.0 | 2026-09-09 | Solicitante humano / Codex | Substitui o blocker anterior pela decisão completa: todos os enforcement points do Super Admin DEV, fontes reconciliadas, IRG READY, migration V88.1, implementação atômica, rollback e fluxo de faturamento verificável. |
| 1.0 | 2026-09-08 | Solicitante humano / Codex | Registrou o bloqueio inicial do cartão Faturamento e as perguntas então abertas. |
