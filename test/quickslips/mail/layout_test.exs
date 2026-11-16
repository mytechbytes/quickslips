defmodule QuickSlips.Mail.LayoutTest do
  use ExUnit.Case, async: true

  alias QuickSlips.Mail.{Layout, Letter}

  # The HTML of an e-mail: what is in every one of them (the brand, the language, the foot), what must never be in
  # one (a script, a tracking pixel, a tag that came from a visitor), and that all text is escaped.

  @url "https://quickslips.example/users/log-in/TOKEN"

  @frame %{
    site_url: "https://quickslips.example",
    logo_url: "https://quickslips.example/images/email/logo.png",
    tagline: "Bills and receipts, ready in seconds",
    link_hint: "Or copy and paste this link into your browser:",
    reply_line: "Questions? Reply to this email and a person will read it.",
    links: [
      {"Contact", "https://quickslips.example/contact"},
      {"Privacy", "https://quickslips.example/privacy"},
      {"Terms", "https://quickslips.example/terms"}
    ]
  }

  defp letter(extra \\ []) do
    struct!(
      %Letter{
        language: "en",
        subject: "Confirm your QuickSlips account",
        preheader: "One step left: confirm your email address.",
        heading: "Confirm your email address",
        blocks: [
          {:text, "Hello,"},
          {:button, "Confirm my account", @url},
          {:note, "The link works once and for 15 minutes."},
          {:links, "Make your first bill",
           [{"Fuel Bill", "https://quickslips.example/en-in/fuel-bill-generator"}]}
        ],
        footer: ["You are receiving this email because person@example.com was used."]
      },
      extra
    )
  end

  defp html(letter \\ letter(), frame \\ @frame), do: Layout.render(letter, frame)
  defp document(html), do: LazyHTML.from_document(html)
  defp query(html, selector), do: html |> document() |> LazyHTML.query(selector)
  defp text(html, selector), do: html |> query(selector) |> LazyHTML.text()

  test "is a whole page in the language of the letter, with the subject as its title" do
    html = html(letter(language: "hi", subject: "अपना खाता पक्का करें"))

    assert String.starts_with?(html, "<!doctype html>")
    assert html =~ ~s(<html lang="hi" dir="ltr">)
    assert text(html, "title") == "अपना खाता पक्का करें"
  end

  test "has the logo, once, as its only picture" do
    html = html()

    assert [src] = html |> query("img") |> LazyHTML.attribute("src")
    assert src == @frame.logo_url
    assert html |> query("img") |> LazyHTML.attribute("alt") == ["QuickSlips"]
    assert html |> query("img") |> LazyHTML.attribute("width") == ["202"]
    assert html |> query("img") |> LazyHTML.attribute("height") == ["43"]
  end

  test "has no script, form, frame or style sheet to load, and no tracking pixel" do
    html = html()

    for selector <- ["script", "form", "iframe", "object", "link[rel=stylesheet]", "input"] do
      assert html |> query(selector) |> Enum.count() == 0, "found #{selector}"
    end

    # the one picture is the logo, and it is not one pixel wide
    refute html =~ ~r/<img[^>]+(width="1"|height="1")/
  end

  test "keeps the letter's words and the preheader that the inbox shows next to the subject" do
    html = html()

    assert text(html, "h1") == "Confirm your email address"
    assert text(html, "body") =~ "One step left: confirm your email address."
    assert text(html, "body") =~ "Hello,"
    assert text(html, "body") =~ "The link works once and for 15 minutes."
    assert html =~ "display:none"
  end

  test "has the heading of the letter as the preheader when there is none" do
    html = html(letter(preheader: nil))

    assert html |> query("body > div") |> Enum.at(0) |> LazyHTML.text() =~
             "Confirm your email address"
  end

  test "has a button that goes to the link, and the link in writing under it" do
    html = html()

    hrefs = html |> query("a") |> LazyHTML.attribute("href")
    assert Enum.count(hrefs, &(&1 == @url)) == 2
    assert text(html, "a.btn-link") =~ "Confirm my account"
    assert text(html, "body") =~ "Or copy and paste this link into your browser:"
    assert html |> query("a.btn-link") |> LazyHTML.attribute("href") == [@url]
  end

  test "ends with the name, the way to the site's pages, the reason for the e-mail and the invitation to reply" do
    html = html()

    assert text(html, "body") =~ "Bills and receipts, ready in seconds"

    assert text(html, "body") =~
             "You are receiving this email because person@example.com was used."

    assert text(html, "body") =~ "Questions? Reply to this email and a person will read it."

    hrefs = html |> query("a") |> LazyHTML.attribute("href")
    assert "https://quickslips.example/contact" in hrefs
    assert "https://quickslips.example/privacy" in hrefs
    assert "https://quickslips.example/terms" in hrefs
    # the logo leads to the site
    assert "https://quickslips.example" in hrefs
  end

  test "has no invitation to reply when the frame has none" do
    html = html(letter(), %{@frame | reply_line: nil})

    refute text(html, "body") =~ "Questions?"
  end

  test "has a list of links for what to do next" do
    html = html()

    assert text(html, "body") =~ "Make your first bill"

    assert "https://quickslips.example/en-in/fuel-bill-generator" in (html
                                                                      |> query("a")
                                                                      |> LazyHTML.attribute(
                                                                        "href"
                                                                      ))
  end

  test "has the dark colours and the narrow-screen rules in its head" do
    html = html()

    assert html =~ "@media (prefers-color-scheme: dark)"
    assert html =~ "@media only screen and (max-width: 620px)"
    assert html =~ ~s(<meta name="color-scheme" content="light dark">)
    assert html =~ ~s(<meta name="viewport")
  end

  test "is made of tables for the layout, with a role that says so" do
    html = html()

    assert html |> query("table") |> Enum.count() > 3

    assert html |> query("table[role=presentation]") |> Enum.count() ==
             html |> query("table") |> Enum.count()
  end

  test "leaves nothing of the template engine in the tags" do
    refute html() =~ "phx-"
  end

  test "stays far below the size at which Gmail cuts an e-mail off" do
    assert byte_size(html()) < 40_000
  end

  describe "text that comes from outside" do
    @hostile "<script>alert(1)</script> <b>bold</b> \"quoted\" & more"

    test "is escaped everywhere, so that it can never become a tag" do
      letter =
        letter(
          subject: @hostile,
          preheader: @hostile,
          heading: @hostile,
          blocks: [
            {:text, @hostile},
            {:button, @hostile, @url},
            {:note, @hostile},
            {:lines, [@hostile]},
            {:facts, [{@hostile, @hostile}]},
            {:quote, @hostile, @hostile},
            {:links, @hostile, [{@hostile, "https://quickslips.example/x"}]}
          ],
          footer: [@hostile]
        )

      html = html(letter, %{@frame | tagline: @hostile})

      assert html |> query("script") |> Enum.count() == 0
      assert html |> query("body b") |> Enum.count() == 0
      refute html =~ "<script>alert"
      assert html =~ "&lt;script&gt;alert(1)&lt;/script&gt;"
      assert text(html, "body") =~ @hostile
    end

    test "is a link only when the letter makes it one" do
      words = "Please see https://evil.example/pay and write to boss@evil.example\n\nThank you"
      html = html(letter(blocks: [{:quote, "Your message:", words}]))

      hrefs = html |> query("a") |> LazyHTML.attribute("href")
      refute Enum.any?(hrefs, &String.contains?(&1, "evil"))
      assert text(html, "body") =~ "https://evil.example/pay"
    end

    test "keeps its lines, and the empty one between them" do
      html = html(letter(blocks: [{:quote, nil, "First\n\nSecond"}]))

      lines = html |> query("td.bd-primary div") |> Enum.map(&LazyHTML.text/1)
      assert lines == ["First", " ", "Second"]
    end

    test "does not touch words that look like the marker of the template engine" do
      html = html(letter(blocks: [{:text, "I am phx-r and <phx-r> too"}]))

      assert text(html, "body") =~ "I am phx-r and <phx-r> too"
    end
  end

  describe "the blocks" do
    test "facts are rows of a label and a value, and a value can be a link" do
      html =
        html(
          letter(
            blocks: [
              {:facts,
               [
                 {"Reference", "AB12"},
                 {"Open", {:link, "https://quickslips.example/admin/messages/1"}}
               ]}
            ]
          )
        )

      assert text(html, "body") =~ "Reference"
      assert text(html, "body") =~ "AB12"

      assert "https://quickslips.example/admin/messages/1" in (html
                                                               |> query("a")
                                                               |> LazyHTML.attribute("href"))
    end

    test "lines are short lines in a box" do
      html = html(letter(blocks: [{:lines, ["Reference: AB12", "Topic: Problem"]}]))

      assert html |> query("td.bg-muted div") |> Enum.map(&LazyHTML.text/1) == [
               "Reference: AB12",
               "Topic: Problem"
             ]
    end

    test "a quote can have no label" do
      html = html(letter(blocks: [{:quote, nil, "Words"}]))

      assert html |> query("td.bd-primary") |> LazyHTML.text() =~ "Words"
    end
  end
end
