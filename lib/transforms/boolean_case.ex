defmodule BooleanCase do
  @moduledoc """
  Transforms Elixir code: converts top-level if/else blocks to case statements on boolean, preserving formatting.
  """

  @doc """
  Takes Elixir code as a string, replaces top-level if/else constructs with equivalent case statements on the condition,
  where the branches match true/false, preserving formatting. Returns {:ok, code_string} or {:error, reason}.
  """
  def main(code) when is_binary(code) do
    case Code.string_to_quoted(code) do
      {:ok, ast} ->
        new_ast = transform_if_to_case(ast)
        {:ok, Macro.to_string(new_ast)}

      {:error, err} ->
        {:error, err}
    end
  end

  def main(ast) when is_tuple(ast) and tuple_size(ast) > 0 do
    new_ast = transform_if_to_case(ast)
    {:ok, Macro.to_string(new_ast)}
  end

  def main(term), do: term

  defp transform_if_to_case(ast) do
    Macro.prewalk(ast, fn
      {:if, meta, [cond, [do: do_block, else: else_block]]} ->
        {
          :case,
          meta,
          [
            cond,
            [
              do: [
                {:->, [], [[true], do_block]},
                {:->, [], [[false], else_block]}
              ]
            ]
          ]
        }

      other ->
        other
    end)
  end
end
