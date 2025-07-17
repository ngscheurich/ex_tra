defmodule SplitAliases do
  @moduledoc """
  Splits multi-alias curly brace notation into single-line aliases.

  ## Examples
  iex> split_aliases("alias Arcadia.Plug.Data.{Account, BillingStatement, Meter, Site}")
  {:ok, "alias Arcadia.Plug.Data.Account\nalias Arcadia.Plug.Data.BillingStatement\nalias Arcadia.Plug.Data.Meter\nalias Arcadia.Plug.Data.Site"}
  """

  def split_aliases(string) when is_binary(string) do
    case Code.string_to_quoted(string) do
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

  defp extract_aliases(_) do
    []
  end

  # Handles {:alias, meta, [dot_tuple_call]}
  defp split_ast(
         {:alias, meta,
          [
            {{:., _, [prefix_ast, :{}]}, _, inner_modules}
          ]} = ast
       ) do
    prefix = extract_prefix(prefix_ast)

    aliases =
      Enum.map(inner_modules, fn {:__aliases__, m, mod} ->
        {:alias, meta, [{:__aliases__, m, prefix ++ mod}]}
      end)

    {:__block__, [], aliases}
  end

  # fallback: for already split alias or anything else
  defp split_ast(ast), do: ast

  defp extract_prefix({:__aliases__, _, prefix}), do: prefix

  defp build_aliases(meta, prefix, {:atoms__, _, [atom]}, rest) do
    aliases = [atom] ++ extract_atoms(rest)

    aliases =
      Enum.map(aliases, fn atom ->
        {:alias, meta, [{:__aliases__, [], [prefix, atom]}]}
      end)
      |> List.flatten()

    {:__block__, [], aliases}
  end

  defp extract_atoms([]), do: []

  defp extract_atoms([{:{}, _meta, elements} | tail]) do
    atoms =
      Enum.map(elements, fn
        {:atoms__, _, [atom]} -> atom
        other -> other
      end)

    atoms ++ extract_atoms(tail)
  end
end
