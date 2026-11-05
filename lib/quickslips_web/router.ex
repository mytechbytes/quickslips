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

  scope "/", QuickSlipsWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{QuickSlipsWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      live "/dashboard", DashboardLive, :index
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", QuickSlipsWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{QuickSlipsWeb.UserAuth, :mount_current_scope}] do
      live "/", HomeLive, :index
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete

    get "/source/:slug/:template", TemplateSourceController, :show
    get "/healthz", HealthController, :show
    get "/:slug", TemplateController, :show
  end
end
