# Política Central Neutra do Harness

Esta política estabelece os invariantes inegociáveis que todo adaptador de runtime deve refletir.

## 1. Entrada Documental e Precedência

1. Políticas organizacionais gerenciadas de segurança e compliance.
2. ADRs aceitos.
3. Standards e settings globais versionados.
4. Adaptadores globais de runtime.
5. Instruções específicas do pacote.
6. Plano e critérios de aceite da tarefa.
7. Preferências locais do usuário.

Antes de qualquer trabalho, leia `docs/ai/README.md`. Use `docs/README.md` como mapa.
Use `docs/agents/AgentOrchestrator.md` como papel inicial para classificar a solicitação, selecionar standards e coordenar gates. Nenhum outro agente é presumido ativo pelo baseline.

## 2. Governança Documental

Todo artefato criado, movido, renomeado, reclassificado ou removido em `docs/` deve atualizar o `README.md` da coleção imediata na mesma mudança. Todo documento atende ao contrato mínimo e à taxonomia do ADR-0000.

## 3. Antes de Implementação (Implementation Readiness)

Aplique `implementation-readiness` antes de escrever código, configuração executável, migration ou IaC e exija `READY` para o task ID, versões, escopo e paths exatos. PRD aplicável não `Validated`, assumption não encerrada, Open Question, `TBD`, dependência ausente ou DoD subjetiva produz `BLOCKED`. Não existe waiver.

## 4. Execução e Assurance

Toda mudança de software cria ou atualiza teste relevante e executa teste focalizado, suíte impactada e gates aplicáveis em ambiente seguro. A1 Test, A2 Quality e A3 Security/Compliance são independentes. Um resultado verde não aprova os demais. Falha fecha o gate (`BLOCKED` ou `FAIL`).

## 5. Segurança e Entrega Git

Leitura local e edição reversível são permitidas dentro do escopo. Git de escrita segue `docs/settings/git-delivery.md`. Trabalhos devem ocorrer em branches separadas. É proibido escrever diretamente na `main` ou fazer force-push nela.

## 6. Handoff

Informe arquivos alterados, decisões, comandos, resultados, skips, falhas, limitações e pendências. Não declare conclusão sem evidência reproduzível.
