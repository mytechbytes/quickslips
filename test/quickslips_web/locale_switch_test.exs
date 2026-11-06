defmodule QuickSlipsWeb.LocaleSwitchTest do
  use ExUnit.Case, async: true

  alias QuickSlips.Locales
  alias QuickSlipsWeb.LocaleSwitch

  defp locale(code), do: Locales.fetch!(code)

  describe "safe_path/1" do
    test "keeps a path on this site, with its query" do
      assert LocaleSwitch.safe_path("/") == "/"
      assert LocaleSwitch.safe_path("/users/log-in") == "/users/log-in"

      assert LocaleSwitch.safe_path("/en-in/fuel-bill-generator?from=3") ==
               "/en-in/fuel-bill-generator?from=3"
    end

    test "refuses everything that could leave the site or split the header" do
      for path <- [
            "//evil.example",
            "///evil.example",
            "https://evil.example/",
            "http:evil.example",
            "javascript:alert(1)",
            "/\\evil.example",
            "/ok\r\nSet-Cookie: x=1",
            "/ok\nLocation: https://evil.example",
            "/ok\0",
            "",
            "relative/path",
            nil,
            42,
            %{}
          ] do
        assert LocaleSwitch.safe_path(path) == nil, "#{inspect(path)} was accepted"
      end
    end

    test "refuses a path that is too long" do
      assert LocaleSwitch.safe_path("/" <> String.duplicate("a", 2_001)) == nil
      assert LocaleSwitch.safe_path("/" <> String.duplicate("a", 1_999)) != nil
    end
  end

  describe "target/2" do
    test "a bill goes to the same bill in the new locale, with its query" do
      assert LocaleSwitch.target("/en-in/fuel-bill-generator", locale("hi-in")) ==
               {"/hi-in/fuel-bill-generator", :same}

      assert LocaleSwitch.target("/en-in/fuel-bill-generator", locale("es-es")) ==
               {"/es-es/generador-de-factura-de-gasolina", :same}

      assert LocaleSwitch.target(
               "/es-es/generador-de-factura-de-gasolina?from=12",
               locale("en-in")
             ) ==
               {"/en-in/fuel-bill-generator?from=12", :same}

      assert LocaleSwitch.target("/hi-in/fuel-bill-generator", locale("hi-in")) ==
               {"/hi-in/fuel-bill-generator", :same}
    end

    test "a bill that the new locale does not have goes to its catalogue, and says so" do
      assert LocaleSwitch.target("/en-in/rent-receipt-generator", locale("hi-in")) ==
               {"/hi-in", :unavailable}

      assert LocaleSwitch.target("/en-in/rent-receipt-generator?from=1", locale("es-es")) ==
               {"/es-es", :unavailable}
    end

    test "a slug that is not a bill in its own locale goes to the catalogue too" do
      assert LocaleSwitch.target("/en-in/generador-de-factura-de-gasolina", locale("hi-in")) ==
               {"/hi-in", :unavailable}

      assert LocaleSwitch.target("/es-mx/anything", locale("hi-in")) == {"/hi-in", :unavailable}
    end

    test "a catalogue goes to the catalogue of the new locale" do
      assert LocaleSwitch.target("/en-in", locale("es-es")) == {"/es-es", :same}
      assert LocaleSwitch.target("/hi-in?x=1", locale("en-in")) == {"/en-in", :same}
      assert LocaleSwitch.target("/es-mx", locale("en-in")) == {"/en-in", :same}
    end

    test "a deeper address under a locale goes to the catalogue" do
      assert LocaleSwitch.target("/en-in/a/b", locale("hi-in")) == {"/hi-in", :unavailable}
    end

    test "any other page stays where it is: the locale is not in its address" do
      for path <- [
            "/",
            "/users/log-in",
            "/users/settings?tab=1",
            "/history",
            "/businesses/3/edit",
            "/dashboard"
          ] do
        assert LocaleSwitch.target(path, locale("hi-in")) == {path, :same}
      end
    end
  end
end
