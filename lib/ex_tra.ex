defmodule ExTra do
  @moduledoc """
  ExTra (Elixir Transforms) is a CLI tool that provides refactoring transforms for
  working with Elixir. This module is compiled into an executable binary that
  can be called with a transform and args from the CLI.
  """

  @transforms Application.compile_env(:ex_tra, :transforms)

  @doc """
  Takes a list where the first element is a transform and subsequent elements are
  args to be passed to that transform.
  """
  @spec main(list()) :: {:ok, term()} | {:error, term()}
  def main(["list_transforms"]) do
    @transforms
    |> Map.keys()
    |> Enum.join(", ")
    |> IO.puts()

    :ok
  end

  def main([transform | args]) do
    @transforms
    |> Map.get(transform)
    |> case do
      nil ->
        {:error, "Unknown transform, try list_transforms to see options."}

      mod ->
        try do
          apply(Module.concat([mod]), :main, args)
        rescue
          err -> {:error, Exception.message(err)}
        end
    end
    |> case do
      {:ok, val} -> IO.puts(val)
      {:error, reason} -> IO.puts("Error: #{inspect(reason)}")
    end
  end
end
