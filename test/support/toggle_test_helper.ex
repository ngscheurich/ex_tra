defmodule ToggleTestHelper do
  @moduledoc """
  A helper module that provides a `using` macro to generate toggle testing functionality.
  """

  defmacro __using__(opts) do
    module = Keyword.get(opts, :module) || raise "Must specify :module option"

    quote do
      defp assert_toggle(original, expected), do: assert_toggle(original, expected, original)

      defp assert_toggle(original, expected, reversed) do
        assert {:ok, ^expected} = unquote(module).main(original)
        assert unquote(module).main(expected) == {:ok, reversed}
      end
    end
  end
end
