# Onboard Tool

## Purpose

Configurar projeto novo ou importar conteúdo de projeto que utiliza versão anterior do harness.

## New Project

`node harness/tooling/harness.mjs onboard`

O comando guia o usuário por um quiz curto, mostra o manifesto para revisão e só
grava após confirmação. Agents são derivados dos profiles selecionados.

## Legacy Project

`node harness/tooling/harness.mjs onboard --source "<path>" --yes`

## Source Safety

A origem é somente leitura, o harness antigo não é copiado sobre o atual e arquivos existentes não são sobrescritos.

## Conflict Behavior

Qualquer conflito ou item ambíguo interrompe a operação. Overwrite automático é proibido.

## Manifest

O único artefato criado pelo quiz é `docs/project-manifest.yaml`. O bloco
`onboarding` registra `status: completed`, versão do questionário e data de
conclusão. Quando o manifesto já existe, o quiz não é repetido.

## Completion

Sucesso do onboarding exige manifesto válido e estado `completed`. Scaffold e
Doctor são etapas posteriores explícitas:

```bash
node harness/tooling/harness.mjs scaffold --check
node harness/tooling/harness.mjs scaffold --create
node harness/tooling/harness.mjs bootstrap
```
