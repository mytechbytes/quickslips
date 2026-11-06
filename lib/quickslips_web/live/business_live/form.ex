defmodule QuickSlipsWeb.BusinessLive.Form do
  use QuickSlipsWeb, :live_view

  alias QuickSlips.Businesses
  alias QuickSlips.Businesses.Business
  alias QuickSlips.Uploads
  alias QuickSlipsWeb.UploadController

  @max_file_size 1_000_000

  # The two uploads on this page, and the column of `businesses` each one fills.
  @images [logo: :logo_path, signature: :signature_path]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} locale={@locale} active={:businesses}>
      <.header>
        {@page_title}
        <:subtitle>
          Saved once, then filled into any bill with one click. The logo and the signature are drawn on the PDF.
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
        <.image_field
          id="signature-field"
          kind="signature"
          label="Signature"
          upload={@uploads.signature}
          path={@business.signature_path}
        />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Business</.button>
          <.button navigate={return_path(@current_scope, @return_to, @business)}>Cancel</.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  attr :id, :string, required: true
  attr :kind, :string, required: true, values: ~w(logo signature)
  attr :label, :string, required: true
  attr :upload, Phoenix.LiveView.UploadConfig, required: true
  attr :path, :string, default: nil, doc: "the stored image, when the business has one"

  # The drop zone from design/components/forms/uploads. The picture on the left is the file the
  # user just chose, else the one that is saved.
  defp image_field(assigns) do
    ~H"""
    <div id={@id} class="mb-4">
      <span class="mb-1 block text-sm/6 font-medium text-ink">{@label}</span>
      <div class="flex flex-col gap-3 sm:flex-row sm:items-stretch">
        <div class="flex h-24 shrink-0 items-center justify-center rounded-card border border-line bg-surface-muted px-4 sm:w-36">
          <.live_img_preview
            :for={entry <- @upload.entries}
            entry={entry}
            class="max-h-16 max-w-full object-contain"
          />
          <img
            :if={@path && @upload.entries == []}
            src={UploadController.path(@path)}
            alt={@label}
            class="max-h-16 max-w-full object-contain"
          />
          <span :if={is_nil(@path) && @upload.entries == []} class="text-xs/5 text-ink-muted">
            None yet
          </span>
        </div>
        <label
          for={@upload.ref}
          phx-drop-target={@upload.ref}
          class="relative flex min-h-24 grow cursor-pointer flex-col items-center justify-center rounded-card border-2 border-dashed border-line-strong px-4 py-4 text-center motion-safe:transition motion-safe:duration-150 hover:border-primary hover:bg-primary-soft focus-within:outline-2 focus-within:outline-offset-2 focus-within:outline-focus"
        >
          <.icon name="hero-arrow-up-tray" class="size-6 text-ink-faint" />
          <span class="mt-2 text-sm/6 text-ink-muted">
            <span class="font-semibold text-primary">
              {if @path, do: "Replace file", else: "Upload a file"}
            </span>
            or drag and drop
          </span>
          <span class="text-xs/5 text-ink-muted">PNG or JPG, up to 1 MB</span>
          <.live_file_input upload={@upload} class="sr-only" />
        </label>
      </div>

      <div
        :for={entry <- @upload.entries}
        class="mt-2 flex flex-wrap items-center justify-between gap-x-3 text-sm/6"
      >
        <span class="truncate text-ink-muted">{entry.client_name}</span>
        <button
          type="button"
          phx-click="cancel_upload"
          phx-value-upload={@kind}
          phx-value-ref={entry.ref}
          class="font-medium text-primary hover:underline"
        >
          Remove
        </button>
        <p :for={error <- upload_errors(@upload, entry)} class="basis-full text-danger">
          {upload_error(error)}
        </p>
      </div>
      <p :for={error <- upload_errors(@upload)} class="mt-2 text-sm/6 text-danger">
        {upload_error(error)}
      </p>
      <button
        :if={@path && @upload.entries == []}
        type="button"
        phx-click="remove_image"
        phx-value-kind={@kind}
        data-confirm={"Remove the saved #{@kind}?"}
        class="mt-2 text-sm/6 font-medium text-primary hover:underline"
      >
        Remove the saved {@kind}
      </button>
    </div>
    """
  end

  defp upload_error(:too_large), do: "This file is too big. The limit is 1 MB."
  defp upload_error(:not_accepted), do: "Only PNG and JPG files can be used."
  defp upload_error(:too_many_files), do: "Choose one file only."
  defp upload_error(_other), do: "This file can't be uploaded."

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> allow_upload(:logo,
       accept: ~w(.png .jpg .jpeg),
       max_entries: 1,
       max_file_size: @max_file_size
     )
     |> allow_upload(:signature,
       accept: ~w(.png .jpg .jpeg),
       max_entries: 1,
       max_file_size: @max_file_size
     )
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
    changeset =
      Businesses.change_business(
        socket.assigns.current_scope,
        socket.assigns.business,
        business_params
      )

    # The files are looked at only when the text fields are fine, so a typo in the GSTIN does not
    # throw away the pictures the user has already chosen.
    if changeset.valid? do
      case store_images(socket) do
        {:ok, images} ->
          save_business(socket, socket.assigns.live_action, business_params, images)

        {:error, message} ->
          {:noreply, put_flash(socket, :error, message)}
      end
    else
      {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
    end
  end

  def handle_event("cancel_upload", %{"upload" => upload, "ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, upload_name(upload), ref)}
  end

  def handle_event("remove_image", %{"kind" => kind}, %{assigns: %{live_action: :edit}} = socket)
      when kind in ["logo", "signature"] do
    {:ok, business} =
      Businesses.remove_image(
        socket.assigns.current_scope,
        socket.assigns.business,
        String.to_existing_atom(kind)
      )

    {:noreply, assign(socket, :business, business)}
  end

  defp upload_name("logo"), do: :logo
  defp upload_name("signature"), do: :signature

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

  defp rejection_message(upload, :unsupported_type),
    do: "The #{upload} is not a real PNG or JPG picture."

  defp rejection_message(upload, :too_large),
    do: "The #{upload} is too big: it may have at most 4000 pixels on a side."

  defp delete_stored(images), do: images |> Map.values() |> Enum.each(&Uploads.delete/1)
end
