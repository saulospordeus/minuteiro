defmodule Minuteiro.Parser do
  @moduledoc """
  Parses the Minuteiro template language into a deterministic structure.
  """

  @conditional_open "[SE "
  @conditional_else "[SENAO]"
  @conditional_close "[FIM_SE]"

  @declaration_regex ~r/!@([[:alpha:]_][[:alnum:]_]*)\[([^\]]+)\]/u
  @reference_regex ~r/(?:^|[^![:alnum:]_])@([[:alpha:]_][[:alnum:]_]*)/u
  @condition_regex ~r/^@([[:alpha:]_][[:alnum:]_]*)\s*=\s*(.+)$/u

  def parse(template) when is_binary(template) do
    with {:ok, segments} <- parse_segments(template, []),
         {:ok, references} <- extract_references(segments) do
      {:ok,
       %{
         source: template,
         segments: segments,
         variables: extract_variables(template),
         references: references,
         conditionals: extract_conditionals(segments)
       }}
    end
  end

  defp parse_segments(template, acc) do
    case :binary.match(template, @conditional_open) do
      :nomatch ->
        {:ok, append_text_segment(acc, template) |> Enum.reverse()}

      {index, _length} ->
        leading_text = binary_part(template, 0, index)
        conditional_start = binary_part(template, index, byte_size(template) - index)

        with {:ok, conditional_segment, rest} <- extract_conditional_segment(conditional_start) do
          updated_acc =
            acc
            |> append_text_segment(leading_text)
            |> prepend_segment(conditional_segment)

          parse_segments(rest, updated_acc)
        end
    end
  end

  # Conditional parsing stays linear on purpose because nested conditionals
  # are out of scope in V1 and should fail fast instead of being guessed.
  defp extract_conditional_segment(template) do
    with {header_end, 1} <- :binary.match(template, "]"),
         {:ok, condition} <- parse_condition(binary_part(template, 4, header_end - 4)) do
      body_start = header_end + 1
      body_and_tail = binary_part(template, body_start, byte_size(template) - body_start)

      case :binary.match(body_and_tail, @conditional_close) do
        :nomatch ->
          {:error, ["conditional block is missing [FIM_SE]"]}

        {close_index, _length} ->
          block_body = binary_part(body_and_tail, 0, close_index)
          rest_start = close_index + byte_size(@conditional_close)
          rest = binary_part(body_and_tail, rest_start, byte_size(body_and_tail) - rest_start)

          if String.contains?(block_body, @conditional_open) do
            {:error, ["nested conditionals are not supported in V1"]}
          else
            {truthy_content, falsy_content} = split_conditional_body(block_body)

            raw_length = body_start + close_index + byte_size(@conditional_close)
            raw = binary_part(template, 0, raw_length)

            {:ok,
             %{
               type: :conditional,
               condition: condition,
               truthy_content: truthy_content,
               falsy_content: falsy_content,
               raw: raw
             }, rest}
          end
      end
    else
      :nomatch -> {:error, ["conditional block is missing closing header bracket"]}
      {:error, _errors} = error -> error
    end
  end

  defp parse_condition(condition_text) do
    condition_text = String.trim(condition_text)

    case Regex.run(@condition_regex, condition_text, capture: :all_but_first) do
      [variable, expected_value] ->
        {:ok, %{variable: variable, operator: "=", value: String.trim(expected_value)}}

      _ ->
        {:error, ["invalid conditional expression: #{condition_text}"]}
    end
  end

  defp split_conditional_body(block_body) do
    case :binary.match(block_body, @conditional_else) do
      :nomatch ->
        {block_body, ""}

      {else_index, _length} ->
        truthy_content = binary_part(block_body, 0, else_index)

        falsy_start = else_index + byte_size(@conditional_else)

        falsy_content =
          binary_part(block_body, falsy_start, byte_size(block_body) - falsy_start)

        {truthy_content, falsy_content}
    end
  end

  defp extract_variables(template) do
    @declaration_regex
    |> Regex.scan(template, capture: :all_but_first)
    |> Enum.reduce([], fn [name, config], variables ->
      if Enum.any?(variables, &(&1.name == name)) do
        variables
      else
        variables ++ [build_variable(name, config)]
      end
    end)
  end

  defp build_variable(name, config) do
    case String.split(config, ":", parts: 2) do
      [type] ->
        %{name: name, type: String.trim(type), raw_options: nil, options: []}

      [type, raw_options] ->
        raw_options = String.trim(raw_options)

        %{
          name: name,
          type: String.trim(type),
          raw_options: raw_options,
          options: split_options(raw_options)
        }
    end
  end

  defp split_options(raw_options) do
    raw_options
    |> String.split(~r/\s*[\|,]\s*/u, trim: true)
  end

  defp extract_references(segments) do
    references =
      Enum.reduce(segments, [], fn segment, acc ->
        case segment do
          %{type: :text, content: content} ->
            acc ++ references_in_text(content)

          %{
            type: :conditional,
            condition: condition,
            truthy_content: truthy,
            falsy_content: falsy
          } ->
            acc ++ [condition.variable] ++ references_in_text(truthy) ++ references_in_text(falsy)
        end
      end)

    {:ok, Enum.uniq(references)}
  end

  defp references_in_text(text) do
    @reference_regex
    |> Regex.scan(text, capture: :all_but_first)
    |> List.flatten()
  end

  defp extract_conditionals(segments) do
    Enum.flat_map(segments, fn
      %{type: :conditional} = conditional -> [conditional]
      _segment -> []
    end)
  end

  defp append_text_segment(acc, ""), do: acc

  defp append_text_segment(acc, text) do
    prepend_segment(acc, %{type: :text, content: text})
  end

  defp prepend_segment(acc, segment), do: [segment | acc]
end
