defmodule Minuteiro.Repo do
  use Ecto.Repo,
    otp_app: :minuteiro,
    adapter: Ecto.Adapters.Postgres
end
