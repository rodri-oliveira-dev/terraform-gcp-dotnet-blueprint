---
name: gcp-terraform-security
description: Aplicar práticas de segurança do Google Cloud a state Terraform, IAM, Secret Manager, Workload Identity Federation, acesso público e autenticação de CI/CD neste repositório.
---

# Segurança GCP com Terraform

Use esta skill sempre que mudanças Terraform envolverem identidade, autenticação, state, segredos, exposição de rede ou configuração sensível à segurança no Google Cloud.

## State Terraform

- Use backend remoto Cloud Storage para ambientes compartilhados.
- Trate state como sensível porque providers podem persistir atributos sensíveis mesmo quando outputs são marcados como sensitive.
- Habilite proteções apropriadas no bucket, como prevenção de acesso público, uniform bucket-level access e versionamento.
- Restrinja acesso ao state à identidade de deployment e administradores necessários.
- Nunca faça commit de state local ou backups de state.

Faça bootstrap do bucket separadamente para que o backend não dependa de si mesmo.

## Autenticação de CI

Para GitHub Actions, prefira Workload Identity Federation a chaves JSON de service account.

- Solicite `id-token: write` somente em jobs que autenticam por OIDC.
- Mantenha `contents: read` a menos que um job comprovadamente precise de permissões mais amplas.
- Restrinja federação com condições de atributos à organização/repositório GitHub confiáveis e, quando apropriado, branch ou environment.
- Prefira claims de identidade estáveis e autoritativos.
- Conceda ao principal federado ou service account impersonada somente as roles necessárias ao workflow.

Este repositório foi criado após o rollout de 15 de julho de 2026 dos subjects OIDC imutáveis padrão do GitHub para novos repositórios. Quando a configuração de confiança Google Cloud for alterada, inspecione o formato real do OIDC subject e prefira condições que preservem identificadores imutáveis de owner/repositório, em vez de enfraquecer a confiança para nomes reutilizáveis. Não copie exemplos legados `repo:owner/name:*` sem validar os claims emitidos para este repositório.

Não crie chaves de service account de longa duração como atalho de conveniência.

## Semântica IAM

Compreenda a diferença entre recursos IAM autoritativos e aditivos antes de escolher.

- Prefira `google_*_iam_member` quando Terraform deve adicionar uma relação principal/role sem possuir toda a policy/binding.
- Use `google_*_iam_binding` ou `google_*_iam_policy` autoritativos somente quando a configuração intencionalmente possuir todo o escopo e o impacto estiver documentado.
- Evite roles amplas no projeto quando houver role mais restrita no nível do recurso.
- Mantenha identidades de runtime específicas por workload quando prático.

## Secret Manager

Terraform pode criar containers de segredos, IAM bindings e referências. Payloads de segredos da aplicação não devem ser hard-coded em Terraform versionado.

Conceda acesso somente aos workloads que necessitam. Não exponha valores de segredos em outputs comuns.

## Exposição pública

Use privado/sem acesso público por padrão. Se Cloud Run Service ou outro recurso precisar ser público no cenário de referência, torne a exposição explícita, documentada e de escopo restrito.

## Plans e mutação real

Revise plans Terraform antes do apply, especialmente para IAM, políticas de bucket, service accounts e recursos cuja substituição pode causar indisponibilidade ou perda de dados.

Nunca execute `terraform apply`, `destroy`, force-unlock, remoção de state ou mudanças IAM destrutivas sem autorização explícita do usuário.

## Checklist de revisão

- O state remoto está protegido e isolado adequadamente?
- Existem credential files ou caminhos de autenticação de CI baseados em chaves?
- A federação está restrita a identidades GitHub confiáveis usando claims OIDC imutáveis reais quando disponíveis?
- Mudanças IAM são aditivas, salvo quando ownership autoritativo é intencional?
- Payloads de segredos estão ausentes do source Terraform e outputs?
- Acesso público está desabilitado salvo quando explicitamente necessário?
- A mudança pode substituir ou revogar infraestrutura/permissões compartilhadas sem intenção?

## Referências

- https://cloud.google.com/docs/terraform/best-practices/security
- https://cloud.google.com/docs/terraform/best-practices/operations
- https://cloud.google.com/docs/terraform/best-practices/working-with-resources
- https://cloud.google.com/iam/docs/best-practices-for-using-workload-identity-federation
- https://cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines
- https://docs.github.com/en/actions/reference/security/oidc
