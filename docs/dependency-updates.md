# Automated dependency updates

This repository uses Dependabot as a preventive supply-chain control alongside the existing Terraform CI and IaC security gates.

## Covered ecosystems

The versioned configuration in `.github/dependabot.yml` covers:

- GitHub Actions from the repository root;
- Terraform dependencies across bootstrap roots, environment roots, examples, and reusable modules.

Terraform directories are expressed with directory patterns so new roots/modules that follow the repository structure inherit the maintenance policy without duplicating configuration.

## Update policy

Dependency checks run weekly in `America/Sao_Paulo`. Minor and patch updates may be grouped per ecosystem to reduce PR noise. Major updates remain separate because provider/module majors can change schemas, defaults, APIs, required permissions, or state behavior and therefore require explicit review.

An automated update PR is a proposal, not evidence that the version is safe to merge.

## Terraform lock files

Executable roots under `bootstrap/`, `environments/`, and `examples/` commit `.terraform.lock.hcl` where required by the repository CI. Provider updates affecting those roots must keep the lock file consistent with the declared constraints.

Reusable child modules do not need to commit their own dependency lock files. They are validated through module initialization/tests and through the roots that consume them.

## Required validation

Dependabot Terraform PRs must pass the same credential-free pull-request gates as manual changes:

- `terraform fmt -check`;
- `terraform init -backend=false` and `terraform validate`;
- `terraform test` for reusable modules that provide tests;
- TFLint;
- Trivy configuration scanning with the existing HIGH/CRITICAL blocking policy.

No `terraform apply` or `terraform destroy` is part of dependency-update validation. GCP credentials must not be introduced merely to validate provider/module version changes that can be checked offline.

## Scope boundary

CodeQL is not used to analyze HCL. Terraform validation, tests, TFLint, Trivy, provider lock files, and review of provider/module release notes remain the relevant controls for infrastructure code in this repository.
