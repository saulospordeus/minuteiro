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
- O dashboard em `/` e o editor em `/templates/:id/edit` ja estao funcionando sobre a API de dominio
- Em desenvolvimento, abrir `/` garante um `Modelo teste` persistido para validacao manual da linguagem, cobrindo texto, data, numero, booleano, lista e um bloco `SE`, sem usar `ia`
- O editor ja mostra estados de salvamento e erros de parsing de forma explicita
- O editor ja oferece manual de sintaxe para ajudar o usuario final a escrever templates
- O editor ja oferece botoes para inserir rapidamente variaveis e blocos condicionais genericos no template
- O editor agora usa CodeMirror com autocomplete de variaveis e highlights estaveis para declaracoes e referencias
- A sintaxe do template agora aceita texto implicito com `!@campo`, booleano curto com `!@campo?`, alias `booleana` e listas separadas por `;`

## Proximo passo imediato

O proximo passo real agora e definir a camada seguinte do editor e da IA:

1. Refinar o comportamento esperado das variaveis `ia`
2. Implementar fluxo assincrono de geracao sem contaminar a logica central do parser/compiler
3. Manter o editor fino, consumindo apenas `Minuteiro.Documents`
4. Depois disso avaliar versionamento inicial de templates

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

3. Condicional simples:

```text
[SE @variavel = VALOR] ... [SENAO] ... [FIM_SE]
```

4. Tipos de variavel:

- `texto`
- `data`
- `numero`
- `booleano`
- `lista`
- `ia`

### Fora da V1

- condicionais aninhadas
- operadores logicos compostos (`E`, `OU`)
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

1. Usuario informa `API Key` e `Contexto`
2. Variavel `ia` exibe prompt + botao `Gerar com IA`
3. A geracao roda de forma assincrona
4. O resultado atualiza `answers`
5. O preview recompila automaticamente

### Regra tecnica

- evitar bloquear o LiveView
- centralizar integracao HTTP fora da camada web
- nao persistir `API Key` no banco

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

### Fase 7 - Preparacao para auditoria

1. Definir modelo de `template_versions`
2. Definir modelo de `generated_documents`
3. Implementar quando o fluxo base estiver estavel

## Foco atual

O foco atual saiu da fundacao da UI e passou para o refinamento do editor e para a futura camada de IA assincrona. A prioridade agora e preservar a separacao de responsabilidades: parser/compiler no nucleo, `Documents` como API de dominio, e LiveView apenas como orquestrador de tela.

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
