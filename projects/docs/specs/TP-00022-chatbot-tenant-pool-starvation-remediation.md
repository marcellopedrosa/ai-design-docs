---
document_id: TP-00022
primary_nature: Plano
objective: Coordenar a correção e a prova de regressão do starvation do pool tenant no chatbot.
scope: Backend Omnichannel, configuração do pool tenant, testes e documentação associada.
non_objectives: Não executar deploy, publicar imagem, acessar providers reais ou introduzir inbox/outbox.
owner: Backend e Arquitetura
status: In Progress
version: 1.1
date: 2026-08-26
last_reviewed: 2026-08-26
keywords: plano, chatbot, hikari, pool, llm, concorrencia
related_files: do../../product/requirements/REQ-00046-chatbot-tenant-pool-starvation-resilience.md, docs/analysis/ANL-00047-chatbot-tenant-pool-starvation-adherence.md, ../../backend/docs/specs/IP-BE-3.2.10-chatbot-tenant-pool-starvation-remediation.md
code_references: backend/
principal_statement: Executar o menor corretivo que limite rede e contenção antes de consumir o pool e provar que operações do tenant continuam adquirindo conexão.
---

# TP-00022 — Remediação do starvation do pool tenant no chatbot

## Authorization and References

Plano aprovado pela solicitação humana explícita de correção em 2026-08-26.
Fontes: `REQ-00046`, `ANL-00047`, ADR-0011, ADR-0012, ADR-0015,
ADR-0019, ADR-0021 e
`IP-BE-3.2.10-chatbot-tenant-pool-starvation-remediation`.

## Work Breakdown

| Step | Deliverable | Status |
| --- | --- | --- |
| 1 | Congelar requisito, aderência e implementation plan | Done |
| 2 | Aplicar timeout real ao cliente LLM | Done |
| 3 | Coordenar concorrência antes da transação e tornar advisory lock não bloqueante | Done |
| 4 | Dimensionar/validar configuração do pool tenant | Done |
| 5 | Adicionar regressões unitárias, WireMock e PostgreSQL | Done — execução PostgreSQL skipped sem Docker socket |
| 6 | Executar testes focais, gates arquiteturais e suíte impactada | Done |
| 7 | Registrar lesson learned e handoff de rebuild/runtime | In Progress — lesson registrada; rebuild/runtime pendente ao operador |

## Acceptance Gate

- Todos os `AC-001` a `AC-008` do REQ-00046 possuem evidência ou pendência explícita.
- Nenhum teste usa provider externo ou dados reais.
- A execução Docker/Testcontainers, se indisponível, é reportada como pendência e não como sucesso.
- Build/restart do container local não ocorre sem autorização operacional explícita.

## Risks

- Vários providers sequenciais podem somar seus budgets individuais.
- Esgotar retry após ACK ainda pode perder update sem inbox durável.
- `N` tenants ativos multiplicam o limite máximo lazy de conexões PostgreSQL.
- Schedulers de outros módulos também podem reter transações durante I/O externo.

## Change Log

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.1 | 2026-08-26 | Codex | Registra implementação, testes verdes e pendências operacionais explícitas. |
| 1.0 | 2026-08-26 | Codex / autorização humana | Plano corretivo aprovado. |
