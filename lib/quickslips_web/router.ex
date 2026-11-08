defmodule QuickSlipsWeb.Router do
  use QuickSlipsWeb, :router
  use ErrorTracker.Web, :router

  import QuickSlipsWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {QuickSlipsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug QuickSlipsWeb.Plugs.VisitorId

    # Reads `:locale` of `/:locale` and `/:locale/:slug` (the last routes below); other routes pass through.
    plug QuickSlipsWeb.Plugs.Locale
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_session do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :fetch_current_scope_for_user
    plug :protect_from_forgery
    plug QuickSlipsWeb.Plugs.VisitorId
  end

  # scope "/", QuickSlipsWeb do
  #   pipe_through :browser

  #   get "/", PageController, :home
  # end

  # Other scopes may use custom stacks.
  scope "/api", QuickSlipsWeb do
    pipe_through :api_session

    post "/generate", GenerateController, :create
    get "/quota", QuotaController, :show
    get "/bill/:slug/view", BillViewController, :show

    # Saved from a bill's page without leaving it. A logged-in user only: the controllers say 401 otherwise.
    post "/signatures", SignatureController, :create
    post "/businesses", BusinessController, :create
  end

  # What search engines read. No session and no cookie: a crawler gets the same answer as everybody, whatever it asks
  # for (the `:browser` pipeline only takes HTML). Like /healthz, these single-segment addresses must come above
  # `/:locale`, which would take them for a locale.
  scope "/", QuickSlipsWeb do
    get "/robots.txt", RobotsController, :show
    get "/sitemap.xml", SitemapController, :show
    get "/sitemap.xsl", SitemapController, :stylesheet
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:quickslips, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: QuickSlipsWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  # The error dashboard (Task 7.8). Only the people in ADMIN_EMAILS may open it; everyone else gets a 404.
  scope "/admin" do
    pipe_through [:browser, :require_authenticated_user, :require_admin]

    error_tracker_dashboard "/errors", on_mount: [{QuickSlipsWeb.UserAuth, :require_admin}]
  end

  scope "/auth", QuickSlipsWeb do
    pipe_through :browser

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
  end

  ## Authentication routes

  # Everything that is not a LiveView and needs a login: a controller route is guarded by the plug.
  scope "/", QuickSlipsWeb do
    pipe_through [:browser, :require_authenticated_user]

    post "/users/update-password", UserSessionController, :update_password
    get "/uploads/:user_id/:file", UploadController, :show
    get "/history/:id/download", HistoryController, :download
  end

  # Everything that works with or without a login, in the `:browser` pipeline. The order matters at the end:
  # `/:locale` and `/:locale/:slug` match any one and any two segments, so they come after every route that
  # has a fixed first segment, and a new single-segment route (like /healthz) goes above them.
  scope "/", QuickSlipsWeb do
    pipe_through [:browser]

    # `/` has no page: it leads to the home page of the visitor's locale. Links inside the site go to the
    # home page of the locale directly.
    get "/", RootController, :index

    # The language and country switch: remembers the choice, then goes to the same page in the new locale.
    post "/locale", LocaleController, :update
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete

    get "/source/:slug/:template", TemplateSourceController, :show
    get "/healthz", HealthController, :show

    # One live session for every page of the site, so that a click on a link is a live navigation (no new
    # page) wherever it goes: the catalogue, a bill, the dashboard. A live navigation only works inside one
    # live session, and it does not run the plugs again; so each LiveView that needs a login says so with
    # `on_mount {QuickSlipsWeb.UserAuth, :require_authenticated}`, and its first load is guarded by the plug.
    live_session :current_user,
      on_mount: [
        {QuickSlipsWeb.Plugs.Locale, :default},
        {QuickSlipsWeb.UserAuth, :mount_current_scope}
      ] do
      scope "/" do
        pipe_through [:require_authenticated_user]

        live "/users/settings", UserLive.Settings, :edit
        live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
        live "/dashboard", DashboardLive, :index
        live "/businesses", BusinessLive.Index, :index
        live "/businesses/new", BusinessLive.Form, :new
        live "/businesses/:id", BusinessLive.Show, :show
        live "/businesses/:id/edit", BusinessLive.Form, :edit
        live "/signatures", SignatureLive.Index, :index
        live "/history", HistoryLive, :index
      end

      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new

      # The sitemap for people; the one for search engines is /sitemap.xml (a controller, above). Like every
      # single-segment address, it comes above `/:locale`.
      live "/sitemap", SitemapLive, :index

      # The legal pages: English only, one address each (not under a locale), above `/:locale` like the others.
      live "/terms", LegalLive, :terms
      live "/privacy", LegalLive, :privacy
      live "/disclaimer", LegalLive, :disclaimer

      # The catalogue of a locale: /en-in, /hi-in, /es-es. An old template address (/fuel-bill) also arrives
      # here, and the locale plug moves it to its new page.
      live "/:locale", HomeLive, :index

      # A bill under its locale: /en-in/fuel-bill-generator. The slug is the public one, which can differ per
      # language; the LiveView finds the template through the locale.
      live "/:locale/:slug", TemplateLive, :show
    end
  end
end
