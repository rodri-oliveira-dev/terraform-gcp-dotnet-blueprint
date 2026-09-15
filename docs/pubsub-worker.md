# Padrão de worker Pub/Sub orientado a eventos

O blueprint separa dois modelos de execução:

1. **processamento orientado a eventos** usa entrega push do Pub/Sub para um Cloud Run Service que atende requisições;
2. **processamento batch finito** usa Cloud Run Job iniciado explicitamente por um mecanismo suportado.

Este documento cobre o primeiro modelo. O comportamento de batch/Scheduler é documentado separadamente em `docs/batch-processing.md`.

## Fluxo de request

```text
Publisher
   |
   v
Tópico Pub/Sub principal
   |
   v
Push subscription
   |  token OIDC: service account de push-auth
   v
Cloud Run Service (worker .NET)
   |
   +--> 2xx: mensagem confirmada
   |
   +--> falha / ack deadline excedido
             |
             v
          política de retry
             |
             +--> falha repetida --> tópico dead-letter --> subscription de inspeção
```

Pub/Sub não é modelado como invocação direta de Cloud Run Job. Uma push subscription exige endpoint HTTP que confirme entrega por status da resposta.

## Limites dos módulos

### `modules/cloud-run-service`

É responsável pelo runtime do worker orientado a requisições:

- imagem e recursos do container;
- scaling e concurrency;
- service account de runtime;
- environment variables e referências Secret Manager;
- ingress e proteção contra exclusão;
- Direct VPC egress opcional.

### `modules/pubsub`

É responsável pelo comportamento de transporte/entrega:

- tópico e subscription principais;
- configuração de push autenticado;
- acknowledgement deadline e retenção de mensagens;
- política de retry;
- tópico dead-letter e subscription de inspeção;
- IAM específico de transporte para o service agent do Pub/Sub.

### Composição no root/ambiente

É responsável pelas relações entre capacidades:

- concede `roles/run.invoker` à service account de push-auth no Cloud Run Service alvo;
- fornece URI do Cloud Run ao módulo Pub/Sub;
- fornece service accounts existentes de runtime e push-auth;
- concede permissão de publisher à identidade de runtime da API no tópico do ambiente;
- compõe segredos, Direct VPC egress, conectividade Redis e observabilidade;
- decide nomes, sizing, labels e política de ambiente.

Isso mantém os módulos reutilizáveis coesos e impede dependências implícitas entre eles.

## Modelo de identidades

O padrão usa três identidades distintas:

| Identidade | Responsabilidade | Exemplo de permissão |
| --- | --- | --- |
| Service account de runtime do worker | Credenciais usadas pelo código .NET | Permissões de runtime específicas, como acesso a segredos |
| Service account de push-auth | Identidade no token OIDC enviado ao Cloud Run | `roles/run.invoker` no service alvo |
| Service agent do Pub/Sub gerenciado pelo Google | Cria tokens OIDC e encaminha mensagens dead-letter | Token Creator na SA push-auth; publisher no tópico DLQ; subscriber na subscription origem |

Separar identidades evita conceder permissões da aplicação à identidade de transporte ou permissões de invocação à identidade de runtime.

## Semântica de entrega

O worker deve ser idempotente. O transporte pode repetir mensagem quando o endpoint retorna falha ou não confirma dentro do deadline. Encaminhamento dead-letter e máximo de tentativas são comportamentos best-effort, não garantias exactly-once.

O módulo reutilizável fornece inputs limitados de retry/retenção; os roots escolhem valores reais. Os ambientes de referência atuais usam thresholds de DLQ diferentes para demonstrar política de ambiente.

## Pré-requisitos de autenticação

Push autenticado exige:

- service account de push-auth no mesmo projeto da subscription;
- identidade de deployment autorizada a anexar/gerenciar as relações necessárias de service account;
- service agent Pub/Sub autorizado a criar tokens OIDC para a conta push-auth;
- conta push-auth com permissão para invocar o Cloud Run Service alvo.

O módulo usa membros IAM aditivos com escopo de recurso quando suportados, em vez de políticas autoritativas no projeto inteiro.

## Tratamento de falhas e observabilidade

O tópico dead-letter possui subscription de inspeção para reter mensagens com falha para inspeção do operador ou reprocessamento explícito. Reprocessamento não é automatizado porque repetir poison message sem correção pode criar loop infinito.

Os roots compõem políticas de alerta do Cloud Monitoring para idade de backlog e encaminhamento dead-letter por `modules/observability-alerts`. Thresholds operacionais diferem entre `dev` e `prod`; procedimentos específicos de retry/replay do produto continuam responsabilidade da aplicação/operações.

Consulte `docs/observability.md`, `docs/environments.md` e `docs/troubleshooting.md`.
