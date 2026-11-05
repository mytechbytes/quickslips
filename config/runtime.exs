import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/quickslips start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :quickslips, QuickSlipsWeb.Endpoint, server: true
end

config :quickslips, QuickSlipsWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

# Social Logins
config :ueberauth, Ueberauth.Strategy.Google.OAuth,
  client_id: System.get_env("GOOGLE_CLIENT_ID"),
  client_secret: System.get_env("GOOGLE_CLIENT_SECRET")

# Cloudflare Turnstile. Locally the keys come from .env (Cloudflare's dummy pair); the prod block below
# makes the release refuse to start without the real ones.
config :quickslips, :turnstile,
  site_key: System.get_env("TURNSTILE_SITE_KEY"),
  secret_key: System.get_env("TURNSTILE_SECRET_KEY")

# The people who may open the error dashboard (/admin/errors): e-mail addresses, comma-separated.
# Nobody can open it while this is empty.
config :quickslips,
       :admin_emails,
       "ADMIN_EMAILS"
       |> System.get_env("")
       |> String.split(",", trim: true)
       |> Enum.map(&(&1 |> String.trim() |> String.downcase()))

if config_env() == :dev do
  # Reload browser tabs when matching files change.
  config :quickslips, QuickSlipsWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        # Static assets, except user uploads
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
        # Gettext translations
        ~r"priv/gettext/.*\.po$"E,
        # Router, Controllers, LiveViews and LiveComponents
        ~r"lib/quickslips_web/router\.ex$"E,
        ~r"lib/quickslips_web/(controllers|live|components)/.*\.(ex|heex)$"E
      ]
    ]
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :quickslips, QuickSlips.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :quickslips, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")
  config :quickslips, :trust_cloudflare_ip, System.get_env("TRUST_CLOUDFLARE_IP") == "true"

  config :quickslips, QuickSlipsWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://bandit.hexdocs.pm/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :quickslips, QuickSlipsWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://plug.hexdocs.pm/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :quickslips, QuickSlipsWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # Email goes out over SMTP. All four values are required, so a release without them refuses to
  # start instead of silently dropping confirmation and log-in emails.
  smtp_host = System.fetch_env!("SMTP_HOST")
  smtp_port = String.to_integer(System.get_env("SMTP_PORT", "587"))
  # Port 465 is TLS from the first byte; the usual port 587 starts plain and upgrades (STARTTLS).
  smtp_implicit_tls? = smtp_port == 465

  # congis for turnstile
  config :quickslips, :turnstile,
    site_key: System.fetch_env!("TURNSTILE_SITE_KEY"),
    secret_key: System.fetch_env!("TURNSTILE_SECRET_KEY")

  # gen_smtp's defaults do not work with OTP 26 and later: its STARTTLS default has no CA list, and
  # its connection default is `depth: 0`, which rejects every certificate chain that has an
  # intermediate CA (that is all of them). These options verify the server's certificate against the
  # system CA store (the image installs ca-certificates).
  smtp_tls_options = [
    versions: [:"tlsv1.2", :"tlsv1.3"],
    verify: :verify_peer,
    depth: 10,
    cacerts: :public_key.cacerts_get(),
    server_name_indication: String.to_charlist(smtp_host),
    customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
  ]

  config :quickslips, QuickSlips.Mailer,
    adapter: Swoosh.Adapters.SMTP,
    relay: smtp_host,
    port: smtp_port,
    username: System.fetch_env!("SMTP_USERNAME"),
    password: System.fetch_env!("SMTP_PASSWORD"),
    auth: :always,
    ssl: smtp_implicit_tls?,
    tls: if(smtp_implicit_tls?, do: :never, else: :always),
    tls_options: smtp_tls_options,
    # gen_smtp opens an implicit-TLS connection with `sockopts` and ignores `tls_options` there.
    sockopts: if(smtp_implicit_tls?, do: smtp_tls_options, else: []),
    retries: 2

  # The address the emails are sent from (an address on a domain you control).
  config :quickslips, :mail_from, System.fetch_env!("MAIL_FROM")

  config :quickslips, :typst_bin, System.get_env("TYPST_BIN", "/usr/local/bin/typst")
  config :quickslips, :uploads_dir, System.get_env("UPLOADS_DIR", "/data/uploads")
end
