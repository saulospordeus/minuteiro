defmodule Minuteiro.Repo.Migrations.CreateTemplates do
  use Ecto.Migration

  def change do
    create table(:templates) do
      add :title, :string, null: false
      add :description, :text
      add :content, :text, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
