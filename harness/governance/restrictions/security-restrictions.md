---
document_id: SECURITY-RESTRICTIONS
document_scope: harness
primary_nature: Restrição
objective: Definir restrições mínimas de segurança para agentes.
scope: Agentes operando sob o harness.
owner: Mantenedores do harness
status: Active
version: 1.0
date: 2026-09-30
last_reviewed: 2026-09-30
keywords: security, secrets, authentication, transport, logging
related_files: ../README.md, ../policies/agent-behavior-policy.md
code_references: ../../tooling/harness-doctor/index.mjs
principal_statement: Controles de segurança universais não podem ser removidos ou reduzidos para obter conveniência.
---

# Security Restrictions

## Purpose

Definir restrições mínimas de segurança para qualquer agente operando sob este harness.

## Secrets

O agente não deve:

- inserir senha, token, chave ou segredo em código-fonte;
- registrar segredo em log;
- copiar segredo para documentação;
- persistir segredo em arquivo não autorizado;
- substituir mecanismo seguro por segredo hardcoded.

## Authentication and Authorization

O agente não deve:

- remover autenticação para resolver erro funcional;
- remover autorização para simplificar teste;
- criar bypass permanente de controle de acesso;
- conceder privilégio maior que o necessário sem justificativa explícita.

## Transport Security

O agente não deve:

- desabilitar validação TLS permanentemente;
- introduzir trust-all em ambiente de produção;
- desabilitar verificação de certificado como solução definitiva;
- trocar canal seguro por canal inseguro sem requisito explícito.

## Logging

O agente não deve registrar:

- credenciais;
- tokens;
- secrets;
- dados sensíveis sem necessidade;
- payloads completos quando puderem expor informação protegida.

## Security Controls

O agente não deve:

- remover validação de segurança para fazer teste passar;
- reduzir proteção sem registrar o risco;
- modificar configuração de segurança fora do escopo da tarefa.

## Enforcement

Sempre que tecnicamente possível, estas restrições devem possuir controle correspondente em:

- tooling;
- gates;
- contracts;
- validators;
- CI.
