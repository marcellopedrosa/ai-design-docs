---
document_id: REQ-00007
primary_nature: Requisito
objective: Validar governanca Google apenas quando a capability e os modulos correspondentes forem ativados.
scope: Validador Google, adapters de pacote e classificacao no Registry.
non_objectives: Exigir Gemini/Antigravity no core ou criar adapters em scaffolds inativos.
owner: Mantenedores do harness
status: Approved
version: 0.1
date: 2026-09-30
last_reviewed: 2026-09-30
keywords: google-runtime, gemini, antigravity, profile
related_files: ../../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md
code_references: ../../../harness/tooling/validators/validate-google-runtime-governance.mjs, ../../../harness/tooling/validators/validate-google-runtime-governance.test.mjs, ../../../harness/registry/tooling.yaml
principal_statement: O validador Google deve ser opt-in e exigir adapters de pacote apenas dos modulos explicitamente ativados.
---

# REQ-00007 — Google Runtime condicional

## Origem e User Story View

FIX-008 do plano V4; PRD não aplicável por ser portabilidade do harness. Como projeto sem módulos Google ativos, quero evitar falha por adapters de scaffolds, mantendo validação quando ativada.

## Acceptance Criteria

- AC-01 — Sem profile Google, CLI informa `SKIP` sem executar o validador.
- AC-02 — Com profile Google e sem módulos de pacote ativos, valida os adapters globais existentes e não exige `backend/frontend/website/infra` locais.
- AC-03 — Com pacote ativo declarado, adapter de pacote ausente falha; adapter válido passa.
- AC-04 — Registry classifica a ferramenta como capability `google-runtime` dependente de configuração.
- AC-05 — Marcadores legados não presentes no ADR vigente não são usados como falsa obrigação; controles globais atuais continuam verificados.

## Contrato e aprovação

Ativação por `--profile google-runtime` e `--package <nome>` repetível para cada módulo ativo; o invocador deve usar o manifesto de módulos como fonte dos nomes. Sem pergunta aberta: o usuário escolheu exigir adapters apenas de módulos ativados. Aprovado em 2026-09-30 ao pedir “aplique o v4”.
