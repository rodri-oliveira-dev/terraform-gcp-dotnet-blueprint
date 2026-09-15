---
name: terraform-style-guide
description: Apply consistent Terraform HCL style, naming, typing, validation, dependency, and versioning conventions when writing or reviewing Terraform in this repository.
---

# Terraform Style Guide

Use this skill for any Terraform HCL authoring or review.

## Core rules

- Run `terraform fmt` rather than hand-formatting around it.
- Use lowercase snake_case for Terraform identifiers.
- Give every variable an explicit `type` and `description`.
- Add variable validation when invalid input can be rejected locally and clearly.
- Give every output a `description`; mark sensitive outputs with `sensitive = true`.
- Prefer references over explicit `depends_on` when the dependency can be expressed through data flow.
- Prefer `for_each` for collections with stable semantic keys; use `count` mainly for simple conditional creation or truly index-based collections.
- Avoid `any` unless the interface genuinely cannot be represented with a useful type.
- Avoid overly generic maps of untyped configuration.
- Keep locals purposeful; do not hide important behavior behind chains of indirection.

## File organization

Use clear responsibility-based files where useful:

- `versions.tf`: Terraform and required-provider constraints.
- `providers.tf`: provider configuration in root modules only.
- `backend.tf`: backend configuration in root modules only.
- `variables.tf`: public input contract.
- `main.tf`: primary resources/data sources/modules.
- `locals.tf`: derived local values when they improve readability.
- `outputs.tf`: public output contract.

Small modules do not need empty files solely to satisfy a template.

## Versions and dependencies

- Respect the repository-pinned Terraform CLI version.
- Declare provider requirements explicitly.
- Reusable child modules declare `required_providers` but do not configure provider credentials or backends.
- Root modules should commit `.terraform.lock.hcl` after intentional provider initialization/upgrades.
- Do not loosen version constraints merely to make initialization succeed.

## Secrets and state

Never hard-code credentials or application secret payloads in `.tf`, `.tfvars`, examples, tests, or documentation. Treat state as sensitive even when an output is marked sensitive.

## Review checklist

Before completing Terraform changes, verify:

- `terraform fmt -check -recursive` passes;
- names are descriptive and stable;
- variable types and validations match actual requirements;
- outputs expose only useful integration contracts;
- no environment-specific value leaked into a reusable module;
- no avoidable explicit dependency was introduced;
- no credential, state, or secret value is committed.

## References

- https://developer.hashicorp.com/terraform/language/style
- https://github.com/hashicorp/agent-skills/tree/main/plugins/terraform/skills/terraform-style-guide
