# CI do Terraform

O repositório valida mudanças Terraform no GitHub Actions antes do merge. O workflow é intencionalmente sem credenciais: validação estática e unit tests não autenticam no Google Cloud.

## Workflow

`.github/workflows/terraform-ci.yml` executa para pull requests e pushes na `main` com permissões read-only no repositório.

O workflow contém cinco quality gates independentes:

1. **Terraform format** — executa `terraform fmt -check -recursive -diff` e falha quando HCL commitado não está formatado.
2. **Terraform validate** — descobre roots deployáveis em `bootstrap/`, `environments/` e `examples/`, além de módulos filhos em `modules/`. Roots são inicializados com `-backend=false`, exigem `.terraform.lock.hcl` commitado e são validados com providers travados. Módulos reutilizáveis são inicializados e validados independentemente sem exigir lock file próprio.
3. **Terraform test** — descobre módulos reutilizáveis com `tests/*.tftest.hcl`, inicializa sem backend e executa `terraform test`. Unit tests devem preferir modo plan e providers mockados para que PRs não criem infraestrutura nem exijam credenciais cloud.
4. **TFLint** — instala a versão em `.tflint-version`, inicializa a configuração do repositório e executa recursivamente regras recomendadas do Terraform e ruleset Google fixado em `.tflint.hcl`.
5. **Scan de segurança IaC** — executa Trivy configuration scanning e falha em achados HIGH ou CRITICAL.

Cada gate é um job separado para facilitar identificação de falhas nos checks do PR.

## Descoberta de roots e módulos Terraform

A arquitetura define roots deployáveis ou inicializáveis independentemente como diretórios filhos diretos de:

- `bootstrap/`;
- `environments/`;
- `examples/`.

Todo root deve commitar `.terraform.lock.hcl`. A validação usa `terraform init -backend=false -lockfile=readonly` para impedir que o CI atualize silenciosamente seleções de providers.

Módulos filhos reutilizáveis são descobertos como diretórios filhos de `modules/` com arquivos Terraform. São validados independentemente mesmo antes de um ambiente ou exemplo consumi-los, detectando cedo erros de schema do provider, referências inválidas e outros problemas semânticos.

Módulos reutilizáveis não possuem backend nem dependency lock file de root. O CI os inicializa com `terraform init -backend=false` e executa `terraform validate` sem impor requisito de lock file.

Módulos com testes nativos em `tests/` também são executados pelo job `Terraform test`. O job permanece sem credenciais; testes que exigem infraestrutura real devem ficar em workflow de integração controlado separado, e não ser introduzidos silenciosamente no CI de PR.

## Segurança e credenciais

O workflow de CI Terraform usa somente:

```yaml
permissions:
  contents: read
```

Ele não solicita `id-token: write`, não consome credenciais Google Cloud e não usa chaves de service account. Autenticação Google Cloud fica isolada em workflows que explicitamente precisam dela, como o smoke test WIF.

GitHub Actions de terceiros são fixadas por SHAs imutáveis de commit, com versão de release correspondente documentada em comentário inline.

## Atualizações de dependências

`.github/dependabot.yml` habilita atualizações de versão para GitHub Actions **e dependências Terraform**. A política detalhada está em `docs/dependency-updates.md`.

A configuração é conservadora:

- checks executam semanalmente em `America/Sao_Paulo`;
- updates minor e patch podem ser agrupados por ecossistema para reduzir ruído de PR;
- updates major permanecem separados para revisão focada de breaking changes;
- PRs do Dependabot passam pelos mesmos cinco gates offline e sem credenciais;
- roots executáveis mantêm `.terraform.lock.hcl` determinístico e commitado;
- módulos filhos reutilizáveis não precisam de lock file próprio.

Atualizações automáticas são propostas de mudança, não evidência de segurança para merge. Mudanças major de provider/módulo exigem revisão explícita de schemas, defaults, APIs, permissões e efeitos sobre state.

## Validação local

Antes de abrir PR, execute os checks aplicáveis localmente.

### Formatação

```bash
terraform fmt -check -recursive -diff
```

### Validação de root

Para cada root Terraform, por exemplo `bootstrap/state`:

```bash
terraform -chdir=bootstrap/state init -backend=false -input=false -lockfile=readonly
terraform -chdir=bootstrap/state validate
```

### Validação de módulo reutilizável

Para cada módulo, por exemplo `modules/cloud-run-service`:

```bash
terraform -chdir=modules/cloud-run-service init -backend=false -input=false
terraform -chdir=modules/cloud-run-service validate
```

Módulos reutilizáveis intencionalmente não exigem `.terraform.lock.hcl` commitado; seleções de providers são travadas pelos root modules que os consomem.

### Testes nativos Terraform

Para módulo com `tests/*.tftest.hcl`:

```bash
terraform -chdir=modules/cloud-run-service init -backend=false -input=false
terraform -chdir=modules/cloud-run-service test
```

Unit tests de pull request devem usar `command = plan` e mock providers sempre que a API Google Cloud não fizer parte do comportamento testado.

### TFLint

Instale a versão em `.tflint-version` e execute:

```bash
tflint --init
tflint --recursive --format compact
```

### Scan de segurança

O workflow GitHub usa Trivy configuration scanning com achados HIGH/CRITICAL como bloqueantes. Desenvolvedores podem reproduzir a política localmente com versão compatível do Trivy:

```bash
trivy config --severity HIGH,CRITICAL --exit-code 1 .
```

## Política de versões das ferramentas

- Terraform CLI é fixado em `.terraform-version`.
- TFLint é fixado em `.tflint-version`.
- Seleções de providers Terraform são fixadas por `.terraform.lock.hcl` em cada root.
- Plugins TFLint são fixados em `.tflint.hcl`.
- GitHub Actions são fixadas por SHAs imutáveis e monitoradas pelo Dependabot.
- Dependabot monitora também providers/módulos Terraform conforme `docs/dependency-updates.md`.

Upgrades de versão devem ser mudanças explícitas no repositório para que o comportamento do CI não sofra drift sem revisão.
