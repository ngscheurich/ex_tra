defmodule TogglePipelineTest do
  use ExUnit.Case

  test "toggles an empty pipeline" do
    original = ""
    expected = ""

    assert_toggle(original, expected)
  end

  test "toggles a non-pipeline expression" do
    original = ":foo + 1"
    expected = ":foo + 1"

    assert_toggle(original, expected)
  end

  test "toggles a function call without a pipe" do
    original = ":foo"
    expected = ":foo"

    assert_toggle(original, expected)
  end

  test "toggles a basic pipeline" do
    original = ":foo |> bar()"
    expected = "bar(:foo)"

    assert_toggle(original, expected)
  end

  test "toggles a nested pipeline" do
    original = "[:foo] |> Enum.map(&(&1 |> bar()))"
    expected = "Enum.map([:foo], &bar(&1))"

    assert_toggle(original, expected)
  end

  test "toggles a pipeline with newlines" do
    original = ":foo\n  |> bar()\n  |> baz()"
    expected = "baz(bar(:foo))"
    reversed = ":foo |> bar() |> baz()"

    assert_toggle(original, expected, reversed)
  end

  defp assert_toggle(original, expected, reversed \\ nil) do
    toggled = TogglePipeline.main(original)

    assert toggled == {:ok, expected}

    assert toggled |> elem(1) |> TogglePipeline.main() ==
             {:ok, if(is_nil(reversed), do: original, else: reversed)}
  end
end
