# Troubleshooting

Este guia cobre modos de falha comuns do blueprint. Use-o junto com a documentação específica de cada componente, e não como substituto para diagnósticos do provider/serviço.

## Backend remoto e state

### `terraform init` não consegue acessar o backend GCS

Verifique:

- `GCP_TERRAFORM_STATE_BUCKET` corresponde ao bucket criado por `bootstrap/state`;
- a identidade de deployment/operador possui acesso a objetos nesse bucket;
- o root selecionado usa o prefixo fixo esperado (`environments/dev` ou `environments/prod`);
- Application Default Credentials/WIF estão realmente ativos no contexto de execução;
- políticas da organização não bloqueiam o caminho de acesso ao bucket/projeto.

Não contorne autorização de backend copiando state para o repositório ou retornando o root do ambiente para state local.

### Problemas de lock ou geração do state

Um run interrompido/com falha pode deixar uma operação que exige investigação. Não automatize `force-unlock` como correção genérica.

1. Confirme que nenhuma operação Terraform ainda está em execução.
2. Identifique o ambiente/root e a geração atual do state GCS.
3. Preserve evidências antes de modificar o state.
4. Use `force-unlock` somente quando o lock estiver comprovadamente obsoleto e o lock ID for compreendido.

Para suspeita de corrupção, siga a sequência de recovery em `docs/production-readiness.md` e `bootstrap/state/README.md`.

### Ações inesperadas de create/delete/replacement

Pare antes do apply. Causas comuns incluem:

- projeto ou bucket/prefixo de state incorreto;
- variáveis do repositório apontando para o ambiente errado;
- mudanças de provider/versão;
- recursos alterados manualmente (drift);
- endereços/recursos Terraform renomeados;
- mudanças em deletion protection ou ativação unidirecional.

Compare state atual, projeto selecionado, commit Git e configuração antes de continuar.

## Workload Identity Federation

### `google-github-actions/auth` não consegue trocar o token

Verifique:

- o workflow executa a partir de `refs/heads/main` quando usa a condição de confiança padrão;
- `GCP_WORKLOAD_IDENTITY_PROVIDER` é o nome completo do recurso do provider;
- `GCP_SERVICE_ACCOUNT` é a service account de deployment pretendida;
- `repository_owner_id` e `repository_id` imutáveis do bootstrap correspondem ao repositório atual;
- o principal ainda possui `roles/iam.workloadIdentityUser` na service account de deployment;
- IAM Credentials API e STS API estão habilitadas no projeto WIF.

Logo após criar/alterar pool/provider, considere eventual consistency antes de concluir que a expressão de confiança está incorreta.

### Autenticação funciona, mas Terraform recebe `403`

WIF comprova identidade, não autorização. Inspecione a permissão exata no erro do provider/API e compare com o mapa de capacidades de deployment em `docs/terraform-deployment.md`.

Não resolva isso adicionando `roles/owner` ou `roles/editor`. Adicione a permissão restrita de capacidade/recurso exigida pela operação.

## Erros de provider e API

### API está desabilitada

Os roots de ambiente declaram os serviços necessários usando `google_project_service`. Um plan pode, portanto, mostrar habilitação de APIs como parte do state desejado.

Se o Terraform nem consegue inspecionar/gerenciar Service Usage, certifique-se de que a identidade de deployment possui as permissões necessárias de Service Usage e que a política organizacional permite habilitação.

`gcp-integration-preflight.sh` pode ser usado em um contexto confiável e read-only de operador para comparar o catálogo de APIs necessárias com o projeto dev selecionado.

### Incompatibilidade de schema/versão do provider

Verifique:

- `.terraform-version` e a versão Terraform usada pelo runner;
- constraints de `required_providers`;
- `.terraform.lock.hcl` commitado para roots executáveis;
- se mudanças de provider pelo Dependabot atualizaram lock files de forma consistente.

Execute os mesmos gates offline do CI antes de atribuir a falha ao GCP.

## VPC e Private Service Access

### Conexão PSA não pode ser criada

Verifique:

- `servicenetworking.googleapis.com` está disponível/habilitado conforme planejado;
- o CIDR PSA alocado não sobrepõe a subnet de workloads ou redes roteadas;
- a identidade de deployment pode gerenciar a rede e a relação Service Networking;
- o identificador de VPC passado ao Redis é a rede esperada do ambiente.

Não use a subnet de workloads como alocação PSA. São preocupações de endereçamento separadas.

### Cloud Run não consegue alcançar o Redis

Verifique:

- Direct VPC egress está configurado no service/job;
- service/job e subnet estão em regiões/configuração compatíveis;
- Redis usa a VPC/conexão Private Service Access esperada;
- configuração da aplicação usa host/porta Redis fornecidos pelo Terraform;
- configurações de TLS e AUTH correspondem à instância Redis e aos valores do bootstrap externo de segredos.

O blueprint não cria Serverless VPC Access connector, portanto o troubleshooting não deve presumir que um exista.

## Memorystore for Redis

### Criação do Redis falha

Causas típicas:

- conexão/range PSA ainda não pronto ou inválido;
- combinação de região/tier/versão não suportada;
- IAM insuficiente;
- limites de quota/capacidade;
- restrições de deletion protection/update em uma instância existente.

Revise o erro exato do provider/API antes de alterar a topologia de rede.

### Aplicação não consegue autenticar ou validar TLS

Terraform não entrega payloads de Redis AUTH ou server CA à aplicação. Verifique se o processo externo confiável de bootstrap populou as versões esperadas do Secret Manager e se as identidades de runtime possuem `secretAccessor` no segredo correto.

Nunca imprima payloads de segredo AUTH/CA nos logs de CI ao diagnosticar conectividade.

## Secret Manager

### Revisão do Cloud Run falha porque uma versão de segredo está ausente

Isso geralmente indica que o ambiente foi ativado antes de concluir a fase externa de bootstrap dos segredos.

1. Inspecione `terraform output secret_bootstrap` para o ambiente.
2. Verifique se cada segredo referenciado possui a versão atual esperada.
3. Verifique se a identidade de runtime do workload possui permissão de accessor no segredo.
4. Execute um novo plan antes do apply.

Não adicione `google_secret_manager_secret_version` com payloads plaintext apenas para contornar o limite de ciclo de vida.

## Cloud Run Services

### Serviço foi implantado, mas não está publicamente acessível

Este comportamento é esperado. Os roots de referência não concedem invocação não autenticada e o ingress padrão do serviço é restritivo.

Se acesso público for requisito do produto, desenhe uma solução explícita de edge/autenticação (por exemplo, padrão de external load balancer/API gateway), em vez de adicionar silenciosamente `allUsers` ao baseline do blueprint.

### Revisão não fica pronta

Investigue:

- URI/acessibilidade da imagem do container;
- comportamento de startup e contrato de porta;
- referências de segredos ausentes/inválidas;
- permissões da service account de runtime;
- dependências de VPC/Redis;
- configuração de CPU/memória e logs da aplicação.

Terraform pode criar o recurso de service, mas não consegue comprovar que a aplicação de negócio está saudável.

## Fluxo do worker Pub/Sub

### Entrega push recebe 401/403

Verifique:

- subscription push usa a service account dedicada de push;
- worker possui binding `roles/run.invoker` no escopo de recurso para essa identidade;
- OIDC audience corresponde à URI do worker;
- permissões de criação de token do service agent do Pub/Sub permanecem corretas onde gerenciadas pelo módulo.

Não conceda invocação pública para fazer o push autenticado funcionar.

### Mensagens acumulam ou vão para DLQ

Revise:

- readiness/erros do worker;
- ack deadline e tempo de processamento;
- política de retry;
- comportamento de idempotência;
- máximo de tentativas de entrega da DLQ;
- alertas de `oldest_unacked_message_age` e dead-letter.

Uma DLQ é evidência de entrega esgotada, não substituto para processo de replay/reparo.

## Cloud Run Job e Scheduler

### Scheduler não consegue iniciar o job

O target do Scheduler é a URI de execução da Cloud Run Admin API, não um endpoint de requisição do job.

Verifique:

- a identidade dedicada do Scheduler possui `roles/run.invoker` no job;
- configuração de token OAuth usa essa identidade;
- nome/localização/URI do job pertencem ao ambiente selecionado;
- APIs Scheduler e Cloud Run estão habilitadas/autorizadas.

### Job inicia, mas falha

Inspecione logs da execução e verifique imagem, referências de segredos, IAM de runtime, conectividade Redis, premissas de task/parallelism e idempotência da aplicação. O baseline de monitoring alerta para execuções concluídas com falha, mas não diagnostica lógica da aplicação.

## Cloud Monitoring

### Política de alerta existe, mas nunca dispara

Confirme:

- o recurso alvo realmente emite a métrica selecionada;
- existe tráfego/execuções durante a janela de avaliação;
- threshold/duration são adequados;
- comportamento de dados ausentes é compreendido;
- nomes de recurso/região no ambiente correspondem aos labels do recurso monitorado.

Alertas de infraestrutura não são SLOs universais.

### Alerta dispara, mas nenhuma notificação chega

O blueprint não cria destinos de notificação. Verifique se os nomes de recursos em `observability_notification_channels` existem e se seus destinos/credenciais de integração, gerenciados pela organização, são válidos.

## Workflows de deployment do GitHub

### Plan manual se recusa a executar em feature branch

Comportamento esperado. Workflows autenticados são restritos à `main` para corresponder ao limite de confiança WIF.

### Apply para porque o fingerprint do plan mudou

Ambiente/state/data sources mudaram entre o plan pré-aprovação e o replan do apply. Isso é uma parada de segurança. Inicie um novo run de deployment e revise o novo plan em vez de ignorar o fingerprint.

### Apply bloqueia ações de delete/replacement

`allow_destroy` usa `false` por padrão. Um replacement inclui uma ação delete e é intencionalmente bloqueado a menos que quem dispara faça opt-in explícito após revisão. Proteções de exclusão de lifecycle/provider ainda podem bloquear a operação mesmo com `allow_destroy=true`.

### Ativação de workloads não pode voltar para `false`

Esperado após uma ativação aplicada. O activation lock impede um caminho de teardown parcial. Para descomissionar intencionalmente um ambiente, desenhe e revise um procedimento dedicado de decommission em vez de usar a flag de bootstrap como switch de destroy.

## Quando parar e escalar

Pare antes do apply quando:

- projeto/prefixo de state selecionado for incerto;
- um plan contiver deletes/replacements inesperados;
- recovery de state ou force-unlock estiver sendo considerado;
- IAM precisar ser ampliado além do limite documentado de capacidade;
- payloads de segredos aparecerem em logs/plans/configuração;
- mudanças de rede puderem sobrepor CIDRs corporativos existentes;
- um deployment de produção exigir remoção de proteções.

Nesses casos, o blueprint favorece revisão explícita por operador em vez de recovery automatizado.
