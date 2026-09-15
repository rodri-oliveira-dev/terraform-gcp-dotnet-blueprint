# Controlled Terraform deployment with GitHub Actions

Issue #28 closes the delivery loop for the blueprint without weakening pull-request validation. Ordinary PR CI remains credential-free; credentialed Terraform operations are manual, run from `main`, and authenticate to Google Cloud through Workload Identity Federation (WIF).

## Workflow boundary

Two workflows intentionally separate review from mutation:

| Workflow | Trigger | Cloud credentials | Mutation |
| --- | --- | --- | --- |
| `Terraform CI` | PR / push to `main` | none | never |
| `Terraform plan` | manual `workflow_dispatch` | WIF | never |
| `Terraform apply` | manual `workflow_dispatch` | WIF | only after plan checks and environment gate |

Neither deployment workflow runs on `pull_request`. Both reject execution from any ref other than `refs/heads/main`, matching the default trust condition provisioned by `bootstrap/github-actions-wif`.

## Required repository variables

The deployment workflows intentionally use GitHub **repository variables**, not repository secrets, for public identifiers and reviewed configuration values.

Configure:

| Variable | Purpose |
| --- | --- |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | full WIF provider resource name from `bootstrap/github-actions-wif` |
| `GCP_SERVICE_ACCOUNT` | deployment service account e-mail impersonated through WIF |
| `GCP_TERRAFORM_STATE_BUCKET` | protected GCS bucket that stores Terraform state |
| `GCP_DEV_PROJECT_ID` | Google Cloud project targeted by `environments/dev` |
| `GCP_PROD_PROJECT_ID` | Google Cloud project targeted by `environments/prod` |
| `TF_DEV_API_IMAGE` | development API container image URI |
| `TF_DEV_WORKER_IMAGE` | development worker container image URI |
| `TF_DEV_BATCH_IMAGE` | development batch image URI |
| `TF_DEV_ENABLE_WORKLOADS` | exact string `true` or `false` matching the desired development activation state |
| `TF_PROD_API_IMAGE` | production API container image URI |
| `TF_PROD_WORKER_IMAGE` | production worker container image URI |
| `TF_PROD_BATCH_IMAGE` | production batch image URI |
| `TF_PROD_ENABLE_WORKLOADS` | exact string `true` or `false` matching the desired production activation state |

The selector script maps only the chosen environment to `TF_VAR_*` variables. It validates required inputs and rejects multiline values before exporting them to the runner environment.

`enable_workloads` is deliberately explicit. The environment roots implement one-way workload activation, so the workflow must not silently fall back to `false` after an environment has been activated.

## GitHub Environments

Create GitHub Environments named exactly:

- `dev`
- `prod`

The apply job references the selected environment. Configure **Required reviewers** on `prod` and enable **Prevent self-review** when your repository governance permits it. The production apply runner does not start until the configured environment protection rules pass.

The `dev` environment can remain unprotected or use a lighter approval policy, depending on the team.

Environment secrets are not required by this design. WIF identifiers and deployment configuration remain repository variables, while the environment is used as a deployment protection boundary and audit record.

## WIF trust model

`bootstrap/github-actions-wif` already constrains federation by immutable GitHub owner/repository IDs and, by default, `refs/heads/main`.

Each credentialed job grants only:

```yaml
permissions:
  contents: read
  id-token: write
```

The workflows use the existing pinned `google-github-actions/auth` action. No service-account key, JSON key secret, or long-lived Google Cloud credential is introduced.

The generated `gha-creds-*.json` file is ephemeral and already ignored by the repository.

## Deployment identity permissions

The WIF bootstrap intentionally creates the deployment service account with no workload project permissions by default. Before using the deployment workflows, an operator must grant the deployer the permissions required by the selected environment.

For this blueprint, the permission boundary includes:

- reading/writing the GCS backend objects for the environment state prefix;
- enabling required project APIs;
- creating/updating VPC and Private Service Access resources;
- managing Memorystore for Redis;
- creating runtime/transport service accounts and the resource-scoped IAM relationships declared by the roots/modules;
- managing Cloud Run services/jobs;
- managing Pub/Sub resources and their IAM;
- managing Secret Manager metadata and secret-level IAM (not secret payload versions);
- managing Cloud Scheduler jobs;
- managing Cloud Monitoring alert policies.

A predefined-role deployment commonly starts from capability-specific roles such as `roles/serviceusage.serviceUsageAdmin`, `roles/compute.networkAdmin`, `roles/servicenetworking.networksAdmin`, `roles/redis.admin`, `roles/iam.serviceAccountAdmin`, `roles/iam.serviceAccountUser`, `roles/run.admin`, `roles/pubsub.admin`, `roles/secretmanager.admin`, `roles/cloudscheduler.admin`, `roles/monitoring.editor`, plus read access such as `roles/browser` where required.

The state bucket should grant the deployment service account object access at bucket scope (for example `roles/storage.objectAdmin`) rather than broad project-wide Storage administration.

Treat that role list as a reference capability map, not a universal least-privilege prescription. Organizations with stricter requirements should derive a custom role from the actual Terraform permission set. Never use `roles/owner` or `roles/editor` as a shortcut.

If `dev`, `prod`, the state bucket, and the WIF provider live in different projects, grant the deployment service account access independently in each target project/resource. The identity can be hosted in one project and receive IAM in another.

## Manual plan workflow

Run **Terraform plan** from the Actions tab and choose `dev` or `prod`.

The workflow:

1. verifies that the selected ref is `main`;
2. validates repository variables for the selected environment;
3. checks out the repository without persisting the GitHub token;
4. authenticates through WIF;
5. initializes `environments/dev` or `environments/prod` against `GCP_TERRAFORM_STATE_BUCKET` with the root's fixed backend prefix;
6. creates a saved plan on the ephemeral runner;
7. publishes only resource/output addresses and action types to the GitHub Job Summary;
8. computes a SHA-256 fingerprint from the complete Terraform JSON plan;
9. discards the runner and its plan file when the job ends.

The full binary plan and full JSON plan are **not** uploaded as artifacts. Terraform plan files can contain sensitive state-derived data even when the human-readable CLI output redacts it.

## Manual apply workflow

Run **Terraform apply** only after an independent plan has been reviewed or when intentionally starting a controlled deployment run.

Inputs are:

- `environment`: `dev` or `prod`;
- `confirmation`: must be exactly `apply-dev` or `apply-prod`;
- `allow_destroy`: defaults to `false`.

The workflow first creates a pre-approval plan and publishes the same safe summary. If that plan contains a delete action (including replacement), the run stops unless `allow_destroy=true` was explicitly selected.

When changes exist, the apply job references the selected GitHub Environment. For `prod`, this is the approval boundary described above.

After environment approval, the apply job does **not** consume an uploaded binary plan. Instead it:

1. authenticates again through WIF;
2. initializes the same remote state;
3. creates a fresh saved plan on the approved runner;
4. recomputes the SHA-256 fingerprint of the complete JSON plan;
5. compares that fingerprint with the pre-approval fingerprint;
6. rechecks the destructive-change policy;
7. applies only the fresh saved plan when the fingerprints match exactly.

If state, data sources, configuration, or planned values changed while approval was pending, the fingerprints differ and nothing is applied. Start a new run and review the new plan.

This avoids persisting a potentially sensitive binary plan while still preventing a stale approval from being reused for a materially different Terraform plan.

## Destructive operations

`allow_destroy=false` is the default. Terraform replacements include a `delete` action, so they are also blocked unless the dispatcher explicitly opts in.

`allow_destroy=true` does not bypass:

- Terraform lifecycle protections;
- Cloud Run / Redis deletion protection;
- the workload activation lock;
- GitHub Environment approval;
- the plan fingerprint check.

It only acknowledges that the reviewed plan legitimately contains delete/replacement actions.

## Two-phase environment bootstrap

The deployment workflow preserves the existing secret bootstrap contract.

For a new environment:

1. set `TF_<ENV>_ENABLE_WORKLOADS=false`;
2. run plan/apply to create foundation resources, identities, Redis, Secret Manager containers and IAM;
3. populate the secret versions through the trusted external process described by the environment README;
4. change `TF_<ENV>_ENABLE_WORKLOADS=true`;
5. run a new plan and review workload creation;
6. run the controlled apply flow.

Do not put Redis AUTH, Redis CA, application configuration, or other secret payloads in GitHub repository variables.

## Rollback and recovery

Terraform deployment rollback is not implemented as an automatic `git revert && apply` mechanism. Reverting configuration can itself destroy or replace resources.

For an infrastructure regression:

1. stop further deployments to the affected environment;
2. inspect the current remote state and the last known-good Git commit;
3. prepare the corrective configuration change;
4. run the manual plan workflow against that commit after it is merged to `main`;
5. inspect replacements/deletions explicitly;
6. use the controlled apply workflow only after review/approval.

For state corruption or accidental state changes, follow `bootstrap/state/README.md` and use GCS object version history. Do not automate `force-unlock`, state removal, or state restoration in these workflows.

## Relationship to issue #26

Issue #26 expands Dependabot coverage to Terraform providers/modules. It does not change this deployment trust model. Provider/module update PRs continue through credential-free Terraform CI; after merge, any real environment plan is still a separate manual WIF-authenticated action.

## What CI validates

Pull requests continue to run:

- `terraform fmt -check -recursive -diff`;
- `terraform init -backend=false` and `terraform validate`;
- `terraform test`;
- TFLint;
- Trivy IaC scanning.

No deployment workflow is automatically dispatched by a PR, and implementing issue #28 does not execute `terraform apply`, `terraform destroy`, or any live Google Cloud mutation.
