defmodule ToggleMapKeysTest do
  use ExUnit.Case
  use ToggleTestHelper, module: ToggleMapKeys

  test "toggles a basic map" do
    original = ~s(
    %{"hello" => :world}
    )

    expected = ~s(
    %{hello: :world}
    )

    assert_toggle(original, expected)
  end

  test "toggles a nested map" do
    original = ~s(
    %{"hello" => %{"foo" => :bar}}
    )

    expected = ~s(
    %{hello: %{foo: :bar}}
    )

    assert_toggle(original, expected)
  end

  test "toggles a map with newlines " do
    original = ~s(%{
  "foo" => :bar
})

    expected = ~s(%{
  foo: :bar
})

    assert_toggle(original, expected)
  end
end
