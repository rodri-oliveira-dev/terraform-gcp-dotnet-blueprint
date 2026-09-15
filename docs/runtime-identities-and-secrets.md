# Runtime identities and Secret Manager

## Purpose

Workloads in this repository use explicit Google Cloud service accounts rather than project-default identities. Secret Manager access is granted to those identities only on the individual secrets they require.

The design separates three concerns:

1. workload identity creation;
2. secret metadata/access policy;
3. secret payload/version lifecycle.

Terraform owns the first two. Application secret payloads remain outside Terraform.

## Runtime identity boundary

`modules/runtime-identity` creates one service account for one workload boundary. Typical module instances include an API runtime identity, an asynchronous worker runtime identity, and a batch-job runtime identity.

The module does not accept arbitrary project roles and never creates service-account keys. A root composes that identity with Cloud Run by passing `module.<identity>.email` to the workload module's `service_account` input.

This keeps runtime credentials separate from deployment credentials, Pub/Sub push identities, Cloud Scheduler trigger identities, and Google-managed service agents.

## Secret metadata boundary

`modules/secret-manager` creates one `google_secret_manager_secret` metadata resource. Deletion protection is enabled by default, automatic replication is used unless locations are explicitly supplied, and no principal receives payload access by default.

When `accessor_service_accounts` is configured, the module adds one `google_secret_manager_secret_iam_member` per workload identity with exactly `roles/secretmanager.secretAccessor` on that secret.

The input is a map with caller-chosen stable keys and service account emails as values:

```hcl
accessor_service_accounts = {
  api_runtime = module.api_identity.email
}
```

The stable key (`api_runtime`) determines the Terraform resource instance address. The email remains a value and may therefore be unknown during the initial plan while the service account is being created in the same graph. Computed service-account emails must not be used as `for_each` keys.

No project-level Secret Manager accessor role is created. This follows Google Cloud least-privilege guidance: a workload that needs one secret should receive access to that secret rather than every secret in the project.

## Payload and version ownership

This repository intentionally does not create `google_secret_manager_secret_version` resources for application credentials and does not expose a variable that accepts secret data.

A trusted operator or delivery process is responsible for:

- adding the initial secret version;
- rotating values;
- assigning aliases when appropriate;
- disabling or destroying compromised/obsolete versions;
- auditing payload access.

Keeping payloads outside Terraform prevents source-controlled configuration from containing credentials and avoids deliberately placing application secret values into Terraform state.

## Cloud Run integration

Both existing Cloud Run modules consume the same reference shape:

```hcl
secret_environment_variables = {
  DATABASE_URL = {
    secret  = "orders-database-url"
    version = "latest"
  }
}
```

The Secret Manager module exposes that exact shape as `secret_reference`, so roots can compose the modules without transforming data:

```hcl
service_account = module.api_identity.email

secret_environment_variables = {
  DATABASE_URL = module.database_secret.secret_reference
}
```

The service account still requires the per-secret accessor binding; referencing a secret does not itself grant access.

## Operational notes

- stable accessor map keys should represent workload boundaries and must not be derived from computed attributes;
- `latest` is convenient for the reference architecture but organizations may prefer a numeric version or managed alias for tighter rollout control;
- changing secret metadata does not create or rotate secret payloads;
- deleting protected secret metadata requires an explicit change to `deletion_protection` before Terraform can remove it;
- IAM resources are additive members rather than authoritative whole-policy replacements.

See `examples/runtime-secrets` for a composition with two workload identities that cannot read each other's secrets.
