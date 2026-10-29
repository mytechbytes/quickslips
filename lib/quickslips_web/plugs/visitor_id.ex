defmodule QuickSlipsWeb.Plugs.VisitorId do
  @moduledoc "Gives every browser an anonymous, signed `vid` cookie and assigns `:visitor_id`."
  import Plug.Conn

  @cookie "vid"
  @max_age 60 * 60 * 24 * 365

  def init(opts), do: opts

  def call(conn, _opts) do
    conn = fetch_cookies(conn, signed: [@cookie])

    case conn.cookies[@cookie] do
      vid when is_binary(vid) and vid != "" ->
        assign(conn, :visitor_id, vid)

      _missing_or_tampered ->
        vid = Ecto.UUID.generate()

        conn
        |> put_resp_cookie(@cookie, vid,
          sign: true,
          max_age: @max_age,
          http_only: true,
          same_site: "Lax"
        )
        |> assign(:visitor_id, vid)
    end
  end
end
