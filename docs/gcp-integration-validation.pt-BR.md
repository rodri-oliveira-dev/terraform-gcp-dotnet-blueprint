# Validação de integração em GCP real

A issue #29 define como o blueprint é validado contra APIs reais do control plane do Google Cloud sem transformar a validação de pull requests em um caminho de deployment.

O alvo da validação é **somente desenvolvimento**. Produção fica deliberadamente fora do escopo.

## Camadas de validação

O repositório usa três camadas distintas:

| Camada | Credenciais | Acesso ao Google Cloud | Mutação |
| --- | --- | --- | --- |
| CI de pull request | nenhuma | nenhum | nunca |
| `Terraform plan` manual na `main` | WIF | backend/APIs de provider reais | nunca |
| `Terraform apply` controlado | WIF | backend/APIs de provider reais | somente deployment explicitamente aprovado |

A issue #29 diz respeito à segunda camada. Ela não autoriza nem exige apply.

## Definição de validação em GCP real

Uma validação de desenvolvimento é considerada real somente quando todos os itens abaixo forem verdadeiros:

1. o run é disparado a partir de `refs/heads/main`;
2. GitHub OIDC consegue trocar o token pelo provider Workload Identity Federation configurado;
3. a service account dedicada de deployment é impersonada sem chave de service account;
4. `terraform init` inicializa `environments/dev` contra o backend GCS protegido;
5. Terraform consegue ler o state atual de desenvolvimento e adquirir o lock de backend necessário para o plan;
6. inicialização do provider conclui com o lock file commitado;
7. `terraform plan` conclui com refresh habilitado contra o projeto real de desenvolvimento;
8. Job Summary contém somente endereços/ações de recursos seguros para revisão, sem upload do plan binário nem do JSON completo.

O `.github/workflows/terraform-plan.yml` existente é o caminho canônico de execução WIF para essas verificações. A issue #29 não cria um segundo workflow privilegiado.

## Pré-requisitos

Antes de executar a validação, configure as repository variables documentadas em `docs/terraform-deployment.md`, incluindo:

- `GCP_WORKLOAD_IDENTITY_PROVIDER`;
- `GCP_SERVICE_ACCOUNT`;
- `GCP_TERRAFORM_STATE_BUCKET`;
- `GCP_DEV_PROJECT_ID`;
- as três variáveis de imagem de container de desenvolvimento;
- `TF_DEV_ENABLE_WORKLOADS` correspondente ao estado real desejado de ativação.

O projeto de desenvolvimento deve estar suficientemente isolado para que um Terraform plan possa inspecionar com segurança seu state e APIs. A identidade de deployment precisa do acesso de leitura exigido pelos refreshes do provider, além de acesso aos objetos do state GCS. Se o plan também deve descrever mudanças futuras, ela precisa das permissões específicas de capacidade documentadas para a identidade de deployment em `docs/terraform-deployment.md`.

Não conceda `roles/owner` ou `roles/editor` apenas para fazer a validação passar.

## Helper de preflight do catálogo de APIs

`.github/scripts/gcp-integration-preflight.sh` é um helper read-only para operadores. Ele verifica:

- se é possível obter access token da identidade Google Cloud atual;
- se o projeto de desenvolvimento configurado pode ser resolvido;
- se todas as APIs declaradas em `environments/dev/local.required_services` existem no catálogo Service Usage;
- quais desses serviços estão atualmente habilitados.

O helper não habilita APIs. Um serviço desabilitado é reportado, e não tratado como falha, porque `environments/dev` é intencionalmente responsável pela habilitação dos serviços por meio de recursos `google_project_service`.

Execute o helper apenas em um contexto confiável e autenticado de operador:

```bash
export GCP_PROJECT_ID="my-dev-project"
export GITHUB_STEP_SUMMARY="$(mktemp)"
bash .github/scripts/gcp-integration-preflight.sh
cat "$GITHUB_STEP_SUMMARY"
```

Para GitHub Actions, WIF permanece o mecanismo oficial de autenticação. O helper não é ligado intencionalmente a outro workflow autenticado.

## Helper de cobertura do plan

`.github/scripts/terraform-plan-coverage.sh` verifica um saved plan de desenvolvimento sem ler nem imprimir valores planejados. Ele inspeciona somente os nomes de tipos de recursos Terraform e verifica a representação dos principais contratos arquiteturais:

- Cloud Run Service;
- Cloud Run Job;
- Cloud Scheduler;
- VPC e subnet;
- alocação/conexão de Private Service Access;
- tópico/subscription Pub/Sub;
- Secret Manager;
- Memorystore for Redis;
- política de alerta do Cloud Monitoring.

Exemplo para reprodução local confiável:

```bash
export TF_ROOT="environments/dev"
export GITHUB_STEP_SUMMARY="$(mktemp)"
bash .github/scripts/terraform-plan-coverage.sh /path/to/dev.tfplan
cat "$GITHUB_STEP_SUMMARY"
```

O workflow de plan do GitHub deliberadamente **não** envia seu plan binário como artifact porque plans podem conter valores sensíveis derivados do state. Portanto, este helper é principalmente útil para reprodução local confiável ou futura integração controlada em runner.

## Grafo completo versus fase de fundação

`environments/dev` possui ciclo de vida em duas fases.

Quando `TF_DEV_ENABLE_WORKLOADS=false`, um plan real valida o caminho da fundação: APIs, VPC/Private Service Access, Redis, identidades, metadados/IAM do Secret Manager e state remoto. Workloads Cloud Run, entrega Pub/Sub, Scheduler e suas políticas de alerta ficam intencionalmente ausentes.

Após o bootstrap dos segredos e a ativação unidirecional documentada para `TF_DEV_ENABLE_WORKLOADS=true`, o mesmo plan manual também exercita o grafo completo dos workloads.

Não altere temporariamente a repository variable apenas para deixar um checklist de validação verde. A variável deve representar o state real desejado do ambiente de desenvolvimento.

## Cobertura por capacidade

| Capacidade | O que a issue #29 pode validar sem apply | O que continua não comprovado |
| --- | --- | --- |
| Cloud Run Services | configuração/plan do provider; refresh de serviços existentes | startup de imagem, health e invocação |
| Cloud Run Job | configuração/plan do provider; refresh de job existente | execução bem-sucedida do job |
| Pub/Sub | plan de tópico/subscription/IAM; refresh quando existente | entrega, retry e comportamento de DLQ |
| Cloud Scheduler | configuração/plan do scheduler; refresh quando existente | trigger autenticado bem-sucedido |
| Secret Manager | plan de metadados/IAM; refresh quando existente | correção/disponibilidade do payload da aplicação |
| VPC / Private Service Access | plan de rede, subnet, range e conexão; refresh quando existente | criação bem-sucedida em um novo plano de endereçamento |
| Memorystore for Redis | plan da instância; refresh quando existente | conectividade AUTH/TLS do cliente e comportamento da aplicação |
| Cloud Monitoring | plan de políticas de alerta; refresh quando existente | produção de métricas, disparo de incidente e entrega de notificação |

Um plan bem-sucedido é mais forte que mocks offline porque usa provider real, backend real e projeto/state atual. Ainda assim, não equivale a criar e exercitar recursos com sucesso.

## Custos e limite de mutação

Esta validação não cria recursos Google Cloud e não contém etapa de apply/destroy. Ela executa apenas requests de leitura do control plane e operações de state/lock do backend.

Recursos de desenvolvimento já existentes podem gerar custos normais de serviço; esses custos não são criados pelo run de validação em si.

Qualquer smoke test futuro que crie recursos temporários com custo precisa ser uma capacidade separada, explícita e manual, com:

- autorização do usuário antes da mutação;
- escopo/custo máximo esperado documentado;
- ownership/labels determinísticos;
- procedimento explícito de cleanup;
- nenhuma execução automática em produção.

Nenhum smoke test que crie recursos faz parte da issue #29.

## Evidência necessária para fechar a issue #29

Não feche a issue #29 apenas porque esta documentação e o tooling foram mergeados. Registre um run manual bem-sucedido de `Terraform plan` a partir da `main` para `dev` e capture:

- workflow run ID;
- commit SHA;
- confirmação de sucesso da autenticação WIF;
- confirmação de sucesso da inicialização do backend GCS remoto;
- conclusão do Terraform plan (`0` sem mudanças ou `2` com mudanças);
- se `TF_DEV_ENABLE_WORKLOADS` estava `false` (cobertura da fundação) ou `true` (cobertura completa dos workloads);
- qualquer erro de provider/API descoberto e a correção ou limitação documentada.

A issue só pode ser considerada integralmente concluída depois que essa evidência existir. A validação de produção permanece fora do escopo.
