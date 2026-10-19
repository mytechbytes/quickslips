defmodule QuickSlipsWeb.PageController do
  use QuickSlipsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
