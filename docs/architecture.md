# Architecture Overview

## Purpose

This repository is a reference implementation for provisioning production-oriented .NET workloads on Google Cloud with Terraform.

The repository separates reusable infrastructure capabilities from environment-specific composition. Application code is deliberately kept out of scope except where a minimal container image or sample workload is required to validate infrastructure behavior.

## Architectural boundaries

### Bootstrap

`bootstrap/` contains infrastructure that must exist before the regular Terraform roots can use it, such as the Cloud Storage bucket used for remote state and the Workload Identity Federation trust used by GitHub Actions.

Bootstrap code must remain intentionally small because it has a different lifecycle from workload infrastructure.

`bootstrap/state` is self-bootstrapping and deliberately starts with local state. `bootstrap/github-actions-wif` is created after the state bucket exists and therefore uses the GCS backend.

### Reusable modules

`modules/` contains focused child modules. Each module should:

- own one infrastructure capability or tightly related capability set;
- expose explicit inputs and outputs;
- avoid environment-specific assumptions;
- avoid hidden cross-module dependencies;
- include validation for relevant inputs;
- document security-sensitive defaults.

Reusable modules do not configure provider credentials or backends. Roots inject project, region, identities, and environment-specific policy.

### Environment roots

`environments/dev` and `environments/prod` are Terraform root modules. They compose reusable modules and contain environment-specific configuration.

Environment roots are responsible for:

- provider configuration;
- backend configuration;
- module composition;
- environment-specific sizing and scaling;
- environment-specific labels and policy choices.

### Examples

`examples/` demonstrates isolated module consumption where doing so improves discoverability or testability. Examples are not substitutes for the environment roots.

## Target runtime architecture

The initial reference workload consists of:

1. A .NET API hosted on a Cloud Run v2 service.
2. Pub/Sub for asynchronous message delivery.
3. A request-serving Cloud Run v2 worker service that receives Pub/Sub push deliveries.
4. A separate Cloud Run Job for finite batch or scheduled processing, invoked through supported execution mechanisms such as Cloud Scheduler calling the authenticated Cloud Run Admin API.
5. Secret Manager for runtime secrets.
6. Memorystore for Redis for managed caching.
7. Google Cloud IAM using least-privilege service accounts.
8. Cloud Logging and Monitoring integrations for operational visibility.

Pub/Sub does not directly execute a Cloud Run Job. Jobs expose an execution API rather than a request-serving endpoint, so event-driven message consumption is modeled through a Cloud Run service. Jobs remain available for workloads that are explicitly started and run to completion.

### Cloud Run service module boundary

`modules/cloud-run-service` owns a single request-serving `google_cloud_run_v2_service`. It is designed for both .NET APIs and request-serving worker services.

The module controls workload-level configuration that belongs to the service itself:

- container image and request port;
- CPU, memory, CPU idle behavior, and startup CPU boost;
- per-instance concurrency and request timeout;
- revision-level automatic scaling bounds;
- runtime service-account assignment;
- literal environment variables and Secret Manager-backed environment references;
- labels, ingress, and deletion protection.

The module deliberately does **not** create service accounts, IAM grants, secrets, secret versions, VPC resources, Pub/Sub resources, or environment roots. Those capabilities remain separate so identity, access, networking, and environment policy are composed explicitly by callers.

A runtime service account is required rather than allowing Cloud Run to fall back implicitly to a project default identity. Secret-backed environment variables carry only a secret identifier and version; Terraform source never receives an application secret payload through this module.

Secure defaults favor internal-only ingress, provider-level deletion protection, scale-to-zero, a bounded maximum instance count, and no public invocation IAM. A caller may choose broader ingress, but unauthenticated invocation requires a separate IAM decision outside this module.

## Delivery architecture

GitHub Actions validates Terraform changes before merge. Authentication to Google Cloud uses Workload Identity Federation instead of long-lived service account keys.

The intended delivery flow is:

```text
Pull Request
    |
    +--> terraform fmt
    +--> terraform validate
    +--> terraform test
    +--> TFLint
    +--> security scanning

Merge / approved deployment
    |
    +--> GitHub OIDC
            |
            v
       Workload Identity Federation
            |
            v
       Dedicated deployment service account
            |
            v
       Google Cloud
```

### GitHub OIDC trust boundary

The Google Cloud trust configuration is managed by `bootstrap/github-actions-wif`.

The provider uses GitHub's OIDC issuer and admits tokens only when the immutable numeric GitHub owner ID and repository ID match the configured values and the token ref matches the explicitly allowed ref. Repository and owner names are not authorization boundaries.

The federated repository principal receives only `roles/iam.workloadIdentityUser` on the dedicated deployment service account. The service account itself receives no Google Cloud project role by default. Concrete deployment permissions are added only when a later capability demonstrates that they are required, preferably at resource scope where the target service supports it.

The GitHub side is implemented by `.github/workflows/gcp-auth-smoke.yml`. The workflow is manually invoked from `main`, where the default trust condition accepts the token ref. Workflow-wide permissions start empty, and only the authentication job receives `contents: read` plus `id-token: write`.

The workflow uses `google-github-actions/auth` with the full provider resource name and dedicated service account, then runs `gcloud auth print-access-token` to force an actual token exchange and impersonation. Pull-request validation remains credential-free and therefore cannot authenticate to Google Cloud accidentally.

## State strategy

Terraform workload state will be stored remotely in Google Cloud Storage. State files and local variable files must never be committed to Git.

The remote-state bucket is created by the independent `bootstrap/state` root. That bootstrap deliberately starts with local state because using the bucket as its own backend would create a circular dependency.

The state bucket enables object versioning, uniform bucket-level access, and enforced public access prevention. Destructive removal is guarded with both `force_destroy = false` and Terraform lifecycle protection.

Each workload root must use a distinct GCS backend prefix, such as `environments/dev` or `environments/prod`, to isolate state. Existing local state must be migrated explicitly with `terraform init -migrate-state`; migration is an operator-reviewed action rather than an implicit repository automation step.

See `bootstrap/state/README.md` for the bootstrap, backend migration, and recovery procedures.

## Security principles

- No service account keys stored in GitHub secrets.
- GitHub OIDC trust is constrained by immutable owner/repository identifiers and an explicit Git ref.
- OIDC permission is granted only to jobs that need to exchange a token.
- Pull-request quality gates remain credential-free.
- Generated `gha-creds-*.json` files are ignored.
- Runtime workload identities are explicit rather than implicit project defaults.
- Least-privilege IAM roles wherever practical.
- Deployment identities receive no broad project role by default.
- Secrets are referenced from Secret Manager rather than stored in Terraform configuration.
- Terraform state is treated as sensitive data.
- Public access is disabled unless explicitly required by the reference scenario.
- CI security checks should fail before deployment when high-confidence issues are detected.

## Evolution

The architecture is intentionally incremental. Each roadmap issue should leave the repository in a valid, reviewable state rather than introducing all infrastructure in a single change.
