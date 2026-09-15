# Exemplo de identidades de runtime e Secret Manager

Este root demonstra o limite entre identidade e segredos introduzido pela issue #7 sem implantar workloads Cloud Run.

Ele cria:

- identidade de runtime `orders-api`;
- identidade de runtime `orders-worker`;
- metadados do segredo `orders-database-url`, legível somente pela identidade da API;
- metadados do segredo `orders-webhook-key`, legível somente pela identidade do worker.

Nenhuma versão nem payload de segredo é criada pelo Terraform.

## Pré-requisitos

- APIs IAM e Secret Manager habilitadas no projeto alvo;
- identidade Terraform de deployment capaz de criar service accounts e segredos Secret Manager;
- identidade de deployment capaz de atualizar IAM nos segredos específicos que cria.

Não execute `terraform apply` por CI ou agente sem autorização explícita. Aplicar este exemplo altera recursos reais do Google Cloud.

## Validar sem criar infraestrutura

```bash
terraform init -backend=false -input=false -lockfile=readonly
terraform validate
terraform plan -input=false -var='project_id=my-project'
```

O CI do repositório inicializa/valida o exemplo, mas não autentica no Google Cloud nem aplica recursos.

## Fornecimento de payloads dos segredos

Depois que os metadados existirem, operador ou sistema de entrega confiável cria versões fora do Terraform. Por exemplo, um operador pode adicionar versão usando Google Cloud CLI com stdin, sem commitar o valor em source control.

O processo exato de bootstrap/rotação dos valores é específico da organização e permanece fora deste root de referência.

## Contrato de integração com Cloud Run

Os outputs refletem os inputs existentes dos módulos de workload:

```hcl
module "api" {
  source = "../../modules/cloud-run-service"

  # ...
  service_account = module.api_identity.email

  secret_environment_variables = {
    DATABASE_URL = module.api_database_secret.secret_reference
  }
}
```

O mesmo objeto `{ secret, version }` é aceito por `modules/cloud-run-job`.

## Resultado de least privilege

A identidade da API não consegue ler o segredo do worker e a identidade do worker não consegue ler o segredo da API porque o módulo cria somente membros `roles/secretmanager.secretAccessor` por segredo. Nenhuma role accessor no projeto inteiro é concedida.
