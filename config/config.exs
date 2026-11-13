# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :quickslips, :scopes,
  user: [
    default: true,
    module: QuickSlips.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: QuickSlips.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :quickslips,
  namespace: QuickSlips,
  ecto_repos: [QuickSlips.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :quickslips, QuickSlipsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: QuickSlipsWeb.ErrorHTML, json: QuickSlipsWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: QuickSlips.PubSub,
  live_view: [signing_salt: "Z2og3Y34"]

# Configure LiveView
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r"

# Social Logins
config :ueberauth, Ueberauth,
  providers: [google: {Ueberauth.Strategy.Google, [default_scope: "email profile"]}]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :quickslips, QuickSlips.Mailer, adapter: Swoosh.Adapters.Local

# The From address of every email. Production sets it from the MAIL_FROM environment variable.
config :quickslips, :mail_from, "no-reply@mytechbytes.in"

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  quickslips: [
    args:
      ~w(js/app.js js/preview_worker.ts --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.3",
  quickslips: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :quickslips, :typst_bin, "typst"

# Where people can support the site (the "Keep QuickSlips free" banner and the footer link); `nil` hides both.
config :quickslips, :support_url, "https://buymeacoffee.com/mytechbytes"

# The page for India (rupees, UPI), if it has one of its own; India uses the page above until then.
config :quickslips, :support_url_in, nil

# limits of quota for downloads PDF
config :quickslips, :quota, anonymous: 2, user: 10, ip: 20

# Messages of the contact form in a day: for one logged-in user and for the whole site (a mailbox can be flooded), and
# the confirmations that one address may be sent (it may not be the sender's). Everybody passes the Turnstile check
# as well.
config :quickslips, :contact_limits, user: 5, all: 100, to: 3

# Upload directory
config :quickslips, :uploads_dir, Path.expand("../priv/uploads", __DIR__)

# Error tracking (Task 7.8). Errors are kept in our own Postgres, with no third party. What may be stored
# and what is not worth storing are decided by QuickSlips.ErrorFilter and QuickSlips.ErrorIgnorer.
config :error_tracker,
  repo: QuickSlips.Repo,
  otp_app: :quickslips,
  filter: QuickSlips.ErrorFilter,
  ignorer: QuickSlips.ErrorIgnorer,
  # Errors you mark as resolved in the dashboard are deleted after a day.
  plugins: [ErrorTracker.Plugins.Pruner]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
