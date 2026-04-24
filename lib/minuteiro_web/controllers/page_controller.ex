defmodule MinuteiroWeb.PageController do
  use MinuteiroWeb, :controller

  alias Minuteiro.Documents
  alias Phoenix.Component

  def home(conn, _params) do
    maybe_bootstrap_sample_template()
    render_dashboard(conn, Component.to_form(Documents.change_template(Documents.new_template())))
  end

  def create_template(conn, %{"template" => template_params}) do
    case Documents.create_template(template_params) do
      {:ok, template} ->
        conn
        |> put_flash(:info, "Modelo criado com sucesso.")
        |> redirect(to: ~p"/templates/#{template.id}/edit")

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render_dashboard(Component.to_form(changeset))
    end
  end

  defp render_dashboard(conn, form) do
    render(conn, :home,
      page_title: "Dashboard",
      templates: Documents.list_templates(),
      form: form
    )
  end

  defp maybe_bootstrap_sample_template do
    if Application.get_env(:minuteiro, :bootstrap_sample_template, false) do
      Documents.ensure_sample_template()
    end
  end
end
