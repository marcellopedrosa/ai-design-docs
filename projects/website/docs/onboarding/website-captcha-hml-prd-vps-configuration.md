---
document_id: ONBOARD-WEBSITE-CAPTCHA-HML-PRD-VPS
document_scope: project
primary_nature: Regra
objective: Orientar o provisionamento, a implantação, a validação e a rotação segura do reCAPTCHA v2 do formulário comercial em HML e PRD hospedados em VPS.
scope: Google reCAPTCHA, runtime Next.js do website, variáveis build-time e server-only, DNS/TLS, proxy, egress, smoke, observabilidade, rollback e troubleshooting.
non_objectives: Criar chaves no provedor, executar deploy, alterar Compose/Nginx/workflows, acessar VPS ou segredos reais, substituir o runbook geral da VPS.
owner: DevOps, Segurança, Website e Produto Comercial
status: Active
version: 1.0
date: 2026-10-05
last_reviewed: 2026-10-05
keywords: onboarding, captcha, recaptcha-v2, website, hml, prd, vps, segredo, deploy, rollback
related_files: README.md, production-vps-deployment.md, github-production-cicd.md, ../architecture/website-evolution-specification.md, ../product/requirements/REQ-00063-commercial-contact-captcha.md, ../delivery/plans/TP-00074-commercial-contact-captcha.md, ../../website/README.md
code_references: ../../website/src/components/RecaptchaCheckbox.tsx, ../../website/src/lib/recaptcha.ts, ../../website/src/app/api/contact/route.ts, ../../website/next.config.ts, ../../website/package.json, ../../docker-compose.hml.yml, ../../docker-compose.prd.yml, ../../infra/proxy/nginx.hml.conf, ../../infra/proxy/nginx.prd.conf, ../../infra/deploy/production.env.example
principal_statement: HML e PRD usam registros reCAPTCHA separados e um runtime Next.js server-side; site key entra no build, secret permanece no BFF e qualquer divergência falha fechado sem encaminhar o contato.
---

# Configuração do CAPTCHA do website em HML e PRD na VPS

## 1. Finalidade e estado atual

Este runbook materializa a estratégia operacional do Google reCAPTCHA v2 Checkbox
usado pelo formulário público “Fale com o time comercial”. Ele começa depois da
implementação repository-local do [REQ-00063](../product/requirements/REQ-00063-commercial-contact-captcha.md)
e termina antes de qualquer ativação pública não autorizada.

O estado atual do repositório impõe um bloqueio explícito:

- `website/` possui o widget e o BFF `POST /api/contact` implementados;
- `docker-compose.hml.yml`, `docker-compose.prd.yml`, os Nginx ambientais e os
  workflows existentes publicam a aplicação autenticada `frontend/`, não o
  website público;
- não existe serviço canônico `website`, imagem/Containerfile, healthcheck,
  virtual host ou workflow ambiental que entregue esse runtime na VPS;
- `npm run build:html` não fornece o BFF e, isoladamente, não pode receber o
  secret nem verificar CAPTCHA server-side.

Portanto, este documento não autoriza adaptar o `frontend` nem apontar
`/api/contact` diretamente ao backend. Antes de configurar as chaves reais, a
Infra deve entregar, por plano `READY` próprio, um runtime Next.js `standalone`
para `website/`, proxy same-origin e rollback. Até lá, o rollout ambiental está
**BLOCKED**, embora o procedimento e as decisões de configuração estejam definidos.

## 2. Owners e separação de responsabilidades

| Responsável | Responsabilidade |
| --- | --- |
| Produto Comercial | Aprovar os FQDNs públicos e a janela de ativação. |
| Segurança/Privacidade | Administrar o projeto reCAPTCHA, revisar políticas/cookies e custodiar secrets. |
| DevOps/Infra | DNS, TLS, egress, runtime, env files, proxy, deploy, rollback e evidência sanitizada. |
| Website | Confirmar build-time/runtime, CSP, mensagens e comportamento fail-closed. |
| Backend/Comercial | Confirmar `CONTACT_WEBHOOK_TOKEN`, persistência `NEW` e ausência de contato/outbox nas falhas CAPTCHA. |
| QA | Executar smoke positivo/negativo em HML e liberar evidência para PRD. |

Nenhuma pessoa deve copiar o secret para issue, chat, terminal compartilhado,
pipeline log, imagem Docker, argumento de processo ou variável `NEXT_PUBLIC_*`.

## 3. Decisões que devem existir antes do provisionamento

Registre estas decisões no change ticket sem valores secretos:

| Decisão | HML | PRD | Regra |
| --- | --- | --- | --- |
| FQDN do website | `<WEBSITE_HML_FQDN>` | `<WEBSITE_PRD_FQDN>` | Nome DNS exato, sem scheme/path/porta. Não inferir de `app-*`. |
| Registro reCAPTCHA | ID técnico HML | ID técnico PRD | Registros distintos; nunca compartilhar secret. |
| Conta/projeto owner | Grupo de Segurança | Grupo de Segurança | Evitar ownership pessoal único. |
| Runtime | Next.js standalone | Next.js standalone | Deve servir páginas e `/api/contact` na mesma origem. |
| Porta interna | Definida pela Infra | Definida pela Infra | Não publicar diretamente na internet. |
| Env file/secret store | Path owner-only | Path owner-only | Fora do Git, backup e logs. |
| Janela/rollback | Ticket HML | Change PRD | Imagem anterior e configuração correspondente identificadas. |

Os placeholders acima são campos de decisão, não valores para deploy. O rollout
permanece bloqueado enquanto qualquer um estiver sem owner, evidência ou valor
aprovado.

## 4. Topologia obrigatória

```text
Internet
   │ HTTPS :443
   ▼
Nginx da VPS — FQDN exclusivo do website
   │ proxy HTTP na rede Docker, sem publicar porta interna
   ▼
website Next.js standalone
   ├─ GET / e /contate
   ├─ POST /api/contact
   │    ├─ valida payload/honeypot/idempotência
   │    ├─ POST HTTPS → Google siteverify
   │    └─ POST HTTPS → backend Commercial
   └─ CSP permite somente os endpoints reCAPTCHA declarados
```

Regras da topologia:

1. O browser fala somente com o FQDN do website e recebe apenas a site key.
2. Nginx encaminha páginas e `/api/contact` ao mesmo container `website`.
3. O BFF usa o secret para chamar a URL fixa do Google por HTTPS.
4. Após validação, o BFF remove `captchaToken` e usa
   `CONTACT_WEBHOOK_TOKEN` para chamar o endpoint comercial.
5. O backend nunca recebe site key, secret ou token CAPTCHA.
6. Uma configuração incompleta mantém o formulário indisponível; não existe
   bypass ambiental.

## 5. Provisionamento no Google reCAPTCHA

O owner de Segurança executa o provisionamento pela console oficial do Google,
usando uma sessão administrativa protegida e registrando somente metadados no
ticket.

### 5.1 Criar registros separados

Para cada ambiente:

1. criar um registro com nome identificável, por exemplo
   `contador-fiscal-website-hml` ou `contador-fiscal-website-prd`;
2. selecionar **reCAPTCHA v2 → caixa de seleção “Não sou um robô”**;
3. cadastrar somente o hostname aprovado do website naquele ambiente;
4. cadastrar grupo owner e alertas administrativos;
5. aceitar termos somente pela autoridade competente;
6. guardar site key e secret diretamente nos destinos de custódia;
7. registrar no ticket data, owner, ambiente, hostname e ID não secreto.

Não cadastrar `localhost`, IP da VPS, domínio do backend, domínio do frontend
autenticado ou wildcard no registro PRD. HML e PRD não reutilizam o mesmo par.

### 5.2 Classificação dos valores

| Valor | Classificação | Destino |
| --- | --- | --- |
| Site key | Pública, mas ambiental | Build arg/env `NEXT_PUBLIC_RECAPTCHA_SITE_KEY`. |
| Secret key | Segredo server-side | Secret manager ou env file owner-only entregue apenas ao runtime website. |
| Hostname permitido | Configuração pública | `RECAPTCHA_ALLOWED_HOSTNAMES`, com comparação exata. |
| Timeout | Configuração operacional | `RECAPTCHA_VERIFY_TIMEOUT_MS`. |

A site key pública não deve ser improvisada no HTML: ela entra no build Next.js
para que o bundle e a imagem sejam rastreáveis. O secret nunca participa do build.

## 6. Contrato de configuração

O runtime implementado reconhece exatamente:

```dotenv
NEXT_PUBLIC_RECAPTCHA_SITE_KEY=<site-key-do-ambiente>
RECAPTCHA_SECRET_KEY=<secret-key-do-mesmo-registro>
RECAPTCHA_ALLOWED_HOSTNAMES=<hostname-exato-sem-scheme>
RECAPTCHA_VERIFY_TIMEOUT_MS=3000
```

Restrições:

- `NEXT_PUBLIC_RECAPTCHA_SITE_KEY` precisa existir durante `next build`; alterar o
  valor exige nova imagem/build;
- `RECAPTCHA_SECRET_KEY` é injetada somente na inicialização do container;
- `RECAPTCHA_ALLOWED_HOSTNAMES` aceita lista separada por vírgula, normalizada
  para minúsculas e comparada por igualdade; não usar `*`, URL, path ou porta;
- timeout deve ser inteiro entre 500 e 5000 ms; o padrão operacional é 3000 ms;
- site key e secret devem pertencer ao mesmo registro ambiental;
- o container também precisa de `CONTACT_WEBHOOK_URL` e
  `CONTACT_WEBHOOK_TOKEN` válidos para concluir o contato;
- `NODE_ENV=production` é obrigatório em HML/PRD para CSP e comportamento de
  produção.

Exemplos de hostnames, após decisão formal:

```dotenv
# HML — exemplo estrutural, não copiar sem resolver o FQDN
RECAPTCHA_ALLOWED_HOSTNAMES=<WEBSITE_HML_FQDN>

# PRD — exemplo estrutural, não copiar sem resolver o FQDN
RECAPTCHA_ALLOWED_HOSTNAMES=<WEBSITE_PRD_FQDN>
```

## 7. Custódia e entrega dos segredos na VPS

Quando o projeto ainda usar env file, aplique o mínimo abaixo:

1. diretório pertencente ao usuário de deploy, modo `0700`;
2. arquivo ambiental separado para o website, modo `0600`;
3. montagem/leitura apenas pelo container website;
4. backup criptografado no cofre aprovado;
5. nenhuma cópia no checkout, home compartilhada ou artefato de CI;
6. `docker inspect` é acessível a administradores do daemon: trate acesso Docker
   como acesso privilegiado aos secrets;
7. logs de validação mostram apenas presença, comprimento permitido e hash/ID
   administrativo quando aprovado — nunca o valor.

Exemplo de criação segura do arquivo vazio, sem incluir credenciais no histórico:

```bash
install -d -m 0700 /opt/duoset/<ambiente>/website-secrets
install -m 0600 /dev/null /opt/duoset/<ambiente>/website-secrets/website.env
```

Preencha o arquivo por editor seguro ou mecanismo do secret manager. Não use
`echo`, argumento de linha de comando ou heredoc com o secret.

## 8. Requisitos de rede, DNS, TLS e proxy

### 8.1 DNS e TLS

- A/AAAA do FQDN aprovado aponta para a borda correta da VPS.
- Certificado cobre exatamente o FQDN e sua cadeia está válida.
- HML e PRD usam FQDNs e certificados distinguíveis.
- Não habilitar HSTS abrangente para domínios fora da autoridade da implantação.

### 8.2 Egress

O runtime website necessita saída TCP 443 e resolução DNS para:

- `www.google.com`, usado pelo script e por `siteverify`;
- `www.gstatic.com`, usado pelos assets do widget;
- backend comercial pelo hostname/rota autorizados.

Não liberar egress irrestrito apenas para corrigir timeout. Registre DNS, destino,
porta e resultado sanitizado da verificação.

### 8.3 Nginx

O virtual host do website deve:

- redirecionar HTTP para HTTPS;
- encaminhar `/` e `POST /api/contact` ao runtime website;
- preservar `Host` e indicar `X-Forwarded-Proto https`;
- aplicar limites de conexão/request compatíveis com o formulário;
- não adicionar CORS cross-origin ao BFF same-origin;
- não encaminhar `/api/contact` diretamente ao backend;
- não registrar body, token CAPTCHA, secret ou campos comerciais;
- manter os headers CSP emitidos pelo Next.js ou reproduzi-los sem relaxamento.

A CSP implementada permite os hosts mínimos do reCAPTCHA. Não adicionar
`unsafe-eval` em HML/PRD nem substituir a política por `*`.

## 9. Ordem de implantação em HML

HML é o único ambiente onde a integração externa é validada antes de PRD.

1. Resolver os campos da seção 3 e concluir o runtime/proxy ausente.
2. Criar DNS e TLS do website HML.
3. Criar o registro reCAPTCHA HML com seu hostname exato.
4. Guardar site key no input de build e secret no secret store/env file HML.
5. Configurar allowlist, timeout, webhook URL/token e `NODE_ENV=production`.
6. Construir imagem imutável a partir do SHA aprovado.
7. Confirmar por inspeção de build metadata que a site key HML foi usada sem
   revelar o valor completo.
8. Subir novo container sem remover a imagem anterior.
9. Validar health local antes de trocar o proxy.
10. Trocar o upstream e executar os smokes da seção 11.
11. Observar erros e latência pelo período aprovado.
12. Registrar evidência sanitizada e decisão explícita de promoção.

Uma falha interrompe a sequência e aciona rollback. HML verde não autoriza PRD
automaticamente.

## 10. Ordem de implantação em PRD

Pré-condições: HML aprovada, privacidade revisada, janela/change autorizado,
backup/rollback verificados e registro PRD separado.

1. Confirmar que a imagem foi construída para a site key PRD; não promover a
   imagem HML se ela embute outra site key.
2. Injetar o secret PRD correspondente somente no runtime website.
3. Confirmar `RECAPTCHA_ALLOWED_HOSTNAMES` com o FQDN PRD exato.
4. Validar DNS, TLS, egress e backend sem exibir valores.
5. Fazer deploy canário ou troca atômica conforme o mecanismo aprovado da VPS.
6. Executar primeiro os smokes negativos, que não criam contato.
7. Executar um único smoke positivo com dados sintéticos identificáveis.
8. Confirmar contato `NEW`, outbox esperada e ausência de token CAPTCHA em todas
   as fronteiras.
9. Monitorar a janela e encerrar somente com owner, SHA, imagem, resultado e
   pendências registrados.

## 11. Plano de validação e smoke

### 11.1 Validação estática antes do deploy

No checkout aprovado, sem chaves reais:

```bash
cd website
npm run lint
npm run typecheck
npm test
npm run build
```

O build local sem site key comprova compilação, não ativação ambiental. A imagem
ambiental precisa ser reconstruída com a site key correspondente.

### 11.2 Smoke negativo

| Cenário | Resultado esperado | Backend/outbox |
| --- | --- | --- |
| Sem resolver checkbox | Botão indisponível e instrução pt-BR. | Nenhuma chamada. |
| Token ausente por chamada controlada | `400 CAPTCHA_REQUIRED`, `no-store`. | Nenhum contato/outbox. |
| Token expirado/reutilizado | `422 CAPTCHA_INVALID`. | Nenhum contato/outbox. |
| Hostname não permitido | `422 CAPTCHA_INVALID`. | Nenhum contato/outbox. |
| Secret/config ausente em ensaio de rollback controlado | `503 CAPTCHA_UNAVAILABLE`. | Nenhum contato/outbox. |
| Egress bloqueado/timeout controlado | `503 CAPTCHA_UNAVAILABLE`. | Nenhum contato/outbox. |

Não provoque falhas removendo configuração do container PRD ativo. Use HML,
fixture aprovada ou slot canário isolado.

### 11.3 Smoke positivo

1. abrir `/contate` no FQDN ambiental;
2. confirmar carregamento do checkbox e links de Privacidade/Termos;
3. preencher somente dados sintéticos autorizados;
4. resolver o desafio e enviar uma vez;
5. esperar `201/SUCCESS` na fronteira BFF;
6. confirmar cadastro `NEW` e duas intenções de notificação conforme UC-00051;
7. confirmar que nenhum log, banco, outbox ou payload backend contém
   `captchaToken` ou secret;
8. remover/identificar o contato sintético conforme a política de dados de teste,
   sem apagar evidência obrigatória de auditoria.

### 11.4 Evidência mínima

- ambiente, SHA, image digest, FQDN e timestamp;
- ID não secreto do registro reCAPTCHA;
- códigos HTTP e correlation IDs sanitizados;
- contagem de contatos/outbox antes/depois dos cenários negativos;
- evidência do único contato sintético positivo;
- métricas agregadas, sem token, IP bruto ou payload;
- resultado, falhas, skips, owner e decisão de rollback/promoção.

Screenshots devem ocultar site key completa quando a política interna assim exigir
e sempre ocultar secrets e dados pessoais.

## 12. Observabilidade e alertas

O BFF registra apenas evento `commercial_contact_captcha` com `outcome`,
`latencyMs`, `environment` e `correlationId`. A plataforma deve agregar:

- taxa e volume de `valid`, `invalid`, `required` e `unavailable`;
- p50/p95/p99 da latência de verificação;
- proporção entre validações válidas e contatos `SUCCESS`;
- respostas 429 do proxy/backend e 5xx do BFF;
- reinícios e health do container website.

Alertas recomendados devem usar baseline aprovado, não números inventados neste
runbook. Um aumento sustentado de `unavailable`, falha total de `valid` ou
divergência entre CAPTCHA válido e contato persistido abre incidente.

## 13. Rotação das chaves

Site key e secret formam um par. Como a site key é embutida no build, a rotação
exige nova imagem e configuração runtime coordenadas.

1. Criar novo registro/par no mesmo ambiente com o hostname aprovado.
2. Manter o registro anterior ativo durante a janela.
3. Construir nova imagem com a nova site key.
4. Preparar secret novo no slot/container novo, nunca no antigo.
5. Validar HML/canário e trocar o tráfego atomicamente.
6. Monitorar `valid`, `invalid` e `unavailable`.
7. Manter imagem + secret anteriores disponíveis pelo prazo de rollback aprovado.
8. Depois da janela, revogar o registro antigo e destruir cópias conforme a
   política de secrets.

Não trocar somente o secret em uma imagem que contém a site key antiga. Esse
descasamento causa falha fechada e deve ser tratado como erro de configuração.

## 14. Rollback

Rollback funcional restaura **imagem anterior + secret anterior + allowlist
anterior** como uma unidade:

1. retirar o novo upstream do tráfego;
2. restaurar container/imagem anterior saudável;
3. restaurar o env/secret correspondente sem imprimir valores;
4. validar health e smoke negativo;
5. validar um smoke positivo somente se autorizado;
6. manter o novo registro desabilitado ou isolado para investigação;
7. registrar causa, período, contatos potencialmente afetados e evidência.

Remover site key/secret para “desativar CAPTCHA” não é rollback: deixa o formulário
fail-closed. Bypassar a verificação ou apontar o formulário direto ao backend é
proibido.

## 15. Troubleshooting

| Sintoma | Verificação sanitizada | Causa provável | Ação segura |
| --- | --- | --- | --- |
| Checkbox não aparece | CSP do browser, request do script, presença da site key no build | Site key ausente, CSP/proxy ou bloqueador do cliente | Confirmar build/env e CSP; oferecer canal alternativo, sem bypass. |
| `CAPTCHA_UNAVAILABLE` imediato | Presença/forma das quatro variáveis, sem revelar valores | Secret/allowlist/timeout inválido | Corrigir config pareada e recriar somente website. |
| `CAPTCHA_UNAVAILABLE` após ~timeout | DNS/egress/TLS para Google e latência | Bloqueio de rede ou indisponibilidade externa | Restaurar egress mínimo ou aguardar; manter fail-closed. |
| `CAPTCHA_INVALID` para todos | FQDN observado e registro/site key ambiental | Hostname divergente ou par site/secret trocado | Corrigir registro/par; não ampliar allowlist com wildcard. |
| Widget valida, mas contato retorna `NOT_CONFIGURED` | Presença da URL/token técnico e rota exata | Integração BFF→backend incompleta | Corrigir `CONTACT_WEBHOOK_*`; não alterar CAPTCHA. |
| Widget valida, mas retorna `DELIVERY_ERROR` | Health/backend e correlation ID | Backend/contrato indisponível | Investigar backend; campos permanecem e novo CAPTCHA será exigido. |
| HML funciona e PRD não | Comparar IDs/FQDNs/build metadata, não secrets | Imagem HML promovida ou registro PRD incorreto | Rebuild PRD e restaurar par correto. |
| Muitos inválidos | Outcome agregado e comportamento de clientes | Expiração, replay, automação ou hostname | Não logar token; revisar janela, abuso e configuração. |

## 16. Checklist de liberação

### Infraestrutura

- [ ] Runtime Next.js do `website/` existe com healthcheck e rollback.
- [ ] `/api/contact` permanece same-origin e aponta ao website, não ao backend.
- [ ] DNS, TLS, proxy, egress e limites foram validados.
- [ ] Imagem anterior e env/secret correspondente estão recuperáveis.

### Google e configuração

- [ ] Registros HML/PRD são separados e têm owners de grupo.
- [ ] Tipo é reCAPTCHA v2 Checkbox.
- [ ] Hostname exato do ambiente está cadastrado, sem wildcard.
- [ ] Site key entrou no build correto; secret existe apenas no runtime.
- [ ] Allowlist e timeout atendem ao contrato.

### Segurança e privacidade

- [ ] Env file/secret store e permissões foram revisados.
- [ ] Logs, métricas, screenshots e tickets não contêm secret/token/PII.
- [ ] CSP não contém wildcard nem `unsafe-eval` em HML/PRD.
- [ ] Revisão de privacidade/cookies foi concluída antes da ativação pública.

### Validação

- [ ] Testes estáticos passaram no SHA implantado.
- [ ] Smokes negativos não criaram contato nem outbox.
- [ ] Smoke positivo criou um contato `NEW` sintético e o fluxo assíncrono esperado.
- [ ] Métricas e alertas foram observados na janela aprovada.
- [ ] Owner registrou decisão de promoção ou rollback.

## 17. Critério de conclusão

O onboarding do ambiente só está concluído quando todos os itens aplicáveis do
checklist estão marcados, a evidência sanitizada está anexada ao change ticket e
o owner confirma que chaves reais, runtime, proxy, observabilidade e rollback são
do mesmo ambiente. “Container saudável” ou “checkbox visível” isoladamente não
comprovam a integração.

## Change log

| Version | Date | Changes |
| --- | --- | --- |
| 1.0 | 2026-10-05 | Materializa estratégia HML/PRD para VPS, separação de chaves, runtime, custódia, deploy, smoke, rotação, rollback e troubleshooting. |
