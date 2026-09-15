---
name: github-actions-hardening
description: Author and review GitHub Actions workflows with least-privilege permissions, OIDC-based cloud authentication, immutable action references, safe trigger choices, and protection against untrusted-input injection.
---

# GitHub Actions Hardening

Use this skill whenever creating or modifying `.github/workflows/*.yml` or `.yaml`.

## Trigger trust boundaries

Understand who can cause a workflow to run and what privileges the workflow receives.

- Treat `pull_request_target`, `workflow_run`, `issue_comment`, and similar privileged/base-context triggers with extra scrutiny.
- Never combine a privileged trigger with checkout/execution of untrusted fork code.
- Prefer ordinary `pull_request` for validation of contributed code.

## Workflow permissions

Set explicit top-level or job-level `permissions:`. Start from the minimum and add only what a job needs.

Typical Terraform validation jobs need only:

```yaml
permissions:
  contents: read
```

A job authenticating to Google Cloud with GitHub OIDC additionally requires:

```yaml
permissions:
  contents: read
  id-token: write
```

Do not grant `write-all` or broad write scopes for convenience.

## OIDC and Google Cloud

Use Workload Identity Federation rather than long-lived service-account keys. Keep authentication in the smallest job scope possible and do not expose credentials to untrusted code.

## Untrusted input

Do not interpolate attacker-controlled GitHub context directly into shell scripts.

Avoid patterns such as embedding PR titles, branch names, issue bodies, comments, or commit messages directly inside `run:` commands. When such data is required, pass it through an environment variable and quote it appropriately for the shell.

## Action supply chain

- Avoid `@main`, `@master`, or other mutable branch references.
- Prefer full commit SHA pins for third-party actions and retain a version comment for maintainability.
- Treat first-party actions as lower risk, but pinning to immutable revisions is still preferred for hardened workflows.
- Configure Dependabot/Renovate for GitHub Actions updates when workflow dependencies become substantial.

## Checkout safety

Do not leave repository credentials available to untrusted steps unnecessarily. Set `persist-credentials: false` when subsequent code does not need Git credentials, especially when executing contributed code.

## Terraform-specific CI

Separate unprivileged validation from privileged deployment concerns.

PR validation should be able to run formatting, static validation, linting, native unit tests, and static security checks without cloud credentials whenever practical.

Credentialed `plan` or deployment workflows should use controlled triggers/environments, OIDC, least privilege, and explicit approval boundaries where appropriate.

## Review checklist

- Are triggers appropriate for the code being executed?
- Could untrusted input become shell or script code?
- Is `permissions:` explicit and minimal?
- Are cloud credentials keyless and scoped to the intended job?
- Are actions pinned immutably where practical?
- Are secrets withheld from untrusted code?
- Is deployment separated from ordinary PR validation?

## References

- https://github.com/github/awesome-copilot/tree/main/skills/github-actions-hardening
- https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions
- https://cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines
