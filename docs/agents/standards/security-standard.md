---
document_id: SECURITY-STANDARD
primary_nature: Regra
objective: Estabelecer controles mínimos de segurança aplicáveis a mudanças de software e documentação operacional.
scope: Segredos, identidade, autorização, dados, dependências, logs, rede e evidência de segurança.
non_objectives: Não substituir threat model, política corporativa, revisão jurídica ou configuração específica da stack.
owner: Segurança e Engenharia
status: Active
version: 1.0
date: 2026-09-11
last_reviewed: 2026-09-11
keywords: seguranca, menor-privilegio, segredos, autenticacao, autorizacao, dados
related_files: README.md, development-standard.md, software-quality-standard.md, iac-supply-chain-standard.md
code_references: N/A - controles executáveis pertencem ao projeto adotante.
principal_statement: Toda mudança aplica menor privilégio, negação por padrão e proteção de dados proporcionais ao risco, com evidência atual.
---

# Security Standard

## Ativação

Baseline para toda mudança. A profundidade do A3 Security/Compliance varia com
exposição, dados e ameaça, mas o gate nunca é omitido sem justificativa.

## Regras

- Nunca ler, persistir, transmitir ou versionar segredo sem autorização e mecanismo
  próprios; exemplos usam valores sintéticos.
- Autenticar identidade e autorizar cada ação no boundary que possui o recurso.
  Cliente, UI e ocultação visual não substituem enforcement server-side.
- Aplicar deny-by-default, menor privilégio, separação de duties e escopo mínimo de
  credenciais, tokens e permissões.
- Validar entrada, codificar saída conforme o contexto e evitar construção insegura
  de consultas, comandos, paths ou URLs.
- Classificar dados, minimizar coleta/retenção, criptografar quando exigido e
  impedir vazamento em logs, erros, telemetria e artefatos de teste.
- Definir timeout, limites, rate control, tratamento de replay e comportamento
  fail-closed em integrações expostas.
- Fixar e verificar dependências conforme o standard de supply chain ativado.
- Registrar ameaça, controles, testes positivos e negativos, limitações e risco
  residual no A3.

## Escalonamento

Vulnerabilidade conhecida, ambiguidade de autorização, exposição de dados,
credencial ausente ou acesso a produção resulta em BLOCKED até decisão e ambiente
autorizados. Um waiver precisa de owner, prazo, compensação e plano de remoção.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.0 | 2026-09-11 | Cria baseline portátil de segurança. |
