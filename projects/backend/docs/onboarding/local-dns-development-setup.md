---
document_id: "ONBOARD-LOCAL-DNS"
primary_nature: "Regra"
objective: "Configurar o DNS e o navegador locais para executar o ambiente de desenvolvimento por subdomínios."
scope: "Entradas de hosts, Web Crypto no Chrome e inicialização local via Docker Compose e proxy reverso."
non_objectives: "Nao configurar DNS público, produção, certificados públicos ou destruir volumes persistentes."
owner: "DevOps e Engenharia"
status: "Active"
date: "2026-08-25"
version: "1.1"
keywords: "onboarding, dns-local, hosts, chrome, keycloak, docker-compose"
related_files: "docs/onboarding/README.md, docs/onboarding/local-development-host-bootstrap.md, docs/onboarding/keycloak-provisioning-identity.md"
code_references: "docker-compose.yml, start-dev-dns-bot.sh"
principal_statement: "O ambiente local usa subdomínios agentefiscal.local resolvidos para 127.0.0.1 e tratados como origem segura somente no navegador de desenvolvimento."
last_reviewed: "2026-08-25"
---

# Configuração do ambiente de desenvolvimento com DNS local

Este guia orienta a subida do ambiente local com uma topologia próxima à de
produção. Em vez de `localhost`, um proxy reverso Nginx distribui chamadas entre
subdomínios virtuais.

## 1. Serviços e endereços

O Docker Compose inicia:

- **Frontend (Next.js):** `app.agentefiscal.local`;
- **Backend (Spring Boot):** `api.agentefiscal.local`;
- **Auth (Keycloak):** `auth.agentefiscal.local`;
- **Banco de dados (Postgres):** bancos separados para aplicação e Keycloak;
- **Redis:** cache e mensageria;
- **Nginx local:** proxy na porta 80 para os containers.

## 2. Configurações de rede obrigatórias

Os domínios `.local` não existem na internet pública. O sistema operacional deve
resolvê-los para a máquina local para evitar erros como
`DNS_PROBE_FINISHED_NXDOMAIN`.

### 2.1 Mapear os endereços no arquivo hosts

No Linux ou macOS, abra o terminal e execute, após revisar os endereços:

```bash
sudo sh -c 'echo "127.0.0.1 app.agentefiscal.local api.agentefiscal.local auth.agentefiscal.local" >> /etc/hosts'
```

O comando altera uma configuração global do sistema operacional e pode exigir
senha administrativa. Remova a entrada manualmente quando ela não for mais
necessária.

No Windows:

1. abra o Bloco de Notas como Administrador;
2. abra `C:\Windows\System32\drivers\etc\hosts`, selecionando a visualização de
   todos os arquivos;
3. adicione a linha abaixo e salve:

```text
127.0.0.1 app.agentefiscal.local api.agentefiscal.local auth.agentefiscal.local
```

### 2.2 Habilitar Web Crypto no Chrome para os domínios locais

O login usa PKCE por meio de `keycloak-js`. O Chrome bloqueia a Web Crypto API em
origens HTTP que não sejam `localhost`. Esta exceção é exclusiva do ambiente local:

1. abra `chrome://flags/#unsafely-treat-insecure-origin-as-secure`;
2. em **Insecure origins treated as secure**, informe:
   `http://app.agentefiscal.local,http://auth.agentefiscal.local,http://api.agentefiscal.local`;
3. altere o estado para **Enabled**;
4. selecione **Relaunch** para reiniciar o navegador.

Sem essa configuração, o redirecionamento de login do Keycloak pode ser abortado
com erro de criptografia no console. A exceção não deve ser aplicada a ambientes
compartilhados ou de produção.

## 3. Iniciar o ambiente

Antes do primeiro Compose, conclua o
[bootstrap do host local](local-development-host-bootstrap.md). Na preparação
inicial, prefira a invocação única com `--continue start-dev-dns-bot`; ela associa
e valida a identidade operacional e já continua este entrypoint em sessão nova.

Depois de o bootstrap estar concluído e uma sessão renovada estar ativa, execute
na raiz do repositório:

```bash
./start-dev-dns-bot.sh
```

Ao concluir, os pontos de acesso são:

- frontend: `http://app.agentefiscal.local`;
- backend: `http://api.agentefiscal.local`;
- administração do Keycloak: `http://auth.agentefiscal.local`.

`docker compose down -v` destrói realms, usuários e bancos locais. Para corrigir a
identidade técnica de provisionamento em volume existente, preserve os dados e
siga [Identidade de provisionamento do Keycloak](keycloak-provisioning-identity.md).
Limpeza de volume só é aceitável em ambiente comprovadamente descartável.

## 4. Change Log

| Version | Date | Owner | Change |
| --- | --- | --- | --- |
| 1.1 | 2026-08-25 | DevOps e Segurança | Torna o bootstrap canônico do host pré-requisito do primeiro Compose e remove a expectativa de correção tardia por sudo. |
| 1.0 | 2026-08-21 | DevOps e Engenharia | Guia inicial de DNS e origem segura local. |
