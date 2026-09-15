# Processamento batch agendado

## Propósito

Workloads batch finitos usam Cloud Run Jobs, não Cloud Run Services orientados a requisições. Um job inicia explicitamente, executa uma ou mais tasks até a conclusão e então termina.

Este repositório modela execução agendada por Cloud Scheduler chamando a Cloud Run Admin API autenticada.

```text
Cloud Scheduler
      |
      | POST + token de acesso OAuth
      v
run.googleapis.com/v2/.../jobs/JOB:run
      |
      v
Cloud Run Job
      |
      +--> task 0
      +--> task 1
      +--> ...
```

## Por que Pub/Sub não executa o job

Uma push subscription Pub/Sub entrega request HTTP a endpoint orientado a requisições. Cloud Run Jobs não expõem esse endpoint; expõem uma API de execução.

Os dois padrões de runtime permanecem, portanto, deliberadamente separados:

```text
Orientado a eventos
Pub/Sub --> push autenticado --> Cloud Run Service (worker .NET)

Batch finito / agendado
Cloud Scheduler --> OAuth --> Cloud Run Admin API --> Cloud Run Job
```

Não modele Pub/Sub como invocação direta de Cloud Run Job.

## Módulo Cloud Run Job

`modules/cloud-run-job` é responsável somente pela configuração do workload batch:

- imagem do container;
- service account de runtime explícita;
- task count;
- parallelism;
- retries por task;
- timeout por task;
- CPU e memória;
- environment variables literais;
- referências Secret Manager;
- labels e proteção contra exclusão.

Ele expõe `execution_uri`, endpoint suportado `:run` da Cloud Run Admin API. Não cria recursos Scheduler nem IAM de invocação.

## Composição do Scheduler

`examples/scheduled-cloud-run-job` demonstra o limite do trigger. Cloud Scheduler envia HTTP `POST` autenticado a `execution_uri` com access token OAuth gerado para service account dedicada do scheduler.

A identidade do scheduler recebe role aditiva `roles/run.invoker` no Cloud Run Job individual. Essa role contém `run.jobs.run`, então nenhuma role Cloud Run no projeto inteiro é necessária ao trigger.

A política de retry do Scheduler e a política de task retry do Cloud Run resolvem falhas diferentes:

- retry do Scheduler trata falha ao submeter/iniciar request de execução;
- `max_retries` do Cloud Run trata task iniciada que terminou sem sucesso.

Código batch deve ser idempotente porque qualquer limite pode repetir trabalho após falhas transitórias.

## Modelo de identidade

Use identidades separadas para limites de confiança distintos:

```text
Service account do Scheduler
  -> roles/run.invoker em um Cloud Run Job
  -> pode submeter execuções do job

Service account de runtime do batch
  -> anexada ao task template do Cloud Run
  -> acessa somente APIs/recursos necessários ao workload .NET batch
```

Nenhuma identidade precisa de chave de longa duração. Terraform não cria payloads de segredos nem chaves de service account.

## Limites representados pelo módulo

O módulo valida constraints relevantes da plataforma antes da execução do provider:

- `task_count`: 1–10000;
- `parallelism`: inteiro positivo, não maior que task count;
- `max_retries`: 0–10;
- `task_timeout`: segundos inteiros positivos, até 604800 segundos (7 dias);
- CPU: 1, 2 ou 4 vCPU inteiros no contrato atual não específico de Gen2;
- ranges compatíveis de CPU/memória;
- nomes de ambiente reservados `CLOUD_RUN_` e `X_GOOGLE_` são rejeitados.

Quotas regionais podem impor teto prático de parallelism menor que o task count configurado.

## Tratamento de segredos

Valores de segredos não são inputs Terraform. O módulo aceita apenas identificadores e versões de segredos Secret Manager. Uma composição posterior de IAM/Secret Manager concede `secretAccessor` à identidade de runtime somente nos segredos necessários.

## Validação

O módulo de job inclui testes nativos em modo plan com provider Google mockado, permitindo ao CI validar defaults e inputs inválidos sem executar job nem autenticar no Google Cloud.

O root de exemplo é inicializado com backend desabilitado e lock file de provider commitado. Nenhuma infraestrutura é criada durante validação de pull request.
