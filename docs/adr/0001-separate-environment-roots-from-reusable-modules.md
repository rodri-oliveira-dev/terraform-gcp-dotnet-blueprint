# ADR 0001: Separate environment roots from reusable modules

- Status: Accepted
- Date: 2026-09-14

## Context

The repository must demonstrate reusable Terraform design without coupling infrastructure modules to a specific environment. At the same time, development and production require different sizing, policy, backend and operational configuration.

Keeping all resources in one Terraform root would make the reference implementation easier to start but would quickly mix reusable infrastructure behavior with environment-specific decisions.

## Decision

The repository will use two distinct layers:

- `modules/` for reusable child modules;
- `environments/<environment>/` for Terraform root modules that compose those child modules.

Infrastructure required before regular roots can operate, such as the remote-state bucket, will live under `bootstrap/` and have an independent lifecycle.

Reusable modules must not configure providers or backends internally. Provider and backend configuration belong to Terraform roots.

## Consequences

### Positive

- Modules remain portable across environments.
- Environment-specific decisions are explicit and reviewable.
- Provider and backend configuration are centralized in root modules.
- Development and production can evolve independently without duplicating module implementation.
- The repository communicates a clear separation between capability implementation and environment composition.

### Trade-offs

- The repository contains more directories and Terraform roots.
- Dependency and version management must be kept consistent across roots.
- CI must discover and validate multiple Terraform roots instead of assuming a single root directory.

## Alternatives considered

### Single root module with workspaces

Rejected as the primary structure because Terraform workspaces alone do not create sufficiently explicit configuration boundaries for a reference architecture intended to demonstrate environment-specific composition.

### Duplicate Terraform per environment

Rejected because it would encourage copy-and-paste infrastructure and increase configuration drift.
