defmodule ToggleStringConcatTest do
  use ExUnit.Case
  use ToggleTestHelper, module: ToggleStringConcat

  test "toggles concatenation and interpolation with a basic example" do
    original = "\"foo\" <> bar"
    expected = "\"foo\#{bar}\""

    assert_toggle(original, expected)
  end

  test "nested concatenation" do
    original = "\"User: \#{name} (\#{\"\#{type}er\"}) from \#{String.upcase(place)}\""

    expected =
      "\"User: \" <> name <> \" (\" <> type <> \"er\" <> \") from \" <> String.upcase(place)"

    # Removes the redundant interpolation
    reversed = "\"User: \#{name} (\#{type}er) from \#{String.upcase(place)}\""

    assert_toggle(original, expected, reversed)
  end

  test "empty strings" do
    original = "\"\" <> \"a\""
    expected = "\"a\""
    reversed = "\"a\""

    assert_toggle(original, expected, reversed)
  end

  test "noop for non-matching input" do
    original = "123 + 456"
    assert_toggle(original, original)
  end

  test "error for invalid code" do
    {:error, reason} = ToggleStringConcat.main("foo <>")
    assert is_binary(reason)
  end
end
