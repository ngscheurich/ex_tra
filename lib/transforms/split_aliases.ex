defmodule SplitAliases do
  @moduledoc """
  Splits multi-alias curly brace notation into single-line aliases.

  ## Examples

    # Basic split
        iex> SplitAliases.main("alias Foo.{\\nBar.Baz,\\nQuux\\n}")
        {:ok, "alias Foo.Bar.Baz\\nalias Foo.Quux"}

    # Preserves full prefix path
        iex> SplitAliases.main("alias MyApp.Stuff.Things.{\\n    One,\\n    Two,\\n    Three\\n  }")
        {:ok, "alias MyApp.Stuff.Things.One\\nalias MyApp.Stuff.Things.Two\\nalias MyApp.Stuff.Things.Three"}

    # No curly-brace notation (unchanged)
        iex> SplitAliases.main("alias MyApp.Alone")
        {:ok, "alias MyApp.Alone"}

    # Invalid input (not an alias expression)
        iex> SplitAliases.main("not-an-alias")
        {:error, "Expected an alias expression, got: not-an-alias"}

    # Alias with whitespace and comments (comments not preserved)
        iex> SplitAliases.main("alias MyApp.{\\n  # comment\\n  One,\\n  Two\\n}")
        {:ok, "alias MyApp.One\\nalias MyApp.Two"}

    # Empty curly braces (should output nothing)
        iex> SplitAliases.main("alias Foo.{}")
        {:error, "Expected an alias expression, got: alias Foo.{}"}

    # Non-curly-brace, multiple lines input (should output unchanged)
        iex> SplitAliases.main("alias A\\nalias B")
        {:ok, "alias A\\nalias B"}

    # Curly-brace usage with space
        iex> SplitAliases.main("alias X.{Y, Z}")
        {:ok, "alias X.Y\\nalias X.Z"}
  """

  def main([arg]), do: main(arg)

  def main(arg) when is_binary(arg) do
    case Code.string_to_quoted(arg) do
      {:ok, ast} ->
        splitted = split_ast(ast)
        aliases = extract_aliases(splitted)

        case aliases do
          [] ->
            {:error, "Expected an alias expression, got: #{arg}"}

          _ ->
            aliases
            |> Enum.map(&alias_node_to_string/1)
            |> Enum.join("\n")
            |> then(&{:ok, &1})
        end

      {:error, _reason} ->
        {:error, "Expected an alias expression, got: #{arg}"}
    end
  end

  defp alias_node_to_string({:alias, _, [{:__aliases__, _, modules}]}) when is_list(modules) do
    "alias " <> Enum.map_join(modules, ".", &to_string/1)
  end

  defp alias_node_to_string({:comment, _, [text]}) when is_binary(text) do
    String.trim(text)
  end

  defp extract_aliases({:__block__, _, nodes}) do
    Enum.flat_map(nodes, &extract_aliases/1)
  end

  defp extract_aliases({:alias, _, _} = alias_node) do
    [alias_node]
  end

  defp extract_aliases({:comment, _, _} = comment_node), do: [comment_node]

  defp extract_aliases(_), do: []

  defp split_ast({:alias, meta, [{{:., _, [prefix_ast, :{}]}, _, inner_modules}]}) do
    prefix = extract_prefix(prefix_ast)

    {comments, aliases_list} =
      Enum.split_with(inner_modules, fn
        {:__block__, _, [{:comment, _, _}]} -> true
        {:comment, _, _} -> true
        _ -> false
      end)

    # Extract comment strings from comment nodes
    comment_lines =
      Enum.flat_map(comments, fn
        {:__block__, _, comment_nodes} ->
          Enum.map(comment_nodes, fn
            {:comment, _, [comment_text]} -> comment_text
            other -> to_string(other)
          end)

        {:comment, _, [comment_text]} ->
          [comment_text]

        other ->
          [to_string(other)]
      end)

    alias_nodes =
      Enum.map(aliases_list, fn
        {:__aliases__, m, mod} -> {:alias, meta, [{:__aliases__, m, prefix ++ mod}]}
        other -> other
      end)

    all_aliases =
      Enum.map(comment_lines, &{:comment, [], [&1]}) ++
        Enum.map(alias_nodes, fn alias_node -> alias_node end)

    {:__block__, [], all_aliases}
  end

  defp split_ast(ast), do: ast

  defp extract_prefix({:__aliases__, _, prefix}), do: prefix
end
