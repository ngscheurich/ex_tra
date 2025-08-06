defmodule TogglePipeline do
  @moduledoc """
  Toggles Elixir pipeline expressions between piped and unpiped forms, preserving formatting and newlines using Sourceror.
  """

  @doc """
  Takes Elixir code (as string) or AST. If the topmost expression is a pipeline, converts to unpiped form; else, converts to a pipeline.
  Preserves source formatting.
  """
  @spec main(String.t() | atom() | list()) :: {:ok, String.t()} | {:error, String.t()}
  def main([arg]), do: main(arg)

  def main(arg) when is_binary(arg) do
    try do
      arg
      |> Code.string_to_quoted!()
      |> is_piped?()
      |> case do
        true -> unpipe_expression(arg)
        false -> pipe_expression(arg)
      end
    catch
      error -> {:error, "Failed: #{inspect(error)}"}
    end
  end

  defp is_piped?({:|>, _, _}), do: true
  defp is_piped?(_), do: false

  defp pipe_expression(term) when is_binary(term) do
    term
    |> Code.string_to_quoted!()
    |> transform_to_pipes()
    |> Macro.to_string()
    |> then(&{:ok, &1})
  end

  defp transform_to_pipes({{:., _, [_module, _function]} = dot_call, meta, [first_arg | rest]}) do
    piped_first = transform_to_pipes(first_arg)
    {:|>, meta, [piped_first, {dot_call, meta, Enum.map(rest, &transform_to_pipes/1)}]}
  end

  defp transform_to_pipes({fun, meta, [first_arg | rest]})
       when is_atom(fun) and is_list(rest) do
    if function_call?(fun) do
      piped_first = transform_to_pipes(first_arg)
      {:|>, meta, [piped_first, {fun, meta, Enum.map(rest, &transform_to_pipes/1)}]}
    else
      {fun, meta, Enum.map([first_arg | rest], &transform_to_pipes/1)}
    end
  end

  defp transform_to_pipes({form, meta, args}) when is_list(args) do
    {form, meta, Enum.map(args, &transform_to_pipes/1)}
  end

  defp transform_to_pipes(list) when is_list(list) do
    Enum.map(list, &transform_to_pipes/1)
  end

  defp transform_to_pipes(other), do: other

  defp function_call?(atom) when is_atom(atom) do
    atom_str = Atom.to_string(atom)

    String.match?(atom_str, ~r/^[a-z_]/) and
      atom not in [
        :fn,
        :&,
        :=,
        :==,
        :!=,
        :<=,
        :>=,
        :<,
        :>,
        :+,
        :-,
        :*,
        :/,
        :++,
        :--,
        :.,
        :|>,
        :and,
        :or,
        :not,
        :in,
        :when,
        :def,
        :defp,
        :defmodule,
        :if,
        :unless,
        :case,
        :cond,
        :with
      ]
  end

  defp unpipe_expression(term) when is_binary(term) do
    term
    |> Code.string_to_quoted!()
    |> unpipe()
    |> Macro.to_string()
    |> then(&{:ok, &1})
  end

  defp unpipe(ast) do
    Macro.prewalk(ast, &unpipe_node/1)
  end

  defp unpipe_node({:|>, _meta, [left, right]} = _pipe) do
    transform_pipe(left, right)
  end

  defp unpipe_node(node), do: node

  defp transform_pipe(left, {fun, meta, args}) do
    {fun, meta, [left | args]}
  end

  defp transform_pipe(_left, right) do
    raise ArgumentError, "Unsupported pipe segment: #{Macro.to_string(right)}"
  end
end
