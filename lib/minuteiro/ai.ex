defmodule Minuteiro.AI do
  @moduledoc """
  Boundary for AI text generation providers.
  """

  def generate_text(%{} = attrs) do
    client().generate_text(attrs)
  end

  def client do
    config()
    |> Keyword.get(:client, Minuteiro.AI.GeminiClient)
  end

  def config do
    Application.get_env(:minuteiro, __MODULE__, [])
  end
end
