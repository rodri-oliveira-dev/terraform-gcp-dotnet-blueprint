# Exemplo de alertas de observabilidade

Este root demonstra o consumo isolado de `modules/observability-alerts`. Ele pressupõe que Cloud Run Services, Cloud Run Job, subscription Pub/Sub, instância Redis e canais de notificação informados já existam no projeto selecionado.

O exemplo cria somente políticas de alerta. Não cria workloads monitorados nem destinos de notificação.

## Validar sem credenciais

```bash
terraform init -backend=false
terraform validate
```

O CI de pull request valida este root com o provider lock file commitado e não executa `terraform apply`.

## Aplicar intencionalmente

Se optar por aplicar este exemplo em projeto real, habilite primeiro a Cloud Monitoring API e substitua os nomes de recursos em `main.tf` por recursos que realmente emitam as métricas correspondentes. Uma política pode ser criada antes de um target emitir dados, mas não será avaliada de forma significativa até existirem séries temporais correspondentes.

Canais de notificação são opcionais e devem ser criados/gerenciados em outro lugar. Forneça somente nomes de recursos, por exemplo:

```hcl
notification_channels = [
  "projects/example-project/notificationChannels/1234567890",
]
```

Não coloque notification tokens, webhook secrets ou credenciais em variáveis Terraform deste módulo.
