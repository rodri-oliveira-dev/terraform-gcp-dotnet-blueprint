# Módulo Cloud Run v2 Service

Módulo filho Terraform reutilizável para implantar workloads .NET orientados a requisições no Google Cloud Run v2.

O módulo é responsável pela configuração do Cloud Run Service, incluindo Direct VPC egress opcional. Identidades de runtime, grants IAM, recursos Secret Manager, ciclo de vida da VPC, Pub/Sub e composição de ambiente permanecem fora deste módulo para que os roots componham essas capacidades explicitamente.

## Padrões de segurança

- Uma service account de runtime é obrigatória; o módulo não usa silenciosamente a service account padrão do projeto.
- Ingress usa `INGRESS_TRAFFIC_INTERNAL_ONLY` por padrão.
- Proteção contra exclusão no provider usa `true` por padrão.
- Scaling usa `0..10` instâncias por padrão para preservar scale-to-zero e limitar exposição de custo da arquitetura de referência.
- Direct VPC egress é desabilitado por padrão.
- Quando Direct VPC está habilitado, egress usa `PRIVATE_RANGES_ONLY` por padrão.
- O módulo não concede `allUsers`, `roles/run.invoker` nem qualquer outra role IAM.
- Valores de segredos nunca são inputs do módulo. Environment variables baseadas em segredos aceitam apenas identificador e versão do Secret Manager.

Callers são responsáveis por conceder à service account de runtime acesso aos segredos referenciados. Prefira grants `roles/secretmanager.secretAccessor` no escopo dos segredos necessários, em vez de acesso amplo no projeto.

## Constraints dos recursos

O módulo valida limites da plataforma Cloud Run antes que um deployment chegue ao provider:

- CPU é intencionalmente restrita a `1`, `2` ou `4` vCPU. CPU fracionária não é exposta porque traz constraints adicionais de billing/concurrency, e `6`/`8` vCPU não são expostos porque exigem ambiente de execução Gen2, ainda não configurado pelo módulo.
- Memória deve ficar entre `512Mi` e `16Gi` e ser compatível com a CPU selecionada: até `4Gi` para 1 vCPU, até `8Gi` para 2 vCPU e `2-16Gi` para 4 vCPU.
- `PORT` e nomes iniciados por `X_GOOGLE_` são rejeitados tanto para variáveis literais quanto para variáveis baseadas no Secret Manager porque são reservados pelo Cloud Run.

Essas validações são cobertas por testes negativos nativos do Terraform, fazendo configurações inválidas falharem no CI em vez do deployment. Se requisitos futuros precisarem de 6/8 vCPU, o módulo deve primeiro expor ou configurar deliberadamente Gen2 e adicionar validação cruzada correspondente.

## Direct VPC egress

O input opcional `direct_vpc` renderiza `vpc_access.network_interfaces` do Cloud Run v2; ele não cria Serverless VPC Access connector.

```hcl
direct_vpc = {
  network    = "blueprint-vpc"
  subnetwork = "blueprint-us-central1"
  egress     = "PRIVATE_RANGES_ONLY"
  tags       = ["api", "serverless"]
}
```

`direct_vpc = null` é o padrão e não renderiza bloco `vpc_access`, preservando compatibilidade para callers que não precisam de rede privada.

Modos de egress suportados:

- `PRIVATE_RANGES_ONLY` — padrão; ranges privados usam a VPC e tráfego público comum mantém o caminho normal do Cloud Run;
- `ALL_TRAFFIC` — opt-in explícito; callers são responsáveis por Cloud NAT ou outro caminho de internet-egress exigido pelo ambiente.

O output `direct_vpc` de `modules/vpc-network` pode ser passado diretamente a este input. Recursos de network/subnetwork continuam pertencendo ao módulo/root de rede.

## Uso

```hcl
module "api" {
  source = "../../modules/cloud-run-service"

  project_id      = "my-project"
  name            = "orders-api"
  location        = "us-central1"
  container_image = "us-central1-docker.pkg.dev/my-project/apps/orders-api:1.0.0"
  service_account = "orders-api@my-project.iam.gserviceaccount.com"

  resources = {
    cpu    = "1"
    memory = "512Mi"
  }

  scaling = {
    min_instance_count = 0
    max_instance_count = 10
  }

  environment_variables = {
    ASPNETCORE_ENVIRONMENT = "Production"
  }

  secret_environment_variables = {
    DATABASE_PASSWORD = {
      secret  = "orders-database-password"
      version = "latest"
    }
  }

  direct_vpc = module.network.direct_vpc

  labels = {
    component  = "api"
    managed-by = "terraform"
  }
}
```

Usar `INGRESS_TRAFFIC_ALL` altera somente a configuração de ingress de rede. Isso **não** torna o serviço não autenticado; IAM de invocação fica deliberadamente fora deste módulo.

## Inputs

| Nome | Tipo | Padrão | Descrição |
| --- | --- | --- | --- |
| `project_id` | `string` | obrigatório | ID do projeto Google Cloud. |
| `name` | `string` | obrigatório | Nome do Cloud Run Service, validado contra constraints de naming. |
| `location` | `string` | obrigatório | Região Google Cloud. |
| `description` | `string` | `null` | Descrição opcional do service, máximo 512 caracteres. |
| `container_image` | `string` | obrigatório | URI da imagem do container. |
| `service_account` | `string` | obrigatório | E-mail da service account de runtime existente. |
| `container_port` | `number` | `8080` | Porta de request do container. |
| `resources` | `object` | CPU `1`, memória `512Mi`, CPU idle habilitado, startup CPU boost habilitado | Configuração de compute restrita a combinações CPU/memória suportadas. |
| `scaling` | `object` | min `0`, max `10` | Limites de autoscaling no nível da revision. |
| `max_instance_request_concurrency` | `number` | `80` | Máximo de requests concorrentes por instância, 1–1000. |
| `timeout` | `string` | `300s` | Duração máxima da request, limitada a 3600 segundos. |
| `ingress` | `string` | `INGRESS_TRAFFIC_INTERNAL_ONLY` | Política de ingress suportada do Cloud Run. |
| `direct_vpc` | `object` | `null` | Rede/subnet Direct VPC opcional, modo de egress e network tags. |
| `deletion_protection` | `bool` | `true` | Proteção contra exclusão no provider. |
| `environment_variables` | `map(string)` | `{}` | Environment variables literais não secretas. Nomes reservados são rejeitados. |
| `secret_environment_variables` | `map(object)` | `{}` | Referências Secret Manager por nome de environment variable não reservado. |
| `labels` | `map(string)` | `{}` | Labels do service. |

Um nome não pode aparecer simultaneamente em `environment_variables` e `secret_environment_variables`.

## Outputs

- `id` — ID completo do recurso Cloud Run Service;
- `name` — nome do service;
- `uri` — serving URI calculada pelo provider;
- `location` — região do service;
- `project` — projeto do service;
- `service_account` — e-mail configurado da service account de runtime.

## Testes

Os testes em `tests/` usam mock provider do Terraform, não exigem credenciais Google Cloud e não criam infraestrutura com custo.

```bash
terraform init -backend=false
terraform validate
terraform test
```

Os testes cobrem padrões seguros, mapeamento de recursos, outputs, constraints CPU/memória, rejeição de CPU exclusiva de Gen2, nomes reservados de environment variables, comportamento opt-in/default de Direct VPC, validação de egress, network tags e conflitos entre fontes de variáveis.

## Fora de escopo

Este módulo não cria ou gerencia:

- service accounts ou IAM bindings;
- acesso público de invoker;
- segredos, versões ou payloads do Secret Manager;
- VPCs, subnets, NAT, routers ou Serverless VPC Access connectors;
- subscriptions Pub/Sub;
- Cloud Run Jobs;
- seleção de execution environment Gen2;
- backends ou configuração de provider específicos de ambiente.
