defmodule QuickSlipsWeb.DashboardLive do
  use QuickSlipsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Dashboard")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="dashboard" class="mx-auto max-w-3xl px-4 py-10">
        <h1 class="text-2xl font-semibold">Dashboard</h1>
        <p class="mt-2 text-base-content/70">Signed in as {@current_scope.user.email}</p>
      </div>
    </Layouts.app>
    """
  end
end
