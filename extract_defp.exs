defmodule ExtractDefp do
  @moduledoc """
  Extracts private functions from a given code region, using all referenced
  variables (except module attributes) as arguments.
  """

  def extract_defp(region) when is_binary(region) do
    try do
      args =
        region
        |> Code.string_to_quoted!()
        |> used_vars()
        |> Enum.to_list()
        |> Enum.sort()
        |> Enum.join(", ")

      func =
        "extracted_fn(#{args})\ndefp extracted_fn(#{args}) do\n#{String.trim(region)}\nend"

      {:ok, func}
    rescue
      error -> {:error, "Failed: #{inspect(error)}"}
    end
  end

  defp used_vars(ast) do
    Macro.prewalk(ast, {MapSet.new(), false}, fn
      {:@, _, _} = attr, {acc, _ignore} ->
        {attr, {acc, true}}

      node, {acc, true} ->
        {node, {acc, true}}

      {name, _, ctx} = var, {acc, false}
      when is_atom(name) and is_atom(ctx) and name != :@ ->
        {var, {MapSet.put(acc, name), false}}

      node, {acc, false} ->
        {node, {acc, false}}
    end)
    |> elem(1)
    |> elem(0)
  end
end
