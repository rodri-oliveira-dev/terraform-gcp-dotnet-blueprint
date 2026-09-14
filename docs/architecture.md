# Architecture Overview

## Purpose

This repository is a reference implementation for provisioning production-oriented .NET workloads on Google Cloud with Terraform.

The repository separates reusable infrastructure capabilities from environment-specific composition. Application code is deliberately kept out of scope except where a minimal container image or sample workload is required to validate infrastructure behavior.

## Architectural boundaries

### Bootstrap

`bootstrap/` contains infrastructure that must exist before the regular Terraform roots can use it, such as the Cloud Storage bucket used for remote state.

Bootstrap code must remain intentionally small because it has a different lifecycle from workload infrastructure.

### Reusable modules

`modules/` contains focused child modules. Each module should:

- own one infrastructure capability or tightly related capability set;
- expose explicit inputs and outputs;
- avoid environment-specific assumptions;
- avoid hidden cross-module dependencies;
- include validation for relevant inputs;
- document security-sensitive defaults.

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

1. A .NET API hosted on Cloud Run v2.
2. Pub/Sub for asynchronous message delivery.
3. A Cloud Run Job for background processing.
4. Secret Manager for runtime secrets.
5. Memorystore for Redis for managed caching.
6. Google Cloud IAM using least-privilege service accounts.
7. Cloud Logging and Monitoring integrations for operational visibility.

## Delivery architecture

GitHub Actions will validate Terraform changes before merge. Authentication to Google Cloud will use Workload Identity Federation instead of long-lived service account keys.

The intended delivery flow is:

```text
Pull Request
    |
    +--> terraform fmt
    +--> terraform validate
    +--> TFLint
    +--> security scanning
    +--> terraform plan

Merge / approved deployment
    |
    +--> GitHub OIDC
            |
            v
       Workload Identity Federation
            |
            v
       Google Cloud
```

## State strategy

Terraform state will be stored remotely in Google Cloud Storage. State files and local variable files must never be committed to Git.

The remote-state bucket is bootstrapped separately from workload infrastructure to avoid a circular dependency between the backend and the infrastructure that creates it.

## Security principles

- No service account keys stored in GitHub secrets.
- Least-privilege IAM roles wherever practical.
- Secrets are referenced from Secret Manager rather than stored in Terraform configuration.
- Terraform state is treated as sensitive data.
- Public access is disabled unless explicitly required by the reference scenario.
- CI security checks should fail before deployment when high-confidence issues are detected.

## Evolution

The architecture is intentionally incremental. Each roadmap issue should leave the repository in a valid, reviewable state rather than introducing all infrastructure in a single change.
