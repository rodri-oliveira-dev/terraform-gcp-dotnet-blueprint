# Terraform state bootstrap

This Terraform root creates the Cloud Storage bucket used by later Terraform roots as the protected remote backend.

It intentionally uses local state while bootstrapping because the remote backend cannot exist before this root creates it. Retain the bootstrap state securely until the bucket exists and its lifecycle/ownership is understood.

## Security defaults

The bucket is configured with:

- object versioning for recovery history;
- uniform bucket-level access;
- public access prevention;
- `force_destroy = false`;
- Terraform `prevent_destroy` lifecycle protection;
- no credentials or secret values in source-controlled Terraform configuration.

Terraform state is sensitive infrastructure data. Access should be limited to identities that need to read or update the relevant state objects.

## Prerequisites

- Terraform version from the repository `.terraform-version`;
- a Google Cloud project with Cloud Storage available;
- an operator credential with permission to create/manage the state bucket.

Do not create or commit a service-account key for this repository.

## Bootstrap

```bash
cd bootstrap/state
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform fmt -check
terraform validate
terraform plan
```

Review the plan before explicitly applying it:

```bash
terraform apply
```

`terraform apply` is a manual operator action. Pull-request CI never creates the state bucket.

After creation, capture the bucket name:

```bash
terraform output -raw bucket_name
```

## Backend layout

Use distinct prefixes for every independent root. The repository uses:

```text
bootstrap/github-actions-wif
environments/dev
environments/prod
```

Environment `backend.tf` files fix their own prefixes; the bucket name is supplied at initialization time, for example:

```bash
terraform -chdir=environments/dev init \
  -backend-config="bucket=MY_STATE_BUCKET"
```

The controlled GitHub deployment workflows use the same bucket variable and environment-owned prefixes.

## Migrate existing local state

If a root already has local state, migration must be explicit and operator-reviewed:

```bash
terraform init \
  -migrate-state \
  -backend-config="bucket=MY_STATE_BUCKET" \
  -backend-config="prefix=environments/dev"
```

Verify the migrated remote state before deleting any local backup. Never commit local state, backups, plan files, credentials or real `.tfvars` files.

## Recovery

Object versioning keeps previous generations when a state object is overwritten. Recovery is an incident procedure, not an automated CI feature:

1. stop deployments for the affected root;
2. preserve the current state object/generation for investigation;
3. identify the intended prior generation and matching configuration commit;
4. restore only after confirming that generation represents the desired state;
5. run a plan before any apply and investigate unexpected replacements/deletions.

Do not automate `force-unlock`, state removal/import or object-generation restoration in generic workflows.

Because the bucket has `prevent_destroy` and `force_destroy = false`, intentional deletion requires explicit configuration/lifecycle changes before Terraform can remove it. This is deliberate protection.

See `docs/production-readiness.md` and `docs/troubleshooting.md` for consolidated recovery guidance.

## Validation

Repository CI validates this root without accessing the real backend where applicable. For local operator validation:

```bash
terraform fmt -check
terraform init
terraform validate
terraform plan
```

A successful offline CI run is not evidence that the current operator/deployment identity can access the live bucket. The manual WIF-authenticated plan workflow provides that separate real-backend validation layer.

## Outputs

| Output | Description |
| --- | --- |
| `bucket_name` | Bucket name consumed by Terraform backend initialization. |
| `bucket_url` | `gs://` URL of the state bucket. |
| `bucket_location` | Configured bucket location. |
