# ADR 0001: Separar roots de ambiente de módulos reutilizáveis

- Status: Aceita
- Data: 2026-09-14

## Contexto

O repositório precisa demonstrar design Terraform reutilizável sem acoplar módulos de infraestrutura a um ambiente específico. Ao mesmo tempo, desenvolvimento e produção exigem sizing, políticas, backend e configuração operacional diferentes.

Manter todos os recursos em um único Terraform root facilitaria o início da implementação de referência, mas rapidamente misturaria comportamento reutilizável da infraestrutura com decisões específicas de ambiente.

## Decisão

O repositório usará duas camadas distintas:

- `modules/` para módulos filhos reutilizáveis;
- `environments/<environment>/` para root modules Terraform que compõem esses módulos filhos.

Infraestrutura necessária antes dos roots normais, como bucket de state remoto, ficará em `bootstrap/` com ciclo de vida independente.

Módulos reutilizáveis não devem configurar providers ou backends internamente. Configuração de provider e backend pertence aos roots Terraform.

## Consequências

### Positivas

- Módulos permanecem portáveis entre ambientes.
- Decisões específicas de ambiente ficam explícitas e revisáveis.
- Configuração de provider/backend fica centralizada nos root modules.
- Desenvolvimento e produção podem evoluir independentemente sem duplicar implementação de módulos.
- O repositório comunica separação clara entre implementação de capacidade e composição de ambiente.

### Trade-offs

- O repositório contém mais diretórios e Terraform roots.
- Gerenciamento de dependências e versões precisa permanecer consistente entre roots.
- CI deve descobrir e validar múltiplos Terraform roots em vez de presumir um único diretório root.

## Alternativas consideradas

### Root module único com workspaces

Rejeitado como estrutura principal porque Terraform workspaces sozinhos não criam limites de configuração suficientemente explícitos para arquitetura de referência destinada a demonstrar composição específica por ambiente.

### Terraform duplicado por ambiente

Rejeitado porque incentivaria infraestrutura copy-and-paste e aumentaria configuration drift.
