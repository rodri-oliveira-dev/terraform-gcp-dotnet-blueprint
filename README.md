# Terraform GCP .NET Blueprint

Production-oriented Terraform blueprint for running .NET workloads on Google Cloud, with reusable modules, secure defaults, CI/CD, IAM, secrets, messaging, caching, observability, and multi-environment infrastructure patterns.

> **Status:** Infrastructure implementation in progress.

## Goals

This repository demonstrates how to structure production-oriented Infrastructure as Code for .NET workloads on Google Cloud using Terraform.

The project is intentionally focused on infrastructure architecture rather than application complexity. It aims to demonstrate:

- reusable Terraform modules;
- explicit environment composition;
- secure-by-default IAM and secret management;
- Cloud Run services and jobs;
- asynchronous messaging with Pub/Sub;
- managed caching with Memorystore for Redis;
- observability and operational readiness;
- automated validation and security checks;
- remote state and CI/CD-friendly authentication;
- documented architectural decisions.

## Target architecture

```mermaid
flowchart TD
    Internet[Internet] --> API[Cloud Run Service\n.NET API]
    API --> Secrets[Secret Manager]
    API --> PubSub[Pub/Sub]
    API --> Redis[Memorystore for Redis]

    PubSub --> Worker[Cloud Run Service\n.NET Worker]
    Worker --> Secrets
    Worker --> Redis

    Scheduler[Cloud Scheduler] --> JobAPI[Cloud Run Admin API]
    JobAPI --> Batch[Cloud Run Job\n.NET Batch Worker]
    Batch --> Secrets
    Batch --> Redis

    GitHub[GitHub Actions] --> WIF[Workload Identity Federation]
    WIF --> GCP[Google Cloud]
```

Pub/Sub messages are consumed by a request-serving Cloud Run service. Cloud Run Jobs are modeled separately for finite batch or scheduled workloads and are invoked through supported execution mechanisms such as Cloud Scheduler calling the authenticated Cloud Run Admin API. Pub/Sub is therefore not modeled as directly launching a Cloud Run Job.

## Planned repository structure

```text
.
├── .agents/
│   └── skills/
├── .github/
│   ├── dependabot.yml
│   └── workflows/
├── bootstrap/
│   ├── github-actions-wif/
│   └── state/
├── docs/
│   ├── architecture.md
│   ├── agent-skills.md
│   ├── agent-workflow.md
│   └── adr/
├── environments/
│   ├── dev/
│   └── prod/
├── modules/
│   ├── cloud-run-service/
│   ├── cloud-run-job/
│   ├── iam/
│   ├── memorystore/
│   ├── pubsub/
│   └── secret-manager/
├── examples/
│   └── minimal/
├── AGENTS.md
├── .terraform-version
├── .tflint.hcl
└── README.md
```

## Design principles

1. **Secure by default** — no long-lived cloud credentials in the repository or CI/CD pipeline.
2. **Least privilege** — IAM permissions are scoped to the minimum required access.
3. **Reusable modules** — infrastructure capabilities are isolated behind explicit inputs and outputs.
4. **Environment composition** — environments consume modules instead of duplicating resource definitions.
5. **Automated quality gates** — formatting, validation, linting and security checks run before changes are merged.
6. **Documented decisions** — relevant trade-offs are captured as Architecture Decision Records.
7. **Production-oriented, not production-prescriptive** — the repository demonstrates patterns that should be adapted to each workload and organization.

## Agent-assisted development

The repository includes project-specific instructions and Agent Skills so Codex can execute issue work consistently across separate chat sessions.

- [`AGENTS.md`](AGENTS.md) is the concise repository instruction map.
- [`docs/agent-workflow.md`](docs/agent-workflow.md) defines the issue, validation, safety, and pull-request workflow.
- [`docs/agent-skills.md`](docs/agent-skills.md) documents the selected skill stack and its sources.
- [`.agents/skills/`](.agents/skills/) contains focused skills for Terraform style, module engineering, testing, GCP security, and GitHub Actions hardening.

Agents must revalidate prerequisite DoD items rather than assuming work from a previous prompt or chat is correct.

## Remote state bootstrap

`bootstrap/state` is an independent Terraform root that creates the Cloud Storage bucket used by later workload roots as their GCS backend.

The bucket is secure by default: object versioning is enabled, uniform bucket-level access is enabled, public access prevention is enforced, `force_destroy` is disabled, and Terraform lifecycle protection prevents accidental destruction.

Bootstrap remains local by design so the repository does not introduce a circular dependency where Terraform needs a remote backend before it can create that backend.

See [`bootstrap/state/README.md`](bootstrap/state/README.md) for prerequisites, initialization, manual apply, backend configuration, migration from local state, recovery guidance, and environment-specific state prefixes.

## GitHub Actions keyless authentication

`bootstrap/github-actions-wif` provisions the Google Cloud trust foundation for keyless GitHub Actions authentication: required APIs, a Workload Identity Pool and GitHub OIDC provider, a dedicated deployment service account, and the service-account impersonation binding.

The trust policy uses immutable GitHub owner and repository IDs and is restricted to `refs/heads/main` by default. The deployment service account receives no project role unless one is explicitly supplied, and broad `roles/owner` / `roles/editor` grants are rejected.

`.github/workflows/gcp-auth-smoke.yml` completes the GitHub side. It is manually triggered from `main`, requests only `contents: read` and `id-token: write`, authenticates with `google-github-actions/auth`, and forces a real access-token exchange through the dedicated service account. No service account key is stored in GitHub.

See [`bootstrap/github-actions-wif/README.md`](bootstrap/github-actions-wif/README.md) for bootstrap instructions, required repository variables, the trust model, smoke-test procedure, and security invariants.

## Terraform validation pipeline

Pull requests run independent quality gates for Terraform formatting, root validation, TFLint, and Trivy IaC security scanning. GitHub Actions are pinned to immutable commit SHAs and monitored by Dependabot for reviewed version updates.

See [`docs/terraform-ci.md`](docs/terraform-ci.md) for root discovery, security assumptions, dependency-update policy, and local reproduction commands.

## Roadmap

The implementation will evolve incrementally:

1. Terraform foundation and repository conventions.
2. Remote state bootstrap on Cloud Storage.
3. Terraform CI, linting and security scanning.
4. GitHub Actions authentication through Workload Identity Federation.
5. Cloud Run v2 service module for .NET APIs and request-serving workers.
6. Pub/Sub worker-service integration plus Cloud Run Job support for scheduled/batch processing.
7. Secret Manager, least-privilege IAM and Memorystore for Redis.
8. Observability, environment composition and production-readiness documentation.

## Current toolchain

- Terraform CLI: pinned through `.terraform-version`.
- Google provider: version constraints are declared by each Terraform root/module as appropriate; current bootstrap roots target Google provider 8.x and commit their dependency lock files.
- TFLint: Terraform recommended rules plus the Google Cloud ruleset.
- Dependabot: weekly GitHub Actions version updates with grouped minor/patch upgrades and isolated major upgrades.
- Google Cloud CLI: pinned in the WIF smoke test for reproducible authentication verification.

## License

Licensed under the MIT License. See [LICENSE](LICENSE).
