defmodule QuickSlipsWeb.QuotaController do
  use QuickSlipsWeb, :controller

  alias QuickSlips.Downloads

  def show(conn, _params) do
    scope = conn.assigns[:current_scope]

    status = Downloads.status(%{
      user: scope && scope.user,
      visitor_id: conn.assigns.visitor_id,
      ip: conn.remote_ip |> :inet.ntoa() |> to_string()
    })

    json(conn, status)
  end
end
