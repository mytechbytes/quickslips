defmodule QuickSlipsWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use QuickSlipsWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout. Every page starts with it.

  There are two shells, and the layout picks one by who is looking:

    * a visitor gets the **public shell**: a header with Log in and Sign up, and a footer;
    * a logged-in user gets the **app shell**: a dark sidebar on a laptop, a dark top bar on a phone.

  Pages never choose. They only pass `current_scope`.

  ## Examples

      <Layouts.app flash={@flash} current_scope={@current_scope}>
        <h1>Content</h1>
      </Layouts.app>

      <Layouts.app flash={@flash} current_scope={@current_scope} active={:dashboard} title="Dashboard">
        <:actions><.button navigate={~p"/"}>New document</.button></:actions>
        ...
      </Layouts.app>

  `active`, `title`, `subtitle` and `actions` only matter in the app shell: `active` highlights a
  sidebar item and `title` writes the page title band under the header.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  attr :active, :atom,
    default: nil,
    doc: "the sidebar item to highlight, one of the keys in nav_items/0"

  attr :title, :string, default: nil, doc: "the page title (app shell)"
  attr :subtitle, :string, default: nil, doc: "a line under the title (app shell)"
  slot :actions, doc: "buttons at the right of the title (app shell)"
  slot :inner_block, required: true

  def app(assigns) do
    if signed_in?(assigns.current_scope), do: app_shell(assigns), else: public_shell(assigns)
  end

  # The sidebar items. Add one when its page exists (Milestones 8 and 9), for example:
  #   {:documents, "Documents", "hero-document-text", ~p"/documents"}
  defp nav_items do
    [
      {:dashboard, "Dashboard", "hero-squares-2x2", ~p"/dashboard"},
      {:businesses, "Saved businesses", "hero-building-storefront", ~p"/businesses"}
    ]
  end

  ## The public shell (visitors)

  defp public_shell(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col">
      <header class="border-b border-line bg-surface">
        <nav
          aria-label="Global"
          class="mx-auto flex max-w-7xl items-center justify-between gap-x-4 px-4 py-3 sm:px-6 lg:px-8"
        >
          <div class="flex items-center gap-x-10">
            <.wordmark id="logo" navigate={~p"/"} />
            <div class="hidden lg:flex lg:gap-x-8">
              <.link
                id="nav-templates"
                navigate={~p"/"}
                class="rounded-field text-sm/6 font-semibold text-ink-muted hover:text-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
              >
                Templates
              </.link>
            </div>
          </div>
          <div class="flex items-center gap-x-1 sm:gap-x-2">
            <.theme_menu id="theme-menu" />
            <div class="hidden items-center gap-x-2 lg:flex">
              <.button id="header-login" variant="ghost" navigate={~p"/users/log-in"}>Log in</.button>
              <.button id="header-signup" navigate={~p"/users/register"}>Sign up</.button>
            </div>
            <button
              id="open-menu"
              type="button"
              command="show-modal"
              commandfor="mobile-menu"
              class="flex size-11 items-center justify-center rounded-full text-ink-muted hover:bg-surface-muted hover:text-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus lg:hidden"
            >
              <span class="sr-only">Open main menu</span>
              <.icon name="hero-bars-3" class="size-6" />
            </button>
          </div>
        </nav>
      </header>

      <%!-- The phone menu: a dialog that slides in from the right. Elements keeps its open state. --%>
      <el-dialog phx-update="ignore" id="mobile-menu-wrapper">
        <dialog id="mobile-menu" class="backdrop:bg-transparent lg:hidden">
          <el-dialog-backdrop class="fixed inset-0 bg-overlay transition-opacity motion-reduce:transition-none data-closed:opacity-0">
          </el-dialog-backdrop>
          <div tabindex="0" class="fixed inset-0 focus:outline-none">
            <el-dialog-panel class="fixed inset-y-0 right-0 z-50 w-full overflow-y-auto bg-surface p-6 transition duration-300 ease-in-out motion-reduce:transition-none data-closed:translate-x-full sm:max-w-sm sm:ring-1 sm:ring-line">
              <div class="flex items-center justify-between">
                <.wordmark id="menu-logo" navigate={~p"/"} />
                <button
                  id="close-menu"
                  type="button"
                  command="close"
                  commandfor="mobile-menu"
                  class="flex size-11 items-center justify-center rounded-full text-ink-muted hover:bg-surface-muted hover:text-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
                >
                  <span class="sr-only">Close menu</span>
                  <.icon name="hero-x-mark" class="size-6" />
                </button>
              </div>
              <div class="mt-6 flow-root">
                <div class="-my-6 divide-y divide-line">
                  <div class="space-y-1 py-6">
                    <.link
                      id="menu-templates"
                      navigate={~p"/"}
                      class="-mx-3 flex min-h-11 items-center rounded-card px-3 py-2 text-base/7 font-semibold text-ink hover:bg-surface-muted focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
                    >
                      Templates
                    </.link>
                  </div>
                  <div class="grid grid-cols-2 gap-3 py-6">
                    <.button id="menu-login" variant="secondary" navigate={~p"/users/log-in"}>Log in</.button>
                    <.button id="menu-signup" navigate={~p"/users/register"}>Sign up</.button>
                  </div>
                </div>
              </div>
            </el-dialog-panel>
          </div>
        </dialog>
      </el-dialog>

      <main class="mx-auto w-full max-w-7xl grow px-4 sm:px-6 lg:px-8">
        {render_slot(@inner_block)}
      </main>

      <footer class="border-t border-line">
        <div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
          <p class="text-sm/6 text-ink-muted">
            © {Date.utc_today().year} QuickSlips. We create documents from the details you enter.
            You are responsible for their accuracy and for using them lawfully.
          </p>
        </div>
      </footer>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  ## The app shell (logged-in users)

  defp app_shell(assigns) do
    assigns = assign(assigns, :user, assigns.current_scope.user)

    ~H"""
    <%!-- Phone: a dark top bar with a menu --%>
    <div class="lg:hidden">
      <nav aria-label="Main" class="bg-sidebar">
        <div class="mx-auto max-w-7xl px-4 sm:px-6">
          <div class="flex h-16 items-center justify-between">
            <.wordmark id="m-logo" tone={:sidebar} navigate={~p"/dashboard"} />
            <div class="-mr-2 flex items-center gap-x-1">
              <.theme_menu id="m-theme-menu" on_dark />
              <button
                id="mobile-menu-toggle"
                type="button"
                command="--toggle"
                commandfor="mobile-menu"
                class="relative inline-flex size-11 items-center justify-center rounded-full text-on-sidebar/80 hover:bg-on-sidebar/10 hover:text-on-sidebar focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-on-sidebar"
              >
                <span class="sr-only">Open main menu</span>
                <.icon name="hero-bars-3" class="size-6 in-aria-expanded:hidden" />
                <.icon name="hero-x-mark" class="size-6 not-in-aria-expanded:hidden" />
              </button>
            </div>
          </div>
        </div>
        <el-disclosure id="mobile-menu" hidden class="block">
          <div class="space-y-1 px-2 pt-2 pb-3 sm:px-3">
            <.button id="m-new-document" navigate={~p"/"} block on_dark class="mb-2">
              <.icon name="hero-plus" class="size-5" /> New document
            </.button>
            <.link
              :for={{key, label, ic, path} <- nav_items()}
              id={"m-nav-#{key}"}
              navigate={path}
              aria-current={@active == key && "page"}
              class="flex min-h-11 items-center gap-x-3 rounded-button px-3 py-2 text-base font-medium text-on-sidebar/80 hover:bg-on-sidebar/10 hover:text-on-sidebar aria-[current=page]:bg-on-sidebar/10 aria-[current=page]:text-on-sidebar focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-on-sidebar"
            >
              <.icon name={ic} class="size-5 shrink-0" />{label}
            </.link>
          </div>
          <div class="border-t border-on-sidebar/20 pt-4 pb-3">
            <div class="flex items-center px-5">
              <.avatar initials={initials(@user)} class="size-10" />
              <div class="ml-3 min-w-0">
                <div class="truncate text-base font-medium text-on-sidebar">
                  {@user.name || @user.email}
                </div>
                <div class="truncate text-sm font-medium text-on-sidebar/70">{@user.email}</div>
              </div>
            </div>
            <div class="mt-3 space-y-1 px-2">
              <.link
                id="m-settings"
                navigate={~p"/users/settings"}
                aria-current={@active == :settings && "page"}
                class="flex min-h-11 items-center gap-x-3 rounded-button px-3 py-2 text-base font-medium text-on-sidebar/80 hover:bg-on-sidebar/10 hover:text-on-sidebar aria-[current=page]:bg-on-sidebar/10 aria-[current=page]:text-on-sidebar focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-on-sidebar"
              >
                <.icon name="hero-cog-6-tooth" class="size-5 shrink-0" /> Settings
              </.link>
              <.link
                id="m-logout"
                href={~p"/users/log-out"}
                method="delete"
                class="flex min-h-11 items-center gap-x-3 rounded-button px-3 py-2 text-base font-medium text-on-sidebar/80 hover:bg-on-sidebar/10 hover:text-on-sidebar focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-on-sidebar"
              >
                <.icon name="hero-arrow-right-start-on-rectangle" class="size-5 shrink-0" /> Log out
              </.link>
            </div>
          </div>
        </el-disclosure>
      </nav>
    </div>

    <%!-- Laptop: the dark sidebar --%>
    <nav
      aria-label="Main"
      class="hidden bg-sidebar ring-1 ring-on-sidebar/10 lg:fixed lg:inset-y-0 lg:z-50 lg:flex lg:w-72 lg:flex-col"
    >
      <div class="flex grow flex-col gap-y-5 overflow-y-auto px-6 pb-4">
        <div class="flex h-16 shrink-0 items-center">
          <.wordmark id="logo" tone={:sidebar} navigate={~p"/dashboard"} />
        </div>
        <.button id="new-document" navigate={~p"/"} block on_dark>
          <.icon name="hero-plus" class="size-5" /> New document
        </.button>
        <div class="flex flex-1 flex-col">
          <ul role="list" class="flex flex-1 flex-col gap-y-7">
            <li>
              <ul role="list" class="-mx-2 space-y-1">
                <li :for={{key, label, ic, path} <- nav_items()}>
                  <.link
                    id={"nav-#{key}"}
                    navigate={path}
                    aria-current={@active == key && "page"}
                    class="group flex min-h-11 items-center gap-x-3 rounded-field p-2 text-sm/6 font-semibold text-on-sidebar/70 hover:bg-on-sidebar/5 hover:text-on-sidebar aria-[current=page]:bg-on-sidebar/10 aria-[current=page]:text-on-sidebar focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-on-sidebar"
                  >
                    <.icon name={ic} class="size-6 shrink-0" />{label}
                  </.link>
                </li>
              </ul>
            </li>
            <li class="mt-auto">
              <ul role="list" class="-mx-2 space-y-1">
                <li>
                  <.link
                    id="nav-settings"
                    navigate={~p"/users/settings"}
                    aria-current={@active == :settings && "page"}
                    class="group flex min-h-11 items-center gap-x-3 rounded-field p-2 text-sm/6 font-semibold text-on-sidebar/70 hover:bg-on-sidebar/5 hover:text-on-sidebar aria-[current=page]:bg-on-sidebar/10 aria-[current=page]:text-on-sidebar focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-on-sidebar"
                  >
                    <.icon name="hero-cog-6-tooth" class="size-6 shrink-0" /> Settings
                  </.link>
                </li>
              </ul>
            </li>
          </ul>
        </div>
      </div>
    </nav>

    <div class="lg:pl-72">
      <header class="sticky top-0 z-40 hidden h-16 shrink-0 items-center gap-x-3 border-b border-line bg-surface px-8 lg:flex">
        <div class="ml-auto flex items-center gap-x-3">
          <.theme_menu id="theme-menu" />
          <div aria-hidden="true" class="h-6 w-px bg-line"></div>
          <.user_menu id="user-menu" user={@user} />
        </div>
      </header>

      <main>
        <div :if={@title} class="border-b border-line bg-surface lg:border-0 lg:bg-transparent">
          <div class="mx-auto max-w-7xl px-4 py-5 sm:px-6 lg:px-8 lg:pt-8 lg:pb-0">
            <div class="sm:flex sm:items-center sm:justify-between sm:gap-x-6">
              <div>
                <h1 class="font-display text-2xl/8 font-semibold tracking-tight text-ink">
                  {@title}
                </h1>
                <p :if={@subtitle} class="mt-1 text-sm/6 text-ink-muted">{@subtitle}</p>
              </div>
              <div :if={@actions != []} class="mt-4 flex gap-x-3 sm:mt-0 sm:shrink-0">
                {render_slot(@actions)}
              </div>
            </div>
          </div>
        </div>
        <div class="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8 lg:py-8">
          {render_slot(@inner_block)}
        </div>
      </main>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  The messages sit in a fixed live region at the top right, so a screen reader reads each
  new one aloud and nothing on the page moves.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div
      id={@id}
      aria-live="polite"
      class="pointer-events-none fixed inset-x-0 top-0 z-60 flex flex-col items-end gap-3 p-4 sm:p-6"
    >
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
