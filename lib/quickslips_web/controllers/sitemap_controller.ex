defmodule QuickSlipsWeb.SitemapController do
  @moduledoc "`/sitemap.xml`: every public page with its alternates in other languages (see `QuickSlipsWeb.Sitemap`)."
  use QuickSlipsWeb, :controller

  def show(conn, _params) do
    conn
    |> put_resp_content_type("application/xml")
    # The pages change only with a new release, so a crawler may keep the answer for an hour.
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(200, QuickSlipsWeb.Sitemap.xml())
  end
end
