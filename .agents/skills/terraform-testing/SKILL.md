---
name: terraform-testing
description: Design and implement Terraform native tests using plan-mode assertions, validation tests, mocks, and carefully scoped integration tests for modules in this repository.
---

# Terraform Testing

Use this skill when adding or reviewing `.tftest.hcl` files or deciding how Terraform behavior should be verified.

## Testing hierarchy

Prefer the cheapest test that proves the behavior:

1. variable validation;
2. `terraform validate`;
3. plan-mode native Terraform test;
4. mock-provider Terraform test;
5. real-provider integration test only when necessary.

Do not create live, billable infrastructure when a plan or mock test can prove the requirement.

## Test organization

Place module tests under the module's `tests/` directory.

Use descriptive names such as:

- `defaults_unit_test.tftest.hcl`;
- `validation_unit_test.tftest.hcl`;
- `security_unit_test.tftest.hcl`;
- `integration_test.tftest.hcl`.

Default unit tests to `command = plan`.

## What to test

Prioritize observable module contracts:

- defaults produce expected resource configuration;
- invalid inputs are rejected;
- optional resources are present/absent correctly;
- scaling, retry, timeout, IAM, and security flags map correctly;
- outputs expose the expected values;
- sensitive outputs are not unnecessarily exposed;
- module composition preserves required dependencies.

Avoid assertions that merely restate implementation details without protecting behavior.

## Mocks

Use mock providers/data/resources when provider calls are not part of the behavior under test. Keep mock values realistic enough to exercise expressions and output contracts.

If a test depends on actual Google Cloud behavior that Terraform cannot model with a plan or mock, classify it explicitly as integration testing and document required credentials, APIs, cost implications, and cleanup behavior.

## Negative tests

Use expected failures to prove variable validations reject invalid values. Error messages should make the failure understandable without inspecting provider internals.

## CI expectations

Unit tests should be safe to run on pull requests without cloud credentials when practical. Credentialed integration tests belong in a separately controlled workflow or stage.

## Completion checklist

- Tests target behavior, not formatting.
- Unit tests do not mutate live infrastructure.
- Integration tests are clearly identifiable.
- Failure messages are diagnostic.
- Tests are deterministic and do not depend on pre-existing personal cloud resources.
- `terraform test` passes for the changed module when the required tooling is available.

## References

- https://developer.hashicorp.com/terraform/language/tests
- https://github.com/hashicorp/agent-skills/tree/main/plugins/terraform/skills/terraform-test
