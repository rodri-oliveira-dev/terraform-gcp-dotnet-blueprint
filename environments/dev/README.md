# Ambiente de desenvolvimento

Este root compõe os módulos reutilizáveis no ambiente completo de desenvolvimento.

Ele usa sizing e thresholds de observabilidade orientados a desenvolvimento, preservando os mesmos limites arquiteturais de produção.

## O que este root cria

Recursos de fundação são sempre declarados:

- APIs Google Cloud necessárias, incluindo Cloud Monitoring, sem desabilitar APIs compartilhadas no destroy;
- uma VPC em modo customizado, subnet de workloads e conexão Private Service Access;
- uma instância Memorystore for Redis usando `PRIVATE_SERVICE_ACCESS`, Redis AUTH e TLS;
- service accounts de runtime separadas para API, worker Pub/Sub e batch;
- identidades de transporte separadas para Pub/Sub push e Cloud Scheduler;
- metadados do Secret Manager e IAM de accessor no escopo de cada segredo para configuração dos workloads, Redis AUTH e server CA do Redis.

Quando `enable_workloads = true`, o root também cria:

- API Cloud Run privada/autenticada;
- worker Cloud Run privado/autenticado;
- tópico/subscription Pub/Sub, política de retry, tópico dead-letter e entrega push autenticada;
- `roles/pubsub.publisher` para a identidade de runtime da API somente no tópico da aplicação;
- Cloud Run Job finito;
- job Cloud Scheduler que invoca a Cloud Run Admin API com identidade dedicada de trigger;
- grants `roles/run.invoker` no escopo de recurso para identidades Pub/Sub e Scheduler;
- políticas de alerta do Cloud Monitoring para taxa 5xx do Cloud Run, backlog/DLQ do Pub/Sub, execuções batch com falha e pressão/conexões rejeitadas do Redis.

Os três workloads usam Direct VPC egress para acessar Redis. Nenhum Serverless VPC Access connector é criado.

## Por que o deployment é intencionalmente dividido em duas fases

O repositório mantém payloads de segredos da aplicação fora do Terraform. Memorystore também gera sua Redis AUTH string e server CA TLS depois que a instância existe. Cloud Run, por outro lado, exige que as versões Secret Manager referenciadas existam quando uma revision é implantada.

Para evitar `terraform -target` como workflow normal, este root usa `enable_workloads`:

1. **Fase de fundação** — mantenha `enable_workloads = false`. Terraform pode criar APIs, rede, Redis, identidades, containers de segredos e IAM sem criar workloads Cloud Run que referenciem versões inexistentes.
2. **Bootstrap de segredos** — operador ou processo de entrega confiável cria versões para cada segredo reportado pelo output `secret_bootstrap`. Material Redis AUTH e CA deve ser recuperado do Memorystore e transferido sem registrar nem commitar payloads.
3. **Fase de workloads** — defina `enable_workloads = true`, revise o plan e aplique. Cloud Run services/job, entrega Pub/Sub, Scheduler e políticas de alerta são então criados usando versões existentes dos segredos.

Terraform nunca recebe esses payloads de segredos como variables ou outputs. Depois que a ativação dos workloads foi aplicada neste state, mudar `enable_workloads` de volta para false é intencionalmente rejeitado pelo activation lock.

## Observabilidade

Desenvolvimento usa o mesmo conjunto de sinais de produção, com padrões mais tolerantes:

- taxa HTTP 5xx do Cloud Run: 10%;
- mensagem Pub/Sub não confirmada mais antiga: 600 segundos;
- uso de memória de dados e sistema do Redis: 90%;
- qualquer encaminhamento para dead-letter, execução de Cloud Run Job com falha ou conexão Redis rejeitada permanece alertável.

`observability_notification_channels` aceita somente nomes de recursos de canais de notificação existentes no Cloud Monitoring. Destinos dos canais e sua configuração sensível ficam fora deste state. Um conjunto vazio cria políticas de alerta sem destinos de notificação.

Consulte `../../docs/observability.md` para expectativas de logging estruturado, orientação SLI/SLO, ownership de telemetria e justificativa para não criar dashboard genérico.

## State remoto

O backend usa prefixo fixo específico do ambiente:

```hcl
prefix = "environments/dev"
```

O bucket de state é fornecido na inicialização em vez de ficar hard-coded:

```bash
terraform init \
  -backend-config="bucket=YOUR_TERRAFORM_STATE_BUCKET"
```

Para validação sem acesso ao backend:

```bash
terraform init -backend=false
terraform validate
```

## Configuração

Copie o arquivo de exemplo localmente e mantenha o arquivo real fora do commit:

```bash
cp terraform.tfvars.example terraform.tfvars
```

No mínimo, substitua placeholders de projeto/imagem e revise CIDRs, labels de ownership, thresholds de alerta e nomes opcionais de recursos de canais de notificação.

O ambiente de desenvolvimento usa intencionalmente uma instância Redis `BASIC` de 1 GiB para reduzir custo mantendo AUTH e TLS.

## Limites de segurança

- A API **não é pública**. Este root não concede `allUsers` nem cria external load balancer/API gateway.
- API, worker e batch usam identidades de runtime diferentes.
- Pub/Sub push e Cloud Scheduler usam identidades de transporte diferentes dos workloads que invocam.
- Acesso a segredos é concedido no escopo de cada segredo.
- A API recebe permissão de publisher somente no tópico Pub/Sub da aplicação.
- Destinos de canais de notificação não são armazenados nesta configuração de ambiente.
- Payloads de Redis AUTH e CA não são outputs Terraform.
- State Terraform permanece sensível porque providers podem persistir atributos sensíveis calculados. Use o bucket GCS protegido criado por `bootstrap/state`.
- `terraform apply` e população de segredos são ações controladas pelo operador; CI de pull request permanece sem credenciais.

## Versões de segredos esperadas

Após a fase de fundação, inspecione `terraform output secret_bootstrap` e crie uma versão atual para cada secret ID retornado. O formato exato do payload é contrato da aplicação e permanece intencionalmente fora deste repositório de infraestrutura.

## Validação

O CI do repositório inicializa este root com `-backend=false`, usa o provider lock file commitado e executa gates Terraform format/validate/test, TFLint e Trivy. Nenhuma etapa de CI deve criar recursos Google Cloud com custo.
