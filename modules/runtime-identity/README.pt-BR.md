# Módulo de identidade de runtime

Cria uma service account Google Cloud destinada a representar um único limite de runtime de workload, como API Cloud Run, worker orientado a requisições ou Cloud Run Job.

O módulo deliberadamente não aceita roles IAM arbitrárias. Criar identidade e conceder acesso a recursos são responsabilidades separadas; callers concedem somente as permissões no escopo dos recursos realmente necessários ao workload.

## Modelo de segurança

- nenhuma chave de service account é criada;
- a service account fica habilitada por padrão;
- uma instância do módulo representa uma identidade de workload;
- nenhuma role no nível do projeto é concedida;
- outputs são formatados para uso direto por Cloud Run e IAM bindings no escopo de recurso.

## Exemplo

```hcl
module "api_identity" {
  source = "../../modules/runtime-identity"

  project_id   = "my-project"
  account_id   = "orders-api"
  display_name = "Orders API runtime"
  description  = "Runtime identity used only by the orders API."
}

module "api" {
  source = "../../modules/cloud-run-service"

  # ...
  service_account = module.api_identity.email
}
```

## Inputs

| Nome | Padrão | Descrição |
| --- | --- | --- |
| `project_id` | obrigatório | Projeto onde a service account é criada. |
| `account_id` | obrigatório | ID de service account compatível com RFC1035, 6–30 caracteres. |
| `display_name` | `null` | Nome legível; por padrão usa `account_id`. |
| `description` | `null` | Descrição opcional do limite de workload, até 256 caracteres. |
| `disabled` | `false` | Se a identidade está desabilitada. |

## Outputs

- `email` — input direto para `service_account` do Cloud Run;
- `name` — nome completo do recurso service account;
- `member` — string IAM member `serviceAccount:...`;
- `unique_id` — identificador estável atribuído pelo Google.

## Fora de escopo

Este módulo não cria chaves, grants IAM no projeto, acesso Secret Manager, recursos Cloud Run ou credenciais da aplicação.
