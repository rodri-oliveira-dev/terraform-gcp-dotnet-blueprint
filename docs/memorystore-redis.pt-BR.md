# Memorystore for Redis

## Propósito

A arquitetura de referência usa Memorystore for Redis como cache gerenciado privado acessível por workloads Cloud Run via Direct VPC egress.

Redis é intencionalmente modelado como capacidade própria. O módulo Redis consome uma VPC existente e assume que Private Service Access já existe; ele não é responsável por rede, Cloud Run, identidades ou segredos da aplicação.

## Caminho de rede

O caminho pretendido é:

```text
Cloud Run Service / Job
        |
        | Direct VPC egress
        v
Subnet de workloads / VPC
        |
        +------------------------------+
        |                              |
        v                              v
Private Google APIs             Service Networking peering
                                       |
                                       v
                              Memorystore for Redis
```

`modules/vpc-network` cria VPC em modo customizado, subnet de workloads, range alocado de Private Service Access e a conexão com `servicenetworking.googleapis.com`.

`modules/memorystore-redis` recebe somente o ID completo da VPC e fixa `connect_mode` em `PRIVATE_SERVICE_ACCESS`. O root de composição também deve garantir que a conexão Service Networking esteja estabelecida antes da instância Redis. No exemplo isolado isso é representado por `depends_on = [module.network]`.

O Google Cloud recomenda Private Service Access em vez de direct peering para Memorystore for Redis. O módulo, portanto, não expõe `DIRECT_PEERING` como modo suportado.

## Padrões de segurança

O módulo usa por padrão:

- tier `STANDARD_HA`;
- Redis 7.2;
- Redis AUTH habilitado;
- criptografia TLS em trânsito com `SERVER_AUTHENTICATION`;
- VPC autorizada explícita;
- prevenção de exclusão no provider.

Esses padrões são orientados a produção, e não ao menor custo. Um caller pode escolher `BASIC` explicitamente, mas AUTH e TLS permanecem habilitados a menos que sejam desabilitados de forma independente.

## Limite do Redis AUTH

Quando AUTH está habilitado, o Memorystore gera a AUTH string. O provider Terraform expõe essa string como atributo calculado sensível.

O módulo não retorna a AUTH string por output nem a grava em uma versão do Secret Manager. Isso preserva a regra do repositório de que o ciclo de vida de payloads de segredos é gerenciado fora da configuração Terraform.

Um operador ou processo de entrega confiável deve recuperar a AUTH string usando a permissão Google Cloud de escopo mínimo necessária e colocá-la no mecanismo de entrega de segredos da aplicação. Rotação deve ser tratada como procedimento operacional porque alternar Redis AUTH gera novo valor.

O state Terraform continua sensível: valores calculados pelo provider podem persistir nele mesmo sem serem outputs. Os controles de state remoto GCS em `bootstrap/state` continuam, portanto, parte do limite de segurança do Redis.

## Limite de TLS

`SERVER_AUTHENTICATION` criptografa o tráfego cliente/servidor Redis. Memorystore suporta TLS 1.2 ou superior para esse recurso.

Um cliente com TLS deve:

1. conectar no host e secure port reportados pelo provider;
2. autenticar quando AUTH estiver habilitado;
3. confiar na server CA exposta pelo Memorystore;
4. lidar com rotação de certificado e reconexões transitórias.

O módulo deliberadamente não emite payloads do certificado CA. Recuperação e instalação da CA pertencem à entrega da aplicação/runtime, não à interface do módulo de infraestrutura.

## Disponibilidade e sizing

`STANDARD_HA` é o tier padrão porque fornece alta disponibilidade primary/replica entre zonas. Callers podem fornecer `location_id` e `alternative_location_id` distintos; caso contrário, o Google Cloud escolhe as zonas.

`BASIC` permanece útil para desenvolvimento ou ambientes explicitamente descartáveis. O módulo rejeita `alternative_location_id` com tier BASIC porque esse campo só tem significado para `STANDARD_HA`.

A memória é configurável entre 1 e 300 GiB. A escolha de capacidade permanece uma decisão do ambiente.

## Contrato de versão do Redis

O módulo limita intencionalmente o contrato público a:

- `REDIS_6_X`;
- `REDIS_7_0`;
- `REDIS_7_2`.

Versões mais antigas suportadas pela API subjacente são excluídas para evitar que novos ambientes adotem versões legadas acidentalmente. Redis 7.2 é o padrão.

## Ciclo de vida

O recurso Redis usa `deletion_policy = "PREVENT"` por padrão. Um caller deve fazer mudança deliberada para `DELETE` antes que Terraform possa destruir a instância.

Criptografia em trânsito é propriedade de segurança definida na criação do Memorystore e não pode simplesmente ser desabilitada depois em uma instância criada com TLS. Trate mudanças de segurança de transporte como sensíveis ao ciclo de vida e revise o plan antes do apply.

## Pré-requisitos de API

Roots que consomem a capacidade completa de rede/cache precisam de:

- `compute.googleapis.com`;
- `servicenetworking.googleapis.com`;
- `redis.googleapis.com`.

Essas APIs no nível do projeto não são habilitadas pelos módulos filhos porque o ciclo de vida de APIs é responsabilidade do root/projeto.

## Exclusões deliberadas

Esta implementação não adiciona:

- Memorystore for Redis Cluster ou Valkey;
- autenticação IAM para Redis Cluster;
- scaling de read replicas;
- configuração de persistência Redis;
- configuração CMEK;
- replicação da AUTH string para Secret Manager;
- recursos de firewall/NAT;
- configuração de cliente específica da aplicação.

Esses itens devem ser introduzidos somente quando um requisito concreto justificar a complexidade adicional de ciclo de vida e operação.
