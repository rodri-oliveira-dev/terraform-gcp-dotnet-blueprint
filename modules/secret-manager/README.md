# Secret Manager module

Creates one Google Cloud Secret Manager secret **metadata resource** and optional resource-scoped access grants for workload service accounts.

The module intentionally does not create secret versions and has no input for secret payloads. Application secret values must be added through a separate operator-controlled or delivery process so Terraform configuration and state do not become the system of record for credentials.

## Security model

- deletion protection is enabled by default;
- automatic replication is the default, with optional user-managed locations;
- no principal receives access by default;
- configured workload service accounts receive only `roles/secretmanager.secretAccessor` on this specific secret;
- no project-wide Secret Manager role is created;
- no `google_secret_manager_secret_version` resource exists in this module.

Google Cloud recommends granting Secret Manager permissions at the lowest resource level practical. This module therefore uses additive `google_secret_manager_secret_iam_member` resources on the individual secret.

## Example

```hcl
module "database_secret" {
  source = "../../modules/secret-manager"

  project_id = "my-project"
  secret_id  = "orders-database-url"

  accessor_service_account_emails = [
    module.api_identity.email,
  ]
}

module "api" {
  source = "../../modules/cloud-run-service"

  # ...
  service_account = module.api_identity.email

  secret_environment_variables = {
    DATABASE_URL = module.database_secret.secret_reference
  }
}
```

The secret version referenced by `secret_reference.version` must already exist when the workload starts. By default the module exposes the `latest` alias; callers can provide a numeric version or alias through `reference_version` without Terraform creating or reading the payload.

## Inputs

| Name | Default | Description |
| --- | --- | --- |
| `project_id` | required | Project containing the secret. |
| `secret_id` | required | Secret ID, 1-255 letters/digits/hyphens/underscores. |
| `accessor_service_account_emails` | `[]` | Workload service accounts granted accessor on this secret only. |
| `replication_locations` | `[]` | Empty for automatic replication; otherwise user-managed locations. |
| `reference_version` | `latest` | Version/alias exposed to Cloud Run consumers. |
| `deletion_protection` | `true` | Prevent accidental Terraform deletion of secret metadata. |
| `labels` | `{}` | Labels applied to the secret. |

## Outputs

- `secret_id` — suitable for Cloud Run Secret Manager references;
- `name` — fully qualified Secret Manager resource name;
- `secret_reference` — `{ secret, version }` object directly compatible with the existing Cloud Run service/job secret environment-variable contracts;
- `accessor_service_account_emails` — explicit set of principals granted access.

## Secret version ownership

Secret versions are deliberately outside Terraform in this repository. Operators or a dedicated delivery workflow are responsible for creating, rotating, disabling, and destroying versions. The runtime identity only receives payload-read permission; it does not receive permission to add or manage versions.

## Out of scope

This module does not create secret payloads, secret versions, arbitrary IAM roles, project-level Secret Manager grants, workload identities, or environment-specific policy.
