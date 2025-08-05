defmodule ToggleMapKeys do
  @moduledoc """
  Toggles the keys of maps in Elixir code or AST strings between atoms and strings,
  preserving source formatting and newlines using Sourceror.
  """

  @doc """
  Takes Elixir code (as string) or AST. If the topmost map's keys are atoms, converts to string keys;
  if the topmost map's keys are strings, converts to atom keys.
  Preserves source formatting.
  """
  def main(code) when is_binary(code) do
    with {:ok, ast} <- Sourceror.parse_string(code) do
      type = detect_map_key_type(ast)
      toggled_ast = toggle_map_keys(ast, type)
      {:ok, Sourceror.to_string(toggled_ast, locals_without_parens: [])}
    else
      _ -> {:error, "Could not parse code"}
    end
  end

  def main(ast) when is_tuple(ast) do
    type = detect_map_key_type(ast)
    toggled_ast = toggle_map_keys(ast, type)

    case Sourceror.to_string(toggled_ast, locals_without_parens: []) do
      {:ok, str} -> {:ok, str}
      _ -> {:error, "Could not stringify toggled ast"}
    end
  end

  def main(term), do: term

  defp detect_map_key_type({:%{}, _meta, pairs}) when is_list(pairs) and pairs != [] do
    [{k, _} | _] = pairs
    key = unwrap_key(k)

    key_type =
      cond do
        is_atom(key) -> :atom
        is_binary(key) -> :string
        true -> :unknown
      end

    key_type
  end

  defp detect_map_key_type(_), do: :unknown

  # Recursively extract the literal key out of Sourceror AST wrappers
  defp unwrap_key({:__block__, _, [key]}), do: unwrap_key(key)

  defp unwrap_key({:__block__, _, key}) when is_list(key) and length(key) == 1,
    do: unwrap_key(hd(key))

  defp unwrap_key(k), do: k

  defp convert_key(k, :atom) do
    val = unwrap_key(k)

    cond do
      is_binary(val) -> safe_string_to_atom(val)
      is_atom(val) -> val
      # unknown, leave as is
      true -> val
    end
  end

  defp convert_key(k, :string) do
    val = unwrap_key(k)

    cond do
      is_atom(val) -> Atom.to_string(val)
      is_binary(val) -> val
      true -> val
    end
  end

  defp convert_key(k, _), do: k

  defp toggle_type(:atom), do: :string
  defp toggle_type(:string), do: :atom
  defp toggle_type(t), do: t

  defp toggle_map_keys({:%{}, meta, pairs} = map_ast, _parent_type)
       when is_list(pairs) and pairs != [] do
    # For each map node, detect for itself
    type = detect_map_key_type(map_ast)

    toggled_pairs =
      Enum.map(pairs, fn {k, v} ->
        new_key = convert_key(k, toggle_type(type))
        toggled_value = toggle_map_keys(v, type)
        {new_key, toggled_value}
      end)

    result = {:%{}, meta, toggled_pairs}
    result
  end

  defp toggle_map_keys({left, right}, type) when is_tuple(right) do
    new_right = toggle_map_keys(right, type)

    new_right =
      case new_right do
        {:ok, val} -> val
        val -> val
      end

    {left, new_right}
  end

  defp toggle_map_keys(list, type) when is_list(list) do
    Enum.map(list, &toggle_map_keys(&1, type))
  end

  defp toggle_map_keys(other, _type), do: other

  defp safe_string_to_atom(s) when is_binary(s) do
    try do
      String.to_atom(s)
    rescue
      _ -> s
    end
  end
end
