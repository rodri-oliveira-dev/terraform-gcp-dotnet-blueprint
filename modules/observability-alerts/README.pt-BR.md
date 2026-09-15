# Módulo de padrões de alerta do Cloud Monitoring

Este módulo é responsável por um conjunto focado de políticas de alerta do Cloud Monitoring para a arquitetura .NET de referência. Ele consome identificadores de infraestrutura já existente e não cria workloads da aplicação, destinos de notificação, dashboards, métricas baseadas em log nem recursos SLO.

## O que monitora

Quando o alvo correspondente é fornecido, o módulo cria políticas para:

- **Cloud Run Services** — taxa HTTP 5xx sustentada usando `run.googleapis.com/request_count`, com threshold padrão de 5% por cinco minutos;
- **subscription principal Pub/Sub** — idade da mensagem não confirmada mais antiga usando `pubsub.googleapis.com/subscription/oldest_unacked_message_age`;
- **encaminhamento dead-letter do Pub/Sub** — qualquer mensagem não entregável encaminhada usando `pubsub.googleapis.com/subscription/dead_letter_message_count`;
- **Cloud Run Job** — execuções concluídas cujo label `result` é `failed`, usando `run.googleapis.com/job/completed_execution_count`;
- **Memorystore for Redis** — pressão de memória de dados/sistema e conexões rejeitadas.

Os defaults são sinais orientados à infraestrutura, não SLOs universais da aplicação, e devem ser ajustados com tráfego real, comportamento dos workloads e error budgets.

## Limite de notificação

O módulo nunca cria `google_monitoring_notification_channel` e nunca aceita e-mails, Slack tokens, webhook secrets, PagerDuty keys ou configuração similar de destino.

Callers podem fornecer nomes de recursos de canais existentes:

```hcl
notification_channels = [
  "projects/example-project/notificationChannels/1234567890",
]
```

Conjunto vazio é válido. As políticas continuam existindo e gerando incidents no Cloud Monitoring, mas nenhum canal externo é notificado até um caller anexá-lo.

## Exemplo

```hcl
module "alerts" {
  source = "../../modules/observability-alerts"

  project_id  = "example-project"
  environment = "prod"
  location    = "us-central1"

  cloud_run_services = {
    api    = "blueprint-prod-api"
    worker = "blueprint-prod-worker"
  }

  cloud_run_job_name       = "blueprint-prod-batch"
  pubsub_subscription_name = "blueprint-prod-worker"
  redis_instance_id        = "blueprint-prod-cache"

  notification_channels = var.notification_channels
}
```

## Thresholds

Defaults portáveis:

| Sinal | Padrão | Avaliação |
| --- | ---: | --- |
| Taxa 5xx Cloud Run | 5% | sustentada por 5 minutos |
| Mensagem Pub/Sub não confirmada mais antiga | 300 segundos | sustentada por 5 minutos |
| Uso de memória de dados Redis | 80% | sustentado por 5 minutos |
| Uso de memória de sistema Redis | 80% | sustentado por 5 minutos |
| Encaminhamento dead-letter Pub/Sub | qualquer mensagem | orientado a evento |
| Execução Cloud Run Job com falha | qualquer falha | orientado a evento |
| Conexões Redis rejeitadas | qualquer conexão rejeitada | orientado a evento |

Somente thresholds portáveis de capacidade/taxa são configuráveis pelo objeto `thresholds`. Políticas orientadas a evento disparam no primeiro evento observado porque cada evento representa caminho concreto de falha que merece investigação.

## Dados ausentes

Condições usam `EVALUATION_MISSING_DATA_INACTIVE`. Ausência de telemetria sozinha não cria incident. Isso evita transformar Cloud Run ocioso, subscription silenciosa ou Redis sem uso em falso positivo. Disponibilidade da telemetria pertence à política operacional mais ampla e pode ser adicionada pelos callers.

## Ciclo de vida

Políticas de alerta usam `deletion_policy = "DELETE"`. São configuração operacional, não recursos duráveis de data plane, portanto remover o módulo deve remover as políticas em vez de bloquear teardown ou abandoná-las sem gerenciamento.

## Segurança e state

- segredos de destinos de notificação ficam fora do módulo;
- nenhum valor secreto da aplicação é aceito ou emitido;
- documentação das políticas contém somente identificadores de recursos e orientação ao responder;
- state contém configuração das políticas e nomes dos canais, mas não material secreto dos canais criados em outro lugar;
- habilitar/desabilitar políticas não altera workloads monitorados.

## Testes

Testes nativos usam provider Google mockado e modo plan. Verificam seleção de targets, contratos de métricas/filtros, defaults, wiring de canais e validação de inputs sem credenciais ou recursos com custo.

## Composição nos ambientes e orientação operacional

O módulo já está conectado aos dois roots:

- `environments/dev/observability.tf` aplica thresholds de desenvolvimento e canais opcionais;
- `environments/prod/observability.tf` aplica thresholds de produção e canais opcionais.

Consulte [`docs/observability.md`](../../docs/observability.md) para logging estruturado, ownership de telemetria, seleção SLI/SLO, error budgets e política de dashboards.
