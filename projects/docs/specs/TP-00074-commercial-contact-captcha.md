---
document_id: TP-00074
document_scope: project
primary_nature: Plano
objective: Implementar e comprovar o reCAPTCHA v2 Checkbox no formulário público de contato comercial.
scope: Contrato browser-BFF, validação server-side, widget acessível, CSP, configuração, testes e documentação do website.
non_objectives: Alterar backend comercial, persistência, outbox, telas administrativas, deploy, chaves reais ou configuração de produção.
owner: Website, Segurança e Produto Comercial
status: Completed — repository-local
version: 1.2
date: 2026-10-02
last_reviewed: 2026-10-05
keywords: website, contato, captcha, recaptcha-v2, bff, seguranca, acessibilidade
related_files: ../../product/requirements/REQ-00063-commercial-contact-captcha.md, ../../product/use-cases/UC-00051-commercial-contact-intake-notification.md, ../../architecture/website-evolution-specification.md, ../../../harness/skills/implementation-readiness/SKILL.md
code_references: ../../../website/src/lib/contact.ts, ../../../website/src/lib/recaptcha.ts, ../../../website/src/app/api/contact/route.ts, ../../../website/src/components/ContactForm.tsx, ../../../website/src/components/RecaptchaCheckbox.tsx, ../../../website/src/app/globals.css, ../../../website/src/i18n/messages/pt-BR.json, ../../../website/next.config.ts, ../../../.env.example
principal_statement: O BFF somente encaminha contatos após prova CAPTCHA válida, recente e pertencente ao hostname permitido, sem expor ou persistir token ou segredo.
---

# TP-00074 — CAPTCHA do contato comercial

## Fontes e versões

| Fonte | Versão/status | Escopo consumido |
| --- | --- | --- |
| Solicitação humana | 2026-10-02 / autorizada | Planejar, implementar, testar e corrigir até o fechamento repository-local. |
| PRD | N/A justificado | O PRD-00007 limita-se à listagem administrativa; este plano aplica controle técnico a uma ingestão pública já aprovada. |
| REQ-00063 | v1.0 / Approved na execução; v1.1 / Implemented repository-local no fechamento | AC-CAP-001 a AC-CAP-014 e BR-CAP-001 a BR-CAP-009. |
| UC-00051 | v1.8 / Approved | Sequência visitante → BFF → CAPTCHA → backend e resultados públicos. |
| ARCH-WEBSITE-EVOLUTION | v1.0 / Active | Boundary do website, configuração e mapa técnico. |

## Granularidade / Decomposição

- Resultado coordenado: impedir que o BFF encaminhe contato sem prova humana válida e oferecer o desafio acessível nas duas instâncias do formulário.
- Critério de divisão: controle autoritativo server-side, experiência client-side e certificação final possuem handoffs independentes.
- Relação pai → filhos: `CAPTCHA-BFF-001` → `CAPTCHA-UI-002` → `CAPTCHA-QG-003`.
- O plano permanece abaixo dos limites de 500 linhas e 64 KiB.

## Dependências e ordem

| Task | Depends on | Handoff para | Estado |
| --- | --- | --- | --- |
| CAPTCHA-BFF-001 | Fontes aprovadas | Website UI | READY |
| CAPTCHA-UI-002 | CAPTCHA-BFF-001 | Quality | READY |
| CAPTCHA-QG-003 | CAPTCHA-BFF-001 e CAPTCHA-UI-002 | Owner do website | READY |

## CAPTCHA-BFF-001 — Validação autoritativa no BFF

- What: validar a prova reCAPTCHA no BFF antes do único encaminhamento permitido ao backend.
- Where: `website/src/lib/contact.ts`, novo `website/src/lib/recaptcha.ts`, `website/src/app/api/contact/route.ts`, testes focais correspondentes e `.env.example`.
- Depends on: REQ-00063 v1.0 e UC-00051 v1.8.
- Reuses: leitura limitada do body, honeypot, idempotência, autenticação técnica e resposta `no-store` existentes.
- Requirements: AC-CAP-003–009, AC-CAP-013–014 e BR-CAP-002–009.

### Gate Audit

| Controle | Evidência | Estado |
| --- | --- | --- |
| Product Definition | PRD não aplicável pelo recorte acima; decisão funcional está no requisito aprovado pelo solicitante. | PASS |
| Fontes superiores | REQ-00063 v1.0 Approved e UC-00051 v1.8 Approved. | PASS |
| User Story View | Visitante legítimo prova humanidade sem remover as proteções existentes. | PASS |
| Assumptions/Open Questions | Provedor, versão, timeout, idade, hostname, códigos e fail-closed já decididos no requisito. | PASS |
| Dependências | Fetch nativo, runtime Next.js e adapter local/fake disponíveis; chaves reais não são necessárias nos testes. | PASS |
| Escopo | Cinco paths executáveis/testáveis; backend comercial e ambientes externos excluídos. | PASS |
| Granularidade | Um controle autoritativo com um handoff para a UI. | PASS |

### Acceptance Tests

| AC | Teste/comando/evidência | Resultado esperado |
| --- | --- | --- |
| AC-CAP-003–004 | Unitários do adapter e integração da rota | Config ausente falha fechada; sucesso/hostname/idade são obrigatórios. |
| AC-CAP-005–006 | Inspeção do segundo fetch e testes negativos | Token nunca integra o payload do backend; rejeições não o chamam. |
| AC-CAP-007–009 | Timeout, provider inválido e regressões existentes | 503/422 corretos e proteções anteriores preservadas. |
| AC-CAP-014 | Revisão de sinks e testes | Nenhum token, secret, IP bruto ou dado de formulário é logado. |

### Prohibited

- Chamar Google em testes, versionar segredo, aceitar wildcard de hostname ou bypassar a validação.
- Alterar o contrato do backend comercial, outbox, persistência ou Idempotency-Key.

### Mandatory

- URL fixa HTTPS, timeout estrito, resposta `no-store`, token limitado e descarte antes do backend.
- Testes positivos e negativos sem rede externa ou credencial real.

### Definition of Done

- [x] O backend só é chamado após validação positiva de sucesso, hostname e idade.
- [x] Ausência, replay/rejeição, hostname divergente, expiração, timeout e configuração ausente têm teste determinístico.
- [x] `captchaToken` não aparece no request destinado ao backend.

### Result

- Estado: COMPLETED
- Auditor/data: Codex / 2026-10-02
- Task ID, versões e paths: `CAPTCHA-BFF-001`; REQ-00063 v1.0; paths declarados acima.
- Blocker/owner: nenhum blocker repository-local.

## CAPTCHA-UI-002 — Widget, estados e acessibilidade

- What: exibir e controlar o reCAPTCHA v2 Checkbox antes da submissão em todas as instâncias de `ContactForm`.
- Where: novo `website/src/components/RecaptchaCheckbox.tsx`, `website/src/components/ContactForm.tsx`, testes de componente, `website/src/app/globals.css`, mensagens pt-BR e `website/next.config.ts`.
- Depends on: CAPTCHA-BFF-001.
- Reuses: `ContactForm`, `next-intl`, região `aria-live`, estilos e CSP existentes.
- Requirements: AC-CAP-001–003, AC-CAP-007–008 e AC-CAP-010–013.

### Gate Audit

| Controle | Evidência | Estado |
| --- | --- | --- |
| Product Definition | Mesma justificativa N/A da task pai. | PASS |
| Fontes superiores | REQ-00063 v1.0 e UX aprovada na seção 8. | PASS |
| Assumptions/Open Questions | Locale, posição, reset, privacidade, acessibilidade e CSP estão resolvidos. | PASS |
| Dependências | API JS oficial pode ser encapsulada sem nova dependência; testes usam fake local. | PASS |
| Escopo | Seis paths explícitos; não inclui frontend administrativo. | PASS |
| Granularidade | Uma experiência de formulário reutilizada pelas duas entradas. | PASS |

### Acceptance Tests

| AC | Teste/comando/evidência | Resultado esperado |
| --- | --- | --- |
| AC-CAP-001–002 | Teste de componente | Widget precede botão; submit sem prova não faz request e anuncia instrução. |
| AC-CAP-007–008 | Teste de erro/sucesso | Campos permanecem; token é limpo e widget resetado. |
| AC-CAP-010–011 | DOM, teclado e texto | Estado acessível, foco preservado e links do Google presentes. |
| AC-CAP-012 | Teste/configuração CSP | Somente hosts mínimos são liberados, sem `unsafe-eval` em produção. |
| AC-CAP-013 | Testes das duas entradas reutilizadas | Landing e `/contate` consomem o mesmo componente protegido. |

### Prohibited

- Inserir secret no bundle, criar bypass client-side ou relaxar globalmente a CSP.
- Limpar os campos em falha recuperável ou simular aprovação do CAPTCHA em produção.

### Mandatory

- Script assíncrono, locale pt-BR, altura reservada, callbacks de expiração/erro e reset.
- Botão indisponível sem prova vigente e mensagem acessível que explique o motivo.

### Definition of Done

- [x] Widget funcional e acessível aparece antes do botão nas duas entradas.
- [x] Sucesso e todas as falhas consumidoras descartam a prova; dados digitados sobrevivem a erros recuperáveis.
- [x] CSP e configuração pública estão documentadas e testadas.

### Result

- Estado: COMPLETED
- Auditor/data: Codex / 2026-10-02
- Task ID, versões e paths: `CAPTCHA-UI-002`; REQ-00063 v1.0; paths declarados acima.
- Blocker/owner: nenhum blocker repository-local.

## CAPTCHA-QG-003 — Assurance e reconciliação documental

- What: executar A1, A2 e A3 no delta aprovado, corrigir falhas atribuíveis e registrar evidência final.
- Where: todos os paths das tasks anteriores, `website/e2e/landing.spec.ts`, `website/e2e/contact-page.spec.ts`, `website/src/app/contate/page.tsx`, este plano, REQ-00063, UC-00051, especificação do website e índices imediatos.
- Depends on: CAPTCHA-BFF-001 e CAPTCHA-UI-002 implementadas.
- Reuses: scripts do pacote `website`, validador documental e `quality-gate` com `security-gate` subordinado.
- Requirements: Definition of Done do REQ-00063.

### Gate Audit

| Controle | Evidência | Estado |
| --- | --- | --- |
| Fontes e escopo | Mesmo task plan, versões e paths das duas unidades implementáveis. | PASS |
| Dependências | Testes, lint, typecheck, format check, build e validação documental locais disponíveis. | PASS |
| Granularidade | Uma certificação final sem deploy, segredo ou rede externa. | PASS |

### Acceptance Tests

| Gate | Comando/evidência | Resultado esperado |
| --- | --- | --- |
| A1 | Testes focais e suíte `npm test` | Zero falha, erro ou skip ocultando cobertura. |
| A2 | lint, typecheck, format check, build e validadores documentais | Todos retornam código zero. |
| A3 | Revisão de trust boundary e testes negativos do CAPTCHA | Sem finding comprovado; segredo/token ausentes de sinks. |

### Prohibited

- Reduzir limiar, excluir teste, acessar rede/produção ou usar segredo real para obter verde.
- Declarar deploy, ativação pública ou validação operacional externa.

### Mandatory

- Corrigir falhas causadas pelo delta e reexecutar primeiro o gate focal e depois o impactado.
- Registrar comandos, contagens, iterações, limitações e estado dos ACs.

### Definition of Done

- [x] A1, A2 e A3 estão separadamente em PASS.
- [x] Documentação e índices refletem implementação e evidência reais.
- [x] Pendências externas, se existirem, permanecem explícitas e sem falso crédito.

### Result

- Estado: COMPLETED
- Auditor/data: Codex / 2026-10-02
- Task ID, versões e paths: `CAPTCHA-QG-003`; TP-00074 v1.1.
- Blocker/owner: nenhum blocker para assurance repository-local.
- Reauditoria 2026-10-05: `READY` para normalizar somente a quebra de linha
  em `website/src/app/contate/page.tsx`, entrada `/contate` do mesmo escopo,
  exigida pelo `npm run format:check`; REQ-00063 v1.0 Approved na execução e
  v1.1 Implemented no fechamento, sem decisão funcional ou dependência aberta.

## Tracking e handoff

O plano autoriza somente alterações repository-local nos paths registrados. A
configuração de chaves e hostnames reais, revisão jurídica final, deploy e smoke de
ambiente permanecem handoffs operacionais posteriores e não impedem a implementação
testável com adapters locais.

## Evidência de assurance

| Gate | Estado | Evidência repository-local |
| --- | --- | --- |
| A1 — Test | PASS | `npm test`: 34 Vitest + 2 testes Node; `npm run test:e2e`: 26 Playwright em desktop/mobile, zero falhas e zero skips. |
| A2 — Quality | PASS | TypeScript, ESLint, Prettier focal, build Next.js e governança documental retornaram código zero. |
| A3 — Security/Compliance | PASS | Testes negativos de ausência, tamanho, expiração, hostname, timeout e configuração; CSP mínima; token descartado; telemetria sem token/secret/PII. |

### Revalidação de entrega — 2026-10-05

- `npm test`: 34 Vitest e 2 testes Node, zero falha/skip; lint,
  typecheck, format check e build passaram.
- `npm run test:e2e`: primeira execução teve 25/26 por clique do menu mobile
  antes de a página terminar de carregar. Após sincronizar o teste, o focal
  passou 1/1 e a matriz completa passou 26/26, sem skips.
- `./infra/scripts/validate-docs.sh` e o validador canônico de governança
  documental passaram.
- O gate oficial `website/pr --delivery` retornou `BLOCKED`: o baseline do
  website ainda não configura cobertura Vitest com thresholds nem o script
  `test:coverage`. Nenhum commit ou push de TP-00074 foi feito sob esse gate.

### Iterações de correção

1. Fixtures antigas falharam sem prova e foram atualizadas para as fronteiras provider/backend.
2. Typecheck e formato apontaram tipagem/formatação no delta; ambos foram corrigidos.
3. Axe apontou contraste 4,41:1; o token de erro foi corrigido e o E2E focal passou.
4. A regressão multiprojeto revelou dois testes baseline incompatíveis com strict locator/layout mobile; os testes foram corrigidos e a matriz final passou 26/26.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.2 | 2026-10-05 | Revalida fontes e amplia o target do assurance para a formatação da entrada `/contate`. |
| 1.1 | 2026-10-02 | Fecha implementação repository-local após A1/A2/A3 e regressão E2E 26/26. |
| 1.0 | 2026-10-02 | Decompõe BFF, UI e assurance; registra IRG READY para implementação repository-local. |
