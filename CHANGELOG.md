# Histórico de alterações

Todas as alterações relevantes deste projeto são documentadas neste arquivo.

O repositório segue a intenção de versionamento semântico para releases publicadas. Até que uma tag seja criada, a seção `v1.0.0` abaixo representa um rascunho de release candidate preparado para revisão humana.

## [v1.0.0] - Não publicado

### Adicionado

- fundação e convenções de repositório Terraform orientadas a produção;
- bootstrap protegido de state remoto em GCS com versionamento, uniform bucket-level access e prevenção de acesso público;
- Workload Identity Federation no GitHub Actions usando IDs imutáveis de repositório/owner e sem chaves de service account;
- CI Terraform sem credenciais com gates de format, validate, testes nativos, TFLint e Trivy;
- módulo reutilizável de Cloud Run v2 Service para API/workers orientados a requisições;
- módulo reutilizável de Cloud Run v2 Job para workloads batch finitos;
- composição de tópicos/subscriptions Pub/Sub com push autenticado, retries e tratamento de dead-letter;
- identidades de runtime específicas por workload e módulos de metadados/acesso do Secret Manager;
- VPC em modo customizado, Direct VPC egress e módulo de Private Service Access;
- módulo privado de Memorystore for Redis com AUTH/TLS e padrões orientados a alta disponibilidade;
- roots completos `dev` e `prod` com diferenças de política explícitas;
- módulo de políticas de alerta do Cloud Monitoring e integração aos ambientes;
- workflows manuais controlados de Terraform plan/apply usando WIF, fingerprints de plan, confirmação de mudanças destrutivas e gates de GitHub Environment;
- procedimento e tooling de validação em GCP real para plans de desenvolvimento sem aplicar recursos;
- cobertura do Dependabot para GitHub Actions e dependências Terraform;
- documentação de prontidão para produção, troubleshooting, adoção e prontidão de release.

### Segurança

- nenhuma credencial GCP de longa duração é exigida pelo GitHub Actions;
- nenhuma invocação pública de Cloud Run é concedida por padrão;
- identidades de runtime e transporte são separadas;
- versões de payloads do Secret Manager permanecem fora do Terraform;
- payloads de Redis AUTH/CA não são expostos como outputs dos módulos;
- o state Terraform é isolado por prefixo de ambiente e tratado como dado sensível;
- operações destrutivas são protegidas por mecanismos de lifecycle/provider e pela política dos workflows;
- GitHub Actions são fixadas por SHAs imutáveis de commit.

### Notas operacionais

- o bootstrap dos ambientes é intencionalmente dividido em duas fases porque os payloads de segredos são externos ao Terraform;
- a ativação dos workloads é uma transição unidirecional por state e não funciona como um toggle de destroy;
- sizing e thresholds de produção são valores de referência e exigem revisão específica do workload;
- a issue #29 acompanha a evidência de validação bem-sucedida de WIF/backend/provider por plan em GCP real;
- smoke tests de runtime, desenho de edge público, rotação de segredos, testes de carga e SLOs específicos de produto permanecem responsabilidades de quem adota o blueprint.
