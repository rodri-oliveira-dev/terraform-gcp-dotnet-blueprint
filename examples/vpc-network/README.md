# Exemplo de rede VPC

Este root isolado demonstra a fundação de rede introduzida pela issue #19.

Ele cria:

- uma VPC em modo customizado;
- uma subnet IPv4 regional de workloads;
- Private Google Access nessa subnet;
- um range explicitamente alocado de Private Service Access;
- uma conexão Service Networking com `servicenetworking.googleapis.com`.

Ele **não** cria workloads Cloud Run, Serverless VPC Access connectors, Redis, firewall rules, Cloud NAT ou Cloud Router.

## Pré-requisitos

Antes de planejar ou aplicar, o projeto alvo deve ter estas APIs habilitadas:

- `compute.googleapis.com`;
- `servicenetworking.googleapis.com`.

A identidade de deployment também precisa de permissões para criar recursos VPC/subnet/global-address e gerenciar a conexão private service networking.

## Validar sem criar infraestrutura

```bash
terraform init -backend=false -input=false -lockfile=readonly
terraform validate
terraform plan -input=false -var='project_id=my-project'
```

O exemplo não possui backend porque não é root de ambiente de produção.

## Plano de endereçamento

O exemplo usa:

```text
Subnet de workloads:     10.20.0.0/24
Private Service Access:  10.30.0.0/16
```

Esses ranges são apenas exemplos. Roots reais devem coordenar CIDRs com VPCs existentes, peering, rotas VPN/Interconnect, política Shared VPC e outros ranges alocados.

## Contrato Direct VPC para workloads

O root expõe `output.direct_vpc`, que pode ser passado diretamente a qualquer módulo Cloud Run:

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

O output fornece nomes da network e subnetwork. Os módulos usam Direct VPC egress `PRIVATE_RANGES_ONLY` e nenhuma network tag por padrão. Um caller que intencionalmente roteia todo tráfego de saída pela VPC pode estender o objeto:

```hcl
direct_vpc = merge(module.network.direct_vpc, {
  egress = "ALL_TRAFFIC"
  tags   = ["serverless"]
})
```

`ALL_TRAFFIC` pode exigir Cloud NAT ou outro desenho de internet-egress; este exemplo não cria essa infraestrutura.

## Aviso de ciclo de vida

A conexão Service Networking usa `deletion_policy = "PREVENT"` por padrão. Isso evita remoção acidental de conexão de serviços privados que pode posteriormente ser usada por Memorystore ou outro producer service.

Aplicar este exemplo cria recursos reais de rede no Google Cloud. Agentes e CI não devem executar `terraform apply` ou `terraform destroy` sem autorização explícita.
