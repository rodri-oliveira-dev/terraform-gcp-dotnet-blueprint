# Fluxo de implementação para agentes

Este documento define como agentes de código devem executar trabalho no repositório. `AGENTS.md` permanece como índice conciso; este arquivo contém o detalhe operacional.

## 1. Estabelecer o contexto da tarefa

Antes de editar:

1. Leia a issue alvo por completo.
2. Identifique pré-requisitos explícitos e implícitos.
3. Leia a documentação de arquitetura e ADRs afetadas pela mudança.
4. Inspecione o código existente em vez de depender apenas do texto da issue.
5. Carregue somente as skills do projeto relevantes para a tarefa.

Se a issue tiver Definition of Ready, trate-a como gate. Se uma issue pré-requisito tiver Definition of Done, verifique os artifacts relevantes no repositório em vez de presumir conclusão apenas pelo estado da issue.

## 2. Planejar respeitando limites arquiteturais

Classifique cada mudança antes de escrever código:

- **Infraestrutura de bootstrap**: pré-requisitos com ciclo de vida separado, como state remoto.
- **Módulo reutilizável**: capacidade de infraestrutura focada com interface tipada.
- **Root de ambiente**: configuração de provider/backend e composição de módulos reutilizáveis.
- **Automação de entrega**: GitHub Actions, autenticação, planning, validação e controles de deployment.
- **Documentação/decisão**: orientação para operadores ou decisão arquitetural com trade-offs.

Se uma implementação solicitada cruzar várias categorias, mantenha cada responsabilidade em seu diretório adequado, em vez de colapsá-las em um módulo de conveniência.

## 3. Implementar incrementalmente

Prefira uma sequência que mantenha a branch revisável:

1. constraints de versão/provider e interfaces;
2. implementação de recursos;
3. outputs e contratos de dependência;
4. testes;
5. documentação;
6. integração com CI/segurança quando fizer parte do escopo.

Não adicione abstrações especulativas para requisitos futuros hipotéticos. O repositório é arquitetura de referência; clareza e trade-offs explícitos valem mais que frameworks genéricos.

## 4. Estratégia de validação Terraform

Use primeiro os checks significativos de menor custo.

### Formatação

```bash
terraform fmt -check -recursive
```

### Inicialização e validação estática

Para root ou exemplo independente quando backend real não for necessário:

```bash
terraform init -backend=false
terraform validate
```

Para módulos reutilizáveis, inicialize a partir do diretório do módulo quando schemas do provider forem necessários para validação.

### Testes

Prefira testes nativos Terraform em modo plan e mock providers para comportamento unitário. Use integration tests em modo apply somente quando comportamento do provider não puder ser validado estaticamente ou com mocks.

```bash
terraform test
```

Nunca crie recursos cloud com custo apenas para satisfazer um unit test rotineiro.

### Lint e segurança

Execute tooling de lint/segurança configurado no repositório quando disponível. Achados devem ser corrigidos ou explicitamente justificados. Não suprima regra apenas para deixar CI verde.

## 5. Segurança de plan e apply

Um plan gerado é material para revisão, não autorização para deployment.

Agentes podem executar `terraform plan` quando credenciais e ambiente seguro estiverem disponíveis e a tarefa exigir. Agentes não devem executar `terraform apply`, `terraform destroy`, comandos destrutivos de state ou mutações IAM reais a menos que o usuário tenha solicitado explicitamente a operação live.

Nunca cole conteúdo de state, credenciais, access tokens ou payloads de segredos em chat, logs, fixtures de teste ou arquivos commitados.

## 6. Regras de documentação e ADR

Atualize documentação quando uma mudança alterar:

- interfaces de módulos ou uso suportado;
- passos de deployment/operação;
- premissas de autenticação ou segurança;
- ownership do state;
- interação em runtime entre serviços;
- responsabilidades dos ambientes.

Crie ou atualize ADR quando a mudança representar decisão arquitetural durável com alternativas ou consequências relevantes. Detalhes rotineiros de implementação não exigem ADR.

## 7. Conclusão do pull request

Antes de abrir ou atualizar PR:

1. Revise o diff em busca de mudanças não relacionadas.
2. Reexecute checks práticos de validação após a última edição.
3. Mapeie explicitamente o resultado para o DoD da issue.
4. Mencione qualquer validação que não pôde ser executada e o motivo.
5. Descreva comportamento sensível à segurança quando relevante.
6. Solicite review somente quando a branch estiver internamente consistente.

Um prompt posterior trabalhando na mesma issue deve reverificar o trabalho do prompt anterior antes de estendê-lo. Sessões de chat separadas não são evidência de que a implementação anterior está correta.
