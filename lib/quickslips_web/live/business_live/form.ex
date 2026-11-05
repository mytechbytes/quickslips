defmodule QuickSlipsWeb.BusinessLive.Form do
  use QuickSlipsWeb, :live_view

  alias QuickSlips.Businesses
  alias QuickSlips.Businesses.Business

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage business records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="business-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:address]} type="textarea" label="Address" />
        <.input field={@form[:gstin]} type="text" label="Gstin" />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Business</.button>
          <.button navigate={return_path(@current_scope, @return_to, @business)}>Cancel</.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    business = Businesses.get_business!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit Business")
    |> assign(:business, business)
    |> assign(:form, to_form(Businesses.change_business(socket.assigns.current_scope, business)))
  end

  defp apply_action(socket, :new, _params) do
    business = %Business{user_id: socket.assigns.current_scope.user.id}

    socket
    |> assign(:page_title, "New Business")
    |> assign(:business, business)
    |> assign(:form, to_form(Businesses.change_business(socket.assigns.current_scope, business)))
  end

  @impl true
  def handle_event("validate", %{"business" => business_params}, socket) do
    changeset =
      Businesses.change_business(
        socket.assigns.current_scope,
        socket.assigns.business,
        business_params
      )

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"business" => business_params}, socket) do
    save_business(socket, socket.assigns.live_action, business_params)
  end

  defp save_business(socket, :edit, business_params) do
    case Businesses.update_business(
           socket.assigns.current_scope,
           socket.assigns.business,
           business_params
         ) do
      {:ok, business} ->
        {:noreply,
         socket
         |> put_flash(:info, "Business updated successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, business)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_business(socket, :new, business_params) do
    case Businesses.create_business(socket.assigns.current_scope, business_params) do
      {:ok, business} ->
        {:noreply,
         socket
         |> put_flash(:info, "Business created successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, business)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(_scope, "index", _business), do: ~p"/businesses"
  defp return_path(_scope, "show", business), do: ~p"/businesses/#{business}"
end
