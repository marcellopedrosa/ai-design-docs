---
document_id: A11Y-STANDARD
primary_nature: Regra
objective: Definir um baseline verificável de acessibilidade para interfaces digitais.
scope: Semântica, teclado, foco, nomes, contraste, conteúdo, movimento, formulários e testes.
non_objectives: Não declarar conformidade legal, escolher nível WCAG ou substituir avaliação com pessoas usuárias.
owner: Design, Engenharia e Qualidade
status: Active
version: 1.0
date: 2026-09-11
last_reviewed: 2026-09-11
keywords: acessibilidade, wcag, teclado, foco, semantica, contraste
related_files: README.md, component-design-standard.md, form-validation-standard.md, frontend-testing-standard.md, ui-ux-standard.md
code_references: N/A - nível, ferramentas e browsers são definidos pelo projeto adotante.
principal_statement: Interfaces devem ser percebidas, operadas e compreendidas sem depender de um único sentido, dispositivo ou modo de interação.
---

# Accessibility Standard

## Ativação

Condicional à existência de interface. O projeto deve selecionar e registrar a
versão e o nível WCAG ou obrigação equivalente aplicáveis.

## Regras

- Preferir HTML ou controle nativo com semântica correta; ARIA complementa e não
  reimplementa comportamento já disponível.
- Toda função interativa é operável por teclado, possui ordem previsível, foco
  visível e restauração de foco após overlays e navegação dinâmica.
- Controles possuem nome, papel, estado e relação programática com labels,
  instruções e erros.
- Contraste, zoom, reflow, target size e orientação atendem ao baseline escolhido.
- Informação não depende apenas de cor, posição, som ou animação; conteúdo não
  textual recebe alternativa adequada.
- Mudanças assíncronas relevantes são anunciadas sem interromper indevidamente.
- Movimento respeita preferência de redução e não introduz risco evitável.

## Evidência

Combinar análise automatizada com inspeção de teclado, foco, zoom/reflow e árvore
de acessibilidade. Jornadas críticas devem incluir teste manual ou assistivo
proporcional ao risco; ferramenta automática não comprova conformidade integral.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.0 | 2026-09-11 | Extrai baseline de acessibilidade sem fixar versão WCAG. |
