---
document_id: BASE-WEBSITE
primary_nature: Contexto
objective: Definir a fronteira base para um site publico separado da aplicacao principal.
scope: Conteudo, interface, assets e testes do website publico, sem dependencia de stack.
non_objectives: Nao presumir que todo projeto possui website separado nem definir marketing, CMS ou framework.
owner: Equipe de Website, Produto ou Conteudo do projeto de destino
status: Active
version: 1.0
date: 2026-09-10
last_reviewed: 2026-09-10
keywords: website, publico, conteudo, scaffold
related_files: ../README.md, ../docs/architecture/module-registry.md, ../docs/business/README.md
code_references: N/A - pasta base sem implementacao.
principal_statement: A pasta website e um scaffold opcional para superficie publica e deve ser removida ou adaptada quando essa fronteira nao existir.
---

# Website

Esta pasta reserva uma superfície pública separada da aplicação principal, como
site institucional, documentação publicada ou landing pages. Sua existência no
baseline não obriga o projeto de destino a manter essa separação.

## Estado do scaffold

- Implementação e conteúdo: nenhum.
- Comando de desenvolvimento/build: não configurado.
- Teste e quality gate: não configurados.
- Publicação: não configurada nem autorizada por este documento.

## Contrato da pasta

- Promessas públicas devem derivar de fontes de negócio e produto aprovadas.
- Conteúdo, assets, acessibilidade, SEO, privacidade e testes seguem standards
  ativados pelo projeto de destino.
- Não duplique comportamento da aplicação principal ou contratos internos.
- Comandos, entrypoints, owner e dependências devem ser registrados no manifesto.
- Remova esta pasta se a fronteira não existir, atualizando `README.md` da raiz e o
  manifesto na mesma mudança.

## Índice

Nenhum artefato de implementação ou conteúdo ativo.

