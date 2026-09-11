---
document_id: COMPONENT-DESIGN-STANDARD
primary_nature: Regra
objective: Definir componentes de interface reutilizáveis, acessíveis e coerentes com um design system.
scope: Tokens, primitives, variantes, composição, estados, API pública, documentação e testes.
non_objectives: Não escolher biblioteca, estilo visual, framework ou catálogo de componentes.
owner: Design e Engenharia de Frontend
status: Active
version: 1.0
date: 2026-09-11
last_reviewed: 2026-09-11
keywords: componentes, design-system, tokens, variantes, acessibilidade
related_files: README.md, frontend-standard.md, a11y-standard.md, ui-ux-standard.md, frontend-testing-standard.md
code_references: N/A - biblioteca e paths dependem do projeto adotante.
principal_statement: Um componente reutilizável possui responsabilidade, API, estados e semântica explícitos e compõe primitives antes de criar exceções.
---

# Component Design Standard

## Ativação

Condicional à existência de UI reutilizável ou design system.

## Regras

- Consumir tokens canônicos para cor, espaço, tipografia, movimento, raio e camada;
  valor isolado precisa de justificativa e caminho de consolidação.
- Compor primitives existentes antes de criar nova primitive ou componente.
- Manter API pequena, tipada e orientada a intenção. Variantes representam
  semântica estável, não combinações arbitrárias de estilo.
- Preservar semântica nativa, navegação por teclado, foco visível, nome acessível e
  comportamento com tecnologias assistivas.
- Definir estados default, hover, focus, active, disabled, loading, error e empty
  conforme a responsabilidade do componente.
- Não ocultar side effects, navegação, acesso a rede ou estado global em componente
  apresentado como puramente visual.
- Documentar exemplos, composição permitida, limites e comportamento responsivo.

## Evidência

Testar variantes e interações significativas, teclado, foco, nomes acessíveis e
regressão visual quando configurada. Duplicação deve ser comparada com primitives e
componentes catalogados antes da aprovação.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.0 | 2026-09-11 | Extrai regras portáteis de component design. |
