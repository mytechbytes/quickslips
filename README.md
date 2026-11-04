# QuickSlips

[![CI](https://github.com/mytechbytes/quickslips/actions/workflows/ci.yml/badge.svg)](https://github.com/mytechbytes/quickslips/actions/workflows/ci.yml)

QuickSlips generates bills and receipts as PDFs. It is a Phoenix 1.8 LiveView app, and the server renders the PDFs with [Typst](https://typst.app).

## Requirements

* Elixir and Erlang/OTP as pinned in `.tool-versions` (`mise install` sets them up) and Node as pinned in `.nvmrc`.
* Docker, for the local Postgres: `docker compose up -d`.
* The `typst` command on your PATH, at the version pinned in the `Dockerfile` (`brew install typst` on macOS). The renderer and its tests need it.

## Run it

```bash
docker compose up -d
npm ci --prefix assets
mix setup
mix phx.server
```

Then visit [`localhost:4000`](http://localhost:4000). `npm ci` comes first because `mix setup` copies the Typst WebAssembly files out of `assets/node_modules`.

## Checks

`mix precommit` is the check to run before a commit. It rewrites files to fix formatting.

GitHub Actions ([`ci.yml`](.github/workflows/ci.yml)) runs the same checks on every push and pull request, but verifies formatting instead of rewriting files, and fails on any warning:

```bash
mix format --check-formatted
mix deps.unlock --check-unused
mix compile --warnings-as-errors
mix test --warnings-as-errors
```

CI also builds the assets and the production Docker image.

## Deploy

CI builds the production image once, for arm64 (the architecture of the Dokploy server). On every push to `main`, after the checks pass, it publishes the image to `ghcr.io/mytechbytes/quickslips` as `latest` and `sha-<commit>`, then asks Dokploy to deploy. Dokploy only pulls that image; it never builds one.

One-time setup:

1. Merge to `main`, so CI publishes the first image. The deploy job reports "Skipped" until step 4.
2. On GitHub, open the `quickslips` package (your profile or organization → Packages → Package settings) and change its visibility to Public. The image holds no secrets: the configuration comes from Dokploy's environment variables.
3. In Dokploy, open the application → General → Provider → **Docker**. Set the image to `ghcr.io/mytechbytes/quickslips:latest` and leave the username, password and registry URL empty. Save, then deploy once by hand. The environment, domain and volume settings stay as they are.
4. Optional, to deploy on every push instead of pressing Deploy by hand. The Dokploy panel is only reachable over Tailscale, so the deploy job joins the tailnet first (the same setup as the `mangogst` repository). Add these repository secrets (GitHub → Settings → Secrets and variables → Actions, or `gh secret set NAME`); until all four exist, the job reports "Skipped":
   * `TS_AUTHKEY`: a Tailscale auth key that is ephemeral, reusable and tagged `tag:ci`. Auth keys expire after at most 90 days; an OAuth client does not (see the comment in `ci.yml`).
   * `DOKPLOY_URL`: the panel's tailnet address with its port, for example `http://<machine>.<tailnet>.ts.net:3000`. Not the public domain: Cloudflare challenges automated requests.
   * `DOKPLOY_API_KEY`: generated in Dokploy (Settings → Profile → API/CLI).
   * `DOKPLOY_APP_ID`: the id at the end of the application page's URL in Dokploy.

To roll back, set the image tag in Dokploy to an earlier `sha-<commit>` and deploy.

### Environment variables

Set these in Dokploy, on the application's Environment tab. `config/runtime.exs` reads them when the release starts.

| Variable | Value |
|---|---|
| `PHX_SERVER` | `true` |
| `PHX_HOST` | the public domain, for example `quickslips.example.com` |
| `SECRET_KEY_BASE` | the output of `mix phx.gen.secret` |
| `DATABASE_URL` | `ecto://USER:PASSWORD@HOST:5432/DATABASE` |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | the Google OAuth client, for "Continue with Google" |
| `SMTP_HOST`, `SMTP_USERNAME`, `SMTP_PASSWORD` | the SMTP details from your email provider |
| `SMTP_PORT` | optional, default `587` (STARTTLS); `465` uses TLS from the first byte |
| `MAIL_FROM` | the From address of every email, on a domain you control (set up SPF and DKIM for it) |
| `TYPST_BIN`, `UPLOADS_DIR`, `POOL_SIZE`, `PORT` | optional, with defaults in `runtime.exs` |

The release refuses to start without `SMTP_HOST`, `SMTP_USERNAME`, `SMTP_PASSWORD` and `MAIL_FROM`, so confirmation and log-in emails can never be dropped silently. The server's certificate is always verified against the system CA store. Any port other than 465 (for example 2525) is treated as STARTTLS.

## Where versions live

| What | Where |
|---|---|
| Elixir and Erlang/OTP | `.tool-versions` (CI reads it too), and the `ARG`s at the top of the `Dockerfile` |
| Node | `.nvmrc` (CI reads it too) |
| Typst, with checksums | the `Dockerfile` and `ci.yml` |

When you change one, change the others in the same commit. The first step of CI checks that `.tool-versions`, the `Dockerfile` and `ci.yml` agree and fails if they do not. Dependabot updates the Mix and npm packages and the workflow actions every week.

## Learn more

* Phoenix: https://www.phoenixframework.org/
* Guides: https://phoenix.hexdocs.pm/overview.html
* Docs: https://phoenix.hexdocs.pm
