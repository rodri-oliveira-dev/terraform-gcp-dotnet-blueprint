# Changelog

All notable changes to this project are documented in this file.

The repository follows semantic-versioning intent for published releases. Until a tag is created, the `v1.0.0` section below is a release candidate draft prepared for human review.

## [v1.0.0] - Unreleased

### Added

- production-oriented Terraform repository foundation and conventions;
- protected GCS remote-state bootstrap with versioning, uniform bucket-level access and public access prevention;
- GitHub Actions Workload Identity Federation using immutable repository/owner IDs and no service-account keys;
- credential-free Terraform CI with format, validate, native tests, TFLint and Trivy gates;
- reusable Cloud Run v2 service module for API/request-serving workers;
- reusable Cloud Run v2 Job module for finite batch workloads;
- Pub/Sub topic/subscription composition with authenticated push, retries and dead-letter handling;
- workload-specific runtime identities and Secret Manager metadata/access modules;
- custom-mode VPC, Direct VPC egress and Private Service Access module;
- private Memorystore for Redis module with AUTH/TLS and HA-oriented defaults;
- complete `dev` and `prod` environment roots with explicit policy differences;
- Cloud Monitoring alert-policy module and environment integration;
- controlled manual Terraform plan/apply workflows using WIF, plan fingerprints, destructive-change acknowledgement and GitHub Environment gates;
- real-GCP integration-validation procedure/tooling for development plans without applying resources;
- Dependabot coverage for GitHub Actions and Terraform dependencies;
- production-readiness, troubleshooting, adoption and release-readiness documentation.

### Security

- no long-lived GCP credential is required by GitHub Actions;
- no public Cloud Run invocation is granted by default;
- runtime and transport identities are separated;
- Secret Manager payload versions remain outside Terraform;
- Redis AUTH/CA payloads are not exposed as module outputs;
- Terraform state is isolated by environment prefix and treated as sensitive data;
- destructive operations are guarded by lifecycle/provider protections and workflow policy;
- GitHub Actions are pinned to immutable commit SHAs.

### Operational notes

- environment bootstrap is intentionally two-phase because secret payloads are external to Terraform;
- workload activation is a one-way transition per state and is not a destroy toggle;
- production sizing/thresholds are reference defaults and require workload-specific review;
- issue #29 tracks evidence for successful real-GCP WIF/backend/provider plan validation;
- runtime smoke testing, public-edge design, secret rotation, load testing and product-specific SLOs remain adopter responsibilities.
