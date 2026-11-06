defmodule QuickSlipsWeb.BrandTest do
  use QuickSlipsWeb.ConnCase

  import Phoenix.LiveViewTest

  # The files the logo and the favicon are made of live in priv/static, and the layout points at them.
  describe "the favicon" do
    test "every page links the icons, and the files exist", %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)

      hrefs =
        html
        |> LazyHTML.from_document()
        |> LazyHTML.query(~s(link[rel="icon"], link[rel="apple-touch-icon"]))
        |> LazyHTML.attribute("href")

      assert length(hrefs) == 3
      assert Enum.any?(hrefs, &String.starts_with?(&1, "/favicon.ico"))
      assert Enum.any?(hrefs, &String.starts_with?(&1, "/images/favicon.svg"))
      assert Enum.any?(hrefs, &String.starts_with?(&1, "/images/apple-touch-icon.png"))

      for href <- hrefs do
        path = href |> URI.parse() |> Map.fetch!(:path)
        assert File.exists?(Path.join("priv/static", path)), "#{path} is linked but missing"
      end
    end

    test "favicon.ico holds the 16, 32 and 48 pixel icons" do
      <<0::16-little, 1::16-little, count::16-little, directory::binary>> =
        File.read!("priv/static/favicon.ico")

      sizes =
        for n <- 0..(count - 1) do
          <<width, height, _rest::binary>> = binary_part(directory, n * 16, 16)
          {width, height}
        end

      assert sizes == [{16, 16}, {32, 32}, {48, 48}]
    end

    test "the touch icon is 180 pixels square" do
      <<"\x89PNG\r\n\x1a\n", _length::32, "IHDR", width::32, height::32, _rest::binary>> =
        File.read!("priv/static/images/apple-touch-icon.png")

      assert {width, height} == {180, 180}
    end

    test "the logo files are SVG" do
      for file <- ~w(logo.svg logo-on-dark.svg logo-mark.svg favicon.svg) do
        assert File.read!("priv/static/images/#{file}") =~ "<svg"
      end
    end
  end

  describe "the logo" do
    test "the header of the public pages shows the mark next to the name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, ~s(#logo img[src^="/images/logo-mark.svg"]))
      assert has_element?(view, "#logo", "QuickSlips")
    end
  end
end
