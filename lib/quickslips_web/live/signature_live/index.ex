defmodule QuickSlipsWeb.SignatureLive.Index do
  @moduledoc """
  The user's signatures: the pictures to choose from on a bill that has a place to sign. Add one under a short
  name, and delete the ones that are not needed. (A bill's page can save one too, without leaving the bill.)
  """
  use QuickSlipsWeb, :live_view

  # A live navigation does not run the router's plugs, so the login is checked here too.
  on_mount {QuickSlipsWeb.UserAuth, :require_authenticated}

  import QuickSlipsWeb.ImageComponents

  alias QuickSlips.Signatures
  alias QuickSlips.Signatures.Signature
  alias QuickSlips.Uploads
  alias QuickSlipsWeb.UploadController

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} locale={@locale} active={:signatures}>
      <.header>
        Signatures
        <:subtitle>
          Saved once, then chosen on any bill that has a place to sign. You can keep up to {@max}.
        </:subtitle>
      </.header>

      <.form
        :if={@count < @max}
        for={@form}
        id="signature-form"
        phx-change="validate"
        phx-submit="save"
        class="mb-8 max-w-2xl"
      >
        <.input
          field={@form[:name]}
          type="text"
          label="Name"
          placeholder="For example: Owner"
          maxlength={Signature.max_name_length()}
          autocomplete="off"
        />
        <.image_field
          id="signature-field"
          kind="signature"
          label="Picture"
          upload={@uploads.signature}
        />
        <.rights_check id="signature-rights" name="signature[rights]" checked={@rights} />
        <.button phx-disable-with="Saving..." variant="primary">Save signature</.button>
      </.form>
      <p :if={@count >= @max} id="signature-limit" class="mb-8 text-sm/6 text-ink-muted">
        You have saved {@max} signatures, the most you can keep. Delete one to add another.
      </p>

      <.table id="signatures" rows={@streams.signatures}>
        <:col :let={{_id, signature}} label="Picture">
          <img
            src={UploadController.path(signature.path)}
            alt={signature.name}
            class="h-12 max-w-40 object-contain"
          />
        </:col>
        <:col :let={{_id, signature}} label="Name">{signature.name}</:col>
        <:action :let={{id, signature}}>
          <.link
            id={"delete-#{id}"}
            phx-click={JS.push("delete", value: %{id: signature.id}) |> hide("##{id}")}
            data-confirm="Delete this signature? Documents in your history that used it will be made without it."
          >
            Delete
          </.link>
        </:action>
      </.table>
      <p :if={@count == 0} id="no-signatures" class="mt-4 text-sm/6 text-ink-muted">
        No signatures yet. Add your first one above.
      </p>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    if connected?(socket), do: Signatures.subscribe_signatures(scope)

    {:ok,
     socket
     |> assign(:page_title, "Signatures")
     |> assign(:rights, false)
     |> assign(:max, Signatures.max_per_user())
     |> allow_upload(:signature,
       accept: ~w(.png .jpg .jpeg),
       max_entries: 1,
       max_file_size: Uploads.max_file_size()
     )
     |> assign_form(%{})
     |> load_signatures()}
  end

  defp new_signature(scope), do: %Signature{user_id: scope.user.id}

  defp assign_form(socket, params) do
    scope = socket.assigns.current_scope
    socket = assign(socket, :rights, params["rights"] == "true")
    changeset = Signatures.change_signature(scope, new_signature(scope), params)
    assign(socket, :form, to_form(changeset, as: :signature, action: :validate))
  end

  defp load_signatures(socket) do
    signatures = Signatures.list_signatures(socket.assigns.current_scope)

    socket
    |> assign(:count, length(signatures))
    |> stream(:signatures, signatures, reset: true)
  end

  @impl true
  def handle_event("validate", %{"signature" => params}, socket) do
    {:noreply, assign_form(socket, params)}
  end

  def handle_event("save", %{"signature" => params}, socket) do
    scope = socket.assigns.current_scope

    cond do
      not Signatures.change_signature(scope, new_signature(scope), params).valid? ->
        {:noreply, assign_form(socket, params)}

      Enum.any?(socket.assigns.uploads.signature.entries, &(not &1.valid?)) ->
        {:noreply,
         put_flash(socket, :error, "Remove the file that was rejected, or choose another.")}

      params["rights"] != "true" ->
        {:noreply, put_flash(socket, :error, rights_message())}

      socket.assigns.uploads.signature.entries == [] ->
        {:noreply, put_flash(socket, :error, "Choose a picture of the signature first.")}

      true ->
        save(socket, params)
    end
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :signature, ref)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    {:ok, _signature} = Signatures.delete_signature(scope, Signatures.get_signature!(scope, id))
    {:noreply, load_signatures(socket)}
  end

  defp save(socket, params) do
    scope = socket.assigns.current_scope

    results =
      consume_uploaded_entries(socket, :signature, fn %{path: tmp}, _entry ->
        case Signatures.create_signature(scope, params, tmp) do
          # The name was taken meanwhile: the file stays chosen, so only the name needs to change.
          {:error, %Ecto.Changeset{}} = taken -> {:postpone, taken}
          other -> {:ok, other}
        end
      end)

    case results do
      [{:ok, _signature}] ->
        {:noreply,
         socket
         |> put_flash(:info, "Signature saved.")
         |> assign_form(%{})
         |> load_signatures()}

      [{:error, %Ecto.Changeset{} = changeset}] ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :signature, action: :validate))}

      [{:error, :limit_reached}] ->
        {:noreply,
         put_flash(socket, :error, "You can keep up to #{socket.assigns.max} signatures.")}

      [{:error, reason}] ->
        {:noreply, put_flash(socket, :error, rejection_message("signature", reason))}
    end
  end

  # A signature was saved or deleted in another tab, or from a bill.
  @impl true
  def handle_info({type, %Signature{}}, socket) when type in [:created, :deleted] do
    {:noreply, load_signatures(socket)}
  end
end
