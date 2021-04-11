defmodule EarmarkParser.LineScanner.TokenScanner do

  @moduledoc false
  
  alias EarmarkParser.Line
  alias EarmarkParser.Options
  #doc false
  def tokens_of_line(line, options, recursive) do
    _tokens_of_line(line, options, recursive, [])
  end

  # This is the re that matches the ridiculous "[id]: url title" syntax
  @id_title_part ~S"""
        (?|
             " (.*)  "         # in quotes
          |  ' (.*)  '         #
          | \( (.*) \)         # in parens
        )
  """

  @id_title_part_re ~r[^\s*#{@id_title_part}\s*$]x

  @id_re ~r'''
     ^(\s{0,3})             # leading spaces
     \[(.+?)\]:             # [someid]:
     \s+
     (?|
         < (\S+) >          # url in <>s
       |   (\S+)            # or without
     )
     (?:
        \s+                   # optional title
        #{@id_title_part}
     )?
     \s*
  $
  '''x

  @indent_re ~r'''
    \A ( (?: \s{4})+ ) (\s*)                       # 4 or more leading spaces
    (.*)                                  # the rest
  '''x

  @void_tags ~w{area br hr img wbr}
  @void_tag_rgx ~r'''
      ^<( #{Enum.join(@void_tags, "|")} )
        .*?
        >
  '''x
  @doc false
  def void_tag?(tag), do: Regex.match?(@void_tag_rgx, "<#{tag}>") 

  defp _tokens_of_line(line, options, recursive, result)
  defp _tokens_of_line(nil, options, recursive, result), do: Enum.reverse(result)
  defp _tokens_of_line(line, options, recursive, result) do
    {token, rest} = _next_token(line, options, recursive)
    _tokens_of_line(rest, options, recursive, [token | result])
  end

  defp _next_token(line, options = %Options{}, recursive) do
    cond do
      match = Regex.run(~r/\A (\s*) \z/x, line) ->
        [_, leading] = match
        {%Line.Blank{indent: String.length(leading)}, nil}

      match = !recursive && Regex.run(~r/\A (\s{0,3}) <! (?: -- .*? -- \s* )+ > \z/x, line) ->
        [_, leading] = match
        {%Line.HtmlComment{complete: true, indent: String.length(leading)}, nil}

      match = !recursive && Regex.run(~r/\A (\s{0,3}) <!-- .*? \z/x, line) ->
        [_, leading] = match
        {%Line.HtmlComment{complete: false, indent: String.length(leading)}, nil}

      match = Regex.run(~r/^ (\s{0,3}) (?:-\s?){3,} $/x, line) ->
        [_, leading] = match
        {%Line.Ruler{type: "-", indent: String.length(leading)}, nil}

      match = Regex.run(~r/^ (\s{0,3}) (?:\*\s?){3,} $/x, line) ->
        [_, leading] = match
        {%Line.Ruler{type: "*", indent: String.length(leading)}, nil}

      match = Regex.run( ~r/\A (\s{0,3}) (?:_\s?){3,} \z/x, line) ->
        [_, leading] = match
        {%Line.Ruler{type: "_", indent: String.length(leading)}, nil}

      match = Regex.run(~R/^(#{1,6})\s+(?|([^#]+)#*$|(.*))/u, line) ->
        [_, level, heading] = match
        {%Line.Heading{level: String.length(level), content: String.trim(heading), indent: 0}, nil}

      match = Regex.run(~r/\A( {0,3})>\s?(.*)/, line) ->
        [_, leading, quote] = match
        {%Line.BlockQuote{content: quote, indent: String.length(leading)}, nil}

      match = Regex.run(@indent_re, line) ->
        [_, spaces, more_spaces, rest] = match
        sl = String.length(spaces)
        {%Line.Indent{level: div(sl, 4), content: more_spaces <> rest, indent: String.length(more_spaces) + sl}, nil}

      match = Regex.run(~r/\A(\s*)(`{3,}|~{3,})\s*([^`\s]*)\s*\z/u, line) ->
        [_, leading, fence, language] = match
        {%Line.Fence{delimiter: fence, language: _attribute_escape(language), indent: String.length(leading)}, nil}

      #   Although no block tags I still think they should close a preceding para as do many other
      #   implementations.
      (match = Regex.run(@void_tag_rgx, line)) && !recursive ->
        [_, tag] = match

        {%Line.HtmlOneLine{tag: tag, content: line, indent: 0}, nil}

      match = !recursive && Regex.run(~r{\A<([-\w]+?)(?:\s.*)?>.*</\1>}, line) ->
        [_, tag] = match
        {%Line.HtmlOneLine{tag: tag, content: line, indent: 0}, nil}

      match = !recursive && Regex.run(~r{\A<([-\w]+?)(?:\s.*)?/>.*}, line) ->
        [_, tag] = match
        {%Line.HtmlOneLine{tag: tag, content: line, indent: 0}, nil}

      match = !recursive && Regex.run(~r/^<([-\w]+?)(?:\s.*)?>/, line) ->
        [_, tag] = match
        {%Line.HtmlOpenTag{tag: tag, content: line, indent: 0}, nil}

      match = !recursive && Regex.run(~r/\A(\s{0,3})<\/([-\w]+?)>/, line) ->
        [_, leading_spaces, tag] = match
        {%Line.HtmlCloseTag{tag: tag, indent: String.length(leading_spaces)}, nil}

      match = Regex.run(@id_re, line) ->
        [_, leading, id, url | title] = match
        title = if(length(title) == 0, do: "", else: hd(title))
        {%Line.IdDef{id: id, url: url, title: title, indent: String.length(leading)}, nil}

      match = options.footnotes && Regex.run(~r/\A\[\^([^\s\]]+)\]:\s+(.*)/, line) ->
        [_, id, first_line] = match
        {%Line.FnDef{id: id, content: first_line, indent: 0}, nil}

      match = Regex.run(~r/^(\s{0,3})([-*+])\s(\s*)(.*)/, line) ->
        [_, leading, bullet, spaces, text] = match

        list_item = %Line.ListItem{
          type: :ul,
          bullet: bullet,
          content: spaces <> text,
          indent: String.length(leading),
          list_indent:  String.length(leading <> bullet <> spaces) + 1,
        }
        {list_item, nil}

      match = Regex.run(~r/^(\s{0,3})(\d{1,9}[.)])\s(\s*)(.*)/, line) ->
        [_, leading, bullet, spaces, text] = match

        # TODO: Rewrite this mess
        sl = String.length(spaces)
        sl1 = if sl > 3, do: 1, else: sl + 1
        sl2 = sl1 + String.length(bullet)
        list_item = %Line.ListItem{
          type: :ol,
          bullet: bullet,
          content: spaces <> text,
          indent: String.length(leading),
          list_indent:  String.length(leading) + sl2,
        }
        {list_item, nil}

      match = Regex.run(~r/^ (\s{0,3}) \| (?: [^|]+ \|)+ \s* $ /x, line) ->
        [body, leading] = match

        body =
          body
          |> String.trim()
          |> String.trim("|")

        columns = split_table_columns(body)
        {%Line.TableLine{content: line, columns: columns, is_header: _determine_if_header(columns), indent: String.length(leading)}, nil}

      match = Regex.run(~r/\A (\s*) .* \s \| \s /x, line) ->
        [_, leading] = match
        columns = split_table_columns(line)
        {%Line.TableLine{content: line, columns: columns, is_header: _determine_if_header(columns), indent: String.length(leading)}, nil}

      match = options.gfm_tables && Regex.run( ~r/\A (\s*) .* \| /x, line) ->
        [_, leading] = match
        columns = split_table_columns(line)
        {%Line.TableLine{content: line, columns: columns, is_header: _determine_if_header(columns), needs_header: true, indent: String.length(leading)}, nil}

      match = Regex.run(~r/^(=|-)+\s*$/, line) ->
        [_, type] = match
        level = if(String.starts_with?(type, "="), do: 1, else: 2)
        {%Line.SetextUnderlineHeading{level: level, indent: 0}, nil}

      match = Regex.run(~r<^(\s{0,3}){:(\s*[^}]+)}\s*$>, line) ->
        [_, leading, ial] = match
        {%Line.Ial{attrs: String.trim(ial), verbatim: ial, indent: String.length(leading)}, nil}

      # Hmmmm in case of perf problems
      # Assuming that text lines are the most frequent would it not boost performance (which seems to be good anyway)
      # it would be great if we could come up with a regex that is a superset of all the regexen above and then
      # we could match as follows
      #       
      #       cond 
      #       nil = Regex.run(superset, line) -> %Text
      #       ...
      #       # all other matches from above
      #       ...
      #       # Catch the case were the supergx was too wide
      #       true -> %Text
      #
      #
      match = Regex.run(~r/\A (\s*) (.*)/x, line) ->
        [_, leading, content] = match
        {%Line.Text{content: content, indent: String.length(leading), line: line}, nil}
      true -> raise "Ooops no such line type"
    end
  end


  defp _attribute_escape(string), do:
    string
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")


  # Not sure yet if we shall enforce all tags, in that case we shall enlargen @block_tags to @html_tags
  # @block_tags ~w< address article aside blockquote canvas dd div dl fieldset figcaption h1 h2 h3 h4 h5 h6 header hgroup li main nav noscript ol output p pre section table tfoot ul video>
  #             |> Enum.into(MapSet.new())
  # defp block_tag?(tag), do: MapSet.member?(@block_tags, tag)

  @column_rgx ~r{\A[\s|:-]+\z}
  defp _determine_if_header(columns) do
    columns
    |> Enum.all?(fn col -> Regex.run(@column_rgx, col) end)
  end
  defp split_table_columns(line) do
    line
    |> String.split(~r{(?<!\\)\|})
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn col -> Regex.replace(~r{\\\|}, col, "|") end)
  end
end
