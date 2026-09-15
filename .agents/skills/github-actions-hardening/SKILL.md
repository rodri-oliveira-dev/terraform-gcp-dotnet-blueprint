---
name: github-actions-hardening
description: Criar e revisar workflows GitHub Actions com least privilege, autenticação cloud baseada em OIDC, referências imutáveis de actions, triggers seguros e proteção contra injeção por inputs não confiáveis.
---

# Hardening de GitHub Actions

Use esta skill ao criar ou modificar `.github/workflows/*.yml` ou `.yaml`.

## Limites de confiança dos triggers

Entenda quem pode causar a execução do workflow e quais privilégios ele recebe.

- Trate `pull_request_target`, `workflow_run`, `issue_comment` e triggers semelhantes de contexto privilegiado/base com escrutínio extra.
- Nunca combine trigger privilegiado com checkout/execução de código não confiável de fork.
- Prefira `pull_request` comum para validar código contribuído.

## Permissões do workflow

Defina `permissions:` explícitas no nível do workflow ou job. Comece pelo mínimo e adicione somente o necessário.

Jobs típicos de validação Terraform precisam apenas de:

```yaml
permissions:
  contents: read
```

Um job que autentica no Google Cloud com GitHub OIDC também exige:

```yaml
permissions:
  contents: read
  id-token: write
```

Não conceda `write-all` ou escopos amplos de escrita por conveniência.

## OIDC e Google Cloud

Use Workload Identity Federation em vez de chaves de service account de longa duração. Mantenha autenticação no menor escopo de job possível e não exponha credenciais a código não confiável.

## Input não confiável

Não interpole contexto GitHub controlado por atacante diretamente em scripts shell.

Evite incorporar títulos de PR, nomes de branch, bodies de issue, comentários ou mensagens de commit diretamente em comandos `run:`. Quando esses dados forem necessários, passe-os por environment variable e faça quoting apropriado ao shell.

## Supply chain das actions

- Evite `@main`, `@master` ou outras referências mutáveis de branch.
- Prefira pins por SHA completo de commit para actions de terceiros e mantenha comentário de versão para manutenção.
- Trate actions first-party como risco menor, mas pins imutáveis continuam preferíveis em workflows hardened.
- Configure Dependabot/Renovate para atualizações de GitHub Actions quando dependências do workflow forem relevantes.

## Segurança do checkout

Não deixe credenciais do repositório disponíveis a etapas não confiáveis sem necessidade. Use `persist-credentials: false` quando o código posterior não precisar de Git credentials, especialmente ao executar código contribuído.

## CI específico de Terraform

Separe validação sem privilégios de responsabilidades privilegiadas de deployment.

Validação de PR deve executar formatting, static validation, linting, unit tests nativos e verificações estáticas de segurança sem credenciais cloud quando prático.

Workflows autenticados de `plan` ou deployment devem usar triggers/environments controlados, OIDC, least privilege e limites explícitos de aprovação quando apropriado.

## Checklist de revisão

- Triggers são adequados ao código executado?
- Input não confiável pode virar código shell/script?
- `permissions:` é explícito e mínimo?
- Credenciais cloud são keyless e restritas ao job pretendido?
- Actions estão fixadas de forma imutável quando prático?
- Segredos ficam fora de código não confiável?
- Deployment está separado da validação normal de PR?

## Referências

- https://github.com/github/awesome-copilot/tree/main/skills/github-actions-hardening
- https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions
- https://cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines
