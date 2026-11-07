defmodule QuickSlipsWeb.ImageComponents do
  @moduledoc """
  The drop zone for a picture (a logo, a signature) that the logged-in pages use with a LiveView upload.
  """
  use QuickSlipsWeb, :html

  alias QuickSlipsWeb.UploadController

  attr :id, :string, required: true
  attr :kind, :string, required: true, values: ~w(logo signature)
  attr :label, :string, required: true
  attr :upload, Phoenix.LiveView.UploadConfig, required: true
  attr :path, :string, default: nil, doc: "the stored image, when there already is one"

  # The drop zone from design/components/forms/uploads. The picture on the left is the file the
  # user just chose, else the one that is saved.
  def image_field(assigns) do
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

  @doc "What to tell the user about a file LiveView refused (`upload_errors/1`)."
  def upload_error(:too_large), do: "This file is too big. The limit is 1 MB."
  def upload_error(:not_accepted), do: "Only PNG and JPG files can be used."
  def upload_error(:too_many_files), do: "Choose one file only."
  def upload_error(_other), do: "This file can't be uploaded."

  @doc "What to tell the user when `QuickSlips.Uploads` turned a file down."
  def rejection_message(what, :unsupported_type),
    do: "The #{what} is not a real PNG or JPG picture."

  def rejection_message(what, :too_large),
    do: "The #{what} is too big: it may have at most 4000 pixels on a side."

  def rejection_message(what, :file_too_large),
    do: "The #{what} is too big. The limit is 1 MB."
end
