# Standard de governança documental

Toda coleção documental ativa possui um `README.md` imediato que funciona como
índice semântico obrigatório da coleção e primeira rota de navegação.

O índice deve seguir `TPL-00005-collection-readme.md` e declarar frontmatter,
contrato da coleção, inventário completo, rotas temáticas e change log. Ao criar,
mover, renomear ou remover um documento, atualize o README da coleção afetada e o
índice pai quando a composição da coleção mudar.

O README é um mapa navegável; não duplica o conteúdo dos documentos. Cada coleção
deve manter uma fonte canônica e links relativos válidos. Coleções vazias não devem
ser criadas apenas para satisfazer a árvore de referência. A regra não se aplica
aos arquivos internos de `docs/specs/`, que seguem exclusivamente o Spec Kit.
