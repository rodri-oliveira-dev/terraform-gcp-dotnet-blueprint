---
name: terraform-testing
description: Projetar e implementar testes nativos Terraform usando assertions em modo plan, testes de validação, mocks e integration tests cuidadosamente restritos para módulos deste repositório.
---

# Testes Terraform

Use esta skill ao adicionar ou revisar arquivos `.tftest.hcl` ou decidir como o comportamento Terraform deve ser verificado.

## Hierarquia de testes

Prefira o teste de menor custo que comprove o comportamento:

1. validação de variável;
2. `terraform validate`;
3. teste nativo Terraform em modo plan;
4. teste Terraform com mock provider;
5. integration test com provider real somente quando necessário.

Não crie infraestrutura live e com custo quando plan ou mock puder comprovar o requisito.

## Organização dos testes

Coloque testes do módulo no diretório `tests/` correspondente.

Use nomes descritivos, como:

- `defaults_unit_test.tftest.hcl`;
- `validation_unit_test.tftest.hcl`;
- `security_unit_test.tftest.hcl`;
- `integration_test.tftest.hcl`.

Use `command = plan` como padrão para unit tests.

## O que testar

Priorize contratos observáveis do módulo:

- defaults produzem configuração esperada;
- inputs inválidos são rejeitados;
- recursos opcionais aparecem/desaparecem corretamente;
- scaling, retry, timeout, IAM e flags de segurança são mapeados corretamente;
- outputs expõem valores esperados;
- outputs sensíveis não são expostos sem necessidade;
- composição de módulos preserva dependências necessárias.

Evite assertions que apenas repitam detalhes de implementação sem proteger comportamento.

## Mocks

Use mock providers/data/resources quando chamadas ao provider não fizerem parte do comportamento testado. Mantenha valores mock realistas o suficiente para exercitar expressions e contratos de output.

Se teste depender de comportamento real do Google Cloud que Terraform não consiga modelar com plan ou mock, classifique explicitamente como integration testing e documente credenciais, APIs, implicações de custo e cleanup necessários.

## Testes negativos

Use expected failures para provar que validações rejeitam valores inválidos. Mensagens de erro devem tornar a falha compreensível sem inspecionar internals do provider.

## Expectativas de CI

Unit tests devem ser seguros para executar em pull requests sem credenciais cloud quando prático. Integration tests autenticados pertencem a workflow ou stage separado e controlado.

## Checklist de conclusão

- Testes focam comportamento, não formatação.
- Unit tests não alteram infraestrutura live.
- Integration tests são claramente identificáveis.
- Mensagens de falha são diagnósticas.
- Testes são determinísticos e não dependem de recursos pessoais cloud preexistentes.
- `terraform test` passa no módulo alterado quando tooling necessário estiver disponível.

## Referências

- https://developer.hashicorp.com/terraform/language/tests
- https://github.com/hashicorp/agent-skills/tree/main/plugins/terraform/skills/terraform-test
