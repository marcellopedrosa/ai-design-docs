---
document_id: "ADR-0017"
primary_nature: "Decisao"
objective: "Registrar a adoção do Spring AI `ChatClient` como fronteira de integração com provedores de LLM."
scope: "Integrações LLM do backend e seus adapters de provider."
non_objectives: "Não definir prompts de negócio, quotas, experiência conversacional ou escolha permanente de fornecedor."
owner: "Arquitetura Backend"
status: "Proposed"
date: "2026-07-16"
version: "0.1"
keywords: "Spring AI, ChatClient, LLM, abstração, provider"
related_files: "README.md, ADR-0007-multi-provider-llm-integration.md, ADR-0021-llm-resilience-fallback-strategy.md"
code_references: "`backend/` - adapters e configuração de integração LLM."
principal_statement: "Integrações LLM devem depender da abstração `ChatClient`/Spring AI e manter detalhes do fornecedor nos adapters."
---

# ADR-0017 - Uso do Spring AI e ChatClient como abstração para LLMs

- Document ID: `ADR-0017`
- Primary Nature: `Decisao`
- Objective: Registrar a adoção do Spring AI `ChatClient` como fronteira de integração com provedores de LLM.
- Scope: Integrações LLM do backend e seus adapters de provider.
- Non-objectives: Não definir prompts de negócio, quotas, experiência conversacional ou escolha permanente de fornecedor.
- Keywords: Spring AI, ChatClient, LLM, abstração, provider
- Related Files: `ADR-0007-multi-provider-llm-integration.md`, `ADR-0021-llm-resilience-fallback-strategy.md`
- Code References: `backend/` - adapters e configuração de integração LLM.
- Principal Decision: Integrações LLM devem depender da abstração `ChatClient`/Spring AI e manter detalhes do fornecedor nos adapters.
- Date: 2026-07-16
- Status: Proposed
- Version: 0.1
- Authors / Owners: Arquitetura Backend
- Reviewers: Responsáveis técnicos do backend
- Stakeholders: Backend, Arquitetura, Segurança e Operações
- Supersedes: N/A
- Superseded by: N/A

---

# 1. Context

O índice histórico registrava este ADR como aceito, mas o artefato correspondente
não estava presente no repositório. O código e outros documentos fazem referência
ao uso de Spring AI e `ChatClient`; sem o registro original não é possível
reconstituir com segurança todas as alternativas, consequências e evidências do
aceite anterior.

# 2. Decision

Propõe-se que casos de uso e domínio dependam de portas próprias e que adapters de
infraestrutura utilizem Spring AI `ChatClient` como abstração de integração. APIs
específicas de fornecedores não devem atravessar a fronteira do adapter.

# 3. Alternatives

- SDK direto de cada fornecedor: aumenta acoplamento e custo de troca.
- Cliente HTTP próprio: amplia controle, mas duplica suporte já oferecido pelo framework.
- Abstração interna sem Spring AI: preserva portabilidade, com maior manutenção local.

# 4. Consequences

- Configuração e observabilidade permanecem nos adapters.
- Troca de provider não altera domínio ou casos de uso.
- Recursos não portáveis exigem extensão explícita e teste de compatibilidade.

# 5. Validation

Antes de promover para `Accepted`, os owners devem confrontar esta reconstrução com
o código vigente, recuperar a revisão histórica quando disponível e validar testes
de troca/fallback de provider.

# 6. Lifecycle note

Este documento é uma reconstrução conservadora criada para restaurar rastreabilidade.
O índice foi corrigido para `Proposed`; ele não reivindica o aceite cuja evidência
original estava ausente.

