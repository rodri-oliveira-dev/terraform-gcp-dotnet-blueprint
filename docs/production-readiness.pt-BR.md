# Guia de prontidão para produção

Este documento é o ponto de entrada orientado a operadores para adoção do blueprint. Ele consolida ordem de ciclo de vida, política de ambientes, limites de segurança, expectativas de recovery, limitações conhecidas e critérios de prontidão de release sem duplicar contratos de baixo nível dos módulos.

## O que significa estar pronto para produção aqui

O repositório é **orientado a produção**, não prescritivo para produção. O baseline v1.0 demonstra composição segura, controles de entrega e limites operacionais que podem ser adaptados a um workload real. Ele não comprova que capacidade padrão, SLOs, desenho de edge público ou modelo IAM da organização sejam adequados a todo sistema de produção.

Antes de adotar o blueprint, trate cada padrão como um ponto inicial a ser revisado, e não como recomendação implícita.

## Passo a passo do zero até um ambiente

### 1. Prepare os projetos Google Cloud e o modelo de ownership

Decida quais projetos são responsáveis por:

- bucket de state Terraform;
- Workload Identity Federation e service account de deployment;
- infraestrutura de `dev`;
- infraestrutura de `prod`.

Eles podem ser o mesmo projeto em um deployment pequeno de referência ou projetos separados em uma organização mais rígida. Quando forem diferentes, conceda acesso à service account de deployment separadamente em cada limite de recurso/projeto.

Revise a região padrão `us-central1`, os CIDRs de subnet/PSA e as políticas organizacionais antes de qualquer apply.

### 2. Faça o bootstrap do state remoto

Use `bootstrap/state` com uma credencial de operador. O root começa deliberadamente com state local.

```bash
cd bootstrap/state
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform fmt -check
terraform validate
terraform plan
```

Aplique somente após revisão. Preserve com segurança o state local do bootstrap. O bucket resultante usa object versioning, uniform bucket-level access, prevenção de acesso público, `force_destroy = false` e `prevent_destroy` do Terraform.

Consulte `bootstrap/state/README.md`.

### 3. Faça o bootstrap do WIF para GitHub Actions

Use `bootstrap/github-actions-wif` com o backend GCS protegido. Valide os IDs imutáveis do owner/repositório GitHub e a ref permitida (`refs/heads/main` por padrão).

O bootstrap cria pool/provider WIF, service account dedicada de deployment e relação de impersonation. Ele não cria chave de service account nem concede acesso amplo aos projetos de workload por padrão.

Após o apply, configure as variáveis de repositório documentadas em `docs/terraform-deployment.md`.

Execute manualmente `gcp-auth-smoke.yml` a partir da `main` para comprovar OIDC -> WIF -> impersonation da service account antes de depender de workflows Terraform autenticados.

### 4. Configure o IAM de deployment deliberadamente

A identidade de deployment precisa das permissões para as capacidades que gerencia, além de acesso a objetos no bucket de state. Use o mapa de capacidades em `docs/terraform-deployment.md` como ponto de partida.

Não conceda `roles/owner` ou `roles/editor` apenas para fazer o Terraform funcionar. Prefira grants no escopo de recurso quando o serviço permitir e derive custom roles quando controles organizacionais exigirem um conjunto mais restrito de permissões.

### 5. Configure GitHub Environments e variáveis do repositório

Crie GitHub Environments chamados `dev` e `prod`. `prod` deve usar Required Reviewers e, quando a governança permitir, Prevent self-review.

Configure variáveis do repositório para:

- nome completo do recurso do provider WIF;
- service account de deployment;
- bucket de state;
- project IDs de dev/prod;
- URIs das imagens API/worker/batch por ambiente;
- valores explícitos de `TF_<ENV>_ENABLE_WORKLOADS`.

Não coloque segredos da aplicação, Redis AUTH ou payloads de CA nas variáveis do repositório.

### 6. Faça plan e apply da fundação do ambiente

Comece com `TF_<ENV>_ENABLE_WORKLOADS=false`.

A fundação cria declarações para habilitar serviços necessários, VPC/subnet, Private Service Access, Redis, identidades de workload/transporte, containers do Secret Manager e IAM com escopo. Ela deliberadamente não cria workloads que referenciem versões de segredos ainda inexistentes.

Use o workflow manual `Terraform plan` para revisar o plan do backend/provider real. Use `Terraform apply` somente após autorização explícita.

### 7. Popule versões dos segredos externamente

Inspecione o output `secret_bootstrap` e crie versões atuais para configurações específicas de aplicação do ambiente, Redis AUTH e segredos de Redis CA por meio de um processo confiável.

Terraform é responsável pelos containers e pela política de acesso dos segredos, **não pela criação ou rotação dos payloads**. Nunca encaminhe esses payloads por variáveis Terraform, variáveis do repositório GitHub, logs de PR ou artifacts de plan.

### 8. Ative os workloads

Altere a variável do ambiente selecionado para `TF_<ENV>_ENABLE_WORKLOADS=true`, revise um novo plan e use o workflow de apply controlado.

Essa transição é intencionalmente unidirecional para um determinado state. Depois que a ativação tiver sido aplicada como `true`, o activation lock rejeita a reversão para `false` antes que o Terraform possa desmontar parcialmente recursos de mensageria/trigger/IAM e depois parar nos recursos Cloud Run protegidos.

### 9. Verifique a observabilidade e ajuste a política

Quando os workloads estão ativos, o ambiente compõe o baseline de alertas do Cloud Monitoring. Configure nomes de recursos de canais de notificação existentes quando notificações forem desejadas.

Trate os thresholds fornecidos como pontos iniciais operacionais, não como SLOs. Ajuste-os usando tráfego observado, capacidade e histórico de incidentes. Times de aplicação devem configurar separadamente semântica de logging/tracing estruturado e redaction de dados sensíveis.

### 10. Execute a validação em GCP real deliberadamente

CI offline não é evidência de compatibilidade real com backend/APIs. Siga `docs/gcp-integration-validation.md` e registre um plan manual de desenvolvimento bem-sucedido a partir da `main` antes de afirmar validação de plan em GCP real.

Um plan ainda não comprova execução em runtime, entrega de mensagens, conectividade do cliente Redis ou comportamento das notificações de alerta.

## Política dev versus prod

| Política | dev | prod |
| --- | --- | --- |
| Prefixo de state | `environments/dev` | `environments/prod` |
| Subnet de workload padrão | `10.40.0.0/24` | `10.60.0.0/24` |
| PSA padrão | `10.50.0.0/16` | `10.70.0.0/16` |
| Redis | `BASIC`, 1 GiB | `STANDARD_HA`, 5 GiB padrão |
| API | 1 vCPU / 512 MiB, min 0, max 2 | 2 vCPU / 1 GiB, min 1, max 20 |
| Worker | 1 vCPU / 512 MiB, min 0, max 2 | 1 vCPU / 1 GiB, min 1, max 20 |
| Tentativas DLQ Pub/Sub | 10 | 20 |
| Batch | 1 task / parallelism 1 / 1 vCPU / 512 MiB | 4 tasks / parallelism 2 / 2 vCPU / 2 GiB |
| Retries do Scheduler | 3 | 5 |
| Alerta 5xx Cloud Run | 10% | 5% |
| Idade da mensagem Pub/Sub não confirmada mais antiga | 600s | 300s |
| Thresholds de memória Redis | 90% | 80% |

Esses valores são referências. A adoção em produção exige testes de capacidade e objetivos de confiabilidade específicos do produto.

## Limites de IAM

A arquitetura separa identidades por propósito:

- runtime da API;
- runtime do worker;
- runtime do batch;
- transporte Pub/Sub push;
- trigger do Scheduler;
- deployment via GitHub Actions.

Módulos de identidade de runtime não concedem roles genéricas de projeto. A API recebe permissão de publisher apenas para seu tópico de aplicação. Grants de secret accessor são aplicados por segredo. Grants de invocação usam escopo de recurso quando suportado.

Revise todas as permissões de deployment no nível de projeto separadamente do IAM de runtime. Um deployer Terraform poderoso não é motivo para tornar poderosas as identidades de runtime.

## Recovery de state

Trate recovery de state como procedimento de incidente.

1. Interrompa deployments do ambiente afetado.
2. Preserve o objeto/geração atual do state para investigação.
3. Identifique a última geração conhecida como boa no GCS e o commit Git correspondente.
4. Determine se o problema é corrupção de state, drift de configuração ou mudança legítima de infraestrutura.
5. Restaure uma geração anterior somente depois de confirmar que ela representa o state pretendido.
6. Execute `terraform plan` antes de qualquer apply e investigue ações inesperadas de create/delete/replacement.
7. Não automatize `force-unlock`, `state rm`, restauração de state ou imports em CI genérico.

Object versioning fornece histórico de recovery; ele não elimina a necessidade de julgamento do operador.

## Proteção contra exclusão

Diversos caminhos destrutivos são intencionalmente protegidos:

- o bucket de state possui `prevent_destroy` do Terraform e `force_destroy = false`;
- Cloud Run e Redis usam proteção contra exclusão no provider por padrão;
- ativação dos workloads usa um lock Terraform com `prevent_destroy`;
- o workflow de apply bloqueia ações de delete/replacement a menos que `allow_destroy=true` seja selecionado explicitamente.

Uma exclusão intencional, portanto, exige mudanças explícitas de configuração e um plan revisado. Não remova múltiplas camadas de proteção em uma única mudança sem revisão.

## Ownership de segredos

Terraform pode persistir no state valores sensíveis calculados pelo provider mesmo quando outputs não os expõem. Por isso:

- acesso ao state remoto é sensível;
- payloads/versões de segredos são gerenciados fora do Terraform;
- material de Redis AUTH e CA não é output;
- variáveis GitHub contêm apenas identificadores/configuração;
- logging da aplicação não deve emitir payloads do Secret Manager, authorization headers, cookies ou credenciais Redis.

## Limitações conhecidas e não objetivos deliberados

O baseline v1.0 deixa intencionalmente para quem o adota:

- arquitetura de ingress/edge público (external load balancer, API Gateway, Cloud Armor, DNS, certificados);
- pipelines de build/release dos containers e código real de negócio .NET;
- bancos relacionais e workflows de migração de banco;
- políticas de organization/folder, governança de billing e integração com rede corporativa;
- Cloud NAT/arquitetura geral de saída para internet;
- automação de criação/rotação de payloads de segredos;
- metas de SLO específicas de workload e políticas de burn-rate;
- dashboards customizados genéricos sem pergunta operacional;
- testes de carga/performance/chaos;
- verificação em runtime de entrega Pub/Sub, execução batch, AUTH/TLS do cliente Redis ou entrega de notificações de alerta;
- rollback automático, manipulação de state ou workflows de destroy;
- recomendações de capacidade para produção.

## Checklist de adoção

Antes de reutilizar este repositório em outro projeto/organização:

- [ ] Substitua os IDs imutáveis de owner/repositório GitHub no bootstrap WIF.
- [ ] Revise a Git ref permitida e as regras de proteção do repositório/ambiente.
- [ ] Escolha os limites de projeto para state, WIF, dev e prod.
- [ ] Escolha um bucket de state globalmente único e revise o IAM do bucket.
- [ ] Revise região, CIDRs das subnets e ranges PSA em relação às rotas existentes.
- [ ] Revise todas as permissões IAM do deployment; não use roles básicas Owner/Editor.
- [ ] Substitua variáveis de imagem por imagens controladas do Artifact Registry/registry.
- [ ] Defina como versões de payloads dos segredos serão criadas e rotacionadas fora do Terraform.
- [ ] Defina quem pode recuperar/distribuir material de Redis AUTH e CA.
- [ ] Revise requisitos de ingress público; não presuma que a API é acessível pela internet.
- [ ] Revise sizing e scaling de `dev`/`prod` de acordo com a demanda do workload.
- [ ] Revise configurações de retry/DLQ do Pub/Sub de acordo com a semântica das mensagens.
- [ ] Revise task count/parallelism/retries do batch de acordo com idempotência.
- [ ] Configure canais de notificação fora deste state quando necessário.
- [ ] Defina SLIs/SLOs reais a partir dos requisitos de produto, em vez de copiar thresholds de alerta.
- [ ] Configure proteção de GitHub Environment para produção.
- [ ] Valide WIF com o workflow de smoke a partir da `main`.
- [ ] Conclua a validação do plan de `dev` em GCP real e retenha a evidência.
- [ ] Estabeleça ownership para recovery de state e pratique o procedimento antes de um incidente real.
- [ ] Documente extensões arquiteturais como mudanças/ADRs separadas e revisadas.

## Checklist de prontidão da release v1.0.0

O repositório pode receber a tag `v1.0.0` somente após revisão humana confirmar:

- [ ] README descreve a arquitetura implementada e não contém linguagem obsoleta de roadmap/status.
- [ ] Documentos de arquitetura, ambiente, deployment, observabilidade e validação de integração estão coerentes com o código.
- [ ] Recovery de state, proteção contra exclusão e ownership de segredos estão documentados.
- [ ] Troubleshooting cobre os principais domínios de falha de backend/WIF/provider/rede/compute/mensageria/cache/monitoring.
- [ ] Limitações conhecidas/não objetivos estão explícitos.
- [ ] Checklist de adoção está completo e compreensível sem contexto do histórico do repositório.
- [ ] `CHANGELOG.md` e `docs/releases/v1.0.0.md` foram revisados.
- [ ] A `main` atual passa format, validate, test, TFLint e Trivy.
- [ ] Nenhuma thread de review não resolvida permanece dos PRs de fechamento do roadmap.
- [ ] A issue #29 contém evidência bem-sucedida de plan em GCP real ou a release está explicitamente marcada como ainda não validada por plan em GCP real.
- [ ] Nenhum state, `.tfvars` real, artifact de plan, credencial ou payload de segredo foi commitado.
- [ ] Nenhum `terraform apply`/`destroy` foi executado apenas para preparar documentação de release.

O checklist prepara a release; ele não cria tag nem GitHub Release automaticamente.
