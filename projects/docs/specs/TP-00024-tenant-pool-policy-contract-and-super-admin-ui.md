---
document_id: TP-00024
primary_nature: Plano
objective: Coordenar o contrato HTTP backend e a implementação frontend local da administração de política de pool por tenant, incluindo o visual textual aprovado, sem antecipar efeitos externos do runtime.
scope: Contratos backend de transporte sem endpoint, boundary HTTP frontend de plataforma, tipos, schemas, serviço, estado remoto, UI Super Admin aprovada, testes locais e documentação.
non_objectives: Implementar store/reconciler/pool runtime fora do TP-00023, expor endpoint funcional antes de seus predecessores, extrapolar o wireframe aprovado, alterar infra/, instalar dependência, executar deploy, acessar produção ou usar dados reais.
owner: Backend, Frontend, Arquitetura e Qualidade
status: Completed
version: 1.4
date: 2026-08-27
last_reviewed: 2026-08-28
keywords: tenant, pool-policy, super-admin, frontend, contrato-http, etag, impersonacao
related_files: ../../backend/docs/adrs/ADR-0052-parametros-pool-conexao-por-tenant.md, do../../product/requirements/REQ-00047-super-admin-tenant-pool-policy-administration.md, do../../product/requirements/REQ-00048-tenant-pool-policy-cache-isolation-resilience.md, do../../product/use-cases/UC-00046-super-admin-tenant-pool-policy-management.md, docs/analysis/ANL-00048-req-00047-tenant-pool-policy-adherence.md, docs/analysis/ANL-00049-req-00047-frontend-tenant-pool-policy-adherence.md, TP-00023-tenant-pool-policy-administration.md, ../../backend/docs/specs/IP-BE-23.0.2-tenant-pool-policy-http-contract.md, ../../frontend/docs/specs/IP-FE-23.3.1-tenant-pool-policy-super-admin-ui.md
code_references: backend/src/main/java/br/com/duoset/saas_service/contexts/tenant/, backend/src/test/java/br/com/duoset/saas_service/contexts/tenant/, frontend/src/lib/apiClient.ts, frontend/src/lib/__tests__/apiClient-tenant-header.test.ts, frontend/src/types/, frontend/src/schemas/, frontend/src/services/, frontend/src/hooks/queries/, frontend/src/app/(dashboard)/tenants/[id]/
principal_statement: Contrato backend, frontend local e integração autenticada backend-real estão implementados e verdes; infraestrutura externa, deploy e produção continuam fora do escopo.
---

# TP-00024 — Contrato da política de pool e UI Super Admin

## 1. Autoridade e relação com o runtime

Em 2026-08-27, instrução humana explícita solicitou os Implementation Plans
frontend/backend faltantes e, após sua conclusão documental, o início da
implementação local. Essa instrução amplia para frontend local o envelope já
aprovado no ADR-0052 e REQ-00047, sem autorizar infraestrutura, deploy, produção,
dados reais ou implementação visual anterior ao wireframe aprovado.

Este TP não substitui o
[TP-00023](TP-00023-tenant-pool-policy-administration.md). O TP-00023 continua
governando store, cache da política, lifecycle do pool, capacidade, membership,
reconcile, API funcional e rollout. Este plano fecha a fronteira consumida pelo
frontend e organiza a UI sem fingir que o runtime está pronto.

## 2. Planos filhos

| Ordem | Implementation Plan | Entrega | Estado |
| ---: | --- | --- | :---: |
| 1 | [IP-BE-23.0.2-tenant-pool-policy-http-contract](../../backend/docs/specs/IP-BE-23.0.2-tenant-pool-policy-http-contract.md) | Requests e resource/operation concluídos, sem controller/store/runtime | ✅ Done |
| 2 | [IP-FE-23.3.1-tenant-pool-policy-super-admin-ui](../../frontend/docs/specs/IP-FE-23.3.1-tenant-pool-policy-super-admin-ui.md) | Boundary, tipos/schemas, service/query, UI aprovada e E2E backend-real concluídos | ✅ Done |

## 3. Matriz de execução

> Legenda: ⬜ Pending · 🔄 In Progress · ✅ Done · ⏸️ Blocked

| Etapa | Entrega | Estado | Gate |
| --- | --- | :---: | --- |
| 24.0 | Reconciliar ADR, RF/NFR, UC e análise frontend | ✅ | ADR-0052 v1.6, REQ-00047 v1.3 e ANL-00049 |
| 24.1 | Persistir e indexar os dois IPs | ✅ | Validação documental passou |
| 24.2 | Implementar contrato backend estrutural | ✅ | 9 focais + 29 arquiteturais verdes; sem endpoint |
| 24.3 | Implementar boundary frontend `platform` e contratos estritos | ✅ | 12 focais + suíte 951/951; sem visual/backend-real |
| 24.4 | Implementar metadata/ETag, service, query keys e MSW contract tests | ✅ | 23 testes de boundary/schema/service e 8 testes de query no conjunto focal |
| 24.5 | Aprovar wireframe da aba, edição, operação e rollback | ✅ | Aprovação humana explícita registrada no IP-FE-23.3.1-tenant-pool-policy-super-admin-ui v1.2 |
| 24.6 | Implementar UI acessível/i18n | ✅ | Aba/diálogos pt-BR, RBAC, estados e axe; suíte 980/980 e build verde |
| 24.7 | Integrar backend-real e E2E | ✅ | Playwright autenticado `1/1`, com GET/ETag, PUT, conflito, rollback, 401/403, impersonação e A/B |

## 4. Contrato transversal escolhido

### 4.1 Isolamento de transporte

- alvo administrativo vem somente de `tenantId` UUID no path;
- requests para a API de plataforma nunca enviam `X-Tenant-ID`;
- impersonação ativa bloqueia o request frontend antes de `fetch`;
- backend repete a defesa e rejeita header/contexto conflitante;
- nenhuma thread HTTP administrativa abre banco dedicado do tenant.

### 4.2 Snapshot materializado

O contrato inicial tipa `profileSource`, `minimumIdle`, `maximumPoolSize`,
`connectionTimeout`, `validationTimeout`, `idleTimeout`, `maxLifetime` e
`keepaliveTime`. Profiles são proveniência de cópia; o payload sempre contém os
valores completos. Cache do REQ-00048 e dados JDBC não fazem parte do transporte.

### 4.3 Concorrência e operação

O contrato completo usará `ETag`/`If-Match`, `Idempotency-Key` e `reason`.
`PUT`/rollback retornam `202` com operação pendente. O frontend não fará retry
automático de mutações e nunca converterá aceitação em convergência. Rollback
cria nova revisão a partir de snapshot anterior.

## 5. Fases autorizadas e bloqueadas

### Checkpoint A — concluído

- contratos backend sem controller, store, segurança runtime ou feature flag;
- `apiClient` com modo explícito `platform`, default `automatic` compatível;
- tipos e schemas frontend estritos dos campos normativos;
- testes focais que provam ausência de header, impersonação fail-closed,
  compatibilidade e rejeição de payload inválido;
- documentação e atualização de evidências.

### Checkpoint B — concluído

- API client que preserve `ETag` de respostas de sucesso;
- service, parsing de Problem Details específico, query keys A/B e mutations;
- MSW apenas como contract test, sem habilitação runtime acidental.

### Checkpoint C — concluído conforme wireframe aprovado

- aba “Pool de conexões” no detalhe do tenant;
- leitura, edição do snapshot completo, acompanhamento de operação e rollback;
- loading, empty, forbidden, conflict, capacity, invalid, pending, degraded,
  failed e converged;
- i18n no catálogo pt-BR ativo, foco, labels, live regions e contraste; en-US
  continua fora do runtime até o rollout app-wide já governado pelo projeto.

### Checkpoint D — concluído

- integração backend-real, E2E e prova de autorização ponta a ponta concluídas
  com serviços locais efêmeros e dados sintéticos;
- nenhum deploy ou operação externa é inferido.

## 6. Estratégia de validação

| Camada | Evidência mínima |
| --- | --- |
| Documentação | `./infra/scripts/validate-docs.sh` verde antes do código |
| Backend contract | testes focais Maven dos tipos/validações; suíte impactada quando aplicável |
| Frontend boundary/schema | Vitest focal, typecheck e lint dos arquivos afetados |
| UI local | Testing Library + axe + i18n + estados; wireframe aprovado referenciado |
| Integração | MSW contract tests e E2E backend-real sem segredo/dado real |

Falha preexistente de suíte deve ser registrada com contagem e arquivo; não pode
ser tratada como sucesso. Teste dependente de Docker só é evidência quando
executado de fato.

## 7. Riscos e rollback

| Risco | Controle | Rollback local |
| --- | --- | --- |
| API platform carregar impersonação | modo `platform` fail-closed e teste sem `fetch` | remover consumidores do modo novo; default automático permanece |
| contrato prematuro divergir do backend | limitar A aos campos normativos e bloquear service | ajustar tipos antes de endpoint funcional |
| UI expor cache/JDBC | allowlist e schema estrito | não renderizar campos fora do snapshot |
| cache frontend misturar A/B | query key com target + contexto global | invalidar/remover namespace da capability |
| `202` parecer concluído | estados desired/committed/rollout separados | voltar à representação somente leitura |
| visual sem aprovação | gate documental explícito | não criar ou remover o slice visual não autorizado |

Não existe rollback destrutivo, down migration, alteração de pool ou limpeza
global de cache neste TP.

## 8. Handoff e critério de conclusão

O plano está `Completed` no recorte repository-local. A integração
backend-real/E2E registrou arquivos, comandos e resultados; a conclusão não
declara readiness de ambiente, deploy ou produção.

### 8.1 Checkpoint de implementação — 2026-08-28

- documentação: `validate-docs.sh` passou com 662 Markdown, 30 diretórios e 642
  artefatos indexados no checkpoint anterior ao registro desta evidência;
- backend: contrato estrutural concluído com `9/9` testes focais e `29/29` gates
  Modulith/Clean Architecture;
- frontend: boundary, metadata/ETag, schemas completos, service, query/mutations,
  MSW local e UI concluídos com `41/41` focais, typecheck/lint/format/build verdes
  e suíte completa `153/153` arquivos, `980/980` testes;
- a UI implementa snapshot desired/committed, operação, capacidade agregada,
  rollout, edição integral e rollback, exclusiva a Super Admin efetivo global;
- E2E backend-real: `1/1 PASS` contra PostgreSQL, Redis, Keycloak e backend locais
  efêmeros, com scanner de privacidade do artefato `PASS`;
- o backend expõe `ETag` e aceita `If-Match` no CORS, lacuna detectada e corrigida
  pelo browser real;
- nenhum serviço externo, deploy ou efeito de produção foi criado; o corretivo
  backend V69 posterior permanece controlado pelo TP-00023 e não reabre este TP
  frontend.

## 9. Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.4 | 2026-08-28 | Codex | Conclui 24.7 com E2E autenticado backend-real 1/1, A/B, 401/403, conflito, rollback e scanner de privacidade; encerra o TP no recorte repository-local. |
| 1.3 | 2026-08-28 | Codex | Conclui 24.4 e 24.6 com contrato/service/query/MSW/UI, 980/980 testes e build local; mantém apenas 24.7 bloqueado pelos predecessores PostgreSQL/runtime. |
| 1.2 | 2026-08-27 | Owner humano / Codex | Registra aprovação do wireframe textual, conclui 24.5 e libera 24.4/24.6 em sequência; integração externa continua gated. |
| 1.1 | 2026-08-27 | Codex | Conclui os checkpoints 24.1–24.3 com evidência verde e mantém service, UI e integração bloqueados. |
| 1.0 | 2026-08-27 | Owner humano / Codex | Cria o coordenador transversal, libera somente contratos não visuais e mantém serviço, UI e E2E atrás de seus gates. |
