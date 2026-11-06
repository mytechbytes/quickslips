defmodule QuickSlipsWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  Every component here returns a fixed set of design-token classes (`bg-surface`,
  `text-ink`, `border-line`, `rounded-field`, `shadow-card` ...). The tokens live in
  `assets/css/theme.css`, the single file that controls the whole look, and switch
  by themselves between the light and the dark theme. Never write a palette colour
  class, a hex value or a `dark:` pair in a component.

  The markup comes from the design in `design/components/`. Each function here is the
  Phoenix version of one snippet there, so a change to the design is a change to one
  function.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://phoenix-live-view.hexdocs.pm/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

  """
  use Phoenix.Component
  use Gettext, backend: QuickSlipsWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices as toasts.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash
        id="welcome-back"
        kind={:info}
        phx-mounted={show("#welcome-back") |> JS.remove_attribute("hidden")}
        hidden
      >
        Welcome Back!
      </.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role={if @kind == :error, do: "alert", else: "status"}
      class="pointer-events-auto w-full max-w-sm rounded-card bg-surface shadow-pop outline-1 outline-line"
      {@rest}
    >
      <div class="flex items-start p-4">
        <.icon
          :if={@kind == :info}
          name="hero-information-circle"
          class="size-6 shrink-0 text-info"
        />
        <.icon :if={@kind == :error} name="hero-x-circle" class="size-6 shrink-0 text-danger" />
        <div class="ml-3 w-0 flex-1 pt-0.5">
          <p :if={@title} class="text-sm/5 font-medium text-ink">{@title}</p>
          <p class={["text-sm/5", (@title && "mt-1 text-ink-muted") || "font-medium text-ink"]}>
            {msg}
          </p>
        </div>
        <button
          type="button"
          class={[
            "-m-1.5 ml-4 inline-flex size-9 shrink-0 cursor-pointer items-center justify-center rounded-field text-ink-faint hover:bg-surface-muted hover:text-ink-muted",
            focus_ring()
          ]}
          aria-label={gettext("close")}
        >
          <.icon name="hero-x-mark" class="size-5" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="secondary">Send!</.button>
      <.button navigate={~p"/"} size="lg" block>Home</.button>
      <.button loading>Making the PDF</.button>
  """
  attr :rest, :global,
    include: ~w(href navigate patch method download name value disabled type form)

  attr :class, :any, default: nil, doc: "extra classes, added to the variant and size classes"

  attr :variant, :string,
    values: ~w(primary secondary ghost ghost-danger danger),
    default: "primary"

  attr :size, :string, values: ~w(sm md lg), default: "md"
  attr :block, :boolean, default: false, doc: "fill the width of the container"
  attr :loading, :boolean, default: false, doc: "show a spinner and disable the button"
  attr :on_dark, :boolean, default: false, doc: "use the focus ring made for the dark sidebar"
  slot :inner_block, required: true

  def button(assigns) do
    assigns =
      assigns
      |> assign(:classes, button_classes(assigns))
      |> then(fn assigns ->
        if assigns.loading do
          assign(assigns, :rest, Map.put(assigns.rest, :disabled, true))
        else
          assigns
        end
      end)

    if assigns.rest[:href] || assigns.rest[:navigate] || assigns.rest[:patch] do
      ~H"""
      <.link class={@classes} {@rest}>
        <.icon :if={@loading} name="hero-arrow-path" class="size-5 shrink-0 motion-safe:animate-spin" />
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@classes} aria-busy={@loading && "true"} {@rest}>
        <.icon :if={@loading} name="hero-arrow-path" class="size-5 shrink-0 motion-safe:animate-spin" />
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  # The ring that shows where the keyboard focus is. Shared by buttons, links and checkboxes.
  defp focus_ring,
    do: "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"

  defp button_classes(assigns) do
    [
      "inline-flex items-center justify-center gap-2 rounded-button font-semibold whitespace-nowrap",
      "motion-safe:transition motion-safe:duration-150 motion-safe:active:translate-y-px",
      "disabled:pointer-events-none disabled:opacity-50",
      if(assigns.on_dark,
        do:
          "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-on-sidebar",
        else: focus_ring()
      ),
      button_variant(assigns.variant),
      button_size(assigns.size),
      assigns.block && "w-full",
      assigns.class
    ]
  end

  defp button_variant("primary"),
    do: "bg-primary text-on-primary shadow-card hover:bg-primary-hover"

  defp button_variant("secondary"),
    do: "border border-line-strong bg-surface text-ink shadow-card hover:bg-surface-muted"

  defp button_variant("ghost"), do: "text-ink-muted hover:bg-surface-muted hover:text-ink"
  defp button_variant("ghost-danger"), do: "text-danger hover:bg-danger-soft"
  defp button_variant("danger"), do: "bg-danger text-on-primary shadow-card hover:bg-danger/90"

  defp button_size("sm"), do: "min-h-8 px-3 text-sm pointer-coarse:min-h-11"
  defp button_size("md"), do: "min-h-10 px-4 text-sm sm:min-h-9"
  defp button_size("lg"), do: "min-h-11 px-5 text-base sm:min-h-10"

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as radio, are best
  written directly in your templates.

  ## Examples

  ```heex
  <.input field={@form[:email]} type="email" />
  <.input name="my-input" errors={["oh no!"]} />
  <.input field={@form[:gstin]} label="GSTIN" help="15 characters, like 29ABCDE1234F1Z5" />
  ```

  ## Select type

  When using `type="select"`, you must pass the `options` and optionally
  a `value` to mark which option should be preselected.

  ```heex
  <.input field={@form[:user_type]} type="select" options={["Admin": "admin", "User": "user"]} />
  ```

  For more information on what kind of data can be passed to `options` see
  [`options_for_select`](https://phoenix-html.hexdocs.pm/Phoenix.HTML.Form.html#options_for_select/2).
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :help, :string, default: nil, doc: "a hint under the field; hidden while there is an error"
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :any, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="mb-2">
      <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} form={@rest[:form]} />
      <div class="flex gap-3">
        <div class="flex h-6 shrink-0 items-center">
          <div class="group grid size-6 grid-cols-1">
            <input
              type="checkbox"
              id={@id}
              name={@name}
              value="true"
              checked={@checked}
              aria-invalid={@errors != [] && "true"}
              class={
                @class ||
                  [
                    "col-start-1 row-start-1 appearance-none rounded-[calc(var(--radius-field)/2.5)] border border-line-strong bg-surface",
                    "checked:border-primary checked:bg-primary disabled:border-line disabled:bg-surface-muted forced-colors:appearance-auto",
                    focus_ring()
                  ]
              }
              {@rest}
            />
            <svg
              viewBox="0 0 14 14"
              fill="none"
              class="pointer-events-none col-start-1 row-start-1 size-4 self-center justify-self-center stroke-on-primary group-has-disabled:stroke-ink-faint"
            >
              <path
                d="M3 8L6 11L11 3.5"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="opacity-0 group-has-checked:opacity-100"
              />
            </svg>
          </div>
        </div>
        <div class="text-sm/6">
          <label for={@id} class="font-medium text-ink">{@label}</label>
        </div>
      </div>
      <.error :for={msg <- @errors} id={"#{@id}-error"}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="mb-2">
      <label for={@id}>
        <span :if={@label} class={label_class()}>{@label}</span>
        <span class="grid grid-cols-1">
          <select
            id={@id}
            name={@name}
            class={[
              @class || control_class(),
              @errors == [] && "border-line-strong focus:border-focus focus:outline-focus",
              @errors != [] && (@error_class || error_class()),
              "col-start-1 row-start-1 appearance-none pr-9"
            ]}
            aria-invalid={@errors != [] && "true"}
            aria-describedby={describedby(assigns)}
            multiple={@multiple}
            {@rest}
          >
            <option :if={@prompt} value="">{@prompt}</option>
            {Phoenix.HTML.Form.options_for_select(@options, @value)}
          </select>
          <.icon
            name="hero-chevron-down"
            class="pointer-events-none col-start-1 row-start-1 mr-3 size-4 self-center justify-self-end text-ink-muted"
          />
        </span>
      </label>
      <.field_notes id={@id} help={@help} errors={@errors} />
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="mb-2">
      <label for={@id}>
        <span :if={@label} class={label_class()}>{@label}</span>
        <textarea
          id={@id}
          name={@name}
          class={[
            @class || control_class(),
            @errors == [] && "border-line-strong focus:border-focus focus:outline-focus",
            @errors != [] && (@error_class || error_class())
          ]}
          aria-invalid={@errors != [] && "true"}
          aria-describedby={describedby(assigns)}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.field_notes id={@id} help={@help} errors={@errors} />
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div class="mb-2">
      <label for={@id}>
        <span :if={@label} class={label_class()}>{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            @class || control_class(),
            @errors == [] && "border-line-strong focus:border-focus focus:outline-focus",
            @errors != [] && (@error_class || error_class())
          ]}
          aria-invalid={@errors != [] && "true"}
          aria-describedby={describedby(assigns)}
          {@rest}
        />
      </label>
      <.field_notes id={@id} help={@help} errors={@errors} />
    </div>
    """
  end

  defp label_class, do: "mb-0.5 block text-sm/5 font-medium text-ink"

  defp control_class do
    "block w-full rounded-field border bg-surface px-3 py-2 text-base text-ink placeholder:text-ink-faint " <>
      "focus:outline-2 focus:-outline-offset-1 disabled:bg-surface-muted disabled:text-ink-faint sm:py-1.5 sm:text-sm/5"
  end

  defp error_class, do: "border-danger focus:outline-danger"

  # The ids of the help text and the error, so a screen reader reads them with the field.
  defp describedby(%{help: help, errors: errors, id: id}) do
    ids = [help && errors == [] && "#{id}-help", errors != [] && "#{id}-error"]
    ids |> Enum.filter(& &1) |> Enum.join(" ") |> then(&if(&1 == "", do: nil, else: &1))
  end

  # The help text shows until there is an error; then the error replaces it.
  attr :id, :string, required: true
  attr :help, :string, default: nil
  attr :errors, :list, default: []

  defp field_notes(assigns) do
    ~H"""
    <p :if={@help && @errors == []} id={"#{@id}-help"} class="mt-1.5 text-sm text-ink-muted">
      {@help}
    </p>
    <.error :for={msg <- @errors} id={"#{@id}-error"}>{msg}</.error>
    """
  end

  # Helper used by inputs to generate form errors
  attr :id, :string, default: nil
  slot :inner_block, required: true

  defp error(assigns) do
    ~H"""
    <p id={@id} class="mt-1.5 flex gap-2 items-center text-sm text-danger">
      <.icon name="hero-exclamation-circle" class="size-5 shrink-0" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", "pb-4"]}>
      <div>
        <h1 class="font-display text-2xl/8 font-semibold tracking-tight text-ink">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="mt-1 text-sm/6 text-ink-muted">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-hidden rounded-card border border-line bg-surface shadow-card">
      <table class="min-w-full divide-y divide-line">
        <thead class="bg-surface-muted">
          <tr>
            <th
              :for={{col, i} <- Enum.with_index(@col)}
              scope="col"
              class={[
                "text-left text-sm/6 font-semibold text-ink-muted",
                i == 0 && "py-3 pr-3 pl-4 sm:pl-6",
                i > 0 && "px-3 py-3"
              ]}
            >
              {col[:label]}
            </th>
            <th :if={@action != []} scope="col" class="py-3 pr-4 pl-3 sm:pr-6">
              <span class="sr-only">{gettext("Actions")}</span>
            </th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}
          class="divide-y divide-line"
        >
          <tr :for={row <- @rows} id={@row_id && @row_id.(row)} class="hover:bg-surface-muted">
            <td
              :for={{col, i} <- Enum.with_index(@col)}
              phx-click={@row_click && @row_click.(row)}
              class={[
                "text-sm/6 text-ink",
                i == 0 && "py-3 pr-3 pl-4 sm:pl-6",
                i > 0 && "px-3 py-3",
                @row_click && "hover:cursor-pointer"
              ]}
            >
              {render_slot(col, @row_item.(row))}
            </td>
            <td :if={@action != []} class="py-1 pr-2 pl-3 whitespace-nowrap sm:pr-4">
              <div class="flex justify-end gap-x-1 font-semibold">
                <%= for action <- @action do %>
                  {render_slot(action, @row_item.(row))}
                <% end %>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <dl class="divide-y divide-line rounded-card border border-line bg-surface px-4 shadow-card">
      <div :for={item <- @item} class="py-3 sm:grid sm:grid-cols-3 sm:gap-4">
        <dt class="text-sm/6 font-medium text-ink-muted">{item.title}</dt>
        <dd class="mt-1 text-sm/6 text-ink sm:col-span-2 sm:mt-0">{render_slot(item)}</dd>
      </div>
    </dl>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icon by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} aria-hidden="true" />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(QuickSlipsWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(QuickSlipsWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
