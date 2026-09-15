# Exemplo de Cloud Run Service

Este root demonstra o consumo isolado de `modules/cloud-run-service` sem introduzir composição específica de ambiente.

O exemplo exige intencionalmente uma service account de runtime existente e não cria IAM bindings. Ele também preserva os padrões seguros do módulo: ingress somente interno, proteção contra exclusão habilitada, scale-to-zero e máximo de dez instâncias.

## Validar localmente

```bash
terraform init -backend=false -lockfile=readonly
terraform validate
```

## Plan

Forneça o projeto alvo e uma service account de runtime existente:

```bash
terraform plan \
  -var="project_id=my-project" \
  -var="service_account=cloud-run-api@my-project.iam.gserviceaccount.com"
```

A imagem padrão é o container público hello do Google Cloud Run, evitando dependência de um repositório Artifact Registry pertencente ao consumidor.

Este exemplo existe para facilitar descoberta e validação do módulo. A composição de ambientes de produção pertence a `environments/`.
