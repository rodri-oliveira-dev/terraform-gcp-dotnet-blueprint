# Real GCP integration validation

Issue #29 defines how the blueprint is validated against real Google Cloud control-plane APIs without turning pull-request validation into a deployment path.

The validation target is **development only**. Production is deliberately excluded.

## Validation layers

The repository uses three distinct validation layers:

| Layer | Credentials | Google Cloud access | Mutation |
| --- | --- | --- | --- |
| Pull-request CI | none | none | never |
| Manual `Terraform plan` on `main` | WIF | real backend/provider APIs | never |
| Controlled `Terraform apply` | WIF | real backend/provider APIs | explicitly approved deployment only |

Issue #29 concerns the second layer. It does not authorize or require an apply.

## Definition of real-GCP validation

A development validation is considered real only when all of the following are true:

1. the run is dispatched from `refs/heads/main`;
2. GitHub OIDC successfully exchanges through the configured Workload Identity Federation provider;
3. the dedicated deployment service account is impersonated without a service-account key;
4. `terraform init` initializes `environments/dev` against the protected GCS backend;
5. Terraform can read the current development state and acquire the backend lock required by planning;
6. provider initialization succeeds with the committed lock file;
7. `terraform plan` completes with refresh enabled against the real development project;
8. the Job Summary contains only review-safe resource addresses/actions and no uploaded binary plan or full JSON plan.

The existing `.github/workflows/terraform-plan.yml` is the canonical WIF execution path for these checks. Issue #29 does not create a second privileged workflow.

## Prerequisites

Before running the validation, configure the repository variables documented in `docs/terraform-deployment.md`, including:

- `GCP_WORKLOAD_IDENTITY_PROVIDER`;
- `GCP_SERVICE_ACCOUNT`;
- `GCP_TERRAFORM_STATE_BUCKET`;
- `GCP_DEV_PROJECT_ID`;
- the three development container image variables;
- `TF_DEV_ENABLE_WORKLOADS` matching the actual desired activation state.

The development project must be isolated enough that a Terraform plan can safely inspect its state and APIs. The deployment identity needs read access required by provider refreshes plus access to the GCS state objects. If the plan is also intended to describe future changes, it needs the capability-specific permissions documented for the deployment identity in `docs/terraform-deployment.md`.

Do not grant `roles/owner` or `roles/editor` merely to make validation pass.

## API catalog preflight helper

`.github/scripts/gcp-integration-preflight.sh` is a read-only operator helper. It verifies:

- an access token can be obtained from the current Google Cloud identity;
- the configured development project can be resolved;
- every API declared in `environments/dev/local.required_services` exists in the Service Usage catalog;
- which of those services are currently enabled.

The helper does not enable APIs. A service being disabled is reported rather than treated as failure because `environments/dev` deliberately owns service enablement through `google_project_service` resources.

Run the helper only in a trusted authenticated operator context:

```bash
export GCP_PROJECT_ID="my-dev-project"
export GITHUB_STEP_SUMMARY="$(mktemp)"
bash .github/scripts/gcp-integration-preflight.sh
cat "$GITHUB_STEP_SUMMARY"
```

For GitHub Actions, WIF remains the authoritative authentication mechanism. The helper is intentionally not wired into an additional credentialed workflow.

## Plan coverage helper

`.github/scripts/terraform-plan-coverage.sh` checks a saved development plan without reading or printing planned values. It inspects only Terraform resource type names and verifies representation of the major architecture contracts:

- Cloud Run service;
- Cloud Run Job;
- Cloud Scheduler;
- VPC and subnet;
- Private Service Access allocation and connection;
- Pub/Sub topic/subscription;
- Secret Manager;
- Memorystore for Redis;
- Cloud Monitoring alert policy.

Example for a trusted local reproduction:

```bash
export TF_ROOT="environments/dev"
export GITHUB_STEP_SUMMARY="$(mktemp)"
bash .github/scripts/terraform-plan-coverage.sh /path/to/dev.tfplan
cat "$GITHUB_STEP_SUMMARY"
```

The GitHub plan workflow deliberately does **not** upload its binary plan as an artifact because plans can contain state-derived sensitive values. Therefore this helper is primarily useful for trusted local reproduction or future controlled runner integration.

## Full graph versus foundation phase

`environments/dev` has a two-phase lifecycle.

When `TF_DEV_ENABLE_WORKLOADS=false`, a real plan validates the foundation path: APIs, VPC/Private Service Access, Redis, identities, Secret Manager metadata/IAM and remote state. Cloud Run workloads, Pub/Sub delivery, Scheduler and their alert policies are intentionally absent.

After secret bootstrap and the documented one-way activation to `TF_DEV_ENABLE_WORKLOADS=true`, the same manual plan also exercises the complete workload graph.

Do not temporarily change the repository variable merely to make a validation checklist green. The variable must represent the real desired state of the development environment.

## Coverage by capability

| Capability | What issue #29 can validate without apply | What remains unproven |
| --- | --- | --- |
| Cloud Run services | provider configuration/planning; refresh of existing services | image startup, health and invocation |
| Cloud Run Job | provider configuration/planning; refresh of an existing job | successful job execution |
| Pub/Sub | topic/subscription/IAM planning; refresh when present | delivery, retry and DLQ behavior |
| Cloud Scheduler | scheduler configuration/planning; refresh when present | successful authenticated trigger |
| Secret Manager | metadata/IAM planning; refresh when present | application payload correctness/availability |
| VPC / Private Service Access | network, subnet, range and connection planning; refresh when present | successful creation in a new address plan |
| Memorystore for Redis | instance planning; refresh when present | client AUTH/TLS connectivity and application behavior |
| Cloud Monitoring | alert-policy planning; refresh when present | metric production, incident firing and notification delivery |

A successful plan is stronger than offline mocks because it uses the real provider, real backend and current project/state. It is still not equivalent to successfully creating and exercising resources.

## Costs and mutation boundary

This validation creates no Google Cloud resources and contains no apply/destroy step. It makes control-plane read requests and backend state/lock operations only.

Existing development resources may already incur normal service costs; those costs are not created by the validation run itself.

Any future smoke test that creates temporary billable resources must be a separate, explicit, manual capability with:

- user authorization before mutation;
- a documented maximum scope/cost expectation;
- deterministic ownership/labels;
- an explicit cleanup procedure;
- no automatic production execution.

No such resource-creating smoke test is part of issue #29.

## Evidence required to close issue #29

Do not close issue #29 merely because this documentation and tooling have merged. Record a successful manual `Terraform plan` run from `main` for `dev` and capture:

- workflow run ID;
- commit SHA;
- confirmation that WIF authentication succeeded;
- confirmation that remote GCS backend initialization succeeded;
- Terraform plan conclusion (`0` no changes or `2` changes);
- whether `TF_DEV_ENABLE_WORKLOADS` was `false` (foundation coverage) or `true` (full workload coverage);
- any provider/API error discovered and the fix or documented limitation.

The issue can be considered fully complete only after that evidence exists. Production validation remains outside its scope.
