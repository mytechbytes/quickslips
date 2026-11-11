defmodule QuickSlipsWeb.StampLive.Index do
  @moduledoc """
  The user's stamps: the pictures of a revenue stamp to choose from on a receipt that has a place for one. Add one under a short
  name, and delete the ones that are not needed. (A bill's page can save one too, without leaving the bill.)
  """
  use QuickSlipsWeb, :live_view

  # A live navigation does not run the router's plugs, so the login is checked here too.
  on_mount {QuickSlipsWeb.UserAuth, :require_authenticated}

  import QuickSlipsWeb.ImageComponents

  alias QuickSlips.Stamps
  alias QuickSlips.Stamps.Stamp
  alias QuickSlips.Uploads
  alias QuickSlipsWeb.UploadController

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} locale={@locale} active={:stamps}>
      <.header>
        Stamps
        <:subtitle>
          Saved once, then chosen on any receipt that has a place for a revenue stamp. You can keep up to {@max}.
        </:subtitle>
      </.header>

      <.form
        :if={@count < @max}
        for={@form}
        id="stamp-form"
        phx-change="validate"
        phx-submit="save"
        class="mb-8 max-w-2xl"
      >
        <.input
          field={@form[:name]}
          type="text"
          label="Name"
          placeholder="For example: Rent receipts"
          maxlength={Stamp.max_name_length()}
          autocomplete="off"
        />
        <.image_field
          id="stamp-field"
          kind="stamp"
          label="Picture"
          upload={@uploads.stamp}
        />
        <.rights_check id="stamp-rights" name="stamp[rights]" checked={@rights} />
        <.button phx-disable-with="Saving..." variant="primary">Save stamp</.button>
      </.form>
      <p :if={@count >= @max} id="stamp-limit" class="mb-8 text-sm/6 text-ink-muted">
        You have saved {@max} stamps, the most you can keep. Delete one to add another.
      </p>

      <.table id="stamps" rows={@streams.stamps}>
        <:col :let={{_id, stamp}} label="Picture">
          <img
            src={UploadController.path(stamp.path)}
            alt={stamp.name}
            class="h-12 max-w-40 object-contain"
          />
        </:col>
        <:col :let={{_id, stamp}} label="Name">{stamp.name}</:col>
        <:action :let={{id, stamp}}>
          <.link
            id={"delete-#{id}"}
            phx-click={JS.push("delete", value: %{id: stamp.id}) |> hide("##{id}")}
            data-confirm="Delete this stamp? Documents in your history that used it will be made without it."
          >
            Delete
          </.link>
        </:action>
      </.table>
      <p :if={@count == 0} id="no-stamps" class="mt-4 text-sm/6 text-ink-muted">
        No stamps yet. Add your first one above.
      </p>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    if connected?(socket), do: Stamps.subscribe_stamps(scope)

    {:ok,
     socket
     |> assign(:page_title, "Stamps")
     |> assign(:rights, false)
     |> assign(:max, Stamps.max_per_user())
     |> allow_upload(:stamp,
       accept: ~w(.png .jpg .jpeg),
       max_entries: 1,
       max_file_size: Uploads.max_file_size()
     )
     |> assign_form(%{})
     |> load_stamps()}
  end

  defp new_stamp(scope), do: %Stamp{user_id: scope.user.id}

  defp assign_form(socket, params) do
    scope = socket.assigns.current_scope
    socket = assign(socket, :rights, params["rights"] == "true")
    changeset = Stamps.change_stamp(scope, new_stamp(scope), params)
    assign(socket, :form, to_form(changeset, as: :stamp, action: :validate))
  end

  defp load_stamps(socket) do
    stamps = Stamps.list_stamps(socket.assigns.current_scope)

    socket
    |> assign(:count, length(stamps))
    |> stream(:stamps, stamps, reset: true)
  end

  @impl true
  def handle_event("validate", %{"stamp" => params}, socket) do
    {:noreply, assign_form(socket, params)}
  end

  def handle_event("save", %{"stamp" => params}, socket) do
    scope = socket.assigns.current_scope

    cond do
      not Stamps.change_stamp(scope, new_stamp(scope), params).valid? ->
        {:noreply, assign_form(socket, params)}

      Enum.any?(socket.assigns.uploads.stamp.entries, &(not &1.valid?)) ->
        {:noreply,
         put_flash(socket, :error, "Remove the file that was rejected, or choose another.")}

      params["rights"] != "true" ->
        {:noreply, put_flash(socket, :error, rights_message())}

      socket.assigns.uploads.stamp.entries == [] ->
        {:noreply, put_flash(socket, :error, "Choose a picture of the stamp first.")}

      true ->
        save(socket, params)
    end
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :stamp, ref)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    {:ok, _stamp} = Stamps.delete_stamp(scope, Stamps.get_stamp!(scope, id))
    {:noreply, load_stamps(socket)}
  end

  defp save(socket, params) do
    scope = socket.assigns.current_scope

    results =
      consume_uploaded_entries(socket, :stamp, fn %{path: tmp}, _entry ->
        case Stamps.create_stamp(scope, params, tmp) do
          # The name was taken meanwhile: the file stays chosen, so only the name needs to change.
          {:error, %Ecto.Changeset{}} = taken -> {:postpone, taken}
          other -> {:ok, other}
        end
      end)

    case results do
      [{:ok, _stamp}] ->
        {:noreply,
         socket
         |> put_flash(:info, "Stamp saved.")
         |> assign_form(%{})
         |> load_stamps()}

      [{:error, %Ecto.Changeset{} = changeset}] ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :stamp, action: :validate))}

      [{:error, :limit_reached}] ->
        {:noreply, put_flash(socket, :error, "You can keep up to #{socket.assigns.max} stamps.")}

      [{:error, reason}] ->
        {:noreply, put_flash(socket, :error, rejection_message("stamp", reason))}
    end
  end

  # A stamp was saved or deleted in another tab, or from a bill.
  @impl true
  def handle_info({type, %Stamp{}}, socket) when type in [:created, :deleted] do
    {:noreply, load_stamps(socket)}
  end
end
