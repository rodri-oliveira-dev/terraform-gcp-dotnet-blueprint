# Módulo Pub/Sub

Módulo filho Terraform reutilizável para tópicos e subscriptions Google Cloud Pub/Sub, incluindo push autenticado, política de retry, encaminhamento dead-letter e subscription de inspeção da dead-letter.

O módulo é focado em transporte. Não cria Cloud Run Services, identidades de runtime da aplicação, identidades publisher ou IAM de invocação do Cloud Run. Root modules compõem essas capacidades explicitamente.

## Modos de entrega suportados

- **Pull:** deixe `push_config = null`.
- **Push autenticado:** forneça endpoint HTTPS e service account gerenciada pelo usuário. Pub/Sub envia token OIDC em cada request push.

Na arquitetura de referência, push autenticado tem como alvo Cloud Run Service orientado a requisições. Pub/Sub nunca é modelado como execução direta de Cloud Run Job.

Quando payload unwrapping está habilitado por `no_wrapper = true`, callers também podem habilitar `write_metadata = true` para expor metadados Pub/Sub como headers. O módulo rejeita `write_metadata = true` quando `no_wrapper = false`, pois Pub/Sub só aplica essa opção dentro da configuração de unwrapping.

## Padrões de confiabilidade

- acknowledgement deadline: 60 segundos;
- retenção de mensagens: 7 dias;
- subscriptions não expiram por inatividade;
- retry backoff: 10 a 600 segundos;
- dead lettering habilitado;
- máximo de tentativas de entrega: 10;
- uma pull subscription é criada no tópico dead-letter para inspeção/reprocessamento;
- retenção de mensagens confirmadas e message ordering ficam desabilitados a menos que explicitamente habilitados.

Tentativas de dead-letter do Pub/Sub são best-effort. Consumers devem permanecer idempotentes e não tratar a contagem configurada como garantia exactly-once.

Quando nomes dead-letter são omitidos, o módulo deriva anexando `-dead-letter` aos nomes principais. Os nomes resultantes são validados contra o limite de 255 caracteres do Pub/Sub durante planning; callers com nomes longos devem fornecer nomes dead-letter explícitos e válidos.

Filtros de subscription são restritos a ASCII imprimível e máximo de 256 caracteres. Como ASCII imprimível usa um byte por caractere em UTF-8, isso aplica localmente o limite de 256 bytes e evita strings Unicode que passariam na contagem de caracteres, mas falhariam no provisionamento.

## Modelo IAM

Quando `manage_service_agent_iam = true` (padrão), o módulo concede somente as permissões exigidas pelo próprio Pub/Sub:

1. `roles/iam.serviceAccountTokenCreator` ao service agent gerenciado do Pub/Sub **na service account de push-auth configurada**, permitindo criação de tokens OIDC;
2. `roles/pubsub.publisher` ao service agent Pub/Sub **no tópico dead-letter**;
3. `roles/pubsub.subscriber` ao service agent Pub/Sub **na subscription principal**, permitindo ao encaminhamento dead-letter confirmar mensagens de origem.

O módulo deliberadamente **não** concede `roles/run.invoker`. O root que compõe Pub/Sub com Cloud Run Service é responsável por essa relação IAM entre módulos.

Três identidades permanecem distintas:

- **service account de runtime do worker** — anexada ao Cloud Run e usada pelo código da aplicação;
- **service account de push-auth** — representada no token OIDC do Pub/Sub e autorizada a invocar o service alvo;
- **service agent do Pub/Sub** — identidade gerenciada pelo Google usada para criar tokens push e encaminhar mensagens dead-letter.

## Pré-requisitos

Antes de aplicar root que consome este módulo:

- `pubsub.googleapis.com` deve estar habilitada;
- service account de push-auth deve existir e, para push autenticado, estar no mesmo projeto da subscription;
- identidade Terraform de deployment precisa de `iam.serviceAccounts.actAs` na service account de push-auth para anexá-la à subscription;
- se o módulo gerencia IAM do service agent, a identidade de deployment também precisa atualizar IAM na service account push-auth, tópico dead-letter e subscription principal;
- o root deve conceder à service account push-auth permissão para invocar o target, por exemplo `roles/run.invoker` em Cloud Run Service.

Essas permissões devem ser concedidas no escopo do recurso quando suportado.

## Exemplo

```hcl
module "events" {
  source = "../../modules/pubsub"

  project_id        = "my-project"
  topic_name        = "orders-events"
  subscription_name = "orders-worker"

  push_config = {
    endpoint              = module.worker.uri
    service_account_email = "orders-push@my-project.iam.gserviceaccount.com"
    audience              = module.worker.uri
  }

  retry_policy = {
    minimum_backoff_seconds = 10
    maximum_backoff_seconds = 300
  }

  dead_letter = {
    max_delivery_attempts = 10
  }
}
```

Consulte `examples/pubsub-worker` para composição com `modules/cloud-run-service` e IAM de Cloud Run invoker no escopo de recurso.

## Inputs

| Nome | Padrão | Descrição |
| --- | --- | --- |
| `project_id` | obrigatório | ID do projeto Google Cloud. |
| `topic_name` | obrigatório | Nome do tópico principal. |
| `subscription_name` | obrigatório | Nome da subscription principal. |
| `ack_deadline_seconds` | `60` | Acknowledgement deadline inicial, 10–600 segundos. |
| `message_retention_seconds` | `604800` | Retenção da subscription, 10 minutos a 31 dias. |
| `retain_acked_messages` | `false` | Retém mensagens confirmadas para replay. |
| `enable_message_ordering` | `false` | Preserva ordering para mensagens com a mesma ordering key. |
| `filter` | `null` | Filtro opcional ASCII imprimível, máximo 256 bytes. |
| `retry_policy` | `10..600s` | Backoff mínimo e máximo de redelivery. |
| `dead_letter` | habilitado | Nomes DLQ, subscription de inspeção e máximo de tentativas. |
| `push_config` | `null` | Endpoint HTTPS, service account push-auth, audience e opções de unwrapping. `write_metadata = true` exige `no_wrapper = true`. |
| `manage_service_agent_iam` | `true` | Gerencia IAM de escopo restrito exigido pelo transporte Pub/Sub. |
| `labels` | `{}` | Labels aplicados aos recursos Pub/Sub. |

## Outputs

O módulo expõe IDs/nomes do tópico e subscription principais, nomes opcionais de recursos dead-letter, e-mail do service agent Pub/Sub e e-mail da service account push-auth configurada.

## Testes

Testes em `tests/` usam mock provider e `command = plan`; não criam recursos Google Cloud nem exigem credenciais.

```bash
terraform init -backend=false
terraform validate
terraform test
```

## Fora de escopo

- Cloud Run Services ou Jobs;
- bindings Cloud Run `roles/run.invoker`;
- service accounts de runtime da aplicação;
- IAM de publisher;
- segredos da aplicação;
- Cloud Scheduler ou execução batch;
- provider/backend específico de ambiente.
