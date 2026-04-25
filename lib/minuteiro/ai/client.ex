defmodule Minuteiro.AI.Client do
  @moduledoc false

  @callback generate_text(map()) :: {:ok, String.t()} | {:error, String.t()}
end
