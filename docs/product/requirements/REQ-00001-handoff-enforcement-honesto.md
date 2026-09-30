---
document_id: REQ-00001
primary_nature: Requisito
objective: Impedir que o harness anuncie enforcement de handoff que não consegue comprovar.
scope: Hook de parada Claude, configuração ativa, registro e documentação operacional.
non_objectives: Criar rastreamento de sessão, heurística de texto ou mecanismo novo de handoff.
owner: Mantenedores do harness
status: Approved
version: 0.1
date: 2026-09-30
last_reviewed: 2026-09-30
keywords: handoff, hook, enforcement, integridade
related_files: ../../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md, ../../../harness/governance/decisions/ADR-0001-boundary-harness-v5.md
code_references: ../../../harness/tooling/hooks/hooks.test.mjs, ../../../.claude/settings.json
principal_statement: O harness não deve executar nem declarar como controle ativo um hook de handoff sem validação determinística.
---

# REQ-00001 — Enforcement honesto de handoff

## Origem e rastreabilidade

- Origem: FIX-001 do plano V4 fornecido pelo usuário.
- PRD: não aplicável; correção da integridade operacional do harness, sem outcome de produto.
- Decisão superior: ADR-0000, governança e evidência verificável.

## User Story View

Como mantenedor do harness, quero que somente controles de handoff verificáveis sejam ativados, para não receber uma garantia falsa ao encerrar uma sessão.

## Comportamento e regras

1. O runtime não deve executar automaticamente `require-handoff.mjs` enquanto o hook não verificar evidência de forma determinística.
2. O hook não funcional pode ser removido; se mantido, deve estar classificado como inativo ou experimental, sem ser apresentado como enforcement ativo.
3. As referências operacionais devem distinguir obrigação documental de enforcement automático.

## Acceptance Criteria

- AC-01 — Dada a configuração Claude ativa, quando suas entradas de hook forem inspecionadas, então nenhuma entrada `Stop` invoca `require-handoff.mjs`.
- AC-02 — Dado o registry e a documentação operacional, quando forem inspecionados, então o hook não aparece como enforcement ativo.
- AC-03 — Dado o repositório corrigido, quando os testes de hook e o Doctor forem executados, então ambos passam sem requerer estado de sessão, rede ou credenciais.

## Requisitos não funcionais

| ID | Qualidade | Critério verificável | Evidência planejada |
| --- | --- | --- | --- |
| NFR-01 | Portabilidade | Nenhum novo serviço, persistência ou dependência de fornecedor | Diff dos paths da task |

## Impacto de contrato

- Estado: alterar configuração de runtime; contratos JSON existentes não mudam.

## Assumptions e Open Questions

Nenhuma assumption ou pergunta aberta para este recorte: o hook e a configuração existem após sincronização com `origin/main`, e o comportamento esperado consta do FIX-001.

## Approval

| Approver | Decisão | Data | Evidência |
| --- | --- | --- | --- |
| Mantenedor humano | Approved | 2026-09-30 | Solicitação explícita “aplique o v4” após apresentação deste requisito e do bloqueio de aprovação; o recorte corresponde ao FIX-001 do plano fornecido. |

## Readiness documental

Resultado: Approved para o comportamento descrito; execução depende de READY da task correspondente.
