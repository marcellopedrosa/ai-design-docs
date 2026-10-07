---
document_id: "IAC-SUPPLY-CHAIN-STANDARD"
primary_nature: "Regra"
objective: "Definir controles open-source-first e fail-closed para governar a cadeia de suprimentos das dependências do futuro POC IaC hermético."
scope: "CLI IaC, providers, scanners, verificadores e runtimes auxiliares do POC governado pelo REQ-00044, desde a origem submetida à allowlist até a quarentena, o mirror selado e o replay offline."
non_objectives: "Aprovar produto, origem, versão, aquisição, exceção ou execução concreta; criar IP-INFRA, infra/iac, tooling, lockfile, cache, mirror, fixture, state ou ambiente; acessar rede, registry, provider, conta, dado ou secret; autorizar ferramenta proprietária ou apenas source-available."
owner: "Segurança e DevOps, com ativação pelo Maintainer Humano"
status: "Active"
date: "2026-08-28"
version: "1.3"
keywords: "iac, supply-chain, open-source, origem, redirect, credencial-efêmera, pinning, lockfile, checksum, assinatura, malware, licença, cve, mirror, provenance, offline, quarentena"
related_files: "../../../backend/docs/adrs/ADR-0033-arquitetura-alvo-iac-segura.md, docs/product/requirements/REQ-00044-infrastructure-iac-hermetic-poc.md, artefatos de análise/ANL-00044-req-00044-iac-hermetic-poc-adherence-analysis.md, ../../specs/TP-00017-infrastructure-iac-hermetic-poc.md, ../../specs/TP-00018-opentofu-offline-manifest-correction.md, ../../specs/TP-00025-opentofu-artifact-eligibility.md, docs/delivery/reports/RPT-0004-frontend-backend-cibersecurity.md, ./security-standard.md"
code_references: "N/A - standard documental; infra/iac, tooling e artefatos da cadeia ainda não existem."
principal_statement: "O baseline open-source-first e o perfil tipificado EPHEMERAL_PUBLIC_ASSET_REDIRECT estão Active; nenhuma origem ou matriz concreta foi aprovada, a allowlist permanece vazia e toda aquisição ou execução continua bloqueada."
last_reviewed: "2026-08-28"
---

# IaC Supply Chain Standard

> [!IMPORTANT]
> Este standard está `Active` desde o `G3.6.2-F`, mas sua ativação somente torna
> os controles abaixo obrigatórios. Isoladamente, ele não aprova dependência,
> origem, versão, exceção, aquisição, pesquisa, replay ou execução concreta. A
> allowlist de artefatos/origens continua vazia. O TP-00017 terminou `Cancelled`
> por no-go.
> Sob lifecycle e gates próprios, o TP-00018 depois realizou pesquisa oficial
> read-only e avaliação local limitada de um artefato OpenTofu, encerrada como
> `Completed — Review Concluded / Artifact Not Eligible`. Isso não desativa nem
> satisfaz a policy e não torna qualquer item elegível. Em 2026-08-28,
> `G25.3-A-REDIRECT-POLICY-ACTIVATION` incorporou literalmente `EAR-DRAFT-001`
> como o perfil normativo estreito `EPHEMERAL_PUBLIC_ASSET_REDIRECT` da v1.3.
> Essa emenda não aprovou origem, matriz concreta, Location histórica, captura,
> rede, GET, download, allowlist ou execução.

## 1. Autoridade, estado e efeito

O `G3.6.2-E` autorizou preparar e revisar este documento como `Draft`. O
Maintainer Humano aprovou o `G3.6.2-F` em 2026-08-24, determinou o baseline
open-source-first com elegibilidade inicial restrita a open source, promoveu
explicitamente `Draft → Active` e encerrou separadamente `L-007` quanto à
existência e aprovação desta policy. SecurityAgent e DevOps-Agent emitiram
revisões técnicas read-only `Approved` neste gate; isso não constitui delegação
nova nem transfere autoridade ao próximo gate.

O encerramento de `L-007` possui boundary estrito:

- `AC-011` está `PASS` somente no eixo documental da policy;
- o conjunto de origens, versões e artefatos permitidos continua vazio;
- nenhuma exceção está aprovada;
- readiness permanece `NOT_PROVEN` e execução permanece `BLOCKED`;
- este standard, isoladamente, não autoriza pesquisa externa, seleção, IP
  específico, `infra/iac/`, tooling, download, rede, registry/provider, ambiente
  ou comandos operacionais;
- nenhuma alçada ou autoridade do `G3.6.2-F` é herdada pelo próximo gate.

O TP-00018 não herdou essa autoridade: recebeu gates humanos próprios somente
para pesquisa read-only em fontes oficiais, intake de arquivos fornecidos pelo
humano e comandos locais offline de inspeção/verificação. O resultado registrou
identidade, integridade e vínculo criptográfico leaf como evidência limitada;
trust chain/tlog, provenance completa, licença do conteúdo, libc, scanners e
elegibilidade permaneceram `NOT_PROVEN`. Nenhuma instalação, execução de
OpenTofu/provider, allowlist, mirror, lockfile, IP ou ambiente foi autorizada.

## 2. Escopo de dependências e raízes de confiança

Esta policy abrange cada artefato executável ou carregável usado na futura
aquisição ou no replay:

- CLI IaC e eventual engine fallback aprovada separadamente;
- cada provider, por identidade completa e plataforma;
- scanners de malware, licença, vulnerabilidade/advisory e configuração;
- verificadores de checksum, assinatura e provenance;
- runtime, imagem ou empacotador que possa interpretar ou transformar bytes da
  cadeia.

Cada item será uma dependência independente. A confiança em um scanner não
valida o próprio scanner: seu binário, versão, plataforma, origem e integridade
também deverão constar da matriz futura de dependências. As raízes de confiança
de checksum e assinatura deverão ser enumeradas e aprovadas; não poderão nascer
de cache local, configuração global do operador ou descoberta automática.

Backend, state, recursos, módulos remotos, credenciais, APIs de provider e
provisioning tenant permanecem fora deste standard e do POC repo-only.

### 2.1 Baseline open-source-first

Para este standard, uma ferramenta é elegível como open source somente quando,
cumulativamente:

- o código-fonte correspondente à versão exata está publicamente disponível para
  inspeção;
- a licença concede direitos de usar, estudar, modificar e redistribuir, possui
  identificador SPDX e pertence à allowlist da Section 6.1;
- release, source revision e artefato podem ser ligados por provenance
  verificável;
- nenhuma parte executável obrigatória do controle depende de componente
  proprietário ou fechado não declarado.

O identificador SPDX auxilia a identificação, mas não prova sozinho os direitos
da licença. Código apenas visível (`source-available`) sem esses direitos,
freeware, binário proprietário e serviço fechado usado na cadeia de tooling não
satisfazem o baseline. Serviços-alvo do provisionamento permanecem fora desta
regra de elegibilidade. Para o POC inicial, a elegibilidade é restrita a open
source; software fechado exige alteração versionada desta policy e novo gate
humano. O status open source não substitui pinning, assinatura, scans ou qualquer
outro controle.

## 3. Classificação fail-closed

| Resultado | Condição | Efeito obrigatório |
| --- | --- | --- |
| `PASS` | Todos os controles aplicáveis possuem evidência íntegra, atual, rastreável e sem violação. | O artefato pode seguir somente para o próximo gate documental ou operacional já autorizado. |
| `FAIL` | Há violação observada, como bytes divergentes, assinatura inválida, malware, licença proibida ou vulnerabilidade acima do threshold. | Rejeitar e colocar em quarentena antes de carregar ou executar. |
| `NOT_PROVEN` | Falta evidência, cobertura, suporte, freshness ou conclusão determinística; ocorreu timeout/erro; provenance não é verificável. | Não carregar nem executar; manter o gate `Blocking`. |
| `BLOCKED` | Estado do gate quando existe `FAIL`, `NOT_PROVEN`, autorização ausente ou precondição incompleta. | Nenhuma progressão ou fallback automático. |

`APPROVED_EXCEPTION` é uma disposição humana separada, nunca um resultado
técnico. Ela preserva o `FAIL`/`NOT_PROVEN` original e só pode tornar o artefato
exato elegível quando a classe for excepcionável pela Section 11, os controles
compensatórios forem satisfeitos e a validade estiver vigente.

Ausência de achado não é evidência de cobertura. `PASS` de supply chain não é
`PROTOCOL_SCHEMA_PASS`, não aprova aquisição e não demonstra compatibilidade de
provider. Quando o mesmo artefato possuir evidência de `FAIL` e lacunas
`NOT_PROVEN`, prevalece `FAIL`, sem apagar as lacunas do registro.

## 4. Origem permitida, identidade e pinning

### 4.1 Origem permitida

Uma origem somente será permitida quando uma matriz futura, versionada e
aprovada registrar exatamente:

- produto e classe da dependência;
- URL HTTPS inicial, host, porta, path e nome do artefato;
- toda a cadeia esperada de redirects, com destino exato;
- versão imutável, sistema operacional e arquitetura;
- metadata de checksum/assinatura e sua origem independente;
- owner, data de aprovação e validade.

Redirecionamento, host, path, query, artefato ou protocolo não previsto DEVE
falhar antes de persistir ou interpretar o conteúdo. Certificado TLS inválido,
bypass de validação, transporte em texto claro, URL com credencial, branch, tag
mutável e alias como `latest` são proibidos por padrão. A única classe tipificada
que PODE tratar uma credencial efêmera de transporte é
`EPHEMERAL_PUBLIC_ASSET_REDIRECT`, exclusivamente quando todos os controles da
Section 4.1.1 e uma matriz concreta aprovada forem satisfeitos. Condição ausente,
ambígua ou expirada mantém `NOT_PROVEN / BLOCKED`.

#### 4.1.1 Perfil `EPHEMERAL_PUBLIC_ASSET_REDIRECT`

URL que contenha credencial humana, de workload ou de conta — incluindo userinfo,
cookie, header de autorização, secret, token fornecido pelo operador ou URL de
asset privado — NÃO DEVE ser usada. Uma `Location` assinada e efêmera emitida por
uma origem pública DEVE ser tratada como credencial temporária mesmo quando
conceder somente leitura de um asset público.

A captura e o consumo dessa `Location` PODEM ocorrer exclusivamente pelo perfil
cumulativo `EPHEMERAL_PUBLIC_ASSET_REDIRECT`. A ativação do perfil, isoladamente,
NÃO autoriza origem, produto, versão, asset, ferramenta, captura, rede ou
aquisição. Cada uso DEVE possuir matriz concreta versionada, gates humanos
próprios e todos os controles abaixo.

##### Elegibilidade cumulativa

Um uso do perfil DEVE satisfazer simultaneamente:

1. o asset é publicamente acessível sem login, cookie, `Authorization`, conta ou
   secret do operador, pertence a projeto open source e corresponde a release de
   versão exata;
2. produto, classe, versão, source revision imutável, licença SPDX, plataforma e
   filename estão fixados;
3. a URL HTTPS inicial, host, porta e path são literais; tag versionada é somente
   locator e DEVE estar ligada a source revision imutável, objeto de release e
   digest autenticado;
4. o HEAD autorizado produz exatamente um `302` e no máximo um hop; destino
   HTTPS, host, porta e path são literais por asset, sem wildcard, alias ou
   normalização permissiva;
5. o destino concede somente leitura de um objeto e não concede listagem,
   escrita, troca de asset ou acesso account-bound;
6. tamanho e SHA-256 esperados provêm de metadata separada e autenticada; a
   assinatura da URL NÃO DEVE ser tratada como checksum, assinatura do publisher,
   provenance ou elegibilidade do conteúdo;
7. o perfil é usado somente para bootstrap de verificador open source
   explicitamente enumerado. Provider, registry, módulo, imagem, asset privado,
   alias mutável e origem account-bound NÃO DEVEM usar este perfil.

##### Fluxo obrigatório

`Capture → Protect → Approve → Acquire → Verify → Retain/Cleanup` DEVE ser
sequencial. Nenhum estágio PODE herdar autorização, resultado ou credencial de
outra versão, asset, plataforma, tentativa ou refresh.

- **Capture:** o cliente DEVE executar HEAD TLS sem follow e sem body, com
  configuração global, proxy, netrc, cookies e credenciais herdadas desabilitados.
  Deve existir exatamente um status `302`, um `Date` e uma `Location`. Headers e
  Location DEVEM possuir limites de tamanho. A Location DEVE ser ASCII, sem
  CR/LF/NUL, fragmento ou userinfo, e corresponder exatamente ao scheme, host,
  porta e path aprovados. A query DEVE ser obrigatória, ter schema ordenado
  fechado, chaves únicas, valores não vazios, percent-encoding válido e
  invariantes aprovados. Campo extra, ausente, duplicado ou reordenado DEVE
  bloquear antes de qualquer GET.
- **Protect:** a representação canônica integral da Location NÃO DEVE aparecer
  em documentação, Git, stdout/stderr, telemetry, ambiente ou argv de processo
  externo. `sig`, `jwt` e equivalentes DEVEM permanecer secretos. A representação
  canônica DEVE existir apenas em storage externo dedicado e protegido, fora do
  repositório e do cache/mirror, em diretório `0700` e arquivo regular `0600`,
  owner esperado, no-clobber e sem symlink. Tamanho e SHA-256 DEVEM ser calculados
  antes e depois da persistência e coincidir. Somente hash, bytes, URL inicial,
  host/porta/path, schema, `Date`, expiry, owner e reviewers sanitizados PODEM ser
  versionados.
- **Approve:** `Date` DEVE vir do mesmo response; diferença para o relógio local
  NÃO DEVE exceder `300s`. O TTL total DEVE ficar entre `900s` e `7200s`.
  Segurança e Maintainer DEVEM aprovar individualmente o compromisso SHA-256 de
  cada Location antes do menor expiry. A aprovação DEVE expirar com a Location.
  Novo HEAD, refresh, hash diferente ou expiry DEVEM reiniciar Capture e Approve;
  refresh automático NÃO DEVE ocorrer.
- **Acquire:** imediatamente antes do GET, type, owner, mode, size e SHA-256 da
  Location, além de host, path, schema e TTL, DEVEM ser revalidados. Devem restar
  pelo menos `600s`. A URL DEVE ser entregue ao cliente por canal protegido de
  stdin/config que não permita injeção; NÃO DEVE ir em argv, ambiente ou log. O
  GET DEVE ser direto ao destino aprovado, com TLS, exatamente zero redirects,
  zero retry/fallback, proxy/netrc/cookies/credenciais herdadas desabilitados,
  timeout e limite de bytes. O destino DEVE ser arquivo novo `0600`, no-clobber,
  em cache de aquisição não confiável conforme a Section 7. Bytes NÃO DEVEM ser
  carregados, interpretados ou executados.
- **Verify:** o response DEVE ser HTTP `200`; tamanho e SHA-256 dos bytes DEVEM
  coincidir com os valores autenticados da matriz. Redirect adicional, resposta
  parcial, excesso de tamanho ou truncamento DEVEM bloquear. Sucesso de
  transporte permite no máximo `RECEIVED_UNVERIFIED`; assinatura, trust chain,
  tlog, revogação, provenance, licença, malware e advisories continuam
  obrigatórios e independentes.
- **Retain/Cleanup:** a credencial bruta DEVE ser invalidada logicamente ao
  concluir a tentativa ou expirar e removida somente em cleanup autorizado;
  apenas o compromisso sanitizado PODE permanecer. Bytes parciais, divergentes ou
  ainda não provados DEVEM permanecer em quarentena até disposição própria.
  Signed URL NÃO DEVE integrar mirror, manifesto de replay ou Git; somente
  conteúdo posteriormente verificado e selado poderá avançar.

##### Matriz concreta obrigatória

Antes de Capture, a matriz versionada DEVE registrar: profile revision;
produto/classe; versão/source revision/licença; plataforma/filename; URL inicial
completa sem credencial; status e hop count; destination scheme/host/porta/path
por asset; schema ordenado, invariantes e campos secretos da query; limites de
header/Location, clock skew e TTL; tamanho/SHA-256 esperado e origem autenticada
dessa metadata; cliente de aquisição e demais ferramentas com versão/digest/
licença/provenance; owner, Segurança, Maintainer, data e validade. Depois de
Capture/Approve, a matriz DEVE ligar cada asset ao tamanho e SHA-256 da Location
canônica sem registrar seus valores secretos.

##### Matriz de decisão fail-closed

| Condição | Resultado obrigatório | Efeito |
| --- | --- | --- |
| Autorização, matriz, ferramenta ou evidência ausente; timeout/erro; clock/TTL não provado; status/host/path/schema/permissão/compromisso divergente; redirect adicional; Location expirada. | `NOT_PROVEN / BLOCKED` | Não capturar novamente, não seguir, não adquirir e não aplicar fallback/retry automático. |
| Location, `sig` ou `jwt` exposto em log, argv, ambiente, Git ou storage não autorizado. | `FAIL / CREDENTIAL_COMPROMISED` | Invalidar a captura, bloquear GET, registrar incidente sanitizado e aguardar cleanup/disposição própria. |
| Origem ou asset comprovadamente trocado; resposta excedente/parcial usada; tamanho ou SHA-256 divergente. | `FAIL / QUARANTINE` | Interromper, não carregar/executar e isolar os bytes. |
| HEAD/captura parcial. | `NOT_PROVEN / BLOCKED` | Nenhuma Location do conjunto autoriza GET; retry exige gate e nova captura. |
| GET HTTP `200`, tamanho e SHA-256 coincidentes. | `RECEIVED_UNVERIFIED` | Permite somente controles posteriores já autorizados; não constitui `PASS`, allowlist, mirror ou elegibilidade. |

##### Limites de autoridade

Este perfil NÃO DEVE:

- criar allowlist por domínio, organização, CDN ou wildcard;
- autorizar genericamente GitHub, `release-assets.githubusercontent.com` ou
  qualquer outro host;
- herdar aprovação entre assets, versões, plataformas, queries, refreshes ou
  produtos;
- aceitar credencial do usuário, workload ou conta, asset privado,
  provider/registry, módulo ou imagem;
- permitir branch, `latest`, resolução automática, redirect adicional, fallback
  de host, retry ou refresh automático;
- substituir pinning, checksum autenticado, assinatura, provenance, revogação,
  tlog, licença, scans, quarentena, mirror ou gates de execução;
- tornar aplicável a rota `APPROVED_EXCEPTION` da Section 11 a qualquer controle
  deste perfil;
- validar retroativamente captura, Location ou bytes anteriores à versão Active
  e à matriz concreta aprovada.

A existência do perfil mantém a allowlist concreta vazia. Cada matriz e aquisição
continuam exigindo aprovação própria. Qualquer caso fora dos requisitos
cumulativos permanece sujeito à proibição geral de URL com credencial e DEVE
ficar `BLOCKED`.

Endereço lógico de provider não autoriza automaticamente o endpoint físico de
download. Registry, release host, CDN e mirror organizacional DEVEM aparecer como
trust boundaries distintas. Um cache local ou artefato fornecido offline somente
PODE ser origem de replay depois de ligado a aquisição e manifesto aprovados.

Este standard Active não contém entradas concretas de origem. Portanto, a
allowlist de artefatos/origens permanece deliberadamente vazia.
### 4.2 Pinning

Cada seleção futura deverá fixar simultaneamente:

- versão exata, sem intervalos, wildcard, canal ou resolução automática;
- plataforma exata, incluindo sistema operacional e arquitetura;
- identidade completa do provider, sem abreviação intercambiável entre
  registries ou engines;
- nome, tamanho e SHA-256 do arquivo efetivamente adquirido;
- digest do executável ou imagem efetivamente usada;
- validade temporal da aprovação.

Atualização automática, fallback de engine, substituição de plataforma ou
re-resolução silenciosa são proibidos. Qualquer alteração retorna ao fluxo de
seleção, verificação e aprovação desde o início.

## 5. Checksum, assinatura, provenance e lockfile

### 5.1 Integridade e autenticidade

A policy exige, cumulativamente:

1. SHA-256 do artefato calculado sobre os bytes exatos;
2. checksum esperado obtido de metadata autenticada e separada do próprio
   artefato;
3. assinatura ou atestação verificável da metadata/artefato;
4. fingerprint completa do signer, origem da chave, algoritmo, validade e
   verificação de revogação no instante da aquisição;
5. ferramenta de verificação pinada e registrada como dependência.

Checksum ou assinatura inválidos, signer divergente, bytes trocados ou metadata
inconsistente resultam em `FAIL`. Assinatura ausente, provenance não verificável,
status de revogação indisponível ou cadeia de confiança incompleta resultam em
`NOT_PROVEN`; não cabe desabilitação silenciosa.

Para OpenTofu, `OPENTOFU_ENFORCE_GPG_VALIDATION=true` deverá permanecer enforced
enquanto existir suporte na versão futuramente aprovada. Este texto não aprova
essa versão nem autoriza definir ou executar a variável.

### 5.2 Lockfile

O lockfile futuro deverá:

- ser gerado exclusivamente pela CLI pinada durante uma aquisição autorizada;
- cobrir todas as plataformas aprovadas e somente as seleções exatas;
- nunca ser criado ou alterado manualmente;
- ser revisado junto com o manifesto e ter seu próprio SHA-256 registrado;
- permanecer read-only no replay;
- ser rejeitado se divergir do digest/atestação aprovados, mesmo que o pacote
  também tenha sido adulterado de forma coerente.

Somente um gate futuro poderá decidir se lockfile e manifesto sanitizado serão
versionados. Binários, archives, cache, mirror e material de quarentena nunca são
candidatos ao Git.

## 6. Licenças, malware, advisories e cobertura de scanners

### 6.1 Allowlist de licenças open source

A allowlist ativa é:

- `Apache-2.0`;
- `BSD-2-Clause`;
- `BSD-3-Clause`;
- `ISC`;
- `MIT`;
- `MPL-2.0`.

O scanner deverá produzir identificador SPDX e evidência de cobertura para o
artefato e seus componentes. Em expressão `AND`, todas as licenças deverão estar
permitidas; em expressão `OR`, a alternativa efetivamente adotada deverá ser
registrada. Licença conhecida fora da allowlist, obrigação incompatível ou texto
divergente resulta em `FAIL`. Resultado `unknown`, `NOASSERTION`, ausência de
inventário ou conflito entre scanners resulta em `NOT_PROVEN`.

Essa allowlist define elegibilidade de licença, não aprova ferramenta, versão,
origem ou aquisição concreta.

### 6.2 Threshold para vulnerabilidades e advisories

Para cada CLI, provider, scanner, verificador, runtime e imagem:

- exploração conhecida/ativa, advisory crítico ou alto, ou CVSS base `>= 7.0`
  resulta em `FAIL`;
- advisory médio ou CVSS entre `4.0` e `6.9` resulta em `NOT_PROVEN` e bloqueia
  até decisão de exceção compatível com a Section 11;
- advisory baixo ou CVSS entre `0.1` e `3.9` deve ser registrado e somente não
  bloqueia quando não houver exploração conhecida, conflito de severidade ou
  precondição ausente;
- severidade/score ausente, componente não identificado, fonte não suportada ou
  divergência entre fontes resulta em `NOT_PROVEN`;
- quando fontes discordarem, prevalece a classificação mais restritiva.

A base de advisories deverá ter sido atualizada no máximo 24 horas antes do
selamento. O conjunto selado poderá ser usado em replay por no máximo sete dias,
ou menos se surgir revogação, incidente ou novo advisory conhecido. Expiração
retorna o artefato a `NOT_PROVEN`; não dispara atualização automática.

### 6.3 Cobertura mínima

| Domínio | Cobertura mínima | `FAIL` | `NOT_PROVEN` |
| --- | --- | --- | --- |
| Malware | Archive exato e conteúdo desempacotado, incluindo executáveis e scripts. | Qualquer detecção positiva confirmada. | Tipo não suportado, exclusão, erro, timeout ou parte não inspecionada. |
| Licença | Artefato, componentes, notices e expressão SPDX. | Licença conhecida fora da allowlist ou obrigação incompatível. | Componente/termo desconhecido, inventário incompleto ou scanner sem suporte. |
| CVE/advisory | Produto, versão, plataforma, componentes e banco dentro da freshness definida. | Exploração conhecida, severidade alta/crítica ou CVSS `>= 7.0`. | Cobertura parcial, banco stale, score desconhecido, erro ou severidade média sem disposição. |
| Configuração | Futuras fixture, configuração CLI, mirror e especificação de sandbox, quando existirem. | Controle proibido observado, como fallback de rede, backend ou secret. | Material exigível ausente, regra não suportada ou análise incompleta. |

O scanner deverá registrar versão, digest, configuração, banco/regras, timestamps,
arquivos inspecionados, exclusões, exit code e resultado. Exclusões silenciosas,
truncamento de output, erro tratado como sucesso ou scanner não compatível com o
formato impedem `PASS`.

## 7. Cache, mirror e selamento

O fluxo obrigatório separa três estados:

1. **cache de aquisição não confiável:** recebe bytes, nunca é usado para carga;
2. **quarentena:** recebe todo conteúdo `FAIL` ou `NOT_PROVEN`;
3. **mirror selado:** recebe somente conteúdo `PASS` ou conteúdo com disposição
   `APPROVED_EXCEPTION` válida, com manifesto e digests aprovados.

Cache e mirror deverão ser efêmeros, dedicados ao POC, fora do repositório e do
home real do operador. Cache global de plugin, reaproveitamento entre execuções,
mount gravável no replay e resolução direta são proibidos.

O mirror deverá preservar os archives oficiais em formato packed, ser
imutável/read-only durante o replay e estar ligado a:

- SHA-256 de cada archive;
- digest do inventário completo, lockfile e manifesto;
- plataforma e identidades aprovadas;
- resultados de integridade, assinatura, licença, malware e advisories;
- revisão/atestação humana e validade.

Diferença de tamanho, path, arquivo, digest, permissão ou inventário entre o
selamento e o replay resulta em `FAIL` antes da carga do provider.

## 8. Manifesto de provenance

O manifesto sanitizado futuro deverá registrar, por dependência:

- classe, produto, versão, plataforma e identidade completa;
- URL inicial e cadeia de redirects aprovada;
- arquivo, tamanho, SHA-256 e digest do executável/imagem;
- origem do checksum, assinatura/atestação, signer e fingerprint;
- ferramenta e resultado de verificação;
- licença/SPDX e notices aplicáveis;
- scanners, versões, digests, bases/regras, timestamps, cobertura e resultados;
- advisory IDs, severidade máxima e disposição;
- digest do lockfile, inventário e mirror;
- instante de aquisição/selamento, reviewers, validade e eventual exceção.

O manifesto não poderá conter token, header, variável de ambiente, path sensível
do host, payload bruto ou log de provider. Evidência ausente ou inconsistente
mantém `NOT_PROVEN`.

## 9. Operação offline

Replay somente poderá consumir mirror previamente selado e deverá ocorrer com:

- egress e DNS negados pelo mecanismo de isolamento;
- nenhuma rota `direct`, atualização, re-resolução ou fallback de rede;
- lockfile read-only e backend desabilitado;
- ambiente criado do zero, sem credencial, proxy, home real ou configuração
  global;
- filesystem mínimo e mirror read-only;
- allowlist própria de executável, digest, `argv`, cwd, paths, ambiente e timeout,
  distinta da aquisição;
- validação do selo antes de interpretar a fixture ou carregar qualquer plugin.

Erro de resolução offline deverá falhar fechado; não autoriza rede, novo mirror,
troca de engine ou redução de controle. A forma exata dos comandos pertence a um
IP futuro, específico e aprovado. Este standard não define nem autoriza `argv`
ou execução.

## 10. Quarentena e cleanup

Todo artefato `FAIL` ou `NOT_PROVEN` deverá ser isolado antes de carga ou execução.
O mecanismo futuro de quarentena deverá:

- usar path dedicado fora do repositório, do mirror e do home real;
- negar execução, compartilhamento, promoção automática e reutilização
  automática;
- liberar para promoção somente a cópia exata coberta por uma disposição
  `APPROVED_EXCEPTION` válida, após revalidar SHA-256 e todos os controles
  compensatórios, sem apagar o resultado técnico original;
- preservar apenas metadata sanitizada suficiente para investigação;
- impedir que retry leia os mesmos bytes sem nova decisão;
- remover os bytes ao final, salvo retenção forense explicitamente autorizada,
  com owner, acesso mínimo, criptografia, prazo e descarte definidos.

Se isolamento ou cleanup não puder ser provado, a aquisição permanece
`NOT_PROVEN` e o conteúdo não entra no mirror.

## 11. Exceções

Uma exceção futura exigirá aceite conjunto de Segurança e Maintainer Humano e
deverá registrar:

- controle e resultado subjacente, que não são reescritos como `PASS`;
- dependência, versão, plataforma, origem e SHA-256 exatos;
- justificativa, impacto, compensações, owner e aprovadores;
- escopo exclusivo do POC e proibição de herança para HML/PRD;
- expiração em até 30 dias ou no encerramento do POC, o que ocorrer primeiro;
- condição de revogação e evidência de cleanup.

Somente outra licença comprovadamente open source, com texto e obrigações
verificados, mas fora da allowlist, ou advisory médio plenamente identificado
poderá ser candidato a exceção neste baseline. Obrigação incompatível, texto de
licença divergente ou não verificado, ferramenta proprietária, fechada ou apenas
source-available exigem revisão desta policy e novo gate, não uma exceção
operacional. Não são excepcionáveis:

- malware detectado;
- checksum/assinatura inválidos ou bytes divergentes;
- origem, versão, plataforma ou signer desconhecidos/mutáveis;
- ausência de provenance ou cobertura mínima;
- exploração conhecida, advisory crítico/alto ou CVSS `>= 7.0`;
- segredo, egress, backend/state ou efeito externo observado;
- falha de quarentena, selamento ou cleanup.

Uma exceção aprovada:

- mantém o resultado técnico original e recebe disposição separada
  `APPROVED_EXCEPTION`;
- permite promoção ao mirror somente do artefato, versão, plataforma e SHA-256
  exatos, após validação dos controles compensatórios;
- deve constar do selo e do manifesto, com owner, aprovadores e expiração;
- ao atingir o prazo ou trigger de revogação, invalida o consumo lógico daquele
  selo e retorna o artefato a `BLOCKED`; o mirror imutável anterior não é mutado,
  e qualquer uso posterior exige nova decisão, revalidação e novo selo.

Não existe exceção aprovada. Uma exceção de supply chain também não substitui os
gates de aquisição e replay.

## 12. Evidência, revisão e rastreabilidade

Cada decisão futura deverá ligar o manifesto e os resultados a:

- [ADR-0033](../../../backend/docs/adrs/ADR-0033-arquitetura-alvo-iac-segura.md);
- [REQ-00044](../../product/requirements/REQ-00044-infrastructure-iac-hermetic-poc.md),
  especialmente `AC-002`–`004`, `AC-011` e `AC-014`;
- ANL-00044,
  especialmente `G3-GAP-002` e `L-007`;
- [TP-00017](../../specs/TP-00017-infrastructure-iac-hermetic-poc.md),
  como ciclo encerrado e fonte do registro append-only; eventual sucessor deverá
  reaplicar `TP-C02`–`C04` e gates equivalentes;
- [TP-00018](../../specs/TP-00018-opentofu-offline-manifest-correction.md),
  como evidência sucessora limitada de um único intake OpenTofu, encerrado
  `Artifact Not Eligible`; seus `PASS` de integridade e leaf binding não
  constituem provenance integral, allowlist ou autorização operacional;
- `SEC-021` do
  [RPT-0004](../../delivery/reports/RPT-0004-frontend-backend-cibersecurity.md).

Reviewers deverão ser identificados por pessoa ou alçada, papel, decisão, data e
validade. A mera menção a um owner funcional não prova representação ou aceite.

## 13. Ativação registrada e boundary seguinte

O `G3.6.2-F` aprovou cumulativamente:

1. os controles de origem, pinning, licença, integridade, scanners, freshness,
   mirror, provenance, quarentena, offline e exceções;
2. o baseline open-source-first da Section 2.1, com elegibilidade inicial
   restrita a open source;
3. a promoção explícita `Draft → Active`;
4. o encerramento separado de `L-007` somente quanto à policy versionada e
   aprovada;
5. a conclusão de `G3.6.2`, sem efeito operacional.

O ciclo do TP-00017 foi encerrado em 2026-08-25 como `Cancelled — Controlled
Administrative Closure`. O TP-00018 sucessor foi encerrado em 2026-08-26 como
`Completed — Review Concluded / Artifact Not Eligible`. Neste sucessor, pesquisa
read-only em fontes oficiais e avaliação offline limitada ocorreram somente sob
gates próprios; um único artefato OpenTofu ganhou evidência parcial, sem atingir
conformidade integral.

O TP-00025 iniciou um ciclo sucessor próprio. Sob gates explícitos, recebeu quinze
arquivos TUF ainda não verificados, consultou metadata Rekor e capturou externamente
seis Locations Cosign comprometidas por SHA-256. Nenhum asset Cosign foi adquirido,
as Locations expiraram e não possuem grandfathering. Trust/provenance, licença,
libc, scanners e elegibilidade continuam `NOT_PROVEN`.

Em 2026-08-28, `G25.3-A-REDIRECT-POLICY-ACTIVATION` aprovou
`EAR-DRAFT-001` como texto normativo exato. O Maintainer representou sua alçada e
delegou Segurança e DevOps somente até este handoff. Após controle de drift
`PASS / NO MATERIAL DRIFT`, o conteúdo literal da seção 4.14.1 do TP-00025
substituiu integralmente a Section 4.1; a emenda passou de `Draft` a incorporada
ao standard já `Active`, versionado atomicamente de v1.2 para v1.3, sem intervalo
de desativação.

A ativação torna normativo apenas o perfil condicional
`EPHEMERAL_PUBLIC_ASSET_REDIRECT`. Ela não aprova origem, produto, versão, asset,
matriz concreta, Location anterior, captura, rede, HEAD, recaptura, GET, download,
instalação, execução, provider, registry, ambiente, IP-INFRA, `infra/iac/` ou
allowlist. A Section 11 não oferece waiver aos controles desse perfil. A allowlist
concreta permanece vazia e toda operação continua fail-closed.

O TP-00025 permanece `In Progress`. A fronteira seguinte é preparar, em gate
documental separado, uma matriz concreta candidata para os seis assets Cosign;
essa preparação não herda autoridade deste gate e não autoriza recaptura ou GET.
As delegações de Segurança e DevOps expiram neste handoff.

## 14. Matriz de controles ativa

| Fonte | Controle deste standard | Estado atual |
| --- | --- | --- |
| REQ-00044 `AC-002` | Identidade, versão, origem, plataforma, hash e signer. | TP-00018 produziu evidência parcial para OpenTofu `1.12.6`; o TP-00025 adicionou metadata ainda não verificada. Trust/provenance, licença completa, libc, scanners, dependências restantes e elegibilidade continuam `NOT_PROVEN`. |
| REQ-00044 `AC-003` | Lockfile gerado, revisado, selado e read-only. | Normativo; lockfile não existe. |
| REQ-00044 `AC-004` | Aquisição e replay como trust boundaries distintas. | O TP-00025 adquiriu somente quinze arquivos TUF sob gate próprio; nenhum asset Cosign foi adquirido e replay permanece bloqueado. Toda aquisição futura exige gate próprio. |
| REQ-00044 `AC-011` | Licenças, malware, advisories, thresholds, cobertura e exceções. | `PASS` documental em G3.6.2-F; não comprova artefato. |
| REQ-00044 `AC-014` | Allowlists distintas de execução. | Somente princípio; detalhes dependem de IP futuro em ciclo autorizado. |
| ANL-00044 `L-007` | Policy versionada anterior à aquisição. | `Closed — G3.6.2-F`, somente no boundary da policy. |
| TP-00017 `TP-C02`–`C04` | Fail-closed, provenance, mirror e handoff selado. | Ciclo Cancelled; controles continuam normativos para sucessor e, naquele ciclo, artefatos/evidências permaneceram inexistentes. |
| TP-00018 `G18.3`–`G18.5` | Aplicação limitada de integridade, autenticidade e decisão fail-closed. | `Completed / Artifact Not Eligible`; integridade/leaf binding `PASS`, demais controles relevantes `NOT_PROVEN`, allowlist vazia. |
| TP-00025 `EAR-001`–`EAR-012` | Perfil cumulativo para redirect efêmero assinado de asset público. | `Active` somente como regra condicional da v1.3; nenhuma matriz/origem/Location/GET foi aprovada, as Locations anteriores expiraram, a allowlist está vazia e o artefato permanece `NOT_PROVEN`. |

## 15. Change Log

| Version | Date | Owner | Change |
| --- | --- | --- | --- |
| 1.3 | 2026-08-28 | Maintainer Humano / Segurança e DevOps sob delegação temporária | Incorpora literalmente `EAR-DRAFT-001` à Section 4.1 como perfil `EPHEMERAL_PUBLIC_ASSET_REDIRECT`, sem intervalo de desativação; mantém a proibição geral como default, rejeita retroatividade e não aprova origem, matriz concreta, rede, GET, download, allowlist ou execução. |
| 1.2 | 2026-08-27 | Segurança e DevOps | Adiciona somente a ponte de evidência para o TP-00018, registrando pesquisa oficial read-only e avaliação offline sob gates próprios, resultado `Artifact Not Eligible` e allowlist vazia; nenhuma regra normativa, threshold ou autorização operacional foi alterada. |
| 1.1 | 2026-08-25 | Maintainer Humano / AgentOrchestrator sob mandato terminal | Atualiza somente o contexto de lifecycle: TP-00017 Cancelled, dependências Deferred/NOT_PROVEN, nenhuma ação ativa e reaplicação integral em ciclo sucessor; controles, L-007 e allowlist vazia permanecem inalterados. |
| 1.0 | 2026-08-24 | Maintainer Humano, com revisões técnicas de Segurança e DevOps | Registra G3.6.2-F, adota baseline open-source-first com elegibilidade inicial somente open source, promove Draft para Active e fecha L-007 somente quanto à policy aprovada, sem autorizar seleção, aquisição ou execução. |
| 0.1 | 2026-08-24 | Segurança / DevOps sob delegação temporária do Maintainer | Cria o Draft não normativo autorizado em G3.6.2-E, com allowlist efetiva vazia, controles candidatos fail-closed e ativação humana separada; não fecha L-007 nem autoriza aquisição ou execução. |
