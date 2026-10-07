---
document_id: STANDARDS-INDEX
document_scope: project
primary_nature: Contexto
objective: Catalogar a biblioteca portátil e permitir seleção semântica sem carregar todos os standards.
scope: Regras reutilizáveis de lifecycle, engenharia, arquitetura, interfaces, testes, segurança e supply chain.
non_objectives: Não duplicar conteúdo normativo, ativar uma stack ou substituir especialização do projeto adotante.
owner: Arquitetura e Qualidade
status: Active
version: 2.6
date: 2026-09-10
last_reviewed: 2026-09-28
keywords: standards, catalogo, nucleo-agnostico, lifecycle, readiness, qualidade, seguranca, appsec, entrega-git, branch, hook, stack, ativacao-condicional
related_files: ./global/software-engineering-lifecycle.md, ./global/implementation-readiness-standard.md, ./global/software-quality-standard.md, ./global/development-standard.md, ./global/security-standard.md
code_references: N/A - standards documentais; ativação executável pertence ao projeto adotante.
principal_statement: Esta coleção pertence ao projeto e indexa os standards locais; corporate-presets fornece o metamodelo e os gates sem assumir seu conteúdo final.
---

# Standards

Os [standards globais](global/README.md) são conteúdo deste projeto. O harness
descobre sua localização pelo Registry, mas o projeto responde por sua vigência,
especialização e critérios locais.

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
- Cada arquivo listado abaixo é a referência canônica deste projeto. Se outro
  projeto copiar um standard, a cópia versionada passa a ser sua fonte local,
  sem dependência normativa deste repositório.

Status Active informa que a regra da biblioteca está vigente; não significa que a
tecnologia ou capacidade esteja ativa no projeto. O campo Ativação controla a
aplicabilidade.

Este catálogo distingue os standards globais existentes de exemplos condicionais.
Estes últimos não são arquivos ativos: a squad só os cria quando uma capacidade,
stack, risco ou decisão arquitetural correspondente existir no seu projeto.

## Núcleo obrigatório e agnóstico

| Standard | Escopo | Ativação | Status |
| --- | --- | --- | --- |
| [Software Engineering Lifecycle](./global/software-engineering-lifecycle.md) | Sequência C.L.E.A.R. e gates | Mudança de software; fases condicionais podem ser N/A com justificativa | Active |
| [Implementation Readiness](./global/implementation-readiness-standard.md) | Gate anterior à escrita executável | Todo handoff executável; N/A para alteração sem execução | Active |
| [Software Quality](./global/software-quality-standard.md) | A1 Test, A2 Quality e A3 Security/Compliance | Mudança de software; alteração exclusivamente documental segue seu gate próprio | Active |
| [Development](./global/development-standard.md) | Práticas de implementação e manutenção | Toda escrita executável | Active |
| [Security](./global/security-standard.md) | Menor privilégio, dados e evidência A3 | Mudança de software e documentação operacional; profundidade por risco | Active |

O núcleo é agnóstico de linguagem, framework, banco, provedor, protocolo e
topologia. `security-standard` é o baseline de segurança; `security-gate` aprofunda
A3 quando o projeto tiver uma superfície de aplicação compatível.

## Exemplos condicionais para projetos adotantes

Os arquivos abaixo são exemplos, não parte dos standards ativos. Crie somente os
correspondentes à capacidade real do projeto, especializando-os com
versão, ferramentas, owners, paths e comandos locais.

| Arquivo de exemplo | Criar quando o projeto adotar |
| --- | --- |
| `project-reporting-standard.md` | Houver reporting recorrente de progresso, risco ou release. |
| `application-security-standard.md` | Houver aplicação web, backend web, auth/authz, dado sensível ou entrada não confiável. |
| `api-security-standard.md` | Houver API REST, GraphQL ou serviço HTTP exposto/consumido. |
| `spring-security-standard.md` | Houver Spring Boot/Spring Security. |
| `api-client-standard.md` | Houver criação ou consumo de clientes de API. |
| `backend-testing-standard.md` | Houver componente server-side ativo. |
| `backend-standard.md` | Houver backend ativo e regras próprias do projeto. |
| `ddd-clean-architecture-standard.md` | Um ADR adotar DDD ou Clean Architecture. |
| `java-standard.md` | Houver módulo Java. |
| `modulith-standard.md` | Houver arquitetura modular monolítica ou Spring Modulith. |
| `websocket-standard.md` | Houver comunicação bidirecional persistente. |
| `frontend-standard.md` | Houver aplicação frontend ativa. |
| `frontend-typography-standard.md` | Houver tipografia de produto a ser definida pela squad. |
| `frontend-testing-standard.md` | Houver testes de frontend, componentes ou E2E. |
| `nextjs-standard.md` | Houver módulo Next.js/React correspondente. |
| `state-management-standard.md` | Houver estado cliente não trivial. |
| `component-design-standard.md` | Houver UI reutilizável ou design system. |
| `data-grid-standard.md` | Houver grid ou tabela de dados complexa. |
| `form-validation-standard.md` | Houver formulários com entrada de usuário. |
| `a11y-standard.md` | Houver interface ativa sujeita a requisitos de acessibilidade. |
| `i18n-standard.md` | Houver produto multilíngue ou multirregional. |
| `ui-ux-standard.md` | Houver fluxo de interface criado ou alterado. |
| `webdesigner-standard.md` | Houver trabalho de design ou handoff web. |
| `rbac-frontend-standard.md` | Houver acesso diferenciado representado no frontend. |
| `keycloak-frontend-standard.md` | Houver Keycloak/OIDC/OAuth no frontend. |
| `iac-supply-chain-standard.md` | Houver IaC, containers, dependências externas ou supply chain. |

## Seleção e especialização

1. O agente coordenador classifica a mudança e aplica o baseline transversal pertinente.
2. ADRs aceitos, requirements, contratos, riscos e o manifesto determinam quais
   exemplos condicionais devem ser criados e ativados.
3. O plano registra cada standard aplicável com path e versão; N/A exige motivo.
4. O projeto completa versões, ferramentas, comandos, thresholds, owners e paths
   que o arquivo portátil deliberadamente não presume.
5. Um exemplo condicional não aplicável não deve ser criado no projeto.
6. Regra local pode elevar ou especializar o baseline, mas não o enfraquecer sem
   decisão arquitetural explícita.
7. Para A3 de aplicação, o `quality-gate` pode acionar `security-gate`; a skill
   executa standards selecionados e devolve evidência, sem criar gate autônomo.
8. Toda criação de exemplo condicional atualiza este catálogo e o README imediato;
   a ausência da capacidade não exige arquivo vazio ou alias.

Entrega Git não é um standard adicional nem uma ativação implícita deste catálogo:
quando adotada, é uma capacidade operacional sujeita à política, aos gates, ao hook
local de commit e ao enforcement local descritos pela skill `git-delivery`.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 2.6 | 2026-09-28 | Remove standards condicionais do baseline e os documenta como exemplos explícitos para novos projetos adotantes. |
| 2.5 | 2026-09-28 | Separa o núcleo agnóstico da biblioteca condicional e explicita critérios para adoção e remoção por contexto. |
| 2.4 | 2026-09-28 | Atualiza a integração dos standards especializados para o subgate `security-gate` do A3. |
| 2.3 | 2026-09-28 | Adiciona standards especializados de Application, API e Spring Security e convenção `<capacidade>-security-standard.md`. |
| 2.2 | 2026-09-13 | Explicita hook local e settings como parte da ativacao opt-in de entrega Git. |
| 2.1 | 2026-09-13 | Relaciona lifecycle, qualidade e desenvolvimento à capacidade opt-in de entrega Git. |
| 2.0 | 2026-09-11 | Incorpora a biblioteca portátil completa e separa disponibilidade, status e ativação por projeto. |

## Inventário de standards locais

- [a11y-standard.md](a11y-standard.md)
- [api-client-standard.md](api-client-standard.md)
- [backend-testing-standard.md](backend-testing-standard.md)
- [component-design-standard.md](component-design-standard.md)
- [data-grid-standard.md](data-grid-standard.md)
- [ddd-clean-architecture-standard.md](ddd-clean-architecture-standard.md)
- [development-standard.md](development-standard.md)
- [form-validation-standard.md](form-validation-standard.md)
- [frontend-standard.md](frontend-standard.md)
- [frontend-testing-standard.md](frontend-testing-standard.md)
- [i18n-standard.md](i18n-standard.md)
- [iac-supply-chain-standard.md](iac-supply-chain-standard.md)
- [implementation-readiness-standard.md](implementation-readiness-standard.md)
- [java-standard.md](java-standard.md)
- [keycloak-frontend-standard.md](keycloak-frontend-standard.md)
- [modulith-standard.md](modulith-standard.md)
- [nextjs-standard.md](nextjs-standard.md)
- [project-reporting-standard.md](project-reporting-standard.md)
- [rbac-frontend-standard.md](rbac-frontend-standard.md)
- [security-standard.md](security-standard.md)
- [software-engineering-lifecycle.md](software-engineering-lifecycle.md)
- [software-quality-standard.md](software-quality-standard.md)
- [state-management-standard.md](state-management-standard.md)
- [ui-ux-standard.md](ui-ux-standard.md)
- [webdesigner-standard.md](webdesigner-standard.md)
- [websocket-standard.md](websocket-standard.md)
