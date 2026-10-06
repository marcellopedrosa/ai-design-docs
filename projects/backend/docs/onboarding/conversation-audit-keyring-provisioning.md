---
document_id: "ONBOARD-CONVERSATION-AUDIT-KEYRINGS"
primary_nature: "Regra"
objective: "Orientar o agente de IA de infraestrutura no provisionamento, geração CSPRNG, estrutura JSON, permissões de filesystem e montagem de volumes dos keyrings criptográficos do Conversation Audit em HML e PRD."
scope: "Provisionamento de chaves AES-256 GCM, HMAC-SHA256 blind index e Outbound Attempt HMAC em ambientes de Homologação (HML) e Produção (PRD)."
non_objectives: "Não autorizar compartilhamento de materiais de chaves; não armazenar material em Git, logs, transcripts ou variáveis de ambiente de processos; não aplicar a desenvolvimento local."
owner: "Segurança e DevOps"
status: "Active"
date: "2026-10-02"
version: "1.1"
keywords: "onboarding, keyrings, criptografia, aes, hmac, blind-index, saas-secrets, hml, prd"
related_files: "docs/onboarding/README.md, docs/onboarding/conversation-audit-hml-prd-onboarding.md, docs/onboarding/conversation-audit-backfill-readiness.md, docs/product/requirements/REQ-00043-conversation-audit-data-governance.md"
code_references: "infra/scripts/generate-outbound-attempt-hmac-keyring.sh, backend/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/infrastructure/crypto/RemoteIdentifierKeyringFileLoader.java, backend/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/infrastructure/crypto/RemoteIdentifierProtectionAdapter.java, docker-compose.prd.yml, docker-compose.hml.yml, infra/deploy/production.env.example"
principal_statement: "Os três keyrings do Conversation Audit devem conter materiais de 32 bytes mutuamente exclusivos, formato JSON canônico, permissões restritas 0600 em diretório 0700 e montagem somente-leitura em /run/saas-secrets."
---

# Provisionamento de Keyrings e Gestão Criptográfica — Conversation Audit

**Document ID:** `ONBOARD-CONVERSATION-AUDIT-KEYRINGS`  
**Owner:** Segurança e DevOps  
**Status:** `Active`  
**Date:** 2026-10-02
**Version:** 1.1
**Ambientes Alvo:** HML e PRD  
**Documento Pai:** [Onboarding Geral de Conversation Audit em HML e PRD](conversation-audit-hml-prd-onboarding.md)

---

## 1. Responsabilidade da Feature

Esta especificação governa exclusivamente a geração, estrutura, validação de permissões e ciclo de vida dos **três keyrings criptográficos** necessários para o funcionamento seguro da proteção de dados conversacionais no backend Spring Boot em Homologação (`HML`) e Produção (`PRD`).

### 1.1 Invariantes Criptográficas Obrigatórias

O agente de infraestrutura DEVE garantir:

1. **Materiais Estritamente Distintos:** Os materiais de chave para AES (cifragem), HMAC (blind index de busca) e Outbound HMAC (ledger de envios do bot) DEVEM ser gerados independentemente por CSPRNG. O [`RemoteIdentifierProtectionAdapter`](../../backend/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/infrastructure/crypto/RemoteIdentifierProtectionAdapter.java) rejeita a inicialização se qualquer par de chaves compartilhar o mesmo material binário (`rejectSharedKeyMaterial`).
2. **Tamanho Exato:** Cada chave DEVE possuir exatamente **32 bytes** (256 bits) decodificados da representação Base64. Tamanhos diferentes causam falha imediata na carga pelo [`RemoteIdentifierKeyringFileLoader`](../../backend/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/infrastructure/crypto/RemoteIdentifierKeyringFileLoader.java).
3. **Imutabilidade e Restrição de Acesso:** Os arquivos de chaves no host DEVEM ter permissões `0600` (ou `0400`) sob um diretório `0700`. O container backend consome esses arquivos através de um volume montado como **somente-leitura (`read_only: true`)** em `/run/saas-secrets`.
4. **Zero Vazamento:** O material em Base64 NUNCA deve ser incluído em arquivos versionados no Git, parâmetros de linha de comando (`argv`), transcripts de agentes, tickets ou logs da aplicação.

---

## 2. Especificação e Formato dos Keyrings

### 2.1 Finalidade de Cada Keyring

| Arquivo de Keyring | Algoritmo | Finalidade no Domínio |
|---|---|---|
| `conversation-audit-aes-keyring.json` | AES-256 GCM | Cifra de forma reversível os identificadores remotos de usuários (telefones de WhatsApp, IDs de Telegram) no formato de envelope `enc:v1:<key-id>:<nonce>:<ciphertext>:<tag>`. |
| `conversation-audit-hmac-keyring.json` | HMAC-SHA256 | Gera hashes cegos determinísticos para viabilizar indexação e buscas exatas de conversas sem necessidade de decifrar toda a tabela. |
| `conversation-outbound-attempt-hmac-keyring.json` | HMAC-SHA256 | Gera assinaturas cegas para deduplicação idempotente e ledger de tentativas de envio outbound de mensagens pelo chatbot. |

### 2.2 Estrutura JSON Canônica

Cada arquivo DEVE conter rigorosamente um único nó raiz `"keys"`, mapeando IDs de chaves para seus valores em Base64:

```json
{
  "keys": {
    "<key-id-ativo>": "<MATERIAL_BASE64_32_BYTES>"
  }
}
```

- Limite de chaves por arquivo: máximo de 32 chaves (para suportar rotações históricas).
- Identificador da chave (`key-id`): deve atender ao padrão regex `^[A-Za-z0-9._-]{1,64}$`.

---

## 3. Procedimento Operacional de Geração pelo Agente de IA

### 3.1 Gerar somente o keyring HMAC outbound

O gerador canônico de responsabilidade única é
`infra/scripts/generate-outbound-attempt-hmac-keyring.sh`. Ele cria um arquivo
novo, recusa sobrescrita e nunca imprime o material da chave. Execute no host do
ambiente, fora de transcripts compartilhados e com o caminho correspondente:

```bash
# PRD
install -d -m 700 ./.deploy/secrets
./infra/scripts/generate-outbound-attempt-hmac-keyring.sh \
  --output ./.deploy/secrets/conversation-outbound-attempt-hmac-keyring.json \
  --active-key-id prd-outbound-v1

# HML
install -d -m 700 ./.deploy/hml/secrets
./infra/scripts/generate-outbound-attempt-hmac-keyring.sh \
  --output ./.deploy/hml/secrets/conversation-outbound-attempt-hmac-keyring.json \
  --active-key-id hml-outbound-v1
```

O arquivo é criado durante a execução explícita desse comando — não pelo backend
Spring Boot e não automaticamente ao subir o container. O bootstrap DEV pode
invocar o mesmo gerador somente quando o keyring local ainda não existe. A
instalação no volume `/run/saas-secrets` continua a cargo do lifecycle do deploy.

Antes do handoff, confirme somente metadados e estrutura; não imprima o valor:

```bash
stat -c '%a %n' ./.deploy/secrets/conversation-outbound-attempt-hmac-keyring.json
jq -e '.keys | type == "object" and length == 1' \
  ./.deploy/secrets/conversation-outbound-attempt-hmac-keyring.json >/dev/null
```

O gerador não deve ser usado sobre um arquivo existente. Rotação exige processo
separado, preservando a chave anterior enquanto houver registros que a referenciem.

### 3.2 Gerar o conjunto completo de três keyrings

O agente de infraestrutura deve executar o script a seguir no host do ambiente alvo (como usuário autorizado de implantação):

```bash
set -Eeuo pipefail
umask 077

# 1. Definir caminhos conforme o ambiente alvo
TARGET_ENV="${1:-prd}" # aceita 'prd' ou 'hml'

if [ "$TARGET_ENV" = "prd" ]; then
    SECRETS_DIR="./.deploy/secrets"
    KEY_PREFIX="prd"
elif [ "$TARGET_ENV" = "hml" ]; then
    SECRETS_DIR="./.deploy/hml/secrets"
    KEY_PREFIX="hml"
else
    echo "ERROR: Ambiente desconhecido: $TARGET_ENV" >&2
    exit 1
fi

mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"

# 2. Gerar material CSPRNG de 32 bytes para cada chave
AES_KEY_MATERIAL=$(openssl rand -base64 32)
HMAC_KEY_MATERIAL=$(openssl rand -base64 32)
OUTBOUND_KEY_MATERIAL=$(openssl rand -base64 32)

# 3. Validar que nenhum material gerado é idêntico
if [ "$AES_KEY_MATERIAL" = "$HMAC_KEY_MATERIAL" ] || \
   [ "$AES_KEY_MATERIAL" = "$OUTBOUND_KEY_MATERIAL" ] || \
   [ "$HMAC_KEY_MATERIAL" = "$OUTBOUND_KEY_MATERIAL" ]; then
    echo "ERROR: Colisão detectada entre materiais criptográficos gerados." >&2
    exit 1
fi

# 4. Gravar os três keyrings com seus IDs canônicos
AES_KEY_ID="${KEY_PREFIX}-audit-aes-v1"
cat <<EOF > "${SECRETS_DIR}/conversation-audit-aes-keyring.json"
{
  "keys": {
    "${AES_KEY_ID}": "${AES_KEY_MATERIAL}"
  }
}
EOF

HMAC_KEY_ID="${KEY_PREFIX}-audit-hmac-v1"
cat <<EOF > "${SECRETS_DIR}/conversation-audit-hmac-keyring.json"
{
  "keys": {
    "${HMAC_KEY_ID}": "${HMAC_KEY_MATERIAL}"
  }
}
EOF

OUTBOUND_KEY_ID="${KEY_PREFIX}-outbound-v1"
cat <<EOF > "${SECRETS_DIR}/conversation-outbound-attempt-hmac-keyring.json"
{
  "keys": {
    "${OUTBOUND_KEY_ID}": "${OUTBOUND_KEY_MATERIAL}"
  }
}
EOF

# 5. Aplicar permissões estritas nos arquivos
chmod 600 "${SECRETS_DIR}/conversation-audit-aes-keyring.json"
chmod 600 "${SECRETS_DIR}/conversation-audit-hmac-keyring.json"
chmod 600 "${SECRETS_DIR}/conversation-outbound-attempt-hmac-keyring.json"

# 6. Limpar variáveis de memória
unset AES_KEY_MATERIAL HMAC_KEY_MATERIAL OUTBOUND_KEY_MATERIAL

echo "Keyrings provisionados com sucesso para ${TARGET_ENV} em ${SECRETS_DIR}."
```

---

## 4. Mapeamento de Volumes e Configuração de Runtime

### 4.1 Mapeamento no Docker Compose

Os arquivos gerados no host entram no volume nomeado já usado pelo ciclo de outbound. Em HML e PRD há duas etapas idempotentes: `outbound-attempt-keyring-init` prepara o volume e `conversation-audit-keyring-init` copia os keyrings AES/HMAC para o mesmo volume. O backend só é publicado depois que ambas terminam com sucesso.

As origens obrigatórias são:

- HML: `.deploy/hml/secrets/conversation-audit-{aes,hmac}-keyring.json`;
- PRD: `.deploy/secrets/conversation-audit-{aes,hmac}-keyring.json`.

O mount efetivo permanece somente leitura no backend:

```yaml
services:
  backend:
    depends_on:
      conversation-audit-keyring-init:
        condition: service_completed_successfully
    volumes:
      - type: volume
        source: prd-outbound-attempt-keyring # ou hml-outbound-attempt-keyring
        target: /run/saas-secrets
        read_only: true
```

Não remova nem substitua o volume de outbound: a etapa de auditoria compartilha esse volume para manter o lifecycle existente e garantir rollback simples.

### 4.2 Variáveis no Arquivo de Ambiente do Host (`.env.production` / `.env.hml`)

O agente DEVE configurar as seguintes propriedades correspondentes aos keyrings gerados:

```properties
# AES Keyring
CONVERSATION_AUDIT_AES_ACTIVE_KEY_ID=prd-audit-aes-v1
CONVERSATION_AUDIT_AES_KEYRING_FILE=/run/saas-secrets/conversation-audit-aes-keyring.json

# HMAC Blind Index Keyring
CONVERSATION_AUDIT_HMAC_ACTIVE_KEY_ID=prd-audit-hmac-v1
CONVERSATION_AUDIT_HMAC_KEYRING_FILE=/run/saas-secrets/conversation-audit-hmac-keyring.json

# Outbound Attempt HMAC Keyring
CONVERSATION_OUTBOUND_ATTEMPT_HMAC_ACTIVE_KEY_ID=prd-outbound-v1
CONVERSATION_OUTBOUND_ATTEMPT_HMAC_KEYRING_FILE=/run/saas-secrets/conversation-outbound-attempt-hmac-keyring.json
```

---

## 5. Rotação e Aposentadoria de Chaves (*Key Rotation & Retirement*)

Para realizar a rotação de uma chave criptográfica sem indisponibilidade:

1. **Adição da Nova Chave:** Adicione a nova chave ao mapa `"keys"` do arquivo JSON mantendo a chave antiga presente no arquivo (para permitir a leitura de registros legados já cifrados com ela).
2. **Alteração da Chave Ativa:** Atualize a variável `*_ACTIVE_KEY_ID` correspondente no arquivo `.env` para apontar para o novo ID.
3. **Reinício do Backend:** Recrie o container backend (`--force-recreate`) para recarregar o keyring em memória. Novas escritas usarão a nova chave ativa; leituras decifrarão registros legados usando o ID registrado no cabeçalho do envelope.
4. **Aposentadoria de Chave Antiga:** A remoção definitiva de uma chave antiga do arquivo JSON só é permitida após a execução de um ciclo de re-cifragem (re-encrypt backfill) de todas as conversas e expiração do prazo de retenção de mensagens protegidas com a chave legada.

---

## 6. Critérios de Aceitação e Verificação

O provisionamento é considerado **CONCLUÍDO** quando:

- [ ] Os três arquivos JSON existem nos caminhos esperados e possuem permissões `0600` em diretório `0700`.
- [ ] O utilitário `jq .keys <arquivo>` confirma formato válido com nós textuais não vazios.
- [ ] Os três materiais Base64 decodificam para exatamente 32 bytes via `base64 -d | wc -c`.
- [ ] O startup do backend não emite erros de inicialização criptográfica ou violação de permissões.
