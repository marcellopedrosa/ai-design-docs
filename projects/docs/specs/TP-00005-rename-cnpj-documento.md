---
document_id: "TP-00005"
primary_nature: "Plano"
objective: "Refatorar a base de código e o banco de dados para suportar clientes tanto como Pessoa Física (CPF) quanto Pessoa Jurídica (CNPJ), unificando ambos sob o conceito de Documento. O sistema de integração fiscal via API do SERPRO continua exigindo a estrutura original dos payloads (numero), mas passa a utilizar um campo tipo correspondente a 1 (CPF) ou 2 (CNPJ)."
scope: "Coordenacao de Migração de CNPJ para Documento (CPF/CNPJ) nos componentes, fases, dependencias e verificacoes explicitamente descritos no plano."
non_objectives: "N/A - o documento original nao explicita nao-objetivos adicionais."
owner: "Engenharia"
status: Draft
date: "2026-08-26"
version: "1.0"
keywords: "plano, coordenacao, rename, cnpj, documento"
related_files: "docs/delivery/plans/README.md"
code_references: "Documento, backend/src/main/resources/db/migration/client/V5__rename_cnpj_and_add_tipo.sql, historical: Cnpj foi substituído por Documento, backend/src/main/java/br/com/duoset/saas_service/shared/types/Documento.java, ConversationEntity, DarfEntity, ChatbotSession, ClientCompany, Darf, Integer, ConsultaFiscal.create, Documento.tipo("
principal_statement: "Migra o conceito restrito de CNPJ para documento alfanumérico."
---

# TP-00005 — Task Plan: Migração de CNPJ para Documento (CPF/CNPJ)

**Document ID:** `TP-00005`  

## Objetivo
Refatorar a base de código e o banco de dados para suportar clientes tanto como Pessoa Física (CPF) quanto Pessoa Jurídica (CNPJ), unificando ambos sob o conceito de `Documento`. O sistema de integração fiscal via API do SERPRO continua exigindo a estrutura original dos payloads (`numero`), mas passa a utilizar um campo `tipo` correspondente a 1 (CPF) ou 2 (CNPJ).

## Mudanças Realizadas

### 1. Banco de Dados e Migrations
- **WhatsApp**: Adição das colunas `tipo_documento` nas tabelas pertinentes e substituição de referências estritas a `selected_cnpj` por `selected_documento`.
- **Client**: Adaptação da estrutura para suportar a coluna `documento` genérica em vez de restrita a 14 caracteres, adicionando a respectiva constraint de tipo.
- **Fiscal**: Migration `V5__rename_cnpj_and_add_tipo.sql` executada para atualizar as colunas na tabela de Histórico Fiscal (DARF).

### 2. Backend (Domínio e Persistência)
- Refatoração do Value Object `Cnpj` para `Documento` (`contexts/client/internal/domain/model/Documento.java`). Este objeto de valor possui a inteligência de derivar seu próprio tipo com base no tamanho (11 = CPF = Tipo 1; 14 = CNPJ = Tipo 2).
- Adaptação das entidades JPA (`ConversationEntity`, `DarfEntity`) e Aggregates (`ChatbotSession`, `ClientCompany`, `Darf`) para que carreguem o `tipoDocumento` mapeado como `Integer`.
- Manutenção de sobrecargas (*overloads*) de compatibilidade em fábricas (ex: `ConsultaFiscal.create`) para evitar quebra em casos de uso e adapters que não instanciam o tipo explicitamente.

### 3. Integração Fiscal (SERPRO)
- REQ-00008, REQ-00009, REQ-00010: Os JSONs de envio para o SERPRO `/Consultar` e afins mantêm o nome de campo `numero` recebendo os dígitos (somente números), em conformidade estrita aos requisitos originais.
- Inclusão do campo `tipo` nas chamadas ao SERPRO, alimentado pelo tipo selecionado na interface ou deduzido via regra do Value Object (`Documento.tipo()`).

### 4. Frontend e UI
- Renomeação do componente utilitário `CnpjInput` para `DocumentoInput`.
- Adição de dropdown seletivo de `Tipo de Documento` (`Select`) contendo "CPF (1)" e "CNPJ (2)" nos modais de Inclusão (`AddClientModal.tsx`) e Edição (`EditClientModal.tsx`). O formulário agora obriga a seleção deste tipo.
- Refatoração de esquemas Zod em `clientSchemas.ts` para suportar validação de Mod-11 de CPF e CNPJ (substituindo a antiga checagem que englobava exclusivamente os 14 dígitos).
- Refatoração do validador customizado `documento.ts` (substituindo o original `cnpj.ts`) para lidar com ambas as regras de formatação (XXX.XXX.XXX-XX e XX.XXX.XXX/XXXX-XX).
- Passagem do parâmetro numérico `tipoDocumento` nas mutações `useCreateClient` e `useUpdateClient` no arquivo `useClientQueries.ts`.

## Conclusão
A arquitetura foi estabilizada. O sistema está perfeitamente aderente ao requisito de permitir dualidade de documentos mantendo a coesão do domínio (Aggregate Roots), enquanto orquestra sem rupturas a persistência SQL via mapeamento JPA.
