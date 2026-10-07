---
document_id: TP-00063
primary_nature: Plano
objective: Migrar realms estaticos de imports JSON para scripts idempotentes sobre a Keycloak Admin REST API.
scope: saas-admin e saas-bpfarias em DEV, HML e PRD, identidades iniciais, Compose, migrations e testes hermeticos.
non_objectives: Nao provisionar ambientes reais, migrar volumes persistidos, alterar onboarding dinamico ou versionar credenciais.
owner: Engenharia de Plataforma, Seguranca e Dados
status: Completed
version: 1.5
date: 2026-09-24
last_reviewed: 2026-09-25
keywords: keycloak, admin-rest-api, kcadm, realms, bootstrap, identidade, saas-theme, OTP
related_files: ../../docs/prds/PRD-00003-tenant-platform-lifecycle.md, ../../docs/prds/PRD-00005-identity-access-governance.md, do../../product/requirements/REQ-00031-phase2-tenant-lifecycle-and-access.md, ../../backend/docs/adrs/ADR-0018-keycloak-realm-provisioning-automation.md, ../../backend/docs/onboarding/keycloak-provisioning-identity.md
code_references: infra/keycloak/, docker-compose.yml, docker-compose.override.yml, docker-compose.hml.yml, docker-compose.prd.yml, backend/src/main/resources/db/migration/tenant/
principal_statement: Os realms estaticos e suas identidades canonicas passam a ser criados pela Admin REST API com saas-theme e sem OTP, sem import de realm, senha versionada ou efeito ambiental nesta entrega.
---

# TP-00063 — Provisionamento de realms pela Keycloak Admin REST API

## 1. Overview

Este plano substitui o consumo dos seis `*-realm.json` por scripts por ambiente que
usam o cliente oficial `kcadm.sh`. A entrega preserva roles, composites, clients,
protocol mappers, origens e timeouts, adiciona as identidades canonicas nos dois
realms e mantém aplicacao e IAM ligados pelo UUID efetivamente retornado pelo
Keycloak.

Nenhum ambiente externo será mutado. A prova combina `kcadm.sh` falso, Compose
renderizado com valores sintéticos e realms locais aleatórios removidos ao final.

## 2. Decisions

- Cada ambiente possui wrapper versionado e reutiliza lógica comum allowlisted.
- O inicializador tenta Client Credentials da service account permanente; a
  credencial de bootstrap é fallback exclusivo da primeira instalação.
- Realm ausente é criado por endpoints granulares; existente é verificado e não
  sobrescrito silenciosamente.
- Realms estáticos configuram explicitamente `loginTheme=saas-theme` (de `infra/keycloak/themes`)
  tanto na criação quanto na reconciliação idempotente de realms existentes.
- Usuários nos realms estáticos (`saas-admin` e `saas-bpfarias`) são criados sem senha versionada,
  com `UPDATE_PASSWORD` e sem ação de OTP (`CONFIGURE_TOTP`), mantendo a recuperação/primeiro
  acesso via SMTP do realm. Reconciliação em usuários existentes remove `CONFIGURE_TOTP` residual.
- `djmarcellopedrosa@gmail.com` recebe `ROLE_SUPER_ADMIN` e
  `ROLE_TENANT_AUDIT`; `contato@matrizcontabil.com.br` recebe
  `ROLE_TENANT_ADMIN`, nos três ambientes.
- O Keycloak é autoridade sobre o UUID de usuário: o script captura o ID retornado
  pela Admin API e o backend concilia o `iam_user_id` canônico por e-mail depois
  que Flyway conclui, falhando fechado em ausência ou ambiguidade.

## 3. Semantic decomposition

| Task | Observable outcome | Depends on | Handoff |
| --- | --- | --- | --- |
| `KC-API-001` | Plano, requisito e decisão registram o contrato. | N/A | Documentação validada. |
| `KC-API-002` | Migration contém os dois usuários da aplicacao. | `KC-API-001` | Seed testado. |
| `KC-API-003` | Scripts substituem seis JSONs e Compose ordena o bootstrap. | `KC-API-001/002` | Shell, contrato e Compose verdes. |
| `KC-API-004` | Exports JSON e consumidores operacionais são removidos. | `KC-API-003` | Busca legado vazia e deploy modular validado. |
| `KC-API-005` | UUID gerado pelo Keycloak é usado na atribuição de roles e conciliado no banco. | `KC-API-002/003` | Teste real aleatório e teste backend verdes. |
| `KC-API-006` | Tema saas-theme configurado nos realms e OTP dispensado nas identidades estáticas. | `KC-API-005` | Testes herméticos, contratos e documentação aprovados. |

## 4. Implementation Readiness Gate

### 4.1 Gate Audit

| Control | Evidence | Result |
| --- | --- | --- |
| Product Definition | PRD-00003 v1.14 e PRD-00005 v1.4 `Validated`. | PASS |
| Requirements | REQ-00031 v1.7 `Approved`, AC-TEN-028 e BR-TEN-031. | PASS |
| ADRs | ADR-0018 v3.9 `Accepted`; ADR-0031 sem efeito ambiental. | PASS |
| Use Cases | Bootstrap técnico sem nova interação de usuário. | N/A |
| API Contract | API externa do Keycloak; API HTTP backend não muda. | N/A |
| Assumptions | Nenhuma; ambientes, realms, identidades, saas-theme e dispensa de OTP decididos. | PASS |
| Open Questions | Nenhuma. | PASS |
| Dependencies | `kcadm.sh` na imagem 26.6.3; tema `saas-theme` em `infra/keycloak/themes`; migrations V16, V21, V88 e V93; Keycloak Admin Client já configurado no backend. | PASS |
| Granularity | Pai decomposto por governança, seed, provisionamento, limpeza, conciliação e alinhamento de tema/OTP. | PASS |

### 4.2 Acceptance Tests

| Criterion | Evidence | Expected result |
| --- | --- | --- |
| `AC-TEN-028-A` | Teste com `kcadm` falso para DEV/HML/PRD. | Realms, clients, mappers, roles e composites criados uma vez com saas-theme e sem CONFIGURE_TOTP. |
| `AC-TEN-028-B` | Segunda execução hermética. | Zero duplicação; tema reconciliado e OTP residual de usuários removido fail-closed. |
| `AC-TEN-028-C` | Inspeção de argumentos e temporários. | Nenhuma senha humana em Git, argv ou log. |
| `AC-TEN-028-D` | Teste da migration V93. | Ambos os e-mails existem uma vez com perfil e IAM ID esperados. |
| `AC-TEN-028-E` | Compose `config --quiet`. | Ordem Keycloak, realms, identidade técnica e backend válida. |
| `AC-TEN-028-F` | Realm aleatório no Keycloak 26.6.3 e teste unitário backend. | O UUID retornado é usado nas roles e substitui o placeholder de V93. |

### 4.3 Prohibited

- Executar deploy ou ambiente externo; o teste local autorizado usa somente realms
  aleatórios e deve removê-los ao terminar.
- Ler `.env`, secrets, dumps ou credenciais; versionar senha inicial.
- Substituir o template backend por construcao programatica de `RealmRepresentation`.
- Atualizar realm existente sem verificação fail-closed.

### 4.4 Mandatory

- Scripts POSIX abaixo de 500 linhas, `bash -n` e teste hermético focal.
- Todos os arquivos alterados informados ao Quality Gate.
- `validate-docs.sh`, teste de migration e Compose com valores dummy.
- Branch governada, hook, commit convencional e push após gates PASS.

### 4.5 Result

| Field | Value |
| --- | --- |
| Readiness Result | READY |
| Auditor | @AgentOrchestrator usando `implementation-readiness` |
| Source Versions | PRD-00003 v1.14; PRD-00005 v1.4; REQ-00031 v1.7; ADR-0018 v3.9; ADR-0031 v1.1 |
| Scope Authorized | `KC-API-001..006`; paths deste plano, provisionador, validadores, documentação de onboard e testes correspondentes |
| Decomposition | `TP-00063 -> KC-API-001 -> KC-API-002 -> KC-API-003 -> KC-API-004 -> KC-API-005 -> KC-API-006` |
| Blockers / Decision Owner | N/A |

## 5. Atomic execution contracts

### KC-API-001 — Governança

- **What/Where:** registrar decisão, requisito, plano e índice nos documentos citados.
- **Reuses:** ADR-0000, TPL-00005 e skill de governança.
- **Definition of Done:** links presentes e `validate-docs.sh` retorna 0.

### KC-API-002 — Identidades na aplicacao

- **What/Where:** semear os dois usuários em nova migration Tenant V93 e teste.
- **Reuses:** V16, V21, V88 e tenant `aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa`.
- **Definition of Done:** migration forward-only idempotente e teste comprova
  e-mails, perfis, status e IDs IAM.

### KC-API-003 — Realms pela Admin API

- **What/Where:** criar e verificar realms em `infra/keycloak/`, Compose e testes.
- **Reuses:** `kcadm.sh`, service account, validadores e reconcilers atuais.
- **Definition of Done:** seis JSONs fora do runtime Compose; scripts, Compose e Quality Gate
  verdes; identidades e contratos de token preservados.

### KC-API-004 — Remoção integral dos exports estáticos

- **What/Where:** remover os seis `*-realm.json` de `infra/keycloak/{dev,hml,prd}`
  e substituir validadores, testes, documentação e empacotamento de PRD por
  contratos sobre `provision-realms.sh` e seus wrappers.
- **Reuses:** `KC-API-003`, `kcadm.sh`, `deploy-production.sh` e validadores
  herméticos existentes.
- **Definition of Done:** nenhuma referência executável aos seis exports, nenhum
  artefato JSON renderizado para bootstrap de PRD e busca de paths legado vazia;
  os contratos de roles, mappers, identidades e ambiente seguem testados.

### KC-API-005 — Conciliação do UUID atribuído pelo Keycloak

- **What/Where:** remover a expectativa de UUID determinístico do provisionador,
  usar o ID retornado pela Admin API e reconciliar o Super Admin canônico no
  bootstrap do backend após Flyway.
- **Reuses:** `Keycloak` Admin Client, `AdminUserJpaRepository`, V93 e busca exata
  por e-mail no realm `saas-admin`.
- **Definition of Done:** ausência/ambiguidade falham o startup; divergência válida
  atualiza `admin_users.iam_user_id`; teste unitário cobre convergência e teste real
  cria/remove realms aleatórios sem tocar `saas-admin` ou `saas-bpfarias`.

### KC-API-006 — Tema customizado e remoção de OTP em identidades estáticas

- **What/Where:** `infra/keycloak/provision/provision-realms.sh`, `infra/keycloak/bootstrap/validate-realm-token-contracts.sh`,
  `infra/scripts/tests/keycloak-static-realm-provisioning-test.sh` e documentação correspondente.
- **Reuses:** tema `saas-theme` em `infra/keycloak/themes`, `kcadm.sh` e contratos existentes.
- **Definition of Done:** criação e reconciliação dos realms configuram `loginTheme=saas-theme`; criação
  e reconciliação de usuários removem `CONFIGURE_TOTP`, mantendo apenas `UPDATE_PASSWORD`; testes
  herméticos e validadores passam zero-skip.

## 6. Rollback and operational handoff

Rollback repository-local reverte scripts e integrações por mudança forward-only,
sem reintroduzir exports JSON. Realms existentes não são apagados. Aplicação a
volume ou ambiente real exige plano operacional, backup e aprovação específica de
Segurança, Dados e Ambiente.

## 7. Tracking

| Task | Status | Evidence |
| --- | --- | --- |
| `KC-API-001` | Done | ADR, requisito, plano e indice aprovados pelo validador documental. |
| `KC-API-002` | Done | V93 aplicada em PostgreSQL; 3 testes focalizados passaram. |
| `KC-API-003` | Done | Teste hermetico idempotente, contratos legados e Compose DEV/HML/PRD passaram. |
| `KC-API-004` | Done | Seis exports removidos; contrato, documentação e deploy passam a apontar ao provisionador Admin API. |
| `KC-API-005` | Done | Keycloak 26.6.3 criou dois realms aleatórios, retornou UUIDs válidos reutilizados na segunda execução e nas roles; reconciler backend convergiu o ID e os realms temporários foram removidos. |
| `KC-API-006` | Done | `keycloak-static-realm-provisioning-test.sh`, `validate-realm-token-contracts.sh` e `keycloak-bootstrap-hardening-test.sh` verdes; tema saas-theme configurado e CONFIGURE_TOTP removido das identidades estáticas. |

### 7.1 Evidência de encerramento

- Provisionamento real idempotente executado duas vezes contra o Keycloak local na
  porta 8180, sem tocar `saas-admin` ou `saas-bpfarias`.
- Os dois UUIDs atribuídos pelo servidor foram capturados, validados e usados nas
  atribuições de roles; uma consulta posterior encontrou exatamente um usuário por
  identidade.
- Os realms aleatórios responderam durante a prova e retornaram HTTP 404 depois da
  limpeza.
- Testes focalizados do provisionador, contratos de token, autoridades, reconciler
  backend e deploy de produção passaram.
- O deploy de produção foi decomposto por responsabilidade em módulos menores que
  500 linhas, preservando o entrypoint e o teste operacional existente.

## 8. Change Log

| Version | Date | Change |
| --- | --- | --- |
| 1.5 | 2026-09-25 | Configura loginTheme=saas-theme para saas-admin e saas-bpfarias, dispensa CONFIGURE_TOTP nas identidades estáticas e atualiza testes herméticos e contratos. |
| 1.4 | 2026-09-24 | Conclui a conciliação do UUID real, registra a prova local idempotente e a decomposição governada do deploy. |
| 1.3 | 2026-09-23 | Reabre o plano para capturar e conciliar o UUID atribuído pelo Keycloak, conforme evidência do teste real autorizado. |
| 1.2 | 2026-09-23 | Conclui a remoção integral dos seis exports JSON e de seus consumidores operacionais. |
| 1.1 | 2026-09-23 | Implementacao e evidencias concluidas; imports JSON removidos do runtime. |
| 1.0 | 2026-09-23 | Plano aprovado pelo Implementation Readiness Gate. |
