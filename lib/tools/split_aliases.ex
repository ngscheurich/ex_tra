defmodule SplitAliases do
  @moduledoc """
  Splits multi-alias curly brace notation into single-line aliases.

  ## Examples

      iex> SplitAliases.main("alias Foo.{\\nBar.Baz,\\nQuux\\n}")
      {:ok, "alias Foo.Bar.Baz\\nalias Foo.Quux"}

      iex> SplitAliases.main("alias MyApp.Stuff.Things.{\\n    One,\\n    Two,\\n    Three\\n  }")
      {:ok, "alias MyApp.Stuff.Things.One\\nalias MyApp.Stuff.Things.Two\\nalias MyApp.Stuff.Things.Three"}
  """

  def main([arg]), do: main(arg)

  def main(arg) when is_binary(arg) do
    case Code.string_to_quoted(arg) do
      {:ok, ast} ->
        split_ast(ast)
        |> extract_aliases()
        |> Enum.map(&alias_node_to_string/1)
        |> Enum.join("\n")
        |> then(&{:ok, &1})

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp alias_node_to_string({:alias, _, [{:__aliases__, _, modules}]}) when is_list(modules) do
    "alias " <> Enum.map_join(modules, ".", &to_string/1)
  end

  defp extract_aliases({:__block__, _, nodes}) do
    Enum.flat_map(nodes, &extract_aliases/1)
  end

  defp extract_aliases({:alias, _, _} = alias_node) do
    [alias_node]
  end

  defp extract_aliases(_), do: []

  defp split_ast({:alias, meta, [{{:., _, [prefix_ast, :{}]}, _, inner_modules}]}) do
    prefix = extract_prefix(prefix_ast)

    aliases =
      Enum.map(inner_modules, fn {:__aliases__, m, mod} ->
        {:alias, meta, [{:__aliases__, m, prefix ++ mod}]}
      end)

    {:__block__, [], aliases}
  end

  defp split_ast(ast), do: ast

  defp extract_prefix({:__aliases__, _, prefix}), do: prefix
end
