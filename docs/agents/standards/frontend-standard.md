---
document_id: FRONTEND-STANDARD
primary_nature: Regra
objective: Definir arquitetura e práticas portáteis para aplicações frontend.
scope: Boundaries de features, renderização, dados, estado, erros, segurança, desempenho e testes.
non_objectives: Não escolher framework, design system, gerenciador de estado, browser matrix ou estratégia de deploy.
owner: Engenharia de Frontend e Arquitetura
status: Active
version: 1.0
date: 2026-09-11
last_reviewed: 2026-09-11
keywords: frontend, arquitetura, componentes, estado, desempenho
related_files: README.md, component-design-standard.md, state-management-standard.md, frontend-testing-standard.md, security-standard.md
code_references: N/A - estrutura e comandos pertencem ao projeto adotante.
principal_statement: O frontend mantém boundaries explícitos, estados completos e contratos verificáveis sem misturar UI, domínio e transporte.
---

# Frontend Standard

## Ativação

Condicional à presença de aplicação web ou cliente interativo.

## Regras

- Organizar por capacidades ou features coesas, com dependências públicas e
  direção de importação explícitas.
- Separar apresentação, regras de domínio, coordenação de estado e transporte; UI
  não conhece detalhes de autenticação, serialização ou cache fora das abstrações.
- Declarar fronteira de execução entre servidor, cliente, worker e edge quando a
  stack possuir mais de um ambiente.
- Toda jornada possui estados inicial, loading, sucesso, vazio, erro, offline e
  permissão negada conforme aplicável.
- Consumir somente contratos versionados; não duplicar schemas, roles ou enums
  manualmente sem teste de paridade.
- Variáveis expostas ao cliente nunca contêm segredo. Autorização real permanece
  no servidor; controles de UI são defesa em profundidade.
- Desempenho é tratado por evidência: medir bundle, renderização, rede e interação
  antes de introduzir memoização ou cache.
- Componentes, estado, acessibilidade, i18n e testes seguem os standards ativados.

## Evidência

Registrar boundaries, entrypoints, contratos consumidos, estados exercitados,
testes, typecheck, lint, build, métricas aplicáveis e limitações de browser.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.0 | 2026-09-11 | Cria baseline frontend independente de framework. |
