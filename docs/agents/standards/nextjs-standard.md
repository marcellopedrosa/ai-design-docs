---
document_id: NEXTJS-STANDARD
primary_nature: Regra
objective: Definir práticas reutilizáveis para projetos que adotem Next.js.
scope: App Router, boundaries servidor/cliente, rotas, cache, metadata, erros, ambiente, build e testes.
non_objectives: Não ativar Next.js, escolher versão, hosting, rendering mode ou estrutura de features.
owner: Engenharia de Frontend e Arquitetura
status: Active
version: 1.0
date: 2026-09-11
last_reviewed: 2026-09-11
keywords: nextjs, react, app-router, server-components, cache
related_files: README.md, frontend-standard.md, frontend-testing-standard.md, state-management-standard.md, security-standard.md
code_references: N/A - versão, routes e comandos pertencem ao projeto adotante.
principal_statement: Quando Next.js estiver ativo, boundaries de execução, cache e exposição de configuração permanecem explícitos e testáveis.
---

# Next.js Standard

## Ativação

Condicional a módulo Next.js registrado com versão e comandos no manifesto.

## Regras

- Preferir Server Components quando interação, browser API ou estado cliente não
  forem necessários; marcar Client Components no menor boundary possível.
- Não importar dependência server-only em bundle cliente nem expor segredo por
  variável pública, prop serializada, source map ou erro.
- Route Handlers, Server Actions e páginas respeitam contrato, autenticação,
  autorização e validação no servidor.
- Estratégia de rendering, cache, revalidation e dynamic data é escolhida por rota
  e requisito de freshness, não por default acidental.
- Loading, not-found, erro e metadata são definidos no boundary apropriado e não
  vazam detalhe interno.
- Navegação, URL state e prefetch preservam expectativa, privacidade e custo.
- Recursos específicos da versão adotada devem ser confirmados na documentação
  oficial e cobertos por build/teste antes do uso.

## Evidência

Executar lint, typecheck, testes e build de produção em ambiente sintético seguro;
inspecionar separação server/client, rotas, cache e variáveis expostas.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.0 | 2026-09-11 | Cria baseline Next.js condicional e sem versão fixa. |
