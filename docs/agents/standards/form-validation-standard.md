---
document_id: FORM-VALIDATION-STANDARD
primary_nature: Regra
objective: Padronizar formulários verificáveis, acessíveis e coerentes com validação server-side.
scope: Schema, campos, mensagens, submissão, erros remotos, segurança e testes.
non_objectives: Não escolher biblioteca, layout, componente ou regra de negócio específica.
owner: Produto, Design e Engenharia
status: Active
version: 1.0
date: 2026-09-11
last_reviewed: 2026-09-11
keywords: formularios, validacao, schema, erros, acessibilidade
related_files: README.md, frontend-standard.md, api-client-standard.md, a11y-standard.md, i18n-standard.md
code_references: N/A - schemas e forms dependem do projeto adotante.
principal_statement: Formulário usa schema explícito, mantém o servidor como autoridade e oferece feedback acessível sem perder dados do usuário.
---

# Form Validation Standard

## Regras

- Definir schema canônico por boundary e manter tipos, valores iniciais,
  normalização e mensagens coerentes com ele.
- Validação cliente melhora feedback, mas não substitui validação e autorização no
  servidor.
- Labels, instruções, obrigatoriedade e formato são perceptíveis antes do erro;
  mensagens identificam o campo e como corrigir sem depender apenas de cor.
- Na submissão, prevenir duplicidade, preservar valores, mostrar progresso e
  distinguir erro de campo, formulário, rede, autorização e conflito.
- Mapear erros server-side por código estável; mensagem inesperada recebe fallback
  seguro e observável.
- Dados sensíveis não são logados nem persistidos no browser sem política explícita.
- Dependências entre campos e validação assíncrona tratam cancelamento e respostas
  fora de ordem.

## Evidência

Testar entradas válidas e inválidas, limites, mensagens, foco no primeiro erro,
teclado, submissão repetida, falha remota e preservação dos dados apropriados.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.0 | 2026-09-11 | Cria standard portátil de formulários e validação. |
