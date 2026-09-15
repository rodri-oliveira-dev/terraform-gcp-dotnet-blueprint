# Exemplo de Memorystore for Redis

Este root isolado compõe a fundação de VPC/Private Service Access do repositório com o módulo seguro Memorystore for Redis.

Ele demonstra:

- VPC em modo customizado e subnet de workloads;
- alocação explícita de Private Service Access e conexão Service Networking;
- instância Redis 7.2 `STANDARD_HA`;
- Redis AUTH habilitado;
- criptografia TLS em trânsito habilitada;
- prevenção de exclusão no provider;
- dependência explícita entre módulos para que Memorystore seja criado somente após Private Service Access existir.

## Pré-requisitos

O projeto alvo precisa ter estas APIs habilitadas antes do apply:

- `compute.googleapis.com`;
- `servicenetworking.googleapis.com`;
- `redis.googleapis.com`.

A identidade de deployment precisa de permissões para gerenciar os recursos VPC/Private Service Access e a instância Memorystore.

## Validar sem criar infraestrutura

```bash
terraform init -backend=false -input=false -lockfile=readonly
terraform validate
terraform plan -input=false -var='project_id=my-project'
```

O exemplo não possui backend porque não é um root de ambiente de produção.

## Plano de endereçamento

O exemplo usa:

```text
Subnet de workloads:     10.20.0.0/24
Private Service Access:  10.30.0.0/16
```

Memorystore usa `PRIVATE_SERVICE_ACCESS` e consome um range disponível dessa alocação. Ambientes reais devem coordenar esses ranges com VPCs existentes, peering, rotas VPN/Interconnect e redes on-premises.

## AUTH e TLS

A Redis AUTH string é gerada pelo Memorystore. O state do provider Terraform pode conter esse valor sensível calculado, portanto o state remoto deve ser tratado como sensível mesmo que o exemplo não exponha o valor como output.

O exemplo também habilita TLS. Clientes devem suportar TLS 1.2 ou superior e confiar na server CA do Memorystore. Recuperação de AUTH, distribuição de CA e configuração do cliente da aplicação permanecem passos operacionais explícitos fora deste exemplo Terraform.

## Composição com Cloud Run

`module.network.direct_vpc` pode ser passado para Cloud Run Service ou Job para que o workload alcance o endpoint privado Redis sem Serverless VPC Access connector:

```hcl
direct_vpc = module.network.direct_vpc
```

Mantenha `PRIVATE_RANGES_ONLY` a menos que o workload precise intencionalmente rotear todo o tráfego de saída pela VPC.

## Aviso de ciclo de vida

A conexão Service Networking e a instância Redis usam prevenção de operações destrutivas por padrão. Aplicar este exemplo cria recursos reais e cobrados no Google Cloud. Agentes e CI não devem executar `terraform apply` ou `terraform destroy` sem autorização explícita.
