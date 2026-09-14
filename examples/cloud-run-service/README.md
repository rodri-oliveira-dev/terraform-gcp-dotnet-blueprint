# Cloud Run service example

This root demonstrates isolated consumption of `modules/cloud-run-service` without introducing environment-specific composition.

The example intentionally requires an existing runtime service account and does not create IAM bindings. It also keeps the module's secure defaults: internal-only ingress, deletion protection enabled, scale-to-zero, and a maximum of ten instances.

## Validate locally

```bash
terraform init -backend=false -lockfile=readonly
terraform validate
```

## Plan

Provide the target project and an existing runtime service account:

```bash
terraform plan \
  -var="project_id=my-project" \
  -var="service_account=cloud-run-api@my-project.iam.gserviceaccount.com"
```

The default image is Google's public Cloud Run hello container so the example does not depend on an Artifact Registry repository owned by the consumer.

This example is for module discoverability and validation. Production environment composition belongs under `environments/`.
