# Runtime identity module

Creates one Google Cloud service account intended to represent a single workload runtime boundary, such as a Cloud Run API, request-serving worker, or Cloud Run Job.

The module deliberately does not accept arbitrary IAM roles. Creating an identity and granting access to a resource are separate concerns; callers grant only the resource-scoped permissions the workload actually needs.

## Security model

- no service-account keys are created;
- the service account is enabled by default;
- one module instance represents one workload identity;
- no project-level roles are granted;
- outputs are shaped for direct use by Cloud Run and resource-scoped IAM bindings.

## Example

```hcl
module "api_identity" {
  source = "../../modules/runtime-identity"

  project_id   = "my-project"
  account_id   = "orders-api"
  display_name = "Orders API runtime"
  description  = "Runtime identity used only by the orders API."
}

module "api" {
  source = "../../modules/cloud-run-service"

  # ...
  service_account = module.api_identity.email
}
```

## Inputs

| Name | Default | Description |
| --- | --- | --- |
| `project_id` | required | Project where the service account is created. |
| `account_id` | required | RFC1035-compatible 6-30 character service-account ID. |
| `display_name` | `null` | Human-readable name; defaults to `account_id`. |
| `description` | `null` | Optional workload-boundary description, up to 256 characters. |
| `disabled` | `false` | Whether the identity is disabled. |

## Outputs

- `email` — direct input for Cloud Run `service_account`;
- `name` — fully qualified service-account resource name;
- `member` — `serviceAccount:...` IAM member string;
- `unique_id` — stable Google-assigned identifier.

## Out of scope

This module does not create keys, project-level IAM grants, Secret Manager access, Cloud Run resources, or application credentials.
