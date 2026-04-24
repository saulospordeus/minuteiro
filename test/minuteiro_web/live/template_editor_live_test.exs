defmodule MinuteiroWeb.TemplateEditorLiveTest do
  use MinuteiroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Minuteiro.Documents

  test "editor renders template and compiled preview", %{conn: conn} do
    template = template_fixture()

    {:ok, view, _html} = live(conn, ~p"/templates/#{template.id}/edit")

    assert has_element?(view, "#template-editor-form")
    assert has_element?(view, "#template-answers-form")
    assert has_element?(view, "#final-document-preview", "Contrato com")
    assert has_element?(view, "#template-save-status", "Salvo")
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
        "content" => "[SE @a = sim]antes [SE @b = sim]durante[FIM_SE] depois[FIM_SE]"
      }
    })
    |> render_change()

    assert has_element?(
             view,
             "#template-parse-errors",
             "nested conditionals are not supported in V1"
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
        "content" => "[SE @a = sim]antes [SE @b = sim]durante[FIM_SE] depois[FIM_SE]"
      }
    })
    |> render_submit()

    updated_template = Documents.get_template!(template.id)

    assert updated_template.content ==
             "[SE @a = sim]antes [SE @b = sim]durante[FIM_SE] depois[FIM_SE]"

    assert has_element?(view, "#template-save-status", "Salvo com alertas")
    assert render(view) =~ "Modelo salvo, mas ainda ha erros de parsing no template."
  end

  defp template_fixture(attrs \\ %{}) do
    valid_attrs = %{
      title: "Contrato base",
      description: "Modelo para o editor",
      content: "!@cliente[texto]\nContrato com @cliente"
    }

    {:ok, template} = Documents.create_template(Map.merge(valid_attrs, attrs))
    template
  end
end
