# Módulo Secret Manager

Cria um recurso de **metadados** do Google Cloud Secret Manager e grants opcionais de acesso no escopo do recurso para service accounts de workloads.

O módulo intencionalmente não cria versões de segredos e não possui input para payloads. Valores de segredos da aplicação devem ser adicionados por processo separado controlado pelo operador/entrega, evitando que configuração e state Terraform se tornem system of record de credenciais.

## Modelo de segurança

- deletion protection habilitada por padrão;
- replication automática por padrão, com locations gerenciadas pelo usuário opcionalmente;
- nenhum principal recebe acesso por padrão;
- service accounts configuradas recebem apenas `roles/secretmanager.secretAccessor` neste segredo específico;
- nenhuma role Secret Manager no projeto inteiro é criada;
- não existe recurso `google_secret_manager_secret_version` neste módulo.

Google Cloud recomenda conceder permissões Secret Manager no menor nível de recurso prático. Por isso o módulo usa recursos aditivos `google_secret_manager_secret_iam_member` no segredo individual.

## Identidade estável de accessors

`accessor_service_accounts` é um map cujas **chaves são identificadores estáveis escolhidos pelo caller** e os valores são e-mails de service accounts. Recursos IAM usam somente as chaves estáveis para identidade de `for_each`.

Isso é importante quando o e-mail vem de outro recurso/módulo e está unknown no plan inicial. E-mails computados permanecem valores do map, onde valores unknown são válidos, em vez de virar chaves de `for_each` que Terraform precisa conhecer antes de planejar instâncias.

```hcl
accessor_service_accounts = {
  api_runtime = module.api_identity.email
}
```

Mantenha as chaves estáticas e semanticamente ligadas ao limite do workload; não derive de atributos computados.

## Exemplo

```hcl
module "database_secret" {
  source = "../../modules/secret-manager"

  project_id = "my-project"
  secret_id  = "orders-database-url"

  accessor_service_accounts = {
    api_runtime = module.api_identity.email
  }
}

module "api" {
  source = "../../modules/cloud-run-service"

  # ...
  service_account = module.api_identity.email

  secret_environment_variables = {
    DATABASE_URL = module.database_secret.secret_reference
  }
}
```

A versão referenciada por `secret_reference.version` deve existir quando o workload iniciar. Por padrão o módulo expõe o alias `latest`; callers podem fornecer versão numérica ou alias via `reference_version` sem Terraform criar ou ler payload.

## Inputs

| Nome | Padrão | Descrição |
| --- | --- | --- |
| `project_id` | obrigatório | Projeto que contém o segredo. |
| `secret_id` | obrigatório | ID do segredo, 1–255 letras/dígitos/hífens/underscores. |
| `accessor_service_accounts` | `{}` | IDs estáveis do caller mapeados a e-mails de service accounts com accessor somente neste segredo. |
| `replication_locations` | `[]` | Vazio para replication automática; caso contrário, locations gerenciadas pelo usuário. |
| `reference_version` | `latest` | Versão/alias exposto aos consumers Cloud Run. |
| `deletion_protection` | `true` | Impede exclusão acidental dos metadados por Terraform. |
| `labels` | `{}` | Labels do segredo. |

## Outputs

- `secret_id` — adequado a referências Secret Manager do Cloud Run;
- `name` — nome completo do recurso Secret Manager;
- `secret_reference` — objeto `{ secret, version }` compatível com contratos de environment variables de segredo dos módulos Cloud Run;
- `accessor_service_accounts` — IDs estáveis mapeados aos principals com acesso concedido.

## Ownership das versões dos segredos

Versões ficam deliberadamente fora do Terraform. Operadores ou workflow dedicado de entrega são responsáveis por criar, rotacionar, desabilitar e destruir versões. A identidade de runtime recebe somente permissão de leitura do payload; não recebe permissão para adicionar ou gerenciar versões.

## Fora de escopo

Este módulo não cria payloads, versões, roles IAM arbitrárias, grants Secret Manager no projeto, identidades de workload ou políticas específicas de ambiente.
