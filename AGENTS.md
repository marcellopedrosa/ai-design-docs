# Harness corporativo

Este repositório separa o core do Spec Kit das extensões corporativas e da documentação do projeto.

- `spec-kit/` é o core upstream (github.com/github/spec-kit) e não deve ser removido/criado arquivos e nem receber regras específicas do produto.
- `corporate-presets/` contém templates, standards, contratos e políticas corporativas.
- `projects/` contém a documentação e os domínios do produto.
- O Spec Kit rege especificação, planejamento, tarefas, implementação e validação. Standards e templates corporativos acrescentam conteúdo de produto e critérios técnicos, sem criar fases ou gates concorrentes.
- Artefatos de cada domínio devem ficar em seu respectivo `docs/`.
- Antes de implementar, consultar a especificação, os standards aplicáveis e o `AGENTS.md` do domínio.

Não criar novas regras dentro de `spec-kit/` para resolver necessidades de `projects/`; use presets, extensões ou workflows fora do core.

`spec-kit/` está protegido por ACL. Antes de qualquer operação que possa escrever, criar, excluir, formatar ou gerar arquivos nesse diretório, interrompa a operação e consulte `scripts/README.md`. Atualizações intencionais exigem desbloqueio explícito e novo bloqueio após a mudança. Nunca use `spec-kit/.specify/` como destino de artefatos de `projects/`.

Após criar, mover, renomear ou remover documentos Markdown em `corporate-presets/` ou `projects/`, execute a skill `validate-relative-links` ou seu verificador. Corrija as referências novas ou alteradas antes de concluir; reporte separadamente as referências legadas ainda quebradas.

Cada coleção documental ativa deve manter um `README.md` como índice semântico imediato, conforme `corporate-presets/standards/documentation-governance-standard.md`.
