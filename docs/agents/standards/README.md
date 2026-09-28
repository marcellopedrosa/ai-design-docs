---
document_id: STANDARDS-INDEX
primary_nature: Contexto
objective: Catalogar a biblioteca portátil e permitir seleção semântica sem carregar todos os standards.
scope: Regras reutilizáveis de lifecycle, engenharia, arquitetura, interfaces, testes, segurança e supply chain.
non_objectives: Não duplicar conteúdo normativo, ativar uma stack ou substituir especialização do projeto adotante.
owner: Arquitetura e Qualidade
status: Active
version: 2.5
date: 2026-09-10
last_reviewed: 2026-09-28
keywords: standards, catalogo, nucleo-agnostico, lifecycle, readiness, qualidade, seguranca, appsec, entrega-git, branch, hook, stack, ativacao-condicional
related_files: ../AgentOrchestrator.md, ../skills/README.md, software-engineering-lifecycle.md, implementation-readiness-standard.md, software-quality-standard.md, development-standard.md, security-standard.md, application-security-standard.md, api-security-standard.md, spring-security-standard.md, ../../settings/settings.md, ../../adrs/ADR-0000-governanca-do-harness-documental.md
code_references: N/A - standards documentais; ativação executável pertence ao projeto adotante.
principal_statement: Esta coleção é a fonte canônica da biblioteca portátil; presença disponibiliza uma regra, enquanto escopo, risco, ADR e manifesto determinam sua ativação.
---

# Standards

## Contrato e canonicidade

- Conteúdo aceito: regra técnica reutilizável, verificável e com aplicabilidade
  explícita.
- Nomes: assunto-standard.md, salvo nomes estáveis do baseline.
- Standards especializados de segurança novos preferem o formato
  `<capacidade>-security-standard.md`; nomes estáveis preexistentes não são
  renomeados apenas por padronização para evitar quebra de referências.
- Estados permitidos: Draft, Active, Deprecated.
- Critério de granularidade: separar quando regra, owner, consumidores ou ciclo de
  revisão forem independentes.
- Cada arquivo listado abaixo é a referência canônica dentro deste harness. Após a
  adoção, a cópia versionada no projeto de destino torna-se sua referência local e
  deve ser especializada ali, sem links normativos para o repositório de origem.

Status Active informa que a regra da biblioteca está vigente; não significa que a
tecnologia ou capacidade esteja ativa no projeto. O campo Ativação controla a
aplicabilidade.

Esta biblioteca possui dois níveis. O núcleo agnóstico pode ser levado para
qualquer projeto de software compatível com o harness. A biblioteca condicional
permanece disponível no harness-fonte, mas só deve ser ativada ou copiada quando a
capacidade, a stack, o risco ou a decisão arquitetural correspondente existir no
projeto adotante.

## Núcleo agnóstico

| Standard | Escopo | Ativação | Status |
| --- | --- | --- | --- |
| [Software Engineering Lifecycle](software-engineering-lifecycle.md) | Sequência C.L.E.A.R. e gates | Mudança de software; fases condicionais podem ser N/A com justificativa | Active |
| [Implementation Readiness](implementation-readiness-standard.md) | Gate anterior à escrita executável | Todo handoff executável; N/A para alteração sem execução | Active |
| [Software Quality](software-quality-standard.md) | A1 Test, A2 Quality e A3 Security/Compliance | Mudança de software; alteração exclusivamente documental segue seu gate próprio | Active |
| [Development](development-standard.md) | Práticas de implementação e manutenção | Toda escrita executável | Active |
| [Security](security-standard.md) | Menor privilégio, dados e evidência A3 | Mudança de software e documentação operacional; profundidade por risco | Active |
| [Project Reporting](project-reporting-standard.md) | Status, métricas e blockers reproduzíveis | Quando houver reporting recorrente | Active |

O núcleo é agnóstico de linguagem, framework, banco, provedor, protocolo e
topologia. `security-standard` é baseline de segurança; os standards especializados
e a skill `security-gate` aprofundam A3 somente quando ativados.

## Biblioteca condicional

Os grupos a seguir podem permanecer na biblioteca portátil, mas não devem ser
tratados como baseline automático. Em um projeto adotante, a ausência da capacidade
correspondente permite não copiar ou remover o standard, desde que os índices e
referências locais sejam reconciliados.

### Segurança especializada

| Standard | Escopo | Ativação | Status |
| --- | --- | --- | --- |
| [Application Security](application-security-standard.md) | Controles verificáveis de AppSec para aplicações expostas | Aplicação web/backend web, auth/authz, dado sensível ou entrada não confiável | Active |
| [API Security](api-security-standard.md) | Autorização de objeto/função/propriedade, abuso, SSRF e consumo seguro | API criada, alterada, publicada ou consumida | Active |
| [Spring Security](spring-security-standard.md) | Spring Security, OAuth2/OIDC/JWT, sessão, CSRF, CORS, Actuator e controles Java web | Spring Boot/Spring Security registrado no projeto | Active |

Os standards desta seção aprofundam A3 e não criam um security gate separado. A
skill `security-gate` pode executá-los como subgate A3 e devolver evidência ao
`quality-gate`.

### Backend, arquitetura e integração

| Standard | Escopo | Ativação | Status |
| --- | --- | --- | --- |
| [API Client](api-client-standard.md) | Contrato HTTP e paridade produtor/consumidor | API HTTP criada, alterada ou consumida | Active |
| [Backend Testing](backend-testing-standard.md) | Unidade, integração, persistência e contrato | Componente server-side ativo | Active |
| [DDD and Clean Architecture](ddd-clean-architecture-standard.md) | Domínio, ports, adapters e boundaries | ADR adota esses padrões | Active |
| [Java](java-standard.md) | Linguagem, toolchain e práticas JVM | Módulo Java no manifesto | Active |
| [Modulith](modulith-standard.md) | Módulos, interfaces e dependências | ADR adota monólito modular | Active |
| [WebSocket](websocket-standard.md) | Contrato e lifecycle bidirecional | ADR e contrato adotam WebSocket | Active |

### Frontend e experiência

| Standard | Escopo | Ativação | Status |
| --- | --- | --- | --- |
| [Frontend](frontend-standard.md) | Boundaries, renderização, dados e estados | Aplicação cliente ativa | Active |
| [Frontend Testing](frontend-testing-standard.md) | Unidade, componente, integração e E2E | Aplicação cliente ativa | Active |
| [Next.js](nextjs-standard.md) | App Router, server/client e cache | Módulo Next.js no manifesto | Active |
| [State Management](state-management-standard.md) | Estado local, remoto, URL e persistência | Estado cliente não trivial | Active |
| [Component Design](component-design-standard.md) | Tokens, primitives, variantes e estados | UI reutilizável ou design system | Active |
| [Data Grid](data-grid-standard.md) | Tabelas, filtros, sort, paginação e volume | Grid ou tabela de dados complexa | Active |
| [Form Validation](form-validation-standard.md) | Schema, erros e submissão | Formulário com entrada de usuário | Active |
| [Accessibility](a11y-standard.md) | Semântica, teclado, foco e percepção | Toda interface ativa | Active |
| [Internationalization](i18n-standard.md) | Locale, mensagens, formatos e timezone | Produto multilíngue ou multirregional | Active |
| [UI/UX](ui-ux-standard.md) | Clareza, feedback e segurança de interação | Fluxo de interface criado ou alterado | Active |
| [Web Designer](webdesigner-standard.md) | Capacidade e handoff de design web | Trabalho de design requerido | Active |
| [RBAC Frontend](rbac-frontend-standard.md) | Representação de autorização na UI | Acesso diferenciado no frontend | Active |
| [Keycloak Frontend](keycloak-frontend-standard.md) | OIDC/OAuth com Keycloak | Keycloak adotado por ADR/configuração | Active |

### Infraestrutura e supply chain

| Standard | Escopo | Ativação | Status |
| --- | --- | --- | --- |
| [IaC and Supply Chain](iac-supply-chain-standard.md) | Proveniência, pinning, SBOM e integridade | IaC, containers ou dependências externas | Active |

## Seleção e especialização

1. O [AgentOrchestrator](../AgentOrchestrator.md) classifica a mudança e aplica o
   baseline transversal pertinente.
2. ADRs aceitos, requirements, contratos, riscos e o manifesto ativam standards
   condicionais.
3. O plano registra cada standard aplicável com path e versão; N/A exige motivo.
4. O projeto completa versões, ferramentas, comandos, thresholds, owners e paths
   que o arquivo portátil deliberadamente não presume.
5. Um standard não aplicável permanece na biblioteca e não precisa ser removido.
6. Regra local pode elevar ou especializar o baseline, mas não o enfraquecer sem
   decisão arquitetural explícita.
7. Para A3 de aplicação, o `quality-gate` pode acionar `security-gate`; a skill
   executa standards selecionados e devolve evidência, sem criar gate autônomo.
8. No projeto adotante, standards condicionais sem capacidade correspondente podem
   ficar ausentes, desde que sua ausência seja refletida no catálogo e nos links
   locais; no harness-fonte, eles permanecem disponíveis como biblioteca portátil.

Entrega Git não é um standard adicional nem uma ativação implícita deste catálogo:
quando adotada, é uma capacidade operacional sujeita à política, aos gates, ao hook
local de commit e ao enforcement local descritos pela skill `git-delivery`.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 2.5 | 2026-09-28 | Separa o núcleo agnóstico da biblioteca condicional e explicita critérios para adoção e remoção por contexto. |
| 2.4 | 2026-09-28 | Atualiza a integração dos standards especializados para o subgate `security-gate` do A3. |
| 2.3 | 2026-09-28 | Adiciona standards especializados de Application, API e Spring Security e convenção `<capacidade>-security-standard.md`. |
| 2.2 | 2026-09-13 | Explicita hook local e settings como parte da ativacao opt-in de entrega Git. |
| 2.1 | 2026-09-13 | Relaciona lifecycle, qualidade e desenvolvimento à capacidade opt-in de entrega Git. |
| 2.0 | 2026-09-11 | Incorpora a biblioteca portátil completa e separa disponibilidade, status e ativação por projeto. |
