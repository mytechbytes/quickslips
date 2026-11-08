defmodule QuickSlipsWeb.SitemapStylesheetTest do
  use QuickSlipsWeb.ConnCase

  alias QuickSlips.Locales
  alias QuickSlipsWeb.Seo

  # The XSLT that lets a browser draw `/sitemap.xml` as a page. Browsers are removing XSLT (Chrome stops running it
  # on 17 November 2026), so this is a bonus: the XML must stay right without it, and these tests say so too.

  @xsltproc System.find_executable("xsltproc")

  test "the XML names its stylesheet right after the declaration", %{conn: conn} do
    [declaration, instruction, root | _] =
      conn |> get(~p"/sitemap.xml") |> response(200) |> String.split("\n")

    assert declaration == ~s(<?xml version="1.0" encoding="UTF-8"?>)
    assert instruction == ~s(<?xml-stylesheet type="text/xsl" href="/sitemap.xsl"?>)
    assert root =~ "<urlset"
  end

  describe "/sitemap.xsl" do
    test "comes as XML, which is what a browser needs to run it, and sets no cookie", %{
      conn: conn
    } do
      conn = get(conn, "/sitemap.xsl")

      assert ["application/xslt+xml" <> _] = get_resp_header(conn, "content-type")
      assert get_resp_header(conn, "cache-control") == ["public, max-age=3600"]
      assert get_resp_header(conn, "set-cookie") == []
    end

    test "is the file in priv, as it was when the app was compiled", %{conn: conn} do
      assert conn |> get("/sitemap.xsl") |> response(200) == File.read!("priv/sitemap.xsl")
    end

    test "is a well-formed XSLT 1.0 stylesheet", %{conn: conn} do
      # xmerl wants the bytes of a UTF-8 document (the stylesheet has names in Hindi, Chinese and Japanese)
      {root, _rest} =
        conn
        |> get("/sitemap.xsl")
        |> response(200)
        |> :binary.bin_to_list()
        |> :xmerl_scan.string(namespace_conformant: true)

      assert [stylesheet] =
               :xmerl_xpath.string(
                 ~c"/*[local-name()='stylesheet' and namespace-uri()='http://www.w3.org/1999/XSL/Transform']",
                 root
               )

      {:xmlElement, _, _, _, _, _, _, attributes, _, _, _, _} = stylesheet

      assert {:xmlAttribute, :version, _, _, _, _, _, _, ~c"1.0", _} =
               List.keyfind(attributes, :version, 1)
    end
  end

  # What the stylesheet makes of the real sitemap, drawn by libxslt, the engine of Chrome and Safari.
  @tag :tmp_dir
  @tag skip: if(@xsltproc, do: false, else: "xsltproc is not installed")
  test "turns the sitemap into a page grouped by language and country", %{
    conn: conn,
    tmp_dir: dir
  } do
    xml = Path.join(dir, "sitemap.xml")
    File.write!(xml, conn |> get(~p"/sitemap.xml") |> response(200))

    # looked up here and not in a module attribute: where xsltproc is missing (CI) that would be a nil the compiler
    # sees in a call to System.cmd/2, and `--warnings-as-errors` fails the run
    {html, 0} = System.cmd(System.find_executable("xsltproc"), ["priv/sitemap.xsl", xml])
    doc = LazyHTML.from_document(html)
    count = fn selector -> doc |> LazyHTML.query(selector) |> Enum.count() end

    # a group for each locale, a row for each page, and the catalogue of each locale marked
    assert count.("details.locale") == length(Locales.live())
    assert count.("li.page") == length(Seo.pages())
    assert count.(".tag") == length(Locales.live())

    # the head of the page says how much there is
    assert doc |> LazyHTML.query(".stats") |> LazyHTML.text() =~ "#{length(Seo.pages())}"

    # the groups carry the names of their locales, and the pages link to the pages
    assert doc |> LazyHTML.query("details.locale > summary") |> LazyHTML.text() =~
             "Español · Spain"

    assert doc
           |> LazyHTML.query("a.path[href$='/es-es/generador-de-factura-de-gasolina']")
           |> Enum.count() == 1

    # each page lists its versions, itself among them (the catalogue of the default locale is also x-default)
    [first | _] = doc |> LazyHTML.query("li.page") |> Enum.to_list()
    assert first |> LazyHTML.query("ul.alts li.self .lang") |> LazyHTML.text() =~ "en-IN"

    assert first |> LazyHTML.query("summary") |> LazyHTML.text() =~
             "#{length(Locales.live())} versions"
  end
end
