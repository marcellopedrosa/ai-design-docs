---
document_id: "TP-00021"
primary_nature: "Plano"
objective: "Coordenar a implementação da landing page do Contador Fiscal a partir das fontes aprovadas de produto, design, autenticação e billing."
scope: "Website público, proposta de valor, planos, navegação, acessibilidade, autenticação e caminho até assinatura."
non_objectives: "Não substituir requisitos, ADRs ou fontes comerciais; não aprovar preços, benefícios, deploy ou acesso externo por implicação."
owner: "Produto e Website"
status: Draft
date: "2026-08-26"
version: "1.3"
last_reviewed: "2026-09-05"
keywords: "plano, landing-page, website, produto, planos, conversao"
related_files: "do../../product/business/product-vision.md, do../../product/business/analise-financeira-precificacao.md, do../../product/requirements/README.md, docs/delivery/plans/README.md"
code_references: "frontend/, website/"
principal_statement: "A landing page deve ser implementada somente a partir de fontes aprovadas, sem inventar preços, benefícios, rotas, permissões ou integrações."
---

# TP-00021 — Brief de implementação da landing page do Contador Fiscal

Você é uma equipe sênior formada por product designer, UX writer, engenheiro frontend Next.js, especialista em acessibilidade, SEO técnico e segurança. Trabalhe diretamente neste repositório e entregue uma landing page pública, responsiva, convincente e pronta para produção para o **Contador Fiscal**.

Não entregue apenas wireframe, explicação ou código ilustrativo: inspecione o projeto, implemente a solução, execute as validações possíveis e apresente o resultado final.

## 1. Objetivo

Transforme a rota pública `/` em uma landing page B2B do Contador Fiscal que:

- explique com clareza o produto e o problema resolvido para escritórios de contabilidade;
- mostre previews fiéis das telas já implementadas em `frontend`;
- apresente os três tipos de plano e suas características sem inventar condições comerciais;
- conduza o visitante até login/cadastro e, depois da autenticação, ao fluxo existente de escolha e assinatura do plano;
- tenha no menu, exatamente nesta ordem, **Quem somos**, **Clientes**, **Planos** e **Contate**;
- funcione bem em celular, tablet e desktop;
- preserve todas as rotas, permissões, integrações e telas autenticadas existentes.

O site deve ter a clareza comercial e o ritmo visual de uma landing page SaaS moderna, usando como referência estrutural `https://www.organizze.com.br/`, mas **sem copiar** textos, marca, cores, imagens, ilustrações, composição exata ou código da Organizze.

Use da referência apenas os princípios: hero orientado a benefício, CTA evidente e recorrente, produto visível, explicação em etapas, blocos de funcionalidades, planos comparáveis, FAQ e encerramento com CTA.

## 2. Leitura obrigatória e fontes de verdade

Antes de alterar qualquer arquivo, leia integralmente:

1. `do../../product/business/product-vision.md` — fonte principal para posicionamento, público, regras e características dos planos;
2. `frontend/src/styles/design-tokens.css` e `frontend/src/app/globals.css` — fonte da identidade visual;
3. `frontend/src/app`, `frontend/src/components`, `frontend/src/lib/menu-config.ts` e `frontend/src/lib/paths.ts` — fonte das telas e rotas existentes;
4. `frontend/src/types/billing.ts`, `frontend/src/services/billingService.ts`, `frontend/src/components/billing/plans` e `frontend/src/mocks/data/billing.ts` — fonte da estrutura técnica dos planos e do fluxo atual de assinatura;
5. `frontend/src/proxy.ts`, `frontend/src/providers/AuthProvider.tsx` e os testes de autenticação/RBAC — fonte das restrições de segurança.

Se houver divergência, use esta prioridade:

1. `do../../product/business/product-vision.md` para afirmações de negócio e marketing;
2. contrato/API real e `frontend/src/types/billing.ts` para dados operacionais;
3. componentes e telas em produção para comportamento e aparência;
4. mocks apenas como dados de demonstração local, nunca como verdade comercial.

Os preços existentes em mocks são fictícios até confirmação. Não os transforme em preços públicos fixos. Não invente período de teste, desconto anual, franquia de consultas, preço de excedente, regra de cancelamento, garantia, meio de pagamento ou SLA.

## 3. Contexto do produto que deve aparecer na comunicação

O Contador Fiscal é um micro SaaS B2B multi-tenant para escritórios de contabilidade. Ele permite que clientes autorizados consultem a situação fiscal pelo WhatsApp, com integração ao Integra Contador/SERPRO Federal e uso seguro de certificados digitais.

Comunique estes pilares em linguagem simples:

- autoatendimento fiscal pelo WhatsApp;
- vínculo rigoroso entre telefone autorizado e documento/empresa;
- isolamento de dados entre escritórios;
- upload e armazenamento criptografado de certificados digitais;
- consulta de situação fiscal e apoio à emissão de DARF;
- painel com clientes, contatos autorizados, consumo, auditoria e histórico;
- rastreabilidade de falhas por `correlationId`;
- redução do trabalho manual e mais tempo para atendimento consultivo.

Não prometa que o produto substitui o contador. Não o descreva como banco, ERP contábil completo ou consultoria tributária. Não declare certificações, conformidade legal, uptime, número de clientes ou integrações que não estejam comprovados no repositório.

## 4. Direção de marca e visual

Use o nome **Contador Fiscal** na comunicação pública. Se for necessário conciliar o nome interno “Contador Fiscal”, trate-o como um módulo ou recurso do Contador Fiscal; não renomeie todo o sistema autenticado sem necessidade.

Reutilize os tokens existentes, sem criar uma segunda identidade visual:

- primária: `#1E40AF`;
- primária escura: `#1E3A8A`;
- primária clara: `#3B82F6`;
- fundo claro: `#F8FAFC`;
- superfícies: `#FFFFFF`;
- texto principal: `#0F172A`;
- texto secundário: `#64748B`;
- borda: `#E2E8F0`;
- sucesso: `#16A34A`;
- atenção/destaque Premium: `#F59E0B` quando semanticamente adequado;
- tipografia: a pilha `Aptos`, `Segoe UI Variable`, `Helvetica Neue`, `sans-serif` já definida.

Prefira fundo claro, muito espaço em branco, seções bem ritmadas, cards com `radius` e sombras dos tokens, ícones Lucide e detalhes azuis discretos. Gradientes só podem ser sutis e derivados da paleta. Evite aparência de template genérico, excesso de efeitos, glassmorphism pesado, ilustrações aleatórias e blocos de texto longos.

Respeite também o tema escuro já existente, garantindo contraste e legibilidade, sem alterar os tokens globais para “forçar” a landing page.

## 5. Arquitetura da página e conteúdo

Implemente a página como uma narrativa única. Use os IDs de seção `#quem-somos`, `#clientes`, `#planos` e `#contate` para os itens obrigatórios do menu.

### 5.1 Cabeçalho

- Cabeçalho sticky, compacto e legível sobre qualquer seção.
- Marca Contador Fiscal à esquerda.
- Menu desktop com: **Quem somos**, **Clientes**, **Planos**, **Contate**.
- Ações à direita: **Entrar** e um CTA primário como **Conhecer os planos**.
- Em telas pequenas, menu off-canvas ou dropdown acessível, com foco controlado, fechamento por `Escape`, clique fora e seleção de item.
- Se o usuário já estiver autenticado, substitua a ação principal por **Ir para o painel** quando isso puder ser feito sem piscar conteúdo nem bloquear a renderização pública.

### 5.2 Hero

Crie copy original, direta e específica. Direção recomendada:

- eyebrow: “Autoatendimento fiscal para escritórios contábeis”;
- H1: “Consultas fiscais pelo WhatsApp, com segurança e escala para o seu escritório.”;
- apoio: explique que contatos autorizados consultam a situação fiscal enquanto o escritório acompanha tudo em um painel auditável;
- CTA primário: **Conhecer os planos**;
- CTA secundário: **Ver a plataforma**;
- microcopy sem promessas inventadas, por exemplo: “Comece pelo plano adequado ao tamanho da sua carteira”.

Ao lado do texto, mostre uma composição fiel ao produto: um preview do painel web e uma conversa de WhatsApp sobre situação fiscal. Use dados fictícios claramente sanitizados, nunca dados reais de tenants, empresas, pessoas, documentos, telefones ou certificados.

### 5.3 Faixa de confiança

Use ícones e texto — não logotipos oficiais sem ativo e autorização — para reforçar:

- integração com Integra Contador/SERPRO;
- dados isolados por escritório;
- certificados protegidos;
- histórico auditável.

### 5.4 Quem somos

Explique a missão do Contador Fiscal: permitir que escritórios ofereçam autoatendimento fiscal confiável e dediquem mais tempo a trabalho consultivo. Apresente os quatro participantes do ecossistema de forma simples: administrador do SaaS, escritório assinante, contador responsável e cliente final via WhatsApp.

### 5.5 Como funciona

Apresente uma jornada numerada e responsiva:

1. o escritório cadastra empresas e contatos autorizados;
2. o contador configura o certificado digital com proteção adequada;
3. o cliente solicita a consulta pelo WhatsApp;
4. o Hub consulta o serviço fiscal, retorna o resultado e registra a interação.

Mostre também os estados reais do fluxo sem transformar a seção em documentação técnica: regular, pendente/irregular com possibilidade de DARF, serviço governamental indisponível, contato não autorizado e documento inválido.

### 5.6 Plataforma por dentro

Não use mockup genérico desconectado do sistema. Baseie os previews nas rotas e componentes realmente implementados no `frontend`.

Crie uma galeria por tabs, carrossel acessível ou blocos alternados que contemple, no mínimo:

- **Painel:** KPIs, evolução fiscal e consultas recentes;
- **Clientes:** empresas, contatos autorizados e limites de uso;
- **Fiscal:** situação fiscal, débitos, DARF/DAS, documentos e processamento em lote conforme o que estiver implementado;
- **Certificados:** lista, status, vencimento e upload seguro;
- **Atendimento:** caixa de entrada, conversa e configurações de chatbot/WhatsApp;
- **Assinatura:** plano atual, consumo, excedentes e faturas;
- **Administração:** escritórios, usuários, logs e notificações, sem expor opções exclusivas como se todos os clientes as recebessem.

Você pode:

- capturar screenshots locais com MSW/dados fictícios, sanitizá-las e salvá-las em formato otimizado em `frontend/public/images/landing`; ou
- criar previews estáticos em React, reutilizando os componentes puramente visuais e os design tokens existentes.

Não monte a landing importando diretamente componentes autenticados que disparem queries protegidas, dependam de tenant ou causem redirecionamento. Não use iframe da aplicação. Toda imagem deve ter dimensões definidas, texto alternativo útil e nenhuma informação sensível.

### 5.7 Clientes

Como não há prova social aprovada no documento de negócio, não invente depoimentos, nomes, logos, avaliações ou números de clientes.

Use a seção **Clientes** para mostrar a adequação por perfil:

- escritório validando o autoatendimento com poucas empresas;
- escritório pequeno ou médio com carteira ativa e busca por produtividade;
- grande escritório ou franquia que precisa de volume, múltiplos certificados e visão avançada.

Se o repositório contiver depoimentos e marcas explicitamente aprovados para uso público, eles podem ser adicionados com sua fonte; caso contrário, mantenha a segmentação por perfil.

### 5.8 Planos e assinatura

Mostre três cards em ordem crescente e uma comparação detalhada acessível. A pessoa deve entender imediatamente para quem é cada plano, o limite de empresas, o que está incluído e como funciona o excedente quando documentado.

Use obrigatoriamente estas informações de negócio:

#### Start — Degustação

- para validar o fluxo antes de migrar a carteira;
- até 2 empresas/clientes;
- consulta de situação fiscal;
- integração Telegram.

#### Business

- para escritórios pequenos e médios com carteira ativa;
- até 20 empresas/clientes;
- integração Telegram ou WhatsApp;
- suporte prioritário;
- redução de até 70% do atendimento humano para dúvidas fiscais básicas;
- valor fixo mensal mais pacote de consultas excedentes.

#### Premium

- para grandes escritórios e franquias;
- limite de empresas/clientes definido em consultoria;
- atendimento pelos canais Telegram ou WhatsApp;
- dashboard avançado de performance de atendimento;
- múltiplos certificados contábeis;
- tarifa reduzida por consulta;
- relatório mensal de economia de horas/homem.

Regras de implementação dos planos:

- preserve os tipos `START`, `BUSINESS` e `PREMIUM` de `PlanType`;
- use a terminologia pública “empresas/clientes (CPF ou CNPJ)” de forma consistente, mesmo que o contrato interno ainda use `documentos`;
- quando houver endpoint público, seguro e funcional para listar planos, use os dados reais de `PlanDetail` para preço, features, limites e destaque;
- se o endpoint exigir autenticação, mostre na landing apenas as características documentadas e leve o usuário autenticado à tela existente de planos para consultar valores e assinar;
- nunca hardcode no marketing os preços de `mockPlans` sem confirmação explícita;
- não crie alternância mensal/anual sem dados reais para ambas as modalidades;
- não marque Business como “mais popular” nem Premium como “sob consulta” por suposição; renderize destaque apenas se ele vier de fonte aprovada ou do campo real `highlight`;
- não esconda diferenças apenas por cor: use texto, ícones e rótulos;
- em telas estreitas, empilhe os cards e transforme a tabela comparativa em blocos legíveis ou ofereça rolagem com indicação clara.

O CTA público de cada card deve preservar somente um `PlanType` válido, encaminhar o visitante ao login/cadastro e, depois da autenticação, à rota protegida `/billing/plans`. Usuário autenticado com permissão adequada pode ir direto para essa rota.

Não chame checkout protegido diretamente da página pública, não duplique a lógica de `StripeCheckoutButton` e não aceite `returnTo` ou URL arbitrária sem validação. Reutilize o fluxo de checkout existente depois da autenticação. Não exiba sucesso de pagamento simulado.

### 5.9 Segurança e privacidade

Crie um bloco comercial curto sobre:

- isolamento multi-tenant;
- validação telefone x documento;
- criptografia de certificados;
- auditoria das interações;
- tratamento seguro das falhas de integração.

Não use o selo “LGPD compliant”, “100% seguro” ou equivalentes sem comprovação formal.

### 5.10 FAQ

Crie um accordion acessível com respostas derivadas apenas das fontes do projeto. Cubra:

- o que é o Contador Fiscal;
- quem pode consultar pelo WhatsApp;
- como os dados dos escritórios são separados;
- para que serve o certificado digital;
- o que acontece quando o SERPRO está indisponível;
- as diferenças entre Start, Business e Premium;
- como escolher e assinar um plano.

Não invente política de cancelamento, reembolso, prazo de teste ou suporte 24/7.

### 5.11 Contate

Crie a seção `#contate` com título acolhedor, canais de contato configuráveis e um formulário curto para lead B2B: nome, e-mail profissional, escritório, telefone/WhatsApp opcional, plano de interesse e mensagem.

- Valide os campos no cliente e no servidor quando houver envio ao servidor.
- Nunca registre PII no console ou em logs.
- Inclua feedback de envio com `aria-live`.
- Implemente honeypot e uma defesa básica contra abuso se criar Route Handler.
- Use variáveis de ambiente server-only para webhook/destino e timeout de rede.
- Não simule sucesso. Se não existir integração de contato configurada, ofereça um canal real configurável e documente a variável necessária, sem botão inerte.

Finalize com um CTA para planos e acesso ao sistema.

### 5.12 Rodapé

Inclua marca, descrição curta, os quatro links do menu, acesso ao sistema e copyright com ano dinâmico. Só mostre Política de Privacidade, Termos ou redes sociais se as rotas/URLs reais existirem; não crie links quebrados.

## 6. Requisitos técnicos

- Mantenha o stack atual: Next.js App Router, React, TypeScript estrito, Tailwind CSS e `next-intl`.
- Implemente a página em `frontend/src/app/page.tsx` e extraia seções para `frontend/src/components/marketing` quando isso melhorar manutenção.
- Use Server Components por padrão. Marque como client apenas navegação móvel, tabs/accordion e interações que realmente precisem de estado/browser.
- Reutilize `Button`, `Card`, tokens, utilitário `cn`, ícones Lucide e padrões do projeto antes de criar abstrações novas.
- Centralize todo texto visível em mensagens `pt-BR` seguindo o padrão de i18n existente; evite strings duplicadas espalhadas.
- Não adicione dependência sem necessidade comprovada.
- Use `next/image` para imagens raster, formatos modernos e carregamento lazy fora do hero.
- Animações devem ser breves, discretas e desativadas com `prefers-reduced-motion`.
- Não use HTML externo copiado, `dangerouslySetInnerHTML`, scripts de terceiros ou imagens remotas não aprovadas.

### Rota pública sem regressão de segurança

A rota `/` hoje redireciona para o painel. Substitua o redirecionamento pela landing e torne apenas `/` pública.

Ao incluir `PATHS.HOME` em `PUBLIC_PATHS`, corrija `matchesRoute` em `frontend/src/proxy.ts` para tratar `/` como correspondência **somente exata**. Uma implementação ingênua pode fazer `/` corresponder a todas as rotas e alterar o tratamento de segurança/cache de todo o app.

Adicione teste explícito provando que:

- `/` é pública;
- `/login` e `/callback` continuam públicos;
- `/dashboard`, `/clients`, `/billing` e demais rotas protegidas continuam protegidas;
- os cabeçalhos CSP e de segurança permanecem ativos.

Não mova telas autenticadas para o layout público e não relaxe RBAC.

## 7. Responsividade e acessibilidade

Trabalhe mobile-first e valide, no mínimo, larguras de 360, 390, 768, 1024 e 1440 px.

- Nenhum scroll horizontal acidental.
- Áreas de toque com pelo menos 44 × 44 px.
- Um único H1; hierarquia sem saltos incoerentes.
- Landmarks semânticos, link “pular para o conteúdo”, labels e nomes acessíveis.
- Contraste WCAG 2.2 AA e foco visível.
- Navegação completa por teclado.
- Accordions e tabs com estado e atributos ARIA corretos.
- Carrossel, se usado, sem autoplay e com controles acessíveis.
- Informações dos planos compreensíveis sem depender de cor ou hover.

## 8. SEO, desempenho e conteúdo

- Atualize `metadata` com título e descrição específicos para a landing em pt-BR.
- Configure Open Graph/Twitter apenas com ativos locais reais.
- Use URL canônica configurável, sem hardcode de domínio desconhecido.
- Adicione JSON-LD de `Organization` e `SoftwareApplication` apenas com dados comprovados; não inclua nota, review, preço ou oferta inventados.
- Garanta HTML útil já no SSR, boa estabilidade visual e carregamento rápido.
- Evite JavaScript desnecessário, imagens pesadas e fontes externas bloqueantes.
- Use linguagem brasileira natural, frases curtas e foco no benefício para o escritório.

## 9. Critérios de aceite

A tarefa só está concluída quando:

1. `/` exibe uma landing pública, sem redirecionar para `/dashboard`;
2. o menu contém **Quem somos**, **Clientes**, **Planos**, **Contate** e funciona por âncoras no desktop e no mobile;
3. a página usa a paleta/tipografia do `frontend` e funciona nos temas claro e escuro;
4. previews reconhecíveis das telas reais do sistema aparecem com dados sanitizados;
5. Start, Business e Premium têm público, limite e características corretos;
6. nenhum preço ou benefício não aprovado foi inventado;
7. o visitante consegue selecionar um plano e seguir de forma segura até autenticação e tela de assinatura;
8. todos os CTAs e links têm ação real; não há botões decorativos que parecem interativos;
9. `/dashboard` e demais rotas internas continuam protegidas e funcionais;
10. não há regressões de RBAC, CSP, autenticação, i18n ou checkout;
11. a página não apresenta overflow em 360 px e é utilizável por teclado;
12. lint, testes relevantes, build e checagem de acessibilidade passam, ou qualquer falha preexistente é isolada e documentada com evidência.

## 10. Validação obrigatória

Execute, a partir de `frontend`, pelo menos:

```bash
npm run lint
npm run test
npm run build
```

Crie/atualize testes unitários e Playwright para cobrir:

- renderização e ordem das seções;
- menu mobile e navegação por âncora;
- cards e comparação dos três planos;
- preservação segura do `PlanType` escolhido;
- comportamento de CTA anônimo e autenticado;
- formulário/canal de contato;
- ausência de overflow nas principais larguras;
- auditoria Axe/WCAG na landing;
- correspondência exata da rota pública `/` sem liberar rotas protegidas.

## 11. Forma da entrega

Antes de codificar, apresente um plano curto e indique os arquivos que pretende alterar. Depois implemente sem parar no planejamento.

Ao finalizar, informe de forma objetiva:

- o que foi implementado;
- arquivos criados e alterados;
- como os dados de planos foram obtidos;
- como funciona o caminho landing → autenticação → assinatura;
- comandos de validação executados e resultados;
- limitações reais ou configurações ainda necessárias, sem mascará-las com mocks.

## 12. Change Log

| Version | Date | Changes |
| --- | --- | --- |
| 1.3 | 2026-09-05 | Reconcilia também os canais com o website vigente: Start apresenta Telegram; Business e Premium apresentam Telegram ou WhatsApp. |
| 1.2 | 2026-09-05 | Reconcilia o brief com o website vigente: Start até 2 empresas/clientes, Business até 20 e Premium definido em consultoria. |
| 1.1 | 2026-08-26 | Preserva o brief da landing pública e seus guardrails de conteúdo, segurança e validação. |
