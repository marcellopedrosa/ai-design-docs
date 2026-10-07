---
document_id: "TP-00012"
primary_nature: "Plano"
objective: "Migrar artefatos documentais numerados para nomes iniciados pelo prefixo canônico de seu tipo sem quebrar referências."
scope: "Templates, requisitos, casos de uso, ADRs, planos de tarefa, planos de implementação, lições aprendidas, relatórios, índices e referências textuais do monorepo."
non_objectives: "Não renumerar IDs, reclassificar conteúdo, alterar decisões/requisitos ou inventar identificadores para documentos contextuais não numerados."
owner: "Arquitetura e Documentação"
status: "Completed"
date: "2026-08-21"
version: "1.3"
keywords: "documentação, prefixos, nomes, links, migração, ADR, REQ, UC, TP, IP, LL, RPT"
related_files: "harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md, harne../../../harness/templates/README.md, docs/delivery/plans/README.md"
code_references: "infra/scripts/validate-docs.sh, infra/scripts/validate-doc-link-labels.pl, infra/scripts/validate-doc-reference-identifiers.pl"
principal_statement: "Todo artefato numerado recorrente começa pelo prefixo de seu tipo e toda renomeação atualiza no mesmo lote os links, índices e referências de caminho."
last_reviewed: 2026-08-21
---

# TP-00012 — Migração de prefixos por tipo documental

## 1. Escopo e matriz canônica

| Coleção / natureza | Prefixo | Formato canônico | Tratamento do legado |
| --- | --- | --- | --- |
| Architecture Decision Record | `ADR` | `ADR-NNNN-short-title.md` | Já aderente; somente validar. |
| Requisito | `REQ` | `REQ-NNNNN-short-title.md` | Mover o identificador anterior para o inicio do nome. |
| Caso de uso | `UC` | `UC-NNNNN-short-title.md` | Já aderente; somente validar. |
| Plano de tarefa | `TP` | `TP-NNNNN-short-title.md` | Renomear planos numerados da raiz de `task_plans/` e completar cinco dígitos. |
| Plano de implementação | `IP` | `IP-BE-X.Y.Z[.N]-short-title.md` / `IP-FE-X.Y.Z[.N]-short-title.md` | Prefixar e namespacear por subcoleção; quarto segmento identifica subplano/review e o nome completo sem `.md` é sempre a identidade. |
| Lição aprendida | `LL` | `LL-BE-NNNNN-short-title.md` / `LL-FE-NNNNN-short-title.md` | Prefixar e namespacear, preservando as sequências locais. |
| Relatório | `RPT` | `RPT-NNNN-short-title.md` | Prefixar relatórios preservando a sequência global existente. |
| Template | `TPL` | `TPL-NNNNN-PromptTemplateName.md` | Renomear os dez templates Markdown para coincidir com `document_id`. |
| Análise numerada | `ANL` | `ANL-NNNNN-short-title.md` | Reclassificar os dois nomes que hoje simulam IDs de requisito. |

`README.md`, índices explícitos de fase/coleção e documentos contextuais sem
sequência própria permanecem com nomes sem prefixo. Esta migração não cria números
retroativos para esses artefatos.

## 2. Fontes superiores e restrições

- [ADR-0000](../../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md): contrato
  mínimo, convenção por coleção, inventário individual e atualização atômica das
  referências.
- [Mapa documental](../README.md): taxonomia e pontos de entrada.
- [Templates](../../../harness/templates/README.md): fonte da convenção para novos artefatos.
- Operações Git que alterem índice, histórico ou remoto permanecem fora do escopo.
- Conteúdo histórico não muda de significado; apenas identificadores de arquivo,
  títulos/IDs diretamente correspondentes e links são normalizados.

## 3. Plano de execução

| Fase | Atividade | Estado | Evidência esperada |
| --- | --- | --- | --- |
| 1 | Atualizar ADR-0000, templates TPL-00003/TPL-00005/TPL-00006/TPL-00007/TPL-00009 e variante raw aplicável | Completed | Convenções explícitas e exemplos canônicos. |
| 2 | Gerar manifesto antigo → novo e provar ausência de colisões | Completed | Manifesto completo, destinos únicos. |
| 3 | Renomear requisitos, planos, lições e relatórios | Completed | Nenhum arquivo numerado permanece no formato legado. |
| 4 | Atualizar links, caminhos textuais, IDs/títulos e READMEs imediatos | Completed | Buscas residuais vazias para nomes antigos, números soltos e listas com prefixo omitido. |
| 5 | Validar documentação e links | Completed | `validate-docs.sh`, labels/IDs textuais, links e `git diff --check` verdes. |

## 4. Regras de transformação

1. Preservar o número e o slug; somente mover/adicionar o prefixo e, nas coleções
   com sequências locais, o namespace `BE`/`FE`.
2. Atualizar a referência ao nome completo do arquivo em todo o monorepo, inclusive
   Markdown, arquivos raw, scripts e configuração.
3. Não substituir termos de domínio que apenas coincidem com um prefixo.
4. Não renomear `README.md` nem índices explícitos.
5. Registrar cada artefato pelo novo nome no `README.md` do diretório imediato.
6. Falhar antes de mover qualquer arquivo se dois nomes produzirem o mesmo destino;
   referências bare a números IP/LL colidentes não são consideradas identidade completa.

## 5. Verificação e rollback

- `./infra/scripts/validate-docs.sh`
- busca por convenções legadas em nomes e referências;
- verificação de todos os destinos de links Markdown relativos;
- `git diff --check`;
- conferência de contagem: total anterior = total posterior por coleção.

Rollback é o manifesto inverso novo → antigo, aplicado somente se a validação falhar
de forma não corrigível. Nenhum arquivo será apagado e nenhum ID será reutilizado.

## 6. Resultado

- 390 artefatos existentes renomeados sem colisao de destino.
- 24 ADR, 42 REQ, 44 UC, 13 TP, 139 IP-BE, 81 IP-FE, 90 LL-BE, 34 LL-FE, 6 RPT, 10 TPL e 2 ANL validados no estado atual do acervo.
- IDs, titulos, indices imediatos e referencias relativas normalizados.
- Referencias textuais compactadas foram expandidas; todo IP usa o stem completo.
- Gate final: `./infra/scripts/validate-docs.sh` aprovado.

## 7. Change log

| Version | Date | Owner | Change |
| --- | --- | --- | --- |
| 1.3 | 2026-08-21 | Arquitetura e Documentacao | Referências textuais e listas compactadas expandidas, IPs referenciados pelo stem completo e gates permanentes reforçados. |
| 1.2 | 2026-08-21 | Arquitetura e Documentacao | Templates reforçados, referências normalizadas pelo ID canônico completo e índices dotados de descrições semânticas. |
| 1.1 | 2026-08-21 | Arquitetura e Documentacao | Migracao concluida, referencias auditadas e gate documental aprovado. |
| 1.0 | 2026-08-21 | Arquitetura e Documentação | Plano inicial e matriz de prefixos. |
