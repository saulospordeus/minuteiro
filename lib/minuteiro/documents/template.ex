defmodule Minuteiro.Documents.Template do
  use Ecto.Schema

  import Ecto.Changeset

  schema "templates" do
    field :title, :string
    field :description, :string
    field :content, :string

    belongs_to :user, Minuteiro.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(template, attrs) do
    template
    |> cast(attrs, [:title, :description, :content])
    |> validate_required([:title, :content])
  end
end
