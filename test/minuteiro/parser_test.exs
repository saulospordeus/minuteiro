defmodule Minuteiro.ParserTest do
  use ExUnit.Case, async: true

  alias Minuteiro.Parser

  test "parse/1 extracts variables, references and top-level conditionals" do
    template = """
    !@nome[texto]
    !@estado[lista:SP|RJ|MG]

    [SE @estado = SP]Ola @nome[SENAO]Tchau @nome[FIM_SE]
    """

    assert {:ok, parsed} = Parser.parse(template)

    assert parsed.variables == [
             %{name: "nome", type: "texto", raw_options: nil, options: []},
             %{
               name: "estado",
               type: "lista",
               raw_options: "SP|RJ|MG",
               options: ["SP", "RJ", "MG"]
             }
           ]

    assert parsed.references == ["estado", "nome"]
    assert length(parsed.conditionals) == 1

    assert [%{condition: condition, truthy_content: truthy_content, falsy_content: falsy_content}] =
             parsed.conditionals

    assert condition == %{variable: "estado", operator: "=", value: "SP"}
    assert truthy_content == "Ola @nome"
    assert falsy_content == "Tchau @nome"
  end

  test "parse/1 keeps multiple top-level segments in order" do
    template = "Inicio [SE @ativo = sim]meio[SENAO]fim[FIM_SE] encerramento"

    assert {:ok, parsed} = Parser.parse(template)

    assert parsed.segments == [
             %{type: :text, content: "Inicio "},
             %{
               type: :conditional,
               condition: %{variable: "ativo", operator: "=", value: "sim"},
               truthy_content: "meio",
               falsy_content: "fim",
               raw: "[SE @ativo = sim]meio[SENAO]fim[FIM_SE]"
             },
             %{type: :text, content: " encerramento"}
           ]
  end

  test "parse/1 rejects nested conditionals" do
    template = "[SE @a = sim]antes [SE @b = sim]durante[FIM_SE] depois[FIM_SE]"

    assert {:error, ["nested conditionals are not supported in V1"]} = Parser.parse(template)
  end

  test "parse/1 rejects invalid conditional expressions" do
    template = "[SE invalido]conteudo[FIM_SE]"

    assert {:error, ["invalid conditional expression: invalido"]} = Parser.parse(template)
  end
end
