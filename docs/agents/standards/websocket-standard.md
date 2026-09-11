---
document_id: WEBSOCKET-STANDARD
primary_nature: Regra
objective: Definir contratos e operação segura para comunicação bidirecional persistente.
scope: Handshake, autenticação, autorização, mensagens, lifecycle, retry, ordem, backpressure, observabilidade e testes.
non_objectives: Não escolher WebSocket, biblioteca, broker, formato, protocolo de presença ou topologia de escala.
owner: Arquitetura e Engenharia de Integração
status: Active
version: 1.0
date: 2026-09-11
last_reviewed: 2026-09-11
keywords: websocket, realtime, eventos, reconnect, backpressure, contrato
related_files: README.md, api-client-standard.md, security-standard.md, backend-testing-standard.md, frontend-testing-standard.md
code_references: N/A - endpoints e infraestrutura pertencem ao projeto adotante.
principal_statement: Comunicação persistente usa contrato versionado, isolamento verificável e recuperação limitada diante de desconexão, duplicidade e pressão.
---

# WebSocket Standard

## Ativação

Condicional a ADR e contrato que escolham conexão bidirecional persistente.

## Contrato mínimo

- URL e subprotocol, handshake, autenticação, autorização e expiração de sessão;
- tipos de mensagem, envelope, schema, versão, correlação e erros;
- garantias de entrega, ordem, duplicidade, idempotência e replay;
- heartbeat, timeouts, encerramento, limites, backpressure e compatibilidade.

## Regras

- Autorizar conexão e cada subscription ou comando no servidor; canal ou tópico
  fornecido pelo cliente não estabelece acesso.
- Isolar usuário, organização ou tenant quando aplicável e impedir broadcast além
  do escopo autorizado.
- Reconexão usa backoff exponencial, jitter, limite e cancelamento; não cria storm
  nem repete mutação sem idempotência.
- Definir ressincronização após gap, mensagem fora de ordem ou sessão retomada.
- Limitar tamanho, frequência, filas e memória; overload possui política explícita
  e observável.
- Não incluir token em URL ou log quando puder vazar em histórico e telemetria.
- Mudança de schema segue versionamento e janela de compatibilidade.

## Evidência

Testar handshake aceito/negado, isolamento, expiração, reconnect, duplicidade,
ordem, gap, backpressure, shutdown e cliente de versão anterior aplicável.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.0 | 2026-09-11 | Cria standard portátil de comunicação WebSocket. |
