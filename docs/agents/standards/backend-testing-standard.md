---
document_id: BACKEND-TESTING-STANDARD
primary_nature: Regra
objective: Definir estratégia portátil de testes para serviços e componentes server-side.
scope: Testes unitários, integração, contrato, persistência, concorrência e regressão de backend.
non_objectives: Não escolher framework, banco, container, cobertura ou comando do projeto adotante.
owner: Engenharia de Backend e Qualidade
status: Active
version: 1.0
date: 2026-09-11
last_reviewed: 2026-09-11
keywords: backend, testes, integracao, contrato, persistencia
related_files: README.md, development-standard.md, software-quality-standard.md, api-client-standard.md
code_references: N/A - stack e comandos devem constar no manifesto.
principal_statement: O backend comprova regras isoladas e integrações reais no menor nível capaz de revelar o risco alterado.
---

# Backend Testing Standard

## Ativação

Condicional à presença de serviço, job, API ou processamento server-side.

## Estratégia

- Unidade: invariantes, decisões, cálculos e falhas sem infraestrutura real.
- Integração: adapters, persistência, transações, migrations e configuração com
  dependências compatíveis e isoladas.
- Contrato: interface pública, serialização, autorização, compatibilidade e erros.
- Sistema/E2E: jornadas críticas apenas quando a integração entre boundaries for o
  risco que precisa ser demonstrado.

## Regras

- Testes são determinísticos, herméticos, independentes de ordem e executáveis em
  ambiente limpo.
- Fixtures são mínimas, legíveis e não usam dados reais; relógio, aleatoriedade e
  concorrência são controlados.
- Mocks ficam em boundaries. Não simular a unidade sob teste nem reproduzir sua
  implementação nas expectativas.
- Persistência testa constraints, rollback, concorrência e evolução de schema
  aplicáveis, não apenas mocks de repositório.
- Autorização e isolamento incluem casos permitidos e negados.
- Teste ignorado, flaky ou desabilitado exige causa, owner e prazo rastreáveis.

## Evidência

Registrar teste focal, suíte impactada, ambiente, dependências, contagens, falhas,
skips e cobertura configurada. O projeto define limiares por pacote e risco.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.0 | 2026-09-11 | Cria estratégia portátil de testes de backend. |
