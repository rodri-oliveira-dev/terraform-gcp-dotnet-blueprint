# Instruções para agentes

Este repositório é uma arquitetura de referência Terraform orientada a produção para workloads .NET no Google Cloud. Trate correção da infraestrutura, segurança, reprodutibilidade e documentação como requisitos de primeira classe.

## Leia primeiro

Antes de alterar código, leia as fontes de verdade relevantes nesta ordem:

1. `README.md` para intenção do projeto, capacidades implementadas, status da release e limites documentados.
2. `docs/architecture.md` para os limites arquiteturais.
3. Registros aplicáveis em `docs/adr/`.
4. A issue do GitHub sendo implementada, incluindo Definition of Ready e Definition of Done.
5. `docs/agent-workflow.md` para o fluxo de execução do repositório.
6. Skills relevantes do projeto em `.agents/skills/`.

Não presuma que uma issue ou prompt anterior foi implementado corretamente. Quando a issue atual depender de trabalho anterior, valide o DoD do pré-requisito antes de fazer alterações.

## Roteamento de skills

Carregue o menor conjunto de skills relevante para a tarefa:

- Autoria ou revisão de HCL Terraform: `terraform-style-guide`.
- Módulos filhos reutilizáveis, limites de root modules, interfaces ou refatoração: `terraform-module-engineering`.
- `.tftest.hcl`, mocks, assertions ou estratégia de testes: `terraform-testing`.
- IAM do GCP, state remoto, Secret Manager, Workload Identity Federation ou segurança de infraestrutura: `gcp-terraform-security`.
- Autoria ou revisão de GitHub Actions: `github-actions-hardening`.

Use múltiplas skills quando uma mudança cruzar diferentes preocupações. Não carregue skills sem relação apenas porque elas existem.

## Limites do repositório

Preserve estas responsabilidades arquiteturais:

- `bootstrap/` é responsável pela infraestrutura que precisa existir antes dos roots de workloads, como o state remoto.
- `modules/` contém módulos filhos reutilizáveis com entradas tipadas explícitas e outputs documentados.
- `environments/` contém root modules e é responsável por backend, configuração de provider, composição de ambiente, sizing e escolhas de política.
- `examples/` demonstra consumo isolado e não deve se tornar um segundo root de produção.
- `docs/adr/` registra decisões com trade-offs arquiteturais relevantes.

Módulos reutilizáveis não devem configurar backends Terraform nem credenciais de provider. Requisitos de provider são permitidos; a configuração do provider pertence aos root modules.

## Requisitos de segurança

Estes requisitos são inegociáveis, a menos que uma ADR documente explicitamente uma exceção justificada:

- Nunca faça commit de credenciais, chaves privadas, valores de segredos, state Terraform ou arquivos `.tfvars` sensíveis.
- Não introduza chaves de service account do Google Cloud de longa duração para CI/CD. Prefira Workload Identity Federation.
- Aplique privilégio mínimo ao IAM do Google Cloud e às permissões de workflows do GitHub.
- Prefira recursos aditivos `google_*_iam_member` quando a propriedade da política IAM completa não for explícita; bindings/policies autoritativos exigem justificativa deliberada.
- Trate o state Terraform como dado sensível.
- O acesso público deve permanecer desabilitado por padrão.
- Recursos do Secret Manager podem gerenciar metadados e acesso, mas payloads de segredos da aplicação não devem ser hard-coded no Terraform.
- GitHub Actions devem usar `permissions:` mínimos e explícitos e referências imutáveis de actions quando prático.

## Restrição da arquitetura de runtime

Não modele Pub/Sub como invocação direta de um Cloud Run Job. A entrega push orientada a eventos do Pub/Sub tem como destino um Cloud Run Service que atende requisições. Cloud Run Jobs são workloads batch finitos e devem usar um mecanismo de execução suportado, como Cloud Scheduler ou uma invocação autenticada da API.

## Convenções Terraform

- Siga as convenções de formatação e estilo da HashiCorp.
- Use tipos e descrições explícitos para variáveis.
- Adicione validação quando um valor inválido puder ser rejeitado localmente.
- Adicione descrições aos outputs e marque outputs sensíveis adequadamente.
- Prefira identidade estável de recursos (`for_each`) ao gerenciar coleções nomeadas.
- Evite `depends_on` desnecessário; expresse dependências por referências.
- Mantenha módulos coesos em vez de excessivamente genéricos.
- Mantenha constantes específicas de ambiente fora dos módulos reutilizáveis.
- Fixe intencionalmente a compatibilidade de Terraform e providers; faça commit dos dependency lock files dos root modules.

## Fluxo de mudanças

Para implementação de issues:

1. Valide o DoR da issue e o DoD dos pré-requisitos.
2. Inspecione a implementação existente antes de editar.
3. Faça a menor mudança coesa que satisfaça integralmente o escopo atual.
4. Atualize a documentação quando comportamento, arquitetura, premissas de segurança ou passos operacionais mudarem.
5. Adicione ou atualize testes para o comportamento dos módulos quando fizer sentido.
6. Execute todas as validações práticas antes de considerar o trabalho concluído.
7. Compare o resultado com cada item do DoD e reporte tudo que não pôde ser validado.

Nunca execute `terraform apply`, destrua infraestrutura, rotacione credenciais ou altere recursos cloud reais, a menos que o usuário solicite explicitamente essa ação.

## Baseline de validação

Execute as verificações aplicáveis após as alterações:

```bash
terraform fmt -check -recursive
terraform validate
terraform test
tflint --recursive
```

A inicialização pode ser necessária antes da validação. Para workflows apenas de validação, evite backends reais e use `terraform init -backend=false` quando apropriado.

Quando houver ferramenta de segurança no repositório, execute-a como parte da mudança relevante. Não afirme que uma verificação passou se a ferramenta estava indisponível ou se credenciais/conectividade impediram a execução.

## Pull requests

- Mantenha uma capacidade arquitetural por issue/PR, a menos que a issue combine explicitamente múltiplas capacidades.
- Explique o que mudou, por que mudou, implicações de segurança e validações executadas.
- Vincule a issue implementada e use palavras-chave de fechamento apenas quando seu DoD estiver integralmente satisfeito.
- Não amplie silenciosamente o escopo para limpezas não relacionadas.
- Resolva comentários de review com código ou uma resposta tecnicamente justificada; não descarte achados válidos apenas para limpar a revisão.
