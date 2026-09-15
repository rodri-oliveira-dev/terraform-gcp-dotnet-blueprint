# Composição dos ambientes

O repositório fornece dois root modules completos em `environments/`:

- `environments/dev` para validação de desenvolvimento com foco em custo;
- `environments/prod` com padrões de disponibilidade e sizing orientados a produção.

Os dois roots compõem as mesmas capacidades reutilizáveis e mantêm a política do ambiente no root, em vez de vazá-la para os módulos filhos.

## Arquitetura compartilhada

```text
Cloud Run API
    |-- Secret Manager
    |-- tópico Pub/Sub
    |-- Direct VPC egress --> Memorystore for Redis

Pub/Sub --> push autenticado --> Cloud Run worker
                                  |-- Secret Manager
                                  `-- Direct VPC egress --> Redis

Cloud Scheduler --> OAuth --> Cloud Run Admin API --> Cloud Run Job
                                                   |-- Secret Manager
                                                   `-- Direct VPC egress --> Redis

Políticas de alerta do Cloud Monitoring
    |-- taxa de 5xx do Cloud Run
    |-- backlog / DLQ do Pub/Sub
    |-- execuções com falha do Cloud Run Job
    `-- pressão / conexões rejeitadas do Redis
```

As identidades de runtime são separadas para API, worker e batch. Pub/Sub push e Cloud Scheduler usam identidades separadas de transporte/disparo. A API recebe permissão de publisher apenas no tópico específico do seu ambiente.

## Dev versus prod

| Política | dev | prod |
| --- | --- | --- |
| Prefixo de state | `environments/dev` | `environments/prod` |
| Subnet de workloads | `10.40.0.0/24` padrão | `10.60.0.0/24` padrão |
| Range PSA | `10.50.0.0/16` padrão | `10.70.0.0/16` padrão |
| Tier do Redis | `BASIC` | `STANDARD_HA` |
| Memória do Redis | 1 GiB | 5 GiB padrão |
| API | 1 vCPU / 512 MiB, min 0, max 2 | 2 vCPU / 1 GiB, min 1, max 20 |
| Worker | 1 vCPU / 512 MiB, min 0, max 2 | 1 vCPU / 1 GiB, min 1, max 20 |
| Threshold da DLQ Pub/Sub | 10 tentativas | 20 tentativas |
| Batch | 1 task, parallelism 1, 1 vCPU / 512 MiB | 4 tasks, parallelism 2, 2 vCPU / 2 GiB |
| Retries do Scheduler | 3 | 5 |
| Alerta 5xx do Cloud Run | 10% | 5% |
| Idade da mensagem Pub/Sub não confirmada mais antiga | 600 segundos | 300 segundos |
| Alertas de memória Redis | 90% | 80% |

Esses valores demonstram onde a política de ambiente deve ficar. São padrões de referência, não recomendações de capacidade nem SLOs contratuais para workloads arbitrários.

## Bootstrap de segredos em duas fases

Os dois roots usam `enable_workloads = false` por padrão porque os payloads de segredos da aplicação ficam intencionalmente fora do Terraform e o Memorystore gera material AUTH/CA somente após a criação.

A sequência suportada é:

1. inicializar o backend do ambiente;
2. executar plan/apply da fundação com workloads desabilitados;
3. popular versões dos IDs de segredos retornados por `secret_bootstrap` por meio de um processo confiável;
4. definir `enable_workloads = true`;
5. revisar o plan completo;
6. aplicar pelo caminho controlado de entrega.

Depois que a ativação dos workloads tiver sido aplicada como `true`, mudar de volta para `false` é intencionalmente rejeitado pelo activation lock. A flag é uma transição de bootstrap, não um switch genérico de destroy.

Não use `terraform -target` como estratégia normal de deployment e não passe payloads de segredos por variáveis Terraform.

## Isolamento de state

O mesmo bucket GCS protegido pode hospedar os dois roots, mas cada root possui um prefixo fixo:

```text
environments/dev
environments/prod
```

Isso impede que operações normais de state em um root atinjam o objeto de state do outro ambiente.

## Workflow de deployment

O CI de pull request sem credenciais usa `terraform init -backend=false` e nunca autentica no GCP.

Após o merge, workflows manuais na `main` fornecem o caminho controlado:

- **Terraform plan** — autenticado via WIF, inicializa o backend GCS real e produz um resumo seguro de ações/endereços sem enviar o plan binário;
- **Terraform apply** — exige ambiente/confirmação explícitos, bloqueia mudanças destrutivas por padrão, usa proteção de GitHub Environment, refaz o plan após aprovação e aplica somente quando o fingerprint do plan corresponde.

Consulte `docs/terraform-deployment.md`.

## Ingress público

Nenhum root concede invocação não autenticada. A URI da API pode existir, mas edge público, API Gateway, external load balancer, Cloud Armor, configuração de DNS/certificados ou binding `allUsers` ficam intencionalmente fora da arquitetura de referência v1.0.

A exposição pública deve ser uma decisão arquitetural separada e explícita.

## Observabilidade

Os dois roots de ambiente habilitam `monitoring.googleapis.com` e compõem `modules/observability-alerts` quando os workloads estão ativos.

O conjunto de sinais é compartilhado, enquanto os thresholds diferem por ambiente. Destinos de notificação são injetados como nomes de recursos de canais existentes do Cloud Monitoring e permanecem fora deste state.

Semântica de logging/tracing estruturado da aplicação, SLIs/SLOs de produto e política de burn-rate continuam sendo responsabilidades do workload. Consulte `docs/observability.md`.

## Orientação operacional

Para ordem de bootstrap, limites de IAM/segredos, recovery de state, proteção contra exclusão, checklist de adoção e orientação de prontidão da release, consulte `docs/production-readiness.md`. Para modos de falha comuns, consulte `docs/troubleshooting.md`.
