---
name: gcp-terraform-security
description: Apply Google Cloud security practices to Terraform state, IAM, Secret Manager, Workload Identity Federation, public access, and CI/CD authentication in this repository.
---

# GCP Terraform Security

Use this skill whenever Terraform changes touch Google Cloud identity, authentication, state, secrets, networking exposure, or security-sensitive service configuration.

## Terraform state

- Use a remote Cloud Storage backend for shared environments.
- Treat state as sensitive because providers may persist sensitive attributes even when outputs are marked sensitive.
- Enable appropriate bucket protections such as public access prevention, uniform bucket-level access, and versioning for the state bucket.
- Restrict state access to the deployment identity and necessary administrators.
- Never commit local state or state backups.

Bootstrap the state bucket separately so the backend does not depend on itself.

## CI authentication

For GitHub Actions, prefer Workload Identity Federation over service-account JSON keys.

- Request `id-token: write` only in jobs that authenticate through OIDC.
- Keep `contents: read` unless a job demonstrably needs broader repository permissions.
- Restrict federation with attribute conditions to the trusted GitHub organization/repository and, where appropriate, branch or environment.
- Prefer stable and authoritative identity claims.
- Grant the federated principal or impersonated service account only the roles required by the workflow.

This repository was created after GitHub's July 15, 2026 rollout of immutable default OIDC subjects for new repositories. When issue #4 configures Google Cloud trust, inspect the actual OIDC subject format and prefer conditions that preserve the immutable owner/repository identifiers rather than weakening trust back to reusable names only. Do not copy legacy `repo:owner/name:*` examples without validating the claims emitted for this repository.

Do not create long-lived service-account keys as a convenience workaround.

## IAM semantics

Understand the difference between authoritative and additive IAM resources before choosing one.

- Prefer `google_*_iam_member` when Terraform should add one principal/role relationship without owning the entire policy/binding.
- Use authoritative `google_*_iam_binding` or `google_*_iam_policy` only when the configuration intentionally owns that complete scope and the impact is documented.
- Avoid broad project roles when a narrower resource-level role is available.
- Keep runtime identities workload-specific where practical.

## Secret Manager

Terraform may create secret containers, IAM bindings, and secret references. Application secret payloads must not be hard-coded in source-controlled Terraform.

Grant secret access only to the workloads that require it. Do not expose secret values through ordinary outputs.

## Public exposure

Default to private/no-public-access. If a Cloud Run service or other resource must become public for the reference scenario, make the exposure explicit, documented, and narrowly scoped.

## Plans and live mutation

Review Terraform plans before apply, especially for IAM, bucket policies, service accounts, and resources whose replacement may cause downtime or data loss.

Never run `terraform apply`, `destroy`, force-unlock, state removal, or destructive IAM changes without explicit user authorization.

## Review checklist

- Is remote state protected and isolated appropriately?
- Are there any credential files or key-based CI authentication paths?
- Is federation restricted to trusted GitHub identities using the repository's actual immutable OIDC claims where available?
- Are IAM changes additive unless authoritative ownership is intentional?
- Are secret payloads absent from Terraform source and outputs?
- Is public access disabled unless explicitly required?
- Could the change unintentionally replace or revoke shared infrastructure/permissions?

## References

- https://cloud.google.com/docs/terraform/best-practices/security
- https://cloud.google.com/docs/terraform/best-practices/operations
- https://cloud.google.com/docs/terraform/best-practices/working-with-resources
- https://cloud.google.com/iam/docs/best-practices-for-using-workload-identity-federation
- https://cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines
- https://docs.github.com/en/actions/reference/security/oidc
