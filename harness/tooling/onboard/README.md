# Onboard Tool

## Purpose

Configurar projeto novo ou importar conteúdo de projeto que utiliza versão anterior do harness.

## New Project

`node harness/tooling/harness.mjs onboard --name <name> --type <type> --profiles <p1,p2> --agents <a1,a2> --yes`

## Legacy Project

`node harness/tooling/harness.mjs onboard --source "<path>" --yes`

## Source Safety

A origem é somente leitura, o harness antigo não é copiado sobre o atual e arquivos existentes não são sobrescritos.

## Conflict Behavior

Qualquer conflito ou item ambíguo interrompe a operação. Overwrite automático é proibido.

## Manifest

O artefato principal é `docs/project-manifest.yaml`.

## Completion

Sucesso exige manifest válido, scaffold concluído e Doctor aprovado.
