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
| `MICROSOFT_CLIENT_ID`, `MICROSOFT_CLIENT_SECRET` | optional: the app registered in the Azure portal (Microsoft Entra ID, "App registrations"), for "Continue with Microsoft". Its redirect URI is `https://<PHX_HOST>/auth/microsoft/callback`, and its client secret expires (24 months at most), so note the date. With either one missing there is no Microsoft button and `/auth/microsoft` is a 404 |
| `SMTP_HOST`, `SMTP_USERNAME`, `SMTP_PASSWORD` | the SMTP details from your email provider |
| `SMTP_PORT` | optional, default `587` (STARTTLS); `465` uses TLS from the first byte |
| `MAIL_FROM` | the From address of every email, on a domain you control. Best a sub-domain of its own (for example `hello@quickslips.example.com`), with SPF, DKIM and DMARC set up for it, so that the reputation of these e-mails stays apart from your own mailbox (see [E-mail](#e-mail)) |
| `TYPST_BIN`, `UPLOADS_DIR`, `POOL_SIZE`, `PORT` | optional, with defaults in `runtime.exs` |
| `CSP_MODE` | optional: `enforce` (the default in production), `report_only` or `off`. The Content-Security-Policy of the pages. If the browser console of the live site says the policy blocked something the site needs, set `report_only` and redeploy: the browser then only reports, and nothing is blocked while it is fixed |
| `CROSS_ORIGIN_OPENER_POLICY` | optional, default `same-origin`; `unsafe-none` or `off` while you use Google's Tag Assistant (the Tag Manager preview), which opens the site in a window and talks to it |

`priv/static/.well-known/microsoft-identity-association.json` is the file that Azure fetches to confirm that the domain belongs to the app (Branding & properties, Publisher domain). It is served as it is, with no redirect, at `https://<PHX_HOST>/.well-known/microsoft-identity-association.json`, and it holds the Application (client) ID of the app, so change it if the app is ever registered again. Cloudflare must let Microsoft's request through (no challenge for that address), or Azure cannot read it.

The release refuses to start without `SMTP_HOST`, `SMTP_USERNAME`, `SMTP_PASSWORD` and `MAIL_FROM`, so confirmation and log-in emails can never be dropped silently. The server's certificate is always verified against the system CA store. Any port other than 465 (for example 2525) is treated as STARTTLS.

## E-mail

The site sends five e-mails: confirm an account, log in with a link, confirm a new address, and the two of the contact form (one to you, one to the visitor). They are all made the same way, by `QuickSlips.Mail`: one branded layout with an HTML and a plain-text version, in the language the visitor chose on the site (the one to you is in English), with no tracking pixel and no tracked links. To see all of them, in every language, without sending anything:

```bash
mix quickslips.mail.preview
```

Then open `tmp/mail-preview/index.html` in a browser. In development the e-mails that the site really sends are also kept at `/dev/mailbox`.

What makes the mail reach the inbox and not the spam folder is partly outside the code:

- **The domain.** Send from a domain, or better a sub-domain, whose DNS has SPF, DKIM and DMARC for your mail provider. Add the records the provider shows, wait until it says "Verified", and only then change `MAIL_FROM` and redeploy (a DMARC policy of `reject` on the main domain also covers its sub-domains, so mail sent before the records exist is refused).
- **Tracking off.** In the provider, keep open tracking and click tracking off. They put a pixel into the HTML and send the links through another address, which breaks the log-in links and is not what the privacy page says.
- **A mailbox that is read.** Set `CONTACT_EMAIL`: it is the Reply-To of the account e-mails, and the foot of them says that a person reads the answers.
- **After a deploy**, send a sign-up e-mail to a Gmail, an Outlook and a Yahoo address and look at the original (in Gmail: the three dots, "Show original") for `SPF: PASS`, `DKIM: PASS` and `DMARC: PASS`. Mark the first ones "Not spam": a new sender builds its reputation by the way people treat its first e-mails.

The logo in the header is `priv/static/images/email/logo.png`, made from `logo-on-dark.svg` with Typst (the command is in `priv/email/logo.typ`), because e-mail programs block SVG. Its address must not change: old e-mails still show it.

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
