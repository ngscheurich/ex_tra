defmodule DoctestsTest do
  use ExUnit.Case, async: true
  import DoctestTransforms
  doctest_transforms()
end
