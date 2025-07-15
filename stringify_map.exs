defmodule StringifyMap do
  @moduledoc """
  Converts atom keys to string keys in maps found within Elixir AST.
  """

  @doc """
  Takes an Elixir AST and recursively converts all atom keys to string keys
  in any maps found within the AST.

  ## Examples

      iex> ast = quote do: %{foo: 1, bar: %{baz: 2}}
      iex> AstMapConverter.convert_map_keys(ast)
      {:%{}, [], [{"foo", 1}, {"bar", {:%{}, [], [{"baz", 2}]}}]}

      iex> ast = quote do: %{:foo => 1, "bar" => 2}
      iex> AstMapConverter.convert_map_keys(ast)
      {:%{}, [], [{"foo", 1}, {"bar", 2}]}

      iex> ast = quote do: [1, %{atom: "value"}, 3]
      iex> AstMapConverter.convert_map_keys(ast)
      [1, {:%{}, [], [{"atom", "value"}]}, 3]
  """
  def stringify_map(term) when is_binary(term) do
    try do
      term |> Code.string_to_quoted() |> convert_map_keys() |> Macro.to_string()
    catch
      :error, error -> {:error, "Failed: #{inspect(error)}"}
    end
  end

  def convert_map_keys(ast) do
    Macro.prewalk(ast, &convert_node/1)
  end

  # Handle map literals: %{key: value} or %{key => value}
  defp convert_node({:%{}, meta, pairs} = node) when is_list(pairs) do
    if is_map_node?(node) do
      converted_pairs = Enum.map(pairs, &convert_map_pair/1)
      {:%{}, meta, converted_pairs}
    else
      node
    end
  end

  # Handle other nodes (pass through)
  defp convert_node(node), do: node

  # Convert a key-value pair in a map
  defp convert_map_pair({key, value}) when is_atom(key) do
    {Atom.to_string(key), value}
  end

  defp convert_map_pair({key, value}) do
    {key, value}
  end

  # Check if a node represents a map
  defp is_map_node?({:%{}, _meta, pairs}) when is_list(pairs) do
    Enum.all?(pairs, fn
      {_key, _value} -> true
      _ -> false
    end)
  end

  defp is_map_node?(_), do: false

  @doc """
  Alternative implementation that also handles runtime maps (not just AST).
  This version can handle both AST nodes and actual map values.

  ## Examples

      iex> AstMapConverter.convert_any(%{foo: 1, bar: %{baz: 2}})
      %{"foo" => 1, "bar" => %{"baz" => 2}}

      iex> ast = quote do: %{foo: 1, bar: %{baz: 2}}
      iex> AstMapConverter.convert_any(ast)
      {:%{}, [], [{"foo", 1}, {"bar", {:%{}, [], [{"baz", 2}]}}]}
  """
  def convert_any(term) when is_map(term) do
    # Handle runtime maps
    Map.new(term, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), convert_any(value)}
      {key, value} -> {key, convert_any(value)}
    end)
  end

  def convert_any(term) when is_list(term) do
    # Handle lists
    Enum.map(term, &convert_any/1)
  end

  def convert_any({:%{}, _, _} = ast) do
    # Handle AST map nodes
    convert_map_keys(ast)
  end

  def convert_any({_, _, _} = ast) do
    # Handle other AST nodes
    Macro.prewalk(ast, fn
      {:%{}, meta, pairs} = node when is_list(pairs) ->
        if is_map_node?(node) do
          converted_pairs = Enum.map(pairs, &convert_map_pair/1)
          {:%{}, meta, converted_pairs}
        else
          node
        end

      other ->
        other
    end)
  end

  def convert_any(term), do: term
end
