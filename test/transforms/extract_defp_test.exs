defmodule ExtractDefpTest do
  use ExUnit.Case, async: true

  describe "main/1" do
    test "extracts a simple expression" do
      original = "a + b * c"
      expected = "extracted_fn(a, b, c)\ndefp extracted_fn(a, b, c) do\na + b * c\nend"

      assert_extraction(original, expected)
    end

    test "extracts with module attributes ignored" do
      original = "@attr + x - y"
      expected = "extracted_fn(x, y)\ndefp extracted_fn(x, y) do\n@attr + x - y\nend"

      assert_extraction(original, expected)
    end

    test "handles no variables" do
      original = "42"
      expected = "extracted_fn()\ndefp extracted_fn() do\n42\nend"

      assert_extraction(original, expected)
    end

    test "handles syntax errors gracefully" do
      original = "a + * b"

      assert {:error, _} = ExtractDefp.main(original)
    end

    test "extracts with nested expressions" do
      original = "if a > 0, do: b + c, else: d - e"

      expected =
        "extracted_fn(a, b, c, d, e)\ndefp extracted_fn(a, b, c, d, e) do\nif a > 0, do: b + c, else: d - e\nend"

      assert_extraction(original, expected)
    end

    test "extracts with no variables and module attributes only" do
      original = "@attr1 + @attr2"
      expected = "extracted_fn()\ndefp extracted_fn() do\n@attr1 + @attr2\nend"

      assert_extraction(original, expected)
    end

    test "extracts with nested lambda function" do
      original = "Enum.reduce(foo, [], fn x, acc ->\n  y = 2\n  [x + y + z | acc]\nend)"

      expected =
        "extracted_fn(foo, z)\ndefp extracted_fn(foo, z) do\nEnum.reduce(foo, [], fn x, acc ->\n  y = 2\n  [x + y + z | acc]\nend)\nend"

      assert_extraction(original, expected)
    end

    test "extracts with case statement" do
      original = "case zap.foo do\n  :a ->\n  bar = 1\n :b -> baz = 2\nend"

      expected =
        "extracted_fn(zap)\ndefp extracted_fn(zap) do\ncase zap.foo do\n  :a ->\n  bar = 1\n :b -> baz = 2\nend\nend"

      assert_extraction(original, expected)
    end
  end

  defp assert_extraction(original, expected) do
    assert ExtractDefp.main(original) == {:ok, expected}
  end
end
