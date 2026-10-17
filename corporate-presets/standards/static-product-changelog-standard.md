---
document_id: CORPORATE-STATIC-PRODUCT-CHANGELOG-STANDARD
primary_nature: Standard
objective: Definir uma política corporativa única para históricos de mudanças de produto estáticos, autenticados e verificáveis.
scope: Changelog de produto, snapshot de frontend, autorização, atualização documental e validação.
non_objectives: Substituir especificações do produto, definir layout visual além do contrato mínimo ou criar uma release automaticamente.
owner: Produto e Engenharia
status: Active
version: 1.0
date: 2026-10-17
last_reviewed: 2026-10-17
keywords: changelog, release, snapshot, stateless, SUPER_ADMIN
related_files: README.md
principal_statement: O changelog publicado na aplicação deve ser um snapshot estático, atualizado explicitamente após cada mudança validada e protegido por autorização do produto.
---

# Standard corporativo de changelog estático

## Contrato obrigatório

Todo produto que expõe um changelog na aplicação deve cumprir estas regras:

- A fonte canônica das mudanças é um `CHANGELOG.md` armazenado na coleção
  documental de releases do produto, normalmente em
  `<projeto>/docs/releases/CHANGELOG.md`.
- A página de changelog deve consumir um artefato derivado versionado, como
  `src/generated/changelog.json`. Ela não pode ler o Markdown em runtime, fazer
  chamadas para obter o histórico ou manter estado próprio para compor a tela.
- O artefato derivado deve ser atualizado explicitamente no mesmo diff da
  mudança validada. A geração não deve ocorrer automaticamente em `build`,
  `analyze`, inicialização da aplicação ou outro hook de execução.
- O JSON gerado não deve ser editado manualmente. O gerador deve filtrar o
  conteúdo autorizado para exibição e o verificador deve detectar snapshot
  desatualizado.

## Autorização

- A rota de changelog deve ser protegida pelo guard de autorização da aplicação.
- Neste harness, o acesso é exclusivo para a autoridade bruta
  `ROLE_SUPER_ADMIN` (`SUPER_ADMIN` no contrato funcional).
- A checagem deve continuar autorizando o Super Admin durante personificação ou
  seleção de tenant. A projeção temporária para `ROLE_TENANT_ADMIN` não pode
  remover acesso a esta superfície global.
- O item de navegação que aponta para a rota deve ser ocultado para identidades
  que não tenham `ROLE_SUPER_ADMIN`.
- A proteção da rota e a visibilidade do item de menu devem possuir testes
  positivos e negativos.

## Apresentação mínima

A tela deve exibir a versão atual, a data da versão atual, uma lista agrupada
por release, o estado de versão atual e as mudanças concluídas com tipo e
descrição.

Quando a versão também for exibida no menu lateral, o formato obrigatório é
`vX.Y.Z - dd/mm/aaaa`, usando a mesma versão e data do snapshot consumido pela
página. Datas desconhecidas devem ser exibidas como `Data: não registrada`.

## Fluxo de atualização

1. Registrar cada mudança observável no `CHANGELOG.md`, na seção `Não lançadas`,
   usando um tipo permitido e marcando `[x]` somente após implementação e
   validação.
2. Regenerar explicitamente o snapshot por meio do comando documentado pelo
   projeto.
3. Validar a sincronização entre Markdown, snapshot, versão e lockfile.
4. Executar a validação de referências relativas quando documentos forem
   criados ou alterados.
5. Perguntar ao responsável se a versão deve permanecer ou subir para patch,
   minor ou major. Nenhum incremento deve ser inferido pelo agente.

## Materialização por projeto

Cada projeto deve complementar este standard com um documento específico que
registre os caminhos concretos, o comando de geração, os verificadores, a
implementação da rota e do guard, a localização do menu, os testes e as
decisões de versão.

O documento específico não pode relaxar este contrato; apenas pode especializar
caminhos, componentes e detalhes de apresentação.
