# Exemplo de worker Pub/Sub push

Este root demonstra isoladamente o padrão de worker orientado a eventos:

```text
Publisher
   |
   v
Tópico Pub/Sub
   |
   v
Push subscription autenticada
   |
   v
Cloud Run Service (worker .NET)
   |
   +--> sucesso: HTTP 2xx confirma a mensagem
   |
   +--> falha repetida: tópico dead-letter --> subscription de inspeção
```

O alvo é deliberadamente um **Cloud Run Service**, não Cloud Run Job. Entrega push do Pub/Sub exige endpoint HTTP que atenda requisições; execução batch finita é modelada separadamente com o padrão Cloud Run Job/Scheduler.

## Separação de identidades

O exemplo exige duas service accounts existentes gerenciadas pelo usuário:

- `worker_runtime_service_account` é anexada à revision Cloud Run e representa o código da aplicação em runtime;
- `push_service_account` é usada pelo Pub/Sub para autenticar requests push e recebe somente `roles/run.invoker` neste worker.

O módulo Pub/Sub usa separadamente o service agent do Pub/Sub gerenciado pelo Google para criação de tokens OIDC e encaminhamento dead-letter. Esse service agent recebe somente as permissões no escopo dos recursos necessárias às operações de transporte.

## Pré-requisitos

- versão Terraform definida em `.terraform-version`;
- `run.googleapis.com` e `pubsub.googleapis.com` habilitadas;
- service account de runtime do worker existente;
- service account push-auth existente no mesmo projeto;
- deployer autorizado a criar recursos Cloud Run/Pub/Sub, anexar a service account push-auth e gerenciar as relações IAM restritas demonstradas aqui;
- imagem de container cujo endpoint HTTP entenda o envelope padrão de push Pub/Sub e retorne sucesso somente após processamento bem-sucedido.

O exemplo não cria service accounts porque o ciclo de vida das identidades pertence à fundação IAM, não aos módulos de workload.

## Uso

Forneça variáveis por arquivo `.tfvars` local ignorado ou outro mecanismo seguro:

```hcl
project_id                     = "my-project"
location                       = "us-central1"
worker_image                   = "us-central1-docker.pkg.dev/my-project/apps/orders-worker:1.0.0"
worker_runtime_service_account = "orders-worker@my-project.iam.gserviceaccount.com"
push_service_account           = "orders-push@my-project.iam.gserviceaccount.com"
```

Validação sem backend real:

```bash
terraform init -backend=false -lockfile=readonly
terraform validate
```

Aplicar este exemplo cria recursos Google Cloud/mudanças IAM e pode gerar custos. CI e agentes não devem executar `terraform apply` sem autorização explícita.

## Comportamento de confiabilidade

O exemplo usa valores limitados de acknowledgement, retry, retenção e dead-letter. O worker deve ser idempotente: entrega Pub/Sub push/dead-letter não é contrato exactly-once e a contagem configurada de tentativas é best effort.

## Ingress do Cloud Run

O módulo Cloud Run reutilizado usa ingress restritivo por padrão. O push Pub/Sub deve ficar no mesmo projeto Google Cloud do worker para que o service permaneça não público com entrega autenticada. A identidade push também é restrita por `roles/run.invoker` somente a este service.

## O que este exemplo isolado omite intencionalmente

- publishers ou IAM de publisher;
- segredos da aplicação;
- integração VPC/Redis;
- Cloud Run Jobs e Cloud Scheduler;
- state/backends remotos de ambiente;
- composição de políticas de alerta no nível do ambiente.

Essas capacidades são implementadas pelos roots completos em `environments/dev` e `environments/prod`. Use este exemplo apenas para compreender o limite Pub/Sub/worker; use os ambientes para a arquitetura de referência completa.
