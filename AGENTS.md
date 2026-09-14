# Agent Instructions

This repository is a production-oriented Terraform reference architecture for .NET workloads on Google Cloud. Treat infrastructure correctness, security, reproducibility, and documentation as first-class requirements.

## Read first

Before changing code, read the relevant sources of truth in this order:

1. `README.md` for project intent and roadmap.
2. `docs/architecture.md` for architectural boundaries.
3. Applicable records under `docs/adr/`.
4. The GitHub issue being implemented, including its Definition of Ready and Definition of Done.
5. `docs/agent-workflow.md` for the repository execution workflow.
6. Relevant project skills under `.agents/skills/`.

Do not assume a previous issue or prompt was implemented correctly. When the current issue depends on earlier work, validate the prerequisite DoD before making changes.

## Skill routing

Load the smallest relevant skill set for the task:

- Terraform HCL authoring or review: `terraform-style-guide`.
- Reusable child modules, root-module boundaries, interfaces, or refactoring: `terraform-module-engineering`.
- `.tftest.hcl`, mocks, assertions, or test strategy: `terraform-testing`.
- GCP IAM, remote state, Secret Manager, Workload Identity Federation, or infrastructure security: `gcp-terraform-security`.
- GitHub Actions authoring or review: `github-actions-hardening`.

Use multiple skills when a change crosses concerns. Do not load unrelated skills merely because they exist.

## Repository boundaries

Preserve these architectural responsibilities:

- `bootstrap/` owns infrastructure that must exist before workload roots, such as remote state.
- `modules/` contains reusable child modules with explicit typed inputs and documented outputs.
- `environments/` contains root modules and owns backend, provider configuration, environment composition, sizing, and policy choices.
- `examples/` demonstrates isolated consumption and must not become a second production root.
- `docs/adr/` records decisions with meaningful architectural trade-offs.

Reusable modules must not configure Terraform backends or provider credentials. Provider requirements are allowed; provider configuration belongs to root modules.

## Security requirements

These are non-negotiable unless an ADR explicitly documents a justified exception:

- Never commit credentials, private keys, secret values, Terraform state, or sensitive `.tfvars` files.
- Do not introduce long-lived Google Cloud service-account keys for CI/CD. Prefer Workload Identity Federation.
- Apply least privilege to Google Cloud IAM and GitHub workflow permissions.
- Prefer additive `google_*_iam_member` resources when ownership of the whole IAM policy is not explicit; authoritative bindings/policies require deliberate justification.
- Treat Terraform state as sensitive data.
- Public access must be disabled by default.
- Secret Manager resources may manage secret metadata and access, but application secret payloads must not be hard-coded in Terraform.
- GitHub Actions must use explicit minimal `permissions:` and immutable action references where practical.

## Runtime architecture constraint

Do not model Pub/Sub as directly invoking a Cloud Run Job. Event-driven Pub/Sub push delivery targets a request-serving Cloud Run service. Cloud Run Jobs are finite batch workloads and must use a supported execution mechanism such as Cloud Scheduler or an authenticated API invocation.

## Terraform conventions

- Follow HashiCorp formatting and style conventions.
- Use explicit variable types and descriptions.
- Add validation when an invalid value can be rejected locally.
- Add descriptions to outputs and mark sensitive outputs appropriately.
- Prefer stable resource identity (`for_each`) when managing named collections.
- Avoid unnecessary `depends_on`; express dependencies through references.
- Keep modules cohesive rather than overly generic.
- Keep environment-specific constants out of reusable modules.
- Pin Terraform and provider compatibility intentionally; commit dependency lock files for root modules.

## Change workflow

For issue implementation:

1. Validate the issue DoR and prerequisite DoD.
2. Inspect the existing implementation before editing.
3. Make the smallest coherent change that fully satisfies the current scope.
4. Update documentation when behavior, architecture, security assumptions, or operator steps change.
5. Add or update tests for module behavior when meaningful.
6. Run all practical validation checks before considering the work complete.
7. Compare the result against every DoD item and report anything that could not be validated.

Never run `terraform apply`, destroy infrastructure, rotate credentials, or mutate live cloud resources unless the user explicitly requests that action.

## Validation baseline

Run the applicable checks after changes:

```bash
terraform fmt -check -recursive
terraform validate
terraform test
tflint --recursive
```

Initialization may be required before validation. For validation-only workflows, avoid live backends and use `terraform init -backend=false` where appropriate.

When security tooling exists in the repository, run it as part of the relevant change. Do not claim a check passed if the tool was unavailable or credentials/network access prevented execution.

## Pull requests

- Keep one architectural capability per issue/PR unless the issue explicitly combines them.
- Explain what changed, why it changed, security implications, and validation performed.
- Link the implemented issue and use closing keywords only when its DoD is fully satisfied.
- Do not silently broaden scope to unrelated cleanup.
- Resolve review comments with code or a technically justified response; do not dismiss valid findings merely to clear a review.
