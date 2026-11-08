defmodule QuickSlipsWeb.RobotsController do
  @moduledoc """
  `/robots.txt`: tells a crawler what it need not visit and where the sitemap is. It is a controller, not a file,
  because the address of the sitemap has to be the full one, and that is only known from the configuration of the
  site.

  What is kept out: the endpoints scripts call, the private pictures, the page sources the preview reads, the log-in
  and account pages, the pages of a logged-in user, and the contact form with a query (`/contact?topic=...&about=...`,
  which every bill page links to: the same page as many times as there are bills; `/contact` itself is open). The
  scripts and styles (`/assets`, `/fonts`, `/wasm`) are not in the list on purpose: a crawler that draws a page needs
  them.
  """
  use QuickSlipsWeb, :controller

  @disallowed ~w(/api/ /uploads/ /source/ /auth/ /users/ /dashboard /businesses /signatures /history /admin/ /dev/ /locale /healthz /contact?)

  def show(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(200, body())
  end

  @doc "The text of the file."
  def body do
    rules = for path <- @disallowed, do: "Disallow: #{path}\n"

    IO.iodata_to_binary([
      "User-agent: *\n",
      "Allow: /\n",
      rules,
      "\n",
      "Sitemap: #{QuickSlipsWeb.Endpoint.url()}/sitemap.xml\n"
    ])
  end
end
