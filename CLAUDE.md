# Instruções globais do projeto para Claude Code

Este adaptador é semanticamente equivalente ao `AGENTS.md` da raiz. Comece por
`docs/ai/README.md`, use `docs/README.md` como mapa, consulte
`docs/adrs/README.md` antes de ADRs específicos e use
`docs/architecture/module-registry.md` para módulos, owners e comandos.

Toda alteração em `docs/` atualiza o `README.md` da coleção imediata e atende ao
contrato mínimo e à taxonomia do ADR-0000. Execute o validador documental do
projeto; se ele ainda não existir, valide estrutura, metadados, links e índices
manualmente e reporte `Automação não configurada`.

Antes de escrever código, configuração executável, migration ou IaC, aplique a
skill `implementation-readiness` e exija `READY` para task ID, versões, escopo e
paths exatos. PRD aplicável não `Validated`, hipótese ou assumption pendente, Open
Question, `TBD`, conflito, dependência ausente ou DoD subjetiva produz `BLOCKED`.
Falta de atomicidade aciona decomposição semântica por resultado e handoff, nunca
divisão puramente por arquivo, camada, linhas ou testes. Em `BLOCKED`, materialize
a resposta na fonte canônica, obtenha a aprovação aplicável e repita o gate.

Toda mudança de software cria ou atualiza teste relevante e executa teste
focalizado, suíte impactada e gates aplicáveis em ambiente seguro. A1 Test, A2
Quality e A3 Security/Compliance são independentes e exigem evidência própria. O
Quality Gate deve corresponder ao mesmo `READY`; divergência retorna ao planejamento.
Não reduza limiar, omita teste nem produza falso verde.

Leitura local e edição reversível solicitada são permitidas no escopo. Instalação,
download, rede, sistema externo, exclusão ampla e ação irreversível exigem
autorização explícita. Não acesse produção, dados reais, segredos ou credenciais.
Git de escrita, push, PR, merge, tag, rebase, reset ou alteração de remote não são
autorizados por este baseline; aplique a política explícita do projeto de destino.

Regras locais podem especializar seu pacote sem enfraquecer fontes superiores. No
handoff, informe arquivos, decisões, comandos, resultados, skips, falhas,
limitações e pendências; não declare conclusão sem evidência reproduzível.

