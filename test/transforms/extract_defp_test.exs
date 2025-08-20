defmodule ExtractDefpTest do
  use ExUnit.Case, async: true

  describe "main/1" do
    test "extracts a simple expression" do
      original = "a + b * c"

      expected = """
      extracted_fn(a, b, c)
      defp extracted_fn(a, b, c) do
      a + b * c
      end
      """

      assert_extraction(original, expected)
    end

    test "extracts with module attributes ignored" do
      original = "@attr + x - y"

      expected = """
      extracted_fn(x, y)
      defp extracted_fn(x, y) do
      @attr + x - y
      end
      """

      assert_extraction(original, expected)
    end

    test "handles no variables" do
      original = "42"

      expected = """
      extracted_fn()
      defp extracted_fn() do
      42
      end
      """

      assert_extraction(original, expected)
    end

    test "handles syntax errors gracefully" do
      original = "a + * b"

      assert {:error, _} = ExtractDefp.main(original)
    end

    test "extracts with nested expressions" do
      original = "if a > 0, do: b + c, else: d - e"

      expected =
        """
        extracted_fn(a, b, c, d, e)
        defp extracted_fn(a, b, c, d, e) do
        if a > 0, do: b + c, else: d - e
        end
        """

      assert_extraction(original, expected)
    end

    test "extracts with no variables and module attributes only" do
      original = "@attr1 + @attr2"

      expected = """
      extracted_fn()
      defp extracted_fn() do
      @attr1 + @attr2
      end
      """

      assert_extraction(original, expected)
    end

    test "extracts with nested lambda function" do
      original = """
      Enum.reduce(foo, [], fn x, acc ->
        y = x + z

        [y | acc]
      end)
      """

      expected =
        """
        extracted_fn(foo, z)
        defp extracted_fn(foo, z) do
        Enum.reduce(foo, [], fn x, acc ->
          y = x + z

          [y | acc]
        end)
        end
        """

      assert_extraction(original, expected)
    end

    test "extracts with case statement" do
      original = """
      case zap.foo do
        :a -> bar = 1
        :b -> baz = 2
      end
      """

      expected =
        """
        extracted_fn(zap)
        defp extracted_fn(zap) do
        case zap.foo do
          :a -> bar = 1
          :b -> baz = 2
        end
        end
        """

      assert_extraction(original, expected)
    end
  end

  test "extracts cond statement" do
    original = "cond do\n  x > 0 -> y\n  x < 0 -> z\n  true -> w\nend"

    expected = """
    extracted_fn(x, y, z, w)
    defp extracted_fn(x, y, z, w) do
    cond do
      x > 0 -> y
      x < 0 -> z
      true -> w
    end
    end
    """

    assert_extraction(original, expected)
  end

  test "extracts with statement with multiple binds" do
    original = "with {:ok, a} <- foo, b = a + k, c <- bar(b) do\n  c * k\nend"

    expected = """
    extracted_fn(foo, k, bar)
    defp extracted_fn(foo, k, bar) do
    with {:ok, a} <- foo, b = a + k, c <- bar(b) do
      c * k
    end
    end
    """

    assert_extraction(original, expected)
  end

  test "extracts for comprehension" do
    original = "for x <- l, y <- m, x + y > z, do: x * y * z"

    expected = """
    extracted_fn(l, m, z)
    defp extracted_fn(l, m, z) do
    for x <- l, y <- m, x + y > z, do: x * y * z
    end
    """

    assert_extraction(original, expected)
  end

  test "extracts try/catch/rescue/after" do
    original = """
    try do
      foo + bar
    catch
      :error -> baz
    rescue
      _ -> qux
    after
      quux
    end
    """

    expected = """
    extracted_fn(foo, bar, baz, qux, quux)
    defp extracted_fn(foo, bar, baz, qux, quux) do
    try do
      foo + bar
    catch
      :error -> baz
    rescue
      _ -> qux
    after
      quux
    end
    end
    """

    assert_extraction(original, expected)
  end

  test "extracts receive block" do
    original = """
    receive do
      {:msg, a} -> handle(a)
      _ -> default
    end
    """

    expected = """
    extracted_fn(handle, default)
    defp extracted_fn(handle, default) do
    receive do
      {:msg, a} -> handle(a)
      _ -> default
    end
    end
    """

    assert_extraction(original, expected)
  end

  test "extracts tuple and list patterns" do
    original = "{a, b} = x; [y, ^b] = z; {y, k}"

    expected = """
    extracted_fn(x, z, k)
    defp extracted_fn(x, z, k) do
    {a, b} = x; [y, ^b] = z; {y, k}
    end
    """

    assert_extraction(original, expected)
  end

  test "ignores compile-time variables" do
    original = "__MODULE__ + x"

    expected = """
    extracted_fn(x)
    defp extracted_fn(x) do
    __MODULE__ + x
    end
    """

    assert_extraction(original, expected)
  end

  test "extracts anonymous function call" do
    original = "fun.(x, y) + rem(x, 2)"

    expected = """
    extracted_fn(fun, x, y)
    defp extracted_fn(fun, x, y) do
    fun.(x, y) + rem(x, 2)
    end
    """

    assert_extraction(original, expected)
  end

  test "handles shadowing in case branches" do
    original = "case foo do\n {:ok, x} -> x + y \n {:error, x} -> x + z \n end"

    expected = """
    extracted_fn(foo, y, z)
    defp extracted_fn(foo, y, z) do
    case foo do
      {:ok, x} -> x + y
      {:error, x} -> x + z
    end
    end
    """

    assert_extraction(original, expected)
  end

  defp assert_extraction(original, expected) do
    assert ExtractDefp.main(String.trim(original)) == {:ok, String.trim(expected)}
  end
end
