---
document_id: "ONBOARD-CONVERSATION-AUDIT-OPERATIONS"
primary_nature: "Regra"
objective: "Orientar operação, migração, monitoramento, rollback e recuperação da Auditoria de Conversas."
scope: "Operações repo-local e de ambiente da Auditoria de Conversas, gates de API, retenção, backfill, provider, backup e restore."
non_objectives: "Não habilitar capability, executar operação destrutiva ou promover ambiente e release sem os gates e autorizações declarados."
owner: "Operações, Segurança e Omnichannel"
status: "Active"
date: "2026-09-09"
version: "1.80"
keywords: "onboarding, runbook, auditoria-conversacional, migracao, rollback, recovery"
related_files: "docs/product/requirements/REQ-00043-conversation-audit-data-governance.md, docs/api_contracts/conversation-audit-retention-policy-v1.openapi.yaml, docs/delivery/plans/implementation_plans/backend/IP-BE-8.1.6-conversation-audit-retention-policy-administration-api.md, docs/delivery/plans/implementation_plans/frontend/IP-FE-8.2.3-conversation-audit-retention-policy-tab.md, docs/delivery/reports/RPT-0006-conversation-audit-security-quality-audit.md, docs/architecture/data-retention-catalog.md"
code_references: "backend/, frontend/, infra/, docker-compose.yml, .github/workflows/"
principal_statement: "O runbook mantém operações e capabilities fail-closed e exige evidência separada para PostgreSQL, provider, backup, restore, runtime e release antes de promoção."
---

# Conversation Audit — Operations, Migration and Rollback Runbook

**Parent plan:** [TP-00008 — 008 — Chatbot Conversation Audit](../delivery/plans/TP-00008-chatbot-conversation-audit-implementation-plan.md)  
**Implementation plan:** [IP-BE-8.3.2-conversation-audit-operations-and-rollout — Operations and Rollout](../delivery/plans/implementation_plans/backend/IP-BE-8.3.2-conversation-audit-operations-and-rollout.md)  
**Requirement:** [REQ-00041](../product/requirements/REQ-00041-chatbot-conversation-audit.md) · [REQ-00043 current](../product/requirements/REQ-00043-conversation-audit-data-governance.md)
**Status:** `DEV activation/readiness and authenticated real-browser search verified; detail/reveal A×B, provider, HML, PRD and release gates remain open`
**Date:** 2026-09-09
**Version:** 1.80  

---

## Telegram: gate de produção

O webhook Telegram só pode ser habilitado depois que os três keyrings independentes e as seis variáveis `CONVERSATION_*` estiverem montados no backend HML/PRD. O Compose deve executar os init services e o backend deve depender deles; um container iniciado sem `/run/saas-secrets` pode retornar `503 PERSISTENCE_UNAVAILABLE` antes de gravar o inbound. Consulte [Configuração de webhooks omnichannel](omnichannel-webhook-configuration.md) para a sequência de registro, smoke e classificação de 429/503.

## 1. Purpose and Safety Boundary

This runbook defines the reversible, observable sequence for key provisioning, schema expansion, bounded identifier backfill, feature enablement, rollback and incident response. It is documentation for an implementation and future operation; it does not authorize a deployment or processing of real conversation data.

Local development and automated tests may use synthetic data. The explicitly authorized local
pilot in §4.0.2 may process only data already present in the current developer-owned local tenant
database; it does not authorize importing production data or copying any row/body into evidence.
HML/PRD remain blocked until all owners in section 3 sign off. Never paste identifiers, message
content, provider payloads, ciphertext, blind indexes or key material into tickets, logs, chat,
screenshots or evidence reports.

## 2. Configuration Contract

No secret has a repository default. Conversation-identifier and outbound-attempt keyrings are mounted read-only, owned by the runtime identity and configured by file reference. The outbound active key is independent; former root material may appear only as a bounded, read-only compatibility candidate while pre-hardening ledger rows can still be replayed.

| Property | Environment reference | Secret? | Safe default |
|---|---|:---:|---|
| `app.conversation-audit.enabled` | `APP_CONVERSATION_AUDIT_ENABLED` | No | `false` |
| `app.conversation-audit.api.enabled` | `APP_CONVERSATION_AUDIT_API_ENABLED` | No | `false` |
| `app.conversation-audit.api.allowed-tenant-ids` | `APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS` | No; UUID allowlist | empty/deny all |
| `app.conversation-audit.remote-identifier.legacy-read-enabled` | `APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED` | No | `false` |
| `app.conversation-audit.crypto.aes.active-key-id` | `CONVERSATION_AUDIT_AES_ACTIVE_KEY_ID` | No, identifier only | none |
| `app.conversation-audit.crypto.aes.keyring-file` | `CONVERSATION_AUDIT_AES_KEYRING_FILE` | Yes, file reference | none |
| `app.conversation-audit.crypto.hmac.active-key-id` | `CONVERSATION_AUDIT_HMAC_ACTIVE_KEY_ID` | No, identifier only | none |
| `app.conversation-audit.crypto.hmac.keyring-file` | `CONVERSATION_AUDIT_HMAC_KEYRING_FILE` | Yes, file reference | none |
| `app.conversation-audit.outbound-attempt-hmac.active-key-id` | `CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID` | No, identifier only | none/fail-closed sends |
| `app.conversation-audit.outbound-attempt-hmac.keyring-file` | `CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE` | Yes, file reference | none/fail-closed sends |
| `app.conversation-audit.backfill.enabled` | `APP_CONVERSATION_AUDIT_BACKFILL_ENABLED` | No | `false` |
| `app.conversation-audit.backfill.tenant-id` | `APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID` | No; UUID único | empty/fail-closed when backfill is enabled |
| `app.conversation-audit.backfill.batch-size` | `APP_CONVERSATION_AUDIT_BACKFILL_BATCH_SIZE` | No | `50`, range `1..50` |
| `app.conversation-audit.backfill.max-batches-per-run` | `APP_CONVERSATION_AUDIT_BACKFILL_MAX_BATCHES` | No | `1`, fixed at `1` |
| `app.conversation-audit.backfill.timeout-seconds` | `APP_CONVERSATION_AUDIT_BACKFILL_TIMEOUT_SECONDS` | No | `30`, range `1..300` |
| `app.conversation-audit.retention.enabled` | `APP_CONVERSATION_AUDIT_RETENTION_ENABLED` | No | `false`; no bootstrap/cache/job |
| `app.conversation-audit.retention.conversation-default-days` | `APP_CONVERSATION_AUDIT_RETENTION_CONVERSATION_DEFAULT_DAYS` | No | empty; explicit integer `1..180` when enabled; `>180` fails startup/readiness |
| `app.conversation-audit.retention.audit-access-default-days` | `APP_CONVERSATION_AUDIT_RETENTION_ACCESS_DEFAULT_DAYS` | No | empty; independent integer `1..180` when enabled; `>180` fails startup/readiness |
| `app.conversation-audit.retention.conversation-purge-enabled` | `APP_CONVERSATION_AUDIT_RETENTION_CONVERSATION_PURGE_ENABLED` | No | empty at application boundary; `.env.example` and Compose use `false` |
| `app.conversation-audit.retention.audit-access-purge-enabled` | `APP_CONVERSATION_AUDIT_RETENTION_ACCESS_PURGE_ENABLED` | No | empty at application boundary; `.env.example` and Compose use `false` |
| `app.conversation-audit.retention.legal-hold` | `APP_CONVERSATION_AUDIT_RETENTION_LEGAL_HOLD` | No | empty at application boundary; `.env.example` and Compose use `true` |
| `app.conversation-audit.retention.backup-restore-ready` | `APP_CONVERSATION_AUDIT_RETENTION_BACKUP_RESTORE_READY` | No | empty at application boundary; `.env.example` and Compose use `false` |
| `app.conversation-audit.retention.effective-from` | `APP_CONVERSATION_AUDIT_RETENTION_EFFECTIVE_FROM` | No | empty; explicit UTC instant when enabled |
| `app.conversation-audit.retention.cache-ttl` | `APP_CONVERSATION_AUDIT_RETENTION_CACHE_TTL` | No | `5m`, range `1s..15m` |
| `app.conversation-audit.retention.purge-batch-size` | `APP_CONVERSATION_AUDIT_RETENTION_PURGE_BATCH_SIZE` | No | `100`, range `1..500` |
| `app.conversation-audit.retention.max-batches-per-run` | `APP_CONVERSATION_AUDIT_RETENTION_MAX_BATCHES` | No | `10`, range `1..100` |
| `app.conversation-audit.retention.schedule-delay` | `APP_CONVERSATION_AUDIT_RETENTION_SCHEDULE_DELAY` | No | `1h`, positive and at most `24h` |
| `app.conversation-audit.retention.dry-run` | `APP_CONVERSATION_AUDIT_RETENTION_DRY_RUN` | No | `true` |
| `app.conversation-audit.retention.inbound-replay-max-age` | `APP_CONVERSATION_AUDIT_RETENTION_INBOUND_REPLAY_MAX_AGE` | No | `15m`, range `1m..12h` |
| `app.conversation-audit.retention.inbound-future-skew` | `APP_CONVERSATION_AUDIT_RETENTION_INBOUND_FUTURE_SKEW` | No | `2m`, range `0s..5m` |
| `app.conversation-audit.outbound-reconciliation.enabled` | `APP_CONVERSATION_AUDIT_OUTBOUND_RECONCILIATION_ENABLED` | No | `false` |
| `app.conversation-audit.outbound-reconciliation.batch-size` | `APP_CONVERSATION_AUDIT_OUTBOUND_RECONCILIATION_BATCH_SIZE` | No | `25`, max `100` |
| `app.conversation-audit.outbound-reconciliation.max-tenants-per-run` | `APP_CONVERSATION_AUDIT_OUTBOUND_RECONCILIATION_MAX_TENANTS` | No | `25`, max `100` |
| `app.conversation-audit.outbound-reconciliation.minimum-age` | `APP_CONVERSATION_AUDIT_OUTBOUND_RECONCILIATION_MINIMUM_AGE` | No | `5m`, `30s..24h` |
| `app.conversation-audit.outbound-reconciliation.lease-duration` | `APP_CONVERSATION_AUDIT_OUTBOUND_RECONCILIATION_LEASE_DURATION` | No | `2m`, `30s..30m` |
| `app.conversation-audit.outbound-reconciliation.max-attempts` | `APP_CONVERSATION_AUDIT_OUTBOUND_RECONCILIATION_MAX_ATTEMPTS` | No | `8`, max `50` |
| `app.conversation-audit.outbound-reconciliation.initial-backoff` | `APP_CONVERSATION_AUDIT_OUTBOUND_RECONCILIATION_INITIAL_BACKOFF` | No | `5m`, `30s..24h` |
| `app.conversation-audit.outbound-reconciliation.max-backoff` | `APP_CONVERSATION_AUDIT_OUTBOUND_RECONCILIATION_MAX_BACKOFF` | No | `6h`, initial backoff..`24h` |
| `app.conversation-audit.outbound-reconciliation.initial-delay-ms` | `APP_CONVERSATION_AUDIT_OUTBOUND_RECONCILIATION_INITIAL_DELAY_MS` | No | `60000`, `10000..3600000` |
| `app.conversation-audit.outbound-reconciliation.scheduler-delay-ms` | `APP_CONVERSATION_AUDIT_OUTBOUND_RECONCILIATION_SCHEDULER_DELAY_MS` | No | `60000`, `10000..3600000` |
| `app.conversation-audit.outbound-reconciliation.terminal-gap-detection-enabled` | `APP_CONVERSATION_AUDIT_OUTBOUND_RECONCILIATION_TERMINAL_GAP_DETECTION_ENABLED` | No | `false`; subordinate V41 switch |
| `app.conversation-audit.outbound-dispatch.lease-duration` | `APP_CONVERSATION_AUDIT_OUTBOUND_DISPATCH_LEASE_DURATION` | No | `5m`; must exceed max provider call + margin |
| `app.conversation-audit.outbound-dispatch.safety-margin` | `APP_CONVERSATION_AUDIT_OUTBOUND_DISPATCH_SAFETY_MARGIN` | No | `30s`; positive |
| `whatsapp.api.connect-timeout` | `WHATSAPP_API_CONNECT_TIMEOUT` | No | `5s`; positive hard timeout |
| `whatsapp.api.read-timeout` | `WHATSAPP_API_READ_TIMEOUT` | No | `10s`; positive hard timeout |
| `telegram.api.connect-timeout` | `TELEGRAM_API_CONNECT_TIMEOUT` | No | `5s`; positive hard timeout |
| `telegram.api.read-timeout` | `TELEGRAM_API_READ_TIMEOUT` | No | `10s`; positive hard timeout |
| `app.conversation-audit.webhook-executor.whatsapp.core-pool-size` | `APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_WHATSAPP_CORE_POOL_SIZE` | No | required by Compose; generated DEV default `2` |
| `app.conversation-audit.webhook-executor.whatsapp.max-pool-size` | `APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_WHATSAPP_MAX_POOL_SIZE` | No | required by Compose; generated DEV default `4` |
| `app.conversation-audit.webhook-executor.whatsapp.queue-capacity` | `APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_WHATSAPP_QUEUE_CAPACITY` | No | required by Compose; generated DEV default `100` |
| `app.conversation-audit.webhook-executor.telegram.core-pool-size` | `APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_TELEGRAM_CORE_POOL_SIZE` | No | required by Compose; generated DEV default `2` |
| `app.conversation-audit.webhook-executor.telegram.max-pool-size` | `APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_TELEGRAM_MAX_POOL_SIZE` | No | required by Compose; generated DEV default `4` |
| `app.conversation-audit.webhook-executor.telegram.queue-capacity` | `APP_CONVERSATION_AUDIT_WEBHOOK_EXECUTOR_TELEGRAM_QUEUE_CAPACITY` | No | required by Compose; generated DEV default `100` |

Each keyring is an independently managed JSON object containing a `keys` map from an opaque key ID to a base64-encoded 32-byte key. AES, identifier-HMAC and outbound-attempt active key IDs/material must be different. The active key encrypts/hashes new writes; old entries remain read-only during a documented rotation window. File content, checksums and paths are not emitted by the application.

Startup rules:

- data-protection feature disabled: application may start without conversation-audit keyrings;
- data-protection feature enabled: both keyrings and active IDs are mandatory and validated;
- API exposure is an independent, default-off gate; enabling it with an empty/invalid tenant allowlist fails startup, and it never bypasses role, impersonation or tenant-boundary checks;
- every API operation also requires data protection enabled and a durable readiness record for the effective tenant database; config flags never substitute the zero-risk counters;
- after V39, every API operation additionally requires the live tenant-scoped stale/missing-attestation check; a previously green durable record is never an evergreen pass;
- V39 also requires composite message-parent integrity. A message whose tenant/channel does not
  match its conversation stops the write/migration; no trigger/readiness path may ignore or repair
  that mismatch implicitly;
- unknown key ID, malformed file, weak/incorrect key length or equal AES/HMAC material fails startup;
- a partially configured outbound keyring fails startup; when both outbound properties are absent, outbound provider sends fail closed before ledger claim/provider invocation;
- every provider send client has explicit connect/read/total hard timeouts; startup/config validation rejects any setup where the V40 dispatch fence is not strictly greater than the maximum provider-call timeout plus the approved safety margin;
- the V41 terminal-gap detector has its own subordinate default-off switch. Enabling ordinary
  outbound reconciliation does not activate it; configuring the child `true` while its parent is
  `false` fails startup, never produces a hidden/no-op scan;
- backfill never activates merely because the feature is enabled;
- retention disabled creates no durable default and starts neither destructive purge worker;
  enabling it requires both day values, both purge flags, `legalHold`, `backupRestoreReady` and
  `effectiveFrom` explicitly. With the master off, only default bootstrap, publication/read of a
  ready policy from cache and destructive jobs are blocked; the bounded V89 normalization
  recovery routine and its cache-generation barrier remain available. Redis is a disposable
  read-through projection and never authorizes deletion;
- while the V89 normalization checkpoint is not `COMPLETE`, default bootstrap performs zero
  upsert, publication/read of a ready policy from cache and the administration API remain
  fail-closed, and both destructive jobs perform zero delete. The application may start only so
  the bounded recovery routine can advance its durable checkpoint and execute its strict opaque
  cache-generation rotation; this recovery path never enables either purge capability;
- conversation purge additionally requires `conversationPurgeEnabled=true`, `legalHold=false`
  and `backupRestoreReady=true`; access-event purge is independent and never deletes an
  `audit_log` row outside the exact REQ-00043 allowlist;
- audit-access purge has a fixed monotonic deadline of 20s per tenant and every statement is
  bounded to at most 5s. Expiry before/after a page or before evidence rolls back the complete raw
  platform transaction; no partial delete or false-success cursor may commit;
- policy `DELETE` is forbidden. The sole database exception is the V61 referential
  `ON DELETE CASCADE` from tenant offboarding, accepted only when the trigger proves a non-null
  `tenant_id`, nested trigger depth and absence of the parent tenant in the same transaction;
  default policy and the PII-free ledger are preserved. Manual/direct delete always fails closed;
- authenticated WhatsApp/Telegram envelopes capture immutable `authenticatedReceivedAt` at the
  authentication boundary and validate freshness there and again immediately before the first
  persistence/domain/provider effect. Events outside the bounded provider-time window are
  acknowledged with zero effect. Telegram message updates use the authenticated message date;
  callback queries have no official occurrence timestamp, are existing-conversation-only and are
  deduplicated by `update_id` plus `callback_query.id` rather than reusing the original message date;
- the incomplete-publication guard performs exactly two bounded, tenant-scoped reads: the first
  loads protected conversation IDs before `LIMIT` to prevent starvation; after candidates are
  locked, the second rechecks exact allowlisted serialized-event correlation immediately before
  the first delete. Overflow/truncation, malformed or incompatible JSON, count mismatch or any
  read failure rolls back the whole batch with zero deletion; payloads are never logged;
- legacy plaintext read is an explicit temporary migration flag and is forbidden after the zero-plaintext gate.

The seven conversation-audit switches (`enabled`, `api.enabled`, `legacy-read-enabled`,
`backfill.enabled`, `outbound-reconciliation.enabled` and subordinate
`outbound-reconciliation.terminal-gap-detection-enabled`, plus `retention.enabled`) are
independently default-off. They do
not disable the ordinary chatbot/provider send path or its outbound-attempt ledger. That path
independently requires the dedicated outbound keyring: missing configuration denies the provider
effect instead of falling back to raw identifiers, unkeyed digests or another application secret.

### 2.1 Super Admin Policy Administration under Impersonation (planned)

Somente uma identidade com `ROLE_SUPER_ADMIN` na role bruta e personificação ativa, explícita e
válida do tenant alvo configura a intenção na aba `Política de retenção` de `/audit`.
`ROLE_TENANT_ADMIN` nunca vê nem opera essa policy; quando combinada com
`ROLE_TENANT_AUDIT`, acessa apenas conversas. `ROLE_TENANT_AUDIT` permanece read-only. O contrato
planejado é GET/PUT `/api/v1/tenants/{tenantId}/settings/conversation-audit-retention` e POST
`.../settings/conversation-audit-retention/preview`; frontend e backend devem negar a operação sem
a dupla prova Super bruta + tenant personificado correspondente.

- ambos os períodos aceitam exclusivamente inteiros `1..180` no frontend, caso de uso, domínio e banco;
- o único toggle público escreve os dois purge flags; desligar preserva os períodos e impede novas unidades;
- ativar ou reduzir exige preview bounded/PII-free e token opaco de até `300s`; PUT usa
  `Policy-Version`/`If-Policy-Version` como precondição aplicativa e idempotência, não ETag HTTP;
- salvar nunca chama o purge; `scheduleDelay` define apenas quando uma unidade fica elegível para
  a fila assíncrona e não promete primeira tentativa, início, conclusão ou exclusão em até `24h`;
- master flag, dry-run, legal hold e backup/restore readiness são operacionais e não editáveis pela tela;
- V89 é metadata-only: instala os três constraints `NOT VALID`, que já rejeitam novas violações,
  não cria índice parcial de offender e cria o checkpoint sempre em `PENDING`, com
  `work_phase=NORMALIZE`, high-watermark/cursor nulos e `restart_from_beginning=true`, inclusive em
  banco fresh/vazio, sem scan global nem reescrita de policy legada;
- o normalizador application-level é a única rotina de recovery entre as migrations: em
  `NORMALIZE`, usa checkpoint/high-watermark/cursor duráveis, lease/CAS distribuído e páginas por
  PK/keyset bounded; somente prazo ofensor vira `180`, ambos os flags da row ficam `false`, e
  versão+ledger+cursor confirmam atomicamente. Ao concluir a fase, muda por CAS para `VERIFY`,
  recaptura o high-watermark, zera o cursor e revarre read-only pelas mesmas páginas PK/keyset, sem
  índice parcial. Offender residual reinicia `PENDING/NORMALIZE`; zero ao fim de `VERIFY` exige
  rotação CSPRNG/readback antes de `COMPLETE`. High-watermark `NULL` em tabela vazia é válido nas
  duas fases, mas não pula `NORMALIZE→VERIFY`, prova zero ou barreira;
- V90 pertence a release posterior e só valida os três constraints/remove os checks antigos após
  evidência ambiental de checkpoint `COMPLETE` e prova de zero offender. V89 e V90 não podem ser
  empacotadas na mesma Phase A.

Esse pipeline separa explicitamente recuperação e destruição: a rotina de normalização pode rodar
com a master retention desligada para recuperar o banco, inclusive executando a rotação estrita da
geração global de cache antes de `COMPLETE`, enquanto bootstrap, publicação/leitura de policy pronta
em cache, API de administração e jobs de purge continuam bloqueados até `COMPLETE`. Normalização
não agenda nem executa delete, e operador não substitui o checkpoint por SQL manual.

A geração global usa a chave `conversation-audit:retention-policy:v1:namespace`, sem TTL, e é um
token opaco de 32 bytes produzidos por CSPRNG, codificado em Base64URL sem padding com exatamente
43 caracteres. `GET` ausente ou malformado é cache miss e nunca inicializa a chave. No `PUT`, chave
ausente é inicializada com candidato aleatório via `SETNX` e o processo relê o vencedor; vencedor
malformado impede publicação e mantém fallback/miss até recovery. A barreira gera sempre outro
token, rejeita reutilização da geração corrente, executa `SET` estrito sem TTL e só avança após
reler e confirmar igualdade byte a byte com o valor proposto. Crash entre rotação e `COMPLETE`
repete a barreira com nova geração; geração anterior nunca é reutilizada intencionalmente.

O claim/takeover do checkpoint usa `dbNow` do PostgreSQL e só é elegível quando
`nextAttemptAt`/`next_attempt_at` é nulo ou `dbNow >= nextAttemptAt`; nenhum runner ignora o
backoff. Se `VERIFY` encontrar qualquer offender, a mesma transação grava `PENDING`,
`workPhase=NORMALIZE`, `restartFromBeginning=true`, `consecutiveFailureCount=0`,
`nextAttemptAt=null`, limpa high-watermark/cursor e libera a lease; o próximo claim recaptura o
limite, zera cursor, consome o flag para `false` e reinicia `RUNNING/NORMALIZE`. Não confundir esse
restart integral com restart do processo ou takeover de lease expirada: estes, assim como retry de
falha técnica, preservam `workPhase`, high-watermark e cursor. `PENDING` só admite `NORMALIZE` com
`restartFromBeginning=true`;
`COMPLETE` só admite `VERIFY` com `restartFromBeginning=false`; `RUNNING` e `FAILED` preservam a
fase corrente.

`failure_category` é obrigatória em `RUNNING` com backoff e em `FAILED`, aceita
somente `ROW_TIMEOUT`, `ROW_STORE_FAILURE`, `LEDGER_FAILURE`,
`VERIFICATION_FAILURE` ou `CACHE_BARRIER_FAILURE`, e permanece nula em `PENDING`,
`RUNNING` ativo e `COMPLETE`. Falha técnica define a categoria; claim ou progresso
committed a limpa. `last_progress_at` nasce no clock PostgreSQL da V89 e só muda
por progresso committed, nunca por claim/heartbeat/falha. Backend+SRE recebem
warning em `>=900s` e critical em `>=3600s` sem progresso para
`PENDING|RUNNING`; `FAILED` e `CACHE_BARRIER_FAILURE` alertam imediatamente. Os
testes de alerta usam exatamente `899/900/3599/3600s`.

O lifecycle é empacotado, não selecionável por configuração: o artefato Phase A contém
`META-INF/conversation-audit-retention-transition.properties` imutável com `phase=A`, não inclui
V90 e exige master e ambos os purge flags desligados antes de datasource/Flyway. Somente após
evidência `V89+COMPLETE+zero offender` e novo gate pode outro artefato alterar esse marker para
`phase=B` e incluir V90. Env, property remota e argumento de startup não podem sobrescrever o
marker. Se V90 falhar antes do commit e permanecer ausente do histórico Flyway, a Phase A pode ser
reimplantada com master e ambos os purge flags desligados. Depois que V90 constar como aplicada,
rollback binário Phase B→Phase A é proibido: manter artifact/schema B com master e ambos os purges
desligados e aplicar forward fix, sem editar o histórico.

Esta seção é contrato de operação futuro e não autoriza executar migrations, habilitar flags ou apagar dados.

## 3. Blocking Approvals

| Gate | Owner | Required evidence | Current state |
|---|---|---|:---:|
| conversation/message/offboarding retention and erasure | Product + Compliance/DPO | [REQ-00043 controls](../product/requirements/REQ-00043-conversation-audit-data-governance.md) | V62/V44 capability/fence/trigger source-implemented and focused-local green; PostgreSQL zero-skip pending, destructive switch off |
| access-audit retention and fail policy | Security + Compliance | exact allowlist from REQ-00043 | V62 capability/fence source-implemented and focused-local green; PostgreSQL zero-skip pending, route-admin audits preserved |
| AES/HMAC ownership, rotation and recovery | Security + SRE | named owner, vault path, recovery exercise | Technical/operational evidence pending — not a policy decision |
| backup and restore | DevOps/SRE + Dados + Segurança | REQ-00043 v1.26 Section 10 enforcement plus successful isolated restore drill | Repository enforcement local-green; live evidence RED and `backupRestoreReady=false` |
| representative performance dataset/SLO | SRE + QA | REQ-00043 dataset v1, PostgreSQL zero-skip report and sign-off | Dataset/SLO resolved; execution/sign-off technical gate RED |
| cross-tenant/DAST identities | Security + QA | tenant A/B and negative-role evidence | Technical execution fixture pending — not a policy decision |
| frontend layout | Product Owner / Client | explicit approval of [IP-FE-8.2.0-conversation-audit-wireframes — wireframe](../delivery/plans/implementation_plans/frontend/IP-FE-8.2.0-conversation-audit-wireframes.md) | Approved 2026-08-18; frontend local quality/release gates remain separate |
| explicit audit RBAC and persisted Keycloak state | Security + Backend + Frontend + SRE | `ROLE_TENANT_AUDIT` non-composite/sem heranca nos grafos realm+client, exact scopes with `fullScopeAllowed=false`, Service Account em allowlist minima, zero `tenant_id` direto/via client scopes, persisted-volume proof and fresh-session evidence | Software e hardening Keycloak v2.6.1 `IMPLEMENTED / STATICALLY VERIFIED LOCAL`; quatro gates shell verdes; volume/sessao vivo NOT EXECUTED por permissoes locais; HML/PRD prohibited |
| data-protection readiness | Backend + Security + SRE | V39 continuous/commit-safe invalidation plus composite parent integrity, one-row legacy CAS, targeted context sync and durable/live zero-risk proof per tenant database | V39 + JDBC correction IMPLEMENTED LOCAL / PARTIALLY EVIDENCED; bounded retry, five-risk readiness, PostgreSQL zero-skip and rollout remain RED |
| canonical outbound attempt and receipt route | Backend + Architecture + SRE | V40/V41 plus V60/V63 platform-first WhatsApp route, tenant-local revalidation and monotonic transition | SOURCE IMPLEMENTED / VERIFICATION PENDING; target 18-report PostgreSQL/CI execution, route provisioning, provider and fault injection remain RED |
| legacy Modulith pending publications | Backend + Security + DPO | REQ-00043 v1.26 two-read guard plus V44 serialization | Source/focused-local green; PostgreSQL/runtime verification pending, not a human decision |

No real-data migration, HML exposure or PRD enablement proceeds while any applicable gate is open.
Retention, anonymization, receipts and SLO values are no longer chosen in this runbook: their sole
normative source is [REQ-00043 v1.26](../product/requirements/REQ-00043-conversation-audit-data-governance.md).
After any restore, `/audit` remains closed until the current-policy purge and zero-expired
verification complete. The policy is resolved; DevOps/SRE remains accountable for evidence.

New producers do not rewrite pending Modulith publications. Inventory them using aggregate counts only and verify the REQ-00043 v1.26 two-read guard plus V44 lock/trigger before rollout; payload inspection/logging is forbidden and this remains a technical gate.

### 3.1 Retention activation and restore-safe sequence

1. Keep `retention.enabled=false`, both purge flags false, `legalHold=true`,
   `backupRestoreReady=false` and `dryRun=true`; before the Phase A binary, remove any legacy
   environment default above `180` or replace it with an approved value in `1..180`, otherwise
   startup validation correctly fails before recovery can run.
2. Verify the immutable packaged marker
   `META-INF/conversation-audit-retention-transition.properties` is exactly `phase=A`; reject any
   artifact or procedure that permits an env/property/argument override. Deploy that Phase A
   artifact containing V89 but not V90. Confirm the three `NOT VALID`
   constraints reject new violations and the singleton checkpoint always starts
   `PENDING/NORMALIZE`, with null high-watermark/cursor, for fresh/empty and non-empty databases
   alike; V89 creates no partial offender index and performs no global scan or policy-row change.
3. Start the application with the retention master still off and let only the bounded
   application-level normalizer claim the checkpoint lease. In `NORMALIZE`, observe bounded
   PK/keyset pages up to the captured high-watermark, durable cursor, row-level
   policy+version+ledger commits and restart/takeover behavior. At its end, require a CAS to
   `VERIFY`, a newly captured high-watermark, reset cursor and a second read-only bounded PK/keyset
   pass. A claim/takeover must obey `dbNow >= nextAttemptAt` whenever backoff is present; an
   offender found in `VERIFY` must reset to `PENDING/NORMALIZE`, clear high-watermark/cursor, set
   `restartFromBeginning=true`, failure count zero and `nextAttemptAt=null`. Do not enable bootstrap,
   ready-policy cache publication/read, administration writes or either destructive job; they
   remain fail-closed while the checkpoint is not `COMPLETE`. The normalizer's strict cache barrier
   rotates to a fresh 43-character CSPRNG Base64URL generation and confirms the exact winner; it
   remains enabled with the master off. On a fresh/empty policy table, the captured high-watermark
   is `NULL` in both phases; the runner must still perform `NORMALIZE→VERIFY`, prove zero offenders
   and rotate/read back the fresh generation before committing `COMPLETE`.
4. Require checkpoint `COMPLETE` plus a fresh zero-offender proof in every environment. Only after
   a separately reviewed Phase B gate may a later artifact change the immutable packaged marker to
   `phase=B` and add V90 to validate the three new constraints/remove the legacy `1..3650` checks.
   Never deploy V89 and V90 together to any database, including fresh/empty, or select a phase
   externally. If V90 stops startup and its transaction leaves V90 absent from Flyway history,
   verify that absence, turn master and both purge flags off, and only then redeploy Phase A to
   resume recovery. If V90 is already recorded as applied, never start Phase A; keep artifact/schema
   B with master and both purges off and deploy a forward fix without editing Flyway history.
5. Configure explicit day values and `effectiveFrom`; enable only the retention-policy bootstrap.
   Verify the durable default, PII-free mutation ledger, cache miss/fallback and resolved version
   without enabling either destructive flag.
6. Ative a policy somente pelo toggle público/caso de uso, que grava
   `auditAccessPurgeEnabled=true` e `conversationPurgeEnabled=true` juntos; mantenha
   `backupRestoreReady=false` e `dryRun=true`. Confirme contagens bounded dos dois
   datasets e que sentinelas fora das quatro ações de audit access permanecem
   intocadas. Nunca altere apenas um dos flags.
7. Com `backupRestoreReady=false`, conversas continuam bloqueadas mesmo com a
   policy ativa. Antes de qualquer `dryRun=false`, prove com Clock/statement lento
   que os deadlines de 20s/5s revertem a transação. Se o ensaio aprovado executar
   audit access, volte obrigatoriamente a `dryRun=true` antes de avançar o gate de
   backup. O relatório conversacional deve preservar attempts não terminais,
   fences/leases, publications incompletas e legal hold; dry-run nunca é evidência
   de exclusão.
8. DevOps/SRE may set `backupRestoreReady=true` only after every gate in REQ-00043
   v1.25 Section 10 has current evidence, including a successful isolated restore
   no older than 31 days and last verified upload younger than 24 hours. Ambos os
   purge flags já devem estar coerentemente ativos pela policy; retain `dryRun=true` for the approved
   observation window before changing it to false.
9. Observe only finite PII-free outcomes and ledgers. Any policy/cache/database error, policy
   version mismatch, unknown tenant, malformed publication or cardinality mismatch must yield zero
   committed deletion for the affected unit.
10. After any restore, immediately force `backupRestoreReady=false` and `dryRun=true`, rotate the
   Redis generation to a new never-reused token with strict `SET` plus exact readback, reapply
   migrations, revalidate the durable policy and run dry-run again. Never
   copy a pre-restore readiness assertion into the restored environment.
11. Never delete a policy row directly. Exercise tenant offboarding only with synthetic fixtures and
   prove the V61 trigger accepts solely the referential cascade with non-null tenant ID, nested
   trigger depth and missing parent in the same transaction; override disappears while the default
   and mutation ledger remain. Every spoofed/manual/direct variant must roll back.

#### 3.1.1 Backup-policy evidence sequence

1. Nomeie o `Backup Service Owner` no change corrente e obtenha revisão de Dados e
   Segurança; isso registra owners, não autoriza acesso por si só.
2. Confirme storage local cifrado, 7 gerações, timer
   `03:15`/`15:15 UTC` com jitter de até 15m e alerta 13h/18h/24h.
3. Confirme no bucket exclusivo em `sa-east-1`: Block Public Access integral, versionamento,
   Object Lock default `COMPLIANCE/35d`, lifecycle de expiração corrente em 45d
   e remoção permanente elegível após 1 dia noncurrent, uma única regra ativa sem
   transitions/delete-marker/data absoluta, e upload sem permissão de delete/bypass.
4. Confirme chave KMS customer-managed/simétrica/habilitada, rotação automática
   em no máximo 365d, recipient `age` vigente e custódias recuperáveis fora da VPS.
5. Execute `verify-only` semanal sobre `VersionId` exato. Mensalmente, restaure o
   bundle mais recente em dois clusters isolados, meça RPO/RTO e aplique a ordem
   pós-restore desta seção sem reabrir `/audit`.
6. Guarde por 400 dias somente instante, policy/tool versions, `VersionId`,
   contagens, duração, RPO/RTO, owners e outcome; nunca conteúdo, tenant ou remote
   identifiers. Destrua os bancos do drill ao final.
7. Qualquer divergência, drill vencido/falho, upload acima de 24h, rotação
   incompleta ou restore volta `backupRestoreReady` para `false` antes do próximo
   purge. Não existe grace period implícito.

Os testes AWS falsos e checks estáticos demonstram somente enforcement do
repositório. Evidência live exige autorização separada para o ambiente e revisão
dos owners; este runbook não concede essa autorização.

Marcadores anteriores ao contrato `conversation-audit-backup-v1` são preservados
e não contam entre as sete gerações elegíveis. Primeiro estime a capacidade local
e investigue cada aviso. Somente depois, execute o wrapper oficial, que já detém
o lock único, com
`./infra/scripts/deploy-production.sh backup --upload-offsite --adopt-legacy-markers`.
O uploader confere que o FD aponta ao mesmo inode de `deploy.lock` e adquire ou
confirma a exclusão; isso prova serialização, não a identidade do processo pai.
Esse modo não descobre objetos por listagem, usa os dois
`VersionId` registrados, exige `LastModified + 35d`, checksum, KMS e Object Lock
atuais e regrava o marcador atomicamente, sem gerar backup nem executar `s3 cp`.
Não chame o uploader diretamente nem edite `OFFSITE_UPLOAD` à mão. Falha ou
marcador parcial continua preservado e deve abrir alerta de capacidade. A
varredura continua para diagnosticar os demais candidatos, mas termina non-zero
se qualquer legado permanecer; sucessos anteriores não autorizam declarar a
manutenção concluída. O marcador falho deve permanecer byte-identical e fora do
pruning, e a invocação parcialmente falha não remove nenhuma geração local.
Marcador corrente apenas inelegível à revalidação continua preservado sem ser
contado como falha da adoção legada. Após rotação, o recipient antigo registrado
na geração continua válido para essa revalidação; a identidade antiga permanece
sob custódia conforme REQ-00043.

#### 3.1.2 Repository-only verification checkpoint — 2026-08-24

`upload-production-backup-test.sh`, `production-bundle-restore-drill-test.sh`,
`bash -n`, `systemd-analyze calendar` e `git diff --check` passaram. A matriz
falsa cobre região, BPA, Object Lock, lifecycle sobreposto, KMS/rotação,
LastModified/retenção, zero upload no preflight e adoção do legado; o restore
sintético cobriu três bancos app e dois Keycloak. `shellcheck` não está instalado.
Esses resultados não substituem o checklist live desta seção e não alteram
`backupRestoreReady=false`.

O checkpoint reaberto pela revisão de completude foi fechado no repositório: a
suíte cobre adoção mista com sucesso, `HeadObject` ausente e estrutura local
inválida; prova non-zero propagado pelo wrapper, zero `age`/`s3 cp`, marcadores
falhos byte-identical, zero pruning parcial e retry íntegro. A revisão independente
final passou sem achados repo-only. Evidência live continua obrigatória e
`backupRestoreReady=false` não muda.

### 3.2 WhatsApp receipt route — local verification and provisioning

This procedure documents the local source boundary; it records no completed runtime action. Keep
`availableEvidence.providerDeliveryReceipts=false`, the Audit API off and all destructive flags off
until the canonical 18-class PostgreSQL gate is green. Tenant V60 owns the globally unique platform
registry; tenant V61/V62/V63 and Omnichannel V43/V44 remain part of the same migration/retention verification
boundary.

1. Apply Flyway in the authorized synthetic/local environment and prove V60, V61 and Omnichannel
   V43 without checksum edits or skips.
2. Before provisioning, verify the tenant is active and that its dedicated database has exactly the
   active WhatsApp phone/account pair. Never discover a tenant by scanning tenant databases or by
   choosing the first match.
3. Using a fresh, authorized `SUPER_ADMIN` session, call
   `POST /api/v1/admin/conversation-audit/whatsapp-receipt-routes` with the tenant UUID, WABA ID and
   phone-number ID through the protected request body. Do not place those values in URL, shell
   history, logs, metrics, screenshots or evidence. The service must revalidate the tenant-local
   configuration before committing the platform route; conflict with another tenant fails closed.
4. Record only PII-free outcome, correlation/error ID and returned opaque `routeId`; do not record
   WABA/phone identifiers. Repeat idempotently and prove the same active route, then execute
   `WhatsAppReceiptRoutePostgresTest` as part of the full 18-class gate.
5. Exercise authenticated synthetic `statuses` through the webhook and require platform-first
   lookup, tenant context entry, local account/provider-message/conversation/message revalidation,
   idempotency and monotonic transitions under `WhatsAppReceiptTransitionPostgresTest`. Missing,
   inactive, ambiguous or mismatched routes must produce zero transition and capability `false`.
6. To retire the binding, call
   `POST /api/v1/admin/conversation-audit/whatsapp-receipt-routes/deactivate` with only the opaque
   `routeId`, then prove late/duplicate receipts cannot transition tenant data. Never hard-delete or
   rewrite V60 history as an operational shortcut.

Provisioning source existence, controller tests or a `2xx` response do not enable the capability.
Provider fixtures/authenticity, PostgreSQL zero-skip, operational reconciliation and release gates
must also pass; until then receipts/runtime/release remain RED.

## 4. Expand and Backfill Procedure

### 4.0 Corrective Pre-remediation Freeze — V39/V41 (2026-08-19)

V39/V40/V41 executable artifacts now exist locally after their earlier docs-first decisions. Later
reviews found additional V39 integrity/compatible-writer gaps and, after V41 implementation, a
`created_at` grace error, missing trigger association index, child-off completion gap and
non-owner digest mutation gap. Both corrective worksets are **RED/not implemented** at this
checkpoint. The V41 focused run (`105` total: `102` passes + `3` JPA fixture failures) and the later
isolated fixture-fixed JPA `13/13` are historical/pre-remediation only. HML/PRD, real-data backfill,
API exposure and outbound reconciliation/detection remain blocked until corrections, the official
ten-report PostgreSQL/CI gate and independent provider/fault-injection evidence exist. Migrations
with applied checksums remain immutable.

#### 4.0.1 Post-remediation Local State — 2026-08-19

The freeze above is preserved as lifecycle history. The corrective V39/V41 work is now
**IMPLEMENTED LOCAL / PARTIALLY EVIDENCED**, never release-ready. Compile passed at `862`
production/`282` test sources; the focused V39/V41 selector passed `110/110`, and the directed
LLM+JPA fixture selector passed `21/21`, all with zero failures/errors/skips. The official
ten-class PostgreSQL selector discovered `45` tests and skipped all `45`; an escalated/unsandboxed
retry still failed on `/var/run/docker.sock` with `BindException: Permission denied`. Therefore the
database gate is **RED / NOT EXECUTED**, not merely untried. The ten-report CI wiring is aligned
statically but has not run. Architecture/full remain RED on the two known `shared → fiscal`
Modulith failures, and all six switches remain default-off.

#### 4.0.2 Docs-first Local Pilot Freeze — 2026-08-21

The requester explicitly authorized activation, bounded backfill and readiness **only** for the
current Docker Compose development environment and one local pilot tenant. This is a narrow local
execution exception to the external-rollout stop in §4.1.9; it does not close any §3 approval,
does not authorize HML/PRD, remote hosts, provider effects, production imports, a second tenant or
release promotion. At the time of this freeze, every item below is **NOT EXECUTED / PENDING**.

Pre-runtime compatibility correction:

- the frontend schema used only to build `{tenantId}` in the audit API path accepts canonical
  PostgreSQL UUID text: exactly `8-4-4-4-12` hexadecimal digits with hyphens, case-insensitive on
  input and normalized to lowercase;
- this permits the existing synthetic/local legacy tenant whose textual UUID does not carry an RFC
  version nibble. Its concrete value must not be written to docs, reports, test names or artifacts;
- whitespace, braces, compact form, wrong segment length and non-hex characters fail before fetch;
- `conversationId`, `messageId`, `errorId`, correlation IDs and all response/resource IDs remain on
  their existing strict contract schemas. The exception is not a shared/general `uuidSchema`;
- focused tests must prove that a synthetic legacy tenant reaches the expected `POST`, lowercase is
  used in the path, malformed tenant input performs zero fetch, and strict IDs still reject their
  non-contract forms. A passing mock response alone is insufficient.

Required execution sequence:

1. Capture only the initial six boolean switch states and aggregate service health. Force
   `APP_CONVERSATION_AUDIT_API_ENABLED=false`, an empty
   `APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS`, backfill/reconciliation/detector `false` and do not
   trigger any webhook or provider send.
2. Implement and run the tenant-path compatibility tests above before using `/audit` as smoke
   evidence. A generic unavailable card without an observed request is a failure, not a backend
   result.
3. Resolve exactly one pilot tenant from the authenticated local context/platform database. Use its
   UUID only in ephemeral `APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID` runtime configuration; do not
   copy it into Git, command transcripts, screenshots or evidence. Backfill habilitado sem alvo
   canônico/registrado deve abortar antes de qualquer datasource; a allowlist da API permanece
   independente e vazia nesta fase.
4. Before migration, writer or backfill changes, create an encrypted local backup outside every Git
   worktree on storage readable only by the current owner. Verify directory mode `0700`, file mode
   `0600` and a successful restore into an isolated temporary database. Record only timestamp,
   success/failure and aggregate schema/migration counts; never record rows, dump path or checksum.
5. Create three independent 32-byte key materials and opaque active IDs: identifier AES,
   identifier blind-index HMAC and outbound-attempt HMAC. Store each keyring outside Git under an
   owner-only directory (`0700`) and file (`0600`), mount read-only and verify the three materials
   differ without printing material, digest, checksum or effective path.
6. Start the compatible application with `APP_CONVERSATION_AUDIT_ENABLED=true`,
   `APP_CONVERSATION_AUDIT_API_ENABLED=false`, allowlist empty, backfill/reconciliation/detector
   `false`. Set `APP_CONVERSATION_AUDIT_LEGACY_READ_ENABLED=true` only when the bounded migration
   window actually contains eligible plaintext; otherwise keep it false.
7. Verify startup/Flyway/health and the current migration policy without amending an applied
   checksum. Any migration, composite-integrity, keyring or startup validation error aborts while
   API remains off.
8. Enable only the identifier backfill with
   `APP_CONVERSATION_AUDIT_BACKFILL_BATCH_SIZE<=50` and
   `APP_CONVERSATION_AUDIT_BACKFILL_MAX_BATCHES=1`, target/timeout válidos e o
   `docker-compose.conversation-audit-backfill.yml` aplicado por último. Antes do start, prove na
   configuração renderizada que `services.backend.restart` é `"no"`. Execute uma invocação
   explícita por vez; não use o Compose normal durante a janela.
   After each invocation observe aggregate counters only; `failed>0`, timeout, increasing risk,
   unbounded selection or ciphertext rewrite aborts.
9. Repeat bounded invocations until an independent full-tenant verification reports separately
   `eligible_plaintext=0`, `missing_or_invalid_hash=0`, `unknown_key_id=0`,
   `missing_or_stale_attestation=0` and `pending_activity=0`, with `failed=0`. Neither
   `completed=true` nor a lone `remaining=0` is sufficient.
10. After plaintext risk reaches zero, set only legacy read to `false` and keep the single-tenant
    backfill enabled at `50 x 1`. Restart/invoke until independent verification persists the same
    five zeros, `failed=0`, `verification_completed=true` and `ready=true` under the new definitive
    fingerprint. Readiness from the legacy-enabled fingerprint is invalid and cannot be promoted.
11. Only then set backfill to `false`, restart with API still off and require the durable UTC
    readiness plus green live stale-marker check to remain valid.
12. Set `APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS` to exactly the one pilot UUID and only then set
    `APP_CONVERSATION_AUDIT_API_ENABLED=true`. Keep outbound reconciliation and its V41 detector
    false. No flag bypasses role, impersonation or tenant boundary.
13. Run backend-real smoke through the authenticated local frontend with MSW off. Observe that the
    search `POST` occurs and verify only HTTP status, `Cache-Control: no-store`, safe error shape,
    contract validation and aggregate result count. Detail/timeline/reveal may be exercised without
    persisting or printing their bodies. A synthetic non-allowlisted tenant must be denied before
    business query; malformed tenant input must produce zero fetch.
14. Keep no screenshot, video, trace, HAR, terminal body, database row or log excerpt containing a
    tenant/user/conversation/message ID, remote identifier, message content, provider data,
    ciphertext or key material. Evidence is limited to aggregate counters and PASS/FAIL commands.

Abort and rollback for this local pilot:

1. At any failure, first set `APP_CONVERSATION_AUDIT_API_ENABLED=false` and empty the allowlist;
   verify the read API is unavailable before any other action.
2. Disable backfill. Let an in-flight transaction commit atomically or roll back; never interrupt
   it with ad-hoc SQL and never clear readiness/attestation markers manually.
3. Keep protection enabled, legacy read disabled after zero-risk, and retain every read key needed
   by ciphertext. Keep additive migrations in place; no down migration or plaintext restoration is
   permitted.
4. Restore the verified backup only after stopping the affected local application and only for a
   demonstrated local data-integrity failure. Restoration does not authorize reuse of stale
   readiness; rerun the whole gate before re-enablement.
5. Outbound reconciliation/detector remain false throughout. This plan never authorizes a provider
   lookup or send.

Pre-execution evidence ledger:

| Local item | State at freeze |
|---|:---:|
| tenant-path compatibility code/tests | `PENDING / NOT EXECUTED` |
| encrypted backup and isolated restore | `NOT EXECUTED` |
| three owner-only keyrings and read-only mounts | `NOT EXECUTED` |
| feature-on/API-off startup and Flyway/health | `NOT EXECUTED` |
| bounded legacy-read/backfill | `NOT EXECUTED` |
| five-risk independent readiness and live recheck | `NOT EXECUTED` |
| legacy/backfill off, single-tenant allowlist and API on | `NOT EXECUTED` |
| MSW-off smoke without content/PII | `NOT EXECUTED` |
| rollback verification | `NOT EXECUTED` |

Post-freeze local evidence, sem substituir a tabela historica acima:

| Local item | Current state |
|---|:---:|
| tenant-path compatibility code/tests | `PASS LOCAL / FOCUSED 21/21` |
| encrypted backup and isolated restore | `PASS LOCAL / CONTENT-FREE EVIDENCE` |
| three owner-only keyrings and read-only mounts | `PASS LOCAL` |
| feature-on/API-off startup and Flyway/health | `PASS LOCAL BEFORE INTERRUPTED BATCH` |
| JDBC temporal binding remediation | `IMPLEMENTED LOCAL`; PostgreSQL retry not executed |
| bounded legacy-read/backfill retry | `NOT EXECUTED / BLOCKED BY LOCAL HOST ACCESS` |
| five-risk independent readiness and live recheck | `NOT EXECUTED`; readiness false and API off |
| single-tenant allowlist, API on and authenticated smoke | `NOT EXECUTED`; allowlist empty/API off |
| HML/PRD/release | `NOT AUTHORIZED / NOT EXECUTED / RED` |

#### 4.0.3 Docs-first RBAC and Keycloak Freeze - 2026-08-22

Antes de qualquer JSON, script, codigo de autorizacao ou mutacao no Keycloak vivo, fica congelada a
extensao estrita `ROLE_TENANT_AUDIT`. Ela substitui, para esta superficie, o acesso implicito por
perfil administrativo generico: um usuario tenant precisa da role explicita; o Super Admin precisa
ter `ROLE_SUPER_ADMIN` e `ROLE_TENANT_AUDIT` em token novo e ainda selecionar um tenant por
impersonacao validada. A role jamais cria `TenantContext` sozinha.

O bootstrap novo deve definir role e role scope nos oito artefatos, sem excecao:

1. `infra/keycloak/provision/dev.sh`;
2. `historical: infra/keycloak/dev/saas-bpfarias-realm.json`;
3. `historical: infra/keycloak/hml/saas-admin-realm.json`;
4. `historical: infra/keycloak/hml/saas-bpfarias-realm.json`;
5. `historical: infra/keycloak/prd/saas-admin-realm.json`;
6. `historical: infra/keycloak/prd/saas-bpfarias-realm.json`;
7. `infra/keycloak/realm-template.json`;
8. `backend/src/main/resources/keycloak/realm-template.json`.

`saas-frontend-spa` deve conservar `fullScopeAllowed=false`. O realm administrativo explicita
somente `ROLE_SUPER_ADMIN` e `ROLE_TENANT_AUDIT`; realms tenant explicitam as quatro roles
tenant/fiscal existentes mais `ROLE_TENANT_AUDIT`. Somente o export administrativo DEV atribui a
nova role ao usuario exato `djmarcellopedrosa@gmail.com`, preservando `ROLE_SUPER_ADMIN`; HML, PRD e
templates nao semeiam usuario nem role mapping humano.

Os JSONs nao migram o PostgreSQL do Keycloak. Para o volume local ja persistido, a operacao futura
deve reutilizar recovery temporario e reconciliar pela Admin API de forma idempotente e fail-closed:

1. preservar backup e parar todos os nodes Keycloak conforme ADR-0018;
2. criar a role somente se ausente e conferir exatamente um SPA por realm;
3. adicionar o scope esperado sem habilitar Full Scope ou remover roles fora do alvo da operacao;
4. localizar exatamente um usuario DEV pelo username e e-mail aprovados, preservar
   `ROLE_SUPER_ADMIN` e adicionar `ROLE_TENANT_AUDIT` sem duplicacao;
5. validar o estado final, remover toda identidade temporaria e manter a Service Account permanente
   sem `manage-realm` adicional;
6. invalidar as sessoes do usuario, autenticar novamente e verificar token com ambas as roles,
   issuer/audience validos e ausencia de `tenant_id`;
7. provar que `/audit` nega Super Admin sem role de auditoria, nega a role sem impersonacao e aceita
   somente role explicita mais contexto tenant valido, sem registrar JWT, cookies ou identificadores.

HML/PRD nao participam deste ciclo local: aplicar os JSONs versionados, executar reconciliacao,
atribuir usuarios, invalidar sessoes ou testar login nesses ambientes exige change e aprovacao
separados. Estado no momento deste freeze:

| Item RBAC/Keycloak | Estado em 2026-08-22 |
|---|:---:|
| oito exports/templates | `NOT IMPLEMENTED` |
| validador estatico e testes de provisioning/token | `NOT IMPLEMENTED / NOT EXECUTED` |
| reconciliacao idempotente do volume local persistido | `NOT IMPLEMENTED / NOT EXECUTED` |
| atribuicao ao superadmin no Keycloak local vivo | `NOT EXECUTED` |
| invalidacao, novo login e prova de token/acesso | `NOT EXECUTED` |
| qualquer operacao HML/PRD | `NOT AUTHORIZED / NOT EXECUTED` |

#### 4.0.4 Post-freeze Local RBAC Reconciliation - 2026-08-22

O freeze da Section 4.0.3 permanece historico. Backend e frontend implementaram a matriz Audit e
passaram respectivamente `117/117` em snapshot isolado sem Docker e `90/90`; TypeScript global,
build de `39` rotas e lint/Prettier focal tambem passaram. Os oito artefatos Keycloak, o validador,
a reconciliacao versionada, a allowlist exata e o gerador/contrato do secret DEV owner-only foram
implementados. A inclusao no `.env.dev.local` real permanece bloqueada com o acesso ao host. O
validador de realms e dois testes shell passaram.

Essa prova e estatica/local. A reconciliacao do volume persistido, atribuicao no usuario vivo,
invalidacao de sessao, login/token novo e smoke autenticado permanecem **NOT EXECUTED / BLOCKED BY
LOCAL HOST ACCESS**. A API de auditoria continua desligada. Nenhum ambiente HML/PRD foi acessado ou
alterado.

#### 4.0.5 Docs-first Keycloak Reconciliation Hardening Freeze - 2026-08-22

Antes de novo patch de script/validator, o proximo ciclo deve cumprir cumulativamente:

1. `ROLE_TENANT_AUDIT` deve ser realm role `composite=false`, nao incluir
   `ROLE_TENANT_ADMIN`/`ROLE_SUPER_ADMIN` e nao ser herdada por composites dessas roles. O
   reconciliador inspeciona os dois sentidos, remove apenas drift inequivoco dentro da allowlist e
   falha fechado diante de ambiguidade, erro ou aresta residual; a verificacao final repete o gate;
2. a Service Account permanente deve ser reconciliada mesmo quando `client_credentials` ja
   funciona. Privilegios efetivos terminam exatamente em `create-realm` no master e
   `manage-users`, `query-users`, `view-users`, `view-realm` somente nos realms estaticos geridos.
   Excedentes sao revogados; heranca/ambiguidade nao removivel aborta. Token valido nao permite
   early-success;
3. no realm administrativo, a verificacao de `tenant_id` percorre mappers diretos e mappers
   efetivos de client scopes default/optional, inclusive scopes herdados/atribuidos. Origem
   inequivocamente gerida e removida; scope compartilhado/ambiguo ou claim residual falha fechado;
4. o estado final e reconsultado antes de limpar recovery identities ou concluir a migracao, sem
   imprimir secrets, tokens ou representacoes sensiveis.

Os passes do validator e dos dois testes shell em §4.0.4 permanecem evidencia historica do
contrato anterior e ainda nao cobrem este hardening. §4.0.5 esta **FROZEN / PENDING IMPLEMENTATION
/ PENDING EVIDENCE**. Volume/sessao, backend-real, HML/PRD e release continuam NOT EXECUTED/RED;
a API permanece off.

#### 4.0.6 Docs-first Single-tenant Backfill Target Freeze - 2026-08-22

Antes de retomar o lote interrompido, a revisão confirmou que o runner existente percorre todos os
datasources tenant registrados, contrariando a autorização de um único piloto em §4.0.2. Fica
obrigatória a propriedade `APP_CONVERSATION_AUDIT_BACKFILL_TENANT_ID`, com exatamente um UUID
canônico/registrado; o runner resolve somente esse datasource e nunca usa iteração global. Valor
ausente, inválido ou não registrado falha antes de qualquer efeito e sem incluir o UUID em
erro/log. A allowlist da API continua independente/vazia até readiness.

Este controle está **FROZEN / PENDING IMPLEMENTATION / PENDING EVIDENCE**. Enquanto não houver
teste A/B de zero interação fora do alvo, backfill/readiness não podem ser executados.

#### 4.0.7 Docs-first Final-fingerprint Readiness Freeze - 2026-08-22

O fingerprint muda quando legacy-read muda de `true` para `false`, e o runner de verificação não é
criado com backfill desligado. Logo é proibido desligar legacy e backfill no mesmo passo. Após
plaintext zero, desliga-se apenas legacy; tenant alvo e backfill `50 x 1` permanecem ativos até
`verification_completed=true`, `ready=true`, cinco riscos zero e `failed=0` no fingerprint novo.
Só então backfill desliga, ocorre restart/API-off e o live recheck deve permanecer verde.

Este gate está **FROZEN / PENDING RUNTIME EVIDENCE** e não autoriza alterar/remover o componente
legacy do fingerprint.

#### 4.0.8 Docs-first Supervised Restart and Timeout Freeze - 2026-08-22

Durante a janela, o override versionado
`docker-compose.conversation-audit-backfill.yml` é obrigatório e deve ser o último arquivo Compose;
sua configuração efetiva fixa `services.backend.restart: "no"`. Cada invocação exige comando
explícito. Falha/timeout não pode gerar restart automático; a policy normal só é restaurada depois
de `APP_CONVERSATION_AUDIT_BACKFILL_ENABLED=false` e nova validação.

O processor usa `APP_CONVERSATION_AUDIT_BACKFILL_TIMEOUT_SECONDS` (`1..300`, default `30`) em
statement e transação. Exceder o limite, inclusive aguardando lock, reverte lote/checkpoint/readiness
e exige análise antes de retry. `/actuator/health/readiness` é apenas saúde geral; readiness Audit
continua sendo o registro durável do fingerprint definitivo mais cinco zeros e live recheck.

Estado: **FROZEN / PENDING IMPLEMENTATION / PENDING EVIDENCE** (`AC-AUD-058–059`).

#### 4.0.9 Docs-first Keycloak v2.6 Corrective Freeze - 2026-08-22

Antes de retomar a migracao do volume Keycloak, nenhum password/secret pode aparecer no `argv`
do host ou do container. Toda paginacao de clients, users e composites deve detectar pagina
repetida, duplicacao, ausencia de progresso e limite excedido. O init normal precisa provar o
conjunto efetivo exato antes de declarar ready; token funcional isolado nao basta. Mapper ou
client scope dedicado e inequivocamente gerido pode ser reconciliado; origem compartilhada,
desconhecida ou claim residual aborta sem remocao ampla.

Estado: **FROZEN / PENDING IMPLEMENTATION / PENDING EVIDENCE**. Os testes v2.5 nao autorizam
volume/sessao. A API e o backfill permanecem desligados.

#### 4.0.10 Post-freeze Local Backfill Guard Reconciliation - 2026-08-22

O runner agora exige target canonico/registrado, resolve somente seu datasource e nao itera os
demais tenants. Timeout `1..300s` cobre statement e transacao; falha reverte. O override
`docker-compose.conversation-audit-backfill.yml` fixa `backend.restart: "no"` e deve continuar
sendo aplicado por ultimo em cada lote supervisionado.

Evidencia: `32/32` testes, shell de contrato e Compose base+DEV+override passaram, incluindo A
selecionado/B zero interacao e ausencia de UUID em erro/log. Isso nao executa o lote PostgreSQL,
legacy-off/fingerprint final, readiness nem API. A operacao continua bloqueada pelo acesso local
ao Docker/arquivo owner-only; o hardening Keycloak v2.6 estatico nao substitui esses gates vivos.

#### 4.0.11 Post-freeze Static Keycloak v2.6 Reconciliation - 2026-08-22

Os estados `PENDING IMPLEMENTATION/EVIDENCE` das Sections 4.0.5 e 4.0.9 permanecem como fatos dos
respectivos freezes. Depois deles, o hardening cumulativo foi implementado nos scripts versionados:
zero password/secret em `argv` host/container, paginacao administrativa bounded/fail-closed,
prova exata dos privilegios efetivos antes do init ready, Audit non-composite/sem heranca admin,
Service Account least-privilege e remocao de mapper/scope somente para origem inequivocamente
gerida.

Estao verdes os tres gates shell estaticos:

- `infra/scripts/tests/keycloak-bootstrap-hardening-test.sh`;
- `infra/keycloak/bootstrap/validate-realm-token-contracts.sh`;
- `infra/scripts/tests/start-dev-bot-outbound-keyring-test.sh`.

Classificacao: **IMPLEMENTED / STATICALLY VERIFIED LOCAL**. A migracao/reconciliacao no volume
persistido, atribuicao viva ao superadmin DEV, invalidacao de sessao, login/token novos e smoke
autenticado permanecem **NOT EXECUTED / BLOCKED BY LOCAL PERMISSIONS**. O mesmo bloqueio impede o
lote backfill e a prova readiness; API e allowlist continuam fechadas. HML/PRD nao foram acessados.

#### 4.0.12 Post-freeze Structural Keycloak v2.6.1 Reconciliation - 2026-08-22

Uma revisão independente adicional encontrou e fechou os riscos residuais antes do runtime. O
estado versionado agora diferencia first bootstrap de client persistido inacessível/duplicado,
prova ownership e fingerprint não interativo do client técnico, inventaria estruturalmente
recovery users/clients e valida o grafo completo de realm roles e client roles para impedir
qualquer herança direta ou transitiva de Audit. Mapper `tenant_id` direto ou via client scope só
entra no plano de remoção quando o fingerprint estrutural gerido é exato; origem customizada,
desconhecida, compartilhada ou residual aborta antes do primeiro delete.

`validate-keycloak-runtime-json.sh` é Bash puro, bounded e fail-closed para token, client, mapper e
recovery page. O arquivo é montado read-only em `keycloak` e `keycloak-provisioning-init`; campos
duplicados, decoys aninhados/escapados, trailing data, tamanho/profundidade/página excedidos ou
arquivo ausente abortam. Sessões `kcadm` são owner-only e `INT`/`TERM` encerram com `130`/`143`,
sem mutação posterior.

Passaram: validador estrutural `38/38`, hardening adversarial, contratos dos realms,
start-dev/keyring, sintaxe dos scripts e Compose base+DEV com valores sintéticos. O CI versionado
executa os dois novos gates estruturais. Classificação: **IMPLEMENTED / STATICALLY VERIFIED
LOCAL**. Volume persistido, atribuição viva, sessão/token novos, backfill/readiness e smoke seguem
**NOT EXECUTED / BLOCKED BY LOCAL HOST PERMISSIONS**; API off, HML/PRD intocados.

#### 4.0.13 Current Local Host Prerequisite - 2026-08-22

Este checkpoint preserva o diagnóstico histórico: o daemon e os proxies locais
respondiam, mas o processo do desenvolvedor não possuía o grupo do socket e a
receita manual surgiu tarde, depois da tentativa de operação. Os códigos HTTP
observados não provavam autenticação nem readiness Audit.

**Superseded em 2026-08-25:** não executar a sequência hardcoded de `chown`,
`chmod` e `usermod` que constava nesta seção. O acesso Docker agora pertence ao
[bootstrap canônico do host local](local-development-host-bootstrap.md), anterior
ao primeiro Compose e independente de username/path pessoal. Ele valida o usuário
explicitamente autorizado, preserva grupos, comprova uma sessão nova e pode
continuar o startup sem comando corretivo posterior.

Permanece proibido usar `chmod 666`, alterar owner/ACL do socket, executar a stack
inteira como root, usar `sudo -E`/`sudo docker compose` ou copiar/imprimir
`.env.dev.local`. Ownership de arquivo owner-only é um incidente separado e nunca
deve ser corrigido por uma receita com path/usuário fixos no runbook Audit.

#### 4.0.14 Docs-first fresh/existing DEV executor bootstrap freeze — 2026-08-23

Antes de alterar `start-dev-bot.sh`, fica registrado que o Compose exige explicitamente as seis
variáveis dos executores inbound dedicados, mas o gerador atual não as inclui. Um bootstrap novo ou
um `.env.dev.local` legado sem essas entradas pode falhar na interpolação antes de iniciar o stack.

O gerador deve gravar `core=2`, `max=4` e `queue=100` para WhatsApp e Telegram em arquivo novo. Em
arquivo regular existente, deve preservar valores não vazios do operador, preencher somente chave
ausente/vazia, falhar em duplicidade, atualizar atomicamente e manter modo `0600`, sem seguir
symlink nem imprimir conteúdo. `--prepare-env-only` deve concluir esse reparo. A regressão exige os
dois caminhos (fresh/existing), uma ocorrência não vazia por chave e o vínculo exato com os seis
`:?required` do Compose.

Estado: **FROZEN / PENDING IMPLEMENTATION / PENDING EVIDENCE**. Não executar Compose/runtime para
classificar este freeze como concluído; API e flags destrutivas permanecem off.

#### 4.0.15 Post-freeze fresh/existing DEV executor bootstrap evidence — 2026-08-23

O gerador agora materializa `2/4/100` para ambos os canais e o repair executa antes de
`--prepare-env-only`. Em arquivo existente regular, valores não vazios são preservados; ausente,
vazio sem aspas ou vazio quoted é reparado por temp+rename único. Duplicidade ou symlink/non-regular
falha sem mutação de conteúdo. O arquivo termina `0600` e o output não contém valores.

`infra/scripts/tests/start-dev-bot-outbound-keyring-test.sh` passou cobrindo fresh/existing,
preservação/reparo, duplicidade fail-closed e vínculo às seis entradas Compose `:?required`;
`bash -n` também passou. Isso é evidência shell local, não Compose/runtime vivo.

#### 4.0.16 Docs-first DEV Audit activation correction — 2026-09-03

O `AUD-404-NOT_FOUND` observado na busca de `/audit` não é falha de roteamento: o mesmo `POST
/api/v1/tenants/{tenantId}/chatbot/audit/conversations/search` existe no frontend, OpenAPI e
controller. O filtro o devolve quando a API está off ou o tenant não está na allowlist. O startup
DEV gera keyrings e consome um overlay opcional, mas não possui produtor versionado para concluir
backfill/readiness e gravar o estado final.

Antes de qualquer patch executável, o [IP-BE-8.3.2.1-conversation-audit-local-activation-and-search-smoke](../delivery/plans/implementation_plans/backend/IP-BE-8.3.2.1-conversation-audit-local-activation-and-search-smoke.md)
congela a correção: o startup local resolve exatamente um tenant provisionado sem hardcode/output,
fecha API e allowlist, comprova dump cifrado e restore isolado, executa somente invocações `50 × 1`
com override `restart: "no"`, passa de legacy-on para o fingerprint legacy-off, exige os cinco
riscos em zero e readiness durável, e somente então grava overlay regular `0600`, allowlist
unitária e API on. Falha ou ausência de progresso restaura primeiro API off/allowlist vazia.

O coordenador será automático somente no `start-dev-bot.sh`; HML/PRD, providers, retenção
destrutiva e defaults globais permanecem intocados. Estado neste registro: **DOCUMENTED BEFORE
IMPLEMENTATION / IMPLEMENTATION PENDING / RUNTIME NOT EXECUTED**.

#### 4.0.17 Post-freeze DEV Audit activation evidence — 2026-09-03

O `start-dev-bot.sh` agora executa automaticamente o coordenador versionado depois da saúde inicial
do backend; não há etapa manual de flags, SQL ou `usermod` para ativar a capacidade. A subida inicial
força API off e allowlist vazia. O coordenador valida um único tenant provisionado sem registrá-lo,
mantém lock/overlay owner-only, faz backup cifrado assinado com custódia separada e restore drill,
executa backfill limitado a `50 × 1` em legacy-on e legacy-off, exige os cinco riscos em zero e
revalida readiness depois de promover API/allowlist. O overlay validado é lido por descritor e não
é repassado ao Compose como `--env-file`, evitando reabertura entre validação e uso.

Em rerun promovido, a etapa fechada preserva feature/legacy anteriores, portanto não reabre uma
janela de writer plaintext enquanto desliga API/allowlist/backfill. O lock é adquirido antes da
captura do overlay e de qualquer mutação; contender ou lock inseguro saem sem regravar overlay,
recriar backend ou executar rollback. O rollback só é armado imediatamente antes da primeira
escrita sob ownership do lock.

Falha ou ausência de progresso aciona rollback state-aware. Antes de zero-risk, o rollback preserva
legacy read para não tornar plaintext remanescente ilegível; depois de zero-risk, fecha legacy. Se
não conseguir comprovar backend recriado com API off/allowlist vazia, ele interrompe o backend e
emite `ROLLBACK FAILED`.

Passaram: sintaxe Bash; teste hermético de ativação; regressão hermética abrangente do startup DEV; safety do
backfill; reset DEV; e backend focal de controller/exposure/readiness/contrato `48/48`, sem
falha/erro/skip. A execução Docker real não foi possível porque o Docker instalado por Snap não
possui a capability necessária nesta sandbox e o socket permanece inacessível para a sessão. Por
isso, backfill PostgreSQL, readiness real e smoke autenticado de `/audit` continuam **NOT EXECUTED**;
não registrar o 404 como resolvido em ambiente até esse smoke retornar o contrato esperado.

#### 4.0.18 Docs-first persistent 404 runtime freeze — 2026-09-04

Uma chamada real originada em `/audit` retornou `AUD-404-NOT_FOUND`: **FAIL runtime observado**.
Frontend, contrato e controller usam o path canônico; não criar alias nem enfraquecer a camuflagem
do filtro. O resultado indica lifecycle não promovido no runtime efetivo e reabre o
[IP-BE-8.3.2.1-conversation-audit-local-activation-and-search-smoke](../delivery/plans/implementation_plans/backend/IP-BE-8.3.2.1-conversation-audit-local-activation-and-search-smoke.md)
antes de qualquer novo patch.

A correção operacional deve obedecer esta ordem:

1. ao entrar na janela de ativação, considerar a UI indisponível e armar `trap`/cleanup para que
   falha, `INT` ou `TERM` não deixem frontend remanescente;
2. executar o ativador canônico, que continua responsável por backup/restore, backfill `50 × 1` e
   readiness durável, sem atalhos manuais;
3. validar o overlay promovido como arquivo regular owner-only sem imprimir conteúdo e comprovar,
   por estado efetivo do backend/runtime, `feature=true`, `API=true`, allowlist com exatamente um
   tenant, `legacy=false` e `backfill=false`;
4. somente depois dessa prova iniciar/manter o frontend e declarar a UI pronta;
5. executar smoke autenticado posterior, sem registrar tenant, corpo de resposta ou identificador
   de erro; somente esse smoke pode promover o runtime a PASS.

O cleanup de falha/interrupção mantém o frontend parado e não altera banco, readiness, backup ou
dados. O fechamento da exposição e a regra de sinais foram endurecidos posteriormente em §4.0.19.
`ConversationAuditSecurityFilter`, readiness, RBAC, allowlist e defaults globais continuam
fail-closed. Neste freeze, correção, novos testes, rerun canônico e smoke verde permanecem
**PENDING**; as evidências repo-only de §4.0.17 continuam históricas e não resolvem o FAIL runtime.

#### 4.0.19 Docs-first post-promotion cleanup and signal freeze — 2026-09-04

Uma revisão adversarial classificou dois achados como **HIGH** antes de qualquer nova edição
executável: a promoção podia sobreviver a falha posterior no startup, e `SIGINT` podia ser ignorado
por um Bash assíncrono enquanto o coordenador continuava executando. O procedimento obrigatório é:

1. armar o gate antes de iniciar o ativador e mantê-lo até as provas finais de overlay, Compose,
   ambiente efetivo do backend, readiness pública e frontend;
2. em erro, `INT` ou `TERM`, parar o frontend e enviar `TERM` à árvore/grupo de processo dedicado do
   ativador, mesmo quando o sinal externo foi `INT`;
3. aguardar por prazo limitado; se o filho/grupo não encerrar, aplicar término forçado somente à
   árvore criada por este startup; coletar o filho com `wait` antes de qualquer fechamento ou
   retorno, impedindo que ele grave/promova posteriormente;
4. preservar o status externo (`INT=130`, `TERM=143`) sem reutilizar esses sinais para decidir como
   cancelar o filho;
5. reabrir o coordenador por novo descritor somente se arquivo regular, owner/mode e o
   `device:inode` pinado permanecerem exatos; invocar apenas `--close-exposure-only` sob o mesmo lock;
6. nesse modo, preservar feature/proteção e legacy válidos, gravar atomicamente API off, allowlist
   vazia e backfill off, recriar o backend regular e verificar a configuração efetiva sem imprimir
   UUID, segredo ou conteúdo;
7. close-only não resolve tenant e não executa backup, restore, backfill, consulta/mutação de
   readiness ou acesso a dados de conversa. Se pinagem, lock, escrita, recriação ou prova efetiva
   falhar, parar o backend antes de retornar erro. Não iniciar o frontend durante recovery.

As regressões herméticas devem cobrir separadamente pós-condição efetiva, túnel/readiness pública,
start/probe do frontend, falha do close-only e sinais `INT`/`TERM` reais enquanto o ativador está
aguardando. Para cada caso, provar frontend ausente, filho coletado, zero promoção tardia, estado
fechado ou backend parado, zero operação de dados no close-only e output sem tenant/segredo. Este é
um freeze **PENDING IMPLEMENTATION / PENDING EVIDENCE**; não operar o lifecycle real nem promover o
smoke com base somente nesta documentação.

#### 4.0.20 Post-implementation repository-only closure evidence — 2026-09-04

O procedimento de §4.0.19 está implementado no repositório. O coordenador possui modo exclusivo
`--close-exposure-only`; seus wrappers regular e de backfill usam timeout com `TERM` e escalada
dirigida para `KILL`. A regressão inclui Docker falso que ignora `TERM` e comprova término limitado,
tentativas de stop+probe e ausência de hang. O supervisor mantém o frontend ausente, encerra e
coleta o ativador e, se o close-only retornar nonzero, para e verifica o backend.

Lock contention tem semântica diferente nos dois níveis e não deve ser confundida. A invocação
direta do close-only que não obtém o lock retorna nonzero sem mutar overlay, runtime ou Docker. O
supervisor `start-dev-bot.sh`, e não o coordenador contendente, é responsável por tratar esse
nonzero com stop+probe fail-closed. Isso preserva a execução que possui o lock e mantém o último
estado seguro sob responsabilidade do processo pai.

No supervisor, stop/probe usa timeout default/máximo de `30s` com `kill-after` default/máximo de
`5s`; o close executa em sessão isolada com timeout externo default de `600s` e máximo de `900s`.
A regressão com limites de teste de `1s` encerrou três PIDs que ignoravam `TERM`, provou os estados
seguros de runtime/frontend/backend e passou também os casos de `INT`/`TERM` reais.

Passaram: sintaxe Bash de close-only/rollback/startup;
`infra/scripts/tests/activate-dev-conversation-audit-test.sh`;
`infra/scripts/tests/start-dev-bot-outbound-keyring-test.sh`; e
`infra/scripts/tests/conversation-audit-backfill-safety-test.sh`. Classificação:
**IMPLEMENTED / VERIFIED HERMETIC**. Docker/PostgreSQL, backfill/readiness reais e o smoke
autenticado de `/audit` continuam **RED / NOT EXECUTED**. O `AUD-404-NOT_FOUND` observado permanece
**FAIL runtime**; este checkpoint não autoriza afirmar que a consulta viva foi corrigida.

#### 4.0.21 Docs-first spawn-handoff and post-promotion Compose freeze — 2026-09-04

Uma nova revisão encontrou dois HIGH e reabre somente a prova do supervisor registrada em §4.0.20.
Não opere nem declare verde o lifecycle DEV com base naquele checkpoint até cumprir este
procedimento:

1. arme `INT`/`TERM` antes de criar o ativador e marque explicitamente o handoff de spawn como em
   andamento;
2. se um sinal chegar antes de PID e PGID estarem publicados e confirmados, preserve o primeiro
   status externo (`130` ou `143`); não retorne, não sobrescreva a causa e não deixe o filho sem
   ownership;
3. assim que o grupo dedicado for confirmado, processe imediatamente o sinal pendente: `TERM`,
   espera limitada, `KILL` dirigido se necessário e `wait`; falha de confirmação continua dentro
   do gate fail-closed e não autoriza frontend ou promoção;
4. depois de `EXPOSURE_MAY_BE_OPEN=true`, execute toda chamada Compose de config, backend,
   frontend e cleanup em sessão isolada com hard timeout default `300s`, máximo `600s`, `TERM` e
   `KILL` após graça limitada;
5. trate timeout e nonzero como qualquer outra falha pós-promoção: frontend ausente, ativador
   encerrado/coletado, close-only pinado; se o fechamento/verificação falhar, stop+probe do backend;
6. mantenha a distinção de lock: close-only direto contendido retorna nonzero sem mutar
   runtime/Docker; somente o supervisor executa o stop+probe decorrente.

As regressões obrigatórias injetam `INT` e `TERM` nos checkpoints determinísticos imediatamente
antes da publicação do PID e antes da confirmação do PGID. Também simulam cada classe Compose
pós-promoção ignorando `TERM`. A saída deve provar primeiro status preservado, zero processo/grupo
sobrevivente, zero promoção tardia, término limitado e estado fechado ou backend parado, sem
tenant, segredo, conteúdo ou `errorId`. Estado: **CORRECTION IN PROGRESS / PENDING FINAL
EVIDENCE**. Docker/PostgreSQL e smoke autenticado `/audit` permanecem **RED / NOT EXECUTED**.

#### 4.0.22 Docs-first interruptible-wrapper freeze — 2026-09-04

O start-gate e o hard timeout de §4.0.21 não bastam quando o próprio wrapper executa
`setsid --wait timeout` em foreground: o entrypoint pode adiar seu trap `INT`/`TERM` até o timeout
operacional, com a exposição possivelmente aberta. Antes do próximo patch, o procedimento passa a
exigir:

1. iniciar cada wrapper Compose pós-promoção assincronamente em sessão própria e impedir o comando
   de avançar até o supervisor registrar PID/PGID, com start-gate quando necessário;
2. usar `wait` interruptível no pai, mantendo os handlers livres para reagir imediatamente;
3. em `INT`/`TERM`, preservar `130/143`, enviar `TERM→CONT`, aguardar somente a graça de shutdown,
   aplicar `KILL` dirigido se necessário e coletar toda a árvore antes do close-only;
4. provar esse comportamento com sinais externos reais durante proof backend e `frontend up`, cada
   um com descendente resistente a `TERM`;
5. medir a latência do cleanup contra a graça de shutdown, nunca contra o timeout operacional
   default `300s`/máximo `600s`; frontend deve ficar ausente e exposição fechada ou backend parado.

Estado: **CORRECTION IN PROGRESS / PENDING FINAL EVIDENCE**. Não operar o lifecycle vivo com base
nas provas anteriores. Docker/PostgreSQL, backfill/readiness e smoke autenticado `/audit` continuam
**RED / NOT EXECUTED**; o `AUD-404-NOT_FOUND` observado não foi resolvido.

#### 4.0.23 Post-implementation interruptible-wrapper evidence — 2026-09-04

O procedimento de §4.0.22 está implementado e verificado no repositório. Cada proof pós-promoção
roda como child assíncrono sob start-gate `SIGSTOP`; o supervisor valida
PID/starttime/PGID/SID, preserva o primeiro sinal e faz polling curto de latch+`/proc` antes do
`wait`, inclusive em `before-supervised-wait`. A terminação executa
`TERM→CONT→grace→KILL` antes do wait, coleta o child, drena o grupo e relê o estado final.

Não há subshell/pipeline do wrapper no shell pai: config retorna somente digest, backend recebe
allowlist por stdin e frontend/cleanup avaliam `ps` no child. O snapshot final inclui stdin `<&0`
e o reparo de drain transitório. A execução independente passou bash-n dos dois scripts, a suíte
startup com exit `0` em cerca de `68s`, a ativação e o safety do backfill. A revisão read-only final
encontrou zero blocker/HIGH. Classificação: **IMPLEMENTED / VERIFIED HERMETIC**.

Isso não autoriza operação viva. Docker permaneceu sem permissão no socket, o bootstrap canônico
não interativo saiu `1` porque `sudo` exigiu senha e probes de readiness e `/audit` saíram curl
`7`/HTTP `000`. Docker/PostgreSQL, backfill/readiness e smoke autenticado permanecem **RED / NOT
EXECUTED**; o 404 observado não foi demonstrado como resolvido.

#### 4.0.24 DEV activation/backfill/readiness runtime evidence — 2026-09-04

O host DEV passou a satisfazer o bootstrap sem `sudo` corretivo posterior. Um launcher único
executou o ciclo completo e terminou `0`: fechamento inicial; backup cifrado e restore isolado;
backfill bounded `50 × 1` em legacy; cinco riscos zero; fingerprint final e readiness durável;
legacy/backfill off; allowlist unitária; API on; proof de backend/Compose; readiness pelo ngrok; e
frontend somente ao final.

Quatro defeitos observados foram corrigidos docs-first no
`IP-BE-8.3.2.1-conversation-audit-local-activation-and-search-smoke`: timeout interno `120s`
divergente do envelope `300s`; herança do lock outbound por filhos; programa pinado compartilhando
stdin com Docker/psql e `BASH_SOURCE` efêmero; e consulta parametrizada entregue por `psql -c` em vez
de stdin. Regressões cobrem cada boundary e o fake psql rejeita a forma `-c`.

Prova sanitizada posterior confirmou `backend_promoted=true`, `durable_readiness=true`, zero
holders nos dois locks, backend healthy e frontend running. O POST sem token retornou
`401 AUTH-401`, não `AUD-404-NOT_FOUND`, comprovando exposure ativa sem usar credencial. O operador
deve atualizar `/audit` na sessão já autenticada e registrar somente PASS/FAIL do `200`, nunca token,
tenant, corpo, identificador remoto ou `errorId`. HML, PRD, provider e release permanecem fora
desta promoção DEV.

#### 4.0.25 DEV authenticated search normalization — 2026-09-05

O erro `AUD-503-QUERY_TIMEOUT` observado em `/audit` não representava esgotamento do orçamento da
consulta. A reprodução PostgreSQL demonstrou falha imediata do driver ao receber `Instant` sem tipo
SQL inferível. O adapter agora vincula `from`, `to` e `expirationCutoff` como `Timestamp`; somente
`QueryTimeoutException`/`SQLTimeoutException` causal produz `AUD-503-QUERY_TIMEOUT`, enquanto outras
falhas de acesso retornam `AUD-503-QUERY_UNAVAILABLE`. Logs preservam apenas o tipo seguro da causa,
sem SQL, parâmetros, identificadores ou conteúdo.

Em DEV com mais de um tenant ativo/provisionado, a ativação deve ser direcionada explicitamente:

```bash
CONVERSATION_AUDIT_ACTIVATION_TENANT_ID=<canonical-dev-uuid> \
  ./infra/scripts/activate-dev-conversation-audit.sh
```

O script valida UUID canônico, existência, estado ativo/provisionado e unicidade antes de qualquer
promoção. Alvo ausente, inválido ou ambiguidade sem seletor falham com exposição fechada; o UUID não
é incluído na evidência. O comportamento histórico implícito permanece permitido apenas quando há
exatamente um tenant elegível.

Evidência local sanitizada: adapter/controller/contratos/arquitetura `55/55`; isolamento PostgreSQL
`2/2`; regressões de ativação, backfill e startup verdes; e Playwright com Keycloak real `1/1`, sem
MSW, observando `POST /search = 200`, `Cache-Control: no-store`, bearer presente e ausência de
`X-Tenant-ID`. A identidade efêmera recebeu somente `ROLE_TENANT_ADMIN` e `ROLE_TENANT_AUDIT` e foi
removida no teardown. A tela `/audit` está **GREEN em DEV para search**. O teste A×B de
detail/messages/reveal, provider, HML, PRD, canary e release continuam gates externos separados.

### 4.1 Preflight

1. Record change owner, incident commander, maintenance window and rollback artifact version.
2. Confirm feature, API, legacy-read, backfill, outbound-reconciliation and its subordinate
   terminal-gap detector flags are all `false`.
3. Produce an encrypted backup and restore it into an isolated temporary environment.
4. Validate all three independent keyrings — identifier AES, identifier blind-index HMAC and outbound-attempt HMAC — without logging their values or fingerprints.
5. Measure table sizes and the lock budget for the regular transactional indexes in `V33`. If rehearsal exceeds the budget, stop; any non-transactional alternative requires a new reviewed migration and cannot be substituted manually.
6. Inventory pending Modulith publications by safe event type and aggregate count; do not extract or log `serialized_event` payloads.
7. Capture only aggregate baselines: tenant-database count, conversation count, message count, null metadata count and maximum timestamp.
8. Drain/pause ordinary provider sends before V40, prove no provider call remains in flight, and
   record the approved hard timeout, dispatch-fence duration and safety margin without recording
   recipient, content, attempt or provider identifiers.
9. Stop at this preflight while the official 18-class PostgreSQL/CI execution, provider/fault
   injection, restore or required approvals are absent. Local implementation and source presence do
   not authorize manual substitute SQL or rollout. Verify Flyway history before deployment; never
   amend any applied V39/V40/V41 checksum, and use the next reviewed forward-only migration for a
   target-specific correction.

### 4.2 Schema Expand

1. Deploy only a reviewed target release containing the ordered, forward-only Omnichannel `V32`
   through `V44` and tenant/platform `V59` through `V63`
   migrations with all seven conversation-audit switches disabled and all destructive/capability
   flags off. Local artifacts are present, but this step remains
   blocked by missing zero-skip PostgreSQL/CI, provider/fault-injection, restore and approvals.
2. Confirm Flyway applied Omnichannel `V32` (audit metadata/checkpoint), `V33`
   (tenant-first indexes), `V34` (durable data-protection readiness), immutable `V35`
   (initial outbound-attempt ledger), additive `V36` (ledger hardening), additive `V37`
   (bounded reconciliation lease/backoff metadata), immutable `V38` (eligibility
   attestation/index plus pending-activity readiness counter), additive `V39` (continuous
   invalidation, composite message-parent integrity and commit-safe compatible-writer support),
   additive `V40` (immutable outbound association and provider-call dispatch fence/CAS support),
   additive `V41` (timeline ack/sticky gap and conflict timestamps/completed-fence digest plus
   bounded detector indexes), additive `V42` (FK/índices e guardas de expurgo) and additive `V43`
   (índice da guarda de publications incompletas) e additive `V44` (fence/serialização da retenção
   com publications). Confirm also tenant/platform `V59` (política
   durável, mutation/run ledgers e índice allowlisted de acesso), `V60` (registro global único da
   rota de receipts WhatsApp), `V61` (hardening da política de retenção), `V62` (capability/fence de
   expurgo) e `V63` (ator e auditoria atômica da rota receipt).
3. Never edit or replace an applied V35 checksum. V36 is the compatibility migration that tightens the state constraint, changes claim uniqueness to `(tenant_id, channel_type, attempt_key)`, adds partial provider-ID uniqueness and indexes both `PENDING` and `UNKNOWN` for reconciliation.
4. Treat a V36 failure on duplicate or incompatible legacy rows as a safe migration stop: PostgreSQL/Flyway must roll back the transaction. Do not delete evidence or weaken constraints; prepare a separately reviewed data-repair plan.
5. Confirm the deployed application tolerates Omnichannel V32–V44 and tenant V59–V63 and do not infer or execute a down
   migration. V40 is deliberately incompatible with legacy outbound writers: keep every send
   drained until all old instances are stopped, migrations complete and only V40+ writers are
   ready. Reader compatibility does not authorize mixed writers.
6. Do not run any SQL that rewrites identifier values or outbound evidence in bulk.
7. Never edit a migration whose checksum was applied. If any V39–V44 or V59–V63 migration fails under Flyway, stop and
   prepare a separately reviewed forward fix; do not weaken constraints, triggers or fences.

### 4.3 Compatible Writer/Reader

1. Mount independent AES/HMAC keyrings.
2. Enable the encrypted writer while keeping `APP_CONVERSATION_AUDIT_API_ENABLED=false`.
3. Temporarily enable legacy read only for the migration window.
4. Verify a synthetic new conversation stores `remote_number` with `enc:v1:` and a `hmac:v1:` lookup value.
5. Verify exact lookup uses indexed candidates and does not decrypt all rows.
6. While legacy read is temporarily enabled, lock one synthetic plaintext conversation and prove
   the ordinary writer upgrades only that row using tenant+channel+ID+old-value CAS before
   revalidation/attestation. CAS loss, disabled legacy flag or crypto failure must leave readiness
   invalid and fail closed; an already encrypted row stays byte-for-byte stable.
7. Verify the phase-2 native attestation synchronizes only its managed conversation and preserves
   unrelated pending changes in the same persistence context; global context clearing is forbidden.

### 4.4 Bounded Backfill

1. Enable the dedicated conversation-audit backfill with `batch-size` in `1..50` and
   `max-batches-per-run=1`; larger values fail before any datasource is accessed.
2. Run one bounded invocation. The V38 cursor selects only tenant-scoped rows whose non-secret protection-policy attestation is absent/stale, whose plaintext/envelope/hash structure is risky, or whose latest message is newer than `last_interaction`. It orders by conversation ID, locks only selected rows and updates by tenant+channel+ID.
3. Treat the marker as an attestation hint, never as PII-derived evidence: it contains only the current policy fingerprint, is invalidated when tenant/channel/ciphertext/hash changes and becomes stale whenever key policy changes. Explicit plaintext/structure/activity predicates remain active even when a marker value is present.
4. Observe only aggregate counters: `eligible_plaintext`, `missing_or_invalid_hash`, `unknown_key_id`, `missing_or_stale_attestation`, `pending_activity`, `processed`, `skipped`, `failed`, `remaining` and duration. `processed` includes attestation-only work; `failed` counts fail-closed attempts and may repeat across bounded invocations; `remaining` is the sum of the five risk counters from independent verification.
5. On failure, disable the runner, resolve the categorized cause and rerun. Already authenticated ciphertext is never re-encrypted to repair only hash, activity or attestation; its bytes remain stable.
6. Repeat until the remaining aggregate count reaches zero.
7. Reconcile `last_interaction` monotonically with the latest accepted message timestamp.

The first post-V38 pass legitimately verifies rows whose marker is null. After attestation, conforming rows are absent from work batches instead of being scanned and counted as skips. A separate bounded full-tenant verification remains mandatory for the zero-risk gate; it persists only counters, invalidates a risky marker and reopens the cursor, but never repairs or re-encrypts data itself.

V39 extends this lifecycle continuously. Conversation insert/relevant update and message
insert/update/move/delete invalidate the affected conversation marker. An ordinary conforming
writer may re-attest only after all source/message mutations are flushed and revalidated in a
commit-safe second phase. A direct, partial or failed write stays invalidated. Never set the marker
manually and never treat the aggregate readiness row as evergreen.

Message ownership is composite: `(conversation_id, tenant_id, channel_type)` must match the exact
conversation identity, backed by a UNIQUE candidate key on the parent and a composite FK on the
child. Validate existing rows before enabling the constraint; any mismatch stops the change and
requires a separately reviewed repair, never automatic reparenting/deletion. Trigger
invalidation resolves the real old/new parent. For messages, a relevant update is a change to that
association or `sent_at`; content/delivery-only changes do not affect the readiness predicates.

The backfill must not be registered in the global `LegacyCiphertextReencryptionRunner`, must not load a whole table into memory, must not re-encrypt authenticated ciphertext, and must not include raw/ciphertext/hash/marker values in output. A query-plan/performance pass on the representative PostgreSQL dataset is still required before rollout.

### 4.5 Zero-Plaintext Gate

The gate passes only when all conditions are true:

- aggregate eligible plaintext count is zero;
- aggregate missing/invalid blind-index count is zero;
- aggregate unknown/unapproved key-ID count is zero;
- aggregate missing/stale protection-attestation count is zero;
- aggregate pending-activity reconciliation count is zero;
- every envelope key ID is present in the approved read keyring;
- exact lookup, wrong-key and tamper tests pass;
- restore drill repeats the same aggregate results;
- legacy read is disabled and synthetic smoke tests still pass.
- a durable readiness record contains tenant database, migration version, approved protection-policy fingerprint, the zero counters and UTC verification time.

`completed=true` in the backfill cursor is not evidence for this gate. A separate verification query must produce the zero counters. Every list/detail/messages/reveal request consumes this readiness and, after V39, also runs the live tenant-scoped check for any absent/stale row attestation. Either failure, query timeout or unavailable risk check returns `503 AUD-503-DATA_PROTECTION_NOT_READY` with `Retry-After: 1` before business query/reveal, consistently in both security-filter and controller-advice paths.

Never publish a row sample as evidence. Store signed aggregate results and test report references only.

### 4.6 Outbound Durability Gate

The local implementation now persists a canonical `PENDING` attempt before invoking the provider. V35 introduced the ledger and must remain immutable; V36 hardens it with:

- a strict `PENDING`/`UNKNOWN`/`PROVIDER_ACCEPTED`/`FAILED` state constraint;
- claim uniqueness on `(tenant_id, channel_type, attempt_key)`, deliberately independent of a recreated conversation aggregate;
- partial provider-ID uniqueness on `(tenant_id, channel_type, provider_message_id)`;
- a tenant/status/time index covering both `PENDING` and `UNKNOWN` reconciliation candidates.

The attempt key is a keyed, tenant/channel-domain-separated HMAC. Its canonical input includes channel account, remote recipient, stable logical operation, origin, message type and complete effect material; the recipient and content-derived material do not reach the ledger in plaintext. For explicit logical operations it excludes mutable conversation UUID/count/current-inbound state. A repeated claim reuses the existing record and must never call the provider again. Claim identity is conversation-independent, but the first `conversation_id`/internal message UUID is immutable provenance. A replay arriving through another conversation does not reparent the ledger or recreate that UUID, makes zero provider call and is retained as ambiguous/manual association work. Only a typed, proven pre-acceptance rejection becomes `FAILED`; generic exceptions, timeouts and crashes are `UNKNOWN` or remain `PENDING` and cannot trigger blind resend.

V37 adds the bounded lease, expiry, probe/backoff, safe outcome/association metadata and candidate
index used by the default-off completion loop. It is additive: V35/V36 history, evidence and
uniqueness remain intact, and stale leases can be reclaimed after restart without turning the
worker into a send path.

V40 adds a separate durable dispatch fence for the provider call. A new `PENDING` receives it
before the external call. Its duration is greater than the maximum hard provider timeout plus the
approved safety margin; terminal states clear it. The completion selector must exclude every
`PENDING` under an active dispatch fence. A sender finalizes by compare-and-set against the
expected pending/fence state and no conflicting reconciliation ownership; zero updated rows is a
conflict unless the stored terminal result is exactly idempotent. A late sender cannot overwrite a
terminal result from reconciliation. Legacy `PENDING` rows receive only an explicitly expired
fence after sends have been drained, so upgrade never invents an active provider call.

V41 adds four independent durable facts: `timeline_materialized_at`, maintained transactionally by
message trigger and revalidatable against the exact canonical association;
`terminal_timeline_gap_detected_at`, a sticky first-detection timestamp;
`association_conflict_detected_at`, a sticky cross-conversation marker that excludes automatic
claims; and `completed_dispatch_fence_digest`, a domain-separated one-way digest used only to prove
that a terminal retry owns the completed fence. Its canonical encoding is
`lowerHex(SHA-256(UTF-8("conversation-audit-completed-dispatch-fence-v1|" + lowerCaseUuid)))`.
`last_reconciliation_outcome` remains the latest
safe event and may change; the sticky timestamps preserve incident history. Accepted equality is
status+internal provider ID+digest; failed equality is status+allowlisted category+digest.
Observation timestamps are deliberately non-material.
Existing terminal rows receive no invented completed-fence digest; a null digest makes any later
sender retry fail closed/manual.

The only legal `NULL→completed_dispatch_fence_digest` transition is part of the sender-owner CAS that
atomically changes the matching active-fence row from `PENDING` to `PROVIDER_ACCEPTED` or `FAILED`,
while no reconciliation owner exists. Reconciliation, a terminal retry, backfill or an operator
update must not populate, repair, replace or clear the digest. A null terminal digest remains
manual forever; it is not evidence that can be manufactured after completion.

For the V41 message trigger, relevant updates are limited to message ID, tenant, conversation,
channel or direction. Content/delivery-only updates do not change the ack. Both old and new exact
associations are reevaluated where an update is permitted. Trigger lookup must use the bounded
`(tenant_id, conversation_id, channel_type, internal_message_id)` attempt index. Every ack mutation
and every transition to terminal advances `outbound_delivery_attempts.updated_at`; detector grace,
cursor/order and the partial candidate index use that timestamp, never `created_at`.

Outbound claim rotation uses a dedicated keyring. New claims use its active
key; lookup calculates the active token plus every configured read-old candidate and reuses exactly
one existing attempt before any insert/provider effect. Candidate handling is bounded and duplicate
matches fail closed. The stored token remains the 64-character keyed HMAC only: key IDs, raw
canonical material, identifiers, content and unkeyed digests are not persisted.

Rotation is staged: deploy all readers with old+new while old remains active, then switch every
writer to new active. Claim acquisition serializes the common candidate set so mixed active writers
with the same read keyring cannot both become provider owners. Pre-hardening rows remain compatible
only when their former root is provisioned as a read-only candidate; it must never remain active.

The focused HMAC, claim and completion-loop tests pass locally. This gate remains **open** because
the PostgreSQL selector did not execute, no real-provider query/list probe is approved and neither
the pre-production provider crash/retry exercise nor the operational rotation drill has run.
Schema/index presence and in-memory tests alone are not release evidence.

### 4.7 Bounded Outbound Completion Procedure

Keep `APP_CONVERSATION_AUDIT_OUTBOUND_RECONCILIATION_ENABLED=false` until the provider-specific
query/list capability and the PostgreSQL concurrency gate are approved. Enabling this switch starts
only the query-only completion loop; it never enables or retries an outbound send.

The generic completion worker, tenant-safe claim/lease persistence and scheduler are implemented
locally. Default-off is still mandatory because no WhatsApp/Telegram real-provider probe has been
approved; absence of capability produces only an inconclusive outcome and never a resend.

1. Configure bounded values within section 2, confirm the reconciliation lease exceeds the
   approved provider lookup timeout and independently confirm the dispatch fence exceeds the
   maximum hard provider send timeout plus safety margin. Do not increase bounds to drain a
   backlog during an incident.
2. For each bounded tenant slice, the worker establishes `TenantContext`, verifies the registered
   tenant database, then atomically claims at most `batch-size` eligible `PENDING`/`UNKNOWN` rows
   with `FOR UPDATE SKIP LOCKED` and an expiring lease. A `PENDING` with active dispatch fence is
   never eligible, even if `minimum-age` has elapsed.
3. The provider probe may return only `PROVIDER_ACCEPTED`, `PROVEN_NOT_ACCEPTED` or
   `INCONCLUSIVE`. It receives no content or raw recipient. It has no send operation.
4. Conclusive evidence completes the ledger and monotonically associates the existing canonical
   message in one tenant transaction. `DELIVERED`/`READ` never regress. A contradictory terminal
   timeline result remains `UNKNOWN` and is escalated without overwriting evidence. If the exact
   canonical association result is `MISSING`, that same completion transaction writes
   `terminal_timeline_gap_detected_at` once, the safe manual outcome/`last_reconciled_at` and the
   aggregate incident signal, even when the subordinate detector switch is `false`. This inline
   safety behavior is not the periodic sweep and never calls provider/send or rebuilds content.
5. No capability, transient errors and inconclusive responses change stale `PENDING` to `UNKNOWN`,
   clear the lease and schedule bounded exponential backoff. After `max-attempts`, leave
   `UNKNOWN`, clear automatic scheduling and open manual review. Never mark `FAILED` merely due to
   age/count, and never send again from this procedure.
6. On process crash, wait for lease expiry. A restarted worker reclaims the row and repeats the
   idempotent lookup; operators must not clear leases manually or invoke the original send path.
7. Monitor aggregate outcome/channel counters. Logs and metrics must not include tenant,
   conversation, attempt/lease token, provider ID, recipient, content or exception message.
8. If a sender returns after its fence or after reconciliation changed the state, require the
   compare-and-set result. Never retry its terminal update blindly; exact terminal equality is
   idempotent, while any divergence opens manual review.

An accepted/rejected result whose canonical message is absent is retained in the ledger with sticky
gap evidence, a safe association outcome and alert for manual investigation regardless of the
periodic detector switch. Reconstructing semantic content from a provider payload is forbidden.

### 4.8 V41 Terminal Timeline Gap Procedure

Keep `APP_CONVERSATION_AUDIT_OUTBOUND_RECONCILIATION_TERMINAL_GAP_DETECTION_ENABLED=false` until
V41 PostgreSQL crash/concurrency/index evidence is approved. The existing reconciliation switch
does not enable this scan implicitly; configuring the child true with the parent false is invalid.

1. Reuse only the validated reconciliation batch size and minimum age; keep the scan tenant-scoped,
   ordered and locked with bounded `FOR UPDATE SKIP LOCKED`. Measure grace from `updated_at`, after
   terminal transition or ack mutation; age is a grace period, not proof, and `created_at` is not a
   detector cursor.
2. Select terminal `PROVIDER_ACCEPTED`/`FAILED` attempts with `timeline_materialized_at IS NULL`, no
   prior sticky gap/conflict and no competing lease, using the partial tenant-first
   `(tenant_id, updated_at, id)` candidate index. The message trigger uses the separate bounded
   `(tenant_id, conversation_id, channel_type, internal_message_id)` association index. Inside the
   same transaction, revalidate
   exact canonical `NOT EXISTS` by tenant+conversation+channel+direction+internal message UUID.
3. If the exact message exists, set `timeline_materialized_at` by CAS in the same bounded
   transaction and do not mark a gap; this is the bounded bootstrap for pre-V41 terminal rows and
   never becomes a bulk update. If the message is absent, set
   `terminal_timeline_gap_detected_at` once, update safe
   last-outcome/last-reconciled metadata and increment an aggregate manual-review metric. Never call
   a provider or construct a message.
4. If a valid message is inserted later, its trigger sets `timeline_materialized_at` but never
   clears `terminal_timeline_gap_detected_at`; current materialization and past incident remain
   independently observable.
5. Cross-conversation replay sets `association_conflict_detected_at` once and the latest safe
   `ASSOCIATION_CONFLICT` outcome without changing canonical IDs. Rows with the sticky conflict do
   not enter either automatic completion loop.
6. A sender terminal retry is read-only idempotent only when the digest of its presented fence and
   its material status/provider-ID-or-category exactly match the stored result. Different
   observation timestamps are ignored; wrong/missing token proof or material divergence is manual.
   It cannot fill a null digest. Only the original sender-owner `PENDING→terminal` CAS may perform
   `NULL→digest`; reconciliation/backfill/operator updates are not repair paths.

Metrics expose only bounded status/outcome/channel categories and aggregate counts. Attempt,
conversation, tenant, fence digest, provider ID and content remain forbidden in telemetry.

## 5. Feature Enablement

The sequence below governs external/canary rollout after §3 closure. The only permitted earlier
activation is the single-tenant Docker-local procedure in §4.0.2; it does not satisfy or bypass any
external gate.

1. Configure exactly the approved pilot UUID in `APP_CONVERSATION_AUDIT_ALLOWED_TENANT_IDS`, keep `APP_CONVERSATION_AUDIT_ENABLED=true`, confirm durable readiness zero-risk, then enable `APP_CONVERSATION_AUDIT_API_ENABLED=true` after all section 3 gates are closed.
2. Verify strict effective-role enforcement: `ROLE_TENANT_AUDIT` succeeds only in valid tenant
   context; `ROLE_TENANT_ADMIN` without the audit role, operator and chatbot admin fail; Super Admin
   succeeds only with the explicit audit role from a fresh token and valid tenant impersonation.
3. Run A→A and negative A→B tests for list, detail, messages and reveal.
4. Confirm `Cache-Control: no-store`, safe error shape and one audit event per operation.
5. Observe latency/error/rate metrics without tenant/user/conversation labels.
6. Enable the approved frontend only after wireframe sign-off and frontend assurance gates.
7. Expand the allowlist gradually; record every step and abort threshold.

These flags expose only the conversation-audit read API. They do not act as a kill switch for ordinary outbound chatbot messages.

Default resource controls are:

| Operation | Requests per effective tenant + user / 60 s | Query timeout |
|---|---:|---:|
| search | 30 | 2 s |
| detail | 60 | 1 s |
| messages | 120 | 1.5 s |
| reveal | 10 | 1 s |

The local limiter is a degraded bounded fallback only: at most 10,000 keys, TTL no longer than two minutes, and safe rejection when full. `429` and transient `503` include integer `Retry-After`; clients do not retry automatically.

## 6. Monitoring and Alerts

Allowed metric dimensions: `operation`, allowlisted `outcome`, HTTP status family and delivery-status enum. Forbidden dimensions: tenant, user, conversation, remote identifier, blind index, provider ID, content, error text and correlation ID.

Logs, traces, errors and audit details also forbid provider IDs/payloads, content and external exception message/cause. Record only safe categories plus opaque `errorId`/`correlationId`; never log `exception.getMessage()` from provider/crypto boundaries.

Alert conditions requiring rollout pause:

- any cross-tenant authorization/isolation failure;
- any plaintext eligible row after the gate;
- decrypt/authentication-tag failure above a single investigated event;
- audit recorder failure while an endpoint returned data;
- error or p95 latency above the approved SLO for two consecutive windows;
- backfill failure growth or unbounded memory/query behavior;
- any terminal timeline gap, association conflict or ack inconsistency detected by V41;
- any pending legacy Modulith publication with sensitive fields still populated at the rollout gate;
- V89 normalization checkpoint `FAILED`, stale/no-progress lease or remaining offender; this pauses
  Phase B and keeps purge jobs blocked, but must not disable the bounded recovery routine;
- PII detected in logs, metrics, traces, audit details or browser cache.

The repository definitions are `infra/monitoring/grafana/dashboards/conversation-audit.json` and
the `conversation-audit-alerts` group in `infra/monitoring/prometheus/alert_rules.yml`. They contain
fourteen PII-free panels and twenty rules owned by `security-sre`, including bounded backfill failure,
terminal timeline gap and association conflict. Validate them before provisioning:

```bash
bash infra/scripts/tests/conversation-audit-observability-test.sh
```

A passing static check proves only structure, owner and finite labels. Import into Grafana,
Prometheus rule load, scrape continuity, notification delivery and a controlled firing test remain
mandatory operational evidence.

## 7. Rollback

1. Disable frontend exposure and `APP_CONVERSATION_AUDIT_API_ENABLED`; do not disable encryption for already protected rows and do not weaken authorization.
2. Disable backfill. In-flight batch either commits atomically or rolls back.
3. Disable the V41 terminal-gap detector and ordinary outbound reconciliation; never clear sticky
   incident timestamps or dispatch/reconciliation leases manually.
4. Keep expand migrations in place. Do not drop columns/indexes during incident response.
5. During the V89-to-V90 transition, never force checkpoint `COMPLETE`, edit Flyway history or
   revert V89. Keep destructive jobs blocked. When V90 fails before commit, first prove it is absent
   from Flyway history; only then, with `retention.enabled` and both purge flags off, redeploy the
   immutable `phase=A` artifact so bounded recovery resumes from its committed cursor. When V90 is
   already applied, binary rollback to A is forbidden: remain on artifact/schema B with master and
   both purges off and use a forward fix. Neither path edits Flyway history or chooses a phase via
   env/property.
6. Keep read keys required by existing ciphertext. Never restore plaintext as an application rollback.
7. Roll application artifact back only to a version proven to tolerate the expanded schema and already-written envelopes. After V36, do not roll back to an adapter that still targets V35's removed `(tenant_id, channel_type, conversation_id, attempt_key)` conflict index. After V40, never resume an older outbound writer; keep sends drained until a forward-compatible release is restored.
8. If provider evidence is suspect, render conservative `UNKNOWN`; never downgrade stored proof by destructive rewrite without a separate plan.
9. Re-run aggregate integrity and tenant isolation checks before re-enablement.

## 8. Key Rotation and Recovery

1. Add a new key ID/material to the relevant keyring; do not replace the old entry.
2. Deploy readers with both keys while the old key stays active.
3. After every instance has the same read keyring, switch the active ID for new writes.
4. Identifier-HMAC queries calculate active and previous candidates using `IN` until bounded reindex completes.
5. Outbound-attempt claims also calculate active+old candidates, but do not bulk-reindex: canonical effect material is deliberately not stored. Retain the old outbound key until the maximum approved replay/ledger-retention window has elapsed and corresponding rows have been removed under the approved retention policy.
6. Verify identifier zero-key-reference counters and outbound ledger age/retention evidence, then remove the old key only after backup-retention implications and recovery drill are approved.

The outbound-attempt deployment boundary enforces this sequence in DEV/HML/PRD before replacing
the mounted keyring. Its owner-only lifecycle state contains only the active/read/retired key IDs,
one-way SHA-256 continuity fingerprints of decoded high-entropy material and used approval IDs;
raw/base64 material, effective paths and fingerprints never enter logs, argv or release evidence.
The state and pending journal stay inside the private keyring volume with mode `0400` and are not
mounted writable by the backend.

- a fresh empty volume may install one valid candidate; an existing pre-gate volume may be adopted
  only when candidate IDs/material are byte-identical to the already mounted keyring;
- every ordinary update preserves every current read ID with identical decoded material; changing
  material under an existing ID, reusing a retired ID/material or removing an ID fails before the
  atomic overwrite;
- adding a key keeps the previous active ID. A later update may switch active only to an ID already
  present in the prior committed read set, and that switch still preserves the former active ID;
- retirement is a separate update, keeps the committed active ID unchanged and requires an exact
  owner-only JSON approval at `outbound-hmac-key-removal.json`. The manifest has exactly
  `version=1`, an opaque unique `approvalId`, UTC `approvedAt`, the sorted unique
  `removedKeyIds`, three non-empty opaque evidence references (`ledgerRetentionEvidenceId`,
  `backupRetentionEvidenceId`, `recoveryDrillEvidenceId`) and boolean `securityApproved=true` plus
  `sreApproved=true`. It authorizes exactly that set once; the resulting tombstones and used
  approval ID remain in protected state;
- the pending journal is written before the keyring overwrite. On interruption/reboot, retry accepts
  only the byte-identical pending candidate and proves the mounted volume matches either the prior
  committed or pending generation; every third state fails closed. The approval is therefore not
  lost before its transition is recoverable;
- HML/PRD initializers execute the same versioned lifecycle validator with no network, bounded
  files, read-only source/approval mounts and a writable private target volume. Direct Compose
  cannot bypass replacement/removal checks; `--no-deps` or manual volume mutation is prohibited.

Antes de qualquer nova transição, o initializer deve copiar o source uma única vez para um
snapshot owner-only dentro do workdir privado. Validação estrutural, fingerprints, next-state e
instalação usam somente esse snapshot; o path bind vivo não pode ser relido depois do snapshot.
Isso fecha a janela em que o owner do host substituiria o arquivo entre validação e `cp`. O gate
adversarial troca o source nesse ponto e exige target/state coerentes com o snapshot ou falha sem
efeito, sempre com output fixo sem ID/material/fingerprint/path.

O source implementado satisfaz este contrato: snapshot privado `0400`, candidate map e instalação
do mesmo arquivo. O teste troca o path vivo após o snapshot e comprova target/state da geração A
sem adotar a geração B; lifecycle, bootstrap DEV, preflight HML/PRD, observabilidade e sintaxe
passaram. Isso é evidência local do boundary, não execução do drill real.

Uma revisão independente posterior encontrou a mesma classe de TOCTOU no manifesto de retirement:
o arquivo vivo podia ser validado para um conjunto A e reaberto depois para obter um `approvalId`
B. Antes do novo patch, fica obrigatório copiar o manifesto uma única vez para snapshot privado
owner-only; schema, chaves removidas, evidências, `approvalId`, verificação one-shot, pending journal
e estado committed devem derivar somente desse snapshot. O path bind vivo não pode ser relido após
a captura. Um teste adversarial deve trocar o manifesto nesse ponto e provar consumo do ID A e
transição autorizada por A — ou falha sem efeito — sem expor ID, evidência, path ou material.

Estado deste fechamento: **FROZEN / PENDING IMPLEMENTATION / PENDING EVIDENCE**. Até o teste passar,
retirement operacional e drill real permanecem RED.

O fechamento pós-freeze está implementado: o manifesto é copiado no máximo uma vez para o workdir
privado `0700`, recebe modo `0400` e governa sozinho schema, removed IDs, evidências, `approvalId`,
one-shot, pending e commit. A regressão adversarial troca o bind vivo de A para B após a captura e
prova target/tombstone/usedApprovalIds coerentes com A, com output fixo e sem dados protegidos. A
suíte lifecycle e a sintaxe passaram; retirement/drill real permanecem não executados.

Uma revisão independente posterior encontrou um boundary de ativação ainda aberto: o backend lê o
keyring para memória no startup, mas o fluxo PRD executava o initializer seguido de `compose up`
sem `--force-recreate`; a instrução HML também era um `up -d` genérico. Se imagem e configuração
permanecessem iguais, a geração instalada no volume não seria necessariamente carregada pelo
processo existente. Em retirement isso manteria a chave retirada aceita em memória.

Antes do patch, fica congelada a sequência oficial abaixo:

1. DEV permanece coberto pelo `--force-recreate` já existente;
2. em HML e PRD, marcar o início do boundary fail-closed antes de executar o initializer, impedindo
   que trap/sinal religue writers antigos a partir desse ponto;
3. concluir o initializer e executar `up -d --no-build --no-deps --force-recreate backend`;
4. aguardar o backend saudável antes de iniciar frontend, proxy ou demais serviços; se houver
   falha desde a entrada no initializer até esse health, manter/parar backend e proxy antigos para
   que a geração anterior em memória não continue atendendo;
5. HML deve usar entrypoint versionado; o comentário genérico de `docker-compose.hml.yml` não é
   procedimento de rollout;
6. testes estáticos devem exigir comando e ordem exatos; o drill vivo permanece obrigatório.

Estado: **FROZEN / PENDING IMPLEMENTATION / PENDING EVIDENCE**. Nenhum ambiente HML/PRD foi
acessado e nenhuma flag foi promovida.

O fechamento pós-freeze está implementado. PRD entra no boundary antes do initializer, força a
recriação isolada do backend, espera health e só então sobe frontend/proxy. O cleanup impede restart
do writer antigo e para proxy/backend se a ativação não alcançar health. HML usa
`infra/scripts/deploy-hml-outbound-hmac-keyring.sh` com env-file explícito `0400`/`0600`, a mesma
ordem e trap fail-closed; o cabeçalho Compose mantém um comando fresh/full separado com
`--force-recreate`.

`deploy-hml-outbound-hmac-keyring-test.sh`, `deploy-production-v40-config-test.sh` e a sintaxe dos
quatro scripts/testes passaram. O teste PRD renderizou somente Compose versionado com exemplo fora
do sandbox por limitação do snap; nenhum container ou ambiente foi iniciado. Essa evidência fecha o
source/static-local, não o drill HML/PRD nem a aprovação humana de Infra.

Compromise response disables exposure, preserves sanitized evidence, rotates the affected keyring independently, invokes Security/DPO notification criteria and follows the zero-plaintext/integrity gates again. A lost read key is not repaired by logging or exposing ciphertext; restore follows the approved recovery copy.

The outbound token is intentionally not self-describing: key IDs are configuration metadata, while the ledger stores only the fixed-size opaque HMAC. Candidate lookup provides rotation compatibility without retaining canonical material. Never remove an old outbound key merely because the active ID changed; doing so before its replay/retention window expires can break replay suppression. A compromised outbound key requires pausing provider sends and a separately approved reconciliation/retention response rather than blind resend.

The focused keyring/candidate tests are green, but this procedure has not been exercised as an
operational rotation drill. Keep the old candidate and the rollout gate in place until the staged
mixed-reader/mixed-active exercise, PostgreSQL concurrency proof and recovery evidence are signed.

## 9. Incident Evidence Template

Record only:

- UTC start/end, release and migration versions;
- operation and allowlisted outcome/category;
- aggregate affected-row/request counts;
- opaque `errorId` references;
- containment, rollback and validation results;
- named owners and approvals.

Explicitly exclude request/response bodies, identifiers, content, provider payload/IDs, JWT/cookies, key paths/material and exception messages that may contain input.

## 10. Verification Commands and Evidence Interpretation

Run Maven commands serially from `backend/`; do not run concurrent builds against the same `target/` tree.

Run the static Keycloak v2.6.1 gates from the repository root before touching a persisted volume:

```bash
bash infra/scripts/tests/keycloak-runtime-json-validator-test.sh
bash infra/scripts/tests/keycloak-bootstrap-hardening-test.sh
bash infra/keycloak/bootstrap/validate-realm-token-contracts.sh
bash infra/scripts/tests/start-dev-bot-outbound-keyring-test.sh
```

All four passed locally; this is structural/static evidence only.

Compile production and test sources before any focused invocation:

```bash
cd backend
./mvnw -B -DskipTests test
```

Run the non-Docker contract/security/API/ledger checks with real class names:

```bash
./mvnw -B -Dtest='ConversationAuditControllerTest,JdbcConversationAuditDataProtectionReadinessAdapterTest,JpaConversationRepositoryAdapterTest,JpaConversationAuditReadAdapterTest,ChannelMessageRouterParameterizedTest,OutboundDeliveryReconciliationServiceTest,OutboundDeliveryDispatchPolicyTest,OutboundDeliveryDispatchPropertiesTest,WhatsAppCloudApiAdapterTest,HmacOutboundAttemptTokenAdapterTest,OutboundDeliveryReconciliationPropertiesTest,OutboundDeliveryReconciliationSchedulerTest' test
```

The PostgreSQL gate requires a usable Docker daemon **before** Maven starts:

```bash
docker info
./mvnw -B -Dtest='ConversationAuditContinuousReadinessPostgresTest,ConversationAuditBackfillTest,ConversationAuditMigrationPostgresTest,ConversationAuditRetentionPlatformPostgresTest,ConversationAuditRetentionCommitFencePostgresTest,ConversationAuditPublicationSerializationPostgresTest,JpaConversationRepositoryAdapterPostgresTest,ConversationAuditReadinessToctouPostgresTest,JdbcConversationRetentionPurgeAdapterPostgresTest,JdbcOutboundDeliveryAttemptAdapterTest,OutboundDeliveryAttemptDurabilityPostgresTest,OutboundDeliveryReconciliationPostgresTest,OutboundDeliveryTerminalTimelinePostgresTest,WhatsAppReceiptRoutePostgresTest,WhatsAppReceiptTransitionPostgresTest,TelegramCallbackGenerationPostgresTest,ConversationAuditTenantIsolationIT,ConversationAuditPerformancePostgresTest' clean test
```

Stop if `docker info` returns non-zero; do not run or accept the Maven result as PostgreSQL evidence. `clean test` is intentional here so old compiled classes or Surefire XML cannot satisfy the gate.

After the PostgreSQL command, require all 18 selected Surefire reports to show at least one test and `errors="0" skipped="0" failures="0"`:

```bash
rg -n 'tests="[1-9][0-9]*" errors="0" skipped="0" failures="0"' \
  target/surefire-reports/TEST-*ConversationAuditContinuousReadinessPostgresTest.xml \
  target/surefire-reports/TEST-*ConversationAuditBackfillTest.xml \
  target/surefire-reports/TEST-*ConversationAuditMigrationPostgresTest.xml \
  target/surefire-reports/TEST-*ConversationAuditRetentionPlatformPostgresTest.xml \
  target/surefire-reports/TEST-*ConversationAuditRetentionCommitFencePostgresTest.xml \
  target/surefire-reports/TEST-*ConversationAuditPublicationSerializationPostgresTest.xml \
  target/surefire-reports/TEST-*JpaConversationRepositoryAdapterPostgresTest.xml \
  target/surefire-reports/TEST-*ConversationAuditReadinessToctouPostgresTest.xml \
  target/surefire-reports/TEST-*JdbcConversationRetentionPurgeAdapterPostgresTest.xml \
  target/surefire-reports/TEST-*JdbcOutboundDeliveryAttemptAdapterTest.xml \
  target/surefire-reports/TEST-*OutboundDeliveryAttemptDurabilityPostgresTest.xml \
  target/surefire-reports/TEST-*OutboundDeliveryReconciliationPostgresTest.xml \
  target/surefire-reports/TEST-*OutboundDeliveryTerminalTimelinePostgresTest.xml \
  target/surefire-reports/TEST-*WhatsAppReceiptRoutePostgresTest.xml \
  target/surefire-reports/TEST-*WhatsAppReceiptTransitionPostgresTest.xml \
  target/surefire-reports/TEST-*TelegramCallbackGenerationPostgresTest.xml \
  target/surefire-reports/TEST-*ConversationAuditTenantIsolationIT.xml \
  target/surefire-reports/TEST-*ConversationAuditPerformancePostgresTest.xml
```

`OutboundDeliveryTerminalTimelinePostgresTest` is mandatory and covers trigger/ack, `updated_at`
grace, both indexes, exact `NOT EXISTS`, inline completion `MISSING`, sticky timestamps,
owner/non-owner digest mutation, crash and late materialization. Its source existence is not proof.

`JpaConversationRepositoryAdapterPostgresTest` and
`ConversationAuditReadinessToctouPostgresTest` are equally mandatory. They cover the real
Spring/JPA writer transaction and the V39 readiness TOCTOU window; source existence or an isolated
non-canonical run is not proof.

The historical expansions from eight to ten, eleven and then fifteen classes/XMLs remain recorded below.
The current gate additionally covers commit fence, publication serialization and Telegram callback
generation, so the CI job must execute the same 18-class selector and fail unless exactly these 18
non-empty reports exist and each matches the
zero-skip expression. Its selector/assertion is aligned statically but has not executed. The
following assertion is normative after the clean lifecycle run; it also rejects a missing or
duplicated report instead of accepting stale local XML:

```bash
reports=(
  target/surefire-reports/TEST-*ConversationAuditContinuousReadinessPostgresTest.xml
  target/surefire-reports/TEST-*ConversationAuditBackfillTest.xml
  target/surefire-reports/TEST-*ConversationAuditMigrationPostgresTest.xml
  target/surefire-reports/TEST-*ConversationAuditRetentionPlatformPostgresTest.xml
  target/surefire-reports/TEST-*ConversationAuditRetentionCommitFencePostgresTest.xml
  target/surefire-reports/TEST-*ConversationAuditPublicationSerializationPostgresTest.xml
  target/surefire-reports/TEST-*JpaConversationRepositoryAdapterPostgresTest.xml
  target/surefire-reports/TEST-*ConversationAuditReadinessToctouPostgresTest.xml
  target/surefire-reports/TEST-*JdbcConversationRetentionPurgeAdapterPostgresTest.xml
  target/surefire-reports/TEST-*JdbcOutboundDeliveryAttemptAdapterTest.xml
  target/surefire-reports/TEST-*OutboundDeliveryAttemptDurabilityPostgresTest.xml
  target/surefire-reports/TEST-*OutboundDeliveryReconciliationPostgresTest.xml
  target/surefire-reports/TEST-*OutboundDeliveryTerminalTimelinePostgresTest.xml
  target/surefire-reports/TEST-*WhatsAppReceiptRoutePostgresTest.xml
  target/surefire-reports/TEST-*WhatsAppReceiptTransitionPostgresTest.xml
  target/surefire-reports/TEST-*TelegramCallbackGenerationPostgresTest.xml
  target/surefire-reports/TEST-*ConversationAuditTenantIsolationIT.xml
  target/surefire-reports/TEST-*ConversationAuditPerformancePostgresTest.xml
)
test "${#reports[@]}" -eq 18
for report in "${reports[@]}"; do
  test -s "$report"
  rg -q 'tests="[1-9][0-9]*" errors="0" skipped="0" failures="0"' "$report"
done
```

Until that statically aligned CI assertion executes and produces 18 green XML artifacts with
Docker available, the PostgreSQL/retention/receipt gate is RED/not executed.

`@Testcontainers(disabledWithoutDocker = true)` intentionally skips these tests when Docker is unavailable. In that situation Maven may print `BUILD SUCCESS`, but the PostgreSQL gate is **not run and remains RED**. `surefire:test` against previously compiled classes is diagnostic only; canonical evidence uses the lifecycle command above and records the test/failure/error/skip counts. Finish with the repository-wide serial gate and reconcile any failure against the canonical quality report; do not relabel known baseline failures as feature success:

```bash
./mvnw -B clean test
```

### 10.1 Historical Local Evidence — 2026-08-18

- Production and test-source compilation: **PASS**.
- Focused non-Docker selector: `73/73`, with zero failures, errors or skips. This includes HMAC
  (`5`), router (`29`, including fail-closed discard when provider-ID classification fails) and
  reconciliation units (`14`: service `10`, properties `2`, scheduler `2`).
- Repository-wide suite recorded before the final one-test router hardening: `1,265` tests, two
  known Modulith baseline failures and `31` skips (`BUILD FAILURE`); the later 73/73 focused gate
  covers that hardening, but the repository-wide quality gate remains **RED** until rerun.
- PostgreSQL selector: `20/20` tests skipped because Docker was unavailable. This is **NOT
  EXECUTED**, not a pass, so the PostgreSQL gate remains **RED**.
- Real-provider query/list probe and the operational rotation/pre-production fault-injection drills
  have not run and remain release blockers.

### 10.2 Post-V40, Pre-V41 Evidence — 2026-08-19

- Production/test-source compilation: **PASS**, `861` production and `277` test sources.
- Focused non-Docker selector shown above: `86/86`, zero failures/errors/skips. This evidence
  precedes the newly frozen V39 repairs and V41 and therefore is historical only.
- PostgreSQL selector with the seven current classes discovered `24` tests and skipped all `24`
  because `/var/run/docker.sock` was unavailable: **NOT EXECUTED / RED**.
- Architecture selector: Clean Architecture `16/16` passed; Modulith still has the two known
  baseline `shared -> fiscal` failures. The full suite was not rerun after V39/V40; the most recent
  full result remains historical `1,265` tests, `2` failures, `0` errors and `31` skips.
- This checkpoint predates V41. Provider probe, pre-production crash/fault injection, index plan and
  release gates remain RED. No local result authorizes enablement.

### 10.3 V41 Local, Pre-remediation Evidence — 2026-08-19

- The initial focused V41 selector executed `105` tests: `102` passed and `3` failed in the JPA
  fixture. This was not a green run.
- After correcting that fixture, the isolated `JpaConversationRepositoryAdapterTest` rerun passed
  `13/13` with zero failure/error/skip. It does not convert the earlier aggregate run or the
  PostgreSQL gate into a pass.
- Static review then found the `created_at` grace, absent trigger association index, missing inline
  sticky/manual incident when the child detector is off, and non-owner digest-mutation gaps. Both
  local runs therefore remain historical/pre-remediation and authorize no enablement.
- At this historical checkpoint, `OutboundDeliveryTerminalTimelinePostgresTest` existed as source
  but no then-eight-report, zero-skip PostgreSQL/CI execution was recorded. The later docs-first
  expansion to ten reports is recorded above and is also RED/not executed.

### 10.4 Post-remediation Local Evidence — 2026-08-19

- Production/test-source compilation: **PASS**, `862` production and `282` test sources.
- Focused V39/V41 selector: **PASS**, `110/110`, zero failures/errors/skips.
- Directed LLM+JPA fixture selector: **PASS**, `21/21`, zero failures/errors/skips.
- Official ten-class PostgreSQL selector: `45/45 SKIPPED`. Both the normal attempt and an
  escalated/unsandboxed retry were denied access to `/var/run/docker.sock`; the latter reported
  `BindException: Permission denied`. Classification: **RED / NOT EXECUTED**.
- CI selector and fail-closed ten-XML assertion: aligned statically; **NOT EXECUTED**.
- Architecture selector: `22` tests, Clean Architecture `16/16` PASS, two known ModuleStructure
  baseline failures `shared → fiscal`, zero errors/skips.
- Final `clean test`: `1,323` tests, the same two baseline failures, zero errors and `56` skips.
- Frontend evidence remains: Vitest `80` files/`409` tests, TypeScript/lint/build PASS and
  Playwright/MSW `51` viewport executions. Global coverage, runtime English and backend-real remain
  open.
- Provider/pre-production fault injection, query plan/performance, zero-risk real backfill,
  backup/restore, rotation, DAST/HML, retention, canary and rollout remain blockers. All switches
  remain default-off.

### 10.5 Audit-role, Keycloak v2.6.1 and JDBC-remediation Evidence — 2026-08-22

- Backend RBAC/IAM/security selector: **PASS**, `144/144`, snapshot isolado sem Docker.
- Frontend full Vitest: **PASS**, `107` arquivos/`590/590`; TypeScript global e lint/Prettier
  focal passaram. O build de `39` rotas permanece evidência verde do checkpoint anterior.
- O `apiClient` remove header tenant fornecido pelo chamador: identidade tenant e Super Admin
  global não enviam `X-Tenant-ID`; somente Super Admin sob impersonação explícita envia o tenant
  selecionado.
- Guardas do backfill: **PASS**, `32/32`; arquitetura impactada: **PASS**, `29/29`.
- Keycloak v2.6.1: runtime JSON validator `38/38`, hardening test, realm-contract validator e
  start-dev/keyring test **PASS**; sintaxe e Compose sintético também passaram. Evidência estática
  somente, sem volume/sessão.
- O binding de `last_interaction` usa `Timestamp.from(reconciledLastInteraction)` no statement.
  O retry PostgreSQL bounded e o gate de cinco riscos permanecem **NOT EXECUTED / BLOCKED BY LOCAL
  HOST ACCESS**. Readiness continua falsa e API/allowlist permanecem fechadas.
- Volume/sessao Keycloak e backend-real permanecem **NOT EXECUTED / BLOCKED BY LOCAL
  PERMISSIONS**; HML, PRD e release permanecem **NOT EXECUTED / RED**.

### 10.6 Implementation-artifact Closure — 2026-08-22

- Exact legacy list/detail snapshots: **PASS LOCAL**, `ChatbotAdminControllerTest` `7/7`.
- Serial mixed backend selector: **56 PASS / 2 SKIPPED**, after compiling `953/365` sources; the
  skips are the two PostgreSQL performance tests blocked by Docker and are not passing evidence.
- Technical performance dataset v1 and full query-plan/p95 test: **SOURCE IMPLEMENTED /
  VERIFICATION PENDING**; the historical eleven-report checkpoint did not execute and the
  canonical CI job now requires 15 reports and rejects any skip.
- Backend-real harness and frontend CI commands: **IMPLEMENTED / STATICALLY VERIFIED LOCAL**;
  real sessions/A×B execution, remote pipeline, coverage and artifact review remain open.
- Eight-panel Grafana dashboard, eleven Prometheus alerts, histogram and finite incident/backfill
  metrics: **IMPLEMENTED / STATICALLY VERIFIED LOCAL** by the observability shell gate; live import,
  scrape/firing and notification delivery remain **NOT EXECUTED**.

### 10.7 Final Local Verification Evidence — 2026-08-23

- backend compile: **PASS**, `1.006` fontes;
- testes focados após as correções: **PASS**, `153/153`, sem
  failure/error/skip;
- arquitetura: **PASS**, `42/42`, sem failure/error/skip;
- observability contract, retention-policy writer allowlist e sintaxe
  YAML/JSON/shell: **PASS**;
- migration `tenant/V59`: byte-identical;
- gate PostgreSQL canônico: `15` classes e `15` XMLs descobertos, mas `72/72
  SKIPPED` por `Permission denied` em `/var/run/docker.sock`; classificação
  **RED / NOT EXECUTED** pela regra zero-skip;
- `./infra/scripts/validate-docs.sh`: **PASS** no rerun reconciliado.

Este checkpoint não autoriza executar as seções destrutivas deste runbook. As
caixas de PostgreSQL, runtime, route/provider, backup/restore e rollout permanecem
abertas. `OQ-AUD-GOV-001` continua sendo a única decisão humana.

### 10.8 v1.11 Mandatory Pre-activation Freeze — 2026-08-23

Não executar purge nem ativar receipt/callback até V62/V63/V44 e o gate alvo
18-class passarem sem skip. Fence pendente nunca é liberado por tempo/restart;
audits administrativos da rota não pertencem às quatro actions expurgáveis.
Saturação inbound retorna `503`/non-`2xx` para retry e faz zero efeito/callback
answer; não responder `2xx` em saturação transitória.

## 11. Completion Checklist

- [x] Local §4.0.2 tenant-path compatibility passes without documenting the concrete tenant UUID.
- [x] Section 4.0.3 eight-artifact audit-role contract and `fullScopeAllowed=false` scopes pass the
      static validator.
- [x] Sections 4.0.11–4.0.12 statically prove the cumulative Keycloak v2.6.1 invariants: Audit
      non-composite/sem herança no grafo realm+client, Service Account least privilege,
      first-bootstrap/ownership/fingerprint, zero secret in argv, bounded structural inventories,
      safe signals/session files and managed-only direct/client-scope mapper reconciliation.
- [ ] Persisted local Keycloak reconciliation is idempotent, assigns only the exact DEV
      superadmin, removes recovery identities and leaves HML/PRD untouched.
- [ ] Sessions are invalidated and a fresh token plus positive/negative impersonation evidence
      proves the strict `ROLE_TENANT_AUDIT` boundary without persisting credentials or JWTs.
- [ ] Local §4.0.2 backup/restore, owner-only keyrings, bounded backfill, five-risk readiness,
      legacy-off recheck, single-tenant API smoke and rollback checks have truthful evidence.
- [ ] Section 3 operational gates closed by named owners; não há decisão de governança aberta, apenas evidências operacionais obrigatórias.
- [x] Repository synthetic uploader and isolated full-bundle restore gate passed for three
      application databases and two Keycloak databases.
- [ ] Live encrypted-media backup and isolated restore drill passed with current owner evidence.
- [ ] Expand/compatibility/backfill/zero-plaintext evidence passed.
- [ ] Eligibility-only selection and durable plaintext/hash/key-ID/attestation/activity zero counters passed.
- [ ] V39 conversation/message invalidation, commit-safe ordinary re-attestation and live fail-closed readiness passed on PostgreSQL.
- [ ] Composite message-parent integrity, real-parent invalidation, one-row legacy CAS, targeted
      persistence-context sync and uniform readiness `Retry-After` passed on JPA/PostgreSQL.
- [ ] Every API operation fails closed when protection/readiness is absent.
- [ ] Durable/idempotent outbound attempt precedes provider and passes crash/retry/collision tests.
- [ ] V40 immutable association, active/expired dispatch fence, hard timeout invariant and late-sender CAS passed on PostgreSQL/provider fault injection.
- [ ] V41 timeline ack, sticky terminal-gap/association-conflict timestamps, bounded query-only
      detector and completed-fence owner proof passed, including `updated_at` grace, association
      index, child-off completion `MISSING`, forbidden non-owner digest mutation, crash and late
      materialization.
- [ ] Official 18-class PostgreSQL selector and its CI assertion produced exactly 18
      non-empty Surefire XMLs with tests and zero skips/errors/failures.
- [ ] Tenant V60/V61/V62/V63 and Omnichannel V43/V44 applied without checksum drift; receipt route provision,
      idempotency/conflict/deactivation, missing-route zero transition and tenant-local receipt
      revalidation passed with sanitized evidence while capability/API remain off.
- [ ] Retention Phase A used the immutable packaged `phase=A` marker, master/purge off, and applied
      V89 with checkpoint always `PENDING` and no policy rewrite/scan; the normalizer accepted a
      `NULL` high-watermark for a fresh/empty table, claims honored `dbNow >= nextAttemptAt`,
      positive post-scan offenders reset the checkpoint to restartable `PENDING`, and a zero proof
      plus exact fresh 256-bit/43-char cache-generation readback preceded `COMPLETE`.
- [ ] V90 and immutable packaged `phase=B` were added together only in a separately gated later
      release; rehearsal proved both branches: failed/uncommitted V90 permits Phase A recovery only
      after history verification, while committed V90 remains on B with master/purges off and a
      forward fix.
- [ ] Real-provider query/list probe is approved and exercised without any send capability.
- [ ] Legacy pending Modulith publications pass the REQ-00043 v1.26 two-read guard plus Omnichannel V44 PostgreSQL serialization evidence; this is a technical gate.
- [ ] Rotation and recovery exercised with independent keys.
- [ ] PostgreSQL tenant A×B, contract, performance and DAST gates passed.
- [x] Versioned dashboard/alert definitions have owners and no high-cardinality or PII dimensions.
- [ ] Dashboard/rules are provisioned, scraped and fired through the approved notification path.
- [ ] Wireframe and frontend gates passed before UI enablement.
- [ ] Canary and rollback evidence attached.

### 10.9 Superseded Local Control Checkpoint — 2026-08-23

- HML/PRD backend activation requires explicit Compose health `healthy`; state absent/`none`
  fails closed, does not start frontend and removes stale proxy/backend. Fake-Docker HML and PRD
  regressions passed locally; no container or external environment was started.
- The primary CI workflow now selects the HML activation regression and the conversation-audit
  backfill safety test explicitly. Shell syntax and the artifact/privacy workflow contract passed.
- Frontend Audit corrections passed `30/30` focused Vitest and `9/9` local Playwright executions
  over desktop, mobile-320 and tablet-768. This is synthetic/MSW evidence, not backend-real.
- The current static observability contract verifies fourteen dashboard panels and twenty owned
  alert rules. Import, scrape, firing/resolution and notification routing remain unchecked.
- Global frontend coverage remains below `70%`; PostgreSQL is still RED at `82/82 SKIPPED`.
  API, destructive jobs and provider capability remain off. `OQ-AUD-GOV-001` is still the only
  human decision; runtime, backup/restore, HML/PRD live, canary and release remain blocked.

### 10.10 Docs-first Final HMAC Safety Freeze — 2026-08-23

Esta seção **substitui o estado de fechamento corrente descrito em §10.9**. Não operar o lifecycle
por aquele checkpoint até implementar e provar cumulativamente:

- snapshots owner-only únicos de env e Compose efetivo por invocação HML/PRD;
- o mesmo image ID/digest pinado no initializer e backend mesmo após troca de tag/YAML;
- lock advisory crash-safe no volume desde antes dos snapshots até pending/target/state/cleanup,
  mais lock host do wrapper HML; concorrência rejeita sem mutação;
- staging DEV versionado `--stage-outbound-hmac-keyring FILE ACTIVE_KEY_ID`, aceitando `1..32`
  chaves válidas e preservando bootstrap fresh, sem iniciar Compose;
- add, switch e retirement em execuções mutuamente exclusivas — candidate com key nova e key
  removida simultaneamente é rejeitado —, approval one-shot, crash/retry conservador e zero output
  de path/ID/fingerprint/material/evidência.

Esses itens são gates técnicos. Não alteram a política REQ-00043 nem a única decisão humana
`OQ-AUD-GOV-001`. Todos os switches permanecem off e nenhuma execução externa está autorizada.

### 10.11 DEV Commit Receipt and Host Serialization Freeze — 2026-08-23

Não usar prepare-only como confirmação entre add e switch. O procedimento DEV obrigatório passa a
ser add → start/initializer → receipt autenticado → switch → start/initializer → novo receipt →
retirement. Switch/retirement rejeitam receipt ausente, stale ou adulterado. Um único lock host
owner-only serializa start/bootstrap, emissão do receipt e staging source→env; crash libera o lock
e deixa estado conservador. Antes de Compose, exportar o active/path canônico validado sob lock,
ignorando/rejeitando overrides divergentes de process env/`.env`; o teste usa `up` fake entre cada
transição. A validação Base64 é a mesma do initializer. Até as regressões passarem,
o staging DEV de §10.10 permanece **PENDING / NÃO OPERAR**.

### 10.12 HML Live-path and Effective Boundary Freeze — 2026-08-23

Após cada snapshot, revalidar o path vivo e rejeitar rename/symlink swap. Antes de pin/run, validar
no Compose efetivo entrypoint lifecycle, env exato, rede/hardening, source+approval RO sem criação,
target RW e o mesmo target RO/dependency no backend. Qualquer drift falha antes de `run`/`up`; o
wrapper de §10.9 continua não operável até os negativos por campo passarem.

### 10.13 Historical DEV sudo Canonical-environment Freeze — 2026-08-23

Checkpoint histórico, supersedido por §10.15: quando o host exigia sudo no
entrypoint, não usar `sudo -E` nem confiar na configuração global de `env_keep`.
O wrapper deve pedir preservação apenas de
`CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID` e
`CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE`, depois de canonizá-los sob o lock. Valores não
podem aparecer em argv. O procedimento add → commit → switch → commit → retirement só volta a ser
operável depois de regressão com sudo/env reset sintético comprovar o mesmo `up` e receipt do
caminho direto; falha de política sudo é fail-closed.

### 10.14 Historical Local Gate Checkpoint — 2026-08-23

A regressão DEV direta+sudo passou: o fallback transporta somente os nomes outbound active/path
canônicos, simula `env_reset`, executa o `up` completo e só então autentica o receipt. Portanto a
correção sudo congelada em §10.13 está implementada e não permanece pendente; a evidência é
sintética-local e não equivale a runtime Docker vivo.

O frontend global passou `145/145` arquivos e `876/876` testes, com V8 de `78,97%` em
statements/lines, `84,93%` em branches e `83,31%` em functions, sem redução de threshold ou
ampliação de excludes. O backend focado de métricas/Observation passou `79/79`, e
`conversation-audit-observability-test.sh` passou.

Os gates complementares frontend passaram: `npm run lint` com `0` erros e `61` warnings não
bloqueantes, `npx tsc --noEmit`, Prettier focal dos arquivos alterados e build isolado Next
`16.3.0` com `39/39` páginas, incluindo `/audit` e `/audit/[conversationId]`.

O changed-lines foi corrigido para usar temporário regular privado, `git apply` por path e cleanup
em `finally`. O contrato shell passou cleanup em sucesso e falha; o Prettier também passou. O gate
real ficou `PASS — N/A (valid diff contains no applicable executable lines)`, porque o diff atual
possui somente configuração, scripts e testes, sem linha executável aplicável no LCOV. Permanecem
imutáveis o threshold `70%`, o limite `64 MiB` e as exclusions.

O Docker escalado alcança o daemon, porém recebe `permission denied` em
`/var/run/docker.sock`; o usuário corrente não pertence aos grupos `docker` ou `podman`. O gate
PostgreSQL canônico continua RED com `18` classes/relatórios e `82/82` testes skipped.
Backend-real, readiness, backfill vivo, provider com estado persistido, HML, PRD, DAST, canary e
release continuam RED/NOT EXECUTED. API, expurgo e demais capabilities destrutivas/provider
permanecem off. `OQ-AUD-GOV-001` foi resolvida desde o REQ-00043 v1.19; o contrato
corrente é REQ-00043 v1.26 e o enforcement repo-only está
local-green e restore live continua RED. Nenhuma evidência técnica pendente vira decisão, `backupRestoreReady` ou aprovação
implícita.

### 10.15 Current Direct-Docker Host-bootstrap Checkpoint — 2026-08-25

O REQ-00045 e o TP-00019 substituem os checkpoints sudo de §10.13–§10.14. Antes
do primeiro Compose, o mantenedor executa o
[bootstrap canônico](local-development-host-bootstrap.md) para a identidade
explicitamente autorizada; a mesma invocação pode continuar um start allowlisted
em sessão nova. Os cinco entrypoints, health check e recovery Keycloak local não
chamam sudo, não alteram socket/ACL e falham fechado quando o usuário ainda não
possui acesso direto ao daemon.

No repositório, passaram o teste hermético do bootstrap — inclusive
idempotência, fresh-session e rollback de aplicação parcial —, as regressões
start/keyring, reset e hardening Keycloak, sintaxe, executable bits, scan dos sete
caminhos governados, CI e Compose base+DEV dummy. Nenhuma alteração real de
usuário/grupo, Docker ou host foi
executada. Assim, o artefato está **IMPLEMENTED / REPO-ONLY GREEN**, enquanto a
aplicação em cada host e os gates PostgreSQL/runtime/provider/HML/PRD permanecem
evidências operacionais separadas e RED/NOT EXECUTED.

O health check usa atribuições aritméticas status-safe para PASS/FAIL/WARN; a
regressão proíbe pós-incrementos que retornariam status falso na primeira
contagem sob `set -e`.

### 10.16 Current Repository-only Audit Closure Checkpoint — 2026-09-04

- `bash -n` nos scripts de close-only/rollback/startup: **PASS**;
- `bash infra/scripts/tests/activate-dev-conversation-audit-test.sh`: **PASS**, incluindo wrappers
  `timeout --signal=TERM --kill-after=2s`, Docker falso que ignora `TERM`, ausência de hang e
  tentativa fail-closed de stop+probe;
- `bash infra/scripts/tests/start-dev-bot-outbound-keyring-test.sh`: **PASS**;
- `bash infra/scripts/tests/conversation-audit-backfill-safety-test.sh`: **PASS**;
- Docker/PostgreSQL reais e smoke autenticado `/audit`: **RED / NOT EXECUTED**.

O lock contendido no close-only direto retorna nonzero sem tocar runtime/Docker. Stop+probe é prova
do supervisor, que deve tratar qualquer nonzero antes de retornar. Nenhum resultado desta seção
converte o `AUD-404-NOT_FOUND` observado em resolução runtime.

### 10.17 Current Docs-first Reopen Checkpoint — 2026-09-04

O checkpoint §10.16 permanece histórico, mas sua classificação final do supervisor foi
superseded por §4.0.21. Os testes de handoff spawn→PID/PGID e de Compose pós-promoção resistente a
`TERM` estão **PENDING FINAL EVIDENCE**. Não há nova evidência Docker/PostgreSQL, backfill/readiness
real ou smoke autenticado; todos continuam **RED / NOT EXECUTED**.

### 10.18 Current Interruptible-wrapper Reopen — 2026-09-04

O handoff SIGSTOP/PID/PGID/SID e as seis classes Compose bounded passaram em evidência hermética,
mas o wrapper foreground pode atrasar o trap. A classificação final continua reaberta até provas
com `INT/TERM` reais durante proof backend e frontend-up demonstrarem árvore resistente encerrada e
cleanup dentro da graça. O ambiente vivo continua indisponível: Docker sem permissão, bootstrap
canônico não interativo bloqueado por elevação e probes curl `7`/HTTP `000`; nenhum smoke
autenticado executou.

### 10.19 Current Repository-only Async-wrapper Closure — 2026-09-04

- `bash -n start-dev-bot.sh`: **PASS**;
- `bash -n infra/scripts/tests/start-dev-bot-outbound-keyring-test.sh`: **PASS**;
- `bash infra/scripts/tests/start-dev-bot-outbound-keyring-test.sh`: **PASS**, exit `0`, cerca de
  `68s`, `stable, bounded and fail-closed`;
- `bash infra/scripts/tests/activate-dev-conversation-audit-test.sh`: **PASS**;
- `bash infra/scripts/tests/conversation-audit-backfill-safety-test.sh`: **PASS**;
- revisão final do design de sinais: **PASS**, zero blocker/HIGH;
- Docker/PostgreSQL/backfill/readiness reais e smoke autenticado `/audit`: **RED / NOT EXECUTED**.

O operador não deve inferir resposta `200` dessas provas. A próxima ação continua sendo obter
acesso Docker pelo bootstrap autorizado e então executar o lifecycle real completo, sem comando
tardio de associação de grupo nem bypass sudo.

## 12. Change Log

| Version | Date | Author | Changes |
|---|---|---|---|
| `1.80` | 2026-09-09 | `Solicitante humano / Codex / @SecurityAgent / @DevOps-Agent` | Restringe o procedimento de administração da policy à role bruta `ROLE_SUPER_ADMIN` sob personificação ativa do tenant alvo; Tenant Admin, inclusive com Audit, não recebe retenção. Preserva as entradas históricas e não promove readiness, API ou runtime. |
| `1.79` | 2026-09-09 | `Codex / @Data-Agent / @DevOps-Agent / @SecurityAgent` | Reancora o procedimento na política final REQ-00043 v1.25/OpenAPI 1.1.1 e explicita a ativação em duas camadas: o toggle tenant liga/desliga a intenção para os dois datasets, mas a execução continua fail-closed sob master flag, dry-run, legal hold, backup/restore, capability e fences server-owned. |
| `1.78` | 2026-09-09 | `Codex / @Data-Agent / @DevOps-Agent` | Corrige o protocolo tenant-facing do PUT: usa `Policy-Version`/`If-Policy-Version` como precondição aplicativa versionada e não ETag HTTP. |
| `1.77` | 2026-09-09 | `Codex / @Data-Agent / @DevOps-Agent` | Distingue os dois ramos de falha V90: transação não committed e ausente do histórico permite recovery pela Phase A; V90 já aplicada proíbe rollback binário A e exige contenção no artifact/schema B, master/purges off e forward fix, sem editar Flyway history. |
| `1.76` | 2026-09-09 | `Codex / @Data-Agent / @DevOps-Agent` | Remove índices parciais da V89 metadata-only e operacionaliza checkpoint `PENDING/NORMALIZE`: passagens PK/keyset `NORMALIZE→VERIFY`, resume que preserva progresso, restart integral por offender e `COMPLETE/VERIFY` somente após zero mais barreira CSPRNG. |
| `1.75` | 2026-09-09 | `Codex / @Data-Agent / @DevOps-Agent` | Elimina o atalho fresh inseguro: V89 sempre cria `PENDING`, inclusive em DB vazio, sem scan; o normalizador aceita high-watermark `NULL` e exige prova zero mais rotação CSPRNG/readback antes de `COMPLETE`. |
| `1.74` | 2026-09-09 | `Codex / @Data-Agent / @DevOps-Agent` | Fecha o lifecycle executável V89/V90: geração Redis opaca CSPRNG 256-bit/Base64URL de 43 chars, inicialização `SETNX`, rotação `SET` com readback e sem reuso; claim respeita `dbNow >= nextAttemptAt`, offender pós-scan reinicia `PENDING`; marker `META-INF` imutável distingue artefatos Phase A/B e rollback para A exige master/purge off. |
| `1.73` | 2026-09-08 | `Codex / @Data-Agent / @DevOps-Agent` | Corrige o pipeline operacional do teto 180 com V89 estrutural/NOT VALID e normalizador application-level bounded; a inicialização do checkpoint dessa revisão foi substituída pelo contrato `PENDING` universal de v1.75. V90 permanece em release posterior após `COMPLETE`+zero. |
| `1.72` | 2026-09-08 | `Product Owner / Client / Codex / @Data-Agent / @SecurityAgent / @DevOps-Agent` | Atualiza o contrato operacional para máximo `180`, aba TenantAdmin-only, GET/preview/PUT, token/ETag/idempotência, execução assíncrona e transição V89/V90 segura de defaults/overrides legados; nenhuma flag ou migration foi executada. |
| `1.71` | 2026-09-05 | `Codex / @Data-Agent / @SecurityOAuth / @FrontendWeb / @TestAutomator / @DevOps-Agent` | Normalizada a busca `/audit`: binding JDBC temporal tipado, taxonomia causal 503, seletor DEV explícito em catálogos multi-tenant e Playwright Keycloak-real `1/1` com `POST /search = 200`, sem MSW e teardown da identidade efêmera. Search DEV verde; detail/reveal A×B, provider e gates externos seguem abertos. |
| `1.70` | 2026-09-04 | `Codex / @DevOps-Agent / @Data-Agent / @SecurityAgent / @TestAutomator` | Runtime DEV concluído: bootstrap `0`, backup/restore, backfill legacy/final, readiness durável, flags promovidas, locks zero, backend healthy/frontend running e POST sem token em `401 AUTH-401` em vez de exposure 404. Smoke `200` pela sessão humana segue pendente; HML/PRD/release intocados. |
| `1.69` | 2026-09-04 | `Codex / @DevOps-Agent / @SecurityAgent / @TestAutomator` | Máquina async reconciliada sem lost-wakeup: PID/starttime/PGID/SID, first-signal, polling antes do wait, término+drain e proofs child-only. Bash-n 2/2, startup ~68s, ativação/backfill e revisão sem HIGH/blocker passaram. Docker/backfill/readiness/smoke real seguem RED/NOT EXECUTED. |
| `1.68` | 2026-09-04 | `Codex / @DevOps-Agent / @SecurityAgent / @TestAutomator` | Terceiro HIGH congelado antes do patch: wrapper foreground pode adiar trap até o timeout. Compose pós-promoção deve rodar async com PID/PGID adquirido e wait interruptível; handler encerra árvore com TERM→CONT→grace→KILL→wait antes do close-only. Regressões reais proof/frontend-up ficam pendentes; runtime segue RED. |
| `1.67` | 2026-09-04 | `Codex / @DevOps-Agent / @SecurityAgent / @TestAutomator` | Reaberto docs-first o supervisor por dois HIGH: o primeiro `INT/TERM` deve sobreviver à janela spawn→PID/PGID e todo Compose pós-promoção deve usar sessão isolada, hard timeout e TERM→KILL. §10.16 fica histórico até regressão final; runtime e smoke `/audit` permanecem RED/NOT EXECUTED. |
| `1.66` | 2026-09-04 | `Codex / @DevOps-Agent / @SecurityAgent / @TestAutomator` | Reconciliados close-only, wrappers bounded, startup e backfill como implementados/verde hermético. Lock contendido direto não muta runtime/Docker; o supervisor trata nonzero com stop+probe. Corrigida a referência do plano para link canônico. Docker/PostgreSQL e smoke autenticado seguem RED/NOT EXECUTED; o 404 observado permanece FAIL runtime. |
| `1.65` | 2026-09-04 | `Codex / @DevOps-Agent / @SecurityAgent / @TestAutomator` | Antes do corretivo, §4.0.19 fecha dois HIGH: qualquer falha/sinal após possível promoção aciona close-only pinado e comprovado ou parada do backend; a árvore do ativador sempre recebe TERM, espera limitada/término dirigido e `wait`, preservando `INT=130`/`TERM=143` e impedindo promoção tardia. |
| `1.64` | 2026-09-04 | `Codex / @DevOps-Agent / @SecurityAgent` | Registrado antes do código o 404 persistente observado em `/audit` e reaberto o boundary DEV: UI somente pós-ativador, validação segura do overlay/config efetivos, cleanup do frontend em falha/interrupção, rerun canônico e smoke autenticado posterior. Nenhuma implementação/evidência nova é promovida neste freeze. |
| `1.63` | 2026-09-03 | `Codex / @DevOps-Agent / @SecurityAgent / @TestAutomator` | Revisão adversarial fechou downgrade de proteção no rerun e corrida do lock: estado é capturado sob ownership, writer protegido é preservado e contender/FIFO executam zero mutação. Regressões dedicadas passaram. |
| `1.62` | 2026-09-03 | `Codex / @DevOps-Agent / @SecurityAgent / @TestAutomator` | Reconciliada a implementação da ativação DEV automática: backup/restore, backfill `50 × 1`, readiness final, overlay/lock owner-only e rollback fail-closed passaram nas regressões locais. Docker/runtime e smoke autenticado permanecem NOT EXECUTED. |
| `1.61` | 2026-09-03 | `Codex / @DevOps-Agent / @SecurityAgent / @TestAutomator` | Documentada antes do código a correção do lifecycle DEV para o 404 de exposure: backup/restore local, backfill `50 × 1`, readiness legacy-off, overlay `0600`, promoção e rollback fail-closed no IP-BE-8.3.2.1-conversation-audit-local-activation-and-search-smoke. |
| `1.60` | 2026-08-25 | `Codex / @DevOps-Agent / @SecurityAgent / @TestAutomator` | Reconciliado o reparo docs-first dos contadores do health check sob `set -e`, com regressão focal verde. |
| `1.59` | 2026-08-25 | `Codex / @DevOps-Agent / @SecurityAgent / @TestAutomator` | O preflight direto passou a governar também health e recovery Keycloak locais; sete caminhos DEV e a regressão Keycloak estão verdes, sem execução do host. |
| `1.58` | 2026-08-25 | `Codex / @DevOps-Agent / @SecurityAgent / @TestAutomator` | Reconciliado o bootstrap local implementado: preflight Docker direto, compensação transacional, entrypoints sem sudo e testes/Compose dummy verdes; checkpoints sudo ficam históricos e host real continua não executado. |
| `1.57` | 2026-08-25 | `Codex / @DevOps-Agent / @SecurityAgent` | Documenta antes do código a substituição do `usermod`/path hardcoded e do fallback sudo pelo bootstrap local canônico anterior ao Compose; nenhuma associação real ou runtime foi executado. |
| `1.56` | 2026-08-24 | `Codex / @ObservabilityDev / @DevOps-Agent / @SecurityAgent / @TestAutomator` | Auditoria final separou implementação repo-only completa de evidência live RED, reconciliou o restore sintético 3+2 no checklist e corrigiu a referência normativa de 15 para 18 XMLs, preservando checkpoints históricos. |
| `1.55` | 2026-08-24 | `Codex / @SecurityAgent / @DevOps-Agent / @TestAutomator` | Reconciliado o fechamento repo-only: lock FD/inode, adoption-only sem cifra/upload, recipient histórico, falhas local/remota non-zero, zero pruning parcial, retry e revisão independente PASS. Controles live e `backupRestoreReady=false` permanecem RED. |
| `1.54` | 2026-08-24 | `Codex / @SecurityAgent / @DevOps-Agent / @TestAutomator` | Antes do patch final, o runbook tornou adoção mista fail-closed: diagnóstico completo, marcador falho byte-identical/fora do pruning, saída non-zero propagada pelo wrapper e regressão com zero cifra/upload. Gate repo-only segue reaberto; live permanece RED. |
| `1.53` | 2026-08-24 | `Codex / @SecurityAgent / @DevOps-Agent / @TestAutomator` | Gate local reaberto antes do patch: adoção somente pelo wrapper sob lock, adoption-only sem novo upload/retenção e recipient `age` por geração para rotação segura. Controles live e `backupRestoreReady=false` permanecem RED. |
| `1.52` | 2026-08-24 | `Codex / @Data-Agent / @SecurityAgent / @DevOps-Agent / @TestAutomator` | Reconciliado o enforcement repo-only local-green: suíte AWS falsa, restore sintético 3+2, sintaxe, timer UTC e diff PASS; `shellcheck` indisponível. Controles e restore live permanecem RED, sem mudar `backupRestoreReady=false` ou autorizar ambiente externo. |
| `1.51` | 2026-08-23 | `Codex / @Data-Agent / @SecurityAgent / @DevOps-Agent / @TestAutomator` | Congelado antes do hardening o contrato REQ-00043 v1.19: ID semântico estável, região/lifecycle/KMS estritos, retenção por `LastModified + 35d` e procedimento explícito/fail-closed para adotar marcadores legados sem edição manual. Ambiente live permanece não acessado e `backupRestoreReady=false`. |
| `1.50` | 2026-08-23 | `Produto / Codex / @Data-Agent / @SecurityAgent / @DevOps-Agent` | Resolvida docs-first OQ-AUD-GOV-001 pelo REQ-00043 v1.18 e adicionado o procedimento de evidência: storage cifrado/7 locais, S3 COMPLIANCE 35d/lifecycle 45d, agenda UTC, RPO/RTO, rotação, owners, verify semanal, restore mensal e invalidadores fail-closed. Nenhum ambiente foi acessado; `backupRestoreReady=false`. |
| `1.49` | 2026-08-23 | `Codex / @CodeGuardian / @DevOps-Agent / @SecurityAgent / @TestAutomator` | Reconciliados frontend global `145/145` e `876/876` com V8 acima de `70%`, lint `0` erros/`61` warnings, TypeScript, Prettier focal, build Next `39/39` e changed-lines `PASS/N/A` sem linhas executáveis LCOV aplicáveis, preservando `70%`, `64 MiB` e exclusions; backend métricas/Observation `79/79`, observabilidade shell e DEV direto+sudo verdes. Docker segue negado no socket e PostgreSQL `82/82` skipped; runtime/backup/rollout não foram promovidos e somente OQ-AUD-GOV-001 requer decisão humana. |
| `1.48` | 2026-08-23 | `Codex / @CodeGuardian / @DevOps-Agent / @SecurityAgent / @TestAutomator` | Antes do patch, congelado o fallback sudo mínimo: preservar só os nomes active/path outbound canônicos, sem `-E`/valores em argv, e provar o ciclo via env reset sintético. |
| `1.47` | 2026-08-23 | `Codex / @CodeGuardian / @DevOps-Agent / @SecurityAgent / @TestAutomator` | Antes dos reparos finais, documentados receipt/lock/Base64 DEV e re-stat/assertion integral HML, com negativos de receipt, concorrência, path swap e drift Compose antes de efeito. |
| `1.46` | 2026-08-23 | `Codex / @CodeGuardian / @DevOps-Agent / @SecurityAgent / @TestAutomator` | Antes do patch, reaberto o runbook para snapshots env/Compose, pin de image, lock crash-safe/concorrência, proibição de add+retirement e staging DEV multi-chave. O procedimento não deve ser operado até as regressões adversariais passarem. |
| `1.45` | 2026-08-23 | `Codex / @CodeGuardian / @DevOps-Agent / @SecurityAgent / @FrontendWeb / @TestAutomator` | Reconciliados health HML/PRD estrito com regressão `none`, seleção CI HML/backfill, frontend `30/30` + Playwright `9/9`, contrato de artefato e observabilidade corrente `14/20`; nada externo foi executado e os gates runtime/release seguem RED. |
| `1.44` | 2026-08-23 | `Codex / @CodeGuardian / @DevOps-Agent / @SecurityAgent / @TestAutomator` | Pós-freeze, PRD e o entrypoint HML cruzam boundary pré-init, forçam backend recreate, aguardam health e param tráfego stale em falha. Sintaxe, fake-Docker HML e gate PRD/Compose passaram; nenhum ambiente externo foi executado. |
| `1.43` | 2026-08-23 | `Codex / @CodeGuardian / @DevOps-Agent / @SecurityAgent / @TestAutomator` | Antes do patch, congelada a ativação in-memory do keyring: HML/PRD entram no boundary fail-closed antes do initializer e seguem com recriação forçada do backend → health → demais serviços; DEV já usa force-recreate. Runtime externo não executado. |
| `1.42` | 2026-08-23 | `Codex / @CodeGuardian / @DevOps-Agent / @SecurityAgent / @TestAutomator` | Precisada a evidência do bootstrap DEV: duplicidade não altera conteúdo, embora o preflight possa endurecer o modo do arquivo regular para `0600`; sem promoção de Compose/runtime. |
| `1.41` | 2026-08-23 | `Codex / @CodeGuardian / @DevOps-Agent / @SecurityAgent / @TestAutomator` | Pós-freeze, o manifesto HMAC usa snapshot privado único até one-shot/pending/commit e passou regressão adversarial; o bootstrap DEV fresh/existing gera/repara seis configs inbound 2/4/100, preserva valores, rejeita duplicidade e mantém 0600. Suítes e sintaxe verdes; Compose/runtime/drill não executados. |
| `1.40` | 2026-08-23 | `Codex / @CodeGuardian / @DevOps-Agent / @SecurityAgent / @TestAutomator` | Antes do patch, congelado o segundo TOCTOU: manifesto de retirement é capturado uma única vez em snapshot privado e esse mesmo arquivo governa validação, chaves, evidências, approvalId, one-shot, pending e estado; regressão adversarial troca o bind vivo sem poder alterar a aprovação consumida. |
| `1.39` | 2026-08-23 | `Codex / @DevOps-Agent / @SecurityAgent / @TestAutomator` | Antes do patch, congelado o reparo fresh/existing de `.env.dev.local` para as seis configurações inbound obrigatórias: defaults 2/4/100, preservação de valores existentes, ausente/vazio reparado atomicamente, duplicidade fail-closed, modo 0600 e teste ligado ao Compose `:?required`. |
| `1.38` | 2026-08-23 | `Codex / @CodeGuardian / @DevOps-Agent / @SecurityAgent / @TestAutomator` | Reconciliado o patch TOCTOU: snapshot privado único alimenta mapa/state/install e o teste adversarial prova coerência mesmo após troca do bind source. Gates lifecycle/DEV/HML/PRD/observabilidade/sintaxe verdes; runtime/drill real permanece aberto. |
| `1.37` | 2026-08-23 | `Codex / @CodeGuardian / @DevOps-Agent / @SecurityAgent / @TestAutomator` | Antes do patch, congelado o fechamento TOCTOU: validação, fingerprints, state e instalação derivam de um único snapshot owner-only; teste adversarial troca o bind source depois do snapshot e exige coerência ou falha sem efeito. |
| `1.36` | 2026-08-23 | `Codex / @DevOps-Agent / @SecurityAgent / @TestAutomator` | Antes do código, congelado o lifecycle gate outbound-HMAC multiambiente: add/read-old e switch em updates distintos, continuidade de material/IDs, tombstones, aprovação exata one-shot para retirement e journal recuperável após reboot, sem material/fingerprint em logs ou evidência. |
| `1.35` | 2026-08-23 | `Codex / @DevOps-Agent / @SecurityAgent / @TestAutomator` | Registrada evidência corretiva: compile/testCompile 1.015/392, retenção 20/20, receipts+saturação 90/90, rota/audit 18/18, arquitetura 29/29, frontend 172/172+TypeScript e contratos estáticos PASS. Gate canônico produziu 18 XMLs e ficou RED em 82/82 skipped; Docker escalado continuou sem permissão. API/flags permanecem off; runtime/provider/backup/release não promovidos. |
| `1.34` | 2026-08-23 | `Codex / @RequirementAgent / @DevOps-Agent` | Reconciliado o source V62/V63/V44/inbound como implementado e verificação pendente; ownership de chaves e identidades A×B/DAST foram classificados explicitamente como evidências técnicas/operacionais, não novas decisões humanas. OQ-AUD-GOV-001 permanece a única decisão aberta; alvo 18-report/runtime/release RED. |
| `1.33` | 2026-08-23 | `Codex / @DevOps-Agent / @SecurityAgent / @Data-Agent` | Runbook reconciliado docs-first ao REQ-00043 v1.11: V62/V63/V44, fence sem auto-release, quatro actions exatas, audits de rota preservados e saturação non-2xx. Gate 15-class/72 skipped permanece histórico; alvo 18-class/runtime/backup/release RED. Docs validation passou no rerun. |
| `1.32` | 2026-08-23 | `Codex / @TestAutomator / @DevOps-Agent` | Registrada a evidência final local: compile 1.006, focado 153/153, arquitetura 42/42, observabilidade/writer allowlist/sintaxe PASS e V59 byte-identical. O gate descobriu 15 classes/XMLs, mas permaneceu RED em 72/72 skipped por permissão Docker; nenhum passo destrutivo/runtime/provider/backup foi autorizado. |
| `1.31` | 2026-08-23 | `Codex / @ImplementerCore / @Data-Agent / @AdapterDev / @SecurityAgent / @DevOps-Agent` | Reconciliado o REQ-00043 v1.9: V60/V61/Omnichannel V43 e retenção/receipts/freshness são source implemented/verification pending; documentado o ciclo SUPER_ADMIN da rota receipt local e atualizado o gate autoritativo para 15 classes/XMLs. API/flags/capability/runtime/release seguem RED e somente OQ-AUD-GOV-001 exige decisão humana. |
| `1.30` | 2026-08-23 | `Codex / @ImplementerCore / @Data-Agent / @SecurityAgent / @DevOps-Agent` | Reconciliada a implementação local docs-first do REQ-00043: V59/V42, política durável/cache não autoritativo, expurgos bounded, ledger PII-free, dry-run pós-restore e freshness autenticada. Todos os switches destrutivos permanecem off; PostgreSQL/runtime e a decisão DevOps de backup/restore continuam RED. |
| `1.29` | 2026-08-23 | `Codex / @DevOps-Agent / @ComplianceAgent / @ObservabilityDev` | Centralizadas no REQ-00043 as decisões de retenção, anonimização, receipts, dataset/SLO e multiambiente; backup permanece único ponto humano aberto de DevOps/SRE, enquanto implementação e evidência continuam gates RED. |
| `1.28` | 2026-08-22 | `Codex / @DevOps-Agent / @SecurityAgent` | Registrado o pré-requisito exato do host: stack responde, mas o usuário corrente não integra o grupo `docker` visto pelo Snap e `.env.dev.local` segue owner-only sob `nobody`; documentados comandos mínimos sem afrouxar permissões ou expor segredos. Runtime Audit permanece NOT EXECUTED/API off. |
| `1.27` | 2026-08-22 | `Codex / @Data-Agent / @TestAutomator` | Corrigido o procedimento operacional canônico para executar e exigir onze classes/XMLs, incluindo `ConversationAuditPerformancePostgresTest`; o gate Docker/PostgreSQL continua NOT EXECUTED e nenhum checkpoint histórico de dez classes foi promovido. |
| `1.26` | 2026-08-22 | `Codex / @ObservabilityDev / @Data-Agent / @TestAutomator` | Reconciliados snapshots legados 7/7, dataset/query-plan técnico e CI de onze relatórios, harness backend-real fail-closed e observabilidade com oito painéis/onze alertas. Gate shell e compilação 953/365 com 56 passes passaram; 2 testes PostgreSQL e toda evidência viva permanecem NOT EXECUTED. |
| `1.25` | 2026-08-22 | `Codex / @Data-Agent / @DevOps-Agent / @TestAutomator` | Fixados em código/configuração os limites do piloto `batch-size 1..50`, exatamente um lote por invocação, timeout `1..300s` e `restart: no`; seletor focal 30/30 e safety shell passaram. Execução PostgreSQL/readiness permaneceu bloqueada. |
| `1.24` | 2026-08-22 | `Codex / @ImplementerCore / @FrontendWeb / @SecurityOAuth / @TestAutomator` | Reconciliados os reruns finais: backend RBAC/IAM/security 144/144, frontend completo 107/590, backfill 32/32 e arquitetura 29/29; registrado o confinamento de `X-Tenant-ID`. Runtime volume/sessão/backfill/readiness/backend-real continua bloqueado, API off. |
| `1.0` | 2026-08-18 | `@AgentOrchestrator / @ObservabilityDev / @SecurityAgent` | Initial pre-implementation runbook with keys, bounded backfill, release gates, monitoring and rollback. |
| `1.1` | 2026-08-18 | `@ObservabilityDev / @DevOps-Agent / @SecurityAgent` | RED checkpoint reconciled; eligibility-only backfill, durable readiness, cumulative API gates, pre-effect outbound attempt and strict telemetry rules added. |
| `1.2` | 2026-08-18 | `@ObservabilityDev / @DevOps-Agent / @SecurityAgent` | Reconciled immutable V35 plus additive V36, default-off boundaries, outbound reconciliation/rotation and legacy pending-publication blockers, and commands that reject Docker skips as green evidence. |
| `1.3` | 2026-08-18 | `@ImplementerCore / @AdapterDev` | Antes da implementação, especificados V37, chave default-off, claim/lease bounded por tenant, backoff/exhaustão, outcomes conclusivos, restart, timeline monotônica e telemetria sem PII. |
| `1.4` | 2026-08-18 | `@ObservabilityDev / @SecurityAgent` | Antes do código, especificados keyring outbound dedicado, active+read-old candidates, fail-closed defaults e rotação em duas fases sem bulk reindex/raw material. |
| `1.5` | 2026-08-18 | `@ImplementerCore / @Data-Agent` | Antes do código, congelados V38 e o seletor eligibility-only: atestação não derivada de PII, invalidação fail-closed, cursor/recheck bounded, ciphertext byte-stable e contadores duráveis de atestação/atividade. |
| `1.6` | 2026-08-18 | `@ImplementerCore / @SecurityAgent / @TestAutomator` | Reconciliados V32–V38, keyring outbound active/read-old e completion loop default-off; registrada evidência compile/focado verde e mantidos RED os gates full/PostgreSQL, provider real e drills de rotação/fault injection. |
| `1.7` | 2026-08-18 | `@ImplementerCore / @SecurityAgent / @TestAutomator` | Registrado gate focado final 73/73 com router 29/29 e descarte fail-closed de ID não confiável; corrigidos os estados de aprovação do wireframe/readiness, o preflight da reconciliação e o inventário dos três keyrings, sem promover PostgreSQL ou rollout. |
| `1.8` | 2026-08-18 | `@ImplementerCore / @AdapterDev / @SecurityAgent / @ObservabilityDev` | Antes do código, inventariadas V32–V40 e congelados V39 continuous/commit-safe readiness e V40 provenance imutável/provider-call fence/hard timeout/CAS; preflight continua default-off e os novos gates ficam RED sem alterar 73/73 histórico. |
| `1.9` | 2026-08-19 | `@ImplementerCore / @AdapterDev / @SecurityAgent / @ObservabilityDev / @CodeGuardian` | Antes do novo código, congelados reparos V39 e V41 com ack/timestamps sticky, detector subordinado default-off/query-only e fence digest; V40 passou a cutover stop/drain obrigatório. Registrados 86/86 históricos e 24/24 PostgreSQL skipped sem promover provider/release. |
| `1.10` | 2026-08-19 | `@ImplementerCore / @AdapterDev / @SecurityAgent / @ObservabilityDev / @TestAutomator` | Reconciliado V41 local como RED/pré-remediação; congelados antes do patch grace/candidato por `updated_at`, índice exato de associação, sticky/manual no completion `MISSING` mesmo com child off e digest apenas no CAS owner `PENDING→terminal`. O gate oficial/CI agora exige oito XMLs e `OutboundDeliveryTerminalTimelinePostgresTest`. Preservados historicamente `105 = 102 + 3 falhas de fixture` e o JPA `13/13`; nenhuma promoção. |
| `1.11` | 2026-08-19 | `@ImplementerCore / @Data-Agent / @AdapterDev / @SecurityAgent / @ObservabilityDev / @TestAutomator` | Antes de qualquer alteração de CI/código, expandido o gate PostgreSQL oficial V39/V41 de oito para dez classes/XMLs com `JpaConversationRepositoryAdapterPostgresTest` e `ConversationAuditReadinessToctouPostgresTest`. O gate permanece RED/não executado; o job CI de oito relatórios ainda precisa ser alinhado. |
| `1.12` | 2026-08-19 | `@ImplementerCore / @Data-Agent / @AdapterDev / @SecurityAgent / @ObservabilityDev / @TestAutomator` | Reconciliado checkpoint pós-remediação: V39/V41 implemented local/partially evidenced por compile 862/282, focado 110/110 e fixtures LLM+JPA 21/21. PostgreSQL oficial permaneceu 45/45 skipped após retry escalado por permissão do Docker socket; arquitetura/full/release RED, CI alinhado mas não executado e switches default-off. |
| `1.13` | 2026-08-21 | `Product Owner / Client / @ImplementerCore / @Data-Agent / @FrontendWeb / @SecurityAgent / @ObservabilityDev / @TestAutomator` | Antes do runtime, congelado §4.0.2 para piloto Docker-local: schema tenant-path PostgreSQL UUID separado, backup/restore, três keyrings owner-only, proteção-on/API-off, legacy/backfill <=50×1, cinco riscos+failed zero, legacy-off/recheck, allowlist unitária/API-on, smoke sem PII e rollback forward-only. Ledger marca tudo NOT EXECUTED; HML/PRD/provider/release RED. |
| `1.14` | 2026-08-22 | `@SecurityOAuth / @DevOps-Agent / @SecurityAgent / @ObservabilityDev` | Antes de JSON/script/codigo/runtime, congelado §4.0.3: `ROLE_TENANT_AUDIT` nos oito artefatos, scope explicito com `fullScopeAllowed=false`, superadmin somente DEV, reconciliacao idempotente do volume persistido e invalidacao/renovacao de sessao. Toda a extensao permanece NOT IMPLEMENTED/NOT EXECUTED; HML/PRD nao autorizados. |
| `1.15` | 2026-08-22 | `Codex / @SecurityOAuth / @DevOps-Agent / @TestAutomator` | Reconciliados software Audit e tenant-path como implementados/focados localmente, Keycloak versionado como estaticamente verificado e correcao JDBC como implementada. Volume/sessao, retry/readiness, backend-real e ambientes externos permanecem NOT EXECUTED; API off. |
| `1.16` | 2026-08-22 | `Codex / @SecurityOAuth / @DevOps-Agent / @SecurityAgent` | Antes de novo patch executavel, congelado §4.0.5: Audit non-composite/sem heranca admin, remocao fail-closed de drift, reconciliacao forcada da Service Account para allowlist minima sem early-success e deteccao de tenant_id tambem via client scopes. Novo gate PENDING IMPLEMENTATION/EVIDENCE; runtime/release continuam RED. |
| `1.17` | 2026-08-22 | `Codex / @Data-Agent / @SecurityAgent / @DevOps-Agent` | Antes de novo código/runtime, congelado §4.0.6: backfill exige exatamente um tenant-id canônico e registrado, resolve somente seu datasource, mantém API allowlist independente e falha sem UUID/efeito para alvo ausente, inválido ou indisponível. Gate AC-AUD-056 PENDING; API off. |
| `1.18` | 2026-08-22 | `Codex / @Data-Agent / @SecurityAgent / @DevOps-Agent` | Antes do runtime, congelado §4.0.7: legacy-read desliga primeiro; backfill continua `50 x 1` até readiness pronta/cinco zeros no fingerprint definitivo; só depois backfill desliga e o live recheck ocorre com API off. AC-AUD-057 PENDING. |
| `1.19` | 2026-08-22 | `Codex / @Data-Agent / @SecurityAgent / @DevOps-Agent` | Antes de código/runtime, congelado §4.0.8: override Compose final com restart no, uma invocação explícita por lote e timeout transação/statement `1..300s`; falha reverte sem auto-retry e Actuator não substitui readiness Audit. AC-AUD-058–059 PENDING. |
| `1.20` | 2026-08-22 | `Codex / @SecurityOAuth / @SecurityAgent / @DevOps-Agent` | Antes de novo patch, congelado §4.0.9: zero segredo em argv host/container, paginacao administrativa fail-closed, prova exata no init normal e reconciliacao segura de mappers/scopes geridos. v2.6 e runtime permanecem PENDING. |
| `1.21` | 2026-08-22 | `Codex / @ImplementerCore / @Data-Agent / @SecurityAgent / @DevOps-Agent / @TestAutomator` | Reconciliado §4.0.10: target único/direto, A/B zero interação, timeout statement+transaction/rollback e override restart-no passaram 32/32 + shell/Compose. Lote/readiness vivo e Keycloak v2.6 permanecem bloqueados; API off. |
| `1.22` | 2026-08-22 | `Codex / @SecurityOAuth / @SecurityAgent / @DevOps-Agent` | Reconciliado §4.0.11: hardening Keycloak v2.6 implementado e estaticamente verde nos gates de hardening, realm contracts e start-dev/keyring. Preservados os freezes históricos; volume persistido, sessão/token novos, backfill/readiness e smoke continuam NOT EXECUTED por permissões locais, com API off e HML/PRD intocados. |
| `1.23` | 2026-08-22 | `Codex / @SecurityOAuth / @SecurityAgent / @DevOps-Agent / @TestAutomator` | Reconciliado §4.0.12: first-bootstrap/ownership, fingerprint não interativo, recovery estrutural, grafo realm+client, parser JSON Bash puro/mounts, sessões/sinais seguros e fingerprint obrigatório também para mapper direto. Quatro gates, 38 cenários, sintaxe e Compose sintético passaram; runtime vivo continua bloqueado/API off. |
