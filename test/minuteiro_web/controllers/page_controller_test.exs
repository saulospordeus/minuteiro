defmodule MinuteiroWeb.PageControllerTest do
  use MinuteiroWeb.ConnCase

  alias Minuteiro.Documents

  setup :register_and_log_in_user

  test "GET / redirects unauthenticated users to login" do
    conn = Phoenix.ConnTest.build_conn() |> get(~p"/")

    assert redirected_to(conn) == ~p"/users/log-in"
  end

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")

    response = html_response(conn, 200)

    assert response =~ "Modelos juridicos prontos para evoluir"
    assert response =~ "dashboard-template-form"
    assert response =~ "Nenhum modelo salvo ainda"
    assert response =~ "dashboard-syntax-manual"
    assert response =~ "Manual da sintaxe"
  end

  test "GET / lists saved templates", %{conn: conn, scope: scope} do
    {:ok, template} =
      Documents.create_template(scope, %{
        title: "Modelo de notificacao",
        description: "Template para comunicacoes formais",
        content: "!@destinatario[texto]\n@destinatario"
      })

    conn = get(conn, ~p"/")
    response = html_response(conn, 200)

    assert response =~ template.title
    assert response =~ template.description
    assert response =~ "template-card-#{template.id}"
  end

  test "GET / bootstraps the local sample template when enabled", %{conn: conn, scope: scope} do
    previous_value = Application.get_env(:minuteiro, :bootstrap_sample_template, false)
    Application.put_env(:minuteiro, :bootstrap_sample_template, true)

    on_exit(fn ->
      Application.put_env(:minuteiro, :bootstrap_sample_template, previous_value)
    end)

    conn = get(conn, ~p"/")
    response = html_response(conn, 200)

    [template] = Documents.list_templates(scope)

    assert response =~ "Modelo teste"
    assert response =~ template.description
    assert template.title == "Modelo teste"
    assert template.content =~ "!@contratante"
    assert template.content =~ "!@data_assinatura[data]"
    assert template.content =~ "!@valor_total[numero]"
    assert template.content =~ "!@tem_representante?"
    assert template.content =~ "!@foro[lista:Recife;Olinda;Jaboatao]"
    assert template.content =~ "[SE @tem_representante = sim]"
    refute template.content =~ "[ia"
  end

  test "POST /templates creates a template and redirects", %{conn: conn, scope: scope} do
    conn =
      post(conn, ~p"/templates", %{
        "template" => %{
          "title" => "Contrato de servicos",
          "description" => "Modelo inicial do dashboard",
          "content" => "!@cliente[texto]\n@cliente"
        }
      })

    [template] = Documents.list_templates(scope)

    assert redirected_to(conn) == ~p"/templates/#{template.id}/edit"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Modelo criado com sucesso."
    assert template.title == "Contrato de servicos"
  end

  test "POST /templates with invalid data rerenders dashboard", %{conn: conn} do
    conn =
      post(conn, ~p"/templates", %{
        "template" => %{
          "title" => "",
          "description" => "Sem conteudo suficiente",
          "content" => ""
        }
      })

    response = html_response(conn, 422)

    assert response =~ "dashboard-template-form"
    assert response =~ "can&#39;t be blank"
  end
end
