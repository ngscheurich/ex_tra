defmodule ToggleMapKeys do
  @moduledoc """
  Toggles the keys of the topmost map in an AST or code string between atoms and strings.
  If the topmost map has atom keys, converts to string keys. If it has string keys, converts to atom keys.
  Works recursively within the topmost map.
  """

  @doc """
  Takes Elixir code (as string or AST). If the topmost map node's keys are atoms, converts to strings;
  if the topmost map node's keys are strings, converts to atoms.

      iex> ToggleMapKeys.toggle_map_keys(quote do: %{foo: 1, bar: %{baz: 2}})
      {:%{}, [], [{"foo", 1}, {"bar", {:%{}, [], [{"baz", 2}]}}]}

      iex> ToggleMapKeys.toggle_map_keys(quote do: %{"foo" => 1, "bar" => %{"baz" => 2}})
      {:%{}, [], [{:foo, 1}, {:bar, {:%{}, [], [{:baz, 2}]}}]}

      iex> ToggleMapKeys.toggle_map_keys("%{foo: 1, bar: 2}")
      "%{"foo" => 1, "bar" => 2}"

      iex> ToggleMapKeys.toggle_map_keys("%{\"foo\" => 1, \"bar\" => 2}")
      "%{foo: 1, bar: 2}"
  """
  def main([arg]), do: main(arg)

  def main(arg) when is_tuple(arg) do
    case arg do
      {:%{}, meta, pairs} when is_list(pairs) and pairs != [] ->
        key_type = map_key_type(pairs)

        toggled_pairs =
          Enum.map(pairs, fn {k, v} -> {toggle_key(k, key_type), toggle_map_keys(v)} end)

        {:%{}, meta, toggled_pairs}

      _ ->
        Macro.prewalk(arg, &toggle_map_keys/1)
    end
  end

  def main(arg) when is_binary(arg) do
    try do
      arg
      |> Code.string_to_quoted!()
      |> toggle_map_keys()
      |> Macro.to_string()
      |> then(&{:ok, &1})
    rescue
      error -> {:error, "Failed: #{inspect(error)}"}
    end
  end

  def toggle_map_keys(term) when is_map(term) and map_size(term) > 0 do
    key_type = map_key_type(Map.to_list(term))
    Map.new(term, fn {k, v} -> {toggle_key(k, key_type), toggle_map_keys(v)} end)
  end

  def toggle_map_keys(term) when is_map(term), do: term
  def toggle_map_keys([head | tail]), do: [toggle_map_keys(head) | toggle_map_keys(tail)]
  def toggle_map_keys(term), do: term

  defp toggle_key(k, :atom) when is_atom(k), do: Atom.to_string(k)
  defp toggle_key(k, :string) when is_binary(k), do: String.to_atom(k)
  defp toggle_key(k, _), do: k

  defp map_key_type([{k, _} | _]) when is_atom(k), do: :atom
  defp map_key_type([{k, _} | _]) when is_binary(k), do: :string
  defp map_key_type(_), do: :unknown
end
