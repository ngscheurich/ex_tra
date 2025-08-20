defmodule ExtractDefp do
  @moduledoc """
  Extracts private functions from a given code region, using all referenced
  variables (except module attributes) as arguments.
  """

  def main(region) when is_binary(region) do
    try do
      quoted = Code.string_to_quoted!(region)

      args =
        quoted
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

  # Collect used (free) variable names, accounting for lexical scope.
  defp used_vars(ast, extra \\ nil) do
    do_used_vars(ast, MapSet.new(extra || []), MapSet.new())
  end

  # do_used_vars(ast, bound_set, used_set)
  # - bound_set: variables currently bound and thus *not* free
  # - used_set: variables we've found that are actually free

  # Ignore module attributes
  defp do_used_vars({:@, _, [_]}, _bound, used) do
    used
  end

  # Assignment: x = ...
  # The binding effect of assignments should be handled in block contexts, so here, just recurse without trying to update bound vars globally.
  defp do_used_vars({:=, _, [pattern, rhs]}, bound, used) do
    used = do_used_vars(rhs, bound, used)

    result = do_used_vars(pattern, bound, used)

    result
  end

  # Lambda/fn: handles both single and multi-clause fns
  defp do_used_vars({:fn, _, clauses}, bound, used) when is_list(clauses) do
    Enum.reduce(clauses, used, fn
      {:->, _, [args, body]}, acc_used ->
        arg_names = Enum.flat_map(args, &extract_var_names/1)
        inner_bound = MapSet.union(bound, MapSet.new(arg_names))

        block =
          case body do
            {:__block__, _, _} -> body
            _ -> {:__block__, [], [body]}
          end

        body_used = do_used_vars(block, inner_bound, MapSet.new())
        # Promote variables free in the lambda out to used set
        MapSet.union(acc_used, MapSet.difference(body_used, inner_bound))

      _, acc ->
        acc
    end)
    # <-- critical: union outer with collected lambda-used vars
    |> MapSet.union(used)
  end

  # Variable usage
  defp do_used_vars({name, _, ctx}, bound, used)
       when is_atom(name) and is_atom(ctx) and name != :@ do
    if MapSet.member?(bound, name) do
      used
    else
      MapSet.put(used, name)
    end
  end

  # Handle cons node [head | tail]
  defp do_used_vars({:|, _, [head, tail]}, bound, used) do
    used
    |> do_used_vars(head, bound)
    |> do_used_vars(tail, bound)
  end

  defp do_used_vars({:__block__, _, exprs}, bound, used) when is_list(exprs) do
    Enum.reduce(exprs, {bound, used}, fn expr, {cur_bound, cur_used} ->
      case expr do
        {:=, _, [pattern, rhs]} ->
          used_rhs = do_used_vars(rhs, cur_bound, cur_used)
          names = extract_var_names(pattern)
          new_bound = MapSet.union(cur_bound, MapSet.new(names))
          # Add pattern variables to the traversal for detection of nested usage
          {new_bound, used_rhs}

        _ ->
          {cur_bound, do_used_vars(expr, cur_bound, cur_used)}
      end
    end)
    |> elem(1)
  end

  # Handle special blocks with keyword lists (e.g., if, case, cond)
  defp do_used_vars({:case, _meta, [subject, clauses]}, bound, used) do
    # Explicitly gather used_vars from the case subject
    {subject_node, _meta, _} = subject
    used = do_used_vars(subject_node, bound, used)

    Enum.reduce(clauses, used, fn clause, acc_used ->
      case clause do
        {:->, _, [pattern, body]} ->
          # Extract variables bound within the clause
          clause_bound =
            pattern
            |> Enum.flat_map(&extract_var_names/1)
            |> MapSet.new()
            |> MapSet.union(bound)

          # Additional debug for clause_bound adds
          clause_used =
            do_used_vars(body, clause_bound, MapSet.new())

          MapSet.union(acc_used, MapSet.difference(clause_used, clause_bound))

        _ ->
          # IO.inspect(clause,
          #   label: "Unexpected case clause blocks. These need to be processed too."
          # )

          acc_used
      end
    end)
  end

  defp do_used_vars({:., _meta, calls}, bound, used) do
    Enum.reduce(calls, used, fn call, acc_used ->
      do_used_vars(call, bound, acc_used)
    end)
  end

  defp do_used_vars({_, _, [_, kw]} = ast, bound, used) when is_list(kw) do
    if Keyword.keyword?(kw) do
      # condition/subject
      used = do_used_vars(elem(ast, 2) |> hd(), bound, used)

      Enum.reduce(kw, used, fn {_k, v}, acc ->
        do_used_vars(v, bound, acc)
      end)
    else
      # Fallback for non-keyword
      Enum.reduce([kw], used, fn arg, acc -> do_used_vars(arg, bound, acc) end)
    end
  end

  # Any AST node with children
  defp do_used_vars({_, _, args}, bound, used) when is_list(args) do
    Enum.reduce(args, used, fn arg, acc ->
      do_used_vars(arg, bound, acc)
    end)
  end

  # Literal or unsupported
  defp do_used_vars(_other, _bound, used) do
    used
  end

  # Extract all variable names in a function/lambda argument or pattern
  defp extract_var_names({name, _, _}) when is_atom(name), do: [name]

  defp extract_var_names({_, _, args}) when is_list(args),
    do: Enum.flat_map(args, &extract_var_names/1)

  defp extract_var_names(list) when is_list(list),
    do: Enum.flat_map(list, &do_used_vars(&1, MapSet.new(), MapSet.new()))

  defp extract_var_names(_), do: []
end
