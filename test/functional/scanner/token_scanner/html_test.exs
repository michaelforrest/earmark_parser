defmodule Functional.Scanner.TokenScanner.HtmlTest do
  use ExUnit.Case, async: true
  alias EarmarkParser.Line, as: L

  @moduletag :dev

  describe "non regression" do
    test "<hello>" do
      line = "<hello>"
      type = L.HtmlOpenTag 
      assert_tokens line, type, tag: "hello"
    end
    test "with attributes" do
      line = ~s{<Hello class="World>">}
      type = L.HtmlOpenTag 
      assert_tokens line, type, tag: "Hello"
    end
  end

  describe "in one line" do
    test "with attributes" do
      line = ~s{<Hello class="World>"</Hello>>}
      [open, close] = scan(line)
      assert_tokens open, L.HtmlOpenTag, tag: "Hello"
    end
  end

  defp assert_tokens(line, tokens, overrides \\ [])
  defp assert_tokens(line, tokens, overrides) when is_list(tokens) do
    result = scan(line, overrides)
    assert result == tokens
  end
  defp assert_tokens(line, token, overrides) do
    assert_tokens(line, [token], overrides)
  end

  defp scan(line, _overrides \\ []) do
    EarmarkParser.LineScanner.TokenScanner.tokens_of_line(line, %EarmarkParser.Options{}, false)
  end

  defp token(scanned, overrides \\ []) do
    lnb = Keyword.get(overrides, :lnb, 42)
    {:ok, content} = Keyword.fetch(overrides, :content)
    {:ok, line} = Keyword.fetch(overrides, :line)
    {:ok, tag} = Keyword.fetch(overrides, :tag)
    struct!(scanned, content: content, indent: 0, line: line, lnb: lnb, tag: tag)
  end

end
