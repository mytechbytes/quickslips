defmodule QuickSlips.Mail.Text do
  @moduledoc """
  The plain-text version of an e-mail, printed from the same `QuickSlips.Mail.Letter` as the HTML.

  It is what a reader sees whose mail program shows no HTML, and what a spam filter compares with the HTML. So it
  says the same things: the name, the heading, every block, and the foot of the e-mail. A link is on a line of its
  own, so that it is not broken in two by a long line.
  """
  alias QuickSlips.Mail.Letter

  @rule String.duplicate("-", 40)

  @doc "The text of `letter`. `frame` is what `QuickSlips.Mail` adds around every letter (site address, links)."
  def render(%Letter{} = letter, frame) do
    (["QuickSlips", "", letter.heading, ""] ++ blocks(letter.blocks) ++ footer(letter, frame))
    |> Enum.join("\n")
  end

  defp blocks(blocks), do: Enum.flat_map(blocks, &(block(&1) ++ [""]))

  defp block({:text, text}), do: [text]
  defp block({:note, text}), do: [text]
  defp block({:lines, lines}), do: lines
  defp block({:button, label, url}), do: [label, url]

  defp block({:facts, rows}) do
    for {label, value} <- rows, do: String.pad_trailing(label <> ":", 11) <> value_text(value)
  end

  defp block({:quote, label, text}) do
    List.wrap(label) ++ [@rule, text, @rule]
  end

  defp block({:links, heading, links}) do
    [heading] ++ for {label, url} <- links, do: "- #{label}: #{url}"
  end

  defp value_text({:link, url}), do: url
  defp value_text(text), do: text

  defp footer(letter, frame) do
    ["--", "QuickSlips · #{frame.site_url}", frame.tagline] ++
      for({label, url} <- frame.links, do: "#{label}: #{url}") ++
      extra(letter.footer ++ List.wrap(frame.reply_line))
  end

  defp extra([]), do: []
  defp extra(lines), do: [""] ++ lines
end
