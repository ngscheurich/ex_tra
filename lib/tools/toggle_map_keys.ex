defmodule ToggleMapKeys do
  @moduledoc """
  Toggles the keys of the topmost map in an AST or code string between atoms and strings.
  If the topmost map has atom keys, converts to string keys. If it has string keys, converts to atom keys.
  Works recursively within the topmost map.
  """

  @doc """
  Takes Elixir code (as string or AST). If the topmost map node's keys are atoms, converts to strings;
  if the topmost map node's keys are strings, converts to atoms.

      iex> ToggleMapKeys.main("%{foo: 1, bar: 2}")
      {:ok, "%{\\"foo\\" => 1, \\"bar\\" => 2}"}

      iex> ToggleMapKeys.main("%{\\"foo\\" => 1, \\"bar\\" => 2}")
      {:ok, "%{foo: 1, bar: 2}"}

      # Variable in scope, only literal map keys toggle
      iex> ToggleMapKeys.main("%{foo: %{bar: 2, baz: [1, 2]}, static: foo}")
      {:ok, "%{\\"foo\\" => %{\\"bar\\" => 2, \\"baz\\" => [1, 2]}, \\"static\\" => foo}"}

  """
  def main(ast) when is_tuple(ast) do
    case ast do
      {:%{}, meta, pairs} when is_list(pairs) and pairs != [] ->
        key_type = map_key_type(pairs)

        toggled_pairs =
          Enum.map(pairs, fn {k, v} -> {toggle_key(k, key_type), main(v)} end)

        {:%{}, meta, toggled_pairs}

      _ ->
        # Return non-map tuples as-is instead of Macro.prewalk to avoid recursion
        ast
    end
  end

  def main(term) when is_binary(term) do
    try do
      term
      |> Code.string_to_quoted!()
      |> main()
      |> Macro.to_string()
      |> then(&{:ok, &1})
    rescue
      error -> {:error, "Failed: #{inspect(error)}"}
    end
  end

  def main(term) when is_map(term) and map_size(term) > 0 do
    key_type = map_key_type(Map.to_list(term))
    Map.new(term, fn {k, v} -> {toggle_key(k, key_type), main(v)} end)
  end

  def main(term) when is_map(term), do: term
  def main([head | tail]), do: [main(head) | main(tail)]
  def main(term), do: term

  defp toggle_key(k, :atom) when is_atom(k), do: Atom.to_string(k)
  defp toggle_key(k, :string) when is_binary(k), do: String.to_atom(k)
  defp toggle_key(k, _), do: k

  defp map_key_type([{k, _} | _]) when is_atom(k), do: :atom
  defp map_key_type([{k, _} | _]) when is_binary(k), do: :string
  defp map_key_type(_), do: :unknown
end
