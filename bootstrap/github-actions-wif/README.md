# GitHub Actions Workload Identity Federation bootstrap

This Terraform root provisions the Google Cloud trust foundation used by GitHub Actions to authenticate without long-lived service account keys.

Issue #4 is implemented in two layers: this root provisions the Google Cloud trust boundary, while `.github/workflows/gcp-auth-smoke.yml` exercises the resulting federation from GitHub Actions.

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

The authentication smoke test therefore validates federation without needing a project-level role: `gcloud auth print-access-token` forces the token exchange and service-account impersonation, but does not access a workload resource.

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

Workload Identity Pool, provider, and IAM changes are eventually consistent. A newly applied trust configuration can require a few minutes before the first token exchange succeeds.

## Configure GitHub repository variables

After apply, capture the values consumed by the workflow:

```bash
terraform output -raw workload_identity_provider_name
terraform output -raw deployment_service_account_email
```

Configure these **repository variables** under GitHub Actions; they are identifiers, not secrets:

| Repository variable | Value |
| --- | --- |
| `GCP_PROJECT_ID` | the Google Cloud project ID used by this root |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `terraform output -raw workload_identity_provider_name` |
| `GCP_SERVICE_ACCOUNT` | `terraform output -raw deployment_service_account_email` |

No service account key, JSON credential, or other long-lived GCP credential is stored in GitHub.

## GitHub Actions authentication

`.github/workflows/gcp-auth-smoke.yml` is intentionally manual (`workflow_dispatch`). Run it from `main` after the Terraform root has been applied and the repository variables above are configured.

The default provider trust only admits `refs/heads/main`, so attempts to authenticate from a feature branch or pull-request ref are expected to fail. Pull requests continue to use credential-free Terraform quality gates.

The authentication job starts with no workflow permissions and grants only:

```yaml
permissions:
  contents: read
  id-token: write
```

The workflow then:

1. validates the three required repository variables;
2. checks out the repository without persisting the GitHub token;
3. uses `google-github-actions/auth` through WIF and the dedicated service account;
4. installs the pinned Google Cloud CLI;
5. runs `gcloud auth print-access-token` to force an actual token exchange and service-account impersonation;
6. verifies that the active account and configured project match the expected values.

The GitHub Actions are pinned to immutable commit SHAs and retain release annotations so Dependabot can keep them reviewable. The Google Cloud CLI is pinned to `584.0.0` for reproducible smoke-test behavior.

## Generated credential files

`google-github-actions/auth` creates a short-lived credentials file in the workspace when `create_credentials_file` is enabled. The repository ignores the action's `gha-creds-*.json` pattern so generated credentials cannot be committed accidentally.

The credentials are ephemeral and derive from GitHub OIDC; they are not service account keys.

## Security invariants

- no service account key is created;
- no long-lived GCP credential belongs in GitHub secrets;
- GitHub tenant admission is restricted by immutable numeric owner/repository IDs;
- the default trust is further restricted to `refs/heads/main`;
- `id-token: write` exists only on the authentication job that needs it;
- the service account has no project permissions by default;
- `roles/owner` and `roles/editor` are explicitly rejected by input validation;
- the provider dependency is committed in `.terraform.lock.hcl`;
- GitHub Actions are pinned to immutable commits;
- generated `gha-creds-*.json` files are ignored.
