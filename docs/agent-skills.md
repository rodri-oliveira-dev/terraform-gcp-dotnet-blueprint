# Skills dos agentes

O repositório usa deliberadamente um conjunto pequeno de skills locais em `.agents/skills/`. O objetivo é melhorar a consistência do Codex sem inundar cada tarefa com instruções não relacionadas.

## Skills selecionadas

| Skill | Use quando | Por que existe |
| --- | --- | --- |
| `terraform-style-guide` | Escrever ou revisar HCL Terraform | Mantém consistentes formatação, nomenclatura, variáveis, outputs, expressão de dependências e versionamento. |
| `terraform-module-engineering` | Projetar módulos reutilizáveis ou composição de roots | Protege o limite do repositório entre módulos filhos, bootstrap e roots de ambiente. |
| `terraform-testing` | Adicionar testes `.tftest.hcl` ou decidir estratégia de testes | Incentiva testes em modo plan e mocks antes de integration tests caros. |
| `gcp-terraform-security` | Trabalhar com GCP IAM, state, segredos, WIF ou acesso público | Codifica decisões de segurança especialmente importantes para este blueprint. |
| `github-actions-hardening` | Criar ou revisar GitHub Actions | Aplica least privilege, OIDC, referências imutáveis de actions e proteção contra inputs não confiáveis. |

## Por que estas skills

A HashiCorp mantém coleção oficial de Terraform Agent Skills com skills ativas para estilo Terraform, testes nativos e refatoração de módulos. O bundle Terraform é exposto explicitamente para Codex e outros runtimes de agentes. Essas skills foram usadas como referência para as skills Terraform específicas deste projeto.

O GitHub suporta Agent Skills no nível do projeto em `.agents/skills/`, e sua coleção `awesome-copilot` inclui skill dedicada de hardening do GitHub Actions. Esse material orientou a skill de segurança de CI.

O Google Cloud publica orientação específica de Terraform cobrindo remote state, módulos reutilizáveis, semântica IAM, pipelines automatizados e Workload Identity Federation. Essas recomendações estão representadas na skill de segurança GCP, em vez de depender somente de orientação Terraform genérica.

## Referências

- HashiCorp Agent Skills: https://github.com/hashicorp/agent-skills
- Catálogo de skills Terraform da HashiCorp: https://github.com/hashicorp/agent-skills/blob/main/SKILLS.md
- Documentação GitHub Agent Skills: https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills
- Skill de hardening do GitHub Actions: https://github.com/github/awesome-copilot/tree/main/skills/github-actions-hardening
- Comportamento de `AGENTS.md` no OpenAI Codex: https://openai.com/index/introducing-codex/
- Práticas de segurança Terraform no Google Cloud: https://cloud.google.com/docs/terraform/best-practices/security
- Práticas de módulos reutilizáveis no Google Cloud: https://cloud.google.com/docs/terraform/best-practices/reusable-modules
- Práticas de recursos/IAM no Google Cloud: https://cloud.google.com/docs/terraform/best-practices/working-with-resources
- Práticas operacionais Terraform no Google Cloud: https://cloud.google.com/docs/terraform/best-practices/operations
- Práticas de Workload Identity Federation no Google Cloud: https://cloud.google.com/iam/docs/best-practices-for-using-workload-identity-federation

## Skills intencionalmente não instaladas

- Skills de desenvolvimento de Terraform provider: este repositório consome providers; não implementa um.
- Skills de import/search Terraform: importar estate existente está fora do escopo da arquitetura de referência v1.0.
- Terraform Stacks: a arquitetura usa intencionalmente root modules de ambiente explícitos em vez de HCP Terraform Stacks.
- Terraform Policy: policy-as-code é extensão organizacional opcional, não requisito do baseline v1.0.
- Skills específicas de Azure: a cloud alvo é Google Cloud.

## Regra de manutenção

Skills são orientação do repositório, não lei imutável. Quando Terraform, provider Google, GitHub Actions ou arquitetura mudarem materialmente, atualize a skill relevante no mesmo PR que alterar a convenção subjacente.
