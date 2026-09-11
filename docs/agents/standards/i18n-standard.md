---
document_id: I18N-STANDARD
primary_nature: Regra
objective: Definir internacionalização e localização consistentes e verificáveis.
scope: Mensagens, chaves, locale, fallback, pluralização, datas, números, timezone, layout e testes.
non_objectives: Não escolher biblioteca, idiomas, serviço de tradução ou política editorial.
owner: Produto, Conteúdo e Engenharia
status: Active
version: 1.0
date: 2026-09-11
last_reviewed: 2026-09-11
keywords: i18n, l10n, locale, traducao, timezone, pluralizacao
related_files: README.md, frontend-standard.md, form-validation-standard.md, ui-ux-standard.md
code_references: N/A - locales e catálogos pertencem ao projeto adotante.
principal_statement: Texto e formatos visíveis são derivados de locale explícito e catálogos verificáveis, nunca de concatenação ou defaults ambientais ocultos.
---

# Internationalization Standard

## Regras

- Definir locales suportados, default, fallback, origem da preferência e estratégia
  de negociação.
- Usar chaves estáveis e semânticas; não usar texto visível como chave nem montar
  frases por concatenação.
- Aplicar pluralização, gênero e seleção conforme os recursos da biblioteca e do
  idioma, com placeholders nomeados e contexto para tradução.
- Formatar números, moeda, percentuais, datas e durações pelo locale. Instantes são
  armazenados de forma inequívoca e exibidos no timezone explicitamente escolhido.
- Conteúdo de servidor e cliente usa os mesmos códigos semânticos de erro; fallback
  não expõe mensagem interna.
- Layout suporta expansão de texto e, quando aplicável, direção RTL sem ordem
  visual codificada indevidamente.
- Traduções ausentes são detectadas antes do release; fallback silencioso deve ser
  observável em desenvolvimento e teste.

## Evidência

Testar cada locale suportado, pluralizações críticas, formatos, timezones, chaves
ausentes, caracteres complexos, expansão e RTL quando aplicável.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.0 | 2026-09-11 | Cria standard portátil de internacionalização. |
