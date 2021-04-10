defmodule Functional.Scanner.HtmlLineTypeTest do
  use ExUnit.Case, async: true
  alias EarmarkParser.Line, as: L

  @moduletag :dev

  describe "non regression" do
    test "<hello>" do
      line = "<hello>"
      type = L.HtmlOpenTag 
      assert_line_type line, type, tag: "hello"
    end
    test "with attributes" do
      line = ~s{<Hello class="World>">}
      type = L.HtmlOpenTag 
      assert_line_type line, type, tag: "Hello"
    end
  end

  describe "in one line" do
    test "with attributes" do
      line = ~s{<Hello class="World>"</Hello>>}
      [open, close] = scan(line)
      assert_line_type open, L.HtmlOpenTag, tag: "Hello"
    end
  end

  defp assert_line_type(token_or_line, type, overrides \\ [])
  defp assert_line_type(line, type, overrides) when is_binary(line) do
    content = Keyword.get(overrides, :content, line)
    assert scan(line) == [token(type, Keyword.merge(overrides, content: content, line: line))]
  end
  defp assert_line_type(token, type, overrides) do
    content = Keyword.get(overrides, :content, token.line)
    assert token == [token(type, Keyword.merge(overrides, content: content, line: token.line))]
  end

  defp scan(line, lnb \\ 42, recursive \\ false), do: EarmarkParser.LineScanner.type_of({line, lnb}, recursive)

  defp token(scanned, overrides \\ []) do
    lnb = Keyword.get(overrides, :lnb, 42)
    {:ok, content} = Keyword.fetch(overrides, :content)
    {:ok, line} = Keyword.fetch(overrides, :line)
    {:ok, tag} = Keyword.fetch(overrides, :tag)
    struct!(scanned, content: content, indent: 0, line: line, lnb: lnb, tag: tag)
  end

end


