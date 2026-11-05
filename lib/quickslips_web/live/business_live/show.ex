defmodule QuickSlipsWeb.BusinessLive.Show do
  use QuickSlipsWeb, :live_view

  alias QuickSlips.Businesses

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Business {@business.id}
        <:subtitle>This is a business record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/businesses"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/businesses/#{@business}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit business
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@business.name}</:item>
        <:item title="Address">{@business.address}</:item>
        <:item title="Gstin">{@business.gstin}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Businesses.subscribe_businesses(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Show Business")
     |> assign(:business, Businesses.get_business!(socket.assigns.current_scope, id))}
  end

  @impl true
  def handle_info(
        {:updated, %QuickSlips.Businesses.Business{id: id} = business},
        %{assigns: %{business: %{id: id}}} = socket
      ) do
    {:noreply, assign(socket, :business, business)}
  end

  def handle_info(
        {:deleted, %QuickSlips.Businesses.Business{id: id}},
        %{assigns: %{business: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "The current business was deleted.")
     |> push_navigate(to: ~p"/businesses")}
  end

  def handle_info({type, %QuickSlips.Businesses.Business{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end
end
