defmodule DoctestTransforms do
  @moduledoc """
  This module is used to automatically run doctests for all transforms defined in the
  `:ex_tra` application environment. It collects the modules specified in the
  `:transforms` configuration and generates doctest calls for each of them.
  """

  @transforms Application.compile_env(:ex_tra, :transforms, %{})

  defmacro doctest_transforms do
    @transforms
    |> Map.values()
    |> Enum.map(fn module_atom ->
      module = Module.concat([module_atom])

      quote do
        doctest unquote(module)
      end
    end)
    |> then(fn asts ->
      quote do
        (unquote_splicing(asts))
      end
    end)
  end
end
