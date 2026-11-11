defmodule QuickSlipsWeb.BusinessLive.Form do
  use QuickSlipsWeb, :live_view

  # A live navigation does not run the router's plugs, so the login is checked here too.
  on_mount {QuickSlipsWeb.UserAuth, :require_authenticated}

  import QuickSlipsWeb.ImageComponents

  alias QuickSlips.Businesses
  alias QuickSlips.Businesses.Business
  alias QuickSlips.Signatures
  alias QuickSlips.Uploads

  # The uploads on this page, and the column of `businesses` each one fills. The signature is not one of them:
  # it is chosen from the library on the Signatures page.
  @images [logo: :logo_path]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} locale={@locale} active={:businesses}>
      <.header>
        {@page_title}
        <:subtitle>
          Saved once, then filled into any bill with one click. The logo and the default signature are drawn on the PDF.
        </:subtitle>
      </.header>

      <.form for={@form} id="business-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:address]} type="textarea" label="Address (optional)" />
        <.input field={@form[:gstin]} type="text" label="GSTIN (optional)" />
        <.image_field
          id="logo-field"
          kind="logo"
          label="Logo"
          upload={@uploads.logo}
          path={@business.logo_path}
        />
        <.rights_check id="logo-rights" name="business[logo_rights]" checked={@rights} />
        <.input
          field={@form[:signature_id]}
          type="select"
          label="Default signature"
          prompt="No default signature"
          options={Enum.map(@signatures, &{&1.name, &1.id})}
          help="Chosen for you when this business is picked on a bill. You can still change it there."
        />
        <p :if={@signatures == []} id="no-signatures" class="mb-4 text-sm/6 text-ink-muted">
          You have no saved signatures yet.
          <.link navigate={~p"/signatures"} class="font-medium text-primary hover:underline">
            Add one on the Signatures page
          </.link>
          or from any bill.
        </p>
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
     |> assign(:rights, false)
     |> allow_upload(:logo,
       accept: ~w(.png .jpg .jpeg),
       max_entries: 1,
       max_file_size: Uploads.max_file_size()
     )
     |> assign(:signatures, Signatures.list_signatures(socket.assigns.current_scope))
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
    socket = assign(socket, :rights, business_params["logo_rights"] == "true")

    changeset =
      Businesses.change_business(
        socket.assigns.current_scope,
        socket.assigns.business,
        business_params
      )

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"business" => business_params}, socket) do
    changeset =
      Businesses.change_business(
        socket.assigns.current_scope,
        socket.assigns.business,
        business_params
      )

    # The files are looked at only when the text fields are fine, so a typo in the GSTIN does not
    # throw away the pictures the user has already chosen.
    cond do
      # a picture that is uploaded must be one the user may use
      socket.assigns.uploads.logo.entries != [] and business_params["logo_rights"] != "true" ->
        {:noreply, socket |> assign(:rights, false) |> put_flash(:error, rights_message())}

      changeset.valid? ->
        case store_images(socket) do
          {:ok, images} ->
            save_business(socket, socket.assigns.live_action, business_params, images)

          {:error, message} ->
            {:noreply, put_flash(socket, :error, message)}
        end

      true ->
        {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
    end
  end

  def handle_event("cancel_upload", %{"upload" => upload, "ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, upload_name(upload), ref)}
  end

  def handle_event(
        "remove_image",
        %{"kind" => "logo"},
        %{assigns: %{live_action: :edit}} = socket
      ) do
    {:ok, business} =
      Businesses.remove_image(socket.assigns.current_scope, socket.assigns.business, :logo)

    {:noreply, assign(socket, :business, business)}
  end

  defp upload_name("logo"), do: :logo

  defp save_business(socket, :edit, business_params, images) do
    case Businesses.update_business(
           socket.assigns.current_scope,
           socket.assigns.business,
           business_params,
           images
         ) do
      {:ok, business} ->
        {:noreply,
         socket
         |> put_flash(:info, "Business updated successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, business)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        delete_stored(images)
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_business(socket, :new, business_params, images) do
    case Businesses.create_business(socket.assigns.current_scope, business_params, images) do
      {:ok, business} ->
        {:noreply,
         socket
         |> put_flash(:info, "Business created successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, business)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        delete_stored(images)
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(_scope, "index", _business), do: ~p"/businesses"
  defp return_path(_scope, "show", business), do: ~p"/businesses/#{business}"

  # Moves the chosen files into the user's private folder. Returns the paths to save,
  # `{:ok, %{logo_path: "12/ab12.png"}}`, or a message to show when a file is not a real picture.
  defp store_images(socket) do
    if Enum.any?(@images, fn {upload, _column} -> rejected_entry?(socket, upload) end) do
      {:error, "Some files were rejected. Remove them, or choose other files."}
    else
      user_id = socket.assigns.current_scope.user.id

      results =
        Enum.flat_map(@images, fn {upload, column} ->
          socket
          |> consume_uploaded_entries(upload, fn %{path: tmp}, _entry ->
            {:ok, Uploads.store(user_id, tmp)}
          end)
          |> Enum.map(&{upload, column, &1})
        end)

      case Enum.find(results, &match?({_upload, _column, {:error, _reason}}, &1)) do
        nil ->
          {:ok, Map.new(results, fn {_upload, column, {:ok, relative}} -> {column, relative} end)}

        {upload, _column, {:error, reason}} ->
          # Don't leave the other picture behind when this one failed.
          for {_upload, _column, {:ok, relative}} <- results, do: Uploads.delete(relative)
          {:error, rejection_message(upload, reason)}
      end
    end
  end

  # An entry LiveView has already refused (too big, wrong type) can't be consumed.
  defp rejected_entry?(socket, upload) do
    Enum.any?(socket.assigns.uploads[upload].entries, &(not &1.valid?))
  end

  defp delete_stored(images), do: images |> Map.values() |> Enum.each(&Uploads.delete/1)
end
