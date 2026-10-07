---
document_id: "ADR-0033"
primary_nature: "Decisao"
objective: "Definir a arquitetura-alvo, as fronteiras e a preferência técnica para evoluir a fundação externa da plataforma para IaC sem ampliar o risco residual ou disputar ownership com Compose e o runtime tenant."
scope: "Recursos de provider, GitHub e AWS; layout futuro dentro de `infra/`; engine IaC; state, locking, encryption, secrets, brownfield, HML, pipeline, drift, recovery e gates humanos."
non_objectives: "Aprovar produção ou piloto; criar `infra/iac/`; instalar ferramentas/providers; escrever configuração; importar/adotar recursos; executar `init`, `plan`, `apply`, `destroy`, deploy ou acessar ambiente/secret."
owner: "Arquitetura, DevOps e Segurança"
status: "Accepted"
date: "2026-08-23"
version: "1.1"
keywords: "IaC, OpenTofu, Terraform, Ansible, infra, state, locking, KMS, secrets, brownfield, Hostinger, GitHub, AWS, HML"
related_files: "README.md, ADR-0031-governanca-topologia-infraestrutura.md, ../../../docs/specs/TP-00016-infrastructure-iac-target-architecture.md, ../../../docs/specs/TP-00006-frontend-backend-cibersecurity-implementation-plan.md"
code_references: "target futuro `infra/iac/`; `infra/`, `docker-compose.yml`, `docker-compose.hml.yml`, `docker-compose.prd.yml`, `.github/workflows/`, `app/src/main/java/br/com/duoset/saas_service/contexts/tenant/`"
principal_statement: "A arquitetura adotada mantém `infra/` como umbrella, reserva uma futura subárvore `infra/iac/` para a fundação externa, prefere OpenTofu de forma condicional com Terraform como fallback, adia Ansible e exige state/segredos/brownfield/pipeline seguros antes de qualquer piloto."
---

# ADR-0033 - Arquitetura-alvo segura e incremental de IaC

- Document ID: `ADR-0033`
- Primary Nature: `Decisao`
- Objective: Definir a arquitetura-alvo, as fronteiras e a preferência técnica para evoluir a fundação externa da plataforma para IaC sem ampliar o risco residual ou disputar ownership com Compose e o runtime tenant.
- Scope: Recursos de provider, GitHub e AWS; layout futuro dentro de `infra/`; engine IaC; state, locking, encryption, secrets, brownfield, HML, pipeline, drift, recovery e gates humanos.
- Non-objectives: Aprovar produção ou piloto; criar `infra/iac/`; instalar ferramentas/providers; escrever configuração; importar/adotar recursos; executar `init`, `plan`, `apply`, `destroy`, deploy ou acessar ambiente/secret.
- Keywords: IaC, OpenTofu, Terraform, Ansible, infra, state, locking, KMS, secrets, brownfield, Hostinger, GitHub, AWS, HML
- Related Files: `ADR-0031-governanca-topologia-infraestrutura.md`, `artefatos de análise/ANL-00042-infrastructure-as-is-iac-gap-analysis.md`, `artefatos de análise/ANL-00043-infrastructure-iac-options-security-analysis.md`, `../../../docs/specs/TP-00016-infrastructure-iac-target-architecture.md`, `docs/delivery/reports/RPT-0004-frontend-backend-cibersecurity.md`, `../../../docs/specs/TP-00006-frontend-backend-cibersecurity-implementation-plan.md`, `docs/architecture/module-registry.md`, `infra/README.md`
- Code References: target futuro `infra/iac/`; `infra/`, `docker-compose.yml`, `docker-compose.hml.yml`, `docker-compose.prd.yml`, `.github/workflows/`, `app/src/main/java/br/com/duoset/saas_service/contexts/tenant/`
- Principal Decision: A arquitetura adotada mantém `infra/` como umbrella, reserva uma futura subárvore `infra/iac/` para a fundação externa, prefere OpenTofu de forma condicional com Terraform como fallback, adia Ansible e exige state/segredos/brownfield/pipeline seguros antes de qualquer piloto.
- Date: 2026-08-23
- Status: Accepted
- Version: 1.1
- Authors / Owners: Arquitetura, DevOps e Segurança
- Reviewers: DevOps, Segurança, Dados, Qualidade e Maintainer Humano de Infraestrutura
- Stakeholders: Engenharia, Operações, Arquitetura, Segurança, Dados, Observabilidade e responsáveis pela plataforma
- Supersedes: N/A; especializa o caminho futuro autorizado pelo ADR-0031 e não reativa trechos superseded do ADR-0016.
- Superseded by: N/A

---

# 1. Context

O Gate 0 preservou `infra/` como pacote operacional umbrella. O Gate 1 demonstrou
que Compose, configurações, workflows e scripts são automação relevante, mas a
fundação externa — provider/VPS, DNS, GitHub e recursos AWS — ainda não possui
desired state, state/locking, import brownfield ou drift uniformes.

A revisão do RPT-0004 não libera produção. O relatório é histórico e declara risco
residual alto enquanto rotação de credenciais, saneamento do histórico Git,
Keycloak/TLS em HML, recovery e pentest permanecerem pendentes. Assim, escolher
uma ferramenta sem definir ownership, state, secrets, approvals e recuperação
apenas codificaria os riscos atuais em outra camada.

A ANL-00043
comparou OpenTofu, Terraform e o papel complementar do Ansible com documentação
oficial atual. O Maintainer Humano aceitou esta decisão em `G2.7` em 2026-08-23;
o aceite é normativo para a arquitetura, mas não autoriza operação ou piloto.

# 2. Decision Statement

A plataforma adota os seguintes princípios cumulativos.

## 2.1 Topologia e separação de autoridades

1. `infra/` permanece o umbrella canônico; não haverá diretório raiz `iac/`.
2. A implementação futura poderá criar `infra/iac/` exclusivamente para desired
   state de recursos externos. A pasta não será criada por este aceite.
3. Compose continua autoridade para serviços, redes e volumes compartilhados.
4. O pipeline/deploy atual continua autoridade para release, `.deploy/state`,
   migrations e proteções stateful.
5. O backend continua autoridade para criar banco, executar Flyway, registrar
   DataSource e provisionar realm de cada tenant. IaC não executa onboarding.
6. Secrets, chaves privadas, TLS, keyrings e dados permanecem em custódias próprias;
   IaC declara somente referências, policies e metadados não secretos.

## 2.2 Escopo inicial da fundação IaC

| Domínio | Recursos candidatos | Condição de entrada |
| --- | --- | --- |
| State foundation | Bucket/KMS/IAM/OIDC exclusivos do state | Bootstrap humano auditado, recovery e break-glass aprovados. |
| GitHub governance | Ruleset, Environment, approvals e integrações suportadas | Sandbox e caminho de desbloqueio testados. |
| AWS backup | Bucket/KMS/IAM/lifecycle de backup | Gate Dados+Segurança e restore drill. |
| Hostinger | VPS, DNS, firewall/recursos suportados e chaves SSH públicas | Inventário, import, preview zero-diff e proteção anti-delete. |
| Host OS | Packages, usuários, SSH e systemd | Fora do primeiro incremento; permanece nos scripts atuais. |

Nenhum recurso entra por conveniência da ferramenta. Resource sem provider maduro,
import seguro, owner, source of truth e rollback fica fora do root declarativo.

## 2.3 Engine e configuração de host

1. **OpenTofu é a engine preferida**, condicionada a POC sem credenciais e com
   versões pinadas dos providers Hostinger, GitHub e AWS.
2. **Terraform CLI é o fallback explícito** se compatibilidade, schema, import ou
   operação do provider Hostinger não forem demonstrados com OpenTofu.
3. O Gate 2 aceita OpenTofu como preferência condicional e Terraform como
   fallback; esta decisão não autoriza instalação, download ou execução.
4. **Ansible é adiado**. Ele será reavaliado quando HML/segundo host, rebuild
   frequente ou drift do sistema operacional justificar um control plane próprio.
5. Provisioners `local-exec` e `remote-exec` são proibidos no baseline. Uma exceção
   exige ADR sucessora porque esconderia automação imperativa dentro do plan.

## 2.4 State, locking e recovery

1. State é remoto, cifrado, versionado, bloqueável, auditável e separado de
   `.deploy/state` e do backup de dados.
2. O backend alvo usa bucket S3 exclusivo, Block Public Access, SSE-KMS,
   versionamento e locking nativo com `use_lockfile=true`.
3. A chave KMS, papéis e prefixes do state são exclusivos do domínio IaC.
4. States são separados por blast radius/trust boundary; PRD não é multiplexado
   por workspace.
5. Leitura cross-state ampla por `terraform_remote_state` não integra o baseline;
   IDs não sensíveis usam data sources do provider ou publicação explícita.
6. State, lock e plan salvo nunca entram em Git, artifact público ou log.
7. A criptografia cliente de state/plan do OpenTofu só será habilitada depois de
   provar recuperação da chave e do state. Perda de KMS deve possuir procedimento
   e evidência antes do enforcement.
8. O bucket de state não reutiliza bucket/chave de backup. Object Lock não é
   premissa do state porque o objeto de lock operacional precisa ser removível;
   imutabilidade adicional requer teste e decisão próprios.
9. O bootstrap do backend não depende circularmente do próprio state: criação
   inicial é um procedimento mínimo, humano e auditado, seguido de import/adoption.

## 2.5 Secrets e identidades

1. Nenhum valor secreto é gravado em Git, HCL, tfvars versionado, output, plan ou
   state quando a API/provider permitir evitar a persistência.
2. `sensitive` é redaction, não prova de ausência no state.
3. GitHub Actions usa credenciais temporárias AWS via OIDC com trust restrita ao
   repositório, contexto e Environment aprovados.
4. GitHub e Hostinger usam identidades dedicadas de mínimo privilégio, injetadas
   pelo ambiente protegido e rotacionadas; forma final depende do inventário.
5. Senhas, private keys, certificados TLS, `.env.production`, `.deploy/state`,
   `.deploy/secrets` e secrets de aplicação nunca são recursos gerenciados pelo
   IaC de fundação.

## 2.6 Brownfield e proteção contra destruição

Cada recurso existente seguirá obrigatoriamente:

`inventário → owner/source of truth → configuração → import/adoption revisado →
preview zero-diff → proteção anti-recreate/delete → recovery → apply autorizado`.

Não haverá import em massa, geração automática a partir do ambiente nem correção
de drift durante a adoção. VPS, DNS, KMS, bucket, Ruleset e Environment exigem
proteção reforçada; replace/delete interrompe o fluxo e retorna ao humano.

## 2.7 Pipeline, HML e drift

1. PR não confiável executa somente format/validate/test/policy/scan sem credencial.
2. Preview credenciado usa SHA revisado em contexto confiável e identidade
   read-only quando suportada.
3. Apply usa o SHA/plano aprovado, Environment protegido, reviewer humano e
   identidade de escrita separada.
4. Não existe auto-apply em PRD. Break-glass é temporário, auditável, revogado e
   reconciliado posteriormente por PR.
5. Drift produz preview read-only e alerta; nunca autorremedia PRD.
6. Providers, modules e actions têm versões/checksums pinados e lockfile
   versionado; updates passam por revisão e scans.
7. HML é uma capacidade obrigatória de validação pré-PRD para TLS, IAM/Keycloak,
   DAST, restore e alertas. Sua forma durável/efêmera e custo permanecem decisão
   operacional anterior ao rollout.

# 3. Decision Drivers

- risco residual alto declarado no RPT-0004;
- ausência de desired state e drift na fundação externa;
- ambiente brownfield com VPS, DNS, GitHub e AWS potencialmente existentes;
- necessidade de state/locking/recovery independente da própria VPS;
- segregação entre plataforma e onboarding dinâmico multi-tenant;
- mínimo privilégio e ausência de secrets persistidos;
- uma VPS e equipe em estágio inicial, evitando dois control planes prematuros;
- provider oficial Hostinger orientado ao ecossistema Terraform/HCL;
- incrementalidade, blast radius pequeno e revisão humana;
- descoberta segura por agentes e preservação do ADR-0031.

# 4. Considered Options

## Option A: Manter somente scripts e Compose

Pros:

- nenhum tooling novo;
- preserva os caminhos operacionais atuais.

Cons:

- não cria desired state de provider/GitHub/AWS;
- não fecha state, locking, import e drift;
- mantém recuperação e ownership externos distribuídos.

## Option B: Terraform + Ansible desde o primeiro incremento

Pros:

- Hostinger documenta diretamente o provider para Terraform;
- separa provider IaC de configuração idempotente do host.

Cons:

- introduz duas ferramentas, dois pipelines e dois modelos de recovery;
- antecipa Ansible sem segundo host/HML operacional ou necessidade comprovada;
- não melhora por si só secrets, approvals ou brownfield.

## Option C: OpenTofu condicional, Terraform fallback e Ansible adiado

Pros:

- preserva HCL e o protocolo/ecossistema de providers;
- oferece locking S3 e criptografia cliente nativa de state/plan;
- mantém fallback explícito para a compatibilidade oficialmente documentada pelo
  provider Hostinger;
- limita o primeiro incremento a um control plane declarativo.

Cons:

- compatibilidade Hostinger/OpenTofu ainda precisa ser provada;
- criptografia cliente exige recovery rigoroso da chave;
- host bootstrap continua temporariamente imperativo.

## Option D: Escolher ferramenta e importar PRD imediatamente

Pros:

- entrega visibilidade aparente mais rapidamente.

Cons:

- viola o sequenciamento P0/P1, amplia blast radius e mistura diagnóstico com
  mutação;
- pode recriar/cancelar recursos brownfield ou vazar state/plan;
- não possui autorização humana para ambiente ou efeito externo.

# 5. Decision Outcome

A **Option C** é a decisão aceita.

Ela oferece a melhor relação entre segurança, capacidade declarativa e
incrementalidade para o estágio atual, sem tornar uma hipótese de compatibilidade
uma adoção irreversível. A escolha permanece condicional: falha no POC Hostinger,
no recovery de state ou nos controles P0/P1 devolve a decisão para Terraform,
redução de escopo ou revisão do ADR.

O Gate 2 humano aceitou esta arquitetura em 2026-08-23. `infra/iac/` não existe,
OpenTofu não está autorizado para instalação ou execução e nenhum recurso é
gerenciado; um piloto exige escopo, plano e autorização operacional separados.

# 6. Consequences

## Positive Consequences

- ownership de IaC, Compose, deploy e runtime tenant fica explícito;
- state não depende da VPS gerenciada nem do backup de dados;
- secrets e approvals tornam-se critérios de arquitetura;
- provider/tooling pode ser validado sem tocar ambiente;
- Ansible só entra quando seu benefício operacional for demonstrável.

## Negative Consequences

- desired state externo continua ausente até um piloto posterior;
- há trabalho inicial de bootstrap, IAM, recovery e import brownfield;
- a compatibilidade Hostinger/OpenTofu é um gate adicional;
- scripts de host permanecem coexistindo com a futura IaC.

## Neutral Consequences

- Compose, `.deploy/state`, workflows de release e onboarding tenant mantêm paths
  e authorities atuais;
- P0/P1 exigem planos próprios; não são corrigidos por esta ADR;
- custos e forma de HML continuam pendentes de inventário/decisão.

# 7. Impact

| Área | Impacto da decisão |
| --- | --- |
| Topologia | Futuro `infra/iac/` dentro do umbrella; nenhum root `iac/`. |
| Segurança | State/plan sensíveis, OIDC, least privilege, approvals e anti-delete obrigatórios. |
| Dados | Backup/state separados; recursos stateful e tenant ficam fora do primeiro escopo. |
| DevOps | Novo control plane somente após POC, requisitos e gate humano. |
| CI/CD | Preview e apply separados; PR não confiável sem credencial; drift somente alerta. |
| Runtime | Compose e backend tenant continuam authorities. |
| Documentação | ADR decide; ANL compara; TP coordena; runbook posterior executa. |
| Agentes | Decisão aceita não pode ser interpretada como autorização para criar pasta, baixar provider ou operar ambiente. |

# 8. AI Agent Considerations

Agentes DEVEM:

- verificar o status `Accepted` e não confundi-lo com autorização operacional;
- carregar ADR-0031, TP-00016 e ANL-00043;
- separar evidência de repositório, documentação externa e estado não verificado;
- tratar plan/state/log como material sensível;
- interromper replace/delete, import ambíguo ou acesso externo e devolver ao
  Maintainer Humano.

Agentes NÃO DEVEM:

- criar `infra/iac/`, instalar CLI/provider ou executar POC sem autorização futura;
- ler `.env`, `.deploy/`, `.dev-secrets/`, state, plan, keys, dumps ou backups;
- usar provisioner como ponte automática para scripts existentes;
- gerir DB/realm tenant ou `.deploy/state` pela fundação IaC;
- criar ferramenta, piloto ou efeito externo somente a partir desta decisão.

# 9. Implementation Plan

Após este aceite, qualquer implementação seguirá planos separados:

1. fechar/aceitar P0/P1 e requisito observável da fundação;
2. criar Implementation Plan do POC repo-only, sem credenciais/backend;
3. provar versões, checksums, provider schemas e testes herméticos;
4. criar runbook de bootstrap/recovery do backend e obter autorização própria;
5. executar piloto sandbox sem dados reais;
6. revisar evidência e somente então planejar brownfield GitHub, AWS e Hostinger;
7. criar `infra/iac/` e atualizar topologia apenas no incremento autorizado.

Rollback desta etapa documental é rejeitar ou superseder a ADR. Não existe
rollback operacional porque nenhum recurso foi alterado.

# 10. Validation

## Nesta etapa

- ADR, TP e análises possuem IDs, links e índices individuais.
- `./infra/scripts/validate-docs.sh` e `git diff --check` passam.
- Cadeia raiz → `infra/AGENTS.md` descobre a Etapa 2 e não concede execução.
- Gate 1 registra aprovação humana sem alegar produção pronta.
- Gate 2 registra aceite humano da arquitetura sem autorizar piloto.

## Antes de um futuro piloto

- POC sem credenciais/backend valida engine e providers pinados.
- Recovery da chave e do state é ensaiado antes de encryption enforcement.
- Pipeline prova separação entre PR, preview e apply.
- Sandbox prova locking, drift/alerta e ausência de auto-apply.
- Plano de import produz zero mudança e bloqueia replace/delete.

# 11. Risks and Mitigations

| Risco | Mitigação |
| --- | --- |
| Provider Hostinger não operar com OpenTofu | POC hermético e Terraform como fallback explícito. |
| Perda de KMS tornar state ilegível | Recovery/break-glass ensaiado antes de criptografia cliente enforced. |
| State ou plan vazar segredo | Evitar valores, stores cifrados, acesso mínimo e nenhum artifact/log público. |
| Import brownfield causar recreate/delete | Inventário, ID revisado, preview zero-diff, proteção destrutiva e gate humano. |
| IaC disputar runtime tenant/Compose | Matriz de authority e exclusões normativas da Section 2.1. |
| GitHub IaC bloquear o próprio repositório | Sandbox e caminho de desbloqueio/break-glass antes de adoption. |
| Dois control planes aumentarem complexidade | Adiar Ansible até necessidade mensurável. |
| ADR aceita ser lida como autorização operacional | Entry points declaram `Accepted`, mas mantêm piloto, tooling e execução proibidos sem plano e autorização separados. |

# 12. Related ADRs

- [ADR-0000 — Governança documental e agentes](../../harness/governance/decisions/ADR-0000-governanca-do-harness-documental.md)
- [ADR-0001 — Technology Stack and Architecture](ADR-0001-technology-stack-and-architecture.md)
- [ADR-0016 — Infrastructure Environment Provisioning](ADR-0016-infrastructure-environment-provisioning.md)
- [ADR-0018 — Keycloak Realm Provisioning](ADR-0018-keycloak-realm-provisioning-automation.md)
- [ADR-0019 — Single Database-per-Tenant](ADR-0019-database-per-tenant.md)
- [ADR-0031 — Governança e topologia de infraestrutura](ADR-0031-governanca-topologia-infraestrutura.md)

# 13. References

- [TP-00016 — Etapa 2](../../../docs/specs/TP-00016-infrastructure-iac-target-architecture.md)
- ANL-00042 — AS-IS e gaps
- ANL-00043 — opções e segurança
- [RPT-0004 — cibersegurança](../delivery/reports/RPT-0004-frontend-backend-cibersecurity.md)
- [OpenTofu — backend S3](https://opentofu.org/docs/language/settings/backends/s3/)
- [OpenTofu — state/plan encryption](https://opentofu.org/docs/language/state/encryption/)
- [OpenTofu — sensitive state](https://opentofu.org/docs/language/state/sensitive-data/)
- [OpenTofu — provisioners](https://opentofu.org/docs/language/resources/provisioners/syntax/)
- [Terraform — backend S3](https://developer.hashicorp.com/terraform/language/backend/s3)
- [Terraform — sensitive data](https://developer.hashicorp.com/terraform/language/manage-sensitive-data)
- [Hostinger — provider oficial](https://github.com/hostinger/terraform-provider-hostinger)
- [GitHub — OIDC](https://docs.github.com/en/actions/concepts/security/openid-connect)
- [AWS — IAM OIDC](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_oidc.html)

# 14. Decision Lifecycle

`Accepted` em 2026-08-23 pelo Maintainer Humano, com `G2.6` e `G2.7` concluídos no
TP-00016. O aceite aprova a arquitetura e a preferência condicional por OpenTofu;
um piloto continua dependendo de requisito, Implementation Plan, ambiente/efeito
identificados e autorização separada.

# 15. Change Log

| Version | Date | Owner | Change |
| --- | --- | --- | --- |
| 1.1 | 2026-08-23 | Maintainer Humano / Arquitetura | Aceita a Option C no Gate 2 e explicita que o status normativo não autoriza piloto ou efeito externo. |
| 1.0 | 2026-08-23 | Arquitetura / DevOps / Segurança | Propõe arquitetura-alvo, preferência OpenTofu condicional, fallback Terraform, Ansible adiado e controles de state, secrets, brownfield e pipeline. |
