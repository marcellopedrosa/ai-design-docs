---
document_id: "ADR-0014"
primary_nature: "Decisao"
objective: "Registrar a decisão arquitetural “Transição para Documento Alfanumérico”, seus motivadores, alternativas e consequências."
scope: "Decisão, componentes, integrações e limites explicitamente descritos em “Transição para Documento Alfanumérico”."
non_objectives: "Não implementar a decisão, substituir requisitos relacionados nem atestar capabilities ou ambientes sem evidência explícita."
owner: "AgentOrchestrator"
status: "Proposed"
date: "2026-04-27"
version: "1.0"
keywords: "adr, decisao, arquitetura, transição, para, documento, alfanumérico"
related_files: "README.md, ADR-0023-agnostic-payment-provider-integration.md"
code_references: "frontend/src/lib/validators/documento.ts, frontend/src/components/shared/DocumentoInput.tsx, app/src/main/java/br/com/duoset/saas_service/shared/types/Documento.java"
principal_statement: "A opção escolhida é a implementação proativa do Documento Alfanumérico em todas as camadas, com armazenamento textual sem máscara, validação própria e atualização de máscaras e regex conforme a especificação descrita."
---

# ADR-0014 - Transição para Documento Alfanumérico

- Date: 2026-04-27
- Status: Proposed
- Version: 1.0
- Authors / Owners: AgentOrchestrator
- Reviewers: Engineering Team
- Stakeholders: Business, Compliance, Frontend, Backend
- Supersedes: None

---

# 1. Context

A Receita Federal do Brasil (RFB) anunciou a transição para um novo formato de Cadastro Nacional da Pessoa Jurídica (Documento) que passará a ser **Alfanumérico**. Essa mudança ocorre porque a disponibilidade de números puramente decimais no formato atual (apenas números) está próxima do esgotamento.

O novo padrão mantém o mesmo tamanho (14 caracteres) e a mesma estrutura de pontuação visual, mas altera a composição de "Raiz" e "Ordem":
- **Documento Número (Antigo)**: `NN.NNN.NNN / NNNN - NN` (onde N é estritamente numérico)
- **Documento Alfanumérico (Novo)**: `SS.SSS.SSS / SSSS - NN` (onde S pode ser Letra Maiúscula ou Número, e N continua estritamente numérico)

Isso impacta diretamente todo o ecossistema do Contador Fiscal Inteligente, incluindo:
- **Frontend**: Máscaras de input (`CnpjInput`), expressões regulares de validação no Zod (`Documento_MASK_REGEX`), e o algoritmo de cálculo de Dígito Verificador (DV).
- **Backend**: Entidades de domínio, contratos de API (DTOs), validações de Beans (ex: `@Documento` do Hibernate Validator que pode ficar defasada), e consultas no banco de dados.
- **Integrações**: Comunicação com sistemas de terceiros (provider de pagamento definido no [ADR-0023](ADR-0023-agnostic-payment-provider-integration.md), APIs do Governo e ERPs) que precisam estar preparados para receber letras no Documento.

---

# 2. Decision Statement

O sistema deve ser refatorado em todas as suas camadas para suportar nativamente o **Documento Alfanumérico**.
As seguintes diretrizes devem ser adotadas imediatamente:
1. **Tipagem de Dados**: O Documento deve ser tratado estritamente como `String` (ou `VARCHAR`) em todas as camadas (Banco de dados, Backend, Frontend). Jamais deve ser convertido para inteiros (`Long` ou `BigInt`).
2. **Máscaras e Regex**: Atualizar expressões regulares para permitir caracteres alfanuméricos (`[A-Z0-9]`) nas primeiras 12 posições, restando apenas números nas 2 últimas posições (DV).
3. **Validação e Dígito Verificador**: Atualizar o algoritmo de cálculo do dígito verificador (Módulo 11) para converter as letras alfabéticas em seus respectivos valores numéricos (tabela ASCII subtraída de 48) conforme a especificação técnica oficial da Receita Federal.
4. **Armazenamento**: O Documento deve continuar sendo armazenado sem máscara (apenas os 14 caracteres alfanuméricos) no banco de dados.

---

# 3. Decision Drivers

- **Compliance Regulatória**: Obrigatoriedade de seguir o novo padrão da Receita Federal para não bloquear o cadastro ou consulta de novas empresas.
- **Interoperabilidade**: Garantir que as consultas fiscais (Módulo Fiscal) e emissões de DARF continuem funcionando para novos Documentos.
- **Integridade de Dados**: Evitar falhas de conversão ou validação silenciosas em rotinas de integração e faturamento.
- **Experiência do Usuário**: O `CnpjInput` no frontend deve permitir a digitação de letras de forma natural, convertendo-as automaticamente para maiúsculas (UpperCase).

---

# 4. Considered Options

### Option 1: Tratamento Reativo (Aguardar bibliotecas de terceiros)
Description: Esperar que bibliotecas padrão como `hibernate-validator` ou pacotes NPM de validação de Documento sejam atualizados e apenas atualizar as dependências.

Pros:
- Menor esforço de codificação interna.
- Delegação da responsabilidade do algoritmo para mantenedores open-source.

Cons:
- Risco de bloqueio do negócio se as bibliotecas não forem atualizadas a tempo da implementação oficial da RFB.
- Não resolve o problema das máscaras de UI (`CnpjInput`) e validações Regex (`Documento_MASK_REGEX`) hardcoded no nosso sistema.

### Option 2: Implementação Proativa via Domain Value Object e Custom Validators
Description: Implementar e atualizar as lógicas de validação de Documento (`isValidCnpj` no frontend e anotação customizada no backend) para suportar o cálculo alfanumérico internamente.

Pros:
- Controle total sobre o algoritmo e garantia de compliance imediato.
- Protege o domínio da aplicação independentemente da atualização de bibliotecas de terceiros.
- Permite adaptar as máscaras do Frontend instantaneamente.

Cons:
- Requer esforço de engenharia para implementar e testar exaustivamente o novo algoritmo Mod-11 com conversão ASCII.

---

# 5. Decision Outcome

**A opção escolhida foi a Option 2 (Implementação Proativa)**. 
A criticidade do Documento como chave primária de identificação de Tenants e Empresas Clientes no SaaS não permite depender do cronograma de atualização de dependências externas. O sistema deve ser autossuficiente na validação e formatação da nova regra da Receita Federal.

As alterações ocorrerão nos seguintes escopos:
- `src/lib/validators/documento.ts` (Frontend): Atualização do algoritmo de cálculo.
- `src/lib/patterns.ts` (Frontend): Atualização da Regex de `^\d{2}...` para aceitar `[A-Z0-9]`.
- `CnpjInput.tsx` (Frontend): Permitir caracteres alfanuméricos e forçar caixa alta (`toUpperCase()`).
- Backend: Criação/Atualização de anotação de validação customizada para os DTOs.

---

# 6. Consequences

**Positive Consequences:**
- Sistema 100% aderente às novas normas da Receita Federal.
- Ausência de disrupção de serviço para clientes que abrirem novas empresas com o novo padrão.
- Padronização no tratamento do dado, forçando a limpeza de legados onde o Documento poderia estar sendo tratado como numérico.

**Negative Consequences:**
- Esforço imediato de refatoração ("technical debt" forçado por mudança externa).
- Necessidade de atualizar e expandir a suíte de testes (Testes Unitários e E2E Playwright) para validar casos de Documentos puramente numéricos (legado) e Documentos alfanuméricos (novos), garantindo a retrocompatibilidade.
- Risco de falhas em integrações com sistemas legados de terceiros (ex: prefeituras ou ERPs antigos) que ainda não suportem o formato alfanumérico nas requisições da nossa API.
