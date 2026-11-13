defmodule QuickSlipsWeb.ConsentTest do
  use QuickSlipsWeb.ConnCase, async: true

  # Every visitor is asked before Google Analytics starts, wherever they are. The server only draws the banner; the
  # choice is made in the browser (assets/js/consent.ts), which these tests cannot see.

  defp page(conn, path, country \\ nil) do
    conn = if country, do: put_req_header(conn, "cf-ipcountry", country), else: conn
    conn |> get(path) |> html_response(200) |> LazyHTML.from_document()
  end

  defp present?(doc, selector), do: doc |> LazyHTML.query(selector) |> Enum.any?()

  defp text(doc, selector),
    do: doc |> LazyHTML.query(selector) |> LazyHTML.text() |> String.trim()

  test "every visitor is asked, whichever country they come from: the banner is on the page, hidden until the script shows it",
       %{conn: conn} do
    for country <- [nil, "IN", "DE", "US", "XX", ""] do
      doc = page(conn, ~p"/en-in", country)

      assert present?(doc, "section#consent-banner[hidden]"), inspect(country)
    end
  end

  test "is on every page that has the layout of the site", %{conn: conn} do
    for path <- [
          ~p"/en-in",
          ~p"/hi-in",
          ~p"/privacy",
          ~p"/terms",
          ~p"/sitemap",
          ~p"/users/log-in"
        ] do
      assert present?(page(conn, path), "#consent-banner"), path
    end
  end

  test "has what the script looks for, and a way to the privacy policy", %{conn: conn} do
    doc = page(conn, ~p"/en-in")

    assert present?(doc, "#consent-banner button#consent-accept[data-consent-accept]")
    assert present?(doc, "#consent-banner button#consent-reject[data-consent-reject]")
    assert present?(doc, "#consent-banner a[href='/privacy']")
    assert present?(doc, "#consent-banner[aria-labelledby='consent-title'] #consent-title")
  end

  test "gets both answers alike: saying no is as easy as saying yes", %{conn: conn} do
    doc = page(conn, ~p"/en-in")
    class = fn id -> doc |> LazyHTML.query("##{id}") |> LazyHTML.attribute("class") end

    assert [_one_class] = class.("consent-accept")
    assert class.("consent-accept") == class.("consent-reject")
  end

  test "is in the language of the page", %{conn: conn} do
    for {path, accept, reject} <- [
          {~p"/en-in", "Accept", "Reject"},
          {~p"/es-es", "Aceptar", "Rechazar"},
          {~p"/hi-in", "स्वीकार करें", "अस्वीकार करें"}
        ] do
      doc = page(conn, path)

      assert text(doc, "#consent-accept") == accept, path
      assert text(doc, "#consent-reject") == reject, path
    end
  end

  test "the footer has the button that opens the choice again, in the language of the page", %{
    conn: conn
  } do
    assert text(page(conn, ~p"/en-in"), "#footer-site button[data-consent-open]") ==
             "Cookie settings"

    assert text(page(conn, ~p"/es-es"), "#footer-site button[data-consent-open]") ==
             "Configuración de cookies"
  end
end
