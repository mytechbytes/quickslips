defmodule QuickSlips.Mail.Theme do
  @moduledoc """
  The colours and the font of the e-mails.

  The site takes its colours from `assets/css/theme.css`, written as `oklch(...)` values and used through CSS
  variables. E-mail programs understand neither, so here the same colours are plain hex values: one set for a light
  inbox and one for a dark one. `QuickSlips.Mail.ThemeTest` converts the values of `theme.css` and compares them with
  these, so a change of the theme that is not copied here is found by `mix test`.

  `tokens/0` says which variable of `theme.css` each colour here comes from.
  """

  @light %{
    page: "#faf7f0",
    card: "#fefdfa",
    muted: "#f2efe7",
    ink: "#161c19",
    ink_muted: "#46504a",
    ink_faint: "#636b66",
    line: "#e4e1d8",
    primary: "#187a60",
    on_primary: "#f7fefb",
    primary_soft: "#dff9ef",
    band: "#01291d",
    on_band: "#e0f0e8",
    accent: "#ec7c27"
  }

  @dark %{
    page: "#0c110e",
    card: "#141a17",
    muted: "#1c2420",
    ink: "#f0eee9",
    ink_muted: "#b3b1a9",
    ink_faint: "#918f87",
    line: "#2a332e",
    primary: "#41c4a0",
    on_primary: "#011e16",
    primary_soft: "#0c362a",
    band: "#002016",
    on_band: "#dcece4",
    accent: "#f28e42"
  }

  # The variable of theme.css that each colour is.
  @tokens %{
    page: "page",
    card: "surface",
    muted: "surface-muted",
    ink: "ink",
    ink_muted: "ink-muted",
    ink_faint: "ink-faint",
    line: "line",
    primary: "primary",
    on_primary: "on-primary",
    primary_soft: "primary-soft",
    band: "sidebar",
    on_band: "on-sidebar",
    accent: "accent"
  }

  # The system fonts, like the site. The names with a space are not in quotes, which CSS allows, so that the
  # list can sit in a `style="..."` attribute as it is.
  @font "-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Helvetica Neue,Arial,Noto Sans,sans-serif"

  @doc "The colours for a light inbox."
  def light, do: @light

  @doc "The colours for a dark inbox (an e-mail program that asks for them with `prefers-color-scheme`)."
  def dark, do: @dark

  @doc "Which variable of `theme.css` each colour is: `%{ink_muted: \"ink-muted\", ...}`."
  def tokens, do: @tokens

  @doc "The font stack, ready for a `font-family:` rule."
  def font, do: @font
end
