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

  defp condition_matches?(%{variable: variable, value: expected_value}, answers) do
    actual_value = fetch_answer(answers, variable)
    expected_value = normalize_condition_value(expected_value)

    cond do
      is_boolean(actual_value) ->
        boolean_matches?(actual_value, expected_value)

      is_list(actual_value) ->
        Enum.any?(actual_value, &(normalize_condition_value(&1) == expected_value))

      true ->
        normalize_condition_value(actual_value) == expected_value
    end
  end

  defp boolean_matches?(true, expected_value),
    do: expected_value in ["true", "verdadeiro", "sim", "1"]

  defp boolean_matches?(false, expected_value),
    do: expected_value in ["false", "falso", "nao", "não", "0"]

  defp normalize_condition_value(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.downcase()
  end

  defp normalize_condition_value(value),
    do: value |> answer_to_string() |> normalize_condition_value()

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
