# Production readiness guide

This document is the operator-oriented entry point for adopting the blueprint. It consolidates lifecycle order, environment policy, security boundaries, recovery expectations, known limitations and release-readiness criteria without duplicating low-level module contracts.

## What production-ready means here

The repository is **production-oriented**, not production-prescriptive. The v1.0 baseline demonstrates secure composition, delivery controls and operational boundaries that can be adapted to a real workload. It does not prove that the default capacity, SLOs, public-edge design or organization IAM model are appropriate for every production system.

Before adopting the blueprint, treat every default as a reviewed starting point rather than an implicit recommendation.

## Zero-to-environment walkthrough

### 1. Prepare the Google Cloud projects and ownership model

Decide which projects own:

- the Terraform state bucket;
- Workload Identity Federation and the deployment service account;
- `dev` infrastructure;
- `prod` infrastructure.

They may be the same project for a small reference deployment or separate projects in a stricter organization. When they differ, grant the deployment service account access independently to each resource/project boundary.

Review the default `us-central1` region, subnet/PSA CIDRs and organization policies before any apply.

### 2. Bootstrap remote state

Use `bootstrap/state` with an operator credential. The root deliberately starts with local state.

```bash
cd bootstrap/state
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform fmt -check
terraform validate
terraform plan
```

Apply only after review. Preserve the bootstrap local state securely. The resulting bucket uses object versioning, uniform bucket-level access, public access prevention, `force_destroy = false` and Terraform `prevent_destroy`.

See `bootstrap/state/README.md`.

### 3. Bootstrap GitHub Actions WIF

Use `bootstrap/github-actions-wif` with the protected GCS backend. Validate the immutable GitHub owner/repository IDs and the allowed ref (`refs/heads/main` by default).

The bootstrap creates the WIF pool/provider, dedicated deployment service account and impersonation relationship. It does not create a service-account key and does not grant broad workload-project access by default.

After apply, configure the repository variables documented in `docs/terraform-deployment.md`.

Run the manual `gcp-auth-smoke.yml` from `main` to prove OIDC -> WIF -> service-account impersonation before relying on credentialed Terraform workflows.

### 4. Configure deployment IAM deliberately

The deployment identity needs permissions for the capabilities it manages plus object access to the state bucket. Use the capability map in `docs/terraform-deployment.md` as a starting point.

Do not grant `roles/owner` or `roles/editor` simply to make Terraform pass. Prefer resource-level grants where the service permits them and derive custom roles if organizational controls require a narrower permission set.

### 5. Configure GitHub Environments and repository variables

Create GitHub Environments named `dev` and `prod`. `prod` should use Required Reviewers and, where governance permits, Prevent self-review.

Configure the repository variables for:

- WIF provider resource name;
- deployment service account;
- state bucket;
- dev/prod project IDs;
- API/worker/batch image URIs per environment;
- explicit `TF_<ENV>_ENABLE_WORKLOADS` values.

Do not place application secrets, Redis AUTH or CA payloads in repository variables.

### 6. Plan and apply the environment foundation

Start with `TF_<ENV>_ENABLE_WORKLOADS=false`.

The foundation creates the required service enablement declarations, VPC/subnet, Private Service Access, Redis, workload/transport identities, Secret Manager containers and scoped IAM. It deliberately does not create workloads that reference secret versions that do not exist yet.

Use the manual `Terraform plan` workflow to review the real backend/provider plan. Use `Terraform apply` only after explicit authorization.

### 7. Populate secret versions externally

Inspect the `secret_bootstrap` output and create current versions for the environment-specific application configuration, Redis AUTH and Redis CA secrets through a trusted process.

Terraform owns the secret containers and access policy, **not payload creation or rotation**. Never route these payloads through Terraform variables, GitHub repository variables, PR logs or plan artifacts.

### 8. Activate workloads

Change the selected repository variable to `TF_<ENV>_ENABLE_WORKLOADS=true`, review a new plan and use the controlled apply workflow.

This transition is intentionally one-way for a given state. Once activation has been applied as `true`, the activation lock rejects reverting the flag to `false` before Terraform can partially dismantle messaging/trigger/IAM resources and then stop at protected Cloud Run resources.

### 9. Verify observability and tune policy

When workloads are active, the environment composes the Cloud Monitoring alert baseline. Configure existing notification channel resource names if notifications are desired.

Treat the shipped thresholds as operational starting points, not SLOs. Tune them using observed traffic, capacity and incident history. Application teams must separately configure structured logging/tracing semantics and redact sensitive data.

### 10. Perform real-GCP validation deliberately

Offline CI is not evidence of real backend/API compatibility. Follow `docs/gcp-integration-validation.md` and record a successful manual development plan from `main` before claiming real-GCP plan validation.

A plan still does not prove runtime execution, delivery, Redis client connectivity or alert notification behavior.

## Dev versus prod policy

| Policy | dev | prod |
| --- | --- | --- |
| State prefix | `environments/dev` | `environments/prod` |
| Workload subnet default | `10.40.0.0/24` | `10.60.0.0/24` |
| PSA default | `10.50.0.0/16` | `10.70.0.0/16` |
| Redis | `BASIC`, 1 GiB | `STANDARD_HA`, 5 GiB default |
| API | 1 vCPU / 512 MiB, min 0, max 2 | 2 vCPU / 1 GiB, min 1, max 20 |
| Worker | 1 vCPU / 512 MiB, min 0, max 2 | 1 vCPU / 1 GiB, min 1, max 20 |
| Pub/Sub DLQ attempts | 10 | 20 |
| Batch | 1 task / parallelism 1 / 1 vCPU / 512 MiB | 4 tasks / parallelism 2 / 2 vCPU / 2 GiB |
| Scheduler retries | 3 | 5 |
| Cloud Run 5xx alert | 10% | 5% |
| Oldest Pub/Sub unacked age | 600s | 300s |
| Redis memory thresholds | 90% | 80% |

These are reference values. Production adoption requires capacity testing and product-specific reliability goals.

## IAM boundaries

The architecture separates identities by purpose:

- API runtime;
- worker runtime;
- batch runtime;
- Pub/Sub push transport;
- Scheduler trigger;
- GitHub Actions deployment.

Runtime identity modules do not grant generic project roles. The API receives topic publisher permission only for its application topic. Secret accessor grants are applied per secret. Invocation grants are resource-scoped where supported.

Review all project-level deployment permissions separately from runtime IAM. A powerful Terraform deployer is not a reason to make runtime identities powerful.

## State recovery

Treat state recovery as an incident procedure.

1. Stop deployments for the affected environment.
2. Preserve the current state object/generation for investigation.
3. Identify the last known-good GCS object generation and matching Git commit.
4. Determine whether the problem is state corruption, configuration drift or a legitimate infrastructure change.
5. Restore a prior object generation only after confirming it represents the intended state.
6. Run `terraform plan` before any apply and investigate unexpected create/delete/replacement actions.
7. Do not automate `force-unlock`, `state rm`, state restoration or imports in generic CI.

Object versioning provides recovery history; it does not eliminate the need for operator judgment.

## Deletion protection

Several destructive paths are intentionally guarded:

- the state bucket has Terraform `prevent_destroy` and `force_destroy = false`;
- Cloud Run and Redis use provider-level deletion protection by default;
- workload activation uses a Terraform `prevent_destroy` lock;
- the apply workflow blocks delete/replacement actions unless `allow_destroy=true` is explicitly selected.

Intentional deletion therefore requires explicit configuration changes and a reviewed plan. Do not remove multiple layers of protection in one unreviewed change.

## Secret ownership

Terraform may persist provider-computed sensitive values in state even when outputs do not expose them. For this reason:

- remote-state access is sensitive;
- secret payloads/versions are managed outside Terraform;
- Redis AUTH and CA material are not outputs;
- GitHub variables contain identifiers/configuration only;
- application logging must not emit Secret Manager payloads, authorization headers, cookies or Redis credentials.

## Known limitations and deliberate non-goals

The v1.0 baseline intentionally leaves the following to adopters:

- public ingress/edge architecture (external load balancer, API Gateway, Cloud Armor, DNS, certificates);
- container build/release pipelines and actual .NET business application code;
- relational databases and database migration workflows;
- organization/folder policy, billing governance and enterprise networking integration;
- Cloud NAT/general outbound-internet architecture;
- secret payload creation/rotation automation;
- workload-specific SLO targets and burn-rate policies;
- generic custom dashboards without an operational question;
- load/performance/chaos testing;
- runtime verification of Pub/Sub delivery, batch execution, Redis client AUTH/TLS or alert notification delivery;
- automatic rollback, state surgery or destroy workflows;
- production capacity recommendations.

## Adoption checklist

Before reusing this repository in another project/organization:

- [ ] Replace immutable GitHub owner/repository IDs in the WIF bootstrap.
- [ ] Review the allowed Git ref and repository/environment protection rules.
- [ ] Choose project boundaries for state, WIF, dev and prod.
- [ ] Choose a globally unique state bucket and review bucket IAM.
- [ ] Review region, subnet CIDRs and PSA ranges against existing routes.
- [ ] Review all deployment IAM permissions; do not use basic Owner/Editor roles.
- [ ] Replace image variables with controlled Artifact Registry/registry images.
- [ ] Decide how secret payload versions are created and rotated outside Terraform.
- [ ] Decide who may retrieve/distribute Redis AUTH and CA material.
- [ ] Review public-ingress requirements; do not assume the API is internet-accessible.
- [ ] Review `dev`/`prod` sizing and scaling against workload demand.
- [ ] Review Pub/Sub retry/DLQ settings against message semantics.
- [ ] Review batch task count/parallelism/retries against idempotency.
- [ ] Configure notification channels outside this state where required.
- [ ] Define real SLIs/SLOs from product requirements rather than copying alert thresholds.
- [ ] Configure GitHub Environment protection for production.
- [ ] Validate WIF with the smoke workflow from `main`.
- [ ] Complete real-GCP `dev` plan validation and retain the evidence.
- [ ] Establish state-recovery ownership and practice the procedure before a real incident.
- [ ] Document any architecture extensions as separate reviewed changes/ADRs.

## v1.0.0 release-readiness checklist

The repository may be tagged `v1.0.0` only after human review confirms:

- [ ] README describes the implemented architecture and contains no obsolete roadmap/status language.
- [ ] Architecture, environment, deployment, observability and integration-validation docs agree with the code.
- [ ] State recovery, deletion protection and secret ownership are documented.
- [ ] Troubleshooting covers the main backend/WIF/provider/network/compute/messaging/cache/monitoring failure domains.
- [ ] Known limitations/non-goals are explicit.
- [ ] Adoption checklist is complete and understandable without repository-history context.
- [ ] `CHANGELOG.md` and `docs/releases/v1.0.0.md` have been reviewed.
- [ ] Current `main` passes format, validate, test, TFLint and Trivy.
- [ ] No unresolved review thread remains from roadmap-closing PRs.
- [ ] Issue #29 either contains successful real-GCP plan evidence or the release is explicitly labeled as not yet real-GCP-plan-validated.
- [ ] No state, real `.tfvars`, plan artifact, credentials or secret payload has been committed.
- [ ] No `terraform apply`/`destroy` was performed merely to prepare release documentation.

The checklist prepares the release; it does not create a tag or GitHub Release automatically.
