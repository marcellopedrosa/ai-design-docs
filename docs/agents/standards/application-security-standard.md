---
document_id: APPLICATION-SECURITY-STANDARD
primary_nature: Regra
objective: Definir baseline verificável de segurança de aplicações web e serviços expostos, com foco em controles técnicos, evidência e revisão AppSec.
scope: Threat boundaries, autenticação, sessão, autorização, validação, encoding, injeção, browser security, SSRF, arquivos, criptografia, dados, erros, logs e superfícies administrativas.
non_objectives: Não substituir política corporativa, pentest, threat model completo, API Security especializado, Spring Security especializado ou ferramenta de scanner.
owner: Segurança, Arquitetura e Engenharia
status: Active
version: 1.0
date: 2026-09-28
last_reviewed: 2026-09-28
keywords: appsec, web, owasp, asvs, cwe, threat-model, secure-coding, a3
related_files: README.md, security-standard.md, software-quality-standard.md, api-security-standard.md, spring-security-standard.md, frontend-standard.md, nextjs-standard.md, iac-supply-chain-standard.md
code_references: N/A - comandos, scanners e thresholds pertencem ao projeto adotante.
principal_statement: Aplicações expostas demonstram controles de segurança por evidência atual; OWASP ASVS é a referência verificável primária e OWASP Top 10 é mapeamento de risco, não checklist completo nem fonte de severidade.
---
# Application Security Standard

## Ativação

Condicional à criação ou alteração de aplicação web, backend web, endpoint, fluxo de
autenticação/autorização, superfície administrativa, processamento de entrada não
confiável ou dado sensível.

## Referências de benchmark

- OWASP ASVS 5.0.0: baseline primário de requisitos técnicos verificáveis.
- OWASP Top 10:2025: taxonomia de riscos e comunicação executiva.
- CWE: classificação de fraquezas quando o identificador estiver confirmado.
- FIRST CVSS v4.0: apoio à severidade quando houver fatos suficientes para vetor confiável.
- NIST SP 800-218 SSDF 1.1: práticas de desenvolvimento seguro no lifecycle.
- NIST SP 800-218 Rev. 1 / SSDF 1.2 permanece referência informativa enquanto Draft.

Não declarar cobertura total de OWASP Top 10 por ferramenta ou inspeção única. Ao
citar ASVS, preferir identificador versionado `v5.0.0-x.y.z`; não inventar número.
Severidade não é inferida da categoria OWASP nem substitui a semântica PASS/FAIL/BLOCKED.

Fontes externas de referência: `https://owasp.org/projects/asvs`,
`https://top10.owasp.org/2025/`, `https://cwe.mitre.org/`,
`https://www.first.org/cvss/v4-0/` e `https://csrc.nist.gov/pubs/sp/800/218/final`.

## Regras

- Identificar trust boundaries, identidades, ativos, entradas controláveis, operações
  privilegiadas e sinks sensíveis afetados pela mudança.
- Autenticar no boundary apropriado e autorizar no servidor cada recurso, função,
  tenant e propriedade sensível. UI e cliente nunca são autoridade de acesso.
- Aplicar deny-by-default, menor privilégio e escopo mínimo de sessão, token,
  credencial e permissão.
- Validar entrada por allowlist e contrato; aplicar encoding/sanitização contextual
  somente onde necessário e usar APIs parametrizadas para queries e comandos.
- Considerar XSS, template/expression injection, command injection, path traversal e
  demais injections apenas quando houver caminho controlável até sink relevante.
- Avaliar CSRF conforme o modelo de credencial do browser. CORS não substitui
  autenticação ou autorização.
- Proteger dados em trânsito e repouso conforme classificação; não registrar segredo,
  token, credencial, dado sensível ou detalhe interno desnecessário.
- Restringir chamadas de saída e destinos controláveis; validar esquema/host/porta,
  impedir bypass de allowlist e proteger serviços internos contra SSRF quando aplicável.
- Upload e download validam identidade, autorização, tipo, tamanho, nome/path,
  armazenamento, execução e conteúdo conforme risco; arquivo do usuário não define
  path arbitrário do servidor.
- Configurar cookies, sessão, headers de segurança, cache e políticas do browser de
  acordo com a arquitetura efetiva; não aplicar regra genérica sem contexto.
- Endpoints de debug, health, metrics, actuator, administração e documentação devem
  possuir exposição e autorização compatíveis com o ambiente.
- Erros e condições excepcionais falham de forma segura, não revelam internals e
  preservam rastreabilidade. Eventos de segurança relevantes produzem logging útil
  sem dados proibidos.
- Mudanças materiais de trust boundary, autenticação, autorização, criptografia ou
  fluxo de dados exigem revisão de design/threat model proporcional ao risco.
- Dependências, containers e pipeline seguem o standard de supply chain quando ativo.

## Evidência e testes

Demonstrar controles com evidência atual e proporcional ao risco, incluindo testes
negativos. Exemplos: acesso de usuário A a recurso de B, claim ausente, tenant
incorreto, payload inválido, URL externa proibida, upload malformado, sessão expirada
e endpoint administrativo sem privilégio.

Um finding só é confirmado quando houver evidência, reachability, control gap e
impacto plausível. Padrão suspeito sem contexto suficiente é pendência de validação.

## Resultado A3

- Violação confirmada de requisito aplicável: `FAIL`.
- Evidência, ferramenta, ambiente, autorização ou contexto obrigatório ausente:
  `BLOCKED`.
- Requisitos aplicáveis demonstrados sem finding confirmado: `PASS`.

Severidade e confiança qualificam o finding, mas não substituem a semântica do gate.
Waivers seguem o Software Quality Standard e não convertem violação em evidência de
conformidade.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.0 | 2026-09-28 | Cria baseline AppSec verificável baseado em ASVS e integrado ao A3. |
