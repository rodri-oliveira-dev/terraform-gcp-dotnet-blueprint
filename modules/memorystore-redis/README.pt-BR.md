# Módulo Memorystore for Redis

Módulo filho Terraform reutilizável para instância Memorystore for Redis segura e privada usada pelos workloads .NET de referência.

O módulo é responsável apenas pela instância Redis. Criação de VPC, Private Service Access, Cloud Run Direct VPC egress, identidades de runtime, payloads Secret Manager e composição de ambiente permanecem fora deste módulo.

## Padrões seguros

O módulo sobrescreve deliberadamente diversos defaults permissivos do provider:

- `connect_mode = "PRIVATE_SERVICE_ACCESS"` é fixo;
- VPC completa e explícita é obrigatória, evitando seleção implícita da default network;
- `tier = "STANDARD_HA"` por padrão;
- `redis_version = "REDIS_7_2"` por padrão;
- Redis AUTH habilitado por padrão;
- criptografia em trânsito usa `SERVER_AUTHENTICATION` por padrão;
- `deletion_policy = "PREVENT"` por padrão.

`BASIC` continua disponível para ambientes explicitamente mais baratos, mas selecioná-lo não desabilita AUTH nem TLS.

## Contrato de rede

A instância usa Private Service Access em vez de direct VPC peering. O caller deve estabelecer a conexão Service Networking antes da instância Redis.

Com o módulo de rede do repositório, componha a dependência explicitamente:

```hcl
module "cache" {
  source = "../../modules/memorystore-redis"

  project_id         = var.project_id
  name               = "orders-cache"
  region             = var.region
  authorized_network = module.network.network_id

  depends_on = [module.network]
}
```

O `depends_on` é intencional: `authorized_network` cria dependência de dados na VPC, mas a API Redis também exige a conexão Private Service Access separada primeiro.

O módulo não cria `reserved_ip_range` dedicado. Com Private Service Access, Memorystore escolhe range disponível da alocação Service Networking estabelecida por `modules/vpc-network`.

## AUTH, TLS e state sensível

Redis AUTH e TLS resolvem problemas diferentes. AUTH exige autenticação do cliente; TLS protege tráfego em trânsito. Ambos são habilitados por padrão.

Memorystore gera a AUTH string. Este módulo intencionalmente **não** expõe `google_redis_instance.auth_string` como output e não cria versão Secret Manager. Operador/processo confiável deve recuperar e distribuir esse material de acordo com o ciclo de vida de segredos da aplicação.

O provider Google ainda pode persistir atributos Redis calculados e sensíveis no state Terraform. Trate o state como sensível mesmo que outputs exponham apenas metadados não secretos. O bootstrap de state remoto é o limite de segurança para isso.

Com TLS, clientes devem suportar TLS 1.2 ou superior e confiar na server CA do Memorystore. Recuperação/instalação da CA é responsabilidade da aplicação/operador; payloads de certificado não são outputs.

## Uso

```hcl
module "cache" {
  source = "../../modules/memorystore-redis"

  project_id         = "my-project"
  name               = "orders-cache"
  region             = "us-central1"
  authorized_network = "projects/my-project/global/networks/orders-vpc"

  memory_size_gb = 2

  labels = {
    component  = "cache"
    managed-by = "terraform"
  }
}
```

Para posicionamento zonal determinístico em `STANDARD_HA`, callers podem definir `location_id` e `alternative_location_id` diferentes. Se omitidos, Google Cloud escolhe as zonas.

## Inputs

| Nome | Padrão | Descrição |
| --- | --- | --- |
| `project_id` | obrigatório | Projeto Google Cloud contendo Redis. |
| `name` | obrigatório | ID da instância Redis, 1–40 caracteres conforme contrato do serviço. |
| `region` | obrigatório | Região Redis. |
| `display_name` | `null` | Nome legível opcional. |
| `authorized_network` | obrigatório | ID completo da VPC. |
| `memory_size_gb` | `1` | Capacidade Redis de 1–300 GiB. |
| `tier` | `STANDARD_HA` | `STANDARD_HA` ou `BASIC` explícito. |
| `redis_version` | `REDIS_7_2` | Versão moderna: 6.x, 7.0 ou 7.2. |
| `auth_enabled` | `true` | Habilita Redis AUTH. |
| `transit_encryption_mode` | `SERVER_AUTHENTICATION` | Modo TLS. |
| `location_id` | `null` | Zona primária opcional. |
| `alternative_location_id` | `null` | Zona secundária opcional para `STANDARD_HA`. |
| `redis_configs` | `{}` | Valores suportados de configuração Redis. |
| `labels` | `{}` | Labels do recurso. |
| `deletion_policy` | `PREVENT` | Guard de ciclo destrutivo; `DELETE` somente por escolha explícita. |

## Outputs

O módulo expõe somente metadados não secretos de integração:

- `id`;
- `name`;
- `host`;
- `port`;
- `region`;
- `tier`;
- `redis_version`;
- `authorized_network`;
- `connection = { host, port, tls_enabled, auth_required }`.

Não expõe Redis AUTH string nem payloads de server CA.

## Testes

Testes em `tests/` usam mocks do provider e modo plan, sem credenciais nem infraestrutura real.

```bash
terraform init -backend=false
terraform validate
terraform test
```

## Fora de escopo

- Memorystore for Redis Cluster ou Valkey;
- autenticação IAM para Redis Cluster;
- read-replica scaling;
- configuração de persistência;
- versões Secret Manager contendo AUTH gerada;
- distribuição do certificado CA;
- configuração da aplicação/cliente;
- criação de VPC, Private Service Access, NAT ou firewall;
- provider/backend específico de ambiente.
