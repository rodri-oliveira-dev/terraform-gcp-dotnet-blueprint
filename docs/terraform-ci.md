# Terraform CI

The repository validates Terraform changes in GitHub Actions before merge. The workflow is intentionally credential-free: static validation and unit tests do not authenticate to Google Cloud.

## Workflow

`.github/workflows/terraform-ci.yml` runs for pull requests and pushes to `main` with read-only repository permissions.

The workflow contains five independent quality gates:

1. **Terraform format** — runs `terraform fmt -check -recursive -diff` and fails when committed HCL is not formatted.
2. **Terraform validate** — discovers deployable roots under `bootstrap/`, `environments/`, and `examples/`, plus reusable child modules under `modules/`. Roots are initialized with `-backend=false`, require a committed `.terraform.lock.hcl`, and are validated with their locked providers. Reusable modules are initialized and validated independently without requiring a root lock file.
3. **Terraform test** — discovers reusable modules that contain `tests/*.tftest.hcl`, initializes them without a backend, and runs `terraform test`. Unit tests should prefer plan mode and mocked providers so pull requests do not create infrastructure or require cloud credentials.
4. **TFLint** — installs the version pinned in `.tflint-version`, initializes the repository configuration, and runs recursively with the Terraform recommended rules and the pinned Google Cloud ruleset from `.tflint.hcl`.
5. **IaC security scan** — runs Trivy configuration scanning and fails on HIGH or CRITICAL findings.

Each gate is a separate job so failures are easy to identify in pull-request checks.

## Terraform root and module discovery

Repository architecture defines deployable or independently initialized roots as direct child directories of:

- `bootstrap/`;
- `environments/`;
- `examples/`.

Every root must commit `.terraform.lock.hcl`. Root validation uses `terraform init -backend=false -lockfile=readonly` so CI cannot silently update provider selections.

Reusable child modules are discovered as direct child directories of `modules/` that contain Terraform files. They are validated independently even before an environment or example consumes them, which catches provider-schema errors, invalid references, and other semantic configuration failures early.

Reusable modules do not own backends or root dependency lock files. CI therefore initializes them with `terraform init -backend=false` and runs `terraform validate` without imposing the root lock-file requirement.

Modules with native Terraform tests under their `tests/` directory are also executed by the `Terraform test` job. The test job remains credential-free; tests that require live infrastructure must be placed in a separately controlled integration workflow rather than silently introduced into pull-request CI.

## Security and credentials

The Terraform CI workflow uses only:

```yaml
permissions:
  contents: read
```

It does not request `id-token: write`, does not consume Google Cloud credentials, and does not use service-account keys. Google Cloud authentication is isolated in workflows that explicitly need it, such as the WIF smoke test.

Third-party GitHub Actions are pinned to immutable commit SHAs, with the corresponding release version documented as an inline comment in the workflow.

## Dependency updates

`.github/dependabot.yml` enables Dependabot version updates for GitHub Actions.

The configuration is intentionally conservative:

- checks run weekly on Monday at 09:00 in `America/Sao_Paulo`;
- minor and patch Action updates are grouped into a single pull request to reduce review noise;
- major Action updates remain separate so breaking changes receive focused review;
- no more than five Dependabot version-update pull requests may remain open at once;
- Dependabot pull requests use the `chore(deps)` commit-message prefix;
- Actions remain pinned to immutable commit SHAs, with release tags kept as same-line comments so Dependabot can update the SHA and its version annotation together.

The Terraform Dependabot ecosystem is intentionally not enabled while this repository targets Terraform 1.16.x because GitHub currently documents Terraform ecosystem support only through Terraform 1.15.x. Provider updates therefore remain explicit changes reviewed through each root's `.terraform.lock.hcl` until official support catches up or the repository adopts another dependency-update mechanism.

## Local validation

Before opening a pull request, run the applicable checks locally.

### Formatting

```bash
terraform fmt -check -recursive -diff
```

### Root validation

For each Terraform root, for example `bootstrap/state`:

```bash
terraform -chdir=bootstrap/state init -backend=false -input=false -lockfile=readonly
terraform -chdir=bootstrap/state validate
```

### Reusable module validation

For each reusable module, for example `modules/cloud-run-service`:

```bash
terraform -chdir=modules/cloud-run-service init -backend=false -input=false
terraform -chdir=modules/cloud-run-service validate
```

Reusable modules intentionally do not require a committed `.terraform.lock.hcl`; provider selections are locked by the root modules that consume them.

### Native Terraform tests

For a module containing `tests/*.tftest.hcl`:

```bash
terraform -chdir=modules/cloud-run-service init -backend=false -input=false
terraform -chdir=modules/cloud-run-service test
```

Pull-request unit tests should use `command = plan` and mock providers whenever the Google Cloud API is not part of the behavior being tested.

### TFLint

Install the version from `.tflint-version`, then run:

```bash
tflint --init
tflint --recursive --format compact
```

### Security scanning

The GitHub workflow uses Trivy configuration scanning with HIGH and CRITICAL findings configured as blocking. Developers may reproduce the same policy locally with a compatible Trivy installation:

```bash
trivy config --severity HIGH,CRITICAL --exit-code 1 .
```

## Tool version policy

- Terraform CLI is pinned in `.terraform-version`.
- TFLint is pinned in `.tflint-version`.
- Terraform provider selections are pinned by each root's `.terraform.lock.hcl`.
- TFLint plugins are pinned in `.tflint.hcl`.
- GitHub Actions are pinned to immutable commit SHAs and monitored by Dependabot.

Version upgrades should be explicit repository changes so CI behavior does not drift without review.
