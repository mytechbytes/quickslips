defmodule QuickSlips.Mail.ThemeTest do
  use ExUnit.Case, async: true

  alias QuickSlips.Mail.Theme

  # E-mail programs cannot read `oklch(...)` or CSS variables, so the colours of the e-mails are hex values copied from
  # assets/css/theme.css (QuickSlips.Mail.Theme). This test reads theme.css, converts what it says into hex the way a
  # browser does, and compares: when the theme changes and the e-mails do not follow, it fails and names the colour.

  @css File.read!(Path.expand("../../../assets/css/theme.css", __DIR__))

  # `{name => {r, g, b}}` for the `--name: oklch(...)` lines of the block that `selector` opens.
  defp theme_colours(selector) do
    [_, body] = Regex.run(selector, @css)

    ~r/--([a-z-]+):\s*oklch\(([\d.]+)%\s+([\d.]+)\s+([\d.]+)\)/
    |> Regex.scan(body)
    |> Map.new(fn [_line, name, l, c, h] ->
      {name, oklch_to_rgb(number(l) / 100, number(c), number(h))}
    end)
  end

  defp number(text), do: text |> Float.parse() |> elem(0)

  # OKLCH to OKLab to linear sRGB to sRGB, as in CSS Color 4; out-of-range values are cut to the edge.
  defp oklch_to_rgb(l, c, h) do
    a = c * :math.cos(h * :math.pi() / 180)
    b = c * :math.sin(h * :math.pi() / 180)

    l3 = :math.pow(l + 0.3963377774 * a + 0.2158037573 * b, 3)
    m3 = :math.pow(l - 0.1055613458 * a - 0.0638541728 * b, 3)
    s3 = :math.pow(l - 0.0894841775 * a - 1.2914855480 * b, 3)

    [
      4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3,
      -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3,
      -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3
    ]
    |> Enum.map(&encode/1)
    |> List.to_tuple()
  end

  defp encode(linear) do
    linear = min(max(linear, 0.0), 1.0)

    value =
      if linear <= 0.0031308, do: 12.92 * linear, else: 1.055 * :math.pow(linear, 1 / 2.4) - 0.055

    round(value * 255)
  end

  defp hex_to_rgb("#" <> hex) do
    <<r::binary-2, g::binary-2, b::binary-2>> = hex
    {String.to_integer(r, 16), String.to_integer(g, 16), String.to_integer(b, 16)}
  end

  # One step in a channel is below what anybody sees, and the two computations may round differently at the edge.
  defp assert_same_colour(name, email, theme) do
    {er, eg, eb} = hex_to_rgb(email)
    {tr, tg, tb} = theme

    assert abs(er - tr) <= 1 and abs(eg - tg) <= 1 and abs(eb - tb) <= 1,
           "#{name} is #{email} in the e-mails but theme.css says #{inspect(theme)} (as r, g, b)"
  end

  # The block of theme.css that has the colours of a mode.
  defp selector(:light), do: ~r/:root,\s*\[data-theme="light"\]\s*\{(.*?)\n\}/s
  defp selector(:dark), do: ~r/\[data-theme="dark"\]\s*\{(.*?)\n\}/s

  for mode <- [:light, :dark] do
    test "the #{mode} colours of the e-mails are the ones of theme.css" do
      theme = theme_colours(selector(unquote(mode)))
      mode_colours = apply(Theme, unquote(mode), [])

      for {colour, token} <- Theme.tokens() do
        assert Map.has_key?(theme, token), "theme.css has no --#{token}"

        assert_same_colour(
          "#{colour} (--#{token})",
          Map.fetch!(mode_colours, colour),
          theme[token]
        )
      end
    end
  end

  test "every colour has a light and a dark value" do
    assert Map.keys(Theme.light()) |> Enum.sort() == Map.keys(Theme.dark()) |> Enum.sort()
    assert Map.keys(Theme.light()) |> Enum.sort() == Map.keys(Theme.tokens()) |> Enum.sort()
  end
end
