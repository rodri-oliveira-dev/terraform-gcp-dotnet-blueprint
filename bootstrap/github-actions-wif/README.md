# GitHub Actions Workload Identity Federation bootstrap

This Terraform root provisions the Google Cloud trust foundation used by GitHub Actions to authenticate without long-lived service account keys.

This is **issue #4, part 1**. It provisions the Google Cloud side only. The GitHub Actions workflow integration (`id-token: write` plus `google-github-actions/auth`) is intentionally deferred to part 2.

## What this root creates

- the IAM, Security Token Service, and IAM Service Account Credentials APIs required by the federation flow;
- one Workload Identity Pool dedicated to GitHub Actions;
- one OIDC provider using `https://token.actions.githubusercontent.com`;
- a dedicated deployment service account;
- a `roles/iam.workloadIdentityUser` binding that allows only the configured repository identity to impersonate the service account;
- optional project-level roles for the deployment service account, empty by default.

## Trust policy

The provider maps the GitHub OIDC token claims needed for admission and auditability:

- `assertion.sub` -> `google.subject`;
- `repository_id`;
- `repository_owner_id`;
- `ref`;
- `workflow_ref`.

Admission requires all of the following:

1. the immutable GitHub owner ID matches `github_owner_id`;
2. the immutable GitHub repository ID matches `github_repository_id`;
3. the workflow Git ref matches `github_ref` (default: `refs/heads/main`).

The default values for the immutable GitHub IDs identify `rodri-oliveira-dev/terraform-gcp-dotnet-blueprint`. They are public identifiers, not secrets, and must be overridden when reusing this blueprint from another repository.

Repository and owner names are deliberately not security boundaries because they can be renamed. The provider uses the corresponding numeric IDs for authorization decisions.

## Least privilege

The deployment service account receives no Google Cloud project role by default. Its only initial relationship is the service-account impersonation binding required by Workload Identity Federation.

`deployment_project_roles` exists for explicit future needs, but remains empty until a deployment workflow has a concrete permission requirement. The variable rejects the broad legacy basic roles `roles/owner` and `roles/editor`.

Prefer resource-level IAM grants when later modules expose resources that support them. Project-level roles should be added only when a deployment operation genuinely requires project scope.

## Prerequisites

- issue #2 remote-state bootstrap completed;
- Terraform 1.16.x;
- a Google Cloud project;
- an operator identity able to enable the required APIs and manage Workload Identity Federation, service accounts, and the IAM bindings declared here;
- the GCS state bucket created by `bootstrap/state`.

The operator credential used to bootstrap this root is separate from the GitHub Actions runtime identity being created.

## Configure variables

```bash
cd bootstrap/github-actions-wif
cp terraform.tfvars.example terraform.tfvars
```

Set at least `project_id`. Verify the GitHub owner/repository IDs and the allowed ref before applying.

## Initialize with the remote backend

This root uses the GCS backend created by `bootstrap/state`:

```bash
terraform init \
  -backend-config="bucket=MY_STATE_BUCKET" \
  -backend-config="prefix=bootstrap/github-actions-wif"
```

Then validate and review the plan:

```bash
terraform fmt -check
terraform validate
terraform plan
```

Apply only after reviewing the identity and IAM changes:

```bash
terraform apply
```

## Outputs consumed by part 2

After apply, capture:

```bash
terraform output -raw workload_identity_provider_name
terraform output -raw deployment_service_account_email
```

Part 2 will pass these values to `google-github-actions/auth`. The workflow will request only `contents: read` and `id-token: write`; no service account key will be stored in GitHub.

## Operational notes

Workload Identity Pool, provider, and IAM changes are eventually consistent. A newly applied trust configuration can require a few minutes before the first token exchange succeeds.

The provider uses the default Google Workload Identity Federation audience behavior. Part 2 should use the full provider resource name output by this root as the `workload_identity_provider` value.

## Security invariants

- no service account key is created;
- no long-lived GCP credential belongs in GitHub secrets;
- GitHub tenant admission is restricted by immutable numeric owner/repository IDs;
- the default trust is further restricted to `refs/heads/main`;
- the service account has no project permissions by default;
- `roles/owner` and `roles/editor` are explicitly rejected by input validation;
- the provider dependency is committed in `.terraform.lock.hcl`.
