defmodule QuickSlipsWeb.UI do
  @moduledoc """
  The rest of the component library, one function per snippet in `design/components/`.

  `QuickSlipsWeb.CoreComponents` holds the pieces every Phoenix app has (button, input,
  flash, table). This module holds the others: badges, alerts, cards, tabs, menus and the
  pieces of the sign-in pages. All of them use design tokens only (see `assets/css/theme.css`).

  Anything that keeps its own open or closed state (a menu, a dialog) is built on a
  Tailwind Plus Elements tag such as `<el-dropdown>`. Give those elements a stable `id`
  and, where the content never changes, `phx-update="ignore"` on the wrapper, so a LiveView
  patch does not reset them.
  """
  use Phoenix.Component
  use Gettext, backend: QuickSlipsWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: QuickSlipsWeb.Endpoint,
    router: QuickSlipsWeb.Router,
    statics: QuickSlipsWeb.static_paths()

  import QuickSlipsWeb.CoreComponents, only: [icon: 1]

  alias Phoenix.LiveView.JS
  alias QuickSlips.Locales

  @doc "True when the scope carries a logged-in user."
  def signed_in?(%{user: %{}}), do: true
  def signed_in?(_scope), do: false

  @doc "Two letters for an avatar: from the name when there is one, else from the email."
  def initials(user) do
    source = if user.name in [nil, ""], do: user.email, else: user.name

    source
    |> String.split(~r/[\s@._-]+/, trim: true)
    |> Enum.map(&String.first/1)
    |> Enum.take(2)
    |> Enum.join()
    |> String.upcase()
  end

  ## Brand

  attr :id, :string, default: "logo"
  attr :navigate, :string, default: "/"
  attr :tone, :atom, values: [:ink, :sidebar], default: :ink

  def wordmark(assigns) do
    ~H"""
    <.link
      id={@id}
      navigate={@navigate}
      class={[
        "inline-flex items-center gap-2.5 rounded-field font-display text-xl font-bold tracking-tight focus-visible:outline-2 focus-visible:outline-offset-2",
        @tone == :ink && "text-ink focus-visible:outline-focus",
        @tone == :sidebar && "text-on-sidebar focus-visible:outline-on-sidebar"
      ]}
    >
      <%!-- The mark is a picture with its own colours, the same in both themes. The name beside it is text. --%>
      <img src={~p"/images/logo-mark.svg"} alt="" width="28" height="28" class="size-7 shrink-0" />
      QuickSlips
    </.link>
    """
  end

  ## Small pieces

  @doc """
  A small label with a tone.

      <.badge tone={:success}>Paid</.badge>
  """
  attr :tone, :atom,
    values: [:neutral, :primary, :success, :warning, :danger, :info, :accent],
    default: :neutral

  attr :mono, :boolean, default: false
  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-1 rounded-full px-2 py-1 text-xs font-medium ring-1 ring-inset",
      badge_tone(@tone),
      @mono && "font-mono"
    ]}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  defp badge_tone(:neutral), do: "bg-surface-muted text-ink-muted ring-line"
  defp badge_tone(:primary), do: "bg-primary-soft text-primary ring-primary/20"
  defp badge_tone(:success), do: "bg-success-soft text-success ring-success/20"
  defp badge_tone(:warning), do: "bg-warning-soft text-warning ring-warning/20"
  defp badge_tone(:danger), do: "bg-danger-soft text-danger ring-danger/20"
  defp badge_tone(:info), do: "bg-info-soft text-info ring-info/20"
  defp badge_tone(:accent), do: "bg-accent-soft text-ink ring-accent/40"

  @doc """
  A round avatar with initials.

      <.avatar initials="AM" />
  """
  attr :initials, :string, required: true
  attr :class, :string, default: "size-9"

  def avatar(assigns) do
    ~H"""
    <span
      class={[
        "flex shrink-0 items-center justify-center rounded-full bg-primary text-sm font-semibold text-on-primary",
        @class
      ]}
      aria-hidden="true"
    >
      {@initials}
    </span>
    """
  end

  @doc """
  A message inside the page. Errors and warnings are announced at once (`role="alert"`).

      <.alert kind={:info} title="Heads up">Something to know.</.alert>
  """
  attr :kind, :atom, values: [:info, :success, :warning, :error], default: :info
  attr :title, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block

  def alert(assigns) do
    ~H"""
    <div
      role={if @kind in [:warning, :error], do: "alert", else: "status"}
      class={["rounded-field p-4 ring-1 ring-inset", alert_tone(@kind), @class]}
      {@rest}
    >
      <div class="flex">
        <div class="shrink-0">
          <.icon name={alert_icon(@kind)} class={["size-5", alert_icon_tone(@kind)]} />
        </div>
        <div class="ml-3 grow">
          <p :if={@title} class="text-sm/5 font-semibold text-ink">{@title}</p>
          <div :if={@inner_block != []} class={["text-sm/5 text-ink-muted", @title && "mt-1"]}>
            {render_slot(@inner_block)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp alert_tone(:info), do: "bg-info-soft ring-info/20"
  defp alert_tone(:success), do: "bg-success-soft ring-success/20"
  defp alert_tone(:warning), do: "bg-warning-soft ring-warning/20"
  defp alert_tone(:error), do: "bg-danger-soft ring-danger/20"

  defp alert_icon(:info), do: "hero-information-circle"
  defp alert_icon(:success), do: "hero-check-circle"
  defp alert_icon(:warning), do: "hero-exclamation-triangle"
  defp alert_icon(:error), do: "hero-x-circle"

  defp alert_icon_tone(:info), do: "text-info"
  defp alert_icon_tone(:success), do: "text-success"
  defp alert_icon_tone(:warning), do: "text-warning"
  defp alert_icon_tone(:error), do: "text-danger"

  @doc """
  A line with a word in the middle.

      <.divider>or</.divider>
  """
  slot :inner_block, required: true

  def divider(assigns) do
    ~H"""
    <div class="flex items-center gap-x-4">
      <div class="w-full flex-1 border-t border-line"></div>
      <p class="text-sm/6 font-medium text-nowrap text-ink-muted">{render_slot(@inner_block)}</p>
      <div class="w-full flex-1 border-t border-line"></div>
    </div>
    """
  end

  @doc """
  A card with an optional header and footer.

      <.card>
        <:header>Recent documents</:header>
        Body
        <:footer>Footer</:footer>
      </.card>
  """
  slot :header
  slot :footer
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div class="divide-y divide-line overflow-hidden rounded-card border border-line bg-surface shadow-card">
      <div :if={@header != []} class="px-4 py-4 sm:px-6">{render_slot(@header)}</div>
      <div class="px-4 py-5 sm:p-6">{render_slot(@inner_block)}</div>
      <div :if={@footer != []} class="bg-surface-muted px-4 py-4 sm:px-6">{render_slot(@footer)}</div>
    </div>
    """
  end

  @doc """
  A key figure. Put several inside `<dl class="grid ...">`.

      <.stat label="Credits" value="120" icon="hero-banknotes" />
  """
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :icon, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global, doc: "for example an `id`"
  slot :footer

  def stat(assigns) do
    ~H"""
    <div class={["rounded-card border border-line bg-surface p-5 shadow-card", @class]} {@rest}>
      <dt class="flex items-center gap-x-2 text-sm/6 font-medium text-ink-muted">
        <.icon :if={@icon} name={@icon} class="size-5 text-ink-faint" />{@label}
      </dt>
      <dd class="mt-2 flex flex-wrap items-baseline gap-x-3 gap-y-1">
        <span class="text-3xl/9 font-semibold tracking-tight text-ink tabular-nums">{@value}</span>
      </dd>
      <dd :if={@footer != []} class="mt-3 text-sm/6">{render_slot(@footer)}</dd>
    </div>
    """
  end

  @doc """
  What a list shows when it has nothing in it yet.

      <.empty_state icon="hero-document-text" title="No documents yet">
        Documents you download are kept here.
        <:actions><.button navigate={~p"/"}>New document</.button></:actions>
      </.empty_state>
  """
  attr :icon, :string, required: true
  attr :title, :string, required: true
  slot :inner_block, required: true
  slot :actions

  def empty_state(assigns) do
    ~H"""
    <div class="rounded-card border-2 border-dashed border-line-strong px-6 py-14 text-center sm:py-16">
      <div class="mx-auto flex size-14 items-center justify-center rounded-full bg-primary-soft">
        <.icon name={@icon} class="size-7 text-primary" />
      </div>
      <h2 class="mt-5 text-base/7 font-semibold text-ink">{@title}</h2>
      <p class="mx-auto mt-1 max-w-md text-sm/6 text-ink-muted">{render_slot(@inner_block)}</p>
      <div :if={@actions != []} class="mt-6">{render_slot(@actions)}</div>
    </div>
    """
  end

  @doc """
  Title on the left, the form in a card on the right. Stacked on phones.
  One section is one form.

      <.form_section id="email" title="Email address" text="Where we send your log-in links.">
        <.form ...>...</.form>
      </.form_section>
  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :text, :string, required: true
  slot :inner_block, required: true

  def form_section(assigns) do
    ~H"""
    <section aria-labelledby={"#{@id}-title"} class="grid grid-cols-1 gap-x-8 gap-y-4 md:grid-cols-3">
      <div>
        <h2 id={"#{@id}-title"} class="text-base/7 font-semibold text-ink">{@title}</h2>
        <p class="mt-1 text-sm/6 text-ink-muted">{@text}</p>
      </div>
      <div class="rounded-card border border-line bg-surface p-5 shadow-card sm:p-6 md:col-span-2">
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end

  ## Sign-in pages

  @doc """
  The centred card on the sign-in, sign-up and confirmation pages.

      <.auth_card title="Log in to QuickSlips" subtitle="Welcome back.">
        ...forms...
        <:footer>New here? <.link navigate={~p"/users/register"}>Sign up</.link></:footer>
      </.auth_card>
  """
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :icon, :string, default: nil
  slot :inner_block, required: true
  slot :footer

  def auth_card(assigns) do
    ~H"""
    <div class="flex flex-col justify-center px-4 py-10 sm:px-6 sm:py-16 lg:px-8">
      <div class="sm:mx-auto sm:w-full sm:max-w-md">
        <div
          :if={@icon}
          class="mx-auto mb-5 flex size-14 items-center justify-center rounded-full bg-primary-soft"
        >
          <.icon name={@icon} class="size-7 text-primary" />
        </div>
        <h1 class="text-center font-display text-2xl/9 font-bold tracking-tight text-ink">
          {@title}
        </h1>
        <p :if={@subtitle} class="mt-2 text-center text-sm/6 text-pretty text-ink-muted">
          {@subtitle}
        </p>
      </div>
      <div class="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
        <div class="rounded-card border border-line bg-surface px-5 py-8 shadow-card sm:px-10">
          {render_slot(@inner_block)}
        </div>
        <p :if={@footer != []} class="mt-8 text-center text-sm/6 text-ink-muted">
          {render_slot(@footer)}
        </p>
      </div>
    </div>
    """
  end

  @doc "The Continue with Google button. A normal link: it leaves the app for Google."
  attr :id, :string, default: "google-login"

  def google_button(assigns) do
    ~H"""
    <.link
      id={@id}
      href={~p"/auth/google"}
      class="flex min-h-11 w-full items-center justify-center gap-3 rounded-button border border-line-strong bg-surface px-3 text-sm font-semibold text-ink shadow-card hover:bg-surface-muted focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
    >
      <img src={~p"/images/google.svg"} alt="" class="size-5" /> {gettext("Continue with Google")}
    </.link>
    """
  end

  @doc """
  Tabs that switch between panels without a round trip to the server (JS commands).

      <.tabs id="login-tabs" variant="pills">
        <:tab id="password" label="Password">...</:tab>
        <:tab id="link" label="Email link">...</:tab>
      </.tabs>
  """
  attr :id, :string, required: true
  attr :variant, :string, values: ~w(underline pills), default: "underline"

  slot :tab, required: true do
    attr :id, :string, required: true
    attr :label, :string, required: true
  end

  def tabs(assigns) do
    assigns = assign(assigns, :keys, Enum.map(assigns.tab, & &1.id))

    ~H"""
    <div id={@id} phx-hook=".Tabs">
      <div
        role="tablist"
        aria-label={@id}
        class={if @variant == "pills", do: "flex gap-x-2", else: "flex gap-x-6 border-b border-line"}
      >
        <button
          :for={{tab, i} <- Enum.with_index(@tab)}
          id={"#{@id}-tab-#{tab.id}"}
          type="button"
          role="tab"
          aria-selected={to_string(i == 0)}
          tabindex={if i == 0, do: "0", else: "-1"}
          aria-controls={"#{@id}-panel-#{tab.id}"}
          phx-click={select_tab(@id, tab.id, @keys)}
          class={[
            tab_class(@variant),
            "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
          ]}
        >
          {tab.label}
        </button>
      </div>
      <div
        :for={{tab, i} <- Enum.with_index(@tab)}
        id={"#{@id}-panel-#{tab.id}"}
        role="tabpanel"
        aria-labelledby={"#{@id}-tab-#{tab.id}"}
        class={[@variant == "pills" && "pt-5", @variant == "underline" && "pt-6", i != 0 && "hidden"]}
      >
        {render_slot(tab)}
      </div>
    </div>

    <%!-- The arrow keys move between the tabs, like in a desktop app. The clicks do the rest. --%>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Tabs">
      export default {
        mounted() {
          this.el.addEventListener("keydown", (event) => {
            if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return

            const tabs = Array.from(this.el.querySelectorAll('[role="tab"]'))
            const current = tabs.indexOf(document.activeElement)
            if (current === -1) return

            event.preventDefault()
            const last = tabs.length - 1
            const next = {
              ArrowLeft: current === 0 ? last : current - 1,
              ArrowRight: current === last ? 0 : current + 1,
              Home: 0,
              End: last,
            }[event.key]

            tabs[next].focus()
            tabs[next].click()
          })
        },
      }
    </script>
    """
  end

  defp tab_class("pills"),
    do:
      "inline-flex min-h-11 items-center rounded-button px-4 text-sm/6 font-medium whitespace-nowrap text-ink-muted hover:bg-surface-muted hover:text-ink aria-selected:bg-primary-soft aria-selected:text-primary sm:min-h-9"

  defp tab_class("underline"),
    do:
      "-mb-px inline-flex min-h-11 items-center border-b-2 border-transparent px-1 text-sm/6 font-medium whitespace-nowrap text-ink-muted hover:border-line-strong hover:text-ink aria-selected:border-primary aria-selected:text-primary"

  # Select one tab and show its panel, hide the others. These JS commands run in the browser.
  defp select_tab(id, selected, keys) do
    Enum.reduce(keys, %JS{}, fn key, js ->
      on? = key == selected
      tab = "##{id}-tab-#{key}"
      panel = "##{id}-panel-#{key}"

      js
      |> JS.set_attribute({"aria-selected", to_string(on?)}, to: tab)
      |> JS.set_attribute({"tabindex", if(on?, do: "0", else: "-1")}, to: tab)
      |> then(
        &if(on?,
          do: JS.remove_class(&1, "hidden", to: panel),
          else: JS.add_class(&1, "hidden", to: panel)
        )
      )
    end)
  end

  ## Menus (Tailwind Plus Elements)

  # The look of a menu panel and of its items.
  defp menu_class do
    "origin-top-right rounded-field bg-surface py-1 shadow-pop outline outline-line transition transition-discrete motion-reduce:transition-none " <>
      "[--anchor-gap:--spacing(2)] data-closed:scale-95 data-closed:transform data-closed:opacity-0 " <>
      "data-enter:duration-100 data-enter:ease-out data-leave:duration-75 data-leave:ease-in"
  end

  defp menu_item_class,
    do:
      "flex w-full items-center gap-2 px-3 py-2 text-left text-sm/6 text-ink focus:bg-surface-muted focus:outline-hidden"

  @doc """
  The System, Light and Dark switch. Same mechanism as the theme script in `root.html.heex`:
  a click dispatches `phx:set-theme`, the script sets `data-theme` on `<html>` and remembers it.
  """
  attr :id, :string, default: "theme-menu"
  attr :on_dark, :boolean, default: false

  def theme_menu(assigns) do
    ~H"""
    <el-dropdown id={@id} class="relative" phx-update="ignore">
      <button
        id={"#{@id}-trigger"}
        type="button"
        class={[
          "relative flex size-11 items-center justify-center rounded-full focus-visible:outline-2 focus-visible:outline-offset-2",
          !@on_dark &&
            "text-ink-muted hover:bg-surface-muted hover:text-ink focus-visible:outline-focus",
          @on_dark &&
            "text-on-sidebar/80 hover:bg-on-sidebar/10 hover:text-on-sidebar focus-visible:outline-on-sidebar"
        ]}
      >
        <span class="sr-only">{gettext("Theme")}</span>
        <span class="hero-sun size-5 dark:hidden" aria-hidden="true"></span>
        <span class="hero-moon hidden size-5 dark:block" aria-hidden="true"></span>
      </button>
      <el-menu anchor="bottom end" popover class={["w-44", menu_class()]}>
        <button
          :for={
            {theme, label, ic} <- [
              {"system", gettext("System"), "hero-computer-desktop"},
              {"light", gettext("Light"), "hero-sun"},
              {"dark", gettext("Dark"), "hero-moon"}
            ]
          }
          id={"#{@id}-#{theme}"}
          type="button"
          phx-click={JS.dispatch("phx:set-theme")}
          data-phx-theme={theme}
          class={["group", menu_item_class()]}
        >
          <.icon name={ic} class="size-5 text-ink-muted" />
          {label}
          <.icon
            name="hero-check"
            class={["ml-auto size-4 text-primary opacity-0", theme_check(theme)]}
          />
        </button>
      </el-menu>
    </el-dropdown>
    """
  end

  # The check mark shows for the active choice: the html tag carries data-theme and data-theme-source.
  defp theme_check("system"), do: "[[data-theme-source=system]_&]:opacity-100"
  defp theme_check("light"), do: "[[data-theme-source=user][data-theme=light]_&]:opacity-100"
  defp theme_check("dark"), do: "[[data-theme-source=user][data-theme=dark]_&]:opacity-100"

  @doc """
  The name of a country in the language of the page (the names are translated like any other text).
  """
  def country_name("in"), do: gettext("India")
  def country_name("es"), do: gettext("Spain")
  def country_name("us"), do: gettext("United States")
  def country_name("gb"), do: gettext("United Kingdom")
  def country_name("cn"), do: gettext("China")
  def country_name("de"), do: gettext("Germany")
  def country_name("jp"), do: gettext("Japan")
  def country_name("fr"), do: gettext("France")
  def country_name("it"), do: gettext("Italy")
  def country_name("br"), do: gettext("Brazil")
  def country_name("ca"), do: gettext("Canada")
  def country_name(code), do: String.upcase(code)

  @doc """
  The language and country switch for a header: a globe, the current choice, and a menu that lists the countries
  and, under each, its languages. A choice posts to `/locale`, which remembers it and goes to the same page in
  the new locale (see `QuickSlipsWeb.LocaleController`).

  The buttons of the menu are not inside the form: they name it with `form=`, which keeps the menu made of plain
  buttons, like the theme menu. The form takes the address of the page when it is submitted
  (`assets/js/locale.ts`); without scripts the server reads the `Referer`.
  """
  attr :id, :string, default: "locale-menu"
  attr :locale, :map, required: true, doc: "the locale of the page, from `QuickSlips.Locales`"
  attr :on_dark, :boolean, default: false

  def locale_menu(assigns) do
    assigns = assign(assigns, :groups, Locales.by_country())

    ~H"""
    <el-dropdown id={@id} class="relative">
      <button
        id={"#{@id}-trigger"}
        type="button"
        class={[
          "relative flex min-h-11 items-center gap-x-1.5 rounded-full px-3 focus-visible:outline-2 focus-visible:outline-offset-2",
          !@on_dark &&
            "text-ink-muted hover:bg-surface-muted hover:text-ink focus-visible:outline-focus",
          @on_dark &&
            "text-on-sidebar/80 hover:bg-on-sidebar/10 hover:text-on-sidebar focus-visible:outline-on-sidebar"
        ]}
      >
        <span class="sr-only">{gettext("Language and country")}</span>
        <.icon name="hero-globe-alt" class="size-5" />
        <span class="hidden text-sm/6 font-medium sm:inline">
          <span lang={@locale.language}>{@locale.name}</span> · {country_name(@locale.country)}
        </span>
        <.icon name="hero-chevron-down" class="hidden size-4 opacity-70 sm:block" />
      </button>
      <el-menu anchor="bottom end" popover class={["w-64", menu_class()]}>
        <p class="px-3 pt-1 pb-1 text-xs/5 font-semibold text-ink-muted">
          {gettext("Language and country")}
        </p>
        <div
          :for={{country, locales} <- @groups}
          role="group"
          aria-label={country_name(country)}
          class="border-t border-line py-1"
        >
          <p class="px-3 py-1 text-xs/5 text-ink-faint">{country_name(country)}</p>
          <button
            :for={locale <- locales}
            id={"#{@id}-#{locale.code}"}
            type="submit"
            form={"#{@id}-form"}
            name="locale"
            value={locale.code}
            lang={locale.language}
            aria-current={locale.code == @locale.code && "true"}
            class={["group", menu_item_class()]}
          >
            {locale.name}
            <.icon
              name="hero-check"
              class={["ml-auto size-4 text-primary", locale.code != @locale.code && "opacity-0"]}
            />
          </button>
        </div>
      </el-menu>
    </el-dropdown>
    <.locale_form id={"#{@id}-form"} />
    """
  end

  @doc """
  The same choice as a list for the footer: each country with its languages, the current one marked. It posts like
  `locale_menu/1`.
  """
  attr :id, :string, default: "footer-locale"
  attr :locale, :map, required: true

  def locale_picker(assigns) do
    assigns = assign(assigns, :groups, Locales.by_country())

    ~H"""
    <div id={@id}>
      <p class="flex items-center gap-x-2 text-sm/6 font-medium text-ink">
        <.icon name="hero-globe-alt" class="size-5 text-ink-muted" />
        {gettext("Language and country")}
      </p>
      <div class="mt-1 flex flex-wrap gap-x-8 gap-y-1">
        <div
          :for={{country, locales} <- @groups}
          role="group"
          aria-label={country_name(country)}
          class="flex flex-wrap items-center gap-x-1"
        >
          <span class="text-sm/6 text-ink-muted">{country_name(country)}</span>
          <button
            :for={locale <- locales}
            id={"#{@id}-#{locale.code}"}
            type="submit"
            form={"#{@id}-form"}
            name="locale"
            value={locale.code}
            lang={locale.language}
            aria-current={locale.code == @locale.code && "true"}
            class="inline-flex min-h-11 items-center rounded-field px-2 text-sm/6 text-ink hover:bg-surface-muted focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus aria-[current=true]:font-semibold aria-[current=true]:text-primary sm:min-h-9"
          >
            {locale.name}
          </button>
        </div>
      </div>
    </div>
    <.locale_form id={"#{@id}-form"} />
    """
  end

  # The form that the locale buttons submit (see `locale_menu/1`). It has nothing to show.
  attr :id, :string, required: true

  defp locale_form(assigns) do
    ~H"""
    <.form for={%{}} id={@id} action={~p"/locale"} method="post" data-locale-form class="hidden">
      <input type="hidden" name="from" value="" />
    </.form>
    """
  end

  @doc "The avatar menu in the app header: who you are, Settings, Log out."
  attr :id, :string, default: "user-menu"
  attr :user, :map, required: true

  def user_menu(assigns) do
    ~H"""
    <el-dropdown id={@id} class="relative">
      <button
        id={"#{@id}-trigger"}
        type="button"
        class="relative flex min-h-11 items-center gap-3 rounded-full pr-1 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
      >
        <span class="sr-only">{gettext("Open user menu")}</span>
        <.avatar initials={initials(@user)} />
        <span class="hidden lg:flex lg:items-center">
          <span class="text-sm/6 font-semibold text-ink">{display_name(@user)}</span>
          <.icon name="hero-chevron-down" class="ml-2 size-4 text-ink-faint" />
        </span>
      </button>
      <el-menu anchor="bottom end" popover class={["w-56", menu_class()]}>
        <div class="px-3 py-2">
          <p class="text-sm/6 font-semibold text-ink">{display_name(@user)}</p>
          <p class="truncate text-sm/6 text-ink-muted">{@user.email}</p>
        </div>
        <div class="border-t border-line pt-1">
          <.link id={"#{@id}-settings"} navigate={~p"/users/settings"} class={menu_item_class()}>
            <.icon name="hero-cog-6-tooth" class="size-5 text-ink-muted" /> {gettext("Settings")}
          </.link>
          <.link
            id={"#{@id}-logout"}
            href={~p"/users/log-out"}
            method="delete"
            class={menu_item_class()}
          >
            <.icon name="hero-arrow-right-start-on-rectangle" class="size-5 text-ink-muted" /> {gettext(
              "Log out"
            )}
          </.link>
        </div>
      </el-menu>
    </el-dropdown>
    """
  end

  defp display_name(user), do: if(user.name in [nil, ""], do: user.email, else: user.name)
end
