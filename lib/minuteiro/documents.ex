defmodule Minuteiro.Documents do
  @moduledoc """
  The Documents context.
  """

  import Ecto.Query, warn: false

  alias Minuteiro.Compiler
  alias Minuteiro.Documents.Template
  alias Minuteiro.Parser
  alias Minuteiro.Repo

  def new_template do
    %Template{}
  end

  def list_templates do
    from(template in Template, order_by: [desc: template.inserted_at])
    |> Repo.all()
  end

  def get_template!(id), do: Repo.get!(Template, id)

  def create_template(attrs \\ %{}) do
    %Template{}
    |> Template.changeset(attrs)
    |> Repo.insert()
  end

  def update_template(%Template{} = template, attrs) do
    template
    |> Template.changeset(attrs)
    |> Repo.update()
  end

  def delete_template(%Template{} = template) do
    Repo.delete(template)
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
end
