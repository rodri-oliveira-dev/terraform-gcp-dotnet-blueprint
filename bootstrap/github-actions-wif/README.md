# Bootstrap do Workload Identity Federation para GitHub Actions

Este Terraform root provisiona a fundação de confiança no Google Cloud usada pelo GitHub Actions para autenticar sem chaves de service account de longa duração.

A implementação possui duas camadas: este root é responsável pelo limite de confiança no Google Cloud, enquanto os workflows GitHub exercitam a federação e usam a identidade de deployment resultante para operações controladas de plan/apply.

## O que este root cria

- APIs IAM, Security Token Service e IAM Service Account Credentials necessárias à federação;
- um Workload Identity Pool dedicado ao GitHub Actions;
- um provider OIDC usando `https://token.actions.githubusercontent.com`;
- uma service account dedicada de deployment;
- um binding `roles/iam.workloadIdentityUser` restrito à identidade configurada do repositório;
- roles opcionais no nível do projeto para a service account de deployment, vazias por padrão.

## Política de confiança

O provider mapeia claims OIDC do GitHub necessários para admissão/auditoria:

- `assertion.sub` -> `google.subject`;
- `repository_id`;
- `repository_owner_id`;
- `ref`;
- `workflow_ref`.

A admissão exige:

1. ID imutável do owner GitHub igual a `github_owner_id`;
2. ID imutável do repositório GitHub igual a `github_repository_id`;
3. ref do token igual a `github_ref` (padrão `refs/heads/main`).

Nomes do repositório/owner não são limites de autorização porque podem ser renomeados. Substitua os IDs de exemplo ao reutilizar o blueprint em outro repositório.

## Least privilege

A service account de deployment não recebe role de projeto dos workloads por padrão. Sua relação inicial é somente o binding de impersonation do WIF.

`deployment_project_roles` existe para uso explícito de bootstrap/operação e rejeita as roles legadas amplas `roles/owner` / `roles/editor`. Para entrega real dos ambientes, use o modelo de permissões por capacidade documentado em `docs/terraform-deployment.md`, preferindo grants em nível de recurso quando suportado.

O smoke test do WIF consegue validar federação sem permissões no projeto de workloads porque `gcloud auth print-access-token` comprova troca de token/impersonation sem gerenciar recurso de aplicação.

## Pré-requisitos

- bucket GCS protegido de state criado por `bootstrap/state`;
- versão do Terraform em `.terraform-version`;
- projeto Google Cloud;
- identidade de operador capaz de gerenciar WIF, service accounts e relações IAM declaradas por este root.

A credencial de operador usada para bootstrap do WIF é separada da identidade de deployment do GitHub Actions que está sendo criada.

## Configurar variáveis

```bash
cd bootstrap/github-actions-wif
cp terraform.tfvars.example terraform.tfvars
```

Defina `project_id`, valide os IDs imutáveis de owner/repositório GitHub e confira a ref permitida antes do apply.

## Inicializar com state remoto

```bash
terraform init \
  -backend-config="bucket=MY_STATE_BUCKET" \
  -backend-config="prefix=bootstrap/github-actions-wif"
terraform fmt -check
terraform validate
terraform plan
```

Aplique somente após revisar as mudanças de confiança/IAM. Alterações de pool/provider/IAM podem sofrer eventual consistency; a primeira troca de token pode exigir um curto intervalo de propagação.

## Configurar repository variables do GitHub

Após o apply, capture:

```bash
terraform output -raw workload_identity_provider_name
terraform output -raw deployment_service_account_email
```

O repositório usa esses identificadores públicos como variables, não secrets. O conjunto completo consumido pelos workflows de plan/apply está documentado em `docs/terraform-deployment.md` e inclui bucket de state, project IDs dos ambientes, URIs das imagens e valores explícitos de ativação dos workloads.

Nenhuma chave de service account, credencial JSON ou outra credencial GCP de longa duração é armazenada no GitHub.

## Smoke test de autenticação

`.github/workflows/gcp-auth-smoke.yml` é manual. Execute-o a partir da `main` depois que o WIF estiver aplicado e as repository variables necessárias estiverem configuradas.

O workflow concede somente:

```yaml
permissions:
  contents: read
  id-token: write
```

Ele autentica via `google-github-actions/auth`, força uma troca por access token e verifica conta/projeto ativos. Pull requests permanecem sem credenciais e tentativas de autenticação por feature/PR ref devem falhar sob a regra de confiança padrão.

## Entrega Terraform controlada

`.github/workflows/terraform-plan.yml` e `.github/workflows/terraform-apply.yml` reutilizam o mesmo limite de confiança WIF a partir da `main`.

- **plan**: inicializa o backend GCS real selecionado e cria resumo seguro para revisão sem enviar o plan completo;
- **apply**: exige confirmação explícita, bloqueia ações delete/replacement por padrão, usa o GitHub Environment selecionado, refaz o plan após aprovação e verifica o fingerprint antes de aplicar.

A identidade de deployment, portanto, precisa de permissões de workload/state além da impersonation WIF para que esses workflows gerenciem infraestrutura. Consulte `docs/terraform-deployment.md`.

## Arquivos de credenciais gerados

`google-github-actions/auth` pode criar arquivo efêmero `gha-creds-*.json` no workspace do runner. Esse padrão é ignorado pelo repositório. Essas credenciais são derivadas temporárias do GitHub OIDC, não chaves de service account.

## Invariantes de segurança

- nenhuma chave de service account é criada;
- nenhuma credencial GCP de longa duração pertence aos GitHub secrets;
- admissão é restrita por IDs imutáveis de owner/repositório e ref explícita;
- `id-token: write` existe somente nos jobs que precisam de OIDC;
- service account de deployment começa sem roles amplas nos projetos de workloads;
- `roles/owner` e `roles/editor` são rejeitadas como atalhos de bootstrap;
- dependência do provider é travada nos lock files dos roots executáveis;
- GitHub Actions são fixadas por commits imutáveis;
- arquivos gerados de credenciais são ignorados;
- validação Terraform de pull request permanece sem credenciais.
