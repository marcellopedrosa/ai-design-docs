---
document_id: REQ-00002
primary_nature: Requisito
objective: Impedir PASS de evals para nivel nao implementado.
scope: CLI do runner de evals e suas mensagens de resultado.
non_objectives: Implementar H2 semantico ou framework novo de avaliacao.
owner: Mantenedores do harness
status: Approved
version: 0.1
date: 2026-09-30
last_reviewed: 2026-09-30
keywords: evals, H1, H2, fail-closed
related_files: ../../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md, ../../../harness/governance/decisions/ADR-0001-boundary-harness-v5.md
code_references: ../../../harness/tooling/eval-runner/index.mjs, ../../../harness/tooling/eval-runner/eval-runner.test.mjs
principal_statement: O runner deve rejeitar com erro e exit code nao zero todo nivel solicitado que nao executa de fato.
---

# REQ-00002 — Nível de eval honesto

## Origem e rastreabilidade

- Origem: FIX-002 do plano fornecido pelo usuário e ordem explícita “aplicação ”.
- PRD: não aplicável; correção de integridade do tooling do harness.
- Decisões superiores: ADR-0000 e ADR-0001 Accepted.

## User Story View

Como operador do harness, quero erro explícito ao solicitar H2 ainda não implementado, para não interpretar um PASS de H1 como evidência de H2.

## Comportamento e regras

1. H1 deve continuar executando os casos determinísticos elegíveis.
2. H2 e qualquer outro nível sem executor não devem delegar silenciosamente para H1.
3. Nível não suportado deve retornar mensagem controlada e exit code diferente de zero antes de carregar casos.

## Acceptance Criteria

- AC-01 — Dado `--level H1`, quando o runner executar, então relata apenas H1 e retorna zero se os casos elegíveis passarem.
- AC-02 — Dado `--level H2`, quando o runner executar, então relata `H2 not implemented` ou equivalente, não relata PASS e retorna exit code não zero.
- AC-03 — Dado nível desconhecido, quando o runner executar, então retorna erro controlado e exit code não zero.

## Requisitos não funcionais

| ID | Qualidade | Critério | Evidência |
| --- | --- | --- | --- |
| NFR-01 | Fail-closed | Nenhuma capability não implementada produz PASS | Testes de CLI |

## Impacto de contrato

- Estado: altera comportamento CLI para níveis não implementados; API programática `runEvalsH1` permanece.

## Assumptions e Open Questions

Nenhuma aberta. H1 é o único executor real verificado no código atual.

## Approval

| Approver | Decisão | Data | Evidência |
| --- | --- | --- | --- |
| Mantenedor humano | Approved | 2026-09-30 | Pedido explícito “aplicação ”, que inclui FIX-002 e seu critério de não retornar PASS por H1. |
