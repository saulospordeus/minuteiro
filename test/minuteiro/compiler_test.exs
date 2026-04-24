defmodule Minuteiro.CompilerTest do
  use ExUnit.Case, async: true

  alias Minuteiro.Compiler
  alias Minuteiro.Parser

  test "compile/2 removes declarations and injects answers" do
    template = """
    !@nome
    !@cidade[texto]

    Ola, @nome.
    Bem-vindo a @cidade.
    """

    assert {:ok, parsed} = Parser.parse(template)

    assert Compiler.compile(parsed, %{nome: "Saulo", cidade: "Recife"}) ==
             "Ola, Saulo.\nBem-vindo a Recife."
  end

  test "compile/2 resolves truthy conditional branch" do
    template = "[SE @estado = SP]Capital paulista[SENAO]Outro estado[FIM_SE]"

    assert {:ok, parsed} = Parser.parse(template)

    assert Compiler.compile(parsed, %{estado: "SP"}) == "Capital paulista"
  end

  test "compile/2 resolves falsy conditional branch" do
    template = "[SE @estado = SP]Capital paulista[SENAO]Outro estado[FIM_SE]"

    assert {:ok, parsed} = Parser.parse(template)

    assert Compiler.compile(parsed, %{estado: "RJ"}) == "Outro estado"
  end

  test "compile/2 handles boolean answers in conditions" do
    template = "[SE @ativo = sim]Ativo[SENAO]Inativo[FIM_SE]"

    assert {:ok, parsed} = Parser.parse(template)

    assert Compiler.compile(parsed, %{ativo: true}) == "Ativo"
    assert Compiler.compile(parsed, %{ativo: false}) == "Inativo"
  end

  test "compile/2 removes shorthand boolean declarations" do
    template = "!@ativo?\n[SE @ativo = sim]Ativo[FIM_SE]"

    assert {:ok, parsed} = Parser.parse(template)

    assert Compiler.compile(parsed, %{ativo: true}) == "Ativo"
  end

  test "compile/2 replaces missing answers with empty strings" do
    template = "!@nome\nAssinado por @nome"

    assert {:ok, parsed} = Parser.parse(template)

    assert Compiler.compile(parsed, %{}) == "Assinado por"
  end

  test "compile_template/2 compiles directly from source" do
    template = "!@nome\n[SE @ativo = true]@nome[FIM_SE]"

    assert {:ok, "Maria"} =
             Compiler.compile_template(template, %{"nome" => "Maria", "ativo" => true})
  end

  test "compile_template/2 returns parser errors" do
    template = "[SE @a = sim]antes [SE @b = sim]durante[FIM_SE] depois[FIM_SE]"

    assert {:error, ["nested conditionals are not supported in V1"]} =
             Compiler.compile_template(template, %{})
  end
end
