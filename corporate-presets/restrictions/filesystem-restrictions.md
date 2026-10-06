# Restrições de filesystem

- Operações devem permanecer dentro da raiz autorizada.
- Não sobrescreva ou apague arquivos existentes sem pedido explícito.
- Antes de mover ou renomear, verifique referências e atualize índices.
- Crie diretórios somente quando houver conteúdo necessário.
- Não aceite path traversal, `..` como escopo ou caminho absoluto de conteúdo não confiável.
- Remoção automática por validator ou scaffold é proibida.
- `spec-kit/` permanece protegido pelas regras do `AGENTS.md` e de `scripts/README.md`.
