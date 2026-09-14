# Terraform state bootstrap

This Terraform root creates the Cloud Storage bucket used by later environment roots as a remote backend.

It intentionally uses local state while bootstrapping because the remote backend cannot exist before this root creates it. The bootstrap state should be retained securely until the bucket exists and the bootstrap lifecycle is understood.

## Security defaults

The bucket is configured with:

- object versioning enabled for state recovery;
- uniform bucket-level access enabled;
- public access prevention enforced;
- `force_destroy = false`;
- Terraform `prevent_destroy` lifecycle protection;
- no credentials or secret values in source-controlled Terraform configuration.

Terraform state is sensitive infrastructure data. Access to this bucket should be granted only to the identities that need to read or update Terraform state.

## Prerequisites

- Terraform 1.16.x;
- a Google Cloud project with Cloud Storage available;
- Application Default Credentials or another supported Google provider authentication method with permission to create and manage the state bucket.

Do not create or commit a service-account key for this repository.

## Bootstrap

Create a local variable file from the committed example:

```bash
cd bootstrap/state
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your own project ID and a globally unique bucket name. The real `terraform.tfvars` file is ignored by Git.

Initialize and validate the root:

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
```

Review the plan before explicitly applying it:

```bash
terraform apply
```

`terraform apply` is intentionally a manual operator action and is not run automatically by repository agents or CI.

After creation, capture the bucket name:

```bash
terraform output -raw bucket_name
```

## Configure an environment backend

Environment roots will declare a GCS backend without embedding environment-specific bucket values in reusable modules. A root can declare:

```hcl
terraform {
  backend "gcs" {}
}
```

Then initialize it using a backend configuration file or command-line values, for example:

```bash
terraform init \
  -backend-config="bucket=MY_STATE_BUCKET" \
  -backend-config="prefix=environments/dev"
```

Use a distinct prefix for every independent Terraform root, such as `environments/dev` and `environments/prod`, so their states cannot overwrite one another.

The GCS backend coordinates state updates and should be the only supported state location for workload environment roots once remote state is enabled.

## Migrate existing local state

If a root already has local state, add the GCS backend declaration and initialize with migration enabled:

```bash
terraform init \
  -migrate-state \
  -backend-config="bucket=MY_STATE_BUCKET" \
  -backend-config="prefix=environments/dev"
```

Terraform will ask for confirmation before copying the existing state to the configured backend. Verify the migrated state before deleting any local backup.

Never commit local state files, state backups, plan files, credentials, or real `.tfvars` files.

## Recovery

Object versioning is enabled so previous object generations remain available if a state object is overwritten or corrupted. Recovery should be treated as an operational procedure: identify the correct prior generation, preserve the current object for investigation, and restore only after confirming the intended state version.

Because the bucket has `prevent_destroy` and `force_destroy = false`, intentional removal requires an explicit code change before Terraform can destroy it. This is deliberate protection for infrastructure state.

## Validation

The expected local validation sequence for this root is:

```bash
terraform fmt -check
terraform init
terraform validate
```

Repository CI for these checks is introduced by roadmap issue #3. Until then, contributors should run the commands locally and report any validation they could not execute in the pull request.

## Outputs

| Output | Description |
| --- | --- |
| `bucket_name` | Bucket name to configure in GCS backends. |
| `bucket_url` | `gs://` URL of the state bucket. |
| `bucket_location` | Configured bucket location. |
