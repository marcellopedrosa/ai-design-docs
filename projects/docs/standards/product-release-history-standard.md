---
document_id: PRODUCT-RELEASE-HISTORY-STANDARD
primary_nature: Standard
objective: Manter um histórico verificável das mudanças do produto por versão.
scope: Mudanças em apps do produto, decisões de versão, checklist de release e versão exibida no frontend.
non_objectives: Substituir os artefatos do Spec Kit ou reconstruir releases passadas sem evidência.
owner: Produto e Engenharia
status: Active
version: 1.0
date: 2026-10-18
last_reviewed: 2026-10-18
keywords: release, versão, changelog, checklist, semver
related_files: ../README.md, ../../../corporate-presets/standards/static-product-changelog-standard.md
principal_statement: Toda mudança do produto entra no checklist da próxima release; o número só muda após decisão humana explícita.
---

# Histórico de mudanças por release

Este standard especializa o contrato corporativo definido em
[`static-product-changelog-standard.md`](../../../corporate-presets/standards/static-product-changelog-standard.md)
para os produtos documentados neste repositório.

## Fonte e escopo

- A coleção de releases do produto deve manter um `CHANGELOG.md` como fonte
  canônica das mudanças, quando o produto possuir uma superfície de changelog.
  A seção `Não lançadas` recebe cada mudança até a decisão de versão.
- A página de changelog deve consumir um snapshot estático versionado, como
  `src/generated/changelog.json`. O produto não deve ler o Markdown em runtime,
  regenerar o snapshot durante `build` ou `analyze`, nem editar o JSON gerado
  manualmente.
- Os caminhos concretos do changelog, do snapshot, do gerador, dos
  verificadores e dos testes devem ser registrados na documentação do domínio
  que materializa este standard.
- Cada release deve registrar a data no formato `dd/mm/aaaa`, por exemplo
  `Data: 18/10/2026`. Datas desconhecidas devem usar `Data: não registrada`.
- Quando uma entrada envolver infraestrutura, migrations ou scripts, acrescente
  um bloco `Arquivos relacionados:` com um item por arquivo técnico. Não liste
  arquivos de aplicação (`.java`, `.ts`, `.tsx`, `.js`, `.css`, `.html`); a
  validação e o snapshot devem preservar apenas o subconjunto de infraestrutura
  definido pelo standard corporativo.

## Fluxo em cada mudança

1. Registre no checklist `Não lançadas` uma linha por mudança observável ou
   correção, com tipo (`Adicionado`, `Alterado`, `Corrigido`, `Segurança` ou
   `Operação`), resumo concreto e referência ao requisito, plano ou PR quando
   existir. Não inclua segredo ou dado pessoal. Marque `[x]` somente quando a
   mudança estiver implementada e validada; mantenha `[ ]` enquanto pendente.
2. Ao concluir o trabalho, apresente ao responsável o resumo e pergunte:
   **"Esta mudança deve manter a versão atual ou incrementar patch, minor ou
   major?"**. Sem resposta, mantenha `Decisão humana: pendente`; não altere o
   número da versão.
3. Se a resposta for `manter`, registre o motivo e a versão alvo. `manter` só é
   válido enquanto a versão ainda não foi publicada ou para mudança que não
   altera o artefato publicado. Uma release publicada é imutável.
4. Se for `patch`, `minor` ou `major`, calcule a próxima versão a partir da
   fonte de versão do produto, crie a seção correspondente e atualize os
   artefatos de versão relacionados juntos. Registre a decisão no formato
   `Decisão humana: aprovada por NOME em AAAA-MM-DD; incremento:
   patch|minor|major; referência: conversa ou ticket`. Use patch para correção
   compatível, minor para recurso compatível e major para quebra de contrato.
5. Antes de publicar, confira o checklist, a data, a decisão e a evidência de
   validação. Marque a release como publicada apenas após deploy confirmado;
   falha de deploy mantém o estado em preparação.

## Verificação

Cada produto deve documentar o comando que verifica versão, lockfile, checklist
e sincronização do snapshot. A automação deve exigir atualização do changelog
quando o diff contiver código de produto e exigir decisão humana identificada
quando o número da versão mudar. A automação é complementar ao processo e não
substitui a decisão explícita do responsável.
