defmodule QuickSlipsWeb.HealthController do
  use QuickSlipsWeb, :controller

  def show(conn, _params) do
    case Ecto.Adapters.SQL.query(QuickSlips.Repo, "SELECT 1", []) do
      {:ok, _} -> send_resp(conn, 200, "ok")
      _ -> send_resp(conn, 503, "database unavailable")
    end
  end
end
