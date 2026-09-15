# Identidades de runtime e Secret Manager

## Propósito

Workloads neste repositório usam service accounts Google Cloud explícitas, em vez de identidades padrão do projeto. O acesso ao Secret Manager é concedido a essas identidades somente nos segredos individuais necessários.

O desenho separa três preocupações:

1. criação da identidade de workload;
2. metadados/política de acesso do segredo;
3. ciclo de vida de payload/versões do segredo.

Terraform é responsável pelas duas primeiras. Payloads de segredos da aplicação permanecem fora do Terraform.

## Limite da identidade de runtime

`modules/runtime-identity` cria uma service account para um limite de workload. Instâncias típicas incluem identidade de runtime da API, worker assíncrono e batch job.

O módulo não aceita roles arbitrárias de projeto e nunca cria chaves de service account. Um root compõe essa identidade com Cloud Run passando `module.<identity>.email` para o input `service_account` do módulo de workload.

Isso mantém credenciais de runtime separadas de credenciais de deployment, identidades Pub/Sub push, identidades de trigger Cloud Scheduler e service agents gerenciados pelo Google.

## Limite de metadados dos segredos

`modules/secret-manager` cria um recurso de metadados `google_secret_manager_secret`. Deletion protection é habilitada por padrão, replication automática é usada a menos que locations sejam fornecidas explicitamente e nenhum principal recebe acesso ao payload por padrão.

Quando `accessor_service_accounts` é configurado, o módulo adiciona um `google_secret_manager_secret_iam_member` por identidade de workload com exatamente `roles/secretmanager.secretAccessor` nesse segredo.

O input é um map com chaves estáveis escolhidas pelo caller e e-mails de service account como valores:

```hcl
accessor_service_accounts = {
  api_runtime = module.api_identity.email
}
```

A chave estável (`api_runtime`) determina o endereço da instância do recurso Terraform. O e-mail permanece valor e pode estar unknown no plan inicial enquanto a service account é criada no mesmo grafo. E-mails computados de service account não devem ser usados como chaves de `for_each`.

Nenhuma role de Secret Manager accessor no projeto inteiro é criada. Isso segue least privilege: workload que precisa de um segredo deve receber acesso a esse segredo, não a todos os segredos do projeto.

## Ownership de payload e versões

O repositório intencionalmente não cria recursos `google_secret_manager_secret_version` para credenciais da aplicação e não expõe variável que aceite secret data.

Um operador ou processo de entrega confiável é responsável por:

- adicionar a versão inicial do segredo;
- rotacionar valores;
- atribuir aliases quando apropriado;
- desabilitar ou destruir versões comprometidas/obsoletas;
- auditar acesso aos payloads.

Manter payloads fora do Terraform evita credenciais em configuração versionada e evita colocar deliberadamente segredos da aplicação no state Terraform.

## Integração com Cloud Run

Os dois módulos Cloud Run consomem o mesmo formato de referência:

```hcl
secret_environment_variables = {
  DATABASE_URL = {
    secret  = "orders-database-url"
    version = "latest"
  }
}
```

O módulo Secret Manager expõe exatamente esse formato como `secret_reference`, permitindo composição sem transformação:

```hcl
service_account = module.api_identity.email

secret_environment_variables = {
  DATABASE_URL = module.database_secret.secret_reference
}
```

A service account ainda precisa do binding de accessor no segredo; referenciar um segredo não concede acesso por si só.

## Notas operacionais

- chaves estáveis do map de accessors devem representar limites de workload e não podem derivar de atributos calculados;
- `latest` é conveniente na arquitetura de referência, mas organizações podem preferir versão numérica ou alias gerenciado para maior controle de rollout;
- alterar metadados do segredo não cria nem rotaciona payload;
- excluir metadados protegidos exige mudança explícita em `deletion_protection` antes que Terraform possa removê-los;
- recursos IAM são membros aditivos, não substituições autoritativas da política inteira.

Consulte `examples/runtime-secrets` para composição com duas identidades de workload que não conseguem ler os segredos uma da outra.
