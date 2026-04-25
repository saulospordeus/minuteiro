# Roadmap - Minuteiro

## Objetivo do produto

Construir uma aplicacao web MPA para criacao, edicao, preenchimento e compilacao de modelos de documentos legais com persistencia de dados e suporte opcional a geracao assistida por IA.

## Status atual

- Ambiente local validado com Elixir 1.15.8, Erlang/OTP 25 e PostgreSQL ativo
- Aplicacao Phoenix 1.8 base ja foi gerada neste repositorio
- Ecto, LiveView, TailwindCSS, DaisyUI e Req estao configurados
- `mix setup`, `mix precommit` e `mix phx.server` passaram localmente
- `Minuteiro.Documents` e `Minuteiro.Documents.Template` ja existem com migration e CRUD basico testado
- `Minuteiro.Parser` e `Minuteiro.Compiler` ja foram implementados com testes unitarios fortes
- `Minuteiro.Documents` ja expoe parse, compile e analise de templates para a camada web
- Autenticacao com `phx.gen.auth` foi instalada e o dashboard em `/` agora exige login
- O editor em `/templates/:id/edit` tambem exige autenticacao e opera apenas sobre templates do usuario logado
- `templates` agora pertencem a um usuario via `user_id`, com queries e testes de ownership
- Em desenvolvimento, abrir `/` enquanto autenticado garante um `Modelo teste` persistido na conta atual para validacao manual da linguagem, cobrindo os tipos estaveis da V1 e um bloco `SE` simples
- O editor ja mostra estados de salvamento e erros de parsing de forma explicita
- O editor ja oferece manual de sintaxe para ajudar o usuario final a escrever templates
- O editor ja oferece botoes para inserir rapidamente variaveis e blocos condicionais genericos no template
- O editor agora usa CodeMirror com autocomplete de variaveis e highlights estaveis para declaracoes e referencias
- A sintaxe do template agora aceita texto implicito com `!@campo`, booleano curto com `!@campo?`, alias `booleana` e listas separadas por `;`

## Proximo passo imediato

O proximo passo real agora e transformar o editor de templates em fluxo persistente de trabalho para o usuario autenticado:

1. Criar `generated_documents` para salvar respostas, contexto de IA e estado do preenchimento
2. Permitir criar um documento a partir de um template e reabrir o rascunho depois
3. Manter `Documents` como fronteira de dominio para templates e documentos gerados
4. Depois disso avaliar refinamentos do editor e versionamento inicial dos templates

## Principios de arquitetura

1. O nucleo do sistema e o parser + compiler.
   A regra de negocio principal nao deve morar no LiveView. O LiveView apenas orquestra estado de tela, eventos do usuario e persistencia.

2. A linguagem de templates da V1 tera escopo controlado.
   Vamos implementar apenas o necessario para entregar valor com previsibilidade e testes confiaveis.

3. O projeto deve nascer preparado para auditoria e versionamento.
   Mesmo que a V1 nao entregue historico completo, a modelagem e a organizacao do codigo nao devem bloquear essa evolucao.

## Arquitetura adaptada

### 1. Stack base

- Backend: Elixir + Phoenix 1.8 + Ecto + PostgreSQL
- Frontend: Phoenix HTML + Phoenix LiveView
- Estilos: TailwindCSS + DaisyUI
- Cliente HTTP: Req

### 2. Responsabilidades por camada

#### Web

- Dashboard em `/` para listar templates e criar novos modelos
- LiveView dedicado em `/templates/:id/edit`
- O LiveView mantem apenas:
  - `template`
  - `variables`
  - `answers`
  - `final_document`
  - estado auxiliar minimo para chamadas assincronas de IA

#### Dominio

- `Minuteiro.Documents`
  - contexto para CRUD de templates
  - no futuro: versionamento e documentos gerados

- `Minuteiro.Parser`
  - extrai declaracoes de variaveis
  - identifica referencias
  - identifica blocos condicionais
  - retorna uma estrutura intermediaria previsivel para o compiler

- `Minuteiro.Compiler`
  - recebe template parseado + respostas
  - resolve condicionais
  - substitui referencias
  - remove marcacoes da linguagem
  - retorna o documento final limpo

#### Infra

- `Minuteiro.AI` ou `Minuteiro.Integrations.Gemini`
  - encapsula chamada HTTP ao Gemini
  - recebe contexto + prompt
  - nao conhece LiveView

## Escopo controlado da linguagem na V1

Para manter o parser confiavel e facil de testar, a V1 tera limites explicitos.

### Suportado na V1

1. Declaracao de variavel:

```text
!@nome_var
!@nome_var[tipo:opcoes]
!@nome_var?
```

- `!@nome_var` implica tipo `texto`
- `!@nome_var?` declara um campo booleano
- `!@nome_var[booleana]` tambem e aceito como booleano
- campos `lista` devem usar `;` entre opcoes, por exemplo `!@estado[lista:SP;RJ;MG]`

2. Referencia de variavel:

```text
@nome_var
```

3. Blocos condicionais:

```text
[SE @variavel = VALOR] ... [SENAO] ... [FIM_SE]
[SE @variavel = VALOR] ... [SE @outra_variavel = OUTRO_VALOR] ... [SENAO] ... [FIM_SE]
```

- A linguagem suporta ramificacoes encadeadas dentro do mesmo bloco logico repetindo ` [SE ...] ` e fechando tudo com um unico ` [FIM_SE] `
- O primeiro ramo verdadeiro vence
- `&&` e `||` sao suportados dentro das condicoes com precedencia padrao

4. Tipos de variavel:

- `texto`
- `data`
- `numero`
- `booleano`
- `lista`
- `ia`

### Fora da V1

- condicionais verdadeiramente aninhadas com um `[FIM_SE]` interno dentro do corpo de outro bloco
- loops
- funcoes customizadas
- expressoes matematicas complexas
- reutilizacao de blocos ou includes

Esses limites sao intencionais. Se a mini-linguagem crescer cedo demais, o custo de manutencao sobe muito antes do produto validar seu fluxo principal.

## Persistencia e preparacao para auditoria

### V1 obrigatoria

Tabela `templates` com:

- `title :string`
- `content :text`
- `description :text`
- `timestamps()`

### Preparado para fase seguinte

Quando entrarmos em auditoria/versionamento, a evolucao natural sera:

1. `template_versions`
   - snapshot do conteudo e metadados a cada salvamento relevante

2. `generated_documents`
   - documento final compilado
   - respostas usadas na compilacao
   - referencia ao template e, idealmente, a uma versao especifica

3. trilha de auditoria
   - quem alterou
   - quando alterou
   - qual versao originou o documento

Nao vamos implementar tudo isso agora, mas as camadas devem ser desenhadas sem acoplamento que dificulte esse passo.

## Estrategia do editor

### Coluna 1 - Editor de modelo

- textarea com o conteudo bruto do template
- `phx-change` com debounce para atualizar preview e parser
- botao `Salvar` para persistir no banco
- evolucao planejada: toolbar de formatacao inline para negrito, italico e sublinhado sem abandonar o template como fonte textual

### Coluna 2 - Formulario dinamico

- cabecalho com `API Key` e `Contexto`
- campos gerados a partir das variaveis retornadas pelo parser
- campos dentro de blocos condicionais so aparecem se a condicao atual for verdadeira com base em `answers`

### Coluna 3 - Documento final

- preview readonly do documento compilado
- atualizacao em tempo real a partir de `answers` e `content`

## IA assincrona

### Diretriz

IA sera um complemento do formulario, nao parte obrigatoria do processo de compilacao.

### Fluxo

1. Ambiente expoe `GEMINI_API_KEY` em runtime e o usuario informa apenas o `Contexto Global`
2. Variavel `ia` exibe prompt + botao `Gerar com IA`
3. A geracao roda de forma assincrona
4. O resultado atualiza `answers` e permanece editavel para revisao humana obrigatoria
5. O preview recompila automaticamente

### Regra tecnica

- evitar bloquear o LiveView
- centralizar integracao HTTP fora da camada web
- nao persistir `API Key` no banco

## Preparacao para uso publico

### Objetivo

Abrir a aplicacao para usuarios reais com isolamento seguro dos dados e capacidade de salvar e reabrir os proprios modelos.

### Requisitos minimos

1. cadastro, login, logout e recuperacao de senha
2. cada template pertence a um usuario
3. dashboard lista apenas os templates do usuario autenticado
4. editor so abre templates do proprio usuario
5. queries, rotas e LiveViews precisam respeitar ownership

### Estrategia de MVP

1. usar ownership direto por `user_id`
2. nao introduzir `workspace` agora
3. manter `Documents` como fronteira de dominio para a camada web
4. deixar `generated_documents` e `template_versions` como evolucoes seguintes

## Ordem de execucao sugerida

### Fase 1 - Fundacao do projeto

Status: concluida

1. Gerar aplicacao Phoenix 1.8 com Ecto/PostgreSQL
2. Configurar TailwindCSS + DaisyUI
3. Adicionar `Req`
4. Validar boot da aplicacao

### Fase 2 - Modelo de dados inicial

Status: concluida

1. Criar contexto `Minuteiro.Documents`
2. Criar schema `Minuteiro.Documents.Template`
3. Criar migration de `templates`
4. Implementar CRUD minimo para dashboard e editor

### Fase 3 - Nucleo da linguagem

Status: concluida

1. Implementar `Minuteiro.Parser`
2. Implementar `Minuteiro.Compiler`
3. Cobrir com testes unitarios fortes
4. Fechar claramente o escopo da V1

### Passo intermediario - API de dominio para a UI

Status: concluido

1. Expor parse/compile no contexto `Minuteiro.Documents`
2. Fazer a futura UI depender do contexto, nao do parser/compiler diretamente
3. Validar esse fluxo com testes

### Fase 4 - Dashboard MPA

Status: concluida

1. Criar rota `/`
2. Listar templates em cards DaisyUI
3. Criar acao de novo template
4. Navegar para o editor dedicado

### Fase 5 - TemplateEditorLive

Status: concluida na base V1

1. Editor de conteudo
2. Formulario dinamico baseado no parser
3. Preview compilado em tempo real
4. Persistencia por botao `Salvar`
5. Feedback de parsing, estado de salvamento e manual de sintaxe para o usuario
6. Atalhos para inserir snippets de variaveis e bloco `SE` diretamente no editor
7. Editor baseado em CodeMirror com autocomplete de variaveis e highlight consistente durante a digitacao
8. Suporte a sintaxe curta de declaracao para texto e booleano, com listas usando `;`

### Fase 6 - IA assincrona

1. Criar modulo de integracao Gemini
2. Adicionar geracao por variavel `ia`
3. Integrar fluxo assincrono no LiveView
4. Tratar loading, erro e sucesso
5. Concluida na primeira iteracao sem persistencia dedicada

### Fase 7 - Autenticacao e ownership dos templates

Status: concluida

1. Rodar `mix phx.gen.auth Accounts User users`
2. Revisar rotas autenticadas e layout base do Phoenix 1.8
3. Adicionar `user_id` em `templates`
4. Tornar `user_id` obrigatorio no schema e no banco
5. Atualizar `Documents` para operar por usuario autenticado
6. Restringir dashboard e editor ao usuario logado
7. Ajustar a experiencia de criacao para nascer com dono definido
8. Cobrir ownership, login e acesso indevido com testes

### Plano tecnico mais concreto da Fase 7

1. Geracao de auth
   - gerar contexto `Accounts`, schema `User`, tokens e telas padrao
   - habilitar cadastro, sessao, confirmacao e reset de senha

2. Dados
   - criar migration adicionando `user_id` em `templates`
   - definir `belongs_to :user, Minuteiro.Accounts.User` em `Template`
   - impedir `user_id` vindo por params do navegador

3. Contexto `Documents`
   - trocar funcoes globais por funcoes escopadas por usuario
   - `list_templates(user)`
   - `get_template!(user, id)`
   - `create_template(user, attrs)`
   - filtrar `update` e `delete` por ownership

4. Web layer
   - proteger `/` e `/templates/:id/edit` por autenticacao
   - passar `current_user` ou `current_scope` para dashboard e editor
   - retornar 404 ou redirecionamento seguro quando o template nao pertencer ao usuario

5. Ajustes de dev
   - revisar o bootstrap do `Modelo teste` para nao conflitar com multiusuario
   - em dev, decidir se o modelo de exemplo sera criado por usuario autenticado ou removido do fluxo automatico

6. Testes
   - cobertura de cadastro e login
   - cobertura de isolamento entre usuarios
   - cobertura de rotas protegidas
   - cobertura do editor abrindo apenas modelos do proprio usuario

7. Criterio de pronto
   - usuario consegue se cadastrar e entrar
   - usuario consegue criar, listar, abrir e salvar apenas os proprios templates
    - acesso cruzado entre usuarios nao funciona
    - suite automatizada cobre o fluxo principal

### Fase 8 - Generated documents

Status: proxima fase concreta

1. Criar migration e schema de `generated_documents`
2. Persistir `answers`, `ai_context`, `status` e `final_document`
3. Vincular cada documento gerado ao `user_id` e `template_id`
4. Expor CRUD escopado por ownership em `Minuteiro.Documents`
5. Permitir criar um documento a partir de um template
6. Permitir salvar e reabrir rascunhos de preenchimento
7. Cobrir ownership e retomada de sessao com testes

### Plano tecnico curto da Fase 8

1. Banco
   - criar tabela `generated_documents`
   - campos iniciais: `user_id`, `template_id`, `title`, `status`, `answers`, `ai_context`, `final_document`

2. Dominio
   - criar schema `Minuteiro.Documents.GeneratedDocument`
   - adicionar API escopada em `Minuteiro.Documents` para listar, criar, buscar e atualizar documentos gerados

3. Web layer
   - adicionar fluxo para criar um documento a partir de um template
   - adicionar tela para reabrir documentos salvos
   - manter o editor de template separado do editor de preenchimento do documento gerado

4. Criterio de pronto
   - usuario autenticado consegue iniciar um documento a partir de um template proprio
   - usuario consegue salvar e reabrir o mesmo rascunho depois
   - acesso cruzado entre usuarios nao funciona

### Fase 9 - Formatacao rica do editor

1. Adicionar toolbar de formatacao no editor
2. Suportar negrito, italico e sublinhado no conteudo do template
3. Preservar compatibilidade com variaveis, condicionais e preview compilado
4. Renderizar preview formatado com sanitizacao segura

### Fase 10 - Preparacao para auditoria

1. Definir modelo de `template_versions`
2. Definir modelo de `generated_documents`
3. Implementar quando o fluxo base estiver estavel

## Foco atual

O foco atual saiu da fundacao da UI e passou da autenticacao para a persistencia do fluxo real de trabalho do usuario. A prioridade agora e implementar `generated_documents` sem quebrar a separacao de responsabilidades: parser/compiler no nucleo, `Documents` como API de dominio, e LiveView apenas como orquestrador de tela.

## Definicao de pronto por etapa

Uma fase so deve ser considerada concluida quando:

- o codigo compila
- os testes da fase passam
- a interface principal da fase funciona manualmente
- a responsabilidade da camada ficou clara e sem logica indevida no LiveView

## Observacoes finais

- O parser e o compiler sao o coracao do produto.
- O LiveView deve permanecer fino.
- A V1 deve privilegiar previsibilidade sobre poder de expressao.
- Auditoria e versionamento entram como evolucao natural, nao como improviso futuro.
