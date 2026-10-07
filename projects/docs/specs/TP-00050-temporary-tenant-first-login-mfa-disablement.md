---
document_id: TP-00050
primary_nature: Plano
objective: Coordenar o desligamento temporario e reversivel do enrollment MFA nos realms de tenant em DEV, HML e production.
scope: Evidencia DEV historica e extensao repository-local do reconciliador/teste para o contrato multiambiente aprovado.
non_objectives: Nao remover mecanismos MFA, alterar Billing ou saas-admin, executar deploy, acessar ou reconciliar HML/production, nem modificar realms fora da allowlist.
owner: Seguranca, IAM, Infraestrutura e Qualidade
status: Completed — repository-local; no environment mutation
version: 1.4
date: 2026-09-09
last_reviewed: 2026-09-12
keywords: MFA, tenant, primeiro acesso, Keycloak, DEV, HML, production, rollback
related_files: ../../docs/prds/PRD-00005-identity-access-governance.md, do../../product/requirements/REQ-00061-temporary-tenant-first-login-mfa-disablement.md, docs/analysis/ANL-00054-tenant-first-login-mfa-inventory.md, ../../backend/docs/adrs/ADR-0018-keycloak-realm-provisioning-automation.md, do../../product/use-cases/UC-00016-cadastro-convite-usuarios-escritorio.md, ../../backend/docs/specs/IP-BE-50.1.1-tenant-first-login-mfa-toggle.md, ../../backend/docs/specs/IP-BE-50.1.2-tenant-first-login-mfa-multi-environment-contract.md
code_references: "infra/keycloak/bootstrap/reconcile-tenant-first-login-mfa.sh, infra/scripts/tests/keycloak-tenant-first-login-mfa-toggle-test.sh"
principal_statement: O plano preserva a execucao DEV concluida e coordena uma unidade repository-local atomica para aceitar e provar OFF/ON em DEV, HML e production sem acessar ambientes.
---

# TP-00050 — Desligamento temporario do MFA no primeiro acesso de tenant

## 1. Context and User Story

ANL-00054 demonstrou que o primeiro acesso de identidades tenant recebe a action
no proprio usuario e que o runtime DEV ja foi reconciliado sem remove-la.
REQ-00061 v1.6 e ADR-0018 v3.7 aprovam o mesmo estado reversivel em DEV, HML e
production. `TP-00050-T05`, decomposta em
`IP-BE-50.1.2-tenant-first-login-mfa-multi-environment-contract`, fechou o gap
repository-local: a flag stateful passou a ser explicita, o guard DEV-only foi
removido e a matriz hermetica 3x2 ficou verde sem tocar em realm real.

> Como usuario de tenant em primeiro acesso, quero autenticar sem enrollment TOTP
> temporariamente nos ambientes autorizados, para usar o workspace enquanto a
> capacidade de rollback permanece preservada.

## 2. Implementation Readiness Gate

### 2.1 Gate Audit

| Control | Exact evidence | Result |
| --- | --- | --- |
| Product Definition | PRD-00005 v1.36 `Validated` | PASS |
| Requirement | REQ-00061 v1.6 `Approved`, default gerenciado separado da flag stateful explicita | PASS |
| ADR | ADR-0018 v3.7 `Accepted` | PASS |
| Use Case | UC-00016 v1.7 `Approved`, User Story View, fluxo 11a e AC mapping | PASS |
| Analysis | ANL-00054 v1.3, alvo repository-local separado da evidencia DEV | PASS |
| Assumptions | ASM-61-001 `Validated` | PASS |
| Open Questions | OQ-61-001/002/003 `Resolved` | PASS |
| Dependencies | Reconciliador e teste hermetico existentes; enum ambiental ja aceita `dev`, `hml` e `production` | PASS |
| API Contract | N/A — nao cria, altera ou consome API HTTP do backend do produto | N/A |
| Granularity / Decomposition | T01-T04 preservam o ciclo DEV concluido; T05 possui um resultado e um handoff em IP-BE-50.1.2-tenant-first-login-mfa-multi-environment-contract | PASS |
| Tests/DoD | Matriz 3x2, comandos e checklist binarios abaixo | PASS |

### 2.2 Acceptance Tests

| Criterion | Planned evidence | Expected result |
| --- | --- | --- |
| AC-61-002/004/005/007 | `bash infra/scripts/tests/keycloak-tenant-first-login-mfa-toggle-test.sh` | Seis ramos `dev|hml|production` x `false|true` PASS, sem rede ou realm real |
| AC-61-003/007 | mesmo teste focal, cenarios de boundary/idempotencia/preflight | `saas-admin`/fora da allowlist e recursos proibidos intocados; falha antes de mutacao |
| AC-61-006 | evidencia preservada de `KeycloakAdminAdapterProvisioningTest` | required actions continuam presentes; codigo Java nao e target de T05 |
| AC-61-008 | contrato repository-local + evidencia historica DEV da Section 4.1 | nenhuma declaracao de execucao HML/production; sessao velha nunca comprova OFF |
| Documentacao | `./infra/scripts/validate-docs.sh` | exit 0 |

### 2.3 Prohibited

- remover provider/action, usuario, role, credencial ou browser flow;
- alterar `saas-admin`, Billing MFA ou realm nao allowlisted;
- ler segredo, acessar ou reconciliar HML/production ou executar deploy;
- ampliar o escopo alem dos dois paths executaveis de
  `IP-BE-50.1.2-tenant-first-login-mfa-multi-environment-contract`.

### 2.4 Mandatory

- preservar payload completo do provider e alterar somente `enabled`;
- usar allowlist exata, limites bounded, pos-verificacao e idempotencia;
- manter `KeycloakAdminAdapter` atribuindo `CONFIGURE_TOTP`;
- provar a matriz 3x2 sem rede, container ou credencial;
- executar quality gate focal de infra com os dois targets e validar documentacao.

### 2.5 Result

| Field | Value |
| --- | --- |
| **Readiness Result** | `READY` |
| **Auditor** | `@AgentOrchestrator using implementation-readiness` |
| **Date** | `2026-09-12` |
| **Source Versions** | `PRD-00005 v1.36; REQ-00061 v1.6; ADR-0018 v3.7; UC-00016 v1.7; ANL-00054 v1.3; TP-00050 v1.3; IP-BE-50.1.2-tenant-first-login-mfa-multi-environment-contract v1.0` |
| **Scope Authorized** | `TP-00050-T05`; somente `infra/keycloak/bootstrap/reconcile-tenant-first-login-mfa.sh` e `infra/scripts/tests/keycloak-tenant-first-login-mfa-toggle-test.sh` |
| **Decomposition** | `TP-00050-T05 -> IP-BE-50.1.2-tenant-first-login-mfa-multi-environment-contract`; uma entrega repository-local, um handoff para Quality Gate |
| **Blockers / Decision Owner** | `N/A` |

## 3. Execution Tracking

| Task | Activity | Status |
| --- | --- | --- |
| TP-00050-T01 | Implementar toggle, reconciliador, wiring, guards e testes | Done |
| TP-00050-T02 | Executar gates e registrar evidencia | Done |
| TP-00050-T03 | Reconciliar provider no DEV local; login humano fica para confirmacao do solicitante | Done |
| TP-00050-T04 | Invalidar a authentication session criada antes do estado OFF e reverificar saude/provider | Done |
| TP-00050-T05 | Estender o contrato repository-local e o teste para OFF/ON em DEV, HML e production conforme IP-BE-50.1.2-tenant-first-login-mfa-multi-environment-contract | Done — 6/6 e Quality Gates PASS |

## 4. Historical Atomic Task Contract — TP-00050-T01

| Field | Content |
| --- | --- |
| **What** | Alternar de modo reversivel o provider `CONFIGURE_TOTP` nos realms tenant DEV allowlisted e invalidar sessão efêmera iniciada antes do OFF. |
| **Where** | `infra/keycloak/bootstrap/reconcile-tenant-first-login-mfa.sh`, `ensure-management-service-account.sh`, Compose/examples/deploy validator, testes shell, documentos indexados e container Keycloak DEV local. |
| **Depends on** | REQ-00061 v1.2, ADR-0018 v3.6, UC-00016 v1.5, ANL-00054 v1.2. |
| **Reuses** | Sessao `kcadm`, allowlist, validator estrutural e padrao verify/reconcile do toggle administrativo. |
| **Requirements** | AC-61-001–007; ADR-0018; standards de seguranca, shell e quality gate. |
| **Gate Audit** | `READY` historico registrado em TP-00050 v1.2; nao constitui o gate corrente de T05. |

**Definition of Done:**

- [x] toggle seguro esta presente e `false` e aceito somente em DEV;
- [x] reconciliador passa testes OFF/ON/boundary/idempotencia;
- [x] teste Java confirma que `CONFIGURE_TOTP` continua atribuido;
- [x] gates impactados e documentais estao registrados;
- [x] reconciliacao local, se o runtime estiver disponivel, e reportada sem
  confundir sua ausencia com falha repository-local.
- [x] sessao `login-actions` anterior ao toggle e invalidada; Keycloak retorna
  saudavel e o provider permanece OFF, sem remover action ou credencial.

## 5. Atomic Task Contract — TP-00050-T05

| Field | Content |
| --- | --- |
| **What** | Aceitar e provar repository-localmente o estado OFF/ON de `CONFIGURE_TOTP.enabled` nos tres identificadores ambientais suportados. |
| **Where** | Os dois paths executaveis congelados na Section 2.5 e detalhados em IP-BE-50.1.2-tenant-first-login-mfa-multi-environment-contract. |
| **Depends on** | PRD-00005 v1.36, REQ-00061 v1.6, ADR-0018 v3.7, UC-00016 v1.7 e ANL-00054 v1.3. |
| **Reuses** | Parser booleano, enum `dev|hml|production`, preflight de todos os providers, allowlist e fake `kcadm` existentes. |
| **Requirements** | REQ-00061 AC-61-002–005/007/008; AC-61-006 permanece coberto pela evidencia Java existente. |
| **Gate Audit** | `READY` na Section 2; handoff tecnico em IP-BE-50.1.2-tenant-first-login-mfa-multi-environment-contract v1.0. |

**Definition of Done:**

- [x] o reconciliador exige a flag explicita, aceita `false` e `true` em `dev`, `hml` e `production` e falha antes de mutacao para flag ausente/malformada ou ambiente invalido;
- [x] o teste hermetico prova os seis ramos, idempotencia, preflight integral e ausencia de mutacao proibida;
- [x] nenhum path alem dos dois targets executaveis e dos documentos/indexes desta reconciliacao foi alterado por T05;
- [x] quality gates focal e PR de infra retornam `PASS`; o gate documental agregado e executado no fechamento do lote documental concorrente.

### 5.1 Evidence — 2026-09-12

- baseline anterior: teste focal `PASS` sob o contrato DEV-only;
- implementacao: flag ausente/malformada e ambiente invalido falham antes de
  `update`; OFF/ON converge em `dev`, `hml` e `production`;
- teste focal: `6/6` combinacoes, verify e replay idempotente, `PASS`;
- Quality Gate focused: `PASS`; Quality Gate PR: `PASS`, incluindo sintaxe da
  suite shell, contratos do executor e metricas dos dois targets;
- ambiente: fixture/fake local; zero rede, credencial, container, deploy ou
  mutacao de DEV/HML/production.

## 6. Rollback

Definir `KEYCLOAK_TENANT_FIRST_LOGIN_MFA_ENABLED=true` e executar o mesmo
reconciliador autorizado. A pos-condicao exige o provider existente e
`enabled=true`; as required actions pendentes nunca foram apagadas.

O rollback de codigo de T05 restaura o guard DEV-only e seus cenarios historicos;
ele nao executa mudanca de realm. O rollback ambiental continua sendo definir
`KEYCLOAK_TENANT_FIRST_LOGIN_MFA_ENABLED=true` e executar o reconciliador somente
sob plano e autorizacao do ambiente alvo.

## 7. Change Log

| Version | Date | Changes |
| --- | --- | --- |
| 1.4 | 2026-09-12 | Conclui T05 repository-local: flag stateful explicita, matriz hermetica 6/6 e gates focused/PR verdes, sem acesso ou mutacao ambiental. |
| 1.3 | 2026-09-12 | Reabre o plano com T05 e IP-BE-50.1.2-tenant-first-login-mfa-multi-environment-contract em IRG READY para o contrato repository-local DEV/HML/production, preservando como historica a evidencia runtime somente DEV. |
| 1.2 | 2026-09-09 | Corrige a verificacao incompleta: invalida a authentication session preexistente, confirma Keycloak healthy e provider ainda OFF. |
| 1.1 | 2026-09-09 | Conclui implementacao, Quality Gates e provider OFF verificado no realm `saas-diretrizcontabilidaderecife`; login humano permanece apenas como confirmacao. |
| 1.0 | 2026-09-09 | Cria plano, materializa decisao e registra IRG READY antes de qualquer edicao executavel. |
