# Fundação de rede privada

## Propósito

A arquitetura de referência usa uma VPC dedicada em modo customizado como limite compartilhado de rede privada para workloads Cloud Run e serviços gerenciados. A rede é modelada separadamente de compute, segredos, mensageria e cache para que os roots componham essas capacidades explicitamente.

A issue #19 foi implementada em duas partes:

1. **Parte 1:** VPC, subnet de workloads, range alocado de Private Service Access e conexão com Service Networking.
2. **Parte 2:** Direct VPC egress opcional para os módulos existentes de Cloud Run Service e Cloud Run Job.

O contrato concluído mantém o ciclo de vida da VPC separado do Cloud Run e expõe um pequeno objeto tipado que os roots podem passar diretamente para qualquer módulo de workload.

## VPC e subnet de workloads

`modules/vpc-network` cria uma `google_compute_network` em modo customizado e uma `google_compute_subnetwork` regional.

A rede em modo customizado desabilita a criação automática de subnets regionais do Google Cloud. Os roots de ambiente, portanto, são responsáveis explicitamente pelo plano de endereçamento, em vez de herdar ranges do auto mode `10.128.0.0/9`.

A subnet de workloads:

- é somente IPv4 no contrato atual;
- habilita Private Google Access por padrão;
- usa região e CIDR explícitos fornecidos pelo caller;
- não cria firewall rules, NAT nem recursos de IP externo.

O Google Cloud permite prefixos IPv4 de subnet de `/4` a `/29`, sujeitos às verificações de ranges proibidos/sobrepostos. O módulo valida localmente o contrato básico de IPv4/prefixo; o Google Cloud continua sendo a autoridade para conflitos com rotas existentes, redes peer e ranges reservados.

## Private Service Access

Private Service Access é separado da subnet de workloads. Ele reserva um range para uma producer network e estabelece uma relação de peering VPC por meio da Service Networking API.

O módulo cria:

```text
google_compute_global_address
  purpose      = VPC_PEERING
  address_type = INTERNAL
        |
        v
google_service_networking_connection
  service = servicenetworking.googleapis.com
```

O range alocado é fornecido como CIDR IPv4 explícito. Isso mantém o planejamento de endereços visível no Terraform em vez de permitir que um serviço do provider escolha um range arbitrário.

Para este blueprint, o intervalo de prefixos aceito é de `/8` a `/24`. O limite superior corresponde à orientação do Memorystore for Redis para Private Service Access, que exige `/24` ou um bloco maior ao estabelecer o range alocado.

O caller deve garantir que a alocação de Private Service Access não sobreponha subnets de workloads, outros ranges alocados de serviços, ranges de VPC peering, rotas VPN/Interconnect ou redes on-premises que possam se tornar alcançáveis posteriormente.

## Ciclo de vida do Service Networking

`google_service_networking_connection` usa `deletion_policy = "PREVENT"` por padrão neste módulo.

Isso é deliberado. Depois que serviços gerenciados consomem a conexão, excluí-la pode falhar ou quebrar conectividade. Um caller pode definir a política como `DELETE` em ambiente explicitamente descartável, mas essa é uma decisão de ciclo de vida no nível do ambiente e deve ser revisada antes do apply.

O módulo não expõe `ABANDON` nem `REMOVE_PEERING` como opções normais porque ambas podem deixar a relação do producer ou a conectividade em estado inesperado.

## Ownership das APIs

O módulo não habilita APIs do projeto. Antes do apply, os roots devem garantir que estejam habilitadas:

- `compute.googleapis.com`;
- `servicenetworking.googleapis.com`.

A habilitação de APIs possui ciclo de vida no projeto inteiro e pode ser compartilhada por vários módulos. Mantê-la fora deste módulo filho evita desabilitação acidental ou conflitos de ownership durante a remoção do módulo.

## Direct VPC egress

Cloud Run Direct VPC egress não exige Serverless VPC Access connector. `modules/cloud-run-service` e `modules/cloud-run-job` aceitam o mesmo objeto opcional `direct_vpc`:

```hcl
direct_vpc = {
  network    = "blueprint-vpc"
  subnetwork = "blueprint-us-central1"
  egress     = "PRIVATE_RANGES_ONLY"
  tags       = ["serverless"]
}
```

O módulo de rede expõe um baseline diretamente componível:

```hcl
direct_vpc = module.network.direct_vpc
```

Esse output contém apenas `network` e `subnetwork`; os módulos Cloud Run fornecem o padrão seguro de egress e conjunto vazio de tags.

### Padrões e semântica de roteamento

`direct_vpc = null` é o padrão para os dois módulos de workload. Nesse estado nenhum bloco `vpc_access` é renderizado, preservando o comportamento de callers existentes.

Quando Direct VPC está habilitado:

- `network` e `subnetwork` são obrigatórios e não podem estar vazios;
- `egress` usa `PRIVATE_RANGES_ONLY` por padrão;
- callers podem escolher explicitamente `ALL_TRAFFIC`;
- tags de rede opcionais são validadas antes de chegar ao provider;
- nenhum Serverless VPC Access connector é criado ou aceito pelo contrato.

`PRIVATE_RANGES_ONLY` é o padrão porque dependências privadas como Memorystore podem usar a VPC enquanto tráfego público comum mantém o caminho normal da plataforma. `ALL_TRAFFIC` é uma decisão explícita do ambiente e pode exigir Cloud NAT ou outro desenho de egress para internet; este repositório não cria esses recursos implicitamente.

### Ownership de região

A localização do Cloud Run service/job e a região da subnet continuam entradas independentes. Os roots de ambiente são responsáveis por compor uma subnet válida para o workload Cloud Run alvo. O módulo de rede expõe `subnet_region` para que os roots validem ou documentem essa política sem que módulos filhos acessem uns aos outros.

## Composição

Um root pode compor as capacidades sem dependências ocultas:

```hcl
module "network" {
  source = "../../modules/vpc-network"

  # ...
}

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

Terraform infere a dependência network-before-workload por esses valores. Nenhum `depends_on` explícito é necessário.

## Exclusões deliberadas

A capacidade de rede não cria:

- Serverless VPC Access connectors;
- Cloud NAT ou Cloud Router;
- firewall rules de workloads;
- configuração de host/service project de Shared VPC;
- recursos Memorystore.

Essas capacidades devem ser adicionadas somente quando um requisito concreto de workload as justificar, em vez de ampliar o módulo preventivamente.
