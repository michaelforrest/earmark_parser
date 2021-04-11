defmodule EarmarkParser.LineScanner do

  @moduledoc false
  
  alias EarmarkParser.Helpers
  alias EarmarkParser.Line
  alias EarmarkParser.LineScanner.TokenScanner
  alias EarmarkParser.Options

  @doc false
  # We want to add the original source line into every
  # line we generate. We also need to expand tabs before
  # proceeding

  # (_,atom() | tuple() | #{},_) -> ['Elixir.B']
  def scan_lines(lines, options \\ %Options{}, recursive \\ false)

  def scan_lines(lines, options, recursive) do
    lines_with_count(lines, options.line - 1)
    |> Options.get_flat_mapper(options).(fn line -> type_of(line, options, recursive) end)
  end

  defp lines_with_count(lines, offset) do
    Enum.zip(lines, offset..(offset + Enum.count(lines)))
  end

  def type_of(line, recursive)
      when is_boolean(recursive),
      do: type_of(line, %Options{}, recursive)

  def type_of({line, lnb}, options = %Options{}, recursive) do
    line = line |> Helpers.expand_tabs() |> Helpers.remove_line_ending()
    TokenScanner.tokens_of_line(line, options, recursive) 
    |> Enum.map( & %{&1 | line: line, lnb: lnb} )
  end

end
