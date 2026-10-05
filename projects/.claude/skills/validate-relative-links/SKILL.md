---
name: validate-relative-links
description: Verifique links Markdown e caminhos relativos no frontmatter após criar, renomear ou remover documentos; reporte referências locais quebradas.
---

# Validar referências relativas

Use após alterar documentos ou quando houver suspeita de referências internas quebradas.

Execute `node scripts/check-links.mjs --root <raiz-do-harness-ou-projeto>` a partir desta pasta da skill. O verificador analisa arquivos Markdown, links locais e campos `related_files`/`code_references` do frontmatter. URLs externas, âncoras isoladas e exemplos em blocos de código ficam fora da verificação.

Pode verificar apenas a coleção alterada com `--root <diretório-da-coleção>`, mantendo a resolução de cada link relativa ao arquivo que o contém. Neste harness, `corporate-presets/templates/`, `corporate-presets/skills/` e `projects/` estão limpos; um scan completo ainda aponta referências herdadas em `corporate-presets/governance/`. Informe essas pendências, sem tratá-las como links válidos.

Corrija cada destino no documento de origem e execute o verificador novamente. Se o destino foi removido intencionalmente, retire a referência ou substitua por um artefato real; não crie arquivos vazios para silenciar o resultado. Não altere o core protegido `spec-kit/`.

Os evals ficam em `evals/check-links.test.mjs` e rodam com `node --test evals/check-links.test.mjs`.
