# Instruções globais do projeto para Claude Code

Estas instruções são semanticamente equivalentes ao `AGENTS.md` da raiz. Este
arquivo governa toda a árvore; instruções locais podem especializar sua subárvore,
mas não enfraquecer segurança, ADR aceito ou standard global.

## Entrada documental

- Antes de trabalhar, leia `docs/ai/README.md`. Use `docs/README.md` como mapa e não
  carregue coleções inteiras sem necessidade.
- Use `docs/agents/AgentOrchestrator.md` como papel inicial para classificar a
  solicitação, selecionar standards e coordenar gates. Nenhum outro agente é
  presumido ativo pelo baseline.
- Consulte `docs/adrs/README.md` antes de abrir um ADR e
  `docs/architecture/module-registry.md` para módulos, owners e comandos.

## Documentação

- Todo artefato criado, movido, renomeado, reclassificado ou removido em `docs/`
  deve atualizar o `README.md` da coleção imediata na mesma mudança.
- Todo documento atende ao contrato mínimo e à taxonomia do ADR-0000.
- Execute o validador documental configurado no projeto. Se ainda não houver um,
  valide estrutura, metadados, links e índices manualmente e registre a lacuna como
  `Automação não configurada`.

## Antes de implementação

- Aplique `implementation-readiness` antes de escrever código, configuração
  executável, migration ou IaC e exija `READY` para o task ID, versões, escopo e
  paths exatos.
- PRD aplicável não `Validated`, assumption ou hipótese não encerrada, Open
  Question, `TBD`, conflito, dependência ausente ou DoD subjetiva produz `BLOCKED`.
- Falta de atomicidade aciona decomposição semântica por resultado e handoff. Não
  divida apenas por arquivo, camada, quantidade de linhas ou testes.
- Em `BLOCKED`, não infira decisão. Materialize a resposta na fonte canônica,
  obtenha a aprovação aplicável e repita o gate.

## Execução e assurance

- Toda mudança de software cria ou atualiza teste relevante e executa teste
  focalizado, suíte impactada e gates aplicáveis em ambiente seguro.
- O Quality Gate exige o mesmo `READY` usado pela implementação. Divergência de
  versão, escopo ou path retorna ao planejamento.
- A1 Test, A2 Quality e A3 Security/Compliance são independentes. Um resultado
  verde não aprova os demais.
- Corrija falhas pertencentes ao escopo e reexecute enquanto houver progresso. Não
  reduza limiar, omita teste ou produza falso verde.

## Segurança e entrega Git

- Leitura local e edição reversível solicitada são permitidas dentro do escopo.
- Instalação, download, rede, sistema externo, exclusão ampla ou ação irreversível
  exigem autorização explícita.
- Não acesse produção, dados reais, segredos ou credenciais.
- Git de escrita e operações de integração são autorizados conforme
  `docs/settings/git-delivery.md`, preservando a proteção da `main`.
- Trabalhos devem ocorrer em branches separadas. PR, merge, rebase, push e outras
  operações Git podem integrar trabalhos quando respeitarem a política local e os
  gates aplicáveis. É proibido escrever diretamente na `main` ou fazer force-push
  nela.
- A skill `git-delivery` não bloqueia paths, funcionalidades ou artefatos novos ou
  alterados apenas por serem novos; conflitos e falhas de gate devem ser tratados
  sem descartar trabalho válido.

## Handoff

Informe arquivos alterados, decisões, comandos, resultados, skips, falhas,
limitações e pendências. Não declare conclusão sem evidência reproduzível.
