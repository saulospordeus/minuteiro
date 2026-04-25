defmodule MinuteiroWeb.PageController do
  use MinuteiroWeb, :controller

  alias Minuteiro.Documents
  alias Phoenix.Component

  def home(conn, _params) do
    current_scope = conn.assigns.current_scope

    maybe_bootstrap_sample_template(current_scope)

    render_dashboard(
      conn,
      current_scope,
      Component.to_form(Documents.change_template(Documents.new_template()))
    )
  end

  def create_template(conn, %{"template" => template_params}) do
    current_scope = conn.assigns.current_scope

    case Documents.create_template(current_scope, template_params) do
      {:ok, template} ->
        conn
        |> put_flash(:info, "Modelo criado com sucesso.")
        |> redirect(to: ~p"/templates/#{template.id}/edit")

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render_dashboard(current_scope, Component.to_form(changeset))
    end
  end

  defp render_dashboard(conn, current_scope, form) do
    render(conn, :home,
      page_title: "Dashboard",
      templates: Documents.list_templates(current_scope),
      form: form,
      current_scope: current_scope
    )
  end

  defp maybe_bootstrap_sample_template(current_scope) do
    if Application.get_env(:minuteiro, :bootstrap_sample_template, false) do
      Documents.ensure_sample_template(current_scope)
    end
  end
end
