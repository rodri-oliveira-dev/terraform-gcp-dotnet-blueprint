# GitHub Actions Workload Identity Federation bootstrap

This Terraform root provisions the Google Cloud trust foundation used by GitHub Actions to authenticate without long-lived service-account keys.

The implementation has two layers: this root owns the Google Cloud trust boundary, while GitHub workflows exercise federation and use the resulting deployment identity for controlled plan/apply operations.

## What this root creates

- IAM, Security Token Service and IAM Service Account Credentials APIs required by federation;
- one Workload Identity Pool dedicated to GitHub Actions;
- one OIDC provider using `https://token.actions.githubusercontent.com`;
- a dedicated deployment service account;
- a `roles/iam.workloadIdentityUser` binding restricted to the configured repository identity;
- optional project-level roles for the deployment service account, empty by default.

## Trust policy

The provider maps GitHub OIDC claims needed for admission/auditability:

- `assertion.sub` -> `google.subject`;
- `repository_id`;
- `repository_owner_id`;
- `ref`;
- `workflow_ref`.

Admission requires:

1. immutable GitHub owner ID equals `github_owner_id`;
2. immutable GitHub repository ID equals `github_repository_id`;
3. token ref equals `github_ref` (default `refs/heads/main`).

Repository/owner names are not authorization boundaries because they can be renamed. Override the example IDs when reusing the blueprint from another repository.

## Least privilege

The deployment service account receives no workload-project role by default. Its initial relationship is the WIF impersonation binding only.

`deployment_project_roles` exists for explicit bootstrap/operator use and rejects broad legacy `roles/owner` / `roles/editor`. For real environment delivery, use the capability-specific permission model documented in `docs/terraform-deployment.md`, preferring resource-level grants where supported.

The WIF smoke test can validate federation without workload-project permissions because `gcloud auth print-access-token` proves token exchange/impersonation without managing an application resource.

## Prerequisites

- protected GCS state bucket from `bootstrap/state`;
- Terraform version from `.terraform-version`;
- a Google Cloud project;
- an operator identity able to manage WIF, service accounts and the IAM relationships declared by this root.

The operator credential bootstrapping WIF is separate from the GitHub Actions deployment identity being created.

## Configure variables

```bash
cd bootstrap/github-actions-wif
cp terraform.tfvars.example terraform.tfvars
```

Set `project_id`, verify the immutable GitHub owner/repository IDs and verify the allowed ref before apply.

## Initialize with remote state

```bash
terraform init \
  -backend-config="bucket=MY_STATE_BUCKET" \
  -backend-config="prefix=bootstrap/github-actions-wif"
terraform fmt -check
terraform validate
terraform plan
```

Apply only after reviewing the trust/IAM changes. Pool/provider/IAM changes can be eventually consistent, so the first token exchange may require a short propagation interval.

## Configure GitHub repository variables

After apply, capture:

```bash
terraform output -raw workload_identity_provider_name
terraform output -raw deployment_service_account_email
```

The repository uses these public identifiers as variables, not secrets. The complete set consumed by plan/apply workflows is documented in `docs/terraform-deployment.md` and includes the state bucket, environment project IDs, image URIs and explicit workload-activation values.

No service-account key, JSON credential or other long-lived GCP credential is stored in GitHub.

## Authentication smoke test

`.github/workflows/gcp-auth-smoke.yml` is manual. Run it from `main` after WIF is applied and required repository variables are configured.

The workflow grants only:

```yaml
permissions:
  contents: read
  id-token: write
```

It authenticates through `google-github-actions/auth`, forces an access-token exchange and verifies the active account/project. Pull requests remain credential-free and attempts to authenticate from a feature/PR ref are expected to fail under the default trust rule.

## Controlled Terraform delivery

`.github/workflows/terraform-plan.yml` and `.github/workflows/terraform-apply.yml` reuse the same WIF trust boundary from `main`.

- **plan**: initializes the selected real GCS backend and creates a review-safe summary without uploading the full plan;
- **apply**: requires explicit confirmation, blocks delete/replacement actions by default, uses the selected GitHub Environment, replans after approval and checks a plan fingerprint before applying.

The deployment identity therefore needs workload/state permissions in addition to WIF impersonation before those workflows can manage infrastructure. See `docs/terraform-deployment.md`.

## Generated credential files

`google-github-actions/auth` may create a short-lived `gha-creds-*.json` file in the runner workspace. That pattern is ignored by the repository. These credentials are ephemeral derivatives of GitHub OIDC, not service-account keys.

## Security invariants

- no service-account key is created;
- no long-lived GCP credential belongs in GitHub secrets;
- admission is restricted by immutable owner/repository IDs and explicit ref;
- `id-token: write` exists only on jobs that need OIDC;
- the deployment service account starts without broad workload-project roles;
- `roles/owner` and `roles/editor` are rejected as bootstrap shortcuts;
- provider dependency is locked in executable-root lock files;
- GitHub Actions are pinned to immutable commits;
- generated credential files are ignored;
- pull-request Terraform validation remains credential-free.
