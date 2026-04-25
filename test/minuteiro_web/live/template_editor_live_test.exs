defmodule MinuteiroWeb.TemplateEditorLiveTest do
  use MinuteiroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Minuteiro.Documents

  setup :register_and_log_in_user

  test "editor redirects unauthenticated users" do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} =
             live(Phoenix.ConnTest.build_conn(), ~p"/templates/123/edit")
  end

  test "editor redirects when template belongs to another user", %{conn: conn} do
    other_scope = Minuteiro.AccountsFixtures.user_scope_fixture()
    template = template_fixture(other_scope)

    assert {:error, {:live_redirect, %{to: "/", flash: %{"error" => "Modelo nao encontrado."}}}} =
             live(conn, ~p"/templates/#{template.id}/edit")
  end

  test "editor renders template and compiled preview", %{conn: conn, scope: scope} do
    template = template_fixture(scope)

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

  test "editor exposes sorted variable names for autocomplete hook", %{conn: conn, scope: scope} do
    template =
      template_fixture(scope, %{
        content: "!@zeta\n!@alpha\n!@meio"
      })

    {:ok, view, _html} = live(conn, ~p"/templates/#{template.id}/edit")

    assert render(view) =~
             ~s(data-variable-names="[&quot;alpha&quot;,&quot;meio&quot;,&quot;zeta&quot;]")
  end

  test "editor renders and updates content revision for hook sync", %{conn: conn, scope: scope} do
    template = template_fixture(scope)

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

  test "snippet buttons insert generic syntax into template content", %{conn: conn, scope: scope} do
    template = template_fixture(scope)

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

  test "answers update preview and reveal conditional fields", %{conn: conn, scope: scope} do
    template =
      template_fixture(scope, %{
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

  test "conditional variables appear only when boolean condition is verdadeiro", %{
    conn: conn,
    scope: scope
  } do
    template =
      template_fixture(scope, %{
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

  test "editor renders dedicated controls for ia variables", %{conn: conn, scope: scope} do
    template =
      template_fixture(scope, %{
        content: "!@ementa[ia: Resuma o caso com base no contexto.]\n@ementa"
      })

    {:ok, view, _html} = live(conn, ~p"/templates/#{template.id}/edit")

    assert has_element?(view, "#ai-global-context-panel")
    assert has_element?(view, "#ai-global-context")
    assert has_element?(view, "#ai_prompt_ementa")
    assert has_element?(view, "#generate-ai-ementa", "Gerar com IA")
    assert has_element?(view, "#answer_ementa")
    assert render(view) =~ "Resuma o caso com base no contexto."
  end

  test "editor generates ai content asynchronously and allows manual review", %{
    conn: conn,
    scope: scope
  } do
    template =
      template_fixture(scope, %{
        content: "!@ementa[ia: Resuma o caso com base no contexto.]\nEmenta: @ementa"
      })

    {:ok, view, _html} = live(conn, ~p"/templates/#{template.id}/edit")

    view
    |> form("#template-answers-form", %{
      "ai" => %{
        "context" => "Peticao inicial descreve pedido urgente.",
        "prompts" => %{"ementa" => "[slow] Resuma o caso com base no contexto."}
      },
      "answers" => %{"ementa" => ""}
    })
    |> render_change()

    loading_html =
      view
      |> element("#generate-ai-ementa")
      |> render_click()

    assert loading_html =~ "Gerando..."

    async_html = render_async(view)

    assert async_html =~ "Resposta IA: [slow] Resuma o caso com base no contexto."
    assert async_html =~ "Peticao inicial descreve pedido urgente."

    assert has_element?(
             view,
             "#final-document-preview",
             "Resposta IA: [slow] Resuma o caso com base no contexto."
           )

    view
    |> form("#template-answers-form", %{
      "ai" => %{
        "context" => "Peticao inicial descreve pedido urgente.",
        "prompts" => %{"ementa" => "Resuma o caso com base no contexto."}
      },
      "answers" => %{"ementa" => "Texto revisado manualmente."}
    })
    |> render_change()

    assert has_element?(view, "#final-document-preview", "Texto revisado manualmente.")
  end

  test "editor surfaces ai generation errors without blocking the form", %{
    conn: conn,
    scope: scope
  } do
    template =
      template_fixture(scope, %{
        content: "!@ementa[ia: Resuma o caso com base no contexto.]\n@ementa"
      })

    {:ok, view, _html} = live(conn, ~p"/templates/#{template.id}/edit")

    view
    |> form("#template-answers-form", %{
      "ai" => %{
        "context" => "Peticao inicial descreve pedido urgente.",
        "prompts" => %{"ementa" => "[force_error]"}
      },
      "answers" => %{"ementa" => ""}
    })
    |> render_change()

    view
    |> element("#generate-ai-ementa")
    |> render_click()

    error_html = render_async(view)

    assert error_html =~ "Falha simulada da IA para testes."
    assert has_element?(view, "#ai-error-ementa", "Falha simulada da IA para testes.")
    assert has_element?(view, "#ai-global-context")
    assert has_element?(view, "#generate-ai-ementa", "Gerar com IA")
  end

  test "editor reveals fields from the first active chained branch", %{conn: conn, scope: scope} do
    template =
      template_fixture(scope, %{
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

  test "editor supports default text and shorthand boolean declarations", %{
    conn: conn,
    scope: scope
  } do
    template =
      template_fixture(scope, %{
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

  test "saving the editor persists template changes", %{conn: conn, scope: scope} do
    template = template_fixture(scope)

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

    updated_template = Documents.get_template!(scope, template.id)

    assert updated_template.title == "Contrato atualizado"
    assert updated_template.description == "Descricao revisada"
    assert updated_template.content == "!@cliente[texto]\nDocumento final para @cliente"
    assert has_element?(view, "#final-document-preview", "Documento final para")
    assert has_element?(view, "#template-save-status", "Salvo")
  end

  test "editing the template marks the draft as unsaved", %{conn: conn, scope: scope} do
    template = template_fixture(scope)

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

  test "editor shows parse errors clearly when content becomes invalid", %{
    conn: conn,
    scope: scope
  } do
    template = template_fixture(scope)

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

  test "saving invalid syntax keeps the draft and signals warnings", %{conn: conn, scope: scope} do
    template = template_fixture(scope)

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

    updated_template = Documents.get_template!(scope, template.id)

    assert updated_template.content ==
             "[SE @a = sim]antes[SENAO]meio[SENAO]fim[FIM_SE]"

    assert has_element?(view, "#template-save-status", "Salvo com alertas")
    assert render(view) =~ "Modelo salvo, mas ainda ha erros de parsing no template."
  end

  defp template_fixture(scope, attrs \\ %{}) do
    valid_attrs = %{
      title: "Contrato base",
      description: "Modelo para o editor",
      content: "!@cliente\nContrato com @cliente"
    }

    {:ok, template} = Documents.create_template(scope, Map.merge(valid_attrs, attrs))
    template
  end
end
