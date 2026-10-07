# Contador Fiscal — Website

Landing page pública e independente do Contador Fiscal, construída com Next.js, React, TypeScript, Tailwind CSS e `next-intl`.

## Executar localmente

```bash
npm ci
npm run dev
```

O website abre em `http://localhost:3002`. A aplicação autenticada continua em `frontend/`, normalmente em `http://localhost:3000`.

No fluxo DEV integrado, inicie antes o backend pela raiz com
`./start-dev-bot.sh`. O comando `npm run dev` carrega as variáveis próprias do
website e, quando URL/token estiverem vazios, usa a URL local e extrai somente
`CONTACT_WEBHOOK_TOKEN` do arquivo owner-only `.env.dev.local` gerado pelo
launcher. O segredo não é copiado para `website/.env.local` nem exibido. Use
`npm run dev:check` para validar esse vínculo sem iniciar o Next.js. Reinicie o
website depois de qualquer rotação do token.

Quem executa um backend diferente pode configurar URL/token próprios em
variáveis do processo. Se usar `website/.env.local`, proteja-o antes com
`chmod 600 .env.local` (a partir deste diretório). URL e token devem ser fornecidos juntos; valores
não vazios têm precedência sobre o fallback DEV. Produção, build, exportação HTML
e `npm start` nunca leem o arquivo DEV da raiz e exigem injeção explícita das
variáveis.

## Versão HTML estática

```bash
npm run build:html
```

O comando recria `site-html/` com `index.html`, página 404, metadados para
buscadores e assets locais. O diretório pode ser publicado na raiz de qualquer
servidor de arquivos estáticos; ele não exige um processo Node.js em execução.

Como a versão estática não possui a rota server-side `/api/contact`, o envio real
do formulário exige um adaptador server-side equivalente na hospedagem. Um proxy
cego não é suficiente: o adaptador precisa validar e remover o honeypot, preservar
`Idempotency-Key` e acrescentar `X-Website-Contact-Token` sem expor o segredo no HTML.

## Configuração

| Variável                         | Uso                                                                          |
| -------------------------------- | ---------------------------------------------------------------------------- |
| `NEXT_PUBLIC_APP_URL`            | Origem da aplicação autenticada usada pelos links de login, painel e planos. |
| `NEXT_PUBLIC_SITE_URL`           | URL canônica do website, sitemap e metadata.                                 |
| `NEXT_PUBLIC_CONTACT_EMAIL`      | E-mail público opcional exibido como alternativa ao formulário.              |
| `CONTACT_WEBHOOK_URL`            | URL server-only exata de `POST /api/v1/public/commercial/contacts`.          |
| `CONTACT_WEBHOOK_TOKEN`          | Segredo obrigatório enviado em `X-Website-Contact-Token` somente pelo BFF.   |
| `NEXT_PUBLIC_RECAPTCHA_SITE_KEY` | Site key pública do Google reCAPTCHA v2 Checkbox.                            |
| `RECAPTCHA_SECRET_KEY`           | Secret key exclusiva do BFF; nunca use prefixo `NEXT_PUBLIC_`.               |
| `RECAPTCHA_ALLOWED_HOSTNAMES`    | Hostnames exatos aceitos, separados por vírgula e sem wildcard.              |
| `RECAPTCHA_VERIFY_TIMEOUT_MS`    | Timeout inteiro entre 500 e 5000 ms; padrão local de 3000 ms.                |

`CONTACT_WEBHOOK_URL` deve conter o endpoint exato, sem query ou fragmento, usar
HTTPS em produção e só pode usar HTTP com host `localhost` fora de produção. Sem
URL e token técnico válidos, o formulário responde com indisponibilidade de
configuração e nunca simula sucesso. Quando `NEXT_PUBLIC_CONTACT_EMAIL` está
definido, a interface oferece esse canal alternativo real; esse endereço público é
independente dos destinatários privados configurados na Central de Notificações.

As quatro variáveis do reCAPTCHA devem ser injetadas pelo ambiente que executa o
website. Configuração ausente ou inválida mantém o botão indisponível e faz o BFF
falhar fechado. O token do desafio vive somente na memória do navegador, é
verificado pelo BFF em `https://www.google.com/recaptcha/api/siteverify` e é
removido antes do encaminhamento ao backend. Os testes usam doubles locais e não
dependem de chaves reais nem de chamadas ao Google.

O navegador gera uma chave idempotente estável para os dados comerciais e envia sempre para
`POST /api/contact`, na mesma origem. O BFF valida e preserva essa chave e encaminha
somente `name`, `email`, `company`, `phone`, `plan` e `message` ao backend. A
confirmação indica que o contato foi registrado como `NEW`; a notificação por
e-mail acontece depois, pelo outbox do backend, e não condiciona a resposta do
formulário.

O endpoint valida e limita o corpo, usa honeypot e timeout. O rate limit autoritativo
é compartilhado no backend; uma borda que conheça o IP de origem também pode aplicar
uma política adicional. O BFF não confia em cabeçalhos de IP fornecidos pelo cliente.

## Fluxo de planos

Os CTAs aceitam somente `START`, `BUSINESS` e `PREMIUM` e apontam para o login da aplicação com um `returnTo` fixo para `/billing/plans`. O website não chama o checkout protegido e não publica preços dos mocks.

O frontend atual ainda precisa consumir `plan` e `returnTo` para fazer a preseleção automática após autenticação. Até essa integração existir, os parâmetros preservam a intenção no link, mas o website não promete seleção automática.

Os preços não são publicados porque a documentação comercial não fornece valores vigentes. Os cards exibem apenas público, limite de empresas e recursos documentados.

## Governança do brief

Não há prompt operacional ativo em `website/prompt/`. O
[ponteiro legado](prompt/README.md) encaminha seletivamente ao
[TP-00021](../../docs/specs/TP-00021-hub-contabil-landing-page-implementation-brief.md),
única fonte canônica do brief da landing page.

## Segurança

O runtime Next.js envia CSP, proteção contra framing, `nosniff`, política de
referência e uma política restritiva de permissões. Na exportação estática, esses
cabeçalhos devem ser configurados pelo servidor de arquivos ou CDN. A URL do backend
e o token técnico permanecem server-only.

## Validação

```bash
npm run format:check
npm run lint
npm run typecheck
npm run test
npm run build
npm run test:e2e
```

Na primeira execução local dos testes de navegador, instale o Chromium com `npx playwright install chromium`.

O build usa Webpack porque o processamento PostCSS do Turbopack precisa abrir uma porta interna em alguns ambientes restritos.
