defmodule QuickSlipsWeb.HomeLive do
  use QuickSlipsWeb, :live_view

  import QuickSlipsWeb.CatalogueComponents

  alias QuickSlips.Locales
  alias QuickSlips.Templates

  # The catalogue of one locale (`/en-in`, `/hi-in`): the templates that are in its language, named in it.
  @impl true
  def mount(%{"locale" => code}, _session, socket) do
    locale =
      case Locales.fetch(code) do
        {:ok, locale} -> locale
        :error -> raise QuickSlipsWeb.NotFoundError
      end

    # The address decides, whatever the session says: this page is the catalogue of that locale.
    Gettext.put_locale(QuickSlipsWeb.Gettext, locale.language)

    socket =
      socket
      |> assign(
        page_title: gettext("Free bill and receipt generator"),
        locale: locale,
        categories: Templates.categories(locale),
        query: "",
        category: "all"
      )
      |> stream_configure(:templates, dom_id: &"template-#{&1["slug"]}")
      |> stream_templates()

    {:ok, socket}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, socket |> assign(:query, query) |> stream_templates()}
  end

  def handle_event("category", %{"category" => category}, socket) do
    {:noreply, socket |> assign(:category, category) |> stream_templates()}
  end

  # Re-stream the whole list with `reset: true` whenever the filter changes.
  defp stream_templates(socket) do
    %{locale: locale, query: query, category: category} = socket.assigns

    templates =
      Enum.filter(Templates.list(locale), fn template ->
        matches_category?(template, category) and matches_query?(template, query)
      end)

    stream(socket, :templates, templates, reset: true)
  end

  defp matches_category?(_template, "all"), do: true
  defp matches_category?(template, category), do: template["category"] == category

  defp matches_query?(template, query) do
    haystack =
      String.downcase("#{template["title"]} #{template["summary"]} #{template["category_name"]}")

    String.contains?(haystack, query |> String.trim() |> String.downcase())
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      locale={@locale}
      title={if signed_in?(@current_scope), do: gettext("Templates")}
      subtitle={if signed_in?(@current_scope), do: gettext("Pick one to start a new document.")}
    >
      <section
        :if={!signed_in?(@current_scope)}
        aria-labelledby="home-title"
        class="mx-auto max-w-3xl pt-10 pb-6 text-center lg:pt-16 lg:pb-8"
      >
        <h1
          id="home-title"
          class="font-display text-3xl font-bold tracking-tight text-balance text-ink sm:text-4xl lg:text-5xl"
        >
          {gettext("Bills and receipts, ready in seconds")}
        </h1>
        <p class="mx-auto mt-3 max-w-xl text-base/7 text-pretty text-ink-muted lg:mt-4 lg:max-w-2xl lg:text-lg/8">
          {gettext("Pick a template, fill in the form and download the PDF. No account needed.")}
        </p>
      </section>

      <div
        id="catalogue"
        class={[signed_in?(@current_scope) && "pt-0", !signed_in?(@current_scope) && "pb-16"]}
      >
        <form
          id="template-search-form"
          phx-change="search"
          phx-submit="search"
          class="lg:mx-auto lg:max-w-xl"
        >
          <.search_input
            id="template-search"
            value={@query}
            label={gettext("Search templates")}
            placeholder={gettext("Search templates, like fuel or rent")}
          />
        </form>

        <div class="mt-6">
          <.category_chips categories={@categories} selected={@category} />
        </div>

        <ul
          id="template-list"
          phx-update="stream"
          role="list"
          class="mt-6 grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-4"
        >
          <li
            id="no-templates"
            class="hidden only:block col-span-full rounded-card border-2 border-dashed border-line-strong px-6 py-10 text-center text-sm/6 text-ink-muted"
          >
            {gettext("No template matches your search.")}
          </li>
          <.template_card :for={{id, template} <- @streams.templates} id={id} template={template} />
        </ul>

        <div
          :if={!signed_in?(@current_scope)}
          class="mt-12 rounded-card bg-primary-soft px-6 py-8 sm:flex sm:items-center sm:justify-between sm:gap-8 sm:px-8"
        >
          <div>
            <h2 class="text-lg/7 font-semibold text-ink">
              {gettext("Need more than 2 downloads a day?")}
            </h2>
            <p class="mt-1 text-sm/6 text-ink-muted">
              {gettext("Log in or sign up to make more documents.")}
            </p>
          </div>
          <div class="mt-5 flex gap-3 sm:mt-0 sm:shrink-0">
            <.button id="cta-login" variant="secondary" navigate={~p"/users/log-in"}>
              {gettext("Log in")}
            </.button>
            <.button id="cta-signup" navigate={~p"/users/register"}>
              {gettext("Sign up")}
            </.button>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
