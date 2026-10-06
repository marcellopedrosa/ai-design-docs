---
name: documentation-governance
description: Mantenha índices README e a fonte canônica ao criar, mover, renomear, revisar ou remover documentos em coleções do harness.
---

# Governança documental

Use esta skill quando uma mudança alterar documentos ou a estrutura de uma coleção.

1. Leia o `AGENTS.md` aplicável e o standard de governança documental.
2. Identifique a coleção imediata e seu `README.md`.
3. Atualize o README para refletir escopo, convenções e inventário dos artefatos.
4. Atualize o índice pai quando a coleção for criada, movida, renomeada ou removida.
5. Execute `validate-relative-links` com `--check-collection-readmes` na raiz do projeto.
6. Corrija referências quebradas novas. Referências legadas fora do escopo devem ser
   reportadas separadamente, com o caminho e a razão.

Não altere `spec-kit/`; ele é o core protegido do harness.
