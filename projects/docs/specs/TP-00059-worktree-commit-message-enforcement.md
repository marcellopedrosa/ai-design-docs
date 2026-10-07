---
document_id: TP-00059
primary_nature: Plano
objective: Impedir commits locais cuja mensagem não corresponda à coordenada da branch do worktree.
scope: Hook versionado, instalador local, validador hermético, teste e instruções de autonomia Git.
non_objectives: Não impor política no servidor remoto, reescrever histórico, criar commit ou configurar credenciais.
owner: Arquitetura e Qualidade
status: Completed
version: 1.1
date: 2026-09-13
last_reviewed: 2026-09-13
keywords: git, worktree, commit-msg, hook, conventional-commits, enforcement
related_files: harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md, do../../agents/standards/development-standard.md, harness/governance/project-settings/settings.md
code_references: .githooks/commit-msg, infra/scripts/install-git-hooks.sh, infra/scripts/validate-commit-message.sh, infra/scripts/tests/validate-commit-message-test.sh
principal_statement: Um hook commit-msg versionado deve validar a mensagem contra a branch do worktree e bloquear qualquer divergência antes do commit ser criado.
---

# TP-00059 — Enforcement de mensagem de commit por worktree

## 1. Overview

Esta tarefa entrega uma barreira local e reproduzível para commits autônomos. O
hook `commit-msg` delega a validação a um script testável; o instalador configura
somente `core.hooksPath` local para apontar à árvore versionada.

## 2. Implementation Readiness Gate

### Gate Audit

| Controle | Evidência | Resultado |
| --- | --- | --- |
| Product Definition | PRD não aplicável: governança de Git sem comportamento de produto. | PASS |
| Requirements / Use Cases | Não aplicáveis: a solicitação do owner define a barreira operacional. | PASS |
| ADR | ADR-0000 v4.23 Accepted, Section 8.7.1. | PASS |
| Assumptions / Open Questions | Nenhuma: hook local é a barreira solicitada; `--no-verify` permanece proibido por instrução. | PASS |
| Dependencies | Bash, Git e paths versionados já presentes; sem rede ou instalação. | PASS |
| API Contract | N/A: sem API HTTP. | PASS |
| Granularity | Uma entrega observável: bloquear mensagem incompatível antes de criar o commit. | PASS |

### Acceptance Tests

| Critério | Evidência |
| --- | --- |
| Branch válida e assunto compatível passam. | Teste hermético do validador retorna `0`. |
| Scope divergente, branch inválida e detached HEAD falham. | Teste hermético retorna `1` para cada cenário. |
| Hook chama o validador. | Teste com `git -c core.hooksPath=.githooks commit` em fixture local. |

### Prohibited

- Usar `--no-verify`, inferir a coordenada pelo diretório, alterar histórico ou acessar rede.

### Mandatory

- Validar branch por `git branch --show-current`, mensagem pelo arquivo passado por `commit-msg` e executar testes herméticos.

### Result

| Campo | Valor |
| --- | --- |
| Readiness Result | READY |
| Auditor | Codex usando implementation-readiness |
| Source Versions | ADR-0000 v4.23; Development Standard v1.9; Settings v2.7 |
| Scope Authorized | `.githooks/commit-msg`, `infra/scripts/{install-git-hooks,validate-commit-message}.sh`, `infra/scripts/tests/validate-commit-message-test.sh`, documentação e adaptadores correlatos |
| Decomposition | N/A — entrega única: enforcement local de mensagem |
| Blockers / Decision Owner | N/A |

## 3. Definition of Done

- Hook versionado bloqueia mensagem incompatível no worktree atual.
- Instalador configura apenas `core.hooksPath` localmente.
- Testes cobrem sucesso e falhas determinísticas sem rede.
- Documentação, índices e `validate-docs.sh` passam.

## 4. Execution Evidence

- `infra/scripts/tests/validate-commit-message-test.sh`: PASS, 7 cenários.
- Hook ativado neste clone por `./infra/scripts/install-git-hooks.sh`.
