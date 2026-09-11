---
document_id: SOFTWARE-ENGINEERING-LIFECYCLE
primary_nature: Regra
objective: Definir o lifecycle C.L.E.A.R. e seus gates obrigatorios.
scope: Da definicao do problema ao release e verificacao.
non_objectives: Nao criar requisitos, decidir arquitetura, escolher stack ou autorizar ambiente externo.
owner: Arquitetura, Produto e Qualidade
status: Active
version: 1.0
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: clear, lifecycle, gates, planejamento, assurance, release
related_files: implementation-readiness-standard.md, software-quality-standard.md, ../../templates/README.md
code_references: N/A - comandos sao registrados no manifesto e nos standards do projeto.
principal_statement: Nenhuma fase executavel inicia sem seus gates anteriores, e nenhum release ocorre sem assurance e autorizacao proprias.
---

# Software Engineering Lifecycle

## Macrofluxo C.L.E.A.R.

```text
Context → Logic & Layout → [READY] → Execution → Assurance → Release
```

| Estágio | Conteúdo | Condição de saída |
| --- | --- | --- |
| C — Context | Negócio, PRD, requirement e approval | Problema/outcome definidos, PRD `Validated`, requirement `Approved` |
| L — Logic & Layout | ADR, análise, use case, arquitetura, contrato e plano | Decisões encerradas, task atômica e IRG `READY` |
| E — Execution | Código, configuração, migration ou IaC | Resultado implementado no escopo auditado e testes atualizados |
| A — Assurance | A1 Test, A2 Quality, A3 Security/Compliance | Todos os subgates aplicáveis em `PASS` |
| R — Release | Entrega, rollout e verificação | Procedimento autorizado concluído e evidência pós-release registrada |

## Fases

1. **Contexto de negócio, condicional:** registrar motivação e vocabulário quando a
   mudança afetar produto ou operação.
2. **Product definition:** validar PRD com problema, público, outcomes, limites,
   métricas e hipóteses.
3. **Decisão arquitetural:** registrar ADR quando houver escolha material ainda não
   coberta.
4. **Requirement:** especificar comportamento e critérios de aceite.
5. **Approval:** owner humano aprova o requirement; autoria não implica aprovação.
6. **Use case, condicional:** detalhar interações complexas e mapear AC → fluxo →
   evidência.
7. **Contrato, condicional:** versionar interface consumida por mais de um boundary.
8. **Task planning:** decompor por resultado e criar contrato finito.
9. **Readiness:** auditar task ID, versões, paths, incertezas e DoD.
10. **Implementation:** executar somente após `READY` vigente.
11. **Assurance:** executar A1, A2 e A3 aplicáveis com evidência atual.
12. **Release e verificação:** seguir autorização, rollout, rollback e observação
    próprios do projeto.

## Regras de gate

- Fase não inicia sem a condição de saída de sua predecessora.
- Fase condicional pode ser omitida apenas com justificativa no plano.
- Mudança de produto exige PRD aplicável `Validated`; manutenção puramente técnica
  registra `PRD not applicable` com motivo específico.
- Assumption ou hypothesis pendente, Open Question, `TBD`, conflito ou approval
  ausente interrompe o fluxo antes de Execution.
- Interface compartilhada ausente ou incompleta bloqueia consumidores e produtores.
- Mudança de fonte, versão, escopo ou path invalida o `READY` anterior.
- Falha encontrada em Assurance retorna à primeira fase capaz de corrigir a causa.
- Release não é autorizado pelo simples fato de os testes estarem verdes.

## Handoff mínimo

Cada transição registra owner anterior e seguinte, artefatos, versões, paths,
resultado do gate, evidência, pendências e condição de retomada.

