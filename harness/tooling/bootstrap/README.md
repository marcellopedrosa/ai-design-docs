# Bootstrap Tool

## Purpose

Validar um clone local de um projeto já configurado com o harness.

## Usage

`node harness/tooling/harness.mjs bootstrap`

## Behavior

Bootstrap não executa onboarding, não altera manifest, não importa projeto,
não recria standards, não move arquivos e executa validações e Doctor.

## Success

`READY` somente é exibido quando todas as verificações obrigatórias passam.
