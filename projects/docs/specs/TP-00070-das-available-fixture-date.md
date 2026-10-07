---
document_id: TP-00070
primary_nature: Plano
objective: Remover a data vencida da fixture do teste de reuso de DAS disponível.
scope: Correção focalizada de fixture em EmitirDasUseCaseTest.
non_objectives: Não alterar regra de validade, emissão, certificado ou contrato fiscal.
owner: Engenharia e Qualidade
status: Completed
version: 1.1
date: 2026-10-01
last_reviewed: 2026-10-01
keywords: DAS, teste, vencimento, qualidade
related_files: TP-00069-flyway-migration-pr-validation.md
code_references: backend/src/test/java/br/com/duoset/saas_service/contexts/fiscal/internal/application/usecase/EmitirDasUseCaseTest.java, backend/src/main/java/br/com/duoset/saas_service/contexts/fiscal/internal/domain/model/DasDocument.java
principal_statement: O teste de reuso de DAS disponível precisa de vencimento posterior ao dia de execução para verificar o ramo de reuso.
---

# TP-00070 — Fixture de validade do DAS disponível

## Implementation Readiness Gate

**Result: READY** — 2026-10-01, somente para o teste indicado.

### Gate Audit

- **Product Definition:** PRD not applicable; correção de fixture sem mudança de comportamento.
- **Fontes:** falha reproduzida no gate de PR e no teste isolado; `DasDocument.isValid()` usa `LocalDate.now()` e rejeita vencimento anterior ao dia atual.
- **What:** fazer o teste de reuso exercitar um DAS ainda disponível, preservando as assertivas existentes.
- **Where:** `backend/src/test/java/br/com/duoset/saas_service/contexts/fiscal/internal/application/usecase/EmitirDasUseCaseTest.java`; este plano e índice imediato.
- **Depends on:** data atual 2026-10-01 e código existente. Nenhuma dependência externa.
- **Reuses:** fixture e teste existentes.
- **Requirements:** preservar a regra de validade e o teste negativo de DAS vencido; somente a data da fixture de reuso pode mudar.
- **Incertezas:** nenhuma; a falha e a condição temporal foram verificadas no código e no teste isolado.
- **Granularidade:** correção atômica distinta da validação Flyway, com teste e handoff próprios.

### Acceptance Tests

1. O teste `reusesOnlyAnAvailableDasForTheSameConsolidationDate` passa isoladamente sem certificado.
2. O restante de `EmitirDasUseCaseTest` mantém as assertivas e passa sem skip.
3. O gate de PR backend é repetido após a correção.

### Prohibited

Alterar regra de negócio, desativar teste, fornecer certificado fictício para contornar o ramo errado ou editar `.github/workflows/`.

### Mandatory

Teste focal, A1/A2/A3 independentes, validação documental e registro do resultado do gate de PR.

### Definition of Done

- Fixture de reuso tem vencimento futuro em relação ao dia de execução.
- Teste fiscal focalizado passa sem skips.
- Resultado do gate de PR e dos subgates registrado, inclusive falhas remanescentes.

## Evidência de 2026-10-01

- **Causa:** fixture com vencimento em 30/09/2026, anterior ao dia de execução;
  `DasDocument.isValid()` usa `LocalDate.now()` e retorna falso nesse caso.
- **A1 focal — PASS:** `./mvnw -B -o -Dtest=EmitirDasUseCaseTest test`;
  9 testes, 0 falhas, 0 erros, 0 skips após vencimento relativo à execução.
- **A2 focal — PASS:** backend/testes compilados no mesmo comando, sem alteração
  do código de produção; validador documental passou.
- **A3 — PASS:** fixture sintética, nenhuma mudança de permissão, segredo,
  endpoint ou dado real.
- **Gate PR — PASS no executor:** a execução completa após a correção incluiu
  `EmitirDasUseCaseTest` com 9/9 testes aprovados, Surefire com 0 falhas/erros,
  Failsafe com 0 falhas/erros/skips, JaCoCo `check` e métricas aprovados.
  Sete skips legados de outros módulos permanecem identificados no TP-00069.
