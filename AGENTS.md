# Bootstrap de agentes — AI Engineering Harness

Este repositório usa o control plane canônico em [`harness/`](harness/README.md).
Leia primeiro `harness/README.md`, depois
`harness/governance/README.md` e [`docs/README.md`](docs/README.md).
Antes de executar alterações, carregue as fontes canônicas de [governança comportamental](harness/governance/policies/agent-behavior-policy.md), [proibições](harness/governance/restrictions/agent-prohibitions.md), [segurança](harness/governance/restrictions/security-restrictions.md) e [filesystem](harness/governance/restrictions/filesystem-restrictions.md); não duplique essas regras neste bootstrap.
Para adoção, use `node harness/tooling/harness.mjs onboard`; para legado use `onboard --source`; para clone configurado use `bootstrap`. A policy canônica está em `harness/onboarding/`.
Consulte `harness.project.yaml` somente se existir; o exemplo em
`harness/examples/` não ativa capabilities.
Quando existir `docs/project-manifest.yaml`, resolva profiles e artefatos pelo
`harness/registry/profiles.yaml` e `artifact-routes.yaml`, usando o scaffold;
nenhum runtime inventa paths ou conteúdo técnico fora dessa cadeia.
Para módulos, owners e comandos reais, consulte
`docs/architecture/module-registry.md`.

`AgentOrchestrator` é o único papel inicial. Carregue progressivamente o ADR,
standard, skill e profile aplicáveis ao pedido; não carregue coleções inteiras
por padrão. Instruções locais podem especializar, mas não enfraquecer as
[decisões aceitas](harness/governance/decisions/README.md), a
[política de ambiente](harness/governance/policies/ai-environment-policy.md) nem
os standards globais.

Antes de escrever código, configuração executável, migration ou IaC, aplique
[`implementation-readiness`](harness/skills/implementation-readiness/SKILL.md)
para task ID, versões, escopo e paths exatos. PRD aplicável não `Validated`,
requirement não `Approved`, hipótese aberta, dependência ausente ou DoD subjetiva
produz `BLOCKED`; somente `READY` vigente permite executar. Não infira a resposta.
Mudança de software exige testes
relevantes e [quality-gate](harness/skills/quality-gate/SKILL.md) com A1, A2 e
A3 independentes. Falha não vira PASS por omissão de teste ou limiar reduzido.

Não acesse produção, dados reais, segredos ou credenciais. Rede, instalação,
exclusão ampla e ação irreversível exigem autorização explícita. Preserve
trabalho local e não sobrescreva conteúdo project-owned. `.agents/skills/` e
`.claude/skills/` são derivados de `harness/skills/`; edite a fonte canônica e
verifique a paridade com `node harness/tooling/harness.mjs sync`.

Git de escrita segue a [git-delivery-policy.md](harness/governance/policies/git-delivery-policy.md)
e gates aplicáveis. Trabalhe em branch separada; é proibido escrever diretamente
na `main` ou fazer force-push nela. Commit e push não são release e só ocorrem
quando solicitados e autorizados pela política local.

Cada documento criado, movido ou removido em `docs/` atualiza o índice imediato.
Use o [validador documental](harness/tooling/validators/README.md) quando
aplicável. Entregue handoff com arquivos, decisões, comandos, resultados,
skips, falhas, limitações e pendências; não declare conclusão sem evidência.
