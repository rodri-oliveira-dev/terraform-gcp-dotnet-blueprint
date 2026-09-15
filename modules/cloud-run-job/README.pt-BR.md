# Módulo Cloud Run v2 Job

Módulo filho Terraform reutilizável para workloads .NET batch finitos que executam até a conclusão em Google Cloud Run Jobs.

O módulo é responsável pela configuração do Cloud Run Job, incluindo Direct VPC egress opcional. Scheduling, IAM de invocação, grants IAM de runtime, recursos Secret Manager, ciclo de vida da VPC e composição de ambiente permanecem fora do módulo para que callers componham essas políticas explicitamente.

## Job versus service

Cloud Run Job não expõe endpoint orientado a requests. Ele executa uma ou mais tasks e termina. Portanto, deve ser iniciado explicitamente por mecanismo suportado como Cloud Run Admin API, Cloud Scheduler, Workflows ou comando de operador.

Não conecte uma push subscription Pub/Sub diretamente a este módulo. Consumo Pub/Sub orientado a eventos pertence a um Cloud Run Service que atende requests.

## Padrões seguros

- service account de runtime explícita é obrigatória;
- deletion protection usa `true` por padrão;
- uma task e parallelism um por padrão;
- timeout por task usa 600 segundos por padrão;
- tasks com falha repetem até três vezes por padrão;
- CPU limitada deliberadamente a 1, 2 ou 4 vCPU inteiros para não depender silenciosamente de configuração exclusiva de Gen2;
- Direct VPC egress desabilitado por padrão;
- com Direct VPC, egress usa `PRIVATE_RANGES_ONLY` por padrão;
- valores de segredos nunca são inputs; somente identificadores e versões Secret Manager são aceitos.

## Configuração de execução

Cloud Run suporta até 10.000 tasks por execução de job. Cada task recebe metadados `CLOUD_RUN_*` gerenciados pelo Cloud Run, como índice, contagem e tentativa de retry. O módulo impede callers de sobrescrever essas variáveis reservadas.

`parallelism` deve ser inteiro positivo não maior que `task_count`. A plataforma pode impor quota regional de concurrency menor em runtime.

`max_retries` aceita de 0 a 10. Valor 0 significa que task com falha não será repetida.

`task_timeout` usa segundos inteiros e é limitado a 604800 segundos (7 dias). Limites específicos de GPU ficam fora do contrato atual.

## Direct VPC egress

O input opcional `direct_vpc` renderiza `vpc_access.network_interfaces` no task template. Não cria nem depende de Serverless VPC Access connector.

```hcl
direct_vpc = {
  network    = "blueprint-vpc"
  subnetwork = "blueprint-us-central1"
  egress     = "PRIVATE_RANGES_ONLY"
  tags       = ["batch", "serverless"]
}
```

`direct_vpc = null` é o padrão. Modos suportados são `PRIVATE_RANGES_ONLY` e `ALL_TRAFFIC`; o primeiro é padrão para dependências privadas como Memorystore. `ALL_TRAFFIC` é explícito e pode exigir Cloud NAT ou outro desenho de egress externo ao módulo.

O output `direct_vpc` de `modules/vpc-network` pode ser passado diretamente ao módulo.

## Exemplo

```hcl
module "batch" {
  source = "../../modules/cloud-run-job"

  project_id      = "my-project"
  name            = "nightly-reconciliation"
  location        = "us-central1"
  container_image = "us-central1-docker.pkg.dev/my-project/apps/reconciliation:1.0.0"
  service_account = "reconciliation-runtime@my-project.iam.gserviceaccount.com"

  task_count   = 4
  parallelism  = 2
  max_retries  = 3
  task_timeout = "1800s"

  environment_variables = {
    DOTNET_ENVIRONMENT = "Production"
  }

  secret_environment_variables = {
    DATABASE_PASSWORD = {
      secret  = "reconciliation-database-password"
      version = "latest"
    }
  }

  direct_vpc = module.network.direct_vpc
}
```

O output `execution_uri` expõe o endpoint da Cloud Run Admin API usado para iniciar o job:

```text
https://run.googleapis.com/v2/projects/PROJECT/locations/REGION/jobs/JOB:run
```

Um caller pode usar essa URI com Cloud Scheduler e token OAuth de service account dedicada do scheduler.

## Limites de IAM

A service account de runtime é a identidade usada pelo processo .NET enquanto as tasks executam. Este módulo não concede permissões a ela.

A identidade que inicia o job é separada. Uma service account de scheduler ou operador deve receber binding aditivo `roles/run.invoker` no Cloud Run Job específico, não permissões Cloud Run amplas no projeto.

Acesso Secret Manager também permanece fora do módulo. Conceda à identidade de runtime acesso somente aos segredos realmente consumidos.

## Inputs

| Nome | Padrão | Finalidade |
| --- | --- | --- |
| `project_id` | obrigatório | Projeto Google Cloud. |
| `name` | obrigatório | Nome do Cloud Run Job. |
| `location` | obrigatório | Região do job. |
| `container_image` | obrigatório | Imagem do container batch. |
| `service_account` | obrigatório | Service account de runtime existente. |
| `task_count` | `1` | Número de tasks, 1–10000. |
| `parallelism` | `1` | Máximo de tasks concorrentes, não maior que task count. |
| `max_retries` | `3` | Retries por task com falha, 0–10. |
| `task_timeout` | `600s` | Timeout por task até 7 dias. |
| `resources` | `1` vCPU / `512Mi` | Limites de CPU e memória. |
| `direct_vpc` | `null` | Rede/subnet Direct VPC opcional, egress e network tags. |
| `environment_variables` | `{}` | Configuração literal não secreta. |
| `secret_environment_variables` | `{}` | Somente referências Secret Manager. |
| `labels` | `{}` | Labels do job. |
| `deletion_protection` | `true` | Proteção contra exclusão no provider. |

## Outputs

- `id`
- `name`
- `location`
- `project`
- `service_account`
- `execution_uri`

## Testes

Os testes usam provider Google mockado e `command = plan`, sem exigir credenciais ou criar infraestrutura.

```bash
terraform init -backend=false
terraform validate
terraform test
```

Cobrem validação de task/retry/recursos, nomes reservados, comportamento opt-in/default de Direct VPC, egress e mapeamento de network tags.

## Fora de escopo

- criação de service accounts;
- grants IAM de runtime;
- criação do scheduler;
- IAM de invocação;
- recursos ou payloads Secret Manager;
- VPC, subnets, NAT, routers ou Serverless VPC Access connectors;
- GPUs;
- configurações explícitas exclusivas de CPU Gen2;
- execução imediata durante `terraform apply`.
