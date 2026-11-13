defmodule QuickSlipsWeb.CatalogueComponents do
  @moduledoc """
  The pieces of the template catalogue: search box, category chips and template cards.

  A "template" is a map with string keys, the schema of a template as one locale sees it (see
  `QuickSlips.Templates.get/2`): `%{"locale" => "en-in", "public_slug" => _, "title" => _, "summary" => _,
  "icon" => "hero-fire"}` (`"icon"` is optional). The card links to the page of the template in that locale.
  """
  use Phoenix.Component
  use Gettext, backend: QuickSlipsWeb.Gettext
  use QuickSlipsWeb, :verified_routes

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
        class="block w-full rounded-field border border-line-strong bg-surface py-2 pr-3 pl-10 text-base text-ink placeholder:text-ink-faint focus:border-focus focus:outline-2 focus:-outline-offset-1 focus:outline-focus sm:py-1.5 sm:text-sm/5"
      />
    </div>
    """
  end

  @doc """
  Category buttons. A click sends the `category` event with the key of the category, or `"all"`.

  Scroll sideways on a phone, wrap from `sm` up.
  """
  attr :categories, :list,
    required: true,
    doc:
      "maps with `:key` (what a click sends, and the chip's id) and `:name` (what the chip says)"

  attr :selected, :string, default: "all"

  def category_chips(assigns) do
    ~H"""
    <div
      role="group"
      aria-label={gettext("Categories")}
      class="-mx-4 flex gap-2 overflow-x-auto px-4 pb-1 sm:mx-0 sm:flex-wrap sm:overflow-visible sm:px-0 sm:pb-0"
    >
      <button
        :for={{key, name} <- [{"all", gettext("All")} | Enum.map(@categories, &{&1.key, &1.name})]}
        id={"chip-#{slug(key)}"}
        type="button"
        phx-click="category"
        phx-value-category={key}
        aria-pressed={to_string(key == @selected)}
        class={[
          "inline-flex min-h-10 sm:min-h-9 items-center rounded-full border border-line-strong bg-surface px-4 text-sm/6 font-medium whitespace-nowrap text-ink-muted hover:bg-surface-muted",
          "aria-pressed:border-primary aria-pressed:bg-primary-soft aria-pressed:text-primary sm:min-h-9",
          focus()
        ]}
      >
        <.icon
          name={category_icon(key)}
          class={["size-5 -ml-1 mr-1.5 shrink-0", category_icon_color(key)]}
        />
        {name}
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

  @doc """
  The icon of a bill in the colours of the logo (green, orange and cream), the glyph always in another colour than the
  ground. Each bill keeps the same colours (they come from its slug).
  """
  attr :slug, :string, required: true
  attr :name, :string, required: true, doc: "the heroicon"
  attr :class, :any, default: nil, doc: "the size of the tile"
  attr :icon_class, :string, default: "size-6"

  def bill_icon(assigns) do
    assigns = assign(assigns, :tone, bill_tone(assigns.slug))

    ~H"""
    <span
      class={[
        "flex shrink-0 items-center justify-center rounded-field shadow-xs",
        @tone,
        @class
      ]}
      aria-hidden="true"
    >
      <.icon name={@name} class={@icon_class} />
    </span>
    """
  end

  # Six pairs of the colours of the logo, each with a glyph of another colour than its ground.
  @tones [
    "bg-primary text-secondary",
    "bg-accent text-primary-hover",
    "bg-secondary text-primary ring-1 ring-primary/40 ring-inset",
    "bg-primary text-accent",
    "bg-accent text-secondary",
    "bg-secondary text-accent ring-1 ring-accent/50 ring-inset"
  ]
  defp bill_tone(slug), do: Enum.at(@tones, :erlang.phash2(slug, length(@tones)))

  @doc "The icon of a category of the catalogue (its key is the English name in the schemas)."
  def category_icon("Food & shopping"), do: "hero-shopping-bag"
  def category_icon("Health & learning"), do: "hero-heart"
  def category_icon("Home & utilities"), do: "hero-home"
  def category_icon("Travel"), do: "hero-truck"
  def category_icon("Work"), do: "hero-briefcase"
  def category_icon(_other), do: "hero-squares-2x2"

  # The colour of the icon of a category chip, and the colours of its tag on a card: the colours of the logo.
  defp category_icon_color("Food & shopping"), do: "text-accent"
  defp category_icon_color("Health & learning"), do: "text-danger"
  defp category_icon_color("Home & utilities"), do: "text-primary"
  defp category_icon_color("Travel"), do: "text-info"
  defp category_icon_color("Work"), do: "text-warning"
  defp category_icon_color(_other), do: "text-ink-muted"

  defp category_pill("Food & shopping"), do: "bg-accent-soft text-on-accent"
  defp category_pill("Travel"), do: "bg-info-soft text-info"
  defp category_pill("Health & learning"), do: "bg-danger-soft text-danger"
  defp category_pill("Work"), do: "bg-warning-soft text-warning"
  defp category_pill(_other), do: "bg-primary-soft text-primary"

  @doc "The tile: an icon, the name and one line. It links to the template page."
  attr :template, :map, required: true
  attr :class, :any, default: nil

  def template_tile(assigns) do
    ~H"""
    <.link
      id={"open-#{@template["slug"]}"}
      navigate={bill_path(@template)}
      class={[
        "group relative h-full gap-3 rounded-card border border-line bg-surface p-5 shadow-card hover:shadow-pop",
        "motion-safe:transition motion-safe:duration-200 motion-safe:hover:-translate-y-0.5",
        @class,
        focus()
      ]}
    >
      <.bill_icon
        slug={@template["slug"]}
        name={icon_name(@template)}
        class="size-10 sm:size-9"
      />
      <span class="min-w-0">
        <span class="block text-base/6 font-semibold text-ink">{@template["title"]}</span>
        <span class="mt-0.5 block text-sm/5 text-ink-muted">{@template["summary"]}</span>
      </span>
      <span class={[
        "absolute top-5 right-5 inline-flex items-center gap-x-1 rounded-button px-2 py-1 text-xs font-medium",
        category_pill(@template["category"])
      ]}>
        <.icon name={category_icon(@template["category"])} class="size-3.5" />
        {@template["category_name"] || @template["category"]}
      </span>
      <span class="min-w-0 block">
        <span class="size-5 text-ink-faint text-sm text-primary font-semibold">{gettext(
          "Generate Now"
        )}</span>
        <.icon
          name="hero-arrow-right"
          class="size-5 text-ink-faint group-hover:text-primary motion-safe:transition motion-safe:group-hover:translate-x-0.5"
        />
      </span>
    </.link>
    """
  end

  @doc "The phone version: a paper sheet on a tray, with the name under it."
  attr :template, :map, required: true
  attr :class, :any, default: nil

  def template_thumb(assigns) do
    assigns = assign(assigns, :lines, thumb_lines(assigns.template["slug"]))

    ~H"""
    <.link
      id={"open-#{@template["slug"]}-thumb"}
      navigate={bill_path(@template)}
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
        <.bill_icon
          slug={@template["slug"]}
          name={icon_name(@template)}
          class="absolute top-4 right-4 size-9 !rounded-full"
          icon_class="size-5"
        />
      </span>
      <span class="mt-3 flex items-start justify-between gap-x-3 px-1 pb-1">
        <span class="min-w-0">
          <span class="block text-base/6 font-semibold text-ink">{@template["title"]}</span>
          <span class="mt-0.5 block text-sm/5 text-ink-muted">{@template["summary"]}</span>
        </span>
        <.icon name="hero-arrow-right" class="mt-0.5 size-5 shrink-0 text-ink-faint" />
      </span>
    </.link>
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

  defp bill_path(template), do: ~p"/#{template["locale"]}/#{template["public_slug"]}"

  # A schema.json may leave out "icon"; the card then shows a plain document.
  defp icon_name(template), do: template["icon"] || "hero-document-text"

  defp slug(name),
    do: name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-") |> String.trim("-")
end
