# Observability alerts example

This root demonstrates isolated consumption of `modules/observability-alerts`. It assumes the named Cloud Run services, Cloud Run Job, Pub/Sub subscription, Redis instance, and any notification channels already exist in the selected project.

The example creates alert policies only. It does not create monitored workloads or notification destinations.

## Validate without credentials

```bash
terraform init -backend=false
terraform validate
```

Pull-request CI validates this root with the committed provider lock file and does not run `terraform apply`.

## Apply intentionally

If you choose to apply this example in a real project, first enable the Cloud Monitoring API and replace the example resource names in `main.tf` with resources that actually emit the corresponding metrics. An alert policy can be created before a target has emitted data, but it will not evaluate meaningfully until matching time series exist.

Notification channels are optional and must be created/owned elsewhere. Supply only channel resource names such as:

```hcl
notification_channels = [
  "projects/example-project/notificationChannels/1234567890",
]
```

Do not place notification tokens, webhook secrets, or credentials in Terraform variables for this module.
