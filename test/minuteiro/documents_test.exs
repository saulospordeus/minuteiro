defmodule Minuteiro.DocumentsTest do
  use Minuteiro.DataCase, async: true

  alias Minuteiro.Documents
  alias Minuteiro.Documents.Template

  @invalid_attrs %{title: nil, description: nil, content: nil}

  test "list_templates/0 returns all templates" do
    template = template_fixture()

    assert Documents.list_templates() == [template]
  end

  test "get_template!/1 returns the template with given id" do
    template = template_fixture()

    assert Documents.get_template!(template.id) == template
  end

  test "create_template/1 with valid data creates a template" do
    valid_attrs = %{
      title: "Contrato de prestacao de servicos",
      description: "Modelo base para contratos simples",
      content: "!@contratante[texto]\n@contratante"
    }

    assert {:ok, %Template{} = template} = Documents.create_template(valid_attrs)
    assert template.title == "Contrato de prestacao de servicos"
    assert template.description == "Modelo base para contratos simples"
    assert template.content == "!@contratante[texto]\n@contratante"
  end

  test "create_template/1 with invalid data returns error changeset" do
    assert {:error, %Ecto.Changeset{}} = Documents.create_template(@invalid_attrs)
  end

  test "update_template/2 with valid data updates the template" do
    template = template_fixture()

    update_attrs = %{
      title: "Peticao inicial",
      description: "Modelo atualizado",
      content: "!@autor[texto]\n@autor"
    }

    assert {:ok, %Template{} = template} = Documents.update_template(template, update_attrs)
    assert template.title == "Peticao inicial"
    assert template.description == "Modelo atualizado"
    assert template.content == "!@autor[texto]\n@autor"
  end

  test "update_template/2 with invalid data returns error changeset" do
    template = template_fixture()

    assert {:error, %Ecto.Changeset{}} = Documents.update_template(template, @invalid_attrs)
    assert template == Documents.get_template!(template.id)
  end

  test "delete_template/1 deletes the template" do
    template = template_fixture()

    assert {:ok, %Template{}} = Documents.delete_template(template)
    assert_raise Ecto.NoResultsError, fn -> Documents.get_template!(template.id) end
  end

  test "change_template/1 returns a template changeset" do
    template = template_fixture()

    assert %Ecto.Changeset{} = Documents.change_template(template)
  end

  test "parse_template/1 parses persisted template content" do
    template =
      template_fixture(%{
        content: "!@nome[texto]\n[SE @ativo = sim]@nome[FIM_SE]"
      })

    assert {:ok, parsed} = Documents.parse_template(template)
    assert Enum.map(parsed.variables, & &1.name) == ["nome"]
    assert parsed.references == ["ativo", "nome"]
  end

  test "parse_template_content/1 parses unsaved editor content" do
    content = "!@cidade\nDocumento para @cidade"

    assert {:ok, parsed} = Documents.parse_template_content(content)
    assert Enum.map(parsed.variables, & &1.name) == ["cidade"]
    assert parsed.references == ["cidade"]
  end

  test "ensure_sample_template/0 creates the sample template once" do
    assert {:ok, first_template} = Documents.ensure_sample_template()
    assert {:ok, second_template} = Documents.ensure_sample_template()

    assert first_template.id == second_template.id
    assert first_template.title == "Modelo teste"
    assert first_template.content =~ "!@contratante"
    assert first_template.content =~ "!@data_assinatura[data]"
    assert first_template.content =~ "!@valor_total[numero]"
    assert first_template.content =~ "!@tem_representante?"
    assert first_template.content =~ "!@foro[lista:Recife;Olinda;Jaboatao]"
    assert first_template.content =~ "[SE @tem_representante = sim]"
    refute first_template.content =~ "[ia"
  end

  test "ensure_sample_template/0 refreshes an existing stale sample template" do
    {:ok, stale_template} =
      Documents.create_template(%{
        title: "Modelo teste",
        description: "Template antigo",
        content: "!@nome: saulo\n\nMeu nome e @nome."
      })

    assert {:ok, refreshed_template} = Documents.ensure_sample_template()

    assert refreshed_template.id == stale_template.id
    assert refreshed_template.description =~ "todos os tipos ja suportados"
    assert refreshed_template.content =~ "!@contratante"
    assert refreshed_template.content =~ "!@data_assinatura[data]"
    assert refreshed_template.content =~ "!@valor_total[numero]"
    assert refreshed_template.content =~ "!@tem_representante?"
    assert refreshed_template.content =~ "!@foro[lista:Recife;Olinda;Jaboatao]"
    assert refreshed_template.content =~ "[SE @tem_representante = sim]"
    refute refreshed_template.content =~ "!@nome: saulo"
  end

  test "analyze_template_content/2 recognizes shorthand boolean declarations" do
    content = """
    !@tem_representante?
    [SE @tem_representante = sim]
    !@representante
    Representante: @representante
    [FIM_SE]
    """

    assert {:ok, analysis} =
             Documents.analyze_template_content(content, %{"tem_representante" => true})

    assert Enum.map(analysis.variables, & &1.name) == ["tem_representante", "representante"]
    assert analysis.final_document == "Representante:"
  end

  test "compile_template/2 compiles persisted template content" do
    template =
      template_fixture(%{
        content: "!@nome[texto]\n[SE @ativo = sim]Ola, @nome[FIM_SE]"
      })

    assert {:ok, "Ola, Joana"} =
             Documents.compile_template(template, %{nome: "Joana", ativo: true})
  end

  test "compile_template_content/2 compiles unsaved editor content" do
    content = "!@cargo[texto]\nCargo: @cargo"

    assert {:ok, "Cargo: Advogada"} =
             Documents.compile_template_content(content, %{cargo: "Advogada"})
  end

  test "compile_template_content/2 returns parser errors for invalid content" do
    content = "[SE @a = sim]antes [SE @b = sim]durante[FIM_SE] depois[FIM_SE]"

    assert {:error, ["nested conditionals are not supported in V1"]} =
             Documents.compile_template_content(content, %{})
  end

  test "analyze_template_content/2 returns active variables and compiled preview" do
    content = """
    !@tem_representante[booleano]
    [SE @tem_representante = sim]
    !@representante[texto]
    Representante: @representante
    [FIM_SE]
    """

    assert {:ok, analysis} =
             Documents.analyze_template_content(content, %{"tem_representante" => true})

    assert Enum.map(analysis.variables, & &1.name) == ["tem_representante", "representante"]
    assert analysis.final_document == "Representante:"
  end

  test "analyze_template_content/2 only exposes conditional variables when branch is active" do
    content = """
    !@variavelbooleano[booleano]
    [SE @variavelbooleano = verdadeiro]
    !@aniversario[data]
    [FIM_SE]
    """

    assert {:ok, inactive_analysis} =
             Documents.analyze_template_content(content, %{"variavelbooleano" => false})

    assert Enum.map(inactive_analysis.variables, & &1.name) == ["variavelbooleano"]

    assert {:ok, active_analysis} =
             Documents.analyze_template_content(content, %{"variavelbooleano" => true})

    assert Enum.map(active_analysis.variables, & &1.name) == ["variavelbooleano", "aniversario"]
  end

  defp template_fixture(attrs \\ %{}) do
    valid_attrs = %{
      title: "Modelo de procuracao",
      description: "Documento base para procuracao",
      content: "!@outorgante[texto]\n@outorgante"
    }

    attrs = Map.merge(valid_attrs, attrs)

    {:ok, template} = Documents.create_template(attrs)
    template
  end
end
