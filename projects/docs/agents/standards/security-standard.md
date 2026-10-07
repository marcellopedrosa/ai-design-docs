---
document_id: "PROJECT-SECURITY-STANDARD"
primary_nature: "Regra"
objective: "Definir regras reutilizáveis e verificáveis para Security."
scope: "Controles de segurança, proteção de dados, segredos e desenvolvimento seguro."
non_objectives: "Não criar requisitos de produto, decisões arquiteturais concretas ou procedimentos fora do escopo deste standard."
owner: "Arquitetura e Qualidade"
status: "Active"
date: "2026-08-25"
version: "1.4"
keywords: "security, standard, standard"
related_files: "./README.md"
code_references: "backend/, frontend/"
principal_statement: "As regras de Security aplicam-se somente ao escopo e aos controles declarados neste standard."
---

# Security Standards

> **Mandatory rules** for security implementation across the SaaS Service ecosystem. This standard governs encryption, data transit, and PII handling.

## 1. Criptografia em Trânsito (External Links)

Para prevenir vazamento (leak) de identificadores sensíveis ou vetores de ataque em URLs expostas em provedores de e-mail ou SMS, a seguinte regra é inegociável:

> [!IMPORTANT]
> **Todo link externo gerado pela plataforma que contenha informações sensíveis (como tokens de ação, identificadores internos de usuários ou parâmetros PII) deve ter seu payload criptografado.**

### Diretrizes de Implementação

1. **Criptografia Bidirecional:** A criptografia deve utilizar um algoritmo simétrico bidirecional (ex: AES), sendo que o componente central de utilitários de segurança (`CryptoUtils`) deve ser o responsável tanto pela criptografia na saída quanto pela decriptografia no retorno.
2. **URL Encoding Seguro:** A saída do algoritmo de criptografia (geralmente Base64) deve obrigatoriamente ser protegida com URL Encoding (ex: `URLEncoder.encode()`) antes de compor a string de query parameters (ex: `?token=`). Isso evita que caracteres especiais como `+`, `/` e `=` sejam truncados pelos clientes de e-mail ou navegadores.
3. **Decriptografia Restrita ao Backend:** O frontend atua apenas como um "pass-through". Ele extrai o parâmetro criptografado da URL (via `useSearchParams`) e envia de volta ao backend de forma opaca. Somente o backend da aplicação, que detém a chave mestra, tem a responsabilidade de decriptografar os dados antes de prosseguir com a lógica de negócio.

---

## 2. Criptografia em Repouso (Data at Rest)

1. **Credenciais de Integração:** Senhas, Chaves de API e Tokens de plataformas terceiras (ex: SMTP, WABA, Telegram) nunca podem ser armazenados em texto puro no banco de dados. Devem utilizar os conversores JPA apropriados com AES-256 GCM.
2. **Certificados Digitais:** Todo binário sensível (como `.pfx` e `.p12`) e suas senhas correspondentes devem permanecer criptografados at-rest. O arquivo desencriptado só deve existir na memória RAM (em tempo de execução) durante o estritamente necessário para transações.

---

## 3. Prevenção de Injeção e Rate Limiting

- (Aguardando definições detalhadas de Web Application Firewall e Rate Limit nos endpoints sensíveis).
