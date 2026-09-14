# Agent Skills

The repository uses a deliberately small set of project-local skills under `.agents/skills/`. The goal is to improve Codex consistency without flooding every task with unrelated instructions.

## Selected skills

| Skill | Use when | Why it exists |
| --- | --- | --- |
| `terraform-style-guide` | Writing or reviewing Terraform HCL | Keeps formatting, naming, variables, outputs, dependency expression, and versioning consistent. |
| `terraform-module-engineering` | Designing reusable modules or root composition | Protects the repository boundary between reusable child modules, bootstrap code, and environment roots. |
| `terraform-testing` | Adding `.tftest.hcl` tests or deciding test strategy | Encourages plan-mode tests and mocks before expensive integration tests. |
| `gcp-terraform-security` | Working with GCP IAM, state, secrets, WIF, or public access | Encodes the security decisions that are especially important for this blueprint. |
| `github-actions-hardening` | Creating or reviewing GitHub Actions | Applies least-privilege permissions, OIDC, immutable action references, and untrusted-input protections. |

## Why these skills

HashiCorp maintains an official Terraform Agent Skills collection with active skills for Terraform style, native testing, and module refactoring. Its Terraform bundle is explicitly exposed for Codex as well as other agent runtimes. Those skills were used as reference material for the Terraform-specific project skills here.

GitHub supports project-level Agent Skills in `.agents/skills/`, and its `awesome-copilot` collection includes a dedicated GitHub Actions hardening skill. That material informed the CI security skill.

Google Cloud publishes Terraform-specific guidance covering remote state, reusable modules, IAM resource semantics, automated pipelines, and Workload Identity Federation. Those recommendations are represented in the GCP security skill rather than relying on generic Terraform guidance alone.

## Source references

- HashiCorp Agent Skills: https://github.com/hashicorp/agent-skills
- HashiCorp Terraform skill catalog: https://github.com/hashicorp/agent-skills/blob/main/SKILLS.md
- GitHub Agent Skills documentation: https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills
- GitHub Actions hardening skill: https://github.com/github/awesome-copilot/tree/main/skills/github-actions-hardening
- OpenAI Codex `AGENTS.md` behavior: https://openai.com/index/introducing-codex/
- Google Cloud Terraform security practices: https://cloud.google.com/docs/terraform/best-practices/security
- Google Cloud reusable-module practices: https://cloud.google.com/docs/terraform/best-practices/reusable-modules
- Google Cloud resource/IAM practices: https://cloud.google.com/docs/terraform/best-practices/working-with-resources
- Google Cloud Terraform operations practices: https://cloud.google.com/docs/terraform/best-practices/operations
- Google Cloud Workload Identity Federation practices: https://cloud.google.com/iam/docs/best-practices-for-using-workload-identity-federation

## Skills intentionally not installed

- Terraform provider-development skills: this repository consumes providers; it does not implement one.
- Terraform import/search skills: importing an existing estate is outside the current reference-architecture roadmap.
- Terraform Stacks: the current ADR intentionally uses explicit environment root modules rather than HCP Terraform Stacks.
- Terraform Policy: policy-as-code may be introduced later, but it is not required by the current eight-issue roadmap.
- Azure-specific skills: the target cloud is Google Cloud.

## Maintenance rule

Skills are repository guidance, not immutable law. When Terraform, the Google provider, GitHub Actions, or the architecture changes materially, update the relevant skill in the same PR that changes the underlying convention.
