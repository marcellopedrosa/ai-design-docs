---
document_id: "TP-00009"
primary_nature: "Plano"
objective: "Coordenar a apresentação do tempoEspera do SITFIS em formato legível nos outcomes públicos de espera."
scope: "Requisitos SITFIS, backend Fiscal/Omnichannel, contrato REST e frontend da consulta fiscal."
non_objectives: "Alterar a unidade recebida do SERPRO, o instante de retry, a precedência dos códigos ou tornar AV01 público."
owner: "Codex / Engenharia"
status: "Completed"
date: "2026-08-21"
version: "1.0"
keywords: "plano, coordenacao, sitfis, human, readable, wait, message"
related_files: "do../../product/requirements/REQ-00009-serpro-apoiar-protocolo-relatorio.md, do../../product/requirements/REQ-00040-serpro-sitfis-message-catalog.md, do../../product/use-cases/UC-00007-solicitacao-relatorio-situacao-fiscal.md, ../../frontend/docs/adrs/ADR-0013-frontend-architecture-state-management.md, docs/delivery/plans/README.md"
code_references: "Plano, backend/src/main/java/br/com/duoset/saas_service/contexts/fiscal/, backend/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/, frontend/src/lib/fiscal/serproMessage.ts, frontend/src/components/fiscal/FiscalStatusCard.tsx, infra/scripts/validate-docs.sh"
principal_statement: "O sistema preserva tempoEsperaMs para contrato e orquestração, mas comunica outcomes públicos de espera com duração humana explícita e consistente em todos os canais."
---

# TP-00009 — �� Mensagem de espera humanizada do SITFIS

**Document ID:** `TP-00009`  
**Primary Nature:** `Plano`  
**Objective:** Coordenar a apresentação do `tempoEspera` do SITFIS em formato legível nos outcomes públicos de espera.  
**Scope:** Requisitos SITFIS, backend Fiscal/Omnichannel, contrato REST e frontend da consulta fiscal.  
**Non-objectives:** Alterar a unidade recebida do SERPRO, o instante de retry, a precedência dos códigos ou tornar AV01 público.  
**Project:** SaaS Service  
**Date:** 2026-08-21 (v1.1)
**Status:** ✅ Completed
**Author / Owner:** Codex / Engenharia  
**Keywords:** SITFIS, AV02, AV03, tempoEspera, duração humana, chatbot, frontend  
**Code References:** `backend/.../contexts/fiscal`, `backend/.../contexts/omnichannel`, `frontend/src/lib/fiscal`  
**Principal Statement:** O sistema preserva `tempoEsperaMs` para contrato e orquestração, mas comunica outcomes públicos de espera com duração humana explícita e consistente em todos os canais.

**References:**
[REQ-00009](../../product/requirements/REQ-00009-serpro-apoiar-protocolo-relatorio.md) ·
[REQ-00040](../../product/requirements/REQ-00040-serpro-sitfis-message-catalog.md) ·
[UC-00007](../../product/use-cases/UC-00007-solicitacao-relatorio-situacao-fiscal.md) ·
[ADR-0013](../../frontend/docs/adrs/ADR-0013-frontend-architecture-state-management.md)

---

## 1. Overview

O retorno técnico do SERPRO continuará usando milissegundos. Para `AV02` e `AV03`,
o backend deve derivar uma mensagem pública canônica que substitua a referência ao
campo técnico por uma duração humana, como `40 segundos`, e entregar a mesma redação
ao REST, frontend, WhatsApp e Telegram.

## 2. Execution Tracking Matrix

| # | Activity | Status | Evidence |
|---|---|:---:|---|
| 1 | Confirmar contrato e ponto único de composição | ✅ | REQ-00009/REQ-00040 e composição central no módulo Fiscal |
| 2 | Atualizar requisito e caso de uso | ✅ | REQ-00009 v1.5, REQ-00040 v1.4 e UC-00007 v1.4 |
| 3 | Implementar composição segura e propagar aos canais | ✅ | Catálogo, adapter e casos de uso inicial/assíncrono atualizados |
| 4 | Cobrir valores e fluxos relevantes com testes | ✅ | 122 testes focalizados/gates e 1.340 testes na suíte backend |
| 5 | Executar gates de código e documentação | ✅ | Backend, frontend focalizado, documentação e whitespace validados |

## 3. Constraints and Decisions

- `tempoEspera` permanece em milissegundos no payload SERPRO, no domínio e no campo
  público `tempoEsperaMs`; somente a frase destinada ao usuário é humanizada.
- `40000` deve ser apresentado como `40 segundos`, com singular/plural corretos.
- A mesma mensagem derivada deve chegar ao frontend e ao chatbot; o texto remoto do
  provider não será usado como template executável.
- `AV01` continua sendo controle interno e silencioso.
- Valores ausentes ou inválidos usam o delay efetivamente adotado pelo domínio antes
  da composição, sem expor `0 segundos` nem duração negativa.

## 4. Verification

- Catálogo e casos de uso: 37 testes, sem falhas, erros ou skips.
- Adapter, REST e consumidores do chatbot: 56 testes, sem falhas, erros ou skips.
- Regras de arquitetura e Spring Modulith: 29 testes, sem falhas, erros ou skips.
- Suíte completa backend: 1.340 testes, 0 falhas, 0 erros e 58 skips de
  integrações indisponíveis no ambiente, incluindo testes dependentes de Docker.
- Frontend focalizado (`serproMessage` e `FiscalStatusCard`): 6 testes, sem falhas.
  Não houve mudança de código frontend; typecheck e lint integrais não foram
  necessários para esta alteração.
- `./infra/scripts/validate-docs.sh`: aprovado.
- `git diff --check`: aprovado.

## 5. Handoff

Registrar arquivos alterados, comandos, contagens, skips e qualquer gate não
executado. Não acessar SERPRO real, produção, dados reais ou segredos.

## 6. Change Log

| Version | Date | Author | Changes |
|---|---|---|---|
| `1.1` | `2026-08-21` | Codex | Execução concluída; evidências de implementação, testes e gates registradas. |
| `1.0` | `2026-08-21` | Codex | Plano transversal persistido antes das edições de produto. |
