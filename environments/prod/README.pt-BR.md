# Ambiente de produção

Este root compõe os módulos reutilizáveis como contraparte de produção de `environments/dev`.

Ele mantém os mesmos limites arquiteturais de desenvolvimento, aplicando políticas explícitas de sizing, disponibilidade, retry, isolamento de state e observabilidade orientadas a produção.

## Diferenças de política de produção

Em comparação com `dev`, este root usa:

- prefixo GCS de backend separado: `environments/prod`;
- VPC, subnet, range Private Service Access, service accounts, segredos, recursos de mensageria e workloads separados;
- Memorystore `STANDARD_HA` em vez de `BASIC`;
- 5 GiB de capacidade Redis por padrão, configurável por `redis_memory_size_gb`;
- API: 2 vCPU / 1 GiB, mínimo 1 instância, máximo 20;
- worker: 1 vCPU / 1 GiB, mínimo 1 instância, máximo 20;
- threshold de dead-letter Pub/Sub de 20 tentativas e retry backoff até 600 segundos;
- batch: 4 tasks, parallelism 2, 2 vCPU / 2 GiB, 5 retries por task, timeout de 30 minutos;
- retry count do Scheduler de 5;
- thresholds de observabilidade mais rígidos que desenvolvimento.

Estes são padrões de referência, não requisitos universais de produção. Planejamento de capacidade, SLOs, perfil de tráfego, objetivos de recovery e orçamento devem orientar valores finais em sistema real.

## Deployment em duas fases

Payloads de segredos da aplicação e material AUTH/CA gerado pelo Memorystore ficam fora do Terraform, portanto produção usa o mesmo processo controlado em duas fases de desenvolvimento:

1. Mantenha `enable_workloads = false` e aplique a fundação: APIs, rede, Redis, identidades, metadados Secret Manager e IAM.
2. Popule as versões Secret Manager listadas por `terraform output secret_bootstrap` usando processo confiável. Nunca registre nem commite payloads Redis AUTH ou CA.
3. Defina `enable_workloads = true`, revise o plan completo de produção, obtenha a aprovação necessária e aplique workloads e políticas de alerta.

Isso evita `terraform -target` como modelo normal de deployment e impede que variables/source Terraform carreguem payloads de segredos. Depois que os workloads de produção forem ativados neste state, mudar `enable_workloads` de volta para false é intencionalmente rejeitado pelo activation lock.

## Observabilidade

Padrões de produção:

- taxa HTTP 5xx do Cloud Run: 5%;
- mensagem Pub/Sub não confirmada mais antiga: 300 segundos;
- uso de memória de dados/sistema Redis: 80%;
- qualquer encaminhamento dead-letter, execução Cloud Run Job com falha ou conexão Redis rejeitada permanece alertável.

`observability_notification_channels` aceita somente nomes de recursos de canais existentes do Cloud Monitoring. E-mails, webhook URLs, chaves de integração PagerDuty e configuração similar de destino devem ser gerenciados fora deste root.

Esses thresholds são baselines operacionais, não compromissos SLO. Defina SLIs/SLOs de produto independentemente e use burn-rate alerting somente quando houver SLI confiável e meta definida. Consulte `../../docs/observability.md` para o modelo operacional completo.

## State remoto

Produção possui prefixo fixo de state:

```hcl
prefix = "environments/prod"
```

Inicialize o backend com o bucket protegido criado por `bootstrap/state`:

```bash
terraform init \
  -backend-config="bucket=YOUR_TERRAFORM_STATE_BUCKET"
```

Para validação sem credenciais:

```bash
terraform init -backend=false
terraform validate
```

Os prefixos `dev` e `prod` nunca devem ser reutilizados para outro ambiente.

## Configuração

Copie o arquivo de exemplo localmente e mantenha tfvars reais fora do commit:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Revise pelo menos:

- `project_id` de produção;
- image digests imutáveis ou release tags revisadas;
- alocação de CIDR e sobreposição com rotas existentes;
- `redis_memory_size_gb`;
- schedule e time zone do batch;
- thresholds de alerta de produção e nomes de recursos dos canais de notificação;
- labels de ownership/custo.

## Limites de segurança

- A API permanece autenticada e não pública por padrão; não existe grant `allUsers`.
- API, worker e batch usam identidades de runtime independentes.
- Pub/Sub push e Scheduler usam identidades dedicadas de transporte/trigger.
- Acesso publisher da API é restrito ao tópico de eventos de produção.
- Acesso a segredos é concedido em recursos individuais Secret Manager.
- Todos os workloads usam Direct VPC egress para alcançar a instância Redis de produção.
- Destinos de canais de notificação não são armazenados nesta configuração de ambiente.
- Payloads Redis AUTH e CA nunca são expostos como outputs Terraform.
- Valores sensíveis calculados pelo provider podem existir no state Terraform, portanto o bucket GCS faz parte do limite de segurança.
- Apply de produção permanece ação do operador/processo aprovado; validação de pull request é sem credenciais.

## Validação

O CI do repositório valida este root com provider lock file commitado e `terraform init -backend=false`, seguido por Terraform validation, formatting, tests, TFLint e Trivy. CI não deve criar recursos de produção.
