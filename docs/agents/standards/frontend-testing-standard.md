---
document_id: FRONTEND-TESTING-STANDARD
primary_nature: Regra
objective: Definir estratégia portátil de testes para interfaces e aplicações frontend.
scope: Testes unitários, componentes, integração, acessibilidade, contrato e E2E.
non_objectives: Não escolher runner, biblioteca, browser, cobertura ou ambiente do projeto.
owner: Engenharia de Frontend e Qualidade
status: Active
version: 1.0
date: 2026-09-11
last_reviewed: 2026-09-11
keywords: frontend, testes, componentes, e2e, acessibilidade
related_files: README.md, frontend-standard.md, component-design-standard.md, a11y-standard.md, software-quality-standard.md
code_references: N/A - ferramentas e comandos pertencem ao projeto adotante.
principal_statement: Testes frontend exercitam comportamento perceptível ao usuário no menor nível confiável e preservam contratos entre UI e serviços.
---

# Frontend Testing Standard

## Estratégia

- Unidade: transformações e regras puras.
- Componente: semântica, interação, estados, foco e acessibilidade isolada.
- Integração: feature, roteamento, cache, formulário e contrato com boundaries
  substituídos de forma controlada.
- E2E: jornadas críticas e integração real que não possam ser provadas abaixo.

## Regras

- Consultar elementos por papel, nome e texto observável; seletores de implementação
  ficam restritos a casos justificados.
- Testar resultado e interação, não snapshots extensos ou detalhes internos.
- Cobrir loading, sucesso, vazio, erro, timeout, permissão negada e retry quando
  aplicáveis.
- Mocks imitam o contrato canônico e incluem respostas negativas; não inventam
  payloads incompatíveis nem tornam a unidade sob teste trivialmente verde.
- Relógio, rede, locale, timezone e aleatoriedade são controlados.
- Teste E2E usa dados sintéticos, isolamento e cleanup seguro; não acessa produção.
- Flakiness é falha de qualidade e exige causa, owner e correção rastreáveis.

## Evidência

Registrar teste focal, suíte impactada, browsers/ambientes, contagens, skips,
cobertura configurada, auditoria de acessibilidade e artefatos de falha úteis.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.0 | 2026-09-11 | Cria estratégia portátil de testes frontend. |
