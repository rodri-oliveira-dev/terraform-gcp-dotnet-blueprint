# Atualizações automatizadas de dependências

Este repositório usa Dependabot como controle preventivo de supply chain junto ao CI Terraform e aos gates de segurança IaC existentes.

## Ecossistemas cobertos

A configuração versionada em `.github/dependabot.yml` cobre:

- GitHub Actions a partir da raiz do repositório;
- dependências Terraform em roots de bootstrap, roots de ambiente, exemplos e módulos reutilizáveis.

Diretórios Terraform são expressos com padrões de diretório para que novos roots/módulos que sigam a estrutura do repositório herdem a política de manutenção sem duplicar configuração.

## Política de atualização

Verificações de dependências executam semanalmente em `America/Sao_Paulo`. Atualizações minor e patch podem ser agrupadas por ecossistema para reduzir ruído de PR. Atualizações major permanecem separadas porque majors de provider/módulo podem alterar schemas, defaults, APIs, permissões exigidas ou comportamento do state e, portanto, exigem revisão explícita.

Um PR automatizado de atualização é uma proposta, não evidência de que a versão é segura para merge.

## Lock files do Terraform

Roots executáveis em `bootstrap/`, `environments/` e `examples/` commitam `.terraform.lock.hcl` quando exigido pelo CI do repositório. Updates de provider que afetam esses roots devem manter o lock file consistente com as constraints declaradas.

Módulos filhos reutilizáveis não precisam commitar dependency lock file próprio. Eles são validados por inicialização/testes do módulo e pelos roots que os consomem.

## Validação obrigatória

PRs Terraform do Dependabot devem passar pelos mesmos gates sem credenciais que mudanças manuais:

- `terraform fmt -check`;
- `terraform init -backend=false` e `terraform validate`;
- `terraform test` para módulos reutilizáveis que fornecem testes;
- TFLint;
- Trivy configuration scanning com a política bloqueante HIGH/CRITICAL existente.

Nenhum `terraform apply` ou `terraform destroy` faz parte da validação de atualização de dependência. Credenciais GCP não devem ser introduzidas apenas para validar versões de provider/módulo que podem ser verificadas offline.

## Limite de escopo

CodeQL não é usado para analisar HCL. Validação Terraform, testes, TFLint, Trivy, provider lock files e revisão das release notes de providers/módulos continuam sendo os controles relevantes para infraestrutura neste repositório.
