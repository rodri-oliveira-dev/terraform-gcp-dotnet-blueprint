# Deployment Terraform controlado com GitHub Actions

A issue #28 fecha o ciclo de entrega do blueprint sem enfraquecer a validação de pull requests. O CI comum de PR permanece sem credenciais; operações Terraform autenticadas são manuais, executadas a partir da `main` e autenticam no Google Cloud por Workload Identity Federation (WIF).

## Limite dos workflows

Três workflows separam intencionalmente validação, revisão e mutação:

| Workflow | Trigger | Credenciais cloud | Mutação |
| --- | --- | --- | --- |
| `Terraform CI` | PR / push para `main` | nenhuma | nunca |
| `Terraform plan` | `workflow_dispatch` manual | WIF | nunca |
| `Terraform apply` | `workflow_dispatch` manual | WIF | somente após verificações do plan e gate do ambiente |

Nenhum workflow de deployment executa em `pull_request`. Ambos rejeitam execução a partir de qualquer ref diferente de `refs/heads/main`, correspondendo à condição de confiança padrão provisionada por `bootstrap/github-actions-wif`.

## Variáveis obrigatórias do repositório

Os workflows de deployment usam intencionalmente **repository variables** do GitHub, e não repository secrets, para identificadores públicos e valores de configuração revisados.

Configure:

| Variável | Finalidade |
| --- | --- |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | nome completo do recurso do provider WIF em `bootstrap/github-actions-wif` |
| `GCP_SERVICE_ACCOUNT` | e-mail da service account de deployment impersonada via WIF |
| `GCP_TERRAFORM_STATE_BUCKET` | bucket GCS protegido que armazena o state Terraform |
| `GCP_DEV_PROJECT_ID` | projeto Google Cloud alvo de `environments/dev` |
| `GCP_PROD_PROJECT_ID` | projeto Google Cloud alvo de `environments/prod` |
| `TF_DEV_API_IMAGE` | URI da imagem do container da API de desenvolvimento |
| `TF_DEV_WORKER_IMAGE` | URI da imagem do worker de desenvolvimento |
| `TF_DEV_BATCH_IMAGE` | URI da imagem batch de desenvolvimento |
| `TF_DEV_ENABLE_WORKLOADS` | string exata `true` ou `false` correspondente ao estado desejado de ativação em desenvolvimento |
| `TF_PROD_API_IMAGE` | URI da imagem do container da API de produção |
| `TF_PROD_WORKER_IMAGE` | URI da imagem do worker de produção |
| `TF_PROD_BATCH_IMAGE` | URI da imagem batch de produção |
| `TF_PROD_ENABLE_WORKLOADS` | string exata `true` ou `false` correspondente ao estado desejado de ativação em produção |

O script seletor mapeia somente o ambiente escolhido para variáveis `TF_VAR_*`. Ele valida entradas obrigatórias e rejeita valores multilinha antes de exportá-los para o ambiente do runner.

`enable_workloads` é deliberadamente explícito. Os roots implementam ativação unidirecional dos workloads, portanto o workflow não pode silenciosamente cair para `false` depois que um ambiente tiver sido ativado.

## GitHub Environments

Crie GitHub Environments com estes nomes exatos:

- `dev`
- `prod`

O job de apply referencia o ambiente selecionado. Configure **Required reviewers** em `prod` e habilite **Prevent self-review** quando a governança do repositório permitir. O runner de apply de produção não inicia até que as regras de proteção do ambiente sejam satisfeitas.

O ambiente `dev` pode permanecer sem proteção ou usar uma política de aprovação mais leve, conforme o time.

Environment secrets não são exigidos por este desenho. Identificadores WIF e configuração de deployment permanecem repository variables, enquanto o Environment é usado como limite de proteção de deployment e registro de auditoria.

## Modelo de confiança WIF

`bootstrap/github-actions-wif` já restringe a federação por IDs imutáveis de owner/repositório GitHub e, por padrão, `refs/heads/main`.

Cada job autenticado concede apenas:

```yaml
permissions:
  contents: read
  id-token: write
```

Os workflows usam a action `google-github-actions/auth` já fixada. Nenhuma chave de service account, JSON key secret ou credencial Google Cloud de longa duração é introduzida.

O arquivo gerado `gha-creds-*.json` é efêmero e já é ignorado pelo repositório.

## Permissões da identidade de deployment

O bootstrap WIF cria intencionalmente a service account de deployment sem permissões de projeto dos workloads por padrão. Antes de usar os workflows de deployment, um operador deve conceder ao deployer as permissões necessárias ao ambiente selecionado.

Para este blueprint, o limite de permissões inclui:

- leitura/escrita dos objetos do backend GCS para o prefixo de state do ambiente;
- habilitação das APIs necessárias do projeto;
- criação/atualização de VPC e Private Service Access;
- gerenciamento do Memorystore for Redis;
- criação de service accounts de runtime/transporte e das relações IAM com escopo de recurso declaradas pelos roots/módulos;
- gerenciamento de Cloud Run services/jobs;
- gerenciamento de recursos Pub/Sub e seu IAM;
- gerenciamento de metadados do Secret Manager e IAM no escopo de segredo (não versões de payload);
- gerenciamento de jobs do Cloud Scheduler;
- gerenciamento de políticas de alerta do Cloud Monitoring.

Um deployment baseado em roles predefinidas normalmente começa por roles específicas de capacidade como `roles/serviceusage.serviceUsageAdmin`, `roles/compute.networkAdmin`, `roles/servicenetworking.networksAdmin`, `roles/redis.admin`, `roles/iam.serviceAccountAdmin`, `roles/iam.serviceAccountUser`, `roles/run.admin`, `roles/pubsub.admin`, `roles/secretmanager.admin`, `roles/cloudscheduler.admin`, `roles/monitoring.editor`, além de acesso de leitura como `roles/browser` quando necessário.

O bucket de state deve conceder à service account de deployment acesso a objetos no escopo do bucket (por exemplo, `roles/storage.objectAdmin`) em vez de administração ampla de Storage no projeto inteiro.

Trate essa lista de roles como um mapa de capacidades de referência, não como prescrição universal de least privilege. Organizações com requisitos mais rígidos devem derivar uma custom role a partir do conjunto real de permissões Terraform. Nunca use `roles/owner` ou `roles/editor` como atalho.

Se `dev`, `prod`, o bucket de state e o provider WIF estiverem em projetos diferentes, conceda acesso à service account de deployment independentemente em cada projeto/recurso alvo. A identidade pode estar hospedada em um projeto e receber IAM em outro.

## Workflow manual de plan

Execute **Terraform plan** pela aba Actions e escolha `dev` ou `prod`.

O workflow:

1. verifica que a ref selecionada é `main`;
2. valida as variáveis de repositório do ambiente selecionado;
3. faz checkout sem persistir o token GitHub;
4. autentica por WIF;
5. inicializa `environments/dev` ou `environments/prod` contra `GCP_TERRAFORM_STATE_BUCKET` usando o prefixo fixo do backend do root;
6. cria um saved plan no runner efêmero;
7. publica somente endereços de recursos/outputs e tipos de ação no GitHub Job Summary;
8. calcula um fingerprint SHA-256 a partir do JSON completo do plan Terraform;
9. descarta o runner e seu plan ao final do job.

O plan binário completo e o plan JSON completo **não** são enviados como artifacts. Arquivos de plan Terraform podem conter dados sensíveis derivados do state mesmo quando a saída CLI legível por humanos os mascara.

Para o ambiente de desenvolvimento, este workflow também é o caminho oficial de validação em GCP real definido pela issue #29. Consulte `gcp-integration-validation.md` para a evidência exigida antes de considerar essa issue concluída e para o limite exato entre um plan real bem-sucedido e comportamentos que ainda exigem deployment explicitamente autorizado.

## Workflow manual de apply

Execute **Terraform apply** somente depois que um plan independente tiver sido revisado ou quando iniciar intencionalmente um deployment controlado.

As entradas são:

- `environment`: `dev` ou `prod`;
- `confirmation`: deve ser exatamente `apply-dev` ou `apply-prod`;
- `allow_destroy`: padrão `false`.

O workflow primeiro cria um plan pré-aprovação e publica o mesmo resumo seguro. Se esse plan contiver uma ação de delete (incluindo replacement), o run para a menos que `allow_destroy=true` tenha sido selecionado explicitamente.

Quando existem mudanças, o job de apply referencia o GitHub Environment selecionado. Para `prod`, este é o limite de aprovação descrito acima.

Após a aprovação do ambiente, o job de apply **não** consome um plan binário enviado anteriormente. Em vez disso:

1. autentica novamente por WIF;
2. inicializa o mesmo state remoto;
3. cria um novo saved plan no runner aprovado;
4. recalcula o fingerprint SHA-256 do JSON completo do plan;
5. compara esse fingerprint com o fingerprint pré-aprovação;
6. verifica novamente a política de mudanças destrutivas;
7. aplica somente o novo saved plan quando os fingerprints correspondem exatamente.

Se state, data sources, configuração ou valores planejados mudarem enquanto a aprovação estiver pendente, os fingerprints serão diferentes e nada será aplicado. Inicie um novo run e revise o novo plan.

Isso evita persistir um plan binário potencialmente sensível e ao mesmo tempo impede reutilizar uma aprovação antiga para um plan Terraform materialmente diferente.

## Operações destrutivas

`allow_destroy=false` é o padrão. Replacements Terraform incluem uma ação `delete`, portanto também são bloqueados a menos que quem disparou o workflow faça opt-in explicitamente.

`allow_destroy=true` não ignora:

- proteções de lifecycle Terraform;
- proteção contra exclusão do Cloud Run / Redis;
- workload activation lock;
- aprovação do GitHub Environment;
- verificação do fingerprint do plan.

Ele apenas confirma que o plan revisado contém legitimamente ações de delete/replacement.

## Bootstrap dos ambientes em duas fases

O workflow de deployment preserva o contrato existente de bootstrap de segredos.

Para um novo ambiente:

1. defina `TF_<ENV>_ENABLE_WORKLOADS=false`;
2. execute plan/apply para criar recursos de fundação, identidades, Redis, containers do Secret Manager e IAM;
3. popule as versões dos segredos pelo processo externo confiável descrito no README do ambiente;
4. altere `TF_<ENV>_ENABLE_WORKLOADS=true`;
5. execute um novo plan e revise a criação dos workloads;
6. execute o fluxo de apply controlado.

Não coloque Redis AUTH, Redis CA, configuração de aplicação ou outros payloads de segredos em repository variables do GitHub.

## Rollback e recovery

Rollback de deployment Terraform não é implementado como mecanismo automático `git revert && apply`. Reverter configuração pode por si só destruir ou substituir recursos.

Para uma regressão de infraestrutura:

1. interrompa novos deployments no ambiente afetado;
2. inspecione o state remoto atual e o último commit Git conhecido como bom;
3. prepare a correção de configuração;
4. execute o workflow manual de plan contra esse commit depois que ele estiver mergeado na `main`;
5. inspecione explicitamente replacements/deletions;
6. use o workflow de apply controlado somente após revisão/aprovação.

Para corrupção de state ou alterações acidentais de state, siga `bootstrap/state/README.md` e use o histórico de versões dos objetos GCS. Não automatize `force-unlock`, remoção ou restauração de state nestes workflows.

## Relação com a issue #26

A issue #26 amplia a cobertura do Dependabot para providers/módulos Terraform. Ela não altera este modelo de confiança de deployment. PRs de atualização de provider/módulo continuam passando pelo CI Terraform sem credenciais; depois do merge, qualquer plan de ambiente real permanece uma ação manual separada e autenticada via WIF.

## O que o CI valida

Pull requests continuam executando:

- `terraform fmt -check -recursive -diff`;
- `terraform init -backend=false` e `terraform validate`;
- `terraform test`;
- TFLint;
- scan IaC com Trivy.

Nenhum workflow de deployment é disparado automaticamente por um PR. A validação em GCP real é uma ação manual explícita a partir da `main`, e o CI comum de PR não obtém credenciais Google Cloud.
