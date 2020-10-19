defmodule EarmarkParser.List.ListParser do
  use EarmarkParser.Types
  alias EarmarkParser.{Block, Line, Options, Parser}
  alias EarmarkParser.List.{ListInfo, ListReader}
  alias EarmarkParser.Block.{Blank, List, ListItem, Text}

  import EarmarkParser.Helpers.StringHelpers, only: [behead_indent: 2]

  @typep list_and_blocks :: [List.t() | Block.ts()]
  @typep list_and_lines :: [%Line.ListItem{} | Line.ts()]
  @moduledoc false

  # @spec parse_list(Lines, Blocks, Option) :: {[List|Blocks], Lines, Option}
  @spec parse_list(list_and_lines(), Block.ts(), Options.t()) ::
          {list_and_blocks(), Line.ts(), Options.t()}
  def parse_list([%Line.ListItem{} = line | _] = input, result, options) do
    # IO.inspect input
    list_info = ListInfo.new(line)
    {list, rest, options1} = parse_list_items(input, [], list_info, options)
    {[list | result], rest, options1}
  end

  @spec parse_list_items(Line.ts(), Block.ts(), ListInfo.t(), Options.t()) ::
          {Block.t(), Line.ts(), Options.t()}
  def parse_list_items(input, items, list_info, options)

  def parse_list_items([], items, list_info, options) do
    {List.new(items, list_info), [], options}
  end

  def parse_list_items(input, items, list_info, options) do
    {list_item, rest, options1} = parse_list_item(input, list_info, options)
    items1 = [list_item | items]

    # IO.inspect({hd(input), list_info})
    case input_continues_list?(input, list_info) do
      {true, list_info1} -> parse_list_items(rest, items1, list_info1, options1)
      _ -> {List.new(items1, list_info), rest, options1}
    end
  end

  @spec parse_list_item(Line.ts(), ListInfo.t(), Options.t()) ::
          {Block.t(), Line.ts(), Options.t()}
  def parse_list_item([%Line.ListItem{} = line | _] = input, list_info, options) do
    # Make a new list Item
    #  |> IO.inspect(label: :read)
    {head_lines, item_lines, rest, options1} =
      ListReader.read_list_item(input, list_info, options)

    list_item_head = Parser.parse(head_lines)
    {list_item_blocks, options2} = parse_list_item_lines(item_lines, list_info, options1) |> IO.inspect() 

    {ListItem.new(line, blocks: [list_item_head | list_item_blocks]), rest, options2}
  end

  @spec parse_list_item_lines(Line.ts(), ListInfo.t(), Options.t()) :: {Block.ts(), Options.t()}
  defp parse_list_item_lines(lines, list_info, options)

  defp parse_list_item_lines([], _list_info, options) do
    {[], options}
  end

  defp parse_list_item_lines(lines, %ListInfo{width: width}, options) do
    {blocks, context} =
      lines
      |> Enum.map(&behead_ws_line(&1, width))
      # |> IO.inspect(label: :beheaded)
      |> EarmarkParser.Parser.parse_markdown(options)

    {blocks, context.options}
  end

  @spec input_continues_list?(Line.ts(), ListInfo.t()) :: maybe({true, ListInfo.t()})
  defp input_continues_list?(input, list_info)

  defp input_continues_list?([%Line.ListItem{} | _], list_info), do: {true, list_info}

  defp input_continues_list?(_, _), do: nil

  defp behead_ws_line(%{line: line} = x, width) do
    IO.inspect(line, label: :before)
    behead_indent(line, width) |> IO.inspect(label: :after)
  end
end
