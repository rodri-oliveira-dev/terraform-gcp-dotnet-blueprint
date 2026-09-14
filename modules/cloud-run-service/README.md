# Cloud Run v2 service module

Reusable Terraform child module for deploying request-serving .NET workloads to Google Cloud Run v2.

The module intentionally owns only the Cloud Run service configuration. Runtime identities, IAM grants, Secret Manager resources, networking, Pub/Sub, and environment composition remain outside this module so roots can compose those capabilities explicitly.

## Security defaults

- A runtime service account is required; the module does not silently fall back to the project's default service account.
- Ingress defaults to `INGRESS_TRAFFIC_INTERNAL_ONLY`.
- Provider-level deletion protection defaults to `true`.
- Scaling defaults to `0..10` instances to preserve scale-to-zero while bounding reference-architecture cost exposure.
- The module does not grant `allUsers`, `roles/run.invoker`, or any other IAM role.
- Secret values are never module inputs. Secret-backed environment variables accept only a Secret Manager identifier and version.

Callers are responsible for granting the runtime service account access to any referenced secrets. Prefer resource-level `roles/secretmanager.secretAccessor` grants on the required secrets rather than broad project-level access.

## Usage

```hcl
module "api" {
  source = "../../modules/cloud-run-service"

  project_id      = "my-project"
  name            = "orders-api"
  location        = "us-central1"
  container_image = "us-central1-docker.pkg.dev/my-project/apps/orders-api:1.0.0"
  service_account = "orders-api@my-project.iam.gserviceaccount.com"

  resources = {
    cpu    = "1"
    memory = "512Mi"
  }

  scaling = {
    min_instance_count = 0
    max_instance_count = 10
  }

  environment_variables = {
    ASPNETCORE_ENVIRONMENT = "Production"
  }

  secret_environment_variables = {
    DATABASE_PASSWORD = {
      secret  = "orders-database-password"
      version = "latest"
    }
  }

  labels = {
    component = "api"
    managed-by = "terraform"
  }
}
```

Using `INGRESS_TRAFFIC_ALL` only changes the network ingress setting. It does **not** make the service unauthenticated; invocation IAM is deliberately outside this module.

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `project_id` | `string` | required | Google Cloud project ID. |
| `name` | `string` | required | Cloud Run service name, validated against Cloud Run naming constraints. |
| `location` | `string` | required | Google Cloud region. |
| `description` | `string` | `null` | Optional service description, maximum 512 characters. |
| `container_image` | `string` | required | Container image URI. |
| `service_account` | `string` | required | Existing runtime service account email. |
| `container_port` | `number` | `8080` | Container request port. |
| `resources` | `object` | CPU `1`, memory `512Mi`, CPU idle enabled, startup CPU boost enabled | Container compute configuration. |
| `scaling` | `object` | min `0`, max `10` | Revision-level automatic scaling bounds. |
| `max_instance_request_concurrency` | `number` | `80` | Maximum concurrent requests per instance, from 1 through 1000. |
| `timeout` | `string` | `300s` | Maximum request duration, capped at 3600 seconds. |
| `ingress` | `string` | `INGRESS_TRAFFIC_INTERNAL_ONLY` | Supported Cloud Run ingress policy. |
| `deletion_protection` | `bool` | `true` | Provider-level service deletion protection. |
| `environment_variables` | `map(string)` | `{}` | Literal, non-secret environment variables. |
| `secret_environment_variables` | `map(object)` | `{}` | Secret Manager references keyed by environment variable name. |
| `labels` | `map(string)` | `{}` | Service labels. |

A variable name cannot appear in both `environment_variables` and `secret_environment_variables`.

## Outputs

- `id` — fully qualified Cloud Run service resource ID;
- `name` — service name;
- `uri` — provider-computed serving URI;
- `location` — service region;
- `project` — service project;
- `service_account` — configured runtime service account email.

## Testing

Tests live under `tests/` and use Terraform's mock provider support so they do not require Google Cloud credentials or create billable infrastructure.

From this module directory:

```bash
terraform init -backend=false
terraform validate
terraform test
```

The unit tests cover secure defaults, resource mapping, output forwarding, input validation, and conflicting environment variable sources.

## Out of scope

This module does not create or manage:

- service accounts or IAM bindings;
- public invoker access;
- Secret Manager secrets, versions, or secret payloads;
- VPC networking;
- Pub/Sub subscriptions;
- Cloud Run Jobs;
- environment-specific backends or provider configuration.

Those responsibilities are composed by subsequent modules and environment roots.
