defmodule MinuteiroWeb.PageControllerTest do
  use MinuteiroWeb.ConnCase

  alias Minuteiro.Documents

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")

    response = html_response(conn, 200)

    assert response =~ "Modelos juridicos prontos para evoluir"
    assert response =~ "dashboard-template-form"
    assert response =~ "Nenhum modelo salvo ainda"
    assert response =~ "dashboard-syntax-manual"
    assert response =~ "Manual da sintaxe"
  end

  test "GET / lists saved templates", %{conn: conn} do
    {:ok, template} =
      Documents.create_template(%{
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

  test "POST /templates creates a template and redirects", %{conn: conn} do
    conn =
      post(conn, ~p"/templates", %{
        "template" => %{
          "title" => "Contrato de servicos",
          "description" => "Modelo inicial do dashboard",
          "content" => "!@cliente[texto]\n@cliente"
        }
      })

    [template] = Documents.list_templates()

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
