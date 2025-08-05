defmodule ToggleMapKeysTest do
  use ExUnit.Case

  test "toggles a basic map" do
    original = "%{\"hello\" => :world}"
    expected = "%{hello: :world}"

    assert_toggle(original, expected)
  end

  test "toggles a nested map" do
    original = "%{\"hello\" => %{\"foo\" => :bar}}"
    expected = "%{hello: %{foo: :bar}}"

    assert_toggle(original, expected)
  end

  test "toggles a map with newlines " do
    original = "%{\n  \"foo\" => :bar\n}"
    expected = "%{\n  foo: :bar\n}"

    assert_toggle(original, expected)
  end

  defp assert_toggle(original, expected) do
    toggled = ToggleMapKeys.main(original)

    assert toggled == {:ok, expected}
    assert toggled |> elem(1) |> ToggleMapKeys.main() == {:ok, original}
  end
end
