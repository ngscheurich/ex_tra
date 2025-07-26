defmodule ToggleStringConcatTest do
  use ExUnit.Case

  test "converts concatenation to interpolation with string literals" do
    assert ToggleStringConcat.main(~s|"foo" <> "bar"|) == {:ok, "\"foo#{"bar"}\""}
  end

  test "converts interpolation to concatenation with string literals" do
    assert ToggleStringConcat.main(~S|"foo#{"bar"}"|) == {:ok, "\"foo\" <> \"bar\""}
  end

  test "nested concatenation" do
    assert ToggleStringConcat.main(~s|"a" <> ("b" <> "c")|) == {:ok, "\"abc\""}
    assert ToggleStringConcat.main(~S|"a#{"b#{"c"}"}"|) == {:ok, "\"a\" <> \"b\" <> \"c\""}
  end

  test "mixed inputs" do
    assert ToggleStringConcat.main(~s|"a" <> Integer.to_string(1)|) ==
             {:ok, "\"a#\{Integer.to_string(1)\}\""}

    assert ToggleStringConcat.main(~S|"a#{Integer.to_string(1)}"|) ==
             {:ok, "\"a\" <> Integer.to_string(1)"}
  end

  test "escape characters" do
    assert ToggleStringConcat.main(~s|"a\nb" <> foo|) == {:ok, "\"a\nb\#{foo}\""}
    assert ToggleStringConcat.main(~S|"a#{"b\n"}"|) == {:ok, "\"a\" <> \"b\\n\""}
  end

  test "empty strings" do
    assert ToggleStringConcat.main(~s|"" <> "a"|) == {:ok, "\"a\""}
    assert ToggleStringConcat.main(~S|"#{""}bar"|) == {:ok, "\"\" <> \"bar\""}
  end

  test "complex interpolation" do
    assert ToggleStringConcat.main(~S|"a#{"b#{"c"}"}"|) == {:ok, "\"a\" <> \"b\" <> \"c\""}
  end

  test "noop for non-matching input" do
    assert ToggleStringConcat.main("123 + 456") == {:ok, "123 + 456"}
  end

  test "error for invalid code" do
    {:error, reason} = ToggleStringConcat.main("foo <>")
    assert is_binary(reason)
  end
end
