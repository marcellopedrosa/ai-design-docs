---
document_id: DEVELOPMENT-STANDARD
primary_nature: Regra
objective: Definir práticas portáteis de implementação, manutenção e verificação de software.
scope: Alterações de código, configuração executável, migrations e infraestrutura como código.
non_objectives: Não escolher linguagem, framework, arquitetura, comandos, branch ou limiares do projeto adotante.
owner: Engenharia e Qualidade
status: Active
version: 1.0
date: 2026-09-11
last_reviewed: 2026-09-11
keywords: desenvolvimento, codigo, manutencao, verificacao, portabilidade
related_files: README.md, software-engineering-lifecycle.md, implementation-readiness-standard.md, software-quality-standard.md, security-standard.md
code_references: N/A - paths e comandos dependem do manifesto do projeto adotante.
principal_statement: Toda implementação permanece pequena, explícita, testável, segura e rastreável às fontes e ao READY vigente.
---

# Development Standard

## Ativação

Baseline para toda escrita ou alteração executável. Regras mais específicas da
stack complementam este arquivo sem reduzi-lo.

## Regras

- Implementar somente o escopo, versões e paths cobertos pelo READY vigente.
- Reutilizar contratos, componentes e padrões existentes antes de criar variantes.
- Preferir unidades coesas, dependências explícitas e interfaces mínimas; tamanho
  excessivo aciona revisão de responsabilidade e decomposição.
- Validar entradas nas fronteiras, preservar invariantes no domínio e representar
  falhas de forma estável, sem silenciar exceções.
- Não registrar segredos, dados pessoais ou conteúdo sensível; logs devem apoiar
  diagnóstico sem ampliar exposição.
- Comentários explicam intenção não evidente. Código morto, workaround sem
  rastreabilidade e TODO sem ID ou URL não são aceitos.
- Alteração de comportamento cria ou atualiza teste relevante. Mudança de contrato
  testa produtor, consumidor, compatibilidade e falhas.
- Formatação, lint, análise estática, tipagem, build e testes seguem comandos
  canônicos registrados no manifesto ou adapter mais próximo.
- Git, rede, instalações, release e ambientes externos seguem a política explícita
  do projeto; este standard não concede autorização.

## Evidência

Registrar targets, fontes, decisão de reuso, testes alterados, comandos, códigos de
saída, cobertura aplicável, skips, riscos e pendências. Conclusão exige os gates do
[Software Quality Standard](software-quality-standard.md).

## Especialização do projeto

Ao adotar este standard, o projeto deve registrar linguagens, formatadores,
analisadores, limites de tamanho, comandos de teste/build, política de dependências
e paths governados. Ausência de ferramenta obrigatória é BLOCKED, não PASS.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.0 | 2026-09-11 | Cria baseline portátil de desenvolvimento. |
