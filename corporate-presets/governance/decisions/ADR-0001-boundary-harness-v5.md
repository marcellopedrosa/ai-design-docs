---
document_id: ADR-0001
primary_nature: Decisao
objective: Decidir a separacao fisica entre control plane do harness e documentacao do projeto.
scope: Topologia canonica , ownership, adapters derivados e migracao do repositorio-fonte.
non_objectives: Alterar lifecycle, afrouxar gates, implementar os FIXes funcionais  ou alterar codigo de produto.
owner: Mantenedores do harness
status: Accepted
version: 0.1
date: 2026-09-30
last_reviewed: 2026-09-30
keywords: harness, , boundary, ownership, migracao
related_files: ADR-0000-governanca-do-harness-documental.md, ../README.md, ../../README.md
code_references: ../../registry/, ../../contracts/, ../../skills/, ../../evals/, ../../tooling/, ../../adapters/, ../../../AGENTS.md
principal_statement: O control plane será concentrado em harness/ e docs/ ficará reservado à documentação do projeto, mantendo shims de runtime na raiz.
---

# ADR-0001 — Boundary do harness

## Contexto

O ADR-0000 aceito fixa paths canônicos do harness dentro de `docs/` e nas árvores de runtime. O plano externo  propõe outro layout: `harness/` para governance e tooling; `docs/` para produto. A mudança conflita com as cláusulas de topologia do ADR-0000, mas não exige alterar suas regras de readiness, assurance ou segurança. Antes da migração, o Doctor  passou H0 48/48 e H1 22/22 no commit `ef25ff9`; esse baseline não comprova conformidade .

## Decision drivers

- Uma fonte canônica por regra, skill e contrato.
- Atualizar o harness sem sobrescrever documentação ou código de projeto adotante.
- Preservar descoberta por Codex, Claude Code, Gemini e outros runtimes.
- Migrar sem perder links, histórico, controles ou trabalho local ainda não commitado.

## Opções consideradas

### Opção 1 — Manter layout

- Benefício: zero migração e compatibilidade imediata.
- Custo: ownership de harness e projeto continua misturado em `docs/`.

### Opção 2 — Boundary `harness/` (proposta)

- Benefício: ownership explícito e adapters derivados de fonte única.
- Custo: migração de paths, Registry, Doctor, CI, links e configuração de runtime em etapas verificadas.

### Opção 3 — `governance/` na raiz

- Benefício: separa algumas regras.
- Custo: não representa registry, contracts, evals e tooling; mantém o control plane fragmentado.

## Decisão proposta

Adotar a opção 2. Esta decisão substitui **apenas as localizações canônicas e a taxonomia de ownership** conflitantes no ADR-0000; seus gates, precedência, limites de segurança e requisitos de approval permanecem vigentes. Durante a migração, paths  continuam operacionais até que seus consumidores sejam atualizados e testados; não há revogação antecipada de controles. `harness/` conterá governance, adapters, registry, contracts, skills, evals, tooling, templates e exemplos. `docs/` conterá documentação do projeto e histórico que o projeto optar por manter. Arquivos exigidos por runtimes ou plataforma podem permanecer na raiz como shims/artefatos derivados. Não sobrescrever automaticamente paths project-owned.

## Consequências

- Positiva: migração e atualização de harness podem ser distinguidas de documentação do projeto.
- Negativa: o layout  é incompatível com referências  até que Registry, Doctor, CI, links e adapters sejam migrados juntos.
- Neutra: os FIXes funcionais do  continuam trabalho separado; a migração física não os resolve nem os cancela.

## Impactos

- Contratos/interfaces: paths de descoberta e de documentação mudam; schemas e semântica dos gates não devem mudar por movimento.
- Segurança/compliance: os controles existentes permanecem; nenhuma permissão nova é concedida.
- Migração/compatibilidade: inventário com reason codes, lotes ORG-001–017 e guia de upgrade; preservar `.agents` e `.claude` até sincronização comprovada.
- Operação/rollback: branch de trabalho, baseline registrado, movimentos reversíveis e testes/Doctor após cada lote.

## Validação

| Controle | Evidência esperada | Owner |
| --- | --- | --- |
| Ownership | Nenhum documento project-owned sobrescrito; inventário de movimentos | Mantenedores |
| Integridade | Doctor, testes, links, Registry, adapters e CI sem paths  ativos | Engenharia |
| Compatibilidade | Guia de upgrade e relatório de migração com Decision Trace | Arquitetura |

## Lifecycle

- Approvers: mantenedor humano do harness.
- Supersedes: somente cláusulas de path e ownership do ADR-0000 quando este ADR for Accepted.
- Superseded by: N/A.
- Decisão/data: Accepted em 2026-09-30; aprovação explícita do mantenedor na conversa: “Aprovo ADR-0001 v0.1”.
