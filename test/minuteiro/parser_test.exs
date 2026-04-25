defmodule Minuteiro.ParserTest do
  use ExUnit.Case, async: true

  alias Minuteiro.Parser

  test "parse/1 extracts variables, references and top-level conditionals" do
    template = """
    !@nome
    !@estado[lista:SP;RJ;MG]

    [SE @estado = SP]Ola @nome[SENAO]Tchau @nome[FIM_SE]
    """

    assert {:ok, parsed} = Parser.parse(template)

    assert parsed.variables == [
             %{name: "nome", type: "texto", raw_options: nil, options: []},
             %{
               name: "estado",
               type: "lista",
               raw_options: "SP;RJ;MG",
               options: ["SP", "RJ", "MG"]
             }
           ]

    assert parsed.references == ["estado", "nome"]
    assert length(parsed.conditionals) == 1

    assert [%{condition: condition, truthy_content: truthy_content, falsy_content: falsy_content}] =
             parsed.conditionals

    assert condition == %{
             type: :comparison,
             operator: "==",
             left: %{type: :variable, name: "estado"},
             right: %{type: :literal, value: "SP"}
           }

    assert truthy_content == "Ola @nome"
    assert falsy_content == "Tchau @nome"
  end

  test "parse/1 respects comparison and logical precedence inside conditionals" do
    template = ~s([SE @idade > 18 && @tipo == "civil" || @admin == true]ok[FIM_SE])

    assert {:ok, parsed} = Parser.parse(template)

    assert [%{condition: condition}] = parsed.conditionals

    assert condition == %{
             type: :logical,
             operator: "||",
             left: %{
               type: :logical,
               operator: "&&",
               left: %{
                 type: :comparison,
                 operator: ">",
                 left: %{type: :variable, name: "idade"},
                 right: %{type: :literal, value: 18}
               },
               right: %{
                 type: :comparison,
                 operator: "==",
                 left: %{type: :variable, name: "tipo"},
                 right: %{type: :literal, value: "civil"}
               }
             },
             right: %{
               type: :comparison,
               operator: "==",
               left: %{type: :variable, name: "admin"},
               right: %{type: :literal, value: true}
             }
           }

    assert parsed.references == ["idade", "tipo", "admin"]
  end

  test "parse/1 defaults declarations without explicit type to texto" do
    assert {:ok, parsed} = Parser.parse("!@cliente\nContrato com @cliente")

    assert parsed.variables == [
             %{name: "cliente", type: "texto", raw_options: nil, options: []}
           ]
  end

  test "parse/1 accepts boolean declarations with booleana and question mark syntaxes" do
    template = "!@aprovado[booleana]\n!@assinado?"

    assert {:ok, parsed} = Parser.parse(template)

    assert parsed.variables == [
             %{name: "aprovado", type: "booleano", raw_options: nil, options: []},
             %{name: "assinado", type: "booleano", raw_options: nil, options: []}
           ]
  end

  test "parse/1 extracts ia declarations with the full prompt text" do
    template =
      "!@fundamentacao[ia: Redija a fundamentacao com base no contexto bruto.]\n@fundamentacao"

    assert {:ok, parsed} = Parser.parse(template)

    assert parsed.variables == [
             %{
               name: "fundamentacao",
               type: "ia",
               prompt: "Redija a fundamentacao com base no contexto bruto.",
               raw_options: "Redija a fundamentacao com base no contexto bruto.",
               options: []
             }
           ]

    assert parsed.references == ["fundamentacao"]
  end

  test "parse/1 keeps multiple top-level segments in order" do
    template = "Inicio [SE @ativo = sim]meio[SENAO]fim[FIM_SE] encerramento"

    assert {:ok, parsed} = Parser.parse(template)

    assert parsed.segments == [
             %{type: :text, content: "Inicio "},
             %{
               type: :conditional,
               branches: [
                 %{
                   condition: %{
                     type: :comparison,
                     operator: "==",
                     left: %{type: :variable, name: "ativo"},
                     right: %{type: :literal, value: true}
                   },
                   content: "meio"
                 }
               ],
               condition: %{
                 type: :comparison,
                 operator: "==",
                 left: %{type: :variable, name: "ativo"},
                 right: %{type: :literal, value: true}
               },
               else_content: "fim",
               truthy_content: "meio",
               falsy_content: "fim",
               raw: "[SE @ativo = sim]meio[SENAO]fim[FIM_SE]"
             },
             %{type: :text, content: " encerramento"}
           ]
  end

  test "parse/1 supports chained conditional branches in the same block" do
    template =
      "[SE @idade < 16]absolutamente incapaz[SE @idade >= 16 && @idade < 18]relativamente incapaz[SE @idade > 65]idoso[SENAO]plenamente capaz[FIM_SE]"

    assert {:ok, parsed} = Parser.parse(template)

    assert [conditional] = parsed.conditionals
    assert conditional.else_content == "plenamente capaz"

    assert conditional.branches == [
             %{
               condition: %{
                 type: :comparison,
                 operator: "<",
                 left: %{type: :variable, name: "idade"},
                 right: %{type: :literal, value: 16}
               },
               content: "absolutamente incapaz"
             },
             %{
               condition: %{
                 type: :logical,
                 operator: "&&",
                 left: %{
                   type: :comparison,
                   operator: ">=",
                   left: %{type: :variable, name: "idade"},
                   right: %{type: :literal, value: 16}
                 },
                 right: %{
                   type: :comparison,
                   operator: "<",
                   left: %{type: :variable, name: "idade"},
                   right: %{type: :literal, value: 18}
                 }
               },
               content: "relativamente incapaz"
             },
             %{
               condition: %{
                 type: :comparison,
                 operator: ">",
                 left: %{type: :variable, name: "idade"},
                 right: %{type: :literal, value: 65}
               },
               content: "idoso"
             }
           ]

    assert parsed.references == ["idade"]
  end

  test "parse/1 keeps compatibility with persisted list options separated by pipe" do
    template = "!@estado[lista:SP|RJ|MG]"

    assert {:ok, parsed} = Parser.parse(template)

    assert parsed.variables == [
             %{
               name: "estado",
               type: "lista",
               raw_options: "SP|RJ|MG",
               options: ["SP", "RJ", "MG"]
             }
           ]
  end

  test "parse/1 rejects multiple else branches in the same block" do
    template = "[SE @a = sim]antes[SENAO]meio[SENAO]fim[FIM_SE]"

    assert {:error, ["conditional block can only contain one [SENAO]"]} = Parser.parse(template)
  end

  test "parse/1 rejects invalid conditional expressions" do
    template = "[SE invalido]conteudo[FIM_SE]"

    assert {:error, ["invalid conditional expression: invalido"]} = Parser.parse(template)
  end
end
