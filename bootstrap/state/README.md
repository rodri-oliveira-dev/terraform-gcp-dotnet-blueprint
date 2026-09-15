# Bootstrap do state Terraform

Este Terraform root cria o bucket do Cloud Storage usado pelos demais roots Terraform como backend remoto protegido.

Ele usa intencionalmente state local durante o bootstrap porque o backend remoto não pode existir antes que este root o crie. Preserve o state de bootstrap com segurança até que o bucket exista e seu ciclo de vida/ownership esteja compreendido.

## Padrões de segurança

O bucket é configurado com:

- object versioning para histórico de recovery;
- uniform bucket-level access;
- prevenção de acesso público;
- `force_destroy = false`;
- proteção de lifecycle `prevent_destroy` do Terraform;
- nenhuma credencial ou valor de segredo na configuração Terraform versionada.

O state Terraform contém dados sensíveis de infraestrutura. O acesso deve ser limitado às identidades que precisam ler ou atualizar os objetos de state relevantes.

## Pré-requisitos

- versão do Terraform definida em `.terraform-version` no repositório;
- projeto Google Cloud com Cloud Storage disponível;
- credencial de operador com permissão para criar/gerenciar o bucket de state.

Não crie nem faça commit de chave de service account para este repositório.

## Bootstrap

```bash
cd bootstrap/state
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform fmt -check
terraform validate
terraform plan
```

Revise o plan antes de aplicá-lo explicitamente:

```bash
terraform apply
```

`terraform apply` é uma ação manual do operador. O CI de pull request nunca cria o bucket de state.

Após a criação, capture o nome do bucket:

```bash
terraform output -raw bucket_name
```

## Estrutura do backend

Use prefixos distintos para cada root independente. O repositório usa:

```text
bootstrap/github-actions-wif
environments/dev
environments/prod
```

Os arquivos `backend.tf` dos ambientes fixam seus próprios prefixos; o nome do bucket é informado na inicialização, por exemplo:

```bash
terraform -chdir=environments/dev init \
  -backend-config="bucket=MY_STATE_BUCKET"
```

Os workflows controlados de deployment do GitHub usam a mesma variável de bucket e os prefixos pertencentes a cada ambiente.

## Migrar state local existente

Se um root já possuir state local, a migração deve ser explícita e revisada pelo operador:

```bash
terraform init \
  -migrate-state \
  -backend-config="bucket=MY_STATE_BUCKET" \
  -backend-config="prefix=environments/dev"
```

Verifique o state remoto migrado antes de excluir qualquer backup local. Nunca faça commit de state local, backups, plan files, credenciais ou arquivos `.tfvars` reais.

## Recovery

Object versioning mantém gerações anteriores quando um objeto de state é sobrescrito. Recovery é um procedimento de incidente, não uma funcionalidade automatizada de CI:

1. interrompa deployments do root afetado;
2. preserve o objeto/geração atual de state para investigação;
3. identifique a geração anterior pretendida e o commit de configuração correspondente;
4. restaure somente depois de confirmar que essa geração representa o state desejado;
5. execute um plan antes de qualquer apply e investigue replacements/deletions inesperados.

Não automatize `force-unlock`, remoção/import de state ou restauração de gerações de objetos em workflows genéricos.

Como o bucket possui `prevent_destroy` e `force_destroy = false`, uma exclusão intencional exige mudanças explícitas de configuração/lifecycle antes que o Terraform possa removê-lo. Essa proteção é deliberada.

Consulte `docs/production-readiness.md` e `docs/troubleshooting.md` para a orientação consolidada de recovery.

## Validação

O CI do repositório valida este root sem acessar o backend real quando aplicável. Para validação local pelo operador:

```bash
terraform fmt -check
terraform init
terraform validate
terraform plan
```

Um CI offline bem-sucedido não comprova que a identidade atual do operador/deployment consegue acessar o bucket real. O workflow manual de plan autenticado via WIF fornece essa camada separada de validação do backend real.

## Outputs

| Output | Descrição |
| --- | --- |
| `bucket_name` | Nome do bucket consumido na inicialização do backend Terraform. |
| `bucket_url` | URL `gs://` do bucket de state. |
| `bucket_location` | Localização configurada do bucket. |
