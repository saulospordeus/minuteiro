defmodule Minuteiro.Documents do
  @moduledoc """
  The Documents context.
  """

  import Ecto.Query, warn: false

  alias Minuteiro.AI
  alias Minuteiro.Accounts.Scope
  alias Minuteiro.Accounts.User
  alias Minuteiro.Compiler
  alias Minuteiro.Documents.Template
  alias Minuteiro.Parser
  alias Minuteiro.Repo

  def new_template do
    %Template{}
  end

  def ensure_sample_template(%Scope{user: %User{} = user} = current_scope) do
    attrs = sample_template_attrs()

    case Repo.get_by(owned_templates_query(user), title: attrs.title) do
      nil -> create_template(current_scope, attrs)
      template -> update_template(current_scope, template, attrs)
    end
  end

  def list_templates(%Scope{user: %User{} = user}) do
    from(template in owned_templates_query(user), order_by: [desc: template.inserted_at])
    |> Repo.all()
  end

  def get_template(%Scope{user: %User{} = user}, id) do
    Repo.get_by(owned_templates_query(user), id: id)
  end

  def get_template!(%Scope{user: %User{} = user}, id) do
    Repo.get_by!(owned_templates_query(user), id: id)
  end

  def create_template(%Scope{user: %User{} = user}, attrs \\ %{}) do
    user
    |> Ecto.build_assoc(:templates)
    |> Template.changeset(attrs)
    |> Repo.insert()
  end

  def update_template(%Scope{} = current_scope, %Template{} = template, attrs) do
    current_scope
    |> get_template!(template.id)
    |> Template.changeset(attrs)
    |> Repo.update()
  end

  def delete_template(%Scope{} = current_scope, %Template{} = template) do
    current_scope
    |> get_template!(template.id)
    |> Repo.delete()
  end

  def change_template(%Template{} = template, attrs \\ %{}) do
    Template.changeset(template, attrs)
  end

  def parse_template(%Template{} = template) do
    parse_template_content(template.content)
  end

  def parse_template_content(content) when is_binary(content) do
    Parser.parse(content)
  end

  def compile_template(%Template{} = template, answers \\ %{}) when is_map(answers) do
    compile_template_content(template.content, answers)
  end

  def compile_template_content(content, answers \\ %{})
      when is_binary(content) and is_map(answers) do
    Compiler.compile_template(content, answers)
  end

  def analyze_template(%Template{} = template, answers \\ %{}) when is_map(answers) do
    analyze_template_content(template.content, answers)
  end

  def analyze_template_content(content, answers \\ %{})
      when is_binary(content) and is_map(answers) do
    with {:ok, parsed_template} <- Parser.parse(content),
         {:ok, active_parsed_template} <-
           parsed_template
           |> Compiler.active_content(answers)
           |> Parser.parse() do
      {:ok,
       %{
         parsed_template: parsed_template,
         variables: active_parsed_template.variables,
         final_document: Compiler.compile(parsed_template, answers)
       }}
    end
  end

  def generate_ai_text(attrs) when is_map(attrs) do
    prompt = fetch_string(attrs, :prompt)
    context = fetch_string(attrs, :context)
    variable_name = fetch_string(attrs, :variable_name)

    if prompt == "" do
      {:error, "Informe uma instrucao antes de gerar com IA."}
    else
      AI.generate_text(%{prompt: prompt, context: context, variable_name: variable_name})
    end
  end

  defp sample_template_attrs do
    %{
      title: "Modelo teste",
      description:
        "Template salvo automaticamente no ambiente local para exercitar todos os tipos ja suportados, exceto IA.",
      content:
        """
        !@contratante
        !@data_assinatura[data]
        !@valor_total[numero]
        !@tem_representante?
        !@foro[lista:Recife;Olinda;Jaboatao]

        MINUTA TESTE DE CONTRATO

        Contratante: @contratante
        Data da assinatura: @data_assinatura
        Valor total: @valor_total
        Foro escolhido: @foro

        [SE @tem_representante = sim]
        O contratante declara que atuara com representante no fechamento deste instrumento.
        [SENAO]
        O contratante declara que assinara este instrumento sem representante.
        [FIM_SE]
        """
        |> String.trim()
    }
  end

  defp fetch_string(attrs, key) do
    attrs
    |> Map.get(key, Map.get(attrs, to_string(key), ""))
    |> to_string()
    |> String.trim()
  end

  defp owned_templates_query(%User{} = user) do
    from(template in Template, where: template.user_id == ^user.id)
  end
end
