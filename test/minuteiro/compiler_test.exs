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

  test "compile/2 compares numeric values against literals" do
    template = "[SE @idade > 18]Maior de idade[SENAO]Menor de idade[FIM_SE]"

    assert {:ok, parsed} = Parser.parse(template)

    assert Compiler.compile(parsed, %{idade: "21"}) == "Maior de idade"
    assert Compiler.compile(parsed, %{idade: 16}) == "Menor de idade"
  end

  test "compile/2 compares one variable against another" do
    template = "[SE @valor_pago < @valor_devido]Saldo pendente[SENAO]Quitado[FIM_SE]"

    assert {:ok, parsed} = Parser.parse(template)

    assert Compiler.compile(parsed, %{valor_pago: "50", valor_devido: "100"}) == "Saldo pendente"
    assert Compiler.compile(parsed, %{valor_pago: 100, valor_devido: 100}) == "Quitado"
  end

  test "compile/2 respects logical precedence in composite expressions" do
    template =
      ~s([SE @idade > 18 && @tipo == "civil" || @admin == true]Permitido[SENAO]Negado[FIM_SE])

    assert {:ok, parsed} = Parser.parse(template)

    assert Compiler.compile(parsed, %{idade: 20, tipo: "civil", admin: false}) == "Permitido"
    assert Compiler.compile(parsed, %{idade: 20, tipo: "penal", admin: false}) == "Negado"
    assert Compiler.compile(parsed, %{idade: 16, tipo: "penal", admin: true}) == "Permitido"
  end

  test "compile/2 handles boolean answers in conditions" do
    template = "[SE @ativo = sim]Ativo[SENAO]Inativo[FIM_SE]"

    assert {:ok, parsed} = Parser.parse(template)

    assert Compiler.compile(parsed, %{ativo: true}) == "Ativo"
    assert Compiler.compile(parsed, %{ativo: false}) == "Inativo"
  end

  test "compile/2 resolves the first matching branch in chained conditionals" do
    template =
      "[SE @idade < 16]absolutamente incapaz[SE @idade >= 16 && @idade < 18]relativamente incapaz[SE @idade > 65]idoso[SENAO]plenamente capaz[FIM_SE]"

    assert {:ok, parsed} = Parser.parse(template)

    assert Compiler.compile(parsed, %{idade: 14}) == "absolutamente incapaz"
    assert Compiler.compile(parsed, %{idade: 17}) == "relativamente incapaz"
    assert Compiler.compile(parsed, %{idade: 70}) == "idoso"
    assert Compiler.compile(parsed, %{idade: 30}) == "plenamente capaz"
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
    template = "[SE @a = sim]antes[SENAO]meio[SENAO]fim[FIM_SE]"

    assert {:error, ["conditional block can only contain one [SENAO]"]} =
             Compiler.compile_template(template, %{})
  end
end
