defmodule ToggleStringConcat do
  @moduledoc """
  Toggle between string concatenation (<> operator) and string interpolation ("")
  in Elixir code *given as a string*. Output is always {:ok, code_string} or {:error, reason}.
  This module only works at the top level of the code string.
  """

  @doc """
  Toggle string concatenation/interpolation in the code string.
  Returns {:ok, new_code_string} or {:error, reason}

  ## Examples

  iex> ToggleStringConcat.toggle_string_concat("foo " <> bar <> " baz")
  {:ok, "\"foo \#{bar} baz\""}

  iex> ToggleStringConcat.toggle_string_concat("foo \#{bar} baz")
  {:ok, "foo " <> bar <> " baz"}

  iex> ToggleStringConcat.toggle_string_concat("plain string")
  {:ok, "plain string"}
  """

  def main([arg]), do: main(arg)

  def toggle_string_concat(arg) when is_binary(arg) do
    code = unescape_interpolation_literal(arg)

    with {:ok, ast} <- Code.string_to_quoted(code) do
      cond do
        is_concat?(ast) ->
          ast |> concat_to_interpolation() |> ok()

        is_interpolation?(ast) ->
          ast |> interpolation_to_concat() |> ok()

        true ->
          ok(code)
      end
    else
      err -> {:error, inspect(err)}
    end
  end

  defp unescape_interpolation_literal(str) do
    String.replace(str, "\#{", "#" <> "{")
  end

  defp is_concat?({:<>, _, [_, _]}), do: true
  defp is_concat?(_), do: false

  defp is_interpolation?({:<<>>, _, parts}) do
    Enum.any?(parts, &match?({:"::", _, _}, &1)) or
      Enum.any?(parts, &(match?({:_, _, _}, &1) == false and is_tuple(&1)))
  end

  defp is_interpolation?(_), do: false

  defp concat_to_interpolation(ast) do
    pieces = flatten_concat(ast)

    content =
      Enum.map(pieces, fn s ->
        if is_string_piece?(s),
          do: string_content_of(s),
          else: "\u0000#{Macro.to_string(s)}\u0000"
      end)
      |> Enum.join("")

    interpolated =
      Regex.replace(~r/\x00(.*?)\x00/, content, "#" <> "{" <> "\\1" <> "}")

    "\"" <> interpolated <> "\""
  end

  defp flatten_concat({:<>, _, [a, b]}), do: flatten_concat(a) ++ flatten_concat(b)
  defp flatten_concat(s), do: [s]
  defp is_string_piece?({:<<>>, _, [c]}) when is_binary(c), do: true
  defp is_string_piece?(s) when is_binary(s), do: true
  defp is_string_piece?(_), do: false
  defp string_content_of({:<<>>, _, [c]}), do: c
  defp string_content_of(s) when is_binary(s), do: s

  defp interpolation_to_concat({:<<>>, _, parts}) do
    concat_parts =
      Enum.map(parts, fn
        b when is_binary(b) -> {:string, b}
        {:"::", _, [expr, {:binary, _, _}]} -> {:expr, unwrap_kernel_to_string(expr)}
        other -> {:expr, unwrap_kernel_to_string(other)}
      end)

    components =
      Enum.map(concat_parts, fn
        {:string, s} -> "\"" <> escape_string(s) <> "\""
        {:expr, ast} -> Macro.to_string(ast)
      end)

    Enum.join(components, " <> ")
  end

  defp interpolation_to_concat(ast), do: ast

  defp unwrap_kernel_to_string({{:., _, [{:__aliases__, _, [:Kernel]}, :to_string]}, _, [expr]}),
    do: expr

  defp unwrap_kernel_to_string({{:., _, [:Kernel, :to_string]}, _, [expr]}), do: expr
  defp unwrap_kernel_to_string({{:., _, [Kernel, :to_string]}, _, [expr]}), do: expr
  defp unwrap_kernel_to_string(expr), do: expr

  defp escape_string(s) do
    s
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", "\\n")
    |> String.replace("\t", "\\t")
    |> String.replace("\r", "\\r")
    |> String.replace("\v", "\\v")
    |> String.replace("\b", "\\b")
    |> String.replace("\f", "\\f")
  end

  defp ok(s), do: {:ok, s}
end
