defmodule QuickSlips.Mail.TextTest do
  use ExUnit.Case, async: true

  alias QuickSlips.Mail.{Letter, Text}

  # The plain-text version says what the HTML says. It is what a reader sees whose program shows no HTML, and what a
  # spam filter holds next to the HTML.

  @frame %{
    site_url: "https://quickslips.example",
    logo_url: "https://quickslips.example/images/email/logo.png",
    tagline: "Bills and receipts, ready in seconds",
    link_hint: "Or copy and paste this link into your browser:",
    reply_line: "Questions? Reply to this email and a person will read it.",
    links: [
      {"Contact", "https://quickslips.example/contact"},
      {"Privacy", "https://quickslips.example/privacy"}
    ]
  }

  test "prints the name, the heading, every kind of block and the foot, in order" do
    letter = %Letter{
      subject: "Subject",
      heading: "Confirm your email address",
      blocks: [
        {:text, "Hello,"},
        {:button, "Confirm my account", "https://quickslips.example/users/log-in/TOKEN"},
        {:note, "The link works once."},
        {:lines, ["Reference: AB12", "Topic: Problem"]},
        {:facts,
         [{"Reference", "AB12"}, {"Open", {:link, "https://quickslips.example/admin/messages/1"}}]},
        {:quote, "Your message:", "First\nSecond"},
        {:links, "Make your first bill",
         [{"Fuel Bill", "https://quickslips.example/en-in/fuel-bill-generator"}]}
      ],
      footer: ["You are receiving this email because person@example.com was used."]
    }

    assert Text.render(letter, @frame) == """
           QuickSlips

           Confirm your email address

           Hello,

           Confirm my account
           https://quickslips.example/users/log-in/TOKEN

           The link works once.

           Reference: AB12
           Topic: Problem

           Reference: AB12
           Open:      https://quickslips.example/admin/messages/1

           Your message:
           ----------------------------------------
           First
           Second
           ----------------------------------------

           Make your first bill
           - Fuel Bill: https://quickslips.example/en-in/fuel-bill-generator

           --
           QuickSlips · https://quickslips.example
           Bills and receipts, ready in seconds
           Contact: https://quickslips.example/contact
           Privacy: https://quickslips.example/privacy

           You are receiving this email because person@example.com was used.
           Questions? Reply to this email and a person will read it.\
           """
  end

  test "has no blank line at the end of the foot when there is nothing to say in it" do
    letter = %Letter{subject: "S", heading: "H", blocks: [{:text, "T"}]}
    text = Text.render(letter, %{@frame | reply_line: nil})

    assert String.ends_with?(text, "Privacy: https://quickslips.example/privacy")
  end

  test "writes a quote without a label as the words between two rules" do
    letter = %Letter{subject: "S", heading: "H", blocks: [{:quote, nil, "Words"}]}

    assert Text.render(letter, @frame) =~
             "H\n\n----------------------------------------\nWords\n----------------------------------------\n"
  end
end
