---
name: document-number-sequence
description: Gere nomes sequenciais TIPO-NNNNN-slug.md para documentos criados a partir de templates corporativos; nunca aplique a regra em docs/specs do Spec Kit.
---

# Sequenciamento de documentos corporativos

Use somente ao criar um documento individual a partir de um template corporativo,
como ADR, PRD ou lição aprendida.

## Regra

- Nome: `TIPO-NNNNN-slug.md`.
- A sequência é independente por tipo e coleção.
- Reutilize o menor número disponível somente quando houver um arquivo removido com
  justificativa; caso contrário, use o próximo número após o maior existente.
- Verifique novamente o diretório antes de criar para evitar colisão concorrente.
- Atualize o README da coleção e os links afetados na mesma mudança.

## Proteção do Spec Kit

Esta skill nunca renomeia, cria ou valida nomes dentro de qualquer caminho
`docs/specs/`. Os artefatos `spec.md`, `plan.md`, `tasks.md` e checklists seguem
exclusivamente a convenção de `docs/specs/<feature>/` do Spec Kit.

Se o caminho informado estiver em `docs/specs/`, encerre com `BLOCKED` e não faça
alterações.

## Validação

Use `scripts/next-id.mjs` para calcular o próximo identificador de uma coleção.
Depois execute `validate-relative-links` e a skill `documentation-governance`.
