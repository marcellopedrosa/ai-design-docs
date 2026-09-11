---
name: governanca-documental
description: Valida e reconcilia a governanca documental conforme o ADR-0000. Use ao criar, mover, reclassificar ou revisar documentos, indices, templates, adaptadores ou skills; nao use para testes funcionais.
---

# Governança documental

- Owner: Arquitetura e Documentação
- Status: Active

## Objetivo

Aplicar o ADR-0000 sem duplicar sua política e produzir evidência verificável da
estrutura, dos metadados, dos links e dos índices afetados.

## Pré-condições

1. Trabalhe a partir da raiz do repositório.
2. Leia `docs/ai/README.md`, o índice imediato e somente as seções aplicáveis do
   ADR-0000.
3. Confirme o escopo e preserve mudanças e documentos alheios.

## Procedimento

1. Inventarie somente os artefatos e índices afetados.
2. Compare o estado com a taxonomia, o contrato mínimo e a matriz de ativação.
3. Aplique a correção mínima. Mudança em artefato atualiza seu índice imediato.
4. Execute o validador documental canônico configurado no projeto.
5. Se não houver automação, valide manualmente metadados, nomes, links, paridade de
   adapters/skills e inventário; registre `Automação não configurada`.
6. Corrija causas no escopo e repita. Achado fora do escopo permanece pendente com
   path, evidência e owner.

## Limites

Não alterar validadores para ocultar divergência, não acessar produção, rede,
segredos ou dados reais e não executar operação destrutiva sem autorização.

## Saída e conclusão

Entregue paths alterados, decisão aplicada, verificações, resultados, falhas, skips
e pendências. Conclua somente quando índices e artefatos concordarem e todos os
controles disponíveis tiverem resultado satisfatório.

