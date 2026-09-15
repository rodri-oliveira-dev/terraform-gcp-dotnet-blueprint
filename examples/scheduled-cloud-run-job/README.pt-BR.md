# Exemplo de Cloud Run Job agendado

Este root compõe `modules/cloud-run-job` com Cloud Scheduler para demonstrar caminho suportado de execução batch finita:

```text
Cloud Scheduler
      |
      | access token OAuth 2.0
      v
Cloud Run Admin API
      |
      | POST .../jobs/JOB:run
      v
Cloud Run Job
      |
      v
Container batch .NET executa até a conclusão
```

Ele intencionalmente **não** usa Pub/Sub para iniciar o job. Push Pub/Sub exige endpoint orientado a requisições e é demonstrado separadamente por `examples/pubsub-worker`.

## Separação de identidades

O exemplo espera duas service accounts existentes:

- `runtime_service_account` — anexada às tasks do Cloud Run Job e usada pelo processo .NET batch ao acessar APIs Google Cloud;
- `scheduler_service_account` — usada somente pelo Cloud Scheduler para autenticar request à Cloud Run Admin API.

O exemplo concede à identidade do scheduler `roles/run.invoker` no Cloud Run Job específico por recurso aditivo `google_cloud_run_v2_job_iam_member`. Não concede permissões Cloud Run no nível do projeto.

As identidades devem ser diferentes para manter permissões de runtime e trigger com escopos independentes.

## Escolha de autenticação

O target do Scheduler é endpoint de Google API (`run.googleapis.com`), portanto o exemplo usa access token OAuth em vez de token OIDC.

A URI alvo é produzida pelo módulo job:

```text
https://run.googleapis.com/v2/projects/PROJECT/locations/REGION/jobs/JOB:run
```

A request HTTP é `POST` com objeto JSON vazio. Cloud Scheduler autentica como `scheduler_service_account` usando o escopo OAuth `cloud-platform`.

## Pré-requisitos

Antes de aplicar:

1. habilite APIs Cloud Run e Cloud Scheduler;
2. crie service accounts de runtime e scheduler;
3. conceda à runtime somente permissões necessárias ao código batch;
4. garanta que o deployer Terraform possa anexar a runtime identity e configurar a identidade OAuth do Scheduler;
5. forneça imagem de container existente;
6. autentique Terraform por ADC ou Workload Identity Federation.

Nenhuma chave de service account é necessária ou esperada.

## Variáveis de exemplo

```hcl
project_id                = "my-project"
location                  = "us-central1"
container_image           = "us-central1-docker.pkg.dev/my-project/apps/reconciliation:1.0.0"
runtime_service_account   = "batch-runtime@my-project.iam.gserviceaccount.com"
scheduler_service_account = "batch-scheduler@my-project.iam.gserviceaccount.com"
schedule                  = "0 2 * * *"
time_zone                 = "America/Sao_Paulo"
```

Não faça commit de arquivos `.tfvars` reais.

## Validação

Este é root de exemplo, não root de deployment de ambiente. O CI o inicializa com backend desabilitado e valida sem autenticar no Google Cloud nem criar recursos.

```bash
terraform init -backend=false -lockfile=readonly
terraform validate
```

O módulo reutilizável do job também é exercitado por testes nativos em `modules/cloud-run-job/tests/`.

## Considerações de produção

- Tasks batch devem ser idempotentes porque retries podem executar novamente uma task com falha.
- Use IAM específico do runtime em vez de roles amplas no projeto.
- Conceda acesso Secret Manager no menor escopo prático.
- Escolha task count e parallelism de acordo com particionamento e quotas regionais Cloud Run.
- Trate retries do Scheduler separadamente dos retries de tasks: Scheduler repete a **request de execução**, enquanto `max_retries` repete uma **task dentro da execução**.
- Use observabilidade/alertas para falhas de Scheduler e Cloud Run antes de adotar o padrão em produção.
