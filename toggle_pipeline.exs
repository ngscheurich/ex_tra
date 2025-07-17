defmodule TogglePipeline do
  def toggle_pipeline(term) when is_binary(term) do
    try do
      ast = Code.string_to_quoted!(term)

      if is_piped?(ast) do
        unpipe_expression(term)
      else
        pipe_expression(term)
      end
    catch
      error -> {:error, "Failed: #{inspect(error)}"}
    end
  end

  # Check if the top-level expression is a pipe
  defp is_piped?({:|>, _, _}), do: true
  defp is_piped?(_), do: false

  defp pipe_expression(term) when is_binary(term) do
    term
    |> Code.string_to_quoted!()
    |> transform_to_pipes()
    |> Macro.to_string()
    |> then(&{:ok, &1})
  end

  # Handle module function calls (e.g., Enum.map, Code.string_to_quoted)
  defp transform_to_pipes({{:., _, [_module, _function]} = dot_call, meta, [first_arg | rest]}) do
    piped_first = transform_to_pipes(first_arg)
    {:|>, meta, [piped_first, {dot_call, meta, Enum.map(rest, &transform_to_pipes/1)}]}
  end

  # Handle local function calls (e.g., convert_map_keys)
  defp transform_to_pipes({fun, meta, [first_arg | rest]})
       when is_atom(fun) and is_list(rest) do
    # Check if this is a function call (not a special form)
    if function_call?(fun) do
      piped_first = transform_to_pipes(first_arg)
      {:|>, meta, [piped_first, {fun, meta, Enum.map(rest, &transform_to_pipes/1)}]}
    else
      # Special forms, operators, etc. - just recurse normally
      {fun, meta, Enum.map([first_arg | rest], &transform_to_pipes/1)}
    end
  end

  # Handle other nodes by recursing into them
  defp transform_to_pipes({form, meta, args}) when is_list(args) do
    {form, meta, Enum.map(args, &transform_to_pipes/1)}
  end

  defp transform_to_pipes(list) when is_list(list) do
    Enum.map(list, &transform_to_pipes/1)
  end

  defp transform_to_pipes(other), do: other

  # Determine if an atom represents a function call (not a special form or operator)
  defp function_call?(atom) when is_atom(atom) do
    atom_str = Atom.to_string(atom)
    # Function names start with lowercase letter or underscore
    # Exclude common operators and special forms
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
    |> Code.string_to_quoted()
    |> unpipe()
    |> Macro.to_string()
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
