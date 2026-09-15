---
name: terraform-style-guide
description: Aplicar convenções consistentes de estilo HCL, nomenclatura, tipagem, validação, dependências e versionamento ao escrever ou revisar Terraform neste repositório.
---

# Guia de estilo Terraform

Use esta skill para qualquer autoria ou revisão de HCL Terraform.

## Regras principais

- Execute `terraform fmt` em vez de formatar manualmente ao redor dele.
- Use lowercase snake_case para identificadores Terraform.
- Dê a toda variável `type` e `description` explícitos.
- Adicione validação quando input inválido puder ser rejeitado localmente e de forma clara.
- Dê a todo output uma `description`; marque outputs sensíveis com `sensitive = true`.
- Prefira referências a `depends_on` explícito quando dependência puder ser expressa pelo data flow.
- Prefira `for_each` para coleções com chaves semânticas estáveis; use `count` principalmente para criação condicional simples ou coleções realmente indexadas.
- Evite `any` salvo quando a interface genuinamente não puder ser representada com tipo útil.
- Evite maps excessivamente genéricos de configuração sem tipo.
- Mantenha locals com propósito; não esconda comportamento importante em cadeias de indireção.

## Organização dos arquivos

Use arquivos claros por responsabilidade quando útil:

- `versions.tf`: constraints Terraform e required providers.
- `providers.tf`: configuração de provider somente em root modules.
- `backend.tf`: configuração de backend somente em root modules.
- `variables.tf`: contrato público de inputs.
- `main.tf`: recursos/data sources/modules principais.
- `locals.tf`: valores locais derivados quando melhoram legibilidade.
- `outputs.tf`: contrato público de outputs.

Módulos pequenos não precisam de arquivos vazios somente para satisfazer template.

## Versões e dependências

- Respeite a versão Terraform CLI fixada no repositório.
- Declare requisitos de provider explicitamente.
- Módulos filhos reutilizáveis declaram `required_providers`, mas não configuram credenciais ou backends.
- Root modules devem commitar `.terraform.lock.hcl` após inicializações/upgrades intencionais de providers.
- Não afrouxe constraints de versão apenas para fazer initialization funcionar.

## Segredos e state

Nunca hard-code credenciais ou payloads de segredos da aplicação em `.tf`, `.tfvars`, exemplos, testes ou documentação. Trate state como sensível mesmo quando output estiver marcado sensitive.

## Checklist de revisão

Antes de concluir mudanças Terraform, verifique:

- `terraform fmt -check -recursive` passa;
- nomes são descritivos e estáveis;
- tipos e validações de variáveis correspondem aos requisitos reais;
- outputs expõem apenas contratos úteis de integração;
- nenhum valor específico de ambiente vazou para módulo reutilizável;
- nenhuma dependência explícita evitável foi introduzida;
- nenhuma credencial, state ou valor de segredo foi commitado.

## Referências

- https://developer.hashicorp.com/terraform/language/style
- https://github.com/hashicorp/agent-skills/tree/main/plugins/terraform/skills/terraform-style-guide
