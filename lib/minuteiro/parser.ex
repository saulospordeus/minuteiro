defmodule Minuteiro.Parser do
  @moduledoc """
  Parses the Minuteiro template language into a deterministic structure.
  """

  @conditional_open "[SE "
  @conditional_else "[SENAO]"
  @conditional_close "[FIM_SE]"

  @declaration_regex ~r/!@([[:alpha:]_][[:alnum:]_]*)(?:\[([^\]]+)\]|(\?))?/u
  @reference_regex ~r/(?:^|[^![:alnum:]_])@([[:alpha:]_][[:alnum:]_]*)/u
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
    case next_conditional_token(template) do
      :nomatch ->
        {:ok, append_text_segment(acc, template) |> Enum.reverse()}

      {@conditional_open, index} ->
        leading_text = binary_part(template, 0, index)
        conditional_start = binary_part(template, index, byte_size(template) - index)

        with {:ok, conditional_segment, rest} <- extract_conditional_segment(conditional_start) do
          updated_acc =
            acc
            |> append_text_segment(leading_text)
            |> prepend_segment(conditional_segment)

          parse_segments(rest, updated_acc)
        end

      {@conditional_else, _index} ->
        {:error, ["unexpected [SENAO] outside conditional block"]}

      {@conditional_close, _index} ->
        {:error, ["unexpected [FIM_SE] outside conditional block"]}
    end
  end

  defp extract_conditional_segment(template) do
    with {header_end, 1} <- :binary.match(template, "]"),
         {:ok, condition} <- parse_condition(binary_part(template, 4, header_end - 4)) do
      body_start = header_end + 1
      body_and_tail = binary_part(template, body_start, byte_size(template) - body_start)

      with {:ok, reverse_branches, else_content, rest} <-
             parse_conditional_branches(
               body_and_tail,
               [%{condition: condition, content: ""}],
               "",
               :branch
             ) do
        branches = Enum.reverse(reverse_branches)
        raw_length = byte_size(template) - byte_size(rest)
        raw = binary_part(template, 0, raw_length)

        {:ok, build_conditional_segment(branches, else_content, raw), rest}
      end
    else
      :nomatch -> {:error, ["conditional block is missing closing header bracket"]}
      {:error, _errors} = error -> error
    end
  end

  defp parse_conditional_branches(remaining, reverse_branches, else_content, mode) do
    case next_conditional_token(remaining) do
      :nomatch ->
        {:error, ["conditional block is missing [FIM_SE]"]}

      {@conditional_open, index} when mode == :branch ->
        leading_text = binary_part(remaining, 0, index)
        reverse_branches = append_branch_content(reverse_branches, leading_text)
        branch_start = binary_part(remaining, index, byte_size(remaining) - index)

        with {header_end, 1} <- :binary.match(branch_start, "]"),
             {:ok, condition} <- parse_condition(binary_part(branch_start, 4, header_end - 4)) do
          next_start = index + header_end + 1

          next_remaining =
            binary_part(remaining, next_start, byte_size(remaining) - next_start)

          parse_conditional_branches(
            next_remaining,
            [%{condition: condition, content: ""} | reverse_branches],
            else_content,
            :branch
          )
        else
          :nomatch -> {:error, ["conditional block is missing closing header bracket"]}
          {:error, _errors} = error -> error
        end

      {@conditional_open, _index} ->
        {:error, ["conditional branches after [SENAO] are not supported"]}

      {@conditional_else, index} when mode == :branch ->
        leading_text = binary_part(remaining, 0, index)
        reverse_branches = append_branch_content(reverse_branches, leading_text)
        next_start = index + byte_size(@conditional_else)

        next_remaining =
          binary_part(remaining, next_start, byte_size(remaining) - next_start)

        parse_conditional_branches(next_remaining, reverse_branches, "", :else)

      {@conditional_else, _index} ->
        {:error, ["conditional block can only contain one [SENAO]"]}

      {@conditional_close, index} ->
        leading_text = binary_part(remaining, 0, index)

        {reverse_branches, else_content} =
          case mode do
            :branch -> {append_branch_content(reverse_branches, leading_text), else_content}
            :else -> {reverse_branches, else_content <> leading_text}
          end

        rest_start = index + byte_size(@conditional_close)
        rest = binary_part(remaining, rest_start, byte_size(remaining) - rest_start)

        {:ok, reverse_branches, else_content, rest}
    end
  end

  defp parse_condition(condition_text) do
    condition_text = String.trim(condition_text)

    with {:ok, tokens} <- tokenize_condition(condition_text),
         {:ok, expression, []} <- parse_or_expression(tokens) do
      {:ok, expression}
    else
      _ -> {:error, ["invalid conditional expression: #{condition_text}"]}
    end
  end

  defp tokenize_condition(condition_text) do
    do_tokenize_condition(condition_text, [])
  end

  defp do_tokenize_condition(<<>>, acc), do: {:ok, Enum.reverse(acc)}

  defp do_tokenize_condition(remaining, acc) do
    cond do
      remaining =~ ~r/^\s+/u ->
        trimmed = String.replace_prefix(remaining, Regex.run(~r/^\s+/u, remaining) |> hd(), "")
        do_tokenize_condition(trimmed, acc)

      String.starts_with?(remaining, "&&") ->
        do_tokenize_condition(String.replace_prefix(remaining, "&&", ""), [
          {:logical_op, "&&"} | acc
        ])

      String.starts_with?(remaining, "||") ->
        do_tokenize_condition(String.replace_prefix(remaining, "||", ""), [
          {:logical_op, "||"} | acc
        ])

      String.starts_with?(remaining, ">=") ->
        do_tokenize_condition(String.replace_prefix(remaining, ">=", ""), [
          {:comparison_op, ">="} | acc
        ])

      String.starts_with?(remaining, "<=") ->
        do_tokenize_condition(String.replace_prefix(remaining, "<=", ""), [
          {:comparison_op, "<="} | acc
        ])

      String.starts_with?(remaining, "==") ->
        do_tokenize_condition(String.replace_prefix(remaining, "==", ""), [
          {:comparison_op, "=="} | acc
        ])

      String.starts_with?(remaining, "!=") ->
        do_tokenize_condition(String.replace_prefix(remaining, "!=", ""), [
          {:comparison_op, "!="} | acc
        ])

      String.starts_with?(remaining, ">") ->
        do_tokenize_condition(String.replace_prefix(remaining, ">", ""), [
          {:comparison_op, ">"} | acc
        ])

      String.starts_with?(remaining, "<") ->
        do_tokenize_condition(String.replace_prefix(remaining, "<", ""), [
          {:comparison_op, "<"} | acc
        ])

      String.starts_with?(remaining, "=") ->
        do_tokenize_condition(String.replace_prefix(remaining, "=", ""), [
          {:comparison_op, "="} | acc
        ])

      String.starts_with?(remaining, "(") ->
        do_tokenize_condition(String.replace_prefix(remaining, "(", ""), [{:paren, "("} | acc])

      String.starts_with?(remaining, ")") ->
        do_tokenize_condition(String.replace_prefix(remaining, ")", ""), [{:paren, ")"} | acc])

      String.starts_with?(remaining, "\"") ->
        with {:ok, value, rest} <- extract_quoted_literal(remaining, "\"") do
          do_tokenize_condition(rest, [{:operand, %{type: :literal, value: value}} | acc])
        end

      String.starts_with?(remaining, "'") ->
        with {:ok, value, rest} <- extract_quoted_literal(remaining, "'") do
          do_tokenize_condition(rest, [{:operand, %{type: :literal, value: value}} | acc])
        end

      variable_token = Regex.run(~r/^@([[:alpha:]_][[:alnum:]_]*)/u, remaining) ->
        [full_match, name] = variable_token

        rest = String.replace_prefix(remaining, full_match, "")
        do_tokenize_condition(rest, [{:operand, %{type: :variable, name: name}} | acc])

      bare_token = Regex.run(~r/^[^\s()&|<>=!]+/u, remaining) ->
        [full_match] = bare_token
        rest = String.replace_prefix(remaining, full_match, "")

        do_tokenize_condition(
          rest,
          [{:operand, %{type: :literal, value: parse_literal_value(full_match)}} | acc]
        )

      true ->
        {:error, :invalid_token}
    end
  end

  defp extract_quoted_literal(remaining, quote) do
    quote_size = byte_size(quote)
    content = binary_part(remaining, quote_size, byte_size(remaining) - quote_size)

    do_extract_quoted_literal(content, quote, [])
  end

  defp do_extract_quoted_literal(<<>>, _quote, _acc), do: {:error, :unterminated_string}

  defp do_extract_quoted_literal(<<?\\, escaped::utf8, rest::binary>>, quote, acc) do
    do_extract_quoted_literal(rest, quote, [<<escaped::utf8>> | acc])
  end

  defp do_extract_quoted_literal(remaining, quote, acc) do
    quote_size = byte_size(quote)

    if String.starts_with?(remaining, quote) do
      rest = binary_part(remaining, quote_size, byte_size(remaining) - quote_size)
      {:ok, acc |> Enum.reverse() |> IO.iodata_to_binary(), rest}
    else
      <<char::utf8, rest::binary>> = remaining
      do_extract_quoted_literal(rest, quote, [<<char::utf8>> | acc])
    end
  end

  defp parse_or_expression(tokens) do
    with {:ok, left, rest} <- parse_and_expression(tokens) do
      parse_logical_chain(rest, left, "||", &parse_and_expression/1)
    end
  end

  defp parse_and_expression(tokens) do
    with {:ok, left, rest} <- parse_boolean_term(tokens) do
      parse_logical_chain(rest, left, "&&", &parse_boolean_term/1)
    end
  end

  defp parse_logical_chain([{:logical_op, operator} | rest], left, operator, next_parser) do
    with {:ok, right, next_rest} <- next_parser.(rest) do
      parse_logical_chain(
        next_rest,
        %{type: :logical, operator: operator, left: left, right: right},
        operator,
        next_parser
      )
    end
  end

  defp parse_logical_chain(tokens, left, _operator, _next_parser), do: {:ok, left, tokens}

  defp parse_boolean_term([{:paren, "("} | rest]) do
    with {:ok, expression, [{:paren, ")"} | next_rest]} <- parse_or_expression(rest) do
      {:ok, expression, next_rest}
    else
      _ -> {:error, :unbalanced_parentheses}
    end
  end

  defp parse_boolean_term(tokens), do: parse_comparison_expression(tokens)

  defp parse_comparison_expression(tokens) do
    with {:ok, left, [{:comparison_op, operator} | rest]} <- parse_operand(tokens),
         {:ok, right, next_rest} <- parse_operand(rest) do
      {:ok,
       %{
         type: :comparison,
         operator: normalize_comparison_operator(operator),
         left: left,
         right: right
       }, next_rest}
    else
      _ -> {:error, :expected_comparison}
    end
  end

  defp parse_operand([{:operand, operand} | rest]), do: {:ok, operand, rest}
  defp parse_operand(_tokens), do: {:error, :expected_operand}

  defp normalize_comparison_operator("="), do: "=="
  defp normalize_comparison_operator(operator), do: operator

  defp parse_literal_value(raw_value) do
    normalized_value = String.trim(raw_value)

    cond do
      boolean_literal?(normalized_value) -> normalize_boolean_literal(normalized_value)
      integer_literal?(normalized_value) -> String.to_integer(normalized_value)
      float_literal?(normalized_value) -> String.to_float(normalized_value)
      true -> normalized_value
    end
  end

  defp boolean_literal?(value) do
    String.downcase(value) in ["true", "false", "verdadeiro", "falso", "sim", "nao", "não"]
  end

  defp normalize_boolean_literal(value) do
    String.downcase(value) in ["true", "verdadeiro", "sim"]
  end

  defp integer_literal?(value) do
    case Integer.parse(value) do
      {_integer, ""} -> true
      _ -> false
    end
  end

  defp float_literal?(value) do
    case Float.parse(value) do
      {_float, ""} -> String.contains?(value, ".")
      _ -> false
    end
  end

  defp build_conditional_segment([first_branch | _] = branches, else_content, raw) do
    %{
      type: :conditional,
      branches: branches,
      else_content: else_content,
      condition: first_branch.condition,
      truthy_content: first_branch.content,
      falsy_content: if(length(branches) == 1, do: else_content, else: ""),
      raw: raw
    }
  end

  defp extract_variables(template) do
    @declaration_regex
    |> Regex.scan(template)
    |> Enum.reduce([], fn [declaration, name | _rest], variables ->
      if Enum.any?(variables, &(&1.name == name)) do
        variables
      else
        variables ++ [build_variable(name, declaration)]
      end
    end)
  end

  defp build_variable(name, declaration) when is_binary(declaration) do
    declaration = String.trim(declaration)

    cond do
      String.ends_with?(declaration, "?") ->
        boolean_variable(name)

      String.contains?(declaration, "[") ->
        declaration
        |> extract_declaration_config()
        |> build_variable_from_config(name)

      true ->
        %{name: name, type: "texto", raw_options: nil, options: []}
    end
  end

  defp boolean_variable(name) do
    %{name: name, type: "booleano", raw_options: nil, options: []}
  end

  defp extract_declaration_config(declaration) do
    declaration
    |> String.split("[", parts: 2)
    |> List.last()
    |> String.trim_trailing("]")
  end

  defp build_variable_from_config(config, name) do
    case String.split(config, ":", parts: 2) do
      [type] ->
        normalized_type = normalize_type(type)

        build_variable_without_options(normalized_type, name)

      [type, raw_options] ->
        normalized_type = normalize_type(type)
        raw_options = String.trim(raw_options)

        build_variable_with_options(normalized_type, name, raw_options)
    end
  end

  defp build_variable_without_options("booleano", name), do: boolean_variable(name)

  defp build_variable_without_options("ia", name) do
    %{name: name, type: "ia", prompt: "", raw_options: nil, options: []}
  end

  defp build_variable_without_options(type, name) do
    %{name: name, type: type, raw_options: nil, options: []}
  end

  defp build_variable_with_options("ia", name, prompt) do
    %{name: name, type: "ia", prompt: prompt, raw_options: prompt, options: []}
  end

  defp build_variable_with_options(type, name, raw_options) do
    %{
      name: name,
      type: type,
      raw_options: raw_options,
      options: split_options(raw_options)
    }
  end

  defp normalize_type(type) do
    case String.trim(type) do
      "booleana" -> "booleano"
      normalized_type -> normalized_type
    end
  end

  defp split_options(raw_options) do
    raw_options
    |> String.split(~r/\s*[;\|,]\s*/u, trim: true)
  end

  defp extract_references(segments) do
    references =
      Enum.reduce(segments, [], fn segment, acc ->
        case segment do
          %{type: :text, content: content} ->
            acc ++ references_in_text(content)

          %{type: :conditional, branches: branches, else_content: else_content} ->
            acc ++
              Enum.flat_map(branches, fn %{condition: condition, content: content} ->
                references_in_condition(condition) ++ references_in_text(content)
              end) ++ references_in_text(else_content)

          %{
            type: :conditional,
            condition: condition,
            truthy_content: truthy,
            falsy_content: falsy
          } ->
            acc ++
              references_in_condition(condition) ++
              references_in_text(truthy) ++ references_in_text(falsy)
        end
      end)

    {:ok, Enum.uniq(references)}
  end

  defp references_in_text(text) do
    @reference_regex
    |> Regex.scan(text, capture: :all_but_first)
    |> List.flatten()
  end

  defp references_in_condition(%{type: :logical, left: left, right: right}) do
    references_in_condition(left) ++ references_in_condition(right)
  end

  defp references_in_condition(%{type: :comparison, left: left, right: right}) do
    references_in_operand(left) ++ references_in_operand(right)
  end

  defp references_in_operand(%{type: :variable, name: name}), do: [name]
  defp references_in_operand(%{type: :literal}), do: []

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

  defp append_branch_content([current_branch | rest], content) do
    [%{current_branch | content: current_branch.content <> content} | rest]
  end

  defp next_conditional_token(template) do
    [@conditional_open, @conditional_else, @conditional_close]
    |> Enum.reduce([], fn token, matches ->
      case :binary.match(template, token) do
        :nomatch -> matches
        {index, _length} -> [{token, index} | matches]
      end
    end)
    |> case do
      [] -> :nomatch
      matches -> Enum.min_by(matches, &elem(&1, 1))
    end
  end

  defp prepend_segment(acc, segment), do: [segment | acc]
end
