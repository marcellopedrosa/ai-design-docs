# New Project

## Command

`node harness/tooling/harness.mjs onboard`

## Flow

1. responder perguntas canônicas;
2. selecionar profiles registrados;
3. revisar e confirmar o manifesto;
4. o manifesto registra `onboarding.status: completed`;
5. novas execuções não repetem o quiz;
6. executar `scaffold --check`, `scaffold --create` e `bootstrap` quando estiver pronto para materializar e validar os documentos.
