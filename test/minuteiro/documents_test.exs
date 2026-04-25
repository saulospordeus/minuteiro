defmodule Minuteiro.DocumentsTest do
  use Minuteiro.DataCase, async: true

  alias Minuteiro.AccountsFixtures
  alias Minuteiro.Documents
  alias Minuteiro.Documents.Template

  @invalid_attrs %{title: nil, description: nil, content: nil}

  setup do
    %{scope: AccountsFixtures.user_scope_fixture()}
  end

  test "list_templates/1 returns all templates for the scope", %{scope: scope} do
    template = template_fixture(scope)

    assert Documents.list_templates(scope) == [template]
  end

  test "list_templates/1 excludes templates from other users", %{scope: scope} do
    template = template_fixture(scope)
    other_scope = AccountsFixtures.user_scope_fixture()
    _other_template = template_fixture(other_scope, %{title: "Template alheio"})

    assert Documents.list_templates(scope) == [template]
  end

  test "get_template!/2 returns the template with given id for the scope", %{scope: scope} do
    template = template_fixture(scope)

    assert Documents.get_template!(scope, template.id) == template
  end

  test "get_template!/2 raises when accessing another user's template", %{scope: scope} do
    other_scope = AccountsFixtures.user_scope_fixture()
    template = template_fixture(other_scope)

    assert_raise Ecto.NoResultsError, fn -> Documents.get_template!(scope, template.id) end
  end

  test "create_template/2 with valid data creates a template", %{scope: scope} do
    valid_attrs = %{
      title: "Contrato de prestacao de servicos",
      description: "Modelo base para contratos simples",
      content: "!@contratante[texto]\n@contratante"
    }

    assert {:ok, %Template{} = template} = Documents.create_template(scope, valid_attrs)
    assert template.title == "Contrato de prestacao de servicos"
    assert template.description == "Modelo base para contratos simples"
    assert template.content == "!@contratante[texto]\n@contratante"
    assert template.user_id == scope.user.id
  end

  test "create_template/2 with invalid data returns error changeset", %{scope: scope} do
    assert {:error, %Ecto.Changeset{}} = Documents.create_template(scope, @invalid_attrs)
  end

  test "update_template/3 with valid data updates the template", %{scope: scope} do
    template = template_fixture(scope)

    update_attrs = %{
      title: "Peticao inicial",
      description: "Modelo atualizado",
      content: "!@autor[texto]\n@autor"
    }

    assert {:ok, %Template{} = template} =
             Documents.update_template(scope, template, update_attrs)

    assert template.title == "Peticao inicial"
    assert template.description == "Modelo atualizado"
    assert template.content == "!@autor[texto]\n@autor"
  end

  test "update_template/3 with invalid data returns error changeset", %{scope: scope} do
    template = template_fixture(scope)

    assert {:error, %Ecto.Changeset{}} =
             Documents.update_template(scope, template, @invalid_attrs)

    assert template == Documents.get_template!(scope, template.id)
  end

  test "delete_template/2 deletes the template", %{scope: scope} do
    template = template_fixture(scope)

    assert {:ok, %Template{}} = Documents.delete_template(scope, template)
    assert_raise Ecto.NoResultsError, fn -> Documents.get_template!(scope, template.id) end
  end

  test "change_template/1 returns a template changeset", %{scope: scope} do
    template = template_fixture(scope)

    assert %Ecto.Changeset{} = Documents.change_template(template)
  end

  test "parse_template/1 parses persisted template content", %{scope: scope} do
    template =
      template_fixture(scope, %{
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

  test "ensure_sample_template/1 creates the sample template once per scope", %{scope: scope} do
    assert {:ok, first_template} = Documents.ensure_sample_template(scope)
    assert {:ok, second_template} = Documents.ensure_sample_template(scope)

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

  test "ensure_sample_template/1 refreshes an existing stale sample template", %{scope: scope} do
    {:ok, stale_template} =
      Documents.create_template(scope, %{
        title: "Modelo teste",
        description: "Template antigo",
        content: "!@nome: saulo\n\nMeu nome e @nome."
      })

    assert {:ok, refreshed_template} = Documents.ensure_sample_template(scope)

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

  test "compile_template/2 compiles persisted template content", %{scope: scope} do
    template =
      template_fixture(scope, %{
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

  test "generate_ai_text/1 delegates to the configured AI client" do
    assert {:ok, generated_text} =
             Documents.generate_ai_text(%{
               prompt: "Resuma o caso em um paragrafo.",
               context: "Autor requer tutela de urgencia.",
               variable_name: "resumo"
             })

    assert generated_text =~ "Resuma o caso em um paragrafo."
    assert generated_text =~ "Autor requer tutela de urgencia."
  end

  test "generate_ai_text/1 validates a missing prompt" do
    assert {:error, "Informe uma instrucao antes de gerar com IA."} =
             Documents.generate_ai_text(%{prompt: "  ", context: "qualquer"})
  end

  test "generate_ai_text/1 propagates client errors" do
    assert {:error, "Falha simulada da IA para testes."} =
             Documents.generate_ai_text(%{prompt: "[force_error]", context: "qualquer"})
  end

  test "compile_template_content/2 returns parser errors for invalid content" do
    content = "[SE @a = sim]antes[SENAO]meio[SENAO]fim[FIM_SE]"

    assert {:error, ["conditional block can only contain one [SENAO]"]} =
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

  test "analyze_template_content/2 keeps ia variables active with their prompt metadata" do
    content = "!@fundamentacao[ia: Redija a fundamentacao com base no contexto.]\n@fundamentacao"

    assert {:ok, analysis} = Documents.analyze_template_content(content, %{})

    assert analysis.variables == [
             %{
               name: "fundamentacao",
               type: "ia",
               prompt: "Redija a fundamentacao com base no contexto.",
               raw_options: "Redija a fundamentacao com base no contexto.",
               options: []
             }
           ]
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

  test "analyze_template_content/2 evaluates composite logical conditions" do
    content = """
    !@idade[numero]
    !@tipo
    !@admin?
    [SE @idade > 18 && @tipo == "civil" || @admin == true]
    !@documento_extra
    [FIM_SE]
    """

    assert {:ok, denied_analysis} =
             Documents.analyze_template_content(content, %{
               "idade" => 16,
               "tipo" => "penal",
               "admin" => false
             })

    assert Enum.map(denied_analysis.variables, & &1.name) == ["idade", "tipo", "admin"]

    assert {:ok, allowed_analysis} =
             Documents.analyze_template_content(content, %{
               "idade" => 20,
               "tipo" => "civil",
               "admin" => false
             })

    assert Enum.map(allowed_analysis.variables, & &1.name) == [
             "idade",
             "tipo",
             "admin",
             "documento_extra"
           ]
  end

  test "analyze_template_content/2 only exposes the first active chained branch" do
    content = """
    !@idade[numero]
    [SE @idade < 16]
    !@representante[texto]
    [SE @idade >= 16 && @idade < 18]
    !@assistente[texto]
    [SENAO]
    !@capaz[texto]
    [FIM_SE]
    """

    assert {:ok, minor_analysis} = Documents.analyze_template_content(content, %{"idade" => 14})
    assert Enum.map(minor_analysis.variables, & &1.name) == ["idade", "representante"]

    assert {:ok, teen_analysis} = Documents.analyze_template_content(content, %{"idade" => 17})
    assert Enum.map(teen_analysis.variables, & &1.name) == ["idade", "assistente"]

    assert {:ok, adult_analysis} = Documents.analyze_template_content(content, %{"idade" => 30})
    assert Enum.map(adult_analysis.variables, & &1.name) == ["idade", "capaz"]
  end

  defp template_fixture(scope, attrs \\ %{}) do
    valid_attrs = %{
      title: "Modelo de procuracao",
      description: "Documento base para procuracao",
      content: "!@outorgante[texto]\n@outorgante"
    }

    attrs = Map.merge(valid_attrs, attrs)

    {:ok, template} = Documents.create_template(scope, attrs)
    template
  end
end
