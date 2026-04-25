defmodule Minuteiro.AI.GeminiClient do
  @moduledoc false

  @behaviour Minuteiro.AI.Client

  @impl true
  def generate_text(%{prompt: prompt} = attrs) when is_binary(prompt) do
    config = Minuteiro.AI.config()
    api_key = Keyword.get(config, :api_key, "")

    if blank?(api_key) do
      {:error, "API de IA nao configurada. Defina GEMINI_API_KEY para habilitar a geracao."}
    else
      url = build_url(config, api_key)

      case Req.post(
             url: url,
             json: build_payload(attrs),
             receive_timeout: Keyword.get(config, :timeout_ms, 30_000)
           ) do
        {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
          extract_generated_text(body)

        {:ok, %Req.Response{status: status, body: body}} ->
          {:error, api_error_message(status, body)}

        {:error, %Req.TransportError{reason: :timeout}} ->
          {:error, "A geracao com IA excedeu o tempo limite. Tente novamente."}

        {:error, error} ->
          {:error, "Nao foi possivel gerar o texto com IA: #{inspect(error)}"}
      end
    end
  end

  def generate_text(_attrs) do
    {:error, "Instrucao de IA invalida."}
  end

  defp build_url(config, api_key) do
    base_url = Keyword.get(config, :base_url, "https://generativelanguage.googleapis.com/v1beta")
    model = Keyword.get(config, :model, "gemini-2.0-flash")

    "#{String.trim_trailing(base_url, "/")}/models/#{model}:generateContent?key=#{api_key}"
  end

  defp build_payload(attrs) do
    %{
      contents: [
        %{
          parts: [
            %{
              text: request_text(attrs)
            }
          ]
        }
      ]
    }
  end

  defp request_text(attrs) do
    context = Map.get(attrs, :context, "")
    prompt = Map.get(attrs, :prompt, "")

    [
      if(blank?(context), do: nil, else: "Contexto global:\n#{String.trim(context)}"),
      "Instrucao:\n#{String.trim(prompt)}"
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n\n")
  end

  defp extract_generated_text(%{"candidates" => candidates}) when is_list(candidates) do
    generated_text =
      candidates
      |> Enum.find_value(&candidate_text/1)
      |> to_string()
      |> String.trim()

    if generated_text == "" do
      {:error, "A IA nao retornou texto para esta solicitacao."}
    else
      {:ok, generated_text}
    end
  end

  defp extract_generated_text(_body) do
    {:error, "Resposta invalida recebida da API de IA."}
  end

  defp candidate_text(%{"content" => %{"parts" => parts}}) when is_list(parts) do
    Enum.map_join(parts, "", fn
      %{"text" => text} -> text
      _part -> ""
    end)
  end

  defp candidate_text(_candidate), do: nil

  defp api_error_message(status, %{"error" => %{"message" => message}}) when is_binary(message) do
    "A API de IA respondeu com erro (#{status}): #{message}"
  end

  defp api_error_message(status, _body) do
    "A API de IA respondeu com erro (#{status})."
  end

  defp blank?(value) do
    String.trim(to_string(value)) == ""
  end
end
