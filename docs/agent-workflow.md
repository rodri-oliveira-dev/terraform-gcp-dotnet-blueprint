# Agent Implementation Workflow

This document defines how coding agents should execute repository work. `AGENTS.md` remains the concise index; this file contains the operational detail.

## 1. Establish task context

Before editing:

1. Read the target issue completely.
2. Identify explicit and implicit prerequisites.
3. Read the architecture documentation and ADRs affected by the change.
4. Inspect existing code instead of relying on issue text alone.
5. Load only the project skills relevant to the task.

If the issue has a Definition of Ready, treat it as a gate. If a prerequisite issue has a Definition of Done, verify the relevant artifacts in the repository rather than assuming completion from issue state alone.

## 2. Plan around architectural boundaries

Classify each change before writing code:

- **Bootstrap infrastructure**: prerequisites with a separate lifecycle, such as remote state.
- **Reusable module**: a focused infrastructure capability with a typed interface.
- **Environment root**: provider/backend configuration and composition of reusable modules.
- **Delivery automation**: GitHub Actions, authentication, planning, validation, and deployment controls.
- **Documentation/decision**: operator guidance or an architectural decision with trade-offs.

If a requested implementation crosses several categories, keep each responsibility in its proper directory rather than collapsing them into a convenience module.

## 3. Implement incrementally

Prefer a sequence that keeps the branch reviewable:

1. version/provider constraints and interfaces;
2. resource implementation;
3. outputs and dependency contracts;
4. tests;
5. documentation;
6. CI/security integration when in scope.

Do not add speculative abstractions for hypothetical future requirements. The repository is a reference architecture, so clarity and explicit trade-offs are more valuable than generic frameworks.

## 4. Terraform validation strategy

Use the cheapest meaningful checks first.

### Formatting

```bash
terraform fmt -check -recursive
```

### Initialization and static validation

For a standalone root or example when a live backend is not needed:

```bash
terraform init -backend=false
terraform validate
```

For reusable modules, initialize from the module directory when provider schemas are required for validation.

### Tests

Prefer plan-mode native Terraform tests and mock providers for unit behavior. Use apply-mode integration tests only when provider behavior cannot be validated statically or with mocks.

```bash
terraform test
```

Never create billable cloud resources merely to satisfy a routine unit-test requirement.

### Lint and security

Run repository-configured lint/security tooling when available. Findings should be fixed or explicitly justified. Do not suppress a rule solely to make CI green.

## 5. Plan and apply safety

A generated plan is review material, not authorization to deploy.

Agents may run `terraform plan` when credentials and a safe target environment are available and the task requires it. Agents must not run `terraform apply`, `terraform destroy`, destructive state commands, or live IAM mutations unless the user explicitly requested the live operation.

Never paste state content, credentials, access tokens, or secret payloads into chat output, logs, test fixtures, or committed files.

## 6. Documentation and ADR rules

Update documentation when a change alters:

- module interfaces or supported usage;
- deployment/operator steps;
- authentication or security assumptions;
- state ownership;
- runtime interaction between services;
- environment responsibilities.

Create or update an ADR when the change represents a durable architectural decision with meaningful alternatives or consequences. Routine implementation details do not need an ADR.

## 7. Pull request completion

Before opening or updating a PR:

1. Review the diff for unrelated changes.
2. Re-run practical validation checks after the final edit.
3. Map the result explicitly to the issue DoD.
4. Mention any validation that could not be executed and why.
5. Describe security-sensitive behavior when relevant.
6. Request review only after the branch is internally consistent.

A later prompt working on the same issue must re-check the earlier prompt's work before extending it. Separate chat sessions are not evidence that previous implementation is correct.
