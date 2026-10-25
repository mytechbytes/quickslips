defmodule QuickSlipsWeb.CatalogueComponents do
  @moduledoc """
  The pieces of the template catalogue: search box, category chips and template cards.

  A "template" is a map with string keys, the shape of a `schema.json`:
  `%{"slug" => _, "title" => _, "summary" => _, "category" => _, "icon" => "hero-fire"}`
  (`"icon"` is optional).
  """
  use Phoenix.Component

  import QuickSlipsWeb.CoreComponents, only: [icon: 1]

  @focus "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"

  @doc "A search box with a magnifier. Put it inside a form with `phx-change`."
  attr :id, :string, required: true
  attr :name, :string, default: "q"
  attr :value, :string, default: ""
  attr :label, :string, default: "Search"
  attr :placeholder, :string, default: nil

  def search_input(assigns) do
    ~H"""
    <div class="relative">
      <.icon
        name="hero-magnifying-glass"
        class="pointer-events-none absolute inset-y-0 left-3 my-auto size-5 text-ink-faint"
      />
      <input
        id={@id}
        type="search"
        name={@name}
        value={@value}
        aria-label={@label}
        placeholder={@placeholder}
        autocomplete="off"
        phx-debounce="200"
        class="block w-full rounded-field border border-line-strong bg-surface py-2.5 pr-3 pl-10 text-base text-ink placeholder:text-ink-faint focus:border-focus focus:outline-2 focus:-outline-offset-1 focus:outline-focus sm:text-sm/6"
      />
    </div>
    """
  end

  @doc """
  Category buttons. A click sends the `category` event with the chosen name, or `"all"`.

  Scroll sideways on a phone, wrap from `sm` up.
  """
  attr :categories, :list, required: true
  attr :selected, :string, default: "all"

  def category_chips(assigns) do
    ~H"""
    <div
      role="group"
      aria-label="Categories"
      class="-mx-4 flex gap-2 overflow-x-auto px-4 pb-1 sm:mx-0 sm:flex-wrap sm:overflow-visible sm:px-0 sm:pb-0"
    >
      <button
        :for={name <- ["all" | @categories]}
        id={"chip-#{slug(name)}"}
        type="button"
        phx-click="category"
        phx-value-category={name}
        aria-pressed={to_string(name == @selected)}
        class={[
          "inline-flex min-h-11 items-center rounded-full border border-line-strong bg-surface px-4 text-sm/6 font-medium whitespace-nowrap text-ink-muted hover:bg-surface-muted",
          "aria-pressed:border-primary aria-pressed:bg-primary-soft aria-pressed:text-primary sm:min-h-9",
          focus()
        ]}
      >
        {if name == "all", do: "All", else: name}
      </button>
    </div>
    """
  end

  @doc """
  One catalogue entry. On a laptop it is a tile; on a phone it is a small sheet of paper.
  Both open the template page. `id` is the stream DOM id.
  """
  attr :id, :string, required: true
  attr :template, :map, required: true

  def template_card(assigns) do
    ~H"""
    <li id={@id}>
      <.template_tile template={@template} class="hidden lg:flex lg:flex-col" />
      <.template_thumb template={@template} class="lg:hidden" />
    </li>
    """
  end

  @doc "The tile: an icon, the name and one line. It links to the template page."
  attr :template, :map, required: true
  attr :class, :any, default: nil

  def template_tile(assigns) do
    ~H"""
    <%!-- The page for each template is built in Task 4.5. Until then these links lead to a 404. --%>
    <a
      id={"open-#{@template["slug"]}"}
      href={"/" <> @template["slug"]}
      class={[
        "group relative h-full gap-3 rounded-card border border-line bg-surface p-5 shadow-card hover:shadow-pop",
        "motion-safe:transition motion-safe:duration-200 motion-safe:hover:-translate-y-0.5",
        @class,
        focus()
      ]}
    >
      <span class="flex size-11 shrink-0 items-center justify-center rounded-field bg-primary-soft text-primary">
        <.icon name={icon_name(@template)} class="size-6" />
      </span>
      <span class="min-w-0">
        <span class="block text-base/6 font-semibold text-ink">{@template["title"]}</span>
        <span class="mt-0.5 block text-sm/5 text-ink-muted">{@template["summary"]}</span>
      </span>
      <.icon
        name="hero-arrow-right"
        class="absolute top-5 right-5 size-5 text-ink-faint group-hover:text-primary motion-safe:transition motion-safe:group-hover:translate-x-0.5"
      />
    </a>
    """
  end

  @doc "The phone version: a paper sheet on a tray, with the name under it."
  attr :template, :map, required: true
  attr :class, :any, default: nil

  def template_thumb(assigns) do
    assigns = assign(assigns, :lines, thumb_lines(assigns.template["slug"]))

    ~H"""
    <a
      id={"open-#{@template["slug"]}-thumb"}
      href={"/" <> @template["slug"]}
      class={[
        "group flex h-full w-full flex-col rounded-card border border-line bg-surface p-3 text-left shadow-card hover:shadow-pop",
        "motion-safe:transition motion-safe:duration-200 motion-safe:hover:-translate-y-0.5",
        @class,
        focus()
      ]}
    >
      <span class="relative block rounded-field bg-tray px-8 pt-6 pb-0">
        <span class="block aspect-3/4 w-full bg-paper p-3 shadow-card">
          <span class="block space-y-1.5" aria-hidden="true">
            <span class="block h-2 w-2/5 rounded-full bg-paper-ink/60"></span>
            <span class={["block h-1.5 rounded-full bg-paper-ink/15", elem(@lines, 0)]}></span>
            <span class="block h-px w-full bg-paper-ink/25"></span>
            <span class={["mt-3 block h-1.5 rounded-full bg-paper-ink/15", elem(@lines, 1)]}></span>
            <span class={["block h-1.5 rounded-full bg-paper-ink/15", elem(@lines, 2)]}></span>
            <span class={["block h-1.5 rounded-full bg-paper-ink/15", elem(@lines, 0)]}></span>
            <span class={["block h-1.5 rounded-full bg-paper-ink/15", elem(@lines, 1)]}></span>
            <span class="mt-4 ml-auto block h-2 w-1/3 rounded-full bg-paper-ink/60"></span>
          </span>
        </span>
        <span class="absolute top-4 right-4 flex size-9 items-center justify-center rounded-full bg-primary-soft text-primary ring-1 ring-primary/20">
          <.icon name={icon_name(@template)} class="size-5" />
        </span>
      </span>
      <span class="mt-3 flex items-start justify-between gap-x-3 px-1 pb-1">
        <span class="min-w-0">
          <span class="block text-base/6 font-semibold text-ink">{@template["title"]}</span>
          <span class="mt-0.5 block text-sm/5 text-ink-muted">{@template["summary"]}</span>
        </span>
        <.icon name="hero-arrow-right" class="mt-0.5 size-5 shrink-0 text-ink-faint" />
      </span>
    </a>
    """
  end

  # Four patterns of line widths, so the little pages do not all look the same.
  @patterns [
    {"w-3/5", "w-4/5", "w-2/3"},
    {"w-1/2", "w-full", "w-3/4"},
    {"w-2/3", "w-3/5", "w-full"},
    {"w-3/4", "w-2/3", "w-4/5"}
  ]
  defp thumb_lines(slug), do: Enum.at(@patterns, :erlang.phash2(slug, 4))

  defp focus, do: @focus

  # A schema.json may leave out "icon"; the card then shows a plain document.
  defp icon_name(template), do: template["icon"] || "hero-document-text"

  defp slug(name),
    do: name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-") |> String.trim("-")
end
