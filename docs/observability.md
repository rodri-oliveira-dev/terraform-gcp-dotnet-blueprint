# Arquitetura de observabilidade

A issue #24 adiciona observabilidade Google Cloud como capacidade arquitetural separada, em vez de incorporar recursos de alerta dentro dos módulos de workload.

## Limite

`modules/observability-alerts` consome nomes de recursos fornecidos por um root module e é responsável apenas pelas políticas de alerta do Cloud Monitoring. `environments/dev` e `environments/prod` conectam essa capacidade aos recursos que já possuem.

O módulo não é responsável por:

- Cloud Run, Pub/Sub, Cloud Run Jobs, Redis ou seus IAMs;
- canais de notificação ou seus destinos/segredos;
- bibliotecas de logging da aplicação ou configuração do SDK OpenTelemetry;
- métricas baseadas em logs;
- metas de SLO específicas de workload.

Canais de notificação são injetados como nomes de recursos existentes do Cloud Monitoring. E-mails, Slack webhooks, chaves de integração PagerDuty e outros destinos de escalonamento ficam fora deste repositório e podem ser gerenciados por um state Terraform da organização.

## Composição nos ambientes

Os dois roots de ambiente habilitam `monitoring.googleapis.com` em seu conjunto compartilhado de dependências de API. Políticas de alerta são criadas apenas depois de `enable_workloads = true`, pois têm como alvo API, worker, subscription Pub/Sub, batch job e instância Redis pertencentes ao ambiente.

Os ambientes usam deliberadamente thresholds operacionais diferentes:

| Sinal | Desenvolvimento | Produção |
| --- | ---: | ---: |
| Taxa HTTP 5xx do Cloud Run | 10% | 5% |
| Idade da mensagem Pub/Sub não confirmada mais antiga | 600 s | 300 s |
| Uso de memória de dados Redis | 90% | 80% |
| Uso de memória de sistema Redis | 90% | 80% |

Encaminhamento para dead-letter, execuções com falha de Cloud Run Jobs e conexões Redis rejeitadas disparam com qualquer evento observado nos dois ambientes.

Esses valores são padrões operacionais do blueprint. Não são SLOs contratuais e devem ser ajustados conforme tráfego observado, capacidade, histórico de incidentes e requisitos do produto.

## Sinais de plataforma selecionados

### Cloud Run Services

O sinal básico de disponibilidade é a taxa de respostas HTTP 5xx sobre todas as requests usando `run.googleapis.com/request_count` no monitored resource `cloud_run_revision`. A política agrega todas as revisions de um serviço antes de calcular a taxa, evitando fragmentar o sinal durante rollout.

### Pub/Sub

Dois modos de falha diferentes são monitorados na subscription principal:

- `pubsub.googleapis.com/subscription/oldest_unacked_message_age` identifica backlog persistentemente antigo, que pode indicar falha do subscriber ou throughput insuficiente;
- `pubsub.googleapis.com/subscription/dead_letter_message_count` reporta mensagens encaminhadas pelo Pub/Sub para dead-letter após esgotar tentativas de entrega.

Usar a métrica direta de dead-letter evita depender de um formato específico de backlog na subscription opcional de inspeção da DLQ.

### Cloud Run Jobs

`run.googleapis.com/job/completed_execution_count` é filtrado por `result="failed"` para o job configurado. Uma execução finita com falha é tratada como falha operacional orientada a evento, em vez de ser diluída em média por janela longa.

### Memorystore for Redis

Os sinais básicos de cache são:

- `redis.googleapis.com/stats/memory/usage_ratio` para pressão de memória de dados Redis;
- `redis.googleapis.com/stats/memory/system_memory_usage_ratio` para pressão de memória de sistema;
- `redis.googleapis.com/stats/reject_connections_count` para clientes rejeitados pela instância.

Redis é infraestrutura de suporte, não o SLO percebido pelo usuário. Alertas Redis ajudam diagnóstico e planejamento de capacidade; SLIs da API/workflow descrevem impacto ao cliente.

## Expectativas de logging estruturado para .NET

Cloud Logging recebe automaticamente stdout/stderr do Cloud Run. A aplicação deve emitir JSON estruturado em vez de depender de texto multilinha não estruturado.

Campos recomendados incluem:

- mensagem concisa e nível de severity mapeado;
- identificadores estáveis de aplicação/componente e ambiente;
- IDs de trace/span quando distributed tracing estiver habilitado;
- IDs de correlação de request/operação;
- identificadores de evento/categoria adequados à agregação;
- campos de duração e resultado para operações de negócio importantes;
- tipo de exception e stack trace em falhas.

Não registre credenciais, authorization headers, cookies, payloads do Secret Manager, Redis AUTH strings, dados pessoais que não sejam operacionalmente necessários ou request bodies completos por padrão.

Ownership da telemetria da aplicação fica fora do Terraform. A aplicação .NET pode usar `Microsoft.Extensions.Logging`, OpenTelemetry ou outra stack suportada, mas o repositório não impõe biblioteca. Terraform é responsável por recursos cloud e políticas de alerta de plataforma; o código da aplicação é responsável por eventos semânticos, traces, métricas customizadas e redaction.

## Orientação sobre SLI e SLO

Um SLI deve descrever comportamento experimentado por usuários ou sistemas upstream, não apenas a saúde de um componente de infraestrutura.

Pontos iniciais razoáveis:

- **disponibilidade da API:** requests elegíveis bem-sucedidas / total de requests elegíveis;
- **latência da API:** proporção de requests elegíveis abaixo de threshold definido pelo produto;
- **freshness assíncrona:** mensagens concluídas antes de uma idade alvo definida pelo produto;
- **confiabilidade do batch:** execuções agendadas bem-sucedidas / execuções esperadas na janela de medição.

Volume de DLQ, memória Redis, CPU, quantidade de instâncias e conexões rejeitadas são indicadores diagnósticos ou leading indicators valiosos, mas não devem virar SLOs de produto automaticamente.

Escolha metas de SLO a partir de requisitos de negócio e comportamento baseline observado. Para SLO expresso como percentual de sucesso, o error budget da janela é `1 - SLO target`; por exemplo, meta de 99,9% permite 0,1% de eventos elegíveis sem sucesso. O repositório não prescreve 99,9%, 99,95% ou outro alvo universal.

As políticas deste módulo são alertas operacionais de sintoma/capacidade. Burn-rate alerting deve ser adicionado somente depois que o workload tiver SLO real e fonte confiável de medição do SLI.

## Telemetria ausente

As condições de métrica do baseline tratam dados ausentes como inativos. Isso é apropriado para serviços que podem ficar intencionalmente ociosos e onde ausência de tráfego não equivale automaticamente a outage.

Um workload que exige heartbeat ou detecção de ausência de telemetria deve adicionar isso como política explícita do ambiente, em vez de alterar o significado dos alertas compartilhados.

## Dashboards

Nenhum dashboard customizado é criado. Cloud Run, Pub/Sub, Cloud Run Jobs, Memorystore e Cloud Monitoring já expõem views de métricas nativas, e um dashboard genérico que apenas repita esses gráficos adicionaria manutenção sem workflow claro de resposta a incidentes.

Um dashboard customizado se justifica quando operadores conseguem nomear uma pergunta durável que ele responde, como correlacionar taxa de erro da API, idade do backlog Pub/Sub e pressão Redis durante um incidente. Esse dashboard deve ser adicionado com objetivo operacional documentado, e não como cobertura decorativa.

## Fluxo do operador

1. Crie canais de notificação em processo controlado pela organização, quando necessários.
2. Coloque apenas seus nomes de recursos Cloud Monitoring em `observability_notification_channels`.
3. Revise os padrões do ambiente em `observability_thresholds` e ajuste-os quando houver evidência para mudança.
4. Conclua o bootstrap normal dos workloads em duas fases.
5. Quando `enable_workloads = true`, revise as políticas de alerta no plan Terraform junto aos recursos de workload.
6. Use `terraform output observability_alert_policy_ids` para localizar as políticas gerenciadas pelo ambiente.

O CI de pull request valida a configuração sem credenciais Google Cloud e nunca aplica políticas de alerta.
