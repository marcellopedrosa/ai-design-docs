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

## Gatilhos e não-gatilhos

- Gatilhos: criar, mover, renomear, reclassificar ou revisar documentos, índices,
  templates, adapters e skills.
- Não-gatilhos: testes funcionais ou alterações executáveis sem impacto documental.

## Escopo e não-objetivos

- Escopo: artefatos documentais e seus índices imediatos.
- Não-objetivos: redefinir requisitos, decisões aceitas ou contratos do ADR-0000.

## Entradas

- Paths alterados, índice imediato, fontes canônicas relacionadas e validador
  documental disponível.

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

## Limites de segurança

Não acesse produção, segredos, credenciais ou rede. Preserve mudanças fora do
escopo e não enfraqueça um controle para obter resultado verde.

## Saídas e evidências

- Saída: documentos reconciliados e índices atualizados.
- Evidência: paths, links, metadados, comando executado e resultado ou limitação.

## Saída e critério de conclusão

Entregue paths alterados, decisão aplicada, verificações, resultados, falhas, skips
e pendências. Conclua somente quando índices e artefatos concordarem e todos os
controles disponíveis tiverem resultado satisfatório.

## Automação disponível

Execute `node docs/scripts/validate-documentation-governance.mjs --root .` como
diagnóstico. Enquanto `docs/scripts/README.md` indicar estado `Partial`, registre
`Automação não configurada` para o gate canônico e complemente com validação manual.

