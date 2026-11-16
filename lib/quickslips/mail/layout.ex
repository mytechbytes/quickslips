defmodule QuickSlips.Mail.Layout do
  @moduledoc """
  The HTML of an e-mail, printed from a `QuickSlips.Mail.Letter`: the same frame for every e-mail of the site.

  An e-mail program is not a browser. Gmail, Outlook and Apple Mail each read a different part of HTML and CSS, so
  the page below is built the way e-mail has always been built, and it is the reason this file looks old-fashioned:

    * the layout is made of `<table>`s, not of `<div>`s with flex or grid, which Outlook does not understand;
    * every style is written on the element (`style="..."`), because some programs throw away the `<style>` of the
      head. The `<style>` only holds what cannot be inline: the dark version (`prefers-color-scheme`, with
      `!important` to win against the inline colour) and the rules for a narrow phone screen;
    * the colours are plain hex values (`QuickSlips.Mail.Theme`) and the font is a stack of system fonts;
    * the logo is a PNG on our own address, with an alt text that is styled, so that an inbox that blocks pictures
      still shows the name;
    * the first thing in the body is the *preheader*, a line that no one sees in the e-mail but that the inbox
      shows next to the subject. The invisible characters after it keep the first words of the e-mail out of it.

  The e-mail is 600 pixels wide at most and fills a phone. It has no script, no form, no tracking pixel and no
  picture besides the logo.
  """
  use Phoenix.Component

  alias QuickSlips.Mail.{Letter, Theme}

  # Characters that show nothing. They fill the preview line of the inbox, so that it does not go on with the first
  # words of the e-mail after the preheader.
  @filler String.duplicate("͏‌ ", 30)

  @doc """
  The HTML of `letter`, as a string. `frame` is what `QuickSlips.Mail` adds around every letter: the address of the
  site and of the logo, the words of the foot, and the link texts (they depend on the language).
  """
  def render(%Letter{} = letter, frame) do
    c = Theme.light()

    assigns = %{
      letter: letter,
      frame: frame,
      c: c,
      s: styles(c, Theme.font()),
      css: css(Theme.dark()),
      filler: @filler
    }

    ~H"""
    <!doctype html>
    <html lang={@letter.language} dir="ltr">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta http-equiv="X-UA-Compatible" content="IE=edge" />
        <meta name="x-apple-disable-message-reformatting" />
        <meta
          name="format-detection"
          content="telephone=no, date=no, address=no, email=no, url=no"
        />
        <meta name="color-scheme" content="light dark" />
        <meta name="supported-color-schemes" content="light dark" />
        <title>{@letter.subject}</title>
        <style phx-no-curly-interpolation>
          <%= Phoenix.HTML.raw(@css) %>
        </style>
      </head>
      <body class="bg-page" style={@s.body}>
        <div style="display:none;font-size:1px;line-height:1px;max-height:0;max-width:0;opacity:0;overflow:hidden;visibility:hidden;color:transparent;mso-hide:all;">
          {@letter.preheader || @letter.heading}{@filler}
        </div>
        <table
          role="presentation"
          class="bg-page"
          width="100%"
          cellpadding="0"
          cellspacing="0"
          border="0"
          bgcolor={@c.page}
        >
          <tr>
            <td align="center" class="outer" style="padding:24px 12px 32px;">
              <table
                role="presentation"
                class="container"
                width="600"
                cellpadding="0"
                cellspacing="0"
                border="0"
                style="width:600px;max-width:600px;"
              >
                <tr>
                  <td class="band px" bgcolor={@c.band} style={@s.band}>
                    <a href={@frame.site_url} target="_blank" style="text-decoration:none;">
                      <img
                        src={@frame.logo_url}
                        width="202"
                        height="43"
                        alt="QuickSlips"
                        style={@s.logo}
                      />
                    </a>
                  </td>
                </tr>
                <tr>
                  <td class="accent" height="3" bgcolor={@c.accent} style={@s.accent}>&nbsp;</td>
                </tr>
                <tr>
                  <td class="card bg-card bd-line px" bgcolor={@c.card} style={@s.card}>
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td>
                          <h1 class="t-ink" style={@s.h1}>{@letter.heading}</h1>
                        </td>
                      </tr>
                      <.block
                        :for={block <- @letter.blocks}
                        block={block}
                        frame={@frame}
                        c={@c}
                        s={@s}
                      />
                    </table>
                  </td>
                </tr>
                <.foot letter={@letter} frame={@frame} s={@s} />
              </table>
            </td>
          </tr>
        </table>
      </body>
    </html>
    """
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
    |> strip_root_markers()
  end

  # The application asks the template engine to mark the root tag of every template with `phx-r` (`root_tag_attribute`
  # in config.exs, which the pages of the site use). It means nothing in an e-mail, so it is taken out of the tags. The
  # pattern needs the `<tag` before it, so a visitor who writes "phx-r" in a message is not touched (text is escaped,
  # so it cannot contain a tag).
  defp strip_root_markers(html), do: String.replace(html, ~r/<(\w+) phx-r(?=[\s>])/, "<\\1")

  ## The blocks of a letter, one clause each

  defp block(%{block: {:text, text}} = assigns) do
    assigns = assign(assigns, :text, text)

    ~H"""
    <tr>
      <td class="t-muted" style={@s.p}>{@text}</td>
    </tr>
    """
  end

  # The button is a table cell with a colour, so that it is also a button in Outlook, with the link inside it. The
  # address is written under it for the reader whose program does not show buttons or whose button does not work.
  defp block(%{block: {:button, label, url}} = assigns) do
    assigns = assign(assigns, label: label, url: url)

    ~H"""
    <tr>
      <td align="center" style="padding:8px 0 16px;">
        <table role="presentation" class="btn-table" cellpadding="0" cellspacing="0" border="0">
          <tr>
            <td class="bg-primary" align="center" bgcolor={@c.primary} style={@s.button_cell}>
              <a href={@url} target="_blank" class="btn-link t-on-primary" style={@s.button}>
                {@label}
              </a>
            </td>
          </tr>
        </table>
      </td>
    </tr>
    <tr>
      <td class="t-faint" style={@s.hint}>
        {@frame.link_hint}<br />
        <a href={@url} target="_blank" class="t-link" style={@s.hint_link}>{@url}</a>
      </td>
    </tr>
    """
  end

  defp block(%{block: {:note, text}} = assigns) do
    assigns = assign(assigns, :text, text)

    ~H"""
    <tr>
      <td style="padding:0 0 20px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
          <tr>
            <td class="bg-soft t-ink" bgcolor={@c.primary_soft} style={@s.note}>{@text}</td>
          </tr>
        </table>
      </td>
    </tr>
    """
  end

  defp block(%{block: {:lines, lines}} = assigns) do
    assigns = assign(assigns, :lines, lines)

    ~H"""
    <tr>
      <td style="padding:0 0 20px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
          <tr>
            <td class="bg-muted t-ink" bgcolor={@c.muted} style={@s.box}>
              <div :for={line <- @lines}>{line}</div>
            </td>
          </tr>
        </table>
      </td>
    </tr>
    """
  end

  defp block(%{block: {:facts, rows}} = assigns) do
    assigns = assign(assigns, :rows, rows)

    ~H"""
    <tr>
      <td style="padding:0 0 14px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
          <tr :for={{label, value} <- @rows}>
            <td valign="top" class="t-faint" style={@s.fact_label}>{label}</td>
            <td valign="top" class="t-ink" style={@s.fact_value}>
              <%= case value do %>
                <% {:link, url} -> %>
                  <a href={url} target="_blank" class="t-link" style={@s.hint_link}>{url}</a>
                <% text -> %>
                  {text}
              <% end %>
            </td>
          </tr>
        </table>
      </td>
    </tr>
    """
  end

  # The words of a visitor. Each line is its own element (a blank line is a non-breaking space, so that it keeps its
  # height), and everything is escaped like any other text: nothing the visitor typed becomes a link or a tag.
  defp block(%{block: {:quote, label, text}} = assigns) do
    assigns = assign(assigns, label: label, lines: lines(text))

    ~H"""
    <tr>
      <td style="padding:0 0 20px;">
        <div :if={@label} class="t-faint" style={@s.quote_label}>{@label}</div>
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
          <tr>
            <td class="bg-muted bd-primary t-ink" bgcolor={@c.muted} style={@s.quote}>
              <div :for={line <- @lines}>{line}</div>
            </td>
          </tr>
        </table>
      </td>
    </tr>
    """
  end

  defp block(%{block: {:links, heading, links}} = assigns) do
    assigns = assign(assigns, heading: heading, links: Enum.with_index(links))

    ~H"""
    <tr>
      <td class="bd-line" style={@s.next}>
        <div class="t-ink" style={@s.next_heading}>{@heading}</div>
        <div style={@s.next_links}>
          <%= for {{label, url}, index} <- @links do %>
            <span :if={index > 0} class="t-faint">·</span>
            <a href={url} target="_blank" class="t-link" style={@s.link}>{label}</a>
          <% end %>
        </div>
      </td>
    </tr>
    """
  end

  defp lines(text) do
    text
    |> String.split(~r/\R/u)
    |> Enum.map(fn
      "" -> " "
      line -> line
    end)
  end

  ## The foot: who we are, where to go, why this e-mail came

  defp foot(assigns) do
    ~H"""
    <tr>
      <td class="px" style={@s.foot}>
        <div class="t-ink" style={@s.foot_name}>QuickSlips</div>
        <div class="t-faint" style={@s.foot_text}>{@frame.tagline}</div>
        <div style={@s.foot_text <> "padding:10px 0 0;"}>
          <%= for {{label, url}, index} <- Enum.with_index(@frame.links) do %>
            <span :if={index > 0} class="t-faint">·</span>
            <a href={url} target="_blank" class="t-link" style={@s.link}>{label}</a>
          <% end %>
        </div>
        <div
          :for={line <- @letter.footer ++ List.wrap(@frame.reply_line)}
          class="t-faint"
          style={@s.foot_text <> "padding:12px 0 0;"}
        >
          {line}
        </div>
      </td>
    </tr>
    """
  end

  ## Styles

  # Every style of the page, written once and used inline. `c` is the set of light colours.
  defp styles(c, font) do
    base = "font-family:#{font};"

    %{
      body: "margin:0;padding:0;width:100%;background-color:#{c.page};",
      band: "background-color:#{c.band};padding:22px 32px;border-radius:10px 10px 0 0;",
      logo:
        base <>
          "display:block;width:202px;height:43px;border:0;outline:none;font-size:22px;line-height:43px;font-weight:bold;color:#{c.on_band};",
      accent:
        "background-color:#{c.accent};height:3px;line-height:3px;font-size:3px;mso-line-height-rule:exactly;",
      card:
        "background-color:#{c.card};padding:36px 32px 32px;border:1px solid #{c.line};border-top:0;border-radius:0 0 10px 10px;",
      h1:
        base <>
          "margin:0;padding:0 0 18px;font-size:24px;line-height:32px;font-weight:bold;color:#{c.ink};",
      p: base <> "padding:0 0 20px;font-size:16px;line-height:25px;color:#{c.ink_muted};",
      button_cell:
        "background-color:#{c.primary};border-radius:6px;mso-padding-alt:15px 36px 15px 36px;",
      button:
        base <>
          "display:inline-block;padding:15px 36px;font-size:16px;line-height:20px;font-weight:bold;color:#{c.on_primary};text-decoration:none;border-radius:6px;",
      hint:
        base <>
          "padding:0 0 24px;font-size:13px;line-height:20px;color:#{c.ink_faint};text-align:center;",
      hint_link: "color:#{c.primary};word-break:break-all;",
      note:
        base <>
          "background-color:#{c.primary_soft};border-radius:6px;padding:14px 16px;font-size:14px;line-height:21px;color:#{c.ink};",
      box:
        base <>
          "background-color:#{c.muted};border-radius:6px;padding:14px 16px;font-size:14px;line-height:22px;color:#{c.ink};",
      quote_label:
        base <> "padding:0 0 6px;font-size:13px;line-height:20px;color:#{c.ink_faint};",
      quote:
        base <>
          "background-color:#{c.muted};border-left:3px solid #{c.primary};border-radius:0 6px 6px 0;padding:14px 16px;font-size:15px;line-height:23px;color:#{c.ink};word-break:break-word;overflow-wrap:anywhere;",
      fact_label:
        base <>
          "padding:6px 16px 6px 0;font-size:13px;line-height:20px;color:#{c.ink_faint};white-space:nowrap;",
      fact_value:
        base <>
          "padding:6px 0;font-size:14px;line-height:20px;color:#{c.ink};word-break:break-word;",
      link: "color:#{c.primary};text-decoration:underline;",
      next: base <> "border-top:1px solid #{c.line};padding:20px 0 0;",
      next_heading:
        base <> "padding:0 0 8px;font-size:15px;line-height:22px;font-weight:bold;color:#{c.ink};",
      next_links: base <> "font-size:15px;line-height:26px;color:#{c.ink_faint};",
      foot: base <> "padding:24px 32px 0;text-align:center;",
      foot_name: "font-size:13px;line-height:20px;font-weight:bold;color:#{c.ink};",
      foot_text: "font-size:12px;line-height:18px;color:#{c.ink_faint};"
    }
  end

  # The `<style>` of the head: the dark version and the narrow screen. `d` is the set of dark colours.
  defp css(d) do
    """
    :root { color-scheme: light dark; supported-color-schemes: light dark; }
    body, table, td, a { -webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; }
    table, td { mso-table-lspace: 0pt; mso-table-rspace: 0pt; }
    img { -ms-interpolation-mode: bicubic; }
    @media (prefers-color-scheme: dark) {
      .bg-page { background-color: #{d.page} !important; }
      .bg-card { background-color: #{d.card} !important; }
      .bg-muted { background-color: #{d.muted} !important; }
      .bg-soft { background-color: #{d.primary_soft} !important; }
      .bg-primary { background-color: #{d.primary} !important; }
      .band { background-color: #{d.band} !important; }
      .accent { background-color: #{d.accent} !important; }
      .bd-line { border-color: #{d.line} !important; }
      .bd-primary { border-left-color: #{d.primary} !important; }
      .t-ink { color: #{d.ink} !important; }
      .t-muted { color: #{d.ink_muted} !important; }
      .t-faint { color: #{d.ink_faint} !important; }
      .t-link { color: #{d.primary} !important; }
      .t-on-primary { color: #{d.on_primary} !important; }
    }
    @media only screen and (max-width: 620px) {
      .outer { padding: 0 0 24px !important; }
      .container { width: 100% !important; max-width: 100% !important; }
      .band { border-radius: 0 !important; }
      .card { border-radius: 0 !important; border-left: 0 !important; border-right: 0 !important; }
      .px { padding-left: 20px !important; padding-right: 20px !important; }
      .btn-table { width: 100% !important; }
      .btn-link { display: block !important; }
    }
    """
  end
end
