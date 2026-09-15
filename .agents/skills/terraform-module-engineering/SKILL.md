---
name: terraform-module-engineering
description: Projetar e revisar módulos filhos Terraform reutilizáveis e root modules de ambiente com interfaces explícitas, responsabilidades coesas, composição segura e limites orientados ao GCP.
---

# Engenharia de módulos Terraform

Use esta skill ao criar, estender ou refatorar módulos Terraform ou composição de ambientes.

## Classifique primeiro o módulo

Determine se o alvo é:

- módulo filho reutilizável em `modules/`;
- root module em `environments/`;
- infraestrutura de bootstrap em `bootstrap/`;
- exemplo isolado em `examples/`.

Não misture essas responsabilidades por conveniência.

## Módulos filhos reutilizáveis

Um módulo reutilizável deve:

- possuir uma capacidade coesa ou conjunto de recursos fortemente relacionados;
- expor inputs tipados explícitos com defaults somente quando existir padrão seguro;
- expor outputs úteis que permitam composição natural de dependências pelos roots;
- evitar nomes de ambiente, project IDs, regiões, nomes de repositório ou valores organizacionais, salvo quando recebidos por inputs;
- evitar configurar backends ou credenciais de provider;
- evitar acessar módulos irmãos diretamente;
- expor labels onde suportado;
- documentar comportamento e premissas sensíveis à segurança.

Se um módulo habilitar APIs Google por conta própria, torne isso explícito e seguro para desabilitar. Evite desabilitar APIs compartilhadas ao destruir o módulo.

## Root modules

Root modules são responsáveis por:

- configuração de backend;
- configuração de provider;
- valores e sizing específicos do ambiente;
- composição de módulos;
- labels e escolhas de política no nível do ambiente.

Mantenha roots pequenos o suficiente para que ownership do state permaneça compreensível. Não mova política de ambiente para módulo genérico apenas para reduzir linhas.

## Design de interface

Prefira objetos e coleções específicos a `map(any)`. Valide enums, ranges numéricos, identificadores e configurações interdependentes quando Terraform puder produzir erro antecipado útil.

Outputs são contratos, não dumps de recursos inteiros. Exponha identificadores, URIs, nomes ou dados estruturados realmente necessários aos consumidores.

## Refatoração de state existente

Ao mover recursos existentes para módulos, preserve identidade com blocos `moved` quando possível. Não presuma que refatoração estrutural é neutra para deployment sem verificar o plan.

Nunca execute comandos destrutivos de `terraform state` sem solicitação explícita e procedimento de migração revisado.

## Testes e documentação

Para módulos reutilizáveis:

- adicione testes nativos Terraform para comportamento de validação/default/interface quando significativo;
- forneça exemplo focado quando melhorar descoberta;
- documente inputs, outputs, premissas e defaults relevantes à segurança.

## Checklist de revisão

- A responsabilidade do módulo é coesa?
- Preocupações exclusivas de root ficaram fora dos módulos filhos?
- Inputs são tipados, mínimos e significativos?
- Outputs permitem composição sem expor detalhes desnecessários?
- Constantes de projeto/ambiente são injetadas, não hard-coded?
- Uma refatoração recriaria recursos inesperadamente?
- A documentação descreve comportamento visível ao operador?

## Referências

- https://github.com/hashicorp/agent-skills/tree/main/plugins/terraform/skills/refactor-module
- https://cloud.google.com/docs/terraform/best-practices/reusable-modules
- https://cloud.google.com/docs/terraform/best-practices/root-modules
