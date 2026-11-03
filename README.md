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
