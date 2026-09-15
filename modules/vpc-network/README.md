# Módulo de rede VPC

Cria a fundação de rede privada usada por Cloud Run Direct VPC egress e serviços gerenciados que dependem de Private Service Access.

O módulo é responsável por uma VPC em modo customizado, uma subnet IPv4 regional de workloads, um range alocado de VPC peering e uma conexão Service Networking. Deliberadamente não cria Serverless VPC Access connectors, Cloud NAT, Cloud Router, firewall rules de workload nem instâncias de serviços gerenciados.

## Padrões de segurança e ciclo de vida

- subnets automáticas são desabilitadas;
- subnet de workloads é somente IPv4;
- Private Google Access habilitado por padrão na subnet;
- conexão Service Networking usa `deletion_policy = "PREVENT"` por padrão;
- nenhuma firewall rule abre acesso de entrada;
- nenhum IP público, NAT gateway ou caminho de internet-egress é criado;
- habilitação da Service Networking API permanece pré-requisito do root/projeto em vez de pertencer ao módulo filho.

`PREVENT` faz exclusão acidental da conexão Private Service Access falhar cedo. Para ambiente explicitamente descartável, callers podem usar `private_service_access_deletion_policy = "DELETE"` após revisar dependências de producer services.

## Private Service Access

Private Service Access exige range interno alocado com `purpose = "VPC_PEERING"`, seguido de conexão a `servicenetworking.googleapis.com`.

O módulo exige CIDR explícito para esse range, em vez de pedir ao Google Cloud que escolha. Isso mantém planejamento de endereços visível no código e permite que roots coordenem ranges sem sobreposição.

Na arquitetura de referência, `private_service_access_cidr` aceita prefixos IPv4 de `/8` a `/24`. Memorystore for Redis documenta `/24` ou range maior para estabelecer Private Service Access. O caller continua responsável por evitar sobreposição com subnets, peer networks, rotas VPN/Interconnect e outros ranges; Google Cloud faz validação autoritativa.

## Pré-requisitos de API

Antes de aplicar root que consome o módulo, habilite pelo menos:

- `compute.googleapis.com`;
- `servicenetworking.googleapis.com`.

O módulo não gerencia essas APIs no projeto porque seu ciclo de vida é compartilhado por outras infraestruturas.

## Exemplo

```hcl
module "network" {
  source = "../../modules/vpc-network"

  project_id   = "my-project"
  network_name = "blueprint-vpc"

  subnet_name          = "blueprint-us-central1"
  subnet_region        = "us-central1"
  subnet_ip_cidr_range = "10.20.0.0/24"

  private_service_access_range_name = "blueprint-managed-services"
  private_service_access_cidr       = "10.30.0.0/16"
}
```

O output `direct_vpc` expõe exatamente nomes de network/subnet esperados pelos inputs `direct_vpc` opcionais dos módulos Cloud Run:

```hcl
module "api" {
  source = "../../modules/cloud-run-service"

  # ...
  direct_vpc = module.network.direct_vpc
}

module "batch" {
  source = "../../modules/cloud-run-job"

  # ...
  direct_vpc = module.network.direct_vpc
}
```

Os módulos de workload usam `PRIVATE_RANGES_ONLY` e nenhuma network tag por padrão. Este módulo permanece responsável somente pelo ciclo de vida da VPC/subnet.

## Inputs

| Nome | Padrão | Descrição |
| --- | --- | --- |
| `project_id` | obrigatório | Projeto contendo a rede. |
| `network_name` | obrigatório | Nome da VPC customizada. |
| `routing_mode` | `REGIONAL` | Modo de roteamento dinâmico: `REGIONAL` ou `GLOBAL`. |
| `mtu` | `1460` | MTU da VPC, 1300–8896 bytes. |
| `subnet_name` | obrigatório | Nome da subnet regional de workloads. |
| `subnet_region` | obrigatório | Região da subnet. |
| `subnet_ip_cidr_range` | obrigatório | CIDR IPv4 com prefixo `/4` a `/29`. |
| `private_ip_google_access` | `true` | Habilita Private Google Access na subnet. |
| `private_service_access_range_name` | obrigatório | Nome do range VPC peering alocado. |
| `private_service_access_cidr` | obrigatório | Range IPv4 explícito reservado para Private Service Access, `/8` a `/24`. |
| `private_service_access_deletion_policy` | `PREVENT` | Política segura; use `DELETE` explicitamente apenas para redes descartáveis. |

## Outputs

O módulo expõe IDs/nomes de network/subnet, região/CIDR da subnet, objeto de composição `direct_vpc`, nome/CIDR do range PSA e nome do peering Service Networking resultante.

## Testes

Testes em `tests/` usam provider Google mockado e `command = plan`, sem criar rede real nem exigir credenciais.

```bash
terraform init -backend=false
terraform validate
terraform test
```

## Fora de escopo

- ciclo de vida de workloads Cloud Run além do contrato tipado `direct_vpc`;
- Serverless VPC Access connectors;
- recursos Memorystore/Redis;
- Cloud NAT ou Cloud Router;
- firewall rules específicas de workload;
- orquestração Shared VPC host/service project;
- configuração de provider/backend específica de ambiente.
