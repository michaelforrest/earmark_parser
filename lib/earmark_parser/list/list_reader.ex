defmodule EarmarkParser.List.ListReader do
  use EarmarkParser.Types

  alias EarmarkParser.Line
  alias EarmarkParser.List.{ListInfo}
  @moduledoc false

  @not_pending {nil, 0}

  def read_list_item(input, list_info, options)

  def read_list_item(input, list_info, options) do
    {head_text, rest, list_info1, options1} = _read_list_item_head(input, [], list_info, options)
    {lines, rest1, options2} = _read_list_item_rest(rest, [], list_info1, options1)
    {head_text, lines, rest1, options2}
  end

  defp _read_list_item_head(input, result, list_info, options)

  defp _read_list_item_head([], result, list_info, options) do
    {Enum.reverse(result), [], list_info, options}
  end

  defp _read_list_item_head([next | rest] = input, result, list_info, options) do
    case _still_in_head?(next) do
      {true, trimmed} -> _read_list_item_head(rest, [trimmed | result], list_info, options)
      {false, _} -> {Enum.reverse(result), input, list_info, options}
    end
  end

  defp _read_list_item_rest(input, result, list_info, options)

  defp _read_list_item_rest([], item_lines, list_info, options) do
    {Enum.reverse(item_lines), [], options}
  end
  defp _read_list_item_rest([line | rest] = input, item_lines, list_info, options) do
    case _still_in_item?(line, list_info) do
      {true, list_info1} -> _read_list_item_rest(rest, [line | item_lines], list_info1, options)
      _ -> {Enum.reverse(item_lines), input, options}
    end
  end

  @spec _still_in_head?(Line.t()) :: {boolean(), String.t()}
  defp _still_in_head?(line)
  defp _still_in_head?(%Line.Blank{}), do: {false, ""}
  defp _still_in_head?(%{line: line}), do: {true, String.trim_leading(line)}

  @spec _still_in_item?(Line.t(), ListInfo.t()) :: maybe({true, ListInfo.t()})
  defp _still_in_item?(line, list_info)

  defp _still_in_item?(line, %ListInfo{pending: @not_pending} = list_info) do
    list_info1 = ListInfo.update_pending(list_info, line)

    if ListInfo.pending?(list_info1) do
      {true, list_info1}
    else
      _still_in_np_list?(line, list_info)
    end
  end

  defp _still_in_item?(line, list_info) do
    {true, ListInfo.update_pending(list_info, line)}
  end

  @spec _still_in_np_list?(Line.t(), ListInfo.t()) :: maybe({true, ListInfo.t()})
  defp _still_in_np_list?(line, list_info)

  defp _still_in_np_list?(%Line.Ruler{}, _list_info) do
    nil
  end

  defp _still_in_np_list?(%Line.Blank{}, list_info) do
    {true, %{list_info | spaced: true}}
  end

  defp _still_in_np_list?(_, %ListInfo{spaced: false} = list_info) do
    {true, list_info}
  end

  # # All following patterns match spaced: true

  defp _still_in_np_list?(%{indent: indent}, %ListInfo{width: width} = list_info) do
    if indent >= width do
      {true, list_info}
    end
  end

  # defp _still_in_np_list?(_, _), do: false
end
