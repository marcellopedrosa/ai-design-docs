---
document_id: IAC-SUPPLY-CHAIN-STANDARD
primary_nature: Regra
objective: Definir controles portáteis para proveniência, integridade e reprodutibilidade de IaC e dependências.
scope: Fontes, pinning, locks, checksums, assinaturas, imagens, SBOM, CVEs, licenças, rede e evidência.
non_objectives: Não escolher registry, scanner, IaC tool, sistema operacional ou política de release.
owner: Plataforma, Segurança e Engenharia
status: Active
version: 1.0
date: 2026-09-11
last_reviewed: 2026-09-11
keywords: iac, supply-chain, sbom, proveniencia, pinning, integridade
related_files: README.md, security-standard.md, development-standard.md, software-quality-standard.md
code_references: N/A - registries e comandos pertencem ao projeto adotante.
principal_statement: Todo artefato externo usado por build ou operação possui origem permitida, versão imutável, integridade verificável e caminho reprodutível.
---

# IaC and Supply Chain Standard

## Ativação

Condicional à presença de IaC, containers, package managers, downloads de build ou
artefatos de terceiros.

## Regras

- Manter allowlist de fontes e preferir registries, mirrors ou repositórios sob
  governança do projeto.
- Fixar dependências por versão imutável, digest ou lockfile apropriado; tag mutável
  não demonstra reprodutibilidade.
- Verificar checksum e assinatura quando disponíveis, antes de executar ou extrair.
- Builds não executam download implícito fora do contrato de rede autorizado.
- Imagens usam base mínima, usuário não privilegiado, digest e provenance
  verificável; segredo não entra em layer, argumento ou log.
- Gerar e reter inventário ou SBOM quando aplicável; avaliar licença,
  vulnerabilidade e origem com política de severidade e expiração definida.
- Atualização automatizada continua sujeita a testes e gates; merge de bot não é
  aprovação de risco.
- Preservar modo de reconstrução ou mirror para dependências críticas conforme a
  necessidade de continuidade.

## Evidência

Registrar fonte, versão/digest, integridade, licença, achados, exceções, comandos e
artefato construído. Fonte não verificável ou dependência obrigatória inacessível é
BLOCKED; não desabilitar validação para obter PASS.

## Change log

| Versão | Data | Mudança |
| --- | --- | --- |
| 1.0 | 2026-09-11 | Extrai controles de supply chain sem infraestrutura de origem. |
