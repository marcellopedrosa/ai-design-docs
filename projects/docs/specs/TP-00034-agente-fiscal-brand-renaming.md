---
document_id: "TP-00034"
primary_nature: "Plano"
objective: "Uniformizar a marca pública e documental como Contador Fiscal."
scope: "Ocorrências textuais da marca legada em docs/ e website/, incluindo metadados, conteúdo visível e testes."
non_objectives: "Renomear arquivos, slugs, IDs técnicos, URLs, pacotes, módulos, diretórios ou alterar frontend/ e backend/."
owner: "Produto, Documentação e Website"
status: "Completed"
date: "2026-09-04"
last_reviewed: "2026-09-04"
version: "1.1"
keywords: "marca, agente-fiscal, documentacao, website, renomeacao"
related_files: "docs/README.md, harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md, TP-00021-hub-contabil-landing-page-implementation-brief.md"
code_references: "website/src/, website/e2e/, website/README.md, website/prompt/README.md"
principal_statement: "Toda ocorrência textual da marca pública no escopo autorizado deve convergir para Contador Fiscal sem renomear identificadores técnicos."
---

# TP-00034 — Padronização da marca Contador Fiscal

## 1. Visão geral

Este plano coordena a atualização transversal da marca nos documentos governados e
no website público. A mudança é editorial e visual; contratos técnicos, caminhos e
identificadores permanecem estáveis.

## 2. Matriz de execução

| # | Atividade | Responsável | Status | Evidência esperada |
| --- | --- | --- | :---: | --- |
| 1 | Inventariar ocorrências textuais em `docs/` e `website/` | Documentação | ✅ | Lista e contagem reproduzíveis por `rg` |
| 2 | Persistir e indexar o plano transversal | Documentação | ✅ | Plano e índice reconciliados |
| 3 | Atualizar a marca textual nos documentos | Documentação | ✅ | Zero ocorrências legadas em `docs/` |
| 4 | Atualizar conteúdo, metadados e testes do website | Website | ✅ | Zero ocorrências legadas em `website/` |
| 5 | Executar gates documentais e do website | Qualidade | ✅ | Validadores e testes aprovados |
| 6 | Reconciliar evidências e concluir o plano | Engenharia | ✅ | Status e changelog finais |

| Total | Pendentes | Em andamento | Concluídas | Progresso |
| ---: | ---: | ---: | ---: | ---: |
| 6 | 0 | 0 | 6 | 100% |

## 3. Restrições e critérios de aceite

- Substituir somente o nome textual da marca no escopo autorizado.
- Preservar nomes de arquivos, slugs, IDs, URLs, pacotes, módulos e diretórios.
- Não alterar `frontend/`, `backend/`, infraestrutura, dados ou integrações.
- Atualizar testes do website que validam conteúdo de marca.
- Obter zero ocorrências textuais legadas em `docs/` e `website/`.
- Executar `./infra/scripts/validate-docs.sh` e os gates aplicáveis do website.

## 4. Riscos e rollback

- Documentos históricos também serão atualizados por solicitação explícita; datas,
  decisões, IDs e referências estruturais devem permanecer intactos.
- Textos de interface podem quebrar expectativas automatizadas; os testes de
  conteúdo e navegação devem ser reconciliados na mesma mudança.
- O rollback é textual e arquivo a arquivo; não há migração de dados nem efeito em
  ambientes externos.

## 5. Change log

| Versão | Data | Autor | Mudança |
| --- | --- | --- | --- |
| 1.1 | 2026-09-04 | Codex | Conclui a padronização textual, os testes do website e os gates documentais. |
| 1.0 | 2026-09-04 | Codex | Plano criado e iniciado antes da alteração transversal. |

## 6. Resultado e evidências

- A varredura `rg` encontrou inicialmente `125` ocorrências exatas em `57`
  arquivos e, após a mudança, zero ocorrências no escopo.
- Foram preservados nomes de arquivos, slugs, IDs técnicos, URLs, pacotes, módulos
  e diretórios.
- Website: `9` testes unitários aprovados; TypeScript, ESLint, Prettier e build de
  produção aprovados; cenário Playwright focalizado aprovado (`1/1`).
- O gate documental inicial e o final foram executados a partir da raiz e
  concluíram sem falhas.
- Não houve acesso a rede, produção, dados reais, segredos ou comandos Git.
