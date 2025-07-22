defmodule Extra do
  @moduledoc """
  Extra (Elixir Transforms) is a CLI tool that provides refactoring tools for
  working with Elixir. This module is compiled into an executable binary that
  can be called with a command and args from the CLI.
  """

  @doc """
  The main function for escript to compile into an executable.

  Takes a list where the first element is a command and subsequent elements are
  args to be passed to that command.
  """
  @spec main(list()) :: {:ok, term()} | {:error, term()}
  def main([command | args]) do
    args =
      case args do
        [arg] -> arg
        _ -> args
      end

    command
    |> case do
      "extract_defp" -> ExtractDefp.main(args)
      "split_aliases" -> SplitAliases.main(args)
      "toggle_map_keys" -> ToggleMapKeys.main(args)
      "toggle_pipeline" -> TogglePipeline.main(args)
      "toggle_string_concat" -> ToggleStringConcat.main(args)
      _ -> {:error, "Unknown command"}
    end
    |> case do
      {:ok, result} -> IO.puts(result)
      {:error, reason} -> IO.puts("Failed with: #{inspect(reason)}")
    end
  end
end
