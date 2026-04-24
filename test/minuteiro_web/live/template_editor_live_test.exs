defmodule MinuteiroWeb.TemplateEditorLiveTest do
  use MinuteiroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Minuteiro.Documents

  test "editor renders template and compiled preview", %{conn: conn} do
    template = template_fixture()

    {:ok, view, _html} = live(conn, ~p"/templates/#{template.id}/edit")

    assert has_element?(view, "#template-editor-form")
    assert has_element?(view, "#template-content-editor")
    assert has_element?(view, "#template-answers-form")
    assert has_element?(view, "#final-document-preview", "Contrato com")
    assert has_element?(view, "#template-save-status", "Salvo")
    assert has_element?(view, "#editor-syntax-manual", "Manual da sintaxe")
    assert has_element?(view, "#create-texto-button", "Criar @texto")
    assert has_element?(view, "#create-data-button", "Criar @data")
    assert has_element?(view, "#create-numero-button", "Criar @numero")
    assert has_element?(view, "#create-booleano-button", "Criar @booleano")
    assert has_element?(view, "#create-lista-button", "Criar @lista")
    assert has_element?(view, "#create-ia-button", "Criar @ia")
    assert has_element?(view, "#create-if-block-button", "Criar Bloco Se")
  end

  test "editor exposes sorted variable names for autocomplete hook", %{conn: conn} do
    template =
      template_fixture(%{
        content: "!@zeta\n!@alpha\n!@meio"
      })

    {:ok, view, _html} = live(conn, ~p"/templates/#{template.id}/edit")

    assert render(view) =~
             ~s(data-variable-names="[&quot;alpha&quot;,&quot;meio&quot;,&quot;zeta&quot;]")
  end

  test "editor renders and updates content revision for hook sync", %{conn: conn} do
    template = template_fixture()

    {:ok, view, _html} = live(conn, ~p"/templates/#{template.id}/edit")

    assert render(view) =~ ~s(data-content-revision="0")

    view
    |> element("#template-content-editor")
    |> render_hook("editor_changed", %{
      "content" => "!@cliente\nContrato revisado com @cliente",
      "revision" => 3
    })

    assert render(view) =~ ~s(data-content-revision="3")
  end

  test "snippet buttons insert generic syntax into template content", %{conn: conn} do
    template = template_fixture()

    {:ok, view, _html} = live(conn, ~p"/templates/#{template.id}/edit")

    view
    |> element("#create-texto-button")
    |> render_click()

    assert render(view) =~ "!@texto"
    assert has_element?(view, "#template-save-status", "Alteracoes locais")

    view
    |> element("#create-booleano-button")
    |> render_click()

    assert render(view) =~ "!@booleano?"

    view
    |> element("#create-if-block-button")
    |> render_click()

    rendered = render(view)
    assert rendered =~ "[SE @var = verdadeiro]"
    assert rendered =~ "resultado verdadeiro"
    assert rendered =~ "[FIM_SE]"
  end

  test "answers update preview and reveal conditional fields", %{conn: conn} do
    template =
      template_fixture(%{
        content: """
        !@tem_representante[booleano]
        [SE @tem_representante = sim]
        !@representante[texto]
        Representante: @representante
        [FIM_SE]
        """
      })

    {:ok, view, _html} = live(conn, ~p"/templates/#{template.id}/edit")

    assert has_element?(view, "#answer_tem_representante")
    refute has_element?(view, "#answer_representante")

    view
    |> form("#template-answers-form", %{"answers" => %{"tem_representante" => "true"}})
    |> render_change()

    assert has_element?(view, "#answer_representante")

    view
    |> form("#template-answers-form", %{
      "answers" => %{"tem_representante" => "true", "representante" => "Marina"}
    })
    |> render_change()

    assert has_element?(view, "#final-document-preview", "Representante: Marina")
  end

  test "conditional variables appear only when boolean condition is verdadeiro", %{conn: conn} do
    template =
      template_fixture(%{
        content: """
        !@variavelbooleano[booleano]
        [SE @variavelbooleano = verdadeiro]
        !@aniversario[data]
        [FIM_SE]
        """
      })

    {:ok, view, _html} = live(conn, ~p"/templates/#{template.id}/edit")

    assert has_element?(view, "#answer_variavelbooleano")
    refute has_element?(view, "#answer_aniversario")

    view
    |> form("#template-answers-form", %{"answers" => %{"variavelbooleano" => "true"}})
    |> render_change()

    assert has_element?(view, "#answer_aniversario")
  end

  test "editor reveals fields from the first active chained branch", %{conn: conn} do
    template =
      template_fixture(%{
        content: """
        !@idade[numero]
        [SE @idade < 16]
        !@representante[texto]
        [SE @idade >= 16 && @idade < 18]
        !@assistente[texto]
        [SENAO]
        !@capaz[texto]
        [FIM_SE]
        """
      })

    {:ok, view, _html} = live(conn, ~p"/templates/#{template.id}/edit")

    assert has_element?(view, "#answer_idade")
    refute has_element?(view, "#answer_representante")
    refute has_element?(view, "#answer_assistente")
    assert has_element?(view, "#answer_capaz")

    view
    |> form("#template-answers-form", %{"answers" => %{"idade" => "14"}})
    |> render_change()

    assert has_element?(view, "#answer_representante")
    refute has_element?(view, "#answer_assistente")
    refute has_element?(view, "#answer_capaz")

    view
    |> form("#template-answers-form", %{"answers" => %{"idade" => "17"}})
    |> render_change()

    refute has_element?(view, "#answer_representante")
    assert has_element?(view, "#answer_assistente")
    refute has_element?(view, "#answer_capaz")

    view
    |> form("#template-answers-form", %{"answers" => %{"idade" => "30"}})
    |> render_change()

    refute has_element?(view, "#answer_representante")
    refute has_element?(view, "#answer_assistente")
    assert has_element?(view, "#answer_capaz")
  end

  test "editor supports default text and shorthand boolean declarations", %{conn: conn} do
    template =
      template_fixture(%{
        content: """
        !@cliente
        !@aprovado?
        [SE @aprovado = sim]
        Documento para @cliente
        [FIM_SE]
        """
      })

    {:ok, view, _html} = live(conn, ~p"/templates/#{template.id}/edit")

    assert has_element?(view, "#answer_cliente")
    assert has_element?(view, "#answer_aprovado")
  end

  test "saving the editor persists template changes", %{conn: conn} do
    template = template_fixture()

    {:ok, view, _html} = live(conn, ~p"/templates/#{template.id}/edit")

    view
    |> form("#template-editor-form", %{
      "template" => %{
        "title" => "Contrato atualizado",
        "description" => "Descricao revisada",
        "content" => "!@cliente[texto]\nDocumento final para @cliente"
      }
    })
    |> render_submit()

    updated_template = Documents.get_template!(template.id)

    assert updated_template.title == "Contrato atualizado"
    assert updated_template.description == "Descricao revisada"
    assert updated_template.content == "!@cliente[texto]\nDocumento final para @cliente"
    assert has_element?(view, "#final-document-preview", "Documento final para")
    assert has_element?(view, "#template-save-status", "Salvo")
  end

  test "editing the template marks the draft as unsaved", %{conn: conn} do
    template = template_fixture()

    {:ok, view, _html} = live(conn, ~p"/templates/#{template.id}/edit")

    view
    |> form("#template-editor-form", %{
      "template" => %{
        "title" => "Contrato atualizado",
        "description" => "Descricao revisada",
        "content" => "!@cliente[texto]\nDocumento final para @cliente"
      }
    })
    |> render_change()

    assert has_element?(view, "#template-save-status", "Alteracoes locais")
  end

  test "editor shows parse errors clearly when content becomes invalid", %{conn: conn} do
    template = template_fixture()

    {:ok, view, _html} = live(conn, ~p"/templates/#{template.id}/edit")

    view
    |> form("#template-editor-form", %{
      "template" => %{
        "title" => template.title,
        "description" => template.description,
        "content" => "[SE @a = sim]antes[SENAO]meio[SENAO]fim[FIM_SE]"
      }
    })
    |> render_change()

    assert has_element?(
             view,
             "#template-parse-errors",
             "conditional block can only contain one [SENAO]"
           )

    assert has_element?(view, "#template-answers-error-state")
    assert has_element?(view, "#template-preview-error-state")
    assert has_element?(view, "#template-save-status", "Alteracoes locais")
  end

  test "saving invalid syntax keeps the draft and signals warnings", %{conn: conn} do
    template = template_fixture()

    {:ok, view, _html} = live(conn, ~p"/templates/#{template.id}/edit")

    view
    |> form("#template-editor-form", %{
      "template" => %{
        "title" => template.title,
        "description" => template.description,
        "content" => "[SE @a = sim]antes[SENAO]meio[SENAO]fim[FIM_SE]"
      }
    })
    |> render_submit()

    updated_template = Documents.get_template!(template.id)

    assert updated_template.content ==
             "[SE @a = sim]antes[SENAO]meio[SENAO]fim[FIM_SE]"

    assert has_element?(view, "#template-save-status", "Salvo com alertas")
    assert render(view) =~ "Modelo salvo, mas ainda ha erros de parsing no template."
  end

  defp template_fixture(attrs \\ %{}) do
    valid_attrs = %{
      title: "Contrato base",
      description: "Modelo para o editor",
      content: "!@cliente\nContrato com @cliente"
    }

    {:ok, template} = Documents.create_template(Map.merge(valid_attrs, attrs))
    template
  end
end
