defmodule QuickSlipsWeb.BusinessLive.Index do
  use QuickSlipsWeb, :live_view

  alias QuickSlips.Businesses

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:businesses}>
      <.header>
        Listing Businesses
        <:actions>
          <.button variant="primary" navigate={~p"/businesses/new"}>
            <.icon name="hero-plus" /> New Business
          </.button>
        </:actions>
      </.header>

      <.table
        id="businesses"
        rows={@streams.businesses}
        row_click={fn {_id, business} -> JS.navigate(~p"/businesses/#{business}") end}
      >
        <:col :let={{_id, business}} label="Name">{business.name}</:col>
        <:col :let={{_id, business}} label="Address">{business.address}</:col>
        <:col :let={{_id, business}} label="GSTIN">{business.gstin}</:col>
        <:action :let={{_id, business}}>
          <div class="sr-only">
            <.link navigate={~p"/businesses/#{business}"}>Show</.link>
          </div>
          <.link navigate={~p"/businesses/#{business}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, business}}>
          <.link
            phx-click={JS.push("delete", value: %{id: business.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Businesses.subscribe_businesses(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Listing Businesses")
     |> stream(:businesses, list_businesses(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    business = Businesses.get_business!(socket.assigns.current_scope, id)
    {:ok, _} = Businesses.delete_business(socket.assigns.current_scope, business)

    {:noreply, stream_delete(socket, :businesses, business)}
  end

  @impl true
  def handle_info({type, %QuickSlips.Businesses.Business{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply,
     stream(socket, :businesses, list_businesses(socket.assigns.current_scope), reset: true)}
  end

  defp list_businesses(current_scope) do
    Businesses.list_businesses(current_scope)
  end
end
