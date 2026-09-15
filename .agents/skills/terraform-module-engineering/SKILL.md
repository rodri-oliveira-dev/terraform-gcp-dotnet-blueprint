---
name: terraform-module-engineering
description: Design and review reusable Terraform child modules and environment root modules with explicit interfaces, cohesive responsibilities, safe composition, and GCP-oriented module boundaries.
---

# Terraform Module Engineering

Use this skill when creating, extending, or refactoring Terraform modules or environment composition.

## Classify the module first

Determine whether the target is:

- a reusable child module under `modules/`;
- a root module under `environments/`;
- bootstrap infrastructure under `bootstrap/`;
- an isolated usage example under `examples/`.

Do not blur these responsibilities for convenience.

## Reusable child modules

A reusable module should:

- own one cohesive capability or a tightly coupled resource set;
- expose explicit, typed inputs with sensible defaults only when a safe default exists;
- expose useful outputs that let roots compose dependencies naturally;
- avoid environment names, project IDs, regions, repository names, or organization-specific values unless provided as inputs;
- avoid configuring backends or provider credentials;
- avoid reaching into sibling modules directly;
- expose labels where supported;
- document security-sensitive behavior and assumptions.

If a module enables Google APIs itself, make that behavior explicit and safe to disable. Avoid disabling shared APIs on module destruction.

## Root modules

Root modules own:

- backend configuration;
- provider configuration;
- environment-specific values and sizing;
- module composition;
- environment-level labels and policy choices.

Keep root modules small enough that state ownership remains understandable. Do not move environment policy into a generic module merely to reduce line count.

## Interface design

Prefer specific objects and collections over `map(any)`. Validate enum-like values, numeric ranges, identifiers, and mutually dependent settings where Terraform can produce a useful early error.

Outputs are contracts, not dumps of entire resources. Expose identifiers, URIs, names, or structured data consumers actually require.

## Refactoring existing state

When moving existing resources into modules, preserve resource identity with `moved` blocks where possible. Do not assume a structural refactor is deployment-neutral without checking the plan.

Never run destructive `terraform state` commands unless explicitly requested and backed by a reviewed migration procedure.

## Testing and documentation

For reusable modules:

- add native Terraform tests for validation/default/interface behavior when meaningful;
- provide a focused usage example when it improves discoverability;
- document inputs, outputs, assumptions, and security-relevant defaults.

## Review checklist

- Is the module responsibility cohesive?
- Are root-only concerns kept out of child modules?
- Are inputs typed, minimal, and meaningful?
- Are outputs sufficient for composition without exposing unnecessary implementation detail?
- Are project/environment constants injected rather than hard-coded?
- Would a refactor recreate resources unexpectedly?
- Does documentation describe operator-visible behavior?

## References

- https://github.com/hashicorp/agent-skills/tree/main/plugins/terraform/skills/refactor-module
- https://cloud.google.com/docs/terraform/best-practices/reusable-modules
- https://cloud.google.com/docs/terraform/best-practices/root-modules
