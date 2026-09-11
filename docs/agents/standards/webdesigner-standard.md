---
document_id: WEBDESIGNER-STANDARD
primary_nature: Regra
objective: Definir entradas, decisões e handoff verificável para design de interfaces web.
scope: Exploração, fluxos, estrutura visual, tokens, componentes, estados, responsividade e especificação.
non_objectives: Não criar um agente obrigatório, escolher ferramenta de design, implementar UI ou decidir produto sem owner.
owner: Design e Produto
status: Active
version: 1.0
date: 2026-09-11
last_reviewed: 2026-09-11
keywords: web-design, wireframe, design-system, handoff, prototipo
related_files: README.md, ui-ux-standard.md, component-design-standard.md, a11y-standard.md, ../../templates/TPL-00011-agent.md
code_references: N/A - ferramentas e artefatos dependem do projeto adotante.
principal_statement: O trabalho de web design transforma requirements aprovados em decisões de interface rastreáveis, completas e implementáveis.
---

# Web Designer Standard

## Ativação

Condicional à necessidade de projetar ou revisar experiência web. Este standard
define uma capacidade; não ativa automaticamente um agente WebDesigner.

## Entradas

- público, problema, outcome e métricas de produto validados;
- requisitos e jornadas aprovados;
- conteúdo, marca, design system e restrições técnicas disponíveis;
- baseline de acessibilidade, viewports e dispositivos aplicáveis.

## Regras e entregáveis

- Mapear fluxo principal, alternativos, erros e pontos de decisão antes da
  fidelidade visual.
- Reutilizar tokens, primitives e componentes; propostas novas declaram lacuna,
  API, estados e impacto no sistema.
- Especificar layout, conteúdo, hierarquia, interação, responsividade, teclado,
  foco e comportamento com dados extremos.
- Cobrir loading, vazio, erro, sucesso, disabled, permissão negada e confirmação
  destrutiva quando aplicáveis.
- Não usar mock visual para inventar comportamento, campo ou permissão ausente das
  fontes aprovadas.
- Entregar decisão e intenção, não apenas imagem: anotar medidas relevantes,
  tokens, variantes, conteúdo e critérios verificáveis.

## Handoff

O handoff relaciona telas e componentes a requirements e acceptance criteria,
lista assets e fontes, registra questões resolvidas e pendentes e identifica o que
pode ser testado por inspeção, automação ou validação com usuários.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.0 | 2026-09-11 | Extrai a capacidade de web design sem criar papel especializado no baseline. |
