---
document_id: TP-00054
primary_nature: Plano
objective: Reconciliar a autonomia auditável do SUPER_ADMIN com a remoção definitiva da aprovação independente em Billing.
scope: PRD-00001, ADR-0050, requisitos e UCs de Billing, contratos Active focais, quatro IPs atômicos e reconciliação repository-local de backend/frontend.
non_objectives: Deploy, ambiente, credenciais, provider externo, cobrança real, efeito financeiro, publicação/ativação automática, mudança de path/payload, remoção histórica, MFA, RBAC ou alçada.
owner: Owner do produto/projeto e Arquitetura
status: In Progress
date: 2026-09-10
version: 1.8
last_reviewed: 2026-09-10
keywords: billing, super-admin, checker-legado, auditoria, transicao-explicita, drafts
related_files: ../../docs/prds/PRD-00001-billing-enterprise.md, ../../backend/docs/adrs/ADR-0050-rbac-sod-aprovacoes-financeiras.md, do../../product/requirements/REQ-00042-enterprise-multitenant-billing-invoicing.md, do../../product/requirements/REQ-00054-super-admin-unified-billing-price-version.md, do../../product/requirements/REQ-00056-payment-provider-management-observability.md, docs/contracts/billing-super-admin-decisions-v1.openapi.yaml, docs/contracts/payment-provider-console-v1.openapi.yaml, ../../backend/docs/specs/IP-BE-54.1.1-super-admin-catalog-self-decision.md, ../../backend/docs/specs/IP-BE-54.1.2-super-admin-invoice-self-decision.md, ../../backend/docs/specs/IP-BE-54.1.3-super-admin-provider-self-decision.md, ../../frontend/docs/specs/IP-FE-54.2.1-super-admin-billing-decision-copy.md
code_references: backend/src/main/java/br/com/duoset/saas_service/contexts/billing/, backend/src/main/resources/db/migration/tenant/, backend/src/main/resources/db/migration/billing/, frontend/src/components/billing/, frontend/src/i18n/messages/pt-BR/
principal_statement: Operações SUPER_ADMIN de Billing não exigem segundo aprovador em DEV, HML ou PRD; drafts e aprovações antigas são preservados como histórico não bloqueante e toda publicação permanece explícita.
---

# TP-00054 — Remoção da aprovação independente no Billing

## 1. Objective and decision

Materializar a decisão humana de 2026-09-10 segundo a qual o mesmo usuário
`SUPER_ADMIN` pode aplicar, editar, validar, ativar, desativar e publicar itens de
Billing dentro de sua alçada, sem depender de outro usuário na fase inicial.

Não haverá segundo aprovador agora nem futuramente neste escopo, em DEV, HML ou
PRD. Qualquer `SUPER_ADMIN` autorizado registra e executa a transição dentro de
sua alçada; o log identifica o ator efetivo.

A estratégia de menor impacto preserva drafts e registros antigos de aprovação
sem reescrita, remoção ou status novo. Eles tornam-se histórico não bloqueante. O
workflow `produto → preço → oferta` permanece, e publicar continua sendo ação
manual explícita, nunca automática.

## 2. Boundaries

- Esta mudança não concede authority fora da alçada do ator.
- Ação sem segundo usuário continua autenticada, autorizada, versionada e auditada.
- MFA, tenant/purpose scope, idempotência, optimistic concurrency e imutabilidade
  não são removidos por inferência; qualquer alteração própria exige decisão separada.
- Justificativa permanece obrigatória somente onde já é exigida hoje; esta decisão
  não cria nova obrigatoriedade para operações simples.
- Provider externo, cobrança real, rollout e mutação ambiental permanecem fora do escopo.
- A execução repository-local limita-se aos quatro IPs atômicos, depois de cada
  um obter `READY` contra os contratos Active exatos.

## 3. Execution tracking

| ID | Entrega | Estado | Evidência/condição de saída |
| --- | --- | --- | --- |
| `TP-00054-T01` | Registrar intenção e gate no PRD-00001 | Done | PRD-00001 v1.10 está Validated para autonomia, ambientes, preservação e evidência repository-local. |
| `TP-00054-T02` | Remover checker de D-13/ADR-0050 e reconciliar REQ-00042, REQ-00054, REQ-00056 e REQ-00059 | Done | Bindings D-13.3 classificam o modelo anterior como legado não normativo para SUPER_ADMIN. |
| `TP-00054-T03` | Reconciliar UCs de catálogo, contrato, invoice, provider e operações financeiras | Done | Os onze casos de uso relacionados possuem binding específico e versões indexadas; a matriz da Seção 7 detalha o núcleo financeiro. |
| `TP-00054-T04` | Sincronizar índices e validar documentação | Pending | `./infra/scripts/validate-docs.sh` retorna código 0. |
| `TP-00054-T05` | Ativar contratos focais sem alterar wire | Done | Billing Super Admin Decisions `Active 1.0.0`; Payment Provider Console `Active 1.8.0`; cobertura 228/228. |
| `TP-00054-T06` | Reauditar os quatro IPs pelo Implementation Readiness Gate | Done | Cada IP registra `READY` para versões, operações e paths exatos. |
| `TP-00054-T07` | Implementar backend, migrations e testes | In Progress | Implementação, 37 testes focais, 8 testes PostgreSQL, 23 testes de controllers e focused gate concluídos; PR gate está `BLOCKED` pelo perfil JaCoCo ausente e dívida preexistente de tamanho. |
| `TP-00054-T08` | Reconciliar copy frontend e testes | In Progress | Copy e 8 testes focais concluídos; quality gates focused `PASS`, mas o gate PR agregado falha em testes externos ao Billing. |

## 4. Documentary acceptance criteria

- `AC-TP54-001`: ADR-0050 declara que segundo aprovador não é exigido em DEV,
  HML ou PRD, agora ou futuramente neste escopo.
- `AC-TP54-002`: qualquer `SUPER_ADMIN` autorizado pode preparar, decidir e
  efetivar a ação dentro de sua alçada.
- `AC-TP54-003`: drafts e registros antigos permanecem imutáveis e consultáveis
  como histórico, sem status novo e sem bloquear o draft.
- `AC-TP54-004`: ausência de checker não produz novo
  `AWAITING_INDEPENDENT_APPROVAL` nem impede transição explícita.
- `AC-TP54-005`: auditoria identifica ator, ação, recurso/revisão e resultado.
- `AC-TP54-006`: `produto → preço → oferta` e `DRAFT` são preservados; publicação
  nunca é automática.
- `AC-TP54-007`: PRD, ADR, REQs, UCs e índices não possuem contradição ativa.

## 5. Gate and validation

Implementation Readiness é obrigatório por IP antes de qualquer edição
executável. A fonte de produto corrente é PRD-00001 `Validated v1.10`; os contratos são
Billing Super Admin Decisions `Active 1.0.0`, operações
`billingCatalogAdminApprove`/`billingRunApprove`, e Payment Provider Console
`Active 1.8.0`, operações `approvePaymentProviderConfigurationRevision`/
`rejectPaymentProviderConfigurationRevision`. A paridade sem mudança de wire foi
comprovada antes da alteração de copy frontend.

Validação canônica:

```bash
./infra/scripts/validate-docs.sh
```

## 6. Current status

`In Progress`: PRD, ADR, requisitos, UCs, contratos, backend, migrations e copy
frontend estão reconciliados no recorte. Os quatro IPs obtiveram `READY`; o
quality gate focused passou no backend e nos dois focos frontend. O encerramento
agregado permanece bloqueado por condições externas ao Billing:

- backend PR: `pom.xml` sem enforcement/check JaCoCo, relatório de cobertura
  ausente e quatro arquivos legados acima do limite de 500 linhas;
- frontend PR: regressões/timeouts em suítes de autenticação, menu, SERPRO,
  certificados, LLM e outras áreas; `.env.local` também impede o build pelo gate;
- documentação: onze referências abreviadas em planos concorrentes de retenção e
  auditoria, dois validadores novos ainda sem entrada individual no índice, o
  corpo portátil do teste divergente do ADR-0000 e sete cenários ausentes no
  contrato do teste de quality gate; os arquivos do TP-00054 não aparecem nesses
  diagnósticos.

## 7. Reconciliação concluída — UC-00038 a UC-00045

O binding D-13.3 no início de cada UC tem precedência explícita sobre o detalhamento
TO-BE legado. Assim, termos como *maker-checker*, *four-eyes*, `checker` e
`PENDING_APPROVAL` continuam pesquisáveis para preservar a evolução e os modelos
de dados, mas não criam obrigação de segundo humano nas operações executadas por
`SUPER_ADMIN`.

| UC | Operações alcançadas | Regra reconciliada para `SUPER_ADMIN` | Controles preservados |
| --- | --- | --- | --- |
| UC-00038 | catálogo, preço, promoção, publicação e retirada | o mesmo ator pode preparar, decidir e executar; `Pricing Approver` distinto e falha por self-approval são legado | `DRAFT`, hash, revisão, seal compatível, histórico e cadeia `produto → preço → oferta`; publicação nunca automática |
| UC-00039 | quote, contrato, assinatura e amendment | decisão administrativa não exige `Pricing/Finance Approver` distinto | aceite do tenant separado, versionamento, idempotência e transição explícita |
| UC-00040 | rating, preview, aprovação e fechamento de invoice | o mesmo ator pode preparar preview, decidir e finalizar | preview/hash, lineage, seal compatível, idempotência e finalização nunca automática |
| UC-00041 | void, reemissão, credit/debit memo e correção | proibição de self-approval não se aplica ao `SUPER_ADMIN` | saldo elegível, cadeia corretiva, regra fiscal, justificativas existentes e auditoria |
| UC-00042 | cobrança, conciliação, pagamento manual e dunning | atos do `SUPER_ADMIN` não aguardam outro humano | alçada, prevenção de fracionamento, causalidade, idempotência e auditoria |
| UC-00043 | crédito, refund, dispute, chargeback e write-off | `Finance Approver` diferente não é precondição do `SUPER_ADMIN` | ledger balanceado, causalidade, limites, reconciliação e histórico |
| UC-00044 | override, emissão, cancelamento e substituição fiscal | `Fiscal Approver` distinto não é precondição do `SUPER_ADMIN` | validação tributária, certificados, prazos legais, evidência fiscal e ambientes DEV/HML/PRD |
| UC-00045 | soft close, reopen, ajuste, write-off e export | qualquer `SUPER_ADMIN` autorizado pode solicitar e decidir explicitamente | watermarks, optimistic version, retenção, redaction, justificativas existentes e auditoria |

### 7.1 Checklist de fechamento documental

- [x] Versões correntes e bindings indexados em `do../../product/use-cases/README.md`.
- [x] Segundo aprovador removido como regra normativa para `SUPER_ADMIN` em DEV, HML e PRD.
- [x] Mesmo ator autorizado para preparar, decidir e efetivar dentro da alçada.
- [x] Ramos, exceções e testes de self-approval posteriores classificados como legado pelo binding de precedência.
- [x] Aceite do tenant e controles legais/fiscais que não representam checker preservados.
- [x] Alçada, tenant/purpose já existente, MFA aplicável, hash/revisão, idempotência e auditoria preservados.
- [x] Drafts e registros antigos preservados como histórico não bloqueante.
- [x] Publicação, finalização e ativação permanecem manuais e nunca automáticas.
- [x] `TP-00054-T03` marcado como `Done` após reconciliação individual dos oito UCs.
- [ ] Gate documental agregado retorna código 0; a última execução foi bloqueada por falhas paralelas fora deste lote.

## 8. Change log

| Version | Date | Change |
| --- | --- | --- |
| 1.8 | 2026-09-10 | Atualiza o blocker documental agregado após a validação final: onze referências e quatro falhas de governança pertencentes a trabalhos concorrentes, sem falha atribuída ao TP-00054. |
| 1.7 | 2026-09-10 | Sincroniza os IPs com o PRD-00001 Validated v1.10 e registra 23/23 testes de controllers backend adicionais. |
| 1.6 | 2026-09-10 | Registra implementação e provas focais verdes, cobertura OpenAPI 228/228 e os blockers reproduzíveis dos gates agregados fora do Billing. |
| 1.5 | 2026-09-10 | Substitui pendências genéricas pela matriz dos oito casos de uso financeiros reconciliados e registra com precisão o que foi removido, preservado e mantido como legado pesquisável. |
| 1.4 | 2026-09-10 | Registra a aprovação humana da baseline wire, ativa os contratos focais e amplia o plano transversal para o loop repository-local dos quatro IPs, condicionado a novo IRG READY e quality gates. |
| 1.3 | 2026-09-10 | Conclui reconciliação normativa, valida PRD-00001 v1.9 e decompõe implementação em quatro IPs atômicos com IRG BLOCKED pelos contratos HTTP. |
| 1.2 | 2026-09-10 | Substitui checker configurável pela remoção definitiva do segundo aprovador; preserva histórico, drafts não bloqueantes, cadeia produto-preço-oferta e publicação explícita. |
