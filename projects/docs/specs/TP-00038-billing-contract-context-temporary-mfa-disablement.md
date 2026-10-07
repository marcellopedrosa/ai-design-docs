---
document_id: TP-00038
primary_nature: Plano
objective: Coordenar a desativacao temporaria e reversivel do MFA na entrada Super Admin do workspace de contratos sem ampliar a excecao para outros fluxos de Billing.
scope: POST /api/v1/admin/billing/elevated-contexts, authorities BILLING_CONTRACT_*, BillingElevatedContext, migration aditiva, launcher /admin/billing/tenants, testes e documentacao repository-local.
non_objectives: Nao desabilitar MFA para tenant-admin, catalogo, faturas, runs, approvals de catalogo, provider, break-glass ou Keycloak; nao remover RBAC, SoD, purpose, TTL, tenant guard, idempotencia ou auditoria; nao executar deploy ou rollout ambiental.
owner: Billing, Seguranca, Backend, Frontend e Arquitetura
status: Completed
version: 1.3
date: 2026-09-06
last_reviewed: 2026-09-10
keywords: billing, contratos, mfa, excecao temporaria, super admin, contexto elevado, rollback
related_files: ../../backend/docs/adrs/ADR-0050-rbac-sod-aprovacoes-financeiras.md, do../../product/requirements/REQ-00054-super-admin-unified-billing-price-version.md, do../../product/use-cases/UC-00049-super-admin-tenant-contract-add-ons-discounts.md, TP-00035-super-admin-unified-billing-management.md, TP-00037-billing-mfa-amr-evidence-correction.md
code_references: backend/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/application/usecase/ManageBillingElevatedContextUseCase.java, backend/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/domain/contract/BillingElevatedContext.java, backend/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/infrastructure/persistence/JdbcBillingElevatedContextStoreAdapter.java, backend/src/main/resources/application.yml, backend/src/main/resources/db/migration/tenant/, frontend/src/components/billing/tenant/BillingTenantLauncher.tsx, frontend/src/components/billing/management/BillingContextBoundary.tsx, frontend/src/lib/protected-routes.ts, frontend/src/lib/__tests__/protected-routes.test.ts, frontend/src/schemas/billingManagementSchemas.ts, frontend/src/schemas/billingManagementSchemas.test.ts, frontend/src/services/__tests__/billingManagementService.test.ts
principal_statement: Enquanto a flag repository-local estiver desativada, somente um contexto Super Admin composto exclusivamente por authorities de contrato pode ser emitido e usado sem prova MFA; qualquer outro contexto continua falhando fechado sem MFA recente.
---

# TP-00038 — Desativacao temporaria do MFA no contexto de contratos

## 1. Autorizacao e resultado esperado

A solicitacao humana de 2026-09-06 autoriza uma emenda material e temporaria ao
baseline do ADR-0050. A proveniencia e `HUMAN_EXPLICIT`; o repositorio nao comprova
criptograficamente a identidade do solicitante. A autorizacao cobre somente a
implementacao repository-local descrita neste plano e nao autoriza deploy, acesso
a ambiente, dado real ou alteracao de identidade no Keycloak.

O Super Admin deve conseguir selecionar um tenant em `/admin/billing/tenants`,
informar o purpose e entrar no workspace de contratos sem reautenticacao MFA. A
excecao deve ser server-authoritative, explicitamente persistida e reversivel por
configuracao. Nao se deve fabricar claim, metodo ou evidencia MFA.

## 2. Matriz de politica

| Emissor / authorities solicitadas | Flag `billing.security.admin-contract-context-mfa-enabled` | Resultado sem MFA recente |
| --- | --- | --- |
| Super Admin / conjunto nao vazio somente de `BILLING_CONTRACT_*` allowlisted | `false` | Emite contexto contratual com waiver explicito. |
| Super Admin / conjunto contratual | `true` | `BILLING_MFA_REQUIRED`. |
| Super Admin / invoice, run ou conjunto misto | qualquer valor | `BILLING_MFA_REQUIRED`. |
| Tenant Admin / qualquer authority financeira | qualquer valor | `BILLING_MFA_REQUIRED`. |
| Catalogo, approval, provider, break-glass ou outro endpoint | qualquer valor | Comportamento vigente, sem excecao. |

A allowlist contratual exata e:

- `BILLING_CONTRACT_DRAFT`;
- `BILLING_CONTRACT_SUBMIT`;
- `BILLING_CONTRACT_ACCEPT`;
- `BILLING_CONTRACT_ACCEPT_RECORD`;
- `BILLING_CONTRACT_ACCEPT_VALIDATE`.

Prefixo livre, wildcard, `BILLING_CONTRACT_ALL` ou authority desconhecida nao
satisfazem a excecao.

## 3. Invariantes preservadas

1. `ROLE_SUPER_ADMIN` e `BILLING_TENANT_IMPERSONATE` continuam obrigatorios no
   endpoint administrativo.
2. Ator humano efetivo, tenant ativo, purpose normalizado, authorities finas,
   idempotencia e hash da decisao continuam validados pelo backend.
3. Hard TTL de 30 minutos, idle TTL de 15 minutos, revogacao e troca/limpeza de
   cache continuam obrigatorios.
4. Path, `X-Tenant-ID`, context ID, purpose e authority continuam conferidos antes
   de datasource ou transacao tenant-local.
5. Maker e checker continuam pessoas humanas distintas; o waiver nao cria
   ApprovalSeal, nao remove SoD e nao concede authority.
6. Contextos com MFA continuam sujeitos a freshness de 15 minutos. Um contexto
   dispensado nunca e reclassificado como prova MFA.
7. Ao reativar a flag, contextos dispensados ainda vivos devem falhar
   imediatamente; nao se espera apenas o hard TTL.

## 4. Contrato tecnico

### 4.1 Backend e persistencia

- introduzir uma porta de politica de MFA no modulo Billing e um adapter de
  configuracao; o default versionado da flag e `false`;
- permitir que `BillingElevatedContext` represente ausencia deliberada de
  evidencia somente quando todas as authorities forem contratuais;
- emitir waiver apenas em `issueForSuperAdmin`; `issueForTenant` permanece
  invariavelmente MFA-bound;
- incluir a decisao MFA/waiver no request hash de idempotencia;
- persistir `mfa_required` e tornar os campos de evidencia nulos somente quando
  `mfa_required=false`, por migration Flyway aditiva no proximo numero livre;
- validar no uso do contexto a politica corrente, de modo que ligar a flag revogue
  na pratica qualquer waiver ainda ativo;
- publicar `BILLING_ELEVATED_CONTEXT_V2` com `mfaRequired` e
  `mfaExpiresAt=null` quando houver waiver, sem atribuir significado falso a uma
  evidencia inexistente.

### 4.2 Frontend

- separar no launcher a entrada contratual da entrada de faturamento;
- a acao de contratos solicita somente authorities `BILLING_CONTRACT_*` e segue
  para `/billing/quotes/new`;
- a acao de faturamento solicita somente authorities de invoice/run, preserva o
  step-up MFA e segue para `/billing/invoices`;
- aceitar o contrato V2 e considerar `mfaExpiresAt` somente quando
  `mfaRequired=true`;
- manter o CTA de reautenticacao para o erro exato `BILLING_MFA_REQUIRED` nos
  fluxos que continuam protegidos.

### 4.3 TP-00038-F01 — consumir tenant GUID e concluir a navegação contratual

**What:** uma resposta `201` válida de emissão do contexto contratual deve ser
consumida pelo frontend e concluir a navegação para `/billing/quotes/new` mesmo
quando o `tenantId` canônico não possui nibble de versão/variante RFC.

**Where:** `frontend/src/schemas/billingManagementSchemas.ts`,
`frontend/src/schemas/billingManagementSchemas.test.ts` e
`frontend/src/services/__tests__/billingManagementService.test.ts`.

**Depends on:** REQ-00054 v1.15 `Approved`, UC-00049 v1.8 `Approved`, ADR-0050
v1.5 `Accepted`, endpoint V2/ETag disponível e TP-00038 v1.1 executado no
repositório.

**Reuses:** `billingTenantIdSchema` de `billingSchemas.ts`, o teste de fronteira
de `tenantPoolPolicySchemas.test.ts`, o precedente documentado em
IP-FE-23.4.1-tenant-pool-managed-runtime-ui-regression e o fluxo existente `billingManagementService.issueContext` →
`BillingTenantLauncher.onSuccess`.

**Requirements:** REQ-00054 AC-050, AC-053 e AC-061–063; UC-00049 passo 3 e
E2/E2a; ADR-0050 Sections 2.7/2.7.1; Frontend Standard v1.4, Frontend Testing
Standard v1.5, Next.js Standard v1.4, Software Quality Standard v1.0 e
Implementation Readiness Standard v1.1.

#### Gate Audit

| Controle | Evidência em 2026-09-08 |
| --- | --- |
| Fontes superiores | REQ-00054 v1.15 está `Approved`; UC-00049 v1.8 está `Approved`; ADR-0050 v1.5 está `Accepted`. |
| User Story View | REQ-00054 Section 2.1 e UC-00049 vinculam o Super Admin, a entrada contratual e o valor aos AC-050/053/061–063. |
| Use Case aplicável | UC-00049 passo 3 e sua matriz AC → fluxo → teste cobrem o `201`, o waiver, o tenant e a navegação. |
| Assumptions | Nenhuma `Proposed`. O payload de 614 bytes foi reproduzido: a única divergência é `tenantId`; ETag e campos nulos estão presentes. |
| Open Questions | Nenhuma `Open`; o relato humano confirma que “Gerenciar contratos” deve abrir o workspace, comportamento já normatizado no passo 3. |
| Dependências | O backend V2 responde `201`, o tenant DEV existe e `billingTenantIdSchema` já é usado por outros contratos tenant. |
| Escopo e tarefa | Sete campos semanticamente tenant serão alinhados; IDs de recurso, MFA, authorities, backend, configuração e ambiente ficam fora. |

#### Acceptance Tests

| Critério | Teste/comando | Resultado esperado |
| --- | --- | --- |
| AC-061/062/063 e UC passo 3 | Atualizar `billingManagementService.test.ts` com o `tenantId=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa` do payload observado. | `issueContext` resolve o V2 com ETag e waiver; não lança `BillingManagementContractError`. |
| AC-053/063 | Criar `billingManagementSchemas.test.ts` cobrindo `audienceTenantId` e os seis `tenantId` de Billing. | Todos aceitam/normalizam GUID tenant; `contextId` e demais IDs de recurso continuam rejeitando valor sem nibble RFC. |
| Navegação observável | Reexecutar `BillingTenantLauncher.test.tsx`. | `setContext`, `setImpersonate` e `router.push('/billing/quotes/new')` ocorrem; não aparece CTA MFA no happy path. |
| Regressão negativa | Reexecutar service, boundary, validade e launcher. | V1, conjunto vazio/misto/invoice, waiver com expiração fabricada e MFA protegida continuam fail-closed. |
| Gate focal | `./infra/scripts/validate-quality-gates.sh --scope frontend --level focused --focus billingManagement` | `QUALITY_GATE_RESULT=PASS`. |

#### Prohibited

- não relaxar o alias UUID usado por IDs de contexto, produto, preço, quote,
  agreement, amendment, run ou outros recursos;
- não alterar backend, migration, flag MFA, allowlist, role, purpose, TTL, SoD,
  approval, Keycloak ou fluxo de faturamento;
- não ler `.env.local`, usar rede, instalar dependência, acessar dados reais,
  promover ambiente ou executar Git;
- não transformar erro `403` ou payload inválido em sucesso.

#### Mandatory

- primeiro reproduzir a falha com fixture tenant sem nibble RFC;
- aplicar somente o schema compartilhado de tenant nos sete campos semânticos;
- executar teste focal, suíte frontend impactada, lint, typecheck, formato do
  conjunto alterado e build em cópia isolada sem arquivo `.env*`;
- executar `./infra/scripts/validate-docs.sh` e registrar toda falha ou skip.

#### Definition of Done

- [x] A regressão falha antes do reparo com `Invalid UUID` somente em `tenantId`.
- [x] Os sete campos tenant reutilizam `billingTenantIdSchema`; IDs de recurso
  continuam no alias UUID estrito.
- [x] Serviço e launcher passam com o tenant GUID observado e navegação esperada.
- [x] Gate focal, suíte frontend impactada, lint, typecheck, formato focal e build
  isolado retornam código `0`.
- [x] Documentos e índices imediatos estão sincronizados e o gate documental
  retorna código `0` ou registra falha externa ao escopo sem falso verde.

#### Result

`READY` — auditado por AgentOrchestrator/Codex em 2026-09-08 para a versão e os
três paths exatos desta task. Não há blocker remanescente; qualquer ampliação de
path, comportamento ou fonte invalida este resultado e exige nova auditoria.

### 4.4 TP-00038-F02 — preservar autorização durante a transição ao workspace

**What:** depois do `201` válido e da seleção do tenant, a rota global
`/admin/billing/tenants` deve permanecer autorizada pelo papel original de Super
Admin durante a transição para `/billing/quotes/new`, sem renderizar
transitoriamente `ForbiddenPage`.

**Where:** `frontend/src/lib/protected-routes.ts` e
`frontend/src/lib/__tests__/protected-routes.test.ts`.

**Depends on:** PRD-00001 v1.10 `Validated`; REQ-00054 v1.18 `Approved`;
UC-00049 v1.12 `Approved`; ADR-0050 v1.8 `Accepted`; TP-00038-F01 concluído; e
autorização humana de continuidade do reparo registrada nesta conversa em
2026-09-10.

**Reuses:** `canAccessRoute`, a regra existente de rota específica antes do papel
efetivo tenant-scoped e a matriz de `protected-routes.test.ts`.

**Requirements:** REQ-00054 AC-050/053/063; UC-00049 passo 3; Frontend Standard,
Frontend Testing Standard, Next.js Standard, Software Quality Standard v1.3 e
Implementation Readiness Standard v1.6.

#### Gate Audit

| Controle | Evidência em 2026-09-10 |
| --- | --- |
| Product Definition | PRD-00001 v1.10 está `Validated`; F-BIL-006/F-BIL-010 cobrem a jornada administrativa de contratos. |
| Fontes superiores | REQ-00054 v1.18 está `Approved`, UC-00049 v1.12 está `Approved` e ADR-0050 v1.8 está `Accepted`; a implementação é autorizada pelo pedido humano corrente e por esta task. |
| User Story View | REQ-00054 Section 2.1 e UC-00049 vinculam o Super Admin, a seleção do tenant e a entrada no workspace aos AC-050/053/063. |
| Use Case aplicável | UC-00049 passo 3 exige que a confirmação redirecione para `/billing/quotes/new`; AC-063 exige instalação do contexto/personificação e navegação. |
| API Contract | N/A — não cria, altera nem consome nova operação HTTP; corrige somente a decisão de rota no cliente após um `201` já coberto. |
| Assumptions | Nenhuma `Proposed`; as capturas mostram o `ForbiddenPage` ainda em `/admin/billing/tenants` imediatamente após o clique. |
| Open Questions | Nenhuma `Open`; o destino, o ator, o tenant e a regra esperada estão definidos nas fontes aprovadas. |
| Dependências | Emissão do contexto, schema GUID e `router.push('/billing/quotes/new')` já estão implementados e verdes em TP-00038-F01. |
| Escopo | Somente a exceção da rota launcher e sua regressão; demais rotas globais continuam negadas durante personificação. |
| Granularidade / Decomposição | `Semantically indivisible`: uma decisão de autorização de transição e seu teste formam um único resultado/handoff. Children: N/A. |
| Tarefa | What, Where, Depends on, Reuses, Requirements e DoD são finitos e binários. |

#### Acceptance Tests

| Critério | Teste/comando | Resultado esperado |
| --- | --- | --- |
| AC-063 / UC passo 3 | Regressão em `protected-routes.test.ts` com Super Admin, `/admin/billing/tenants` e tenant selecionado. | O launcher continua autorizado durante a transição. |
| Isolamento global | Mesma regressão verifica outra rota administrativa global durante personificação. | A outra rota permanece negada; não há relaxamento geral de RBAC. |
| Destino tenant-scoped | Matriz existente verifica `/billing/quotes/new` com Super Admin personificado. | O destino continua autorizado como tenant admin efetivo. |
| Gate focal | Executor canônico com foco `protected-routes` e todos os targets alterados. | A1/A2 aplicáveis em `PASS`. |

#### Prohibited

- não liberar genericamente rotas `/admin/**` durante personificação;
- não persistir `BillingElevatedContext`, remover `ForbiddenPage` ou relaxar
  validação de tenant/authority/TTL;
- não alterar backend, API, MFA, Keycloak, roles, dados reais ou ambiente;
- não instalar dependência, usar rede, ler segredo ou executar deploy.

#### Mandatory

- reproduzir primeiro o RED na função pura `canAccessRoute`;
- limitar a exceção ao launcher `/admin/billing/tenants` para o papel original
  `ROLE_SUPER_ADMIN`;
- manter negativa explícita para outra rota administrativa durante personificação;
- executar teste focal, suíte impactada, lint, typecheck, formato, build seguro,
  Quality Gate com todos os `--target` e validador documental.

#### Definition of Done

- [x] RED comprova que o launcher fica negado assim que o tenant é selecionado.
- [x] Launcher permanece autorizado pelo papel original somente durante/na
  personificação; demais rotas administrativas preservam a decisão vigente.
- [x] Destino `/billing/quotes/new` permanece autorizado e o contexto financeiro
  continua memory-only/fail-closed.
- [x] Testes focados e impactados, lint, typecheck, formato e build retornam `0`.
- [x] Quality Gate e governança documental finais retornam `PASS` com todos os
  targets e evidências registrados.

#### Result

`COMPLETED` — implementado e verificado por AgentOrchestrator/Codex em 2026-09-10
para TP-00038 v1.3, IP-FE-13.2.2-super-admin-tenant-commercial-contracts v1.8
e os dois paths exatos de **Where**. Blockers do corretivo: nenhum.

## 5. Sequencia de execucao

| Ordem | Entrega | Estado |
| ---: | --- | --- |
| 1 | Emendar ADR-0050, REQ-00054, UC-00049 e planos relacionados. | Completed |
| 2 | Implementar flag, modelo de contexto, migration e adapter JDBC. | Completed |
| 3 | Atualizar contrato TypeScript/Zod, launcher e guards de expiracao. | Completed |
| 4 | Criar/atualizar testes backend, frontend e PostgreSQL. | Completed |
| 5 | Executar suites impactadas, gates arquiteturais, build e validador documental. | Completed com excecoes globais registradas na Secao 9. |
| 6 | Registrar evidencias e concluir o plano sem promover ambiente. | Completed |
| 7 | Corrigir TP-00038-F01, executar regressões e reconciliar evidências. | Completed |
| 8 | Corrigir TP-00038-F02 e impedir `ForbiddenPage` durante a transição ao workspace. | Completed |

## 6. Verificacao

Backend focalizado:

    cd backend
    ./mvnw -B -Dtest=BillingElevatedContextTest,ManageBillingElevatedContextUseCaseTest,BillingElevatedContextControllerTest,BillingSecurityConfigurationTest test
    ./mvnw -B -Dtest=BillingElevatedContextMigrationPostgresTest test
    ./mvnw -B -Dtest=ModuleStructureVerificationTest test
    ./mvnw -B -Dtest=CleanArchitectureRulesTest,CleanArchitectureRuleContractTest test
    ./mvnw -B clean test

Frontend focalizado e gates:

    cd frontend
    npm test -- --run src/components/billing/tenant/__tests__/BillingTenantLauncher.test.tsx src/components/billing/management/__tests__/BillingContextBoundary.test.tsx src/services/__tests__/billingManagementService.test.ts src/lib/__tests__/billingContextValidity.test.ts
    npm test
    npm run lint
    npx tsc --noEmit --incremental false
    npm run format:check
    npm run build

Documentacao:

    ./infra/scripts/validate-docs.sh

O teste PostgreSQL pode ser `SKIPPED` somente quando Docker estiver realmente
indisponivel; o skip deve ser reportado e nao equivale a evidencia ambiental.

## 7. Rollback e criterio de reativacao

Rollback operacional repository-local: definir
`BILLING_SECURITY_ADMIN_CONTRACT_CONTEXT_MFA_ENABLED=true` (binding relaxed da
flag) e reiniciar a aplicacao. A validacao server-side deve rejeitar imediatamente
contextos com waiver ainda nao expirados. Nenhuma linha e removida e nenhum
contexto e convertido retroativamente em evidencia MFA.

A reativacao definitiva exige decisao humana explicita, atualizacao do
ADR-0050/REQ-00054/UC-00049, testes do caminho MFA recente e remocao ou promocao
consciente da flag. Evidencia AMR produzida pelo TP-00037 permanece valida e nao e
desinstalada por este plano.

## 8. Riscos e mitigacoes

| Risco | Mitigacao |
| --- | --- |
| Excecao alcançar invoice/run | Allowlist exata, request contratual separado e testes de conjunto misto. |
| Waiver parecer MFA real | Campos de evidencia nulos, `mfaRequired=false` e schema V2. |
| Flag ligada nao invalidar contexto antigo | Policy corrente participa da validacao de cada uso. |
| Remocao de MFA eliminar SoD | Guards de identidade humana e maker/checker permanecem independentes. |
| Apenas a UI desabilitar o controle | A decisao e emitida, persistida e validada pelo backend. |
| Mudanca quebrar cliente antigo | Schema versionado V2 e frontend atualizado no mesmo conjunto repository-local. |

## 9. Evidencias de execucao repository-local

### 9.1 Evidências do corretivo TP-00038-F02 em 2026-09-10

- RED focal: `protected-routes.test.ts` falhou em 1/16 antes da correção, porque
  `/admin/billing/tenants` retornava `false` após a seleção do tenant.
- GREEN focal: `protected-routes.test.ts` passou 16/16; a suíte impactada de
  `protected-routes`, `BillingTenantLauncher` e `BillingContextBoundary` passou
  23/23.
- Quality Gate focal canônico, com os seis targets de código e documentação,
  retornou `QUALITY_GATE_RESULT=PASS`.
- `npm run lint` retornou zero erros (52 warnings preexistentes), `npm run
  typecheck` retornou `0` e o Prettier focal retornou `0`.
- O build Next.js com webpack, variáveis públicas locais e diretório isolado
  retornou `0`, compilou TypeScript e gerou 56 páginas. O Turbopack não pôde
  abrir sua porta interna no sandbox e não foi usado como evidência positiva.
- `./infra/scripts/validate-docs.sh` retornou `PASS`: 795 Markdown, 31
  diretórios, 797 artefatos indexados e cobertura de contrato 228/228.
- A cobertura global executou 1312 testes: 1309 passaram e 3 falharam em
  expectativas preexistentes de `auth-return-to`/`menu-utils`, fora dos dois
  paths desta task. O arquivo alterado atingiu 96,19% de linhas e 100% de
  branches no recorte focal; as falhas globais não foram reclassificadas como
  resultado deste corretivo.

| Gate | Resultado em 2026-09-06 |
| --- | --- |
| Backend focalizado — dominio, use case, controller e binding da flag | `PASS`: 22 testes, zero falhas, erros ou skips. |
| Arquitetura backend — Modulith e Clean Architecture | `PASS`: 29 testes, zero falhas, erros ou skips. |
| Migration PostgreSQL `V82__allow_contract_context_mfa_waiver.sql` | Classe compilada; teste marcado `SKIPPED` porque o sandbox negou `/var/run/docker.sock`. O skip nao constitui prova PostgreSQL ambiental. |
| Backend completo — `./mvnw -B clean test` | 2.728 testes: uma falha de expectativa Keycloak sobre quatro roles Billing preexistentes, quatro erros de suites Fiscal por Docker indisponivel e 130 skips. Os cinco resultados nao pertencem ao waiver; os testes do recorte passaram dentro da execucao. |
| Frontend focalizado | `PASS`: 4 arquivos e 21 testes; apos o unico ajuste mecanico de formato, o launcher foi repetido com 3/3 testes verdes. |
| Frontend completo — `npm test` | `PASS`: 171 arquivos e 1.064 testes. |
| ESLint e TypeScript | `PASS`: lint com zero erros e 56 avisos; `tsc --noEmit --incremental false` sem diagnosticos. |
| Build Next.js | `PASS`: build de producao com valores publicos ficticios e rota `/admin/billing/tenants` gerada. |
| Prettier do conjunto alterado | `PASS`: 11 arquivos TypeScript/TSX/JSON. O `format:check` global permanece fora do recorte porque encontra outros arquivos nao formatados e o artefato UTF-16 `frontend/use-permission-result.json`. |
| Compose | `PASS`: `config --quiet` com valores ficticios e resolucao observada `BILLING_SECURITY_ADMIN_CONTRACT_CONTEXT_MFA_ENABLED: "false"`; nenhum container foi iniciado. |
| Governanca documental agregada | O contrato estrutural passou para 738 Markdown, 30 diretorios e 719 artefatos indexados, e o gate IP-INFRA passou. O wrapper global terminou com duas categorias de erro exclusivamente na familia concorrente `TP-00039-payment-provider-management-console.md` e seus artefatos; esses arquivos nao foram alterados por este plano. |

### 9.2 Evidencias do corretivo TP-00038-F01 em 2026-09-08

| Gate | Resultado |
| --- | --- |
| RED antes do reparo — `npm test -- billingManagement` | `FAIL` esperado: 3 arquivos, 8 testes falharam e 26 passaram; os sete campos tenant e o consumo do contexto rejeitaram o GUID observado com `Invalid UUID`. |
| Gate focal canônico | `PASS`: `QUALITY_GATE_RESULT=PASS`, 3 arquivos e 34/34 testes. |
| Suíte impactada | `PASS`: schema, service, launcher, boundary e validade; 5 arquivos e 42/42 testes. O launcher preservou MFA no faturamento e navegou contratos para `/billing/quotes/new`. |
| Frontend global — `npm test` | `FAIL/INCONCLUSIVE`: o executor terminou por `SIGTERM`/143 antes do resumo. Os timeouts observados pertenciam a seis arquivos fora de Billing; cinco passaram isolados. `UserGrid` teve 1 timeout de 5 s, depois passou no caso isolado e no arquivo completo, sem apagar a falha intermitente inicial. Nenhum teste do recorte falhou. |
| ESLint, TypeScript e formato focal | `PASS`: lint com zero erros e 52 avisos preexistentes; `npm run typecheck` sem diagnóstico; os três arquivos alterados passaram no Prettier após ajuste mecânico do teste novo. |
| Build Next.js | `PASS`: `npm run build` em cópia limpa, sem `.env*` nem `.next*` preexistente e com somente valores públicos fictícios; as rotas `/admin/billing/tenants` e `/billing/quotes/new` foram geradas. As duas preparações anteriores falharam por symlink externo rejeitado pelo Turbopack e por artefatos `.next-*` copiados, não por código da entrega. |
| Governança documental final | `PASS`: wrapper canônico com 24/24 testes estruturais, 750 Markdown, 30 diretórios, 732 artefatos indexados, contratos de Quality Gate/IP-INFRA e referências cruzadas aprovados. |
| E2E autenticado/backend-real | `NOT RUN`: não integra o contrato finito deste corretivo de schema e exige ambiente/identidade operacional não autorizados nesta execução. |

Nao houve deploy, acesso a producao, alteracao de realm, uso de credencial real nem
promocao ambiental. A execucao solicitada corresponde ao default repository-local
desativado, ao wiring do Compose e ao comportamento implementado/testado. Para um
ambiente ja implantado, a efetivacao depende do fluxo operacional autorizado de
deploy e restart.

## 10. Criterio de conclusao

O plano termina somente quando a matriz positiva/negativa estiver automatizada,
o default `false` for observado em teste de configuracao e no Compose, o launcher
contratual nao oferecer step-up no happy path, os fluxos fora do recorte
continuarem fail-closed e o handoff registrar qualquer skip ou ausencia de prova
ambiental.
Esses criterios foram satisfeitos no repositorio; falhas globais externas ao
recorte permanecem explicitamente separadas na Secao 9.

## 11. Change log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.3 | 2026-09-10 | Solicitante humano / Codex | Reabre o plano e registra TP-00038-F02 `READY` para eliminar a negação transitória do launcher sem liberar outras rotas administrativas. |
| 1.2 | 2026-09-08 | Solicitante humano / Codex | Registra `READY`, executa TP-00038-F01 e restaura a navegação pós-`201` ao alinhar os sete campos tenant ao GUID canônico, preservando UUID de recursos e o limite do waiver MFA. |
| 1.1 | 2026-09-06 | Codex | Conclui a desativacao repository-local restrita a contratos, registra regressao completa de frontend, gates focalizados/arquiteturais de backend, wiring Compose, rollback e excecoes globais externas ao recorte sem promover ambiente. |
| 1.0 | 2026-09-06 | Solicitante humano / Codex, materializacao | Autoriza e planeja a excecao temporaria, exata, reversivel e repository-local antes de qualquer edicao transversal de software. |
