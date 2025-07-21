defmodule DoctestsTest do
  use ExUnit.Case, async: true

  doctest ExtractDefp
  doctest SplitAliases
  doctest ToggleMapKeys
  doctest TogglePipeline
  doctest ToggleStringConcat
end
