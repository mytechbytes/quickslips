defmodule QuickSlipsWeb.SitemapController do
  @moduledoc """
  `/sitemap.xml`: every public page with its alternates in other languages (see `QuickSlipsWeb.Sitemap`), and
  `/sitemap.xsl`, the stylesheet that lets a browser draw it as a page.

  The stylesheet is a controller and not a static file because `Plug.Static` would send a `.xsl` file as
  `application/octet-stream`, and a browser only runs a stylesheet that comes as XML. It is read when this module
  is compiled, so a release has no file to look for.
  """
  use QuickSlipsWeb, :controller

  @stylesheet_path Path.expand("../../../priv/sitemap.xsl", __DIR__)
  @external_resource @stylesheet_path
  @stylesheet File.read!(@stylesheet_path)

  def show(conn, _params) do
    conn
    |> put_resp_content_type("application/xml")
    # The pages change only with a new release, so a crawler may keep the answer for an hour.
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(200, QuickSlipsWeb.Sitemap.xml())
  end

  def stylesheet(conn, _params) do
    conn
    |> put_resp_content_type("application/xslt+xml")
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(200, @stylesheet)
  end
end
