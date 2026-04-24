defmodule Minuteiro.Compiler do
  @moduledoc """
  Compiles parsed Minuteiro templates into final document text.
  """

  alias Minuteiro.Parser

  @declaration_line_regex ~r/^[ \t]*!@[[:alpha:]_][[:alnum:]_]*(?:\[[^\]]+\]|\?)?[ \t]*\r?\n?/mu
  @declaration_regex ~r/!@[[:alpha:]_][[:alnum:]_]*(?:\[[^\]]+\]|\?)?/u
  @reference_replace_regex ~r/(^|[^[:alnum:]_])@([[:alpha:]_][[:alnum:]_]*)/u

  def active_content(parsed_template, answers \\ %{})
      when is_map(parsed_template) and is_map(answers) do
    parsed_template.segments
    |> Enum.map_join(&select_segment_content(&1, answers))
  end

  def compile(parsed_template, answers \\ %{}) when is_map(parsed_template) and is_map(answers) do
    parsed_template
    |> active_content(answers)
    |> remove_declarations()
    |> inject_answers(answers)
    |> normalize_output()
  end

  def compile_template(template, answers \\ %{}) when is_binary(template) and is_map(answers) do
    with {:ok, parsed_template} <- Parser.parse(template) do
      {:ok, compile(parsed_template, answers)}
    end
  end

  defp select_segment_content(%{type: :text, content: content}, _answers) do
    content
  end

  defp select_segment_content(%{type: :conditional, branches: branches} = segment, answers) do
    case Enum.find(branches, &condition_matches?(&1.condition, answers)) do
      nil -> Map.get(segment, :else_content, "")
      branch -> branch.content
    end
  end

  defp select_segment_content(%{type: :conditional, condition: condition} = segment, answers) do
    if condition_matches?(condition, answers) do
      segment.truthy_content
    else
      segment.falsy_content
    end
  end

  defp remove_declarations(content) do
    content
    |> String.replace(@declaration_line_regex, "")
    |> String.replace(@declaration_regex, "")
  end

  defp inject_answers(content, answers) do
    Regex.replace(@reference_replace_regex, content, fn _full_match, prefix, name ->
      prefix <> answer_to_string(fetch_answer(answers, name))
    end)
  end

  defp fetch_answer(answers, name) do
    Enum.find_value(answers, "", fn {key, value} ->
      if to_string(key) == name, do: value
    end)
  end

  defp condition_matches?(%{type: :logical, operator: "&&", left: left, right: right}, answers) do
    evaluate_condition(left, answers) and evaluate_condition(right, answers)
  end

  defp condition_matches?(%{type: :logical, operator: "||", left: left, right: right}, answers) do
    evaluate_condition(left, answers) or evaluate_condition(right, answers)
  end

  defp condition_matches?(%{type: :comparison} = condition, answers) do
    evaluate_condition(condition, answers)
  end

  defp evaluate_condition(%{type: :logical, operator: "&&", left: left, right: right}, answers) do
    evaluate_condition(left, answers) and evaluate_condition(right, answers)
  end

  defp evaluate_condition(%{type: :logical, operator: "||", left: left, right: right}, answers) do
    evaluate_condition(left, answers) or evaluate_condition(right, answers)
  end

  defp evaluate_condition(
         %{type: :comparison, operator: operator, left: left, right: right},
         answers
       ) do
    compare_values(resolve_operand(left, answers), resolve_operand(right, answers), operator)
  end

  defp resolve_operand(%{type: :variable, name: name}, answers) do
    fetch_answer(answers, name)
  end

  defp resolve_operand(%{type: :literal, value: value}, _answers), do: value

  defp compare_values(left, right, operator) when is_list(left) do
    case operator do
      "==" -> Enum.any?(left, &compare_values(&1, right, "=="))
      "!=" -> Enum.all?(left, &compare_values(&1, right, "!="))
      _ -> false
    end
  end

  defp compare_values(left, right, operator) when is_list(right) do
    case operator do
      "==" -> Enum.any?(right, &compare_values(left, &1, "=="))
      "!=" -> Enum.all?(right, &compare_values(left, &1, "!="))
      _ -> false
    end
  end

  defp compare_values(left, right, operator) do
    case comparable_pair(left, right) do
      {{:number, left_number}, {:number, right_number}} ->
        apply_comparison(left_number, right_number, operator)

      {{:boolean, left_boolean}, {:boolean, right_boolean}} ->
        apply_comparison(left_boolean, right_boolean, operator)

      {{:string, left_string}, {:string, right_string}} ->
        apply_comparison(left_string, right_string, operator)

      _ ->
        false
    end
  end

  defp comparable_pair(left, right) do
    {normalize_comparable_value(left), normalize_comparable_value(right)}
  end

  defp normalize_comparable_value(value) when is_binary(value) do
    trimmed_value = String.trim(value)

    cond do
      boolean_string?(trimmed_value) -> {:boolean, normalize_boolean_string(trimmed_value)}
      integer_string?(trimmed_value) -> {:number, String.to_integer(trimmed_value)}
      float_string?(trimmed_value) -> {:number, String.to_float(trimmed_value)}
      true -> {:string, String.downcase(trimmed_value)}
    end
  end

  defp normalize_comparable_value(value) when is_integer(value) or is_float(value),
    do: {:number, value}

  defp normalize_comparable_value(value) when is_boolean(value),
    do: {:boolean, value}

  defp normalize_comparable_value(nil), do: {:string, ""}

  defp normalize_comparable_value(value) do
    value
    |> answer_to_string()
    |> normalize_comparable_value()
  end

  defp apply_comparison(left, right, "=="), do: left == right
  defp apply_comparison(left, right, "!="), do: left != right
  defp apply_comparison(left, right, ">"), do: left > right
  defp apply_comparison(left, right, "<"), do: left < right
  defp apply_comparison(left, right, ">="), do: left >= right
  defp apply_comparison(left, right, "<="), do: left <= right

  defp boolean_string?(value) do
    String.downcase(value) in [
      "true",
      "false",
      "verdadeiro",
      "falso",
      "sim",
      "nao",
      "não",
      "1",
      "0"
    ]
  end

  defp normalize_boolean_string(value) do
    String.downcase(value) in ["true", "verdadeiro", "sim", "1"]
  end

  defp integer_string?(value) do
    case Integer.parse(value) do
      {_integer, ""} -> true
      _ -> false
    end
  end

  defp float_string?(value) do
    case Float.parse(value) do
      {_float, ""} -> String.contains?(value, ".")
      _ -> false
    end
  end

  defp answer_to_string(nil), do: ""
  defp answer_to_string(true), do: "true"
  defp answer_to_string(false), do: "false"

  defp answer_to_string(value) when is_list(value),
    do: Enum.map_join(value, ", ", &answer_to_string/1)

  defp answer_to_string(value), do: to_string(value)

  defp normalize_output(content) do
    content
    |> String.replace(~r/[ \t]+\n/u, "\n")
    |> String.replace(~r/\n{3,}/u, "\n\n")
    |> String.trim()
  end
end
