defmodule Minuteiro.AI.TestClient do
  @moduledoc false

  @behaviour Minuteiro.AI.Client

  @impl true
  def generate_text(%{context: context, prompt: prompt}) do
    cond do
      String.contains?(prompt, "[force_error]") ->
        {:error, "Falha simulada da IA para testes."}

      String.contains?(prompt, "[slow]") ->
        Process.sleep(25)
        {:ok, build_response(context, prompt)}

      true ->
        {:ok, build_response(context, prompt)}
    end
  end

  defp build_response(context, prompt) do
    context = String.trim(context || "")
    prompt = String.trim(prompt || "")

    if context == "" do
      "Resposta IA: #{prompt}"
    else
      "Resposta IA: #{prompt}\n\nContexto: #{context}"
    end
  end
end
