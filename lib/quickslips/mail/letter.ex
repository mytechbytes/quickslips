defmodule QuickSlips.Mail.Letter do
  @moduledoc """
  What an e-mail says, before it is made into HTML and plain text.

  Each e-mail of the site is described once, as a `%Letter{}`: the subject, a heading, and a list of *blocks*. Two
  renderers then print the same description: `QuickSlips.Mail.Layout` as HTML (with the logo, the colours and a
  layout that works in Gmail, Outlook and on a phone) and `QuickSlips.Mail.Text` as plain text. Because both read the
  same list, the two versions cannot say different things, and an e-mail that has a text version next to its HTML is
  one of the things that mail providers like to see.

  The blocks:

    * `{:text, "A paragraph."}`
    * `{:button, "Label", url}`: the one thing the reader should do. The renderers add the address under the button,
      so that it can be copied when the button does not work.
    * `{:note, "A line of fine print."}`: a soft box, for what the reader should know (how long a link works).
    * `{:lines, ["Reference: AB12", "Topic: Problem"]}`: a few short lines in a box.
    * `{:facts, [{"Label", "value"}, {"Open", {:link, url}}]}`: rows of a label and a value; a value can be a link.
    * `{:quote, "Your message:", text}`: the words of a visitor, kept as they were written (the label can be `nil`).
      They are shown as plain text, never as links.
    * `{:links, "Heading", [{"Label", url}]}`: a short list of links, for what to do next.

  `footer` has the lines for the foot of the e-mail that say why it was sent. `language` is the language of the
  e-mail (`lang` of the HTML). The texts are written in that language by whoever builds the letter, with Gettext.
  """

  @enforce_keys [:subject, :heading]
  defstruct [:subject, :heading, :preheader, language: "en", blocks: [], footer: []]

  @type block ::
          {:text, String.t()}
          | {:button, String.t(), String.t()}
          | {:note, String.t()}
          | {:lines, [String.t()]}
          | {:facts, [{String.t(), String.t() | {:link, String.t()}}]}
          | {:quote, String.t() | nil, String.t()}
          | {:links, String.t(), [{String.t(), String.t()}]}

  @type t :: %__MODULE__{
          subject: String.t(),
          heading: String.t(),
          preheader: String.t() | nil,
          language: String.t(),
          blocks: [block()],
          footer: [String.t()]
        }
end
