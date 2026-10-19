# QuickSlips: detailed step-by-step build guide

This is the long version of `Build plan (step by step).md`. Every task from the plan is here, in the same order and with the same numbers, but each one now has:

- **Why**: the idea behind the task, so you learn instead of copy.
- **Do it**: exact commands and steps.
- **Code**: the files to open, annotated, and the code you write.
- **Check**: how to know it worked.
- **Pitfalls**: what usually goes wrong.
- **Commit**: a suggested commit message.

When you start a task, tell me its number (for example "Task 1.4") and I'll walk through it with you.

## Contents

- [How to read this file](#how-to-read-this-file)
- [Where your project is right now](#where-your-project-is-right-now)
- [Corrections to the plan](#corrections-to-the-plan)
- [Daily workflow](#daily-workflow)
- [Milestone 0: Set up (recap)](#milestone-0-set-up-recap)
- [Milestone 1: Email and password login](#milestone-1-email-and-password-login)
- [Milestone 2: Continue with Google](#milestone-2-continue-with-google)
- [Milestone 3: Layout and template catalogue](#milestone-3-layout-and-template-catalogue)
- [Milestone 4: First PDF from the server](#milestone-4-first-pdf-from-the-server)
- [Milestone 5: Form and live WASM preview](#milestone-5-form-and-live-wasm-preview)
- [Milestone 6: 2 free downloads a day](#milestone-6-2-free-downloads-a-day)
- [Milestone 7: Account features](#milestone-7-account-features)
- [Milestone 8: Payments and bulk](#milestone-8-payments-and-bulk)
- [Milestone 9: Deploy to production](#milestone-9-deploy-to-production)
- [Appendix A: command cheat sheet](#appendix-a-command-cheat-sheet)
- [Appendix B: when something breaks](#appendix-b-when-something-breaks)

---

## How to read this file

Two kinds of statements appear in this guide, and I mark them differently so you know how much to trust each one.

- **✅ Checked.** I read it in your project (`mix.exs`, `router.ex`, config) or in the generator templates inside `deps/phoenix/priv/templates/phx.gen.auth/`. Milestones 0 to 2 lean heavily on this.
- **⚠️ Verify.** It comes from my general knowledge of a library (typst.ts, Oban, Razorpay, Turnstile, and so on). Versions move, so check the library's own docs before you rely on it. These notes appear as `> ⚠️ Verify:` callouts.

**Code I wrote in this file has not been compiled.** I was asked not to run anything while writing it. Treat the snippets as a very good first draft. If one doesn't compile or a test fails, paste the error to me with the task number and we'll fix it together.

Conventions:

- Commands run from the project root (`~/development/projects/quickslips`) unless stated.
- `QuickSlips` is the business-logic namespace (`lib/quickslips/`), `QuickSlipsWeb` is the web layer (`lib/quickslips_web/`).
- Generated file paths are what Phoenix 1.8 normally produces. Run `git status` after a generator and trust that over this file.

---

## Where your project is right now

✅ Checked on 2026-10-19:

| Thing | State |
|---|---|
| Elixir / Erlang | Elixir 1.20.4 on OTP 28 |
| Phoenix | 1.8.15, LiveView 1.2 |
| Assets | Tailwind 4.3.3, esbuild 0.25.4, daisyUI plugin installed, `assets/tsconfig.json` present |
| Database | `postgres:16` container is up (`docker compose ps`); no migrations exist yet |
| Typst | `/opt/homebrew/bin/typst`, version 0.15.1 |
| Git | One commit on `main` ("Application scaffolded"), working tree clean |
| Router | Only `get "/", PageController, :home` plus the dev dashboard and `/dev/mailbox` |
| Auth | None yet. `lib/quickslips/` has only `application.ex`, `mailer.ex`, `repo.ex` |

Project rules from `AGENTS.md` that this guide follows:

- Run `mix precommit` when a set of changes is finished, and fix what it reports.
- HTTP calls use `Req`, never HTTPoison/Tesla/httpc.
- Templates start with `<Layouts.app flash={@flash} current_scope={@current_scope}>`.
- Forms use `to_form/2`, `<.form for={@form}>` and `<.input>`; always give forms and key elements a unique `id`.
- Lists in LiveView use streams.
- Never put an inline `<script>` in a template. Scripts live in `assets/js/` or are colocated hooks.
- You can't add `<script src="https://...">` to a layout. Third-party scripts (Turnstile, Razorpay) get loaded from a hook. Tasks 6.5 and 8.2 show how.
- Write your own Tailwind components rather than leaning on daisyUI. The generated auth pages use daisyUI classes (`btn`, `alert`), which is fine to start with. Milestone 3 gives the site its own look.

---

## Corrections to the plan

Reading the real generator output turned up places where the plan and Phoenix 1.8 disagree. None of them change the order of work, but you should know about them before you hit them.

1. **There is no "Forgot password" page in Phoenix 1.8.** ✅ "Reset a forgotten password" means: log in with an email link (magic link) → open Settings → set a new password. Task 1.7 tests that exact flow. If you want a "Forgot your password?" link, it points at the "Log in with email" form.
2. **Password at sign-up collides with the email confirmation link.** ✅ In `Accounts.login_user_by_magic_link/1` the generator deliberately `raise`s when an unconfirmed user has a password. If you only do what Task 1.4 says, clicking the confirmation link crashes. Phoenix's own docs say why: an attacker could register your email with *their* password, and you'd later "confirm" an account they can still log into. Task 1.4 includes the fix: confirmation requires typing the password you chose.
3. **The generator already puts a login menu in the layout.** ✅ It injects a `<ul class="menu ...">` into `root.html.heex` (after `<body>`, because your root layout has no `<nav>`). Task 1.6 becomes "restyle and extend what's there".
4. **Linking a Google account to an existing unconfirmed password account** (Task 2.4) needs the same care as point 2. The guide shows the one extra line that closes the hole.
5. **`templates/` location (Task 3.2).** I suggest `priv/bill_templates/` instead. Anything under `priv/` is automatically included in a production release, so you never have to remember to copy the folder in the Dockerfile. Phoenix also uses `priv/templates/` for generator overrides, which is why I avoid that exact name. Use `templates/` if you prefer; just adjust paths.
6. **Section 5 of your "main tab" document.** The plan refers to a schema format described there. I don't have that document, so Task 3.2 proposes a simple format. Swap in yours if it differs.
7. **`Registry` name clash (Task 3.3).** Elixir already has a built-in `Registry` module. `QuickSlips.Templates.Registry` is fine (the full name is different) but be aware of it when reading error messages.
8. **Node.js is needed from Milestone 5.** The plan never installs it. `brew install node` is only needed for `npm install` of typst.ts. The Phoenix build itself stays on esbuild.

---

## Daily workflow

Use the same loop for every task. It keeps you out of trouble.

```bash
# 1. Start from a clean, known state
git status                       # should be clean, or only contain the task you're on
docker compose up -d             # Postgres
mix test                         # should be green before you start a task

# 2. Do the task (edit, run the server, click around)
mix phx.server                   # http://localhost:4000

# 3. Finish the task
mix precommit                    # compile with warnings as errors, format, run tests
git add -A
git commit -m "Task X.Y: what you did"
```

Tips:

- One task, one commit. Small commits make it easy to undo a mistake: `git revert <hash>`.
- Work on a branch per milestone: `git switch -c m1-auth`. When the milestone's "Done when" is true, merge it to `main` and push.
- If a generator touched many files and you aren't sure what happened, `git diff` is your friend, and `git restore .` plus `git clean -fd` throws it all away (careful: this deletes uncommitted work).
- `iex -S mix` opens an interactive shell with your whole app loaded. It's the best way to try a function before wiring it into the web layer.

---

## Milestone 0: Set up (recap)

All five tasks are ticked in your plan. This recap is only here so the guide is complete, plus a quick health check you can run any time.

### Tasks 0.1 to 0.5 (done)

| Task | What it gave you |
|---|---|
| 0.1 Install tools | Postgres in Docker, Typst CLI, Hex, `phx_new` |
| 0.2 Elixir basics | Modules, pattern matching, pipes, maps/structs, `case`/`with`, `{:ok, _}`/`{:error, _}` |
| 0.3 Create the app | `mix phx.new . --app quickslips --module QuickSlips` |
| 0.4 Tour the folders | `lib/quickslips/` (logic), `lib/quickslips_web/` (web), `config/`, `priv/repo/migrations/` |
| 0.5 Git | Repo initialised, first commit made |

### Health check

```bash
docker compose ps                 # db container "Up"
mix test                          # should pass (3 starter tests)
mix phx.server                    # http://localhost:4000 shows the Phoenix welcome page
git log --oneline                 # at least "Application scaffolded"
git remote -v                     # shows your GitHub URL; empty output means Task 0.5's push never happened
```

If `git remote -v` prints nothing, create a private GitHub repo and run:

```bash
git remote add origin git@github.com:<you>/quickslips.git
git push -u origin main
```

### Mini-lesson: how a request travels

You'll keep coming back to this picture, so learn it now:

```
Browser  ->  Endpoint  ->  Router  ->  pipeline (:browser)  ->  Controller or LiveView  ->  Context  ->  Repo/DB
                            |             plugs: session,           (web layer)             (logic)
                            |             CSRF, current user
                            +-- matches the URL and HTTP verb
```

- **Endpoint** (`endpoint.ex`): the front door; static files, sessions, body parsing.
- **Router** (`router.ex`): maps `GET /users/log-in` to a module.
- **Pipeline**: a named list of plugs that run before your code. `:browser` loads the session and protects against CSRF.
- **Controller / LiveView**: the web layer. It translates between HTTP and your logic.
- **Context** (`Accounts`, later `Templates`, `Quota`, ...): plain Elixir modules with the real logic. The web layer calls *only* these.
- **Schema + changeset**: a schema describes a table; a changeset validates changes before they reach the DB.

---

## Milestone 1: Email and password login

**Goal:** a visitor can register with email and password, confirm their email, log in, log out, and reset or change the password.

**Elixir you'll meet:** changesets, `with`, pattern matching in function heads, guards (`when`), plugs, `on_mount` hooks.

**Know this first.** ✅ Phoenix 1.8's generator builds a *magic-link first* system:

- Register with an **email only**; Phoenix emails a link.
- Clicking the link confirms the account and logs you in.
- A password is optional and is set later on the Settings page.

You want passwords at sign-up, so Task 1.4 bends the generated code. Do 1.1 to 1.3 first, using it as generated. That way you can tell what the generator wrote from what you changed.

### Task 1.1: Generate auth

**Why.** Authentication is easy to get subtly wrong (timing attacks, session fixation, token reuse). `mix phx.gen.auth` produces code written and reviewed by the Phoenix team. You own the result: it lands in your project as normal files you can edit.

**Do it.**

```bash
docker compose up -d                          # make sure Postgres is up
mix test                                      # baseline: green before we touch anything
mix phx.gen.auth Accounts User users --live   # --live = LiveView pages instead of controllers
mix deps.get
mix ecto.migrate
```

The three words after `phx.gen.auth` mean: context module `Accounts`, schema module `User`, table name `users`. If you leave off `--live`, Phoenix asks "Do you want to create a LiveView based authentication system?" and you answer `Y`.

**What happens.**

- The generator prints a long list of `* creating ...` and `* injecting ...` lines.
- It **edits existing files**: `mix.exs` (adds `bcrypt_elixir`), `config/test.exs` (cheaper hashing in tests), `router.ex`, `root.html.heex` (menu), `conn_case.ex` (test helpers).
- It tells you to run `mix deps.get` and `mix ecto.migrate`; you ran both above.

**Code created (✅ from the templates; confirm with `git status`):**

| File | Purpose |
|---|---|
| `priv/repo/migrations/*_create_users_auth_tables.exs` | `users` and `users_tokens` tables |
| `lib/quickslips/accounts.ex` | the Accounts context (public API) |
| `lib/quickslips/accounts/user.ex` | `User` schema + changesets |
| `lib/quickslips/accounts/user_token.ex` | session and email tokens |
| `lib/quickslips/accounts/user_notifier.ex` | the emails it sends |
| `lib/quickslips/accounts/scope.ex` | `%Scope{user: ...}`, the "who is calling" struct |
| `lib/quickslips_web/user_auth.ex` | plugs and `on_mount` hooks |
| `lib/quickslips_web/live/user_live/{registration,login,confirmation,settings}.ex` | the pages |
| `lib/quickslips_web/controllers/user_session_controller.ex` | log in / log out / update password (needs HTTP to set cookies) |
| `test/...` | tests for all of the above, plus `test/support/fixtures/accounts_fixtures.ex` |

**Check.**

```bash
git status                                    # see every file touched
mix test                                      # still green, now with ~60+ tests
docker compose exec db psql -U postgres quickslips_dev -c '\dt'
# expect tables: schema_migrations, users, users_tokens
```

**Pitfalls.**

- *`bcrypt_elixir` fails to compile* (`make: command not found`, `cc: not found`): install the Xcode command-line tools: `xcode-select --install`. Or regenerate with `--hashing-lib pbkdf2`, which needs no C compiler (slightly weaker; fine for learning).
- *`connection refused` on `ecto.migrate`*: Postgres isn't running; `docker compose up -d`.
- *`type "citext" does not exist`*: the migration enables the `citext` extension (case-insensitive email). The official `postgres:16` image includes it, so this shouldn't happen. If it does, you're pointing at a different Postgres.
- *You ran the generator twice*: it will refuse or create duplicates. `git restore . && git clean -fd` and start again.

**Commit.** `git add -A && git commit -m "Task 1.1: generate auth with phx.gen.auth (LiveView)"`

### Task 1.2: Try the flow in the browser

**Why.** Before reading code, watch the thing work. You'll recognise each file in Task 1.3 because you've seen what it does.

**Do it.**

```bash
mix phx.server
```

1. Open http://localhost:4000/users/register. Enter an email (anything, such as `me@example.com`). There's no password field yet. Submit.
2. You land on `/users/log-in` with a message: an email was sent.
3. Open http://localhost:4000/dev/mailbox. This is Swoosh's local mailbox: in development nothing is sent for real; emails are stored here. Open "Confirmation instructions" and click the link.
4. The page says "Welcome me@example.com". Click **Confirm and stay logged in**.
5. You're at `/` with a "User confirmed successfully" message and a menu showing your email, Settings, and Log out.
6. Click **Log out**. Then go to `/users/log-in`, use the first form ("Log in with email"), check the mailbox again (this email is titled "Log in instructions") and log in.
7. Open `/users/settings`. Set a password (12 to 72 characters). Log out and use the *second* form on the login page with that password.

**Experiments (each teaches something).**

- Click the same email link twice. The second time it fails: links are single-use. They also expire after 15 minutes.
- While logged in, open `/users/register`. You get redirected away; the LiveView checks for a current user when it mounts.
- Open `/users/settings` in a private window. You're sent to log in with "You must log in to access this page."
- In `iex -S mix`, run `QuickSlips.Repo.all(QuickSlips.Accounts.User)` and look at `hashed_password`. It's a bcrypt hash, not your password.

**Pitfalls.**

- *The link in the mailbox goes to the wrong port*: the dev endpoint config uses `localhost:4000`; if you run on another port, links break.
- *You don't see the email*: it's at `/dev/mailbox` (not `/dev/dashboard`). That route only exists in development.

**Commit.** Nothing to commit; this task only changes your database.

### Task 1.3: Read what was generated

**Why.** You will change this code in 1.4, 1.5 and 1.6, and extend it in Milestone 2. Reading it once, in the right order, makes every later task easy. Keep the files open next to this guide.

**Do it.** Read in this order. For each file, find the thing in the "Look for" column.

**1. The migration** (`priv/repo/migrations/*_create_users_auth_tables.exs`)

- `users`: `email` is **`citext`** (Postgres's case-insensitive text, so `A@x.com` equals `a@x.com`), `hashed_password` is nullable, `confirmed_at` is nullable. Passwords are optional by design.
- `users_tokens`: one row per session or emailed link. Columns `token`, `context` ("session", "login", "change:old@x.com"), `sent_to`, `authenticated_at`.
- `unique_index(:users, [:email])` is what finally guarantees no duplicate emails.

**2. `accounts/user.ex`** (changesets are validation rules)

- `field :password, virtual: true, redact: true`: exists in memory only; never stored; hidden from logs.
- `email_changeset/3`: required, must match `^[^@,;\s]+@[^@,;\s]+$`, max 160 characters, unique (`unsafe_validate_unique` gives a friendly pre-check; `unique_constraint` is the safety net).
- `password_changeset/3`: min 12, max 72; `validate_confirmation` compares `password` with `password_confirmation`; `maybe_hash_password` hashes with bcrypt and deletes the plain password. The option `hash_password: false` is for live form validation (no point hashing on every keystroke).
- `confirm_changeset/1`: sets `confirmed_at` to now.
- `valid_password?/2`: when there is no user or no hash it still does a fake hash check (`no_user_verify`). That makes "wrong email" take as long as "wrong password", so attackers can't tell which emails exist.

**3. `accounts/user_token.ex`**

- Session tokens are random bytes stored directly in the DB (the browser cookie holds the same bytes, signed). Deleting the row logs that session out everywhere.
- Email tokens are **hashed with SHA-256** before being stored; the raw value only exists in the email. A database leak doesn't leak working links.
- Validity constants at the top: magic link 15 minutes, change-email 7 days, session 14 days.

**4. `accounts.ex`** (the Accounts context; the only module the web layer should call)

- Sections, in order: *getters*, *registration*, *settings*, *session*.
- `register_user/1` (today: email only). `get_user_by_email_and_password/2`.
- `sudo_mode?/2`: "authenticated in the last N minutes". Sensitive pages (Settings) require it.
- `login_user_by_magic_link/1`: has **three cases** documented in its `@doc`. Case 3 `raise`s. Keep that in mind for 1.4.
- `update_user_and_delete_all_tokens/1` (private): changing a password wipes every token, which logs out all other devices.

**5. `scope.ex`.** A tiny struct `%Scope{user: user}`. You'll see `@current_scope.user` everywhere. Scopes are Phoenix 1.8's way to carry "who is making this request" into every context function, so queries can be limited to the caller's own data. Milestone 7 depends on this.

**6. `user_auth.ex`** (plugs and hooks)

- Plugs (for controller-style requests): `fetch_current_scope_for_user` (reads the session or remember-me cookie, loads the user, assigns `current_scope`) and `require_authenticated_user` (redirects to log-in if there is no user, and remembers where you wanted to go).
- LiveView hooks (`on_mount`): `:mount_current_scope` (just load the user), `:require_authenticated` (redirect if no user), `:require_sudo_mode`.
- `log_in_user/3`, `log_out_user/1`, the remember-me cookie (14 days), token re-issue after 7 days, and `signed_in_path/1`, where you go after logging in.

**7. `router.ex`** (new parts)

- `:browser` pipeline gained `plug :fetch_current_scope_for_user`.
- Group A: `pipe_through [:browser, :require_authenticated_user]`: **`/users/settings`**, **`/users/settings/confirm-email/:token`**, and `POST /users/update-password`. These need a logged-in user.
- Group B: `pipe_through [:browser]`: `/users/register`, `/users/log-in`, `/users/log-in/:token`, `POST /users/log-in`, `DELETE /users/log-out`. Open to everyone.
- Run `mix phx.routes` to see the full table.

**Quick quiz (answers at the bottom of this task).**

1. Why does the login LiveView *submit a normal HTML form* (`phx-trigger-action`) instead of handling login over its websocket?
2. Why are email tokens hashed in the database but session tokens aren't?
3. What would happen if `valid_password?/2` returned `false` immediately when the user doesn't exist?

*Answers.* (1) Only a normal HTTP response can set the session cookie; a LiveView websocket can't. So LiveView validates the form live, then hands the final submit to `UserSessionController`. (2) An email token is a *bearer secret* sent through a less-trusted channel; if someone reads your DB they must not be able to use those links. A session token is already a secret that lives in your own cookie, and you need to look it up directly. (3) Response time would reveal which emails are registered.

**Commit.** Nothing to commit.

### Task 1.4: Ask for a password at sign-up

**Why.** The plan wants "email + password" registration. We need to (a) accept a password at registration and store its hash, and (b) fix the confirmation-link problem described in [Corrections](#corrections-to-the-plan), point 2.

This task has four parts. Commit after each.

#### 1.4a: A registration changeset

In `lib/quickslips/accounts/user.ex`, add this *below* `email_changeset/3` (top level of the module):

```elixir
  @doc """
  A changeset for registering with an email and a password.

  Options are passed to both changesets: `:validate_unique` (email) and
  `:hash_password` (password). Both are set to `false` for live validation.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> email_changeset(attrs, opts)
    |> password_changeset(attrs, opts)
  end
```

What this shows: a changeset is just a function from `(struct, params)` to a changeset, so you can compose them with `|>`.

#### 1.4b: The context functions

In `lib/quickslips/accounts.ex`, replace `register_user/1` and add `change_user_registration/3`:

```elixir
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns a changeset for the registration form (no hashing, no uniqueness query).
  """
  def change_user_registration(%User{} = user, attrs \\ %{}, opts \\ []) do
    User.registration_changeset(user, attrs, opts)
  end
```

Then deal with the trap. Find `login_user_by_magic_link/1`. It has a branch that `raise`s for "unconfirmed with a password". Replace the `raise` with an error tuple, so a forged request produces a normal "invalid link" message instead of a 500:

```elixir
      # Unconfirmed users who have a password must confirm with
      # confirm_user_with_password/2 (see below), not with the link alone.
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        {:error, :password_required}
```

Add the new function in the same file (anywhere in the "Session" section is fine):

```elixir
  @doc """
  Confirms an account that was registered with a password.

  Holding the emailed token is not enough: the caller must also know the password
  chosen at registration. This stops an attacker from pre-registering someone
  else's email with a password only the attacker knows.

  Returns `{:ok, {user, expired_tokens}}` or `{:error, :invalid}`.
  """
  def confirm_user_with_password(token, password) when is_binary(token) and is_binary(password) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {%User{confirmed_at: nil} = user, _token} <- Repo.one(query),
         true <- User.valid_password?(user, password) do
      user
      |> User.confirm_changeset()
      |> update_user_and_delete_all_tokens()
    else
      _ -> {:error, :invalid}
    end
  end
```

What this shows: `with` runs the steps in order, and the first one that doesn't match its pattern jumps to `else`. `{%User{confirmed_at: nil} = user, _token}` is pattern matching on a tuple and a struct field at once.

> ⚠️ Verify: the generated file has an `alias QuickSlips.Accounts.{User, UserToken, UserNotifier}` near the top, so `User` and `UserToken` resolve. If you get "undefined module", check that alias line.

#### 1.4c: The registration page

Open `lib/quickslips_web/live/user_live/registration.ex`.

1. In `render/1`, inside the `<.form ...>`, **after** the email `<.input>` and **before** the `<.button>`, add:

```heex
          <.input
            field={@form[:password]}
            type="password"
            label="Password"
            autocomplete="new-password"
            spellcheck="false"
            required
          />
          <.input
            field={@form[:password_confirmation]}
            type="password"
            label="Confirm password"
            autocomplete="new-password"
            spellcheck="false"
            required
          />
```

2. In `mount/3`, the second clause builds the changeset. Change it to the new function:

```elixir
    changeset =
      Accounts.change_user_registration(%User{}, %{}, validate_unique: false, hash_password: false)
```

3. In `handle_event("validate", ...)`, change the same call:

```elixir
    changeset =
      Accounts.change_user_registration(%User{}, user_params,
        validate_unique: false,
        hash_password: false
      )
```

The `"save"` handler stays as generated: it calls `Accounts.register_user/1` (now password-aware), emails the link, and redirects to the login page.

Update the flash text if you like: "An email was sent to ..., open it and use the password you just chose to confirm your account."

#### 1.4d: Confirming with the password

Two small changes make the emailed link ask for the password.

**In the Confirmation LiveView** (`lib/quickslips_web/live/user_live/confirmation.ex`), in the first `<.form :if={!@user.confirmed_at} ...>`, add this right after the hidden `token` input:

```heex
          <.input
            :if={@user.hashed_password}
            field={@form[:password]}
            type="password"
            label="Password you chose at sign-up"
            autocomplete="current-password"
            required
          />
```

**In the session controller** (`lib/quickslips_web/controllers/user_session_controller.ex`), add a new clause **above** the existing `# magic link login` clause (order matters: Elixir tries clauses top to bottom, and this one is more specific):

```elixir
  # confirm an account registered with a password: token + password
  defp create(conn, %{"user" => %{"token" => token, "password" => password} = user_params}, info) do
    case Accounts.confirm_user_with_password(token, password) do
      {:ok, {user, tokens_to_disconnect}} ->
        UserAuth.disconnect_sessions(tokens_to_disconnect)

        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params)

      {:error, _} ->
        conn
        |> put_flash(:error, "That link or password is not valid.")
        |> redirect(to: ~p"/users/log-in")
    end
  end
```

> ⚠️ Verify: the generated controller aliases `QuickSlipsWeb.UserAuth` (so `UserAuth` works) and has `defp create/3` clauses that take `(conn, params, info)`. Match the names you see there.

**Try it.**

1. Register with email + password + confirmation.
2. Open `/dev/mailbox`, click the confirmation link. The page now has a password box.
3. Wrong password: you get an error. Right password: you're confirmed and logged in.
4. Log out. On `/users/log-in`, use the password form.

**Check.**

- `iex -S mix`: `QuickSlips.Repo.all(QuickSlips.Accounts.User)` shows `confirmed_at` set and a `hashed_password`.
- Try registering with a password under 12 characters. The error appears live, under the field, as you type.
- Try mismatched confirmation. The message is "does not match password" on the confirmation field.

**Add tests** (create `test/quickslips/accounts_registration_test.exs`; fix fixtures first, see Task 1.7):

```elixir
defmodule QuickSlips.AccountsRegistrationTest do
  use QuickSlips.DataCase

  alias QuickSlips.Accounts

  import QuickSlips.AccountsFixtures

  describe "register_user/1 with a password" do
    test "stores a hash and not the password" do
      {:ok, user} = Accounts.register_user(valid_user_attributes())
      assert is_binary(user.hashed_password)
      assert is_nil(user.password)
    end

    test "rejects a mismatched confirmation" do
      {:error, changeset} =
        Accounts.register_user(valid_user_attributes(password_confirmation: "something else!"))

      assert %{password_confirmation: ["does not match password"]} = errors_on(changeset)
    end
  end

  describe "confirm_user_with_password/2" do
    test "needs the right password" do
      user = unconfirmed_user_fixture()
      token = extract_user_token(fn url -> Accounts.deliver_login_instructions(user, url) end)

      assert {:error, :invalid} = Accounts.confirm_user_with_password(token, "not the password")
      assert {:ok, {confirmed, _}} = Accounts.confirm_user_with_password(token, valid_user_password())
      assert confirmed.confirmed_at
    end
  end
end
```

**Pitfalls.**

- *`mix test` explodes after this task*: expected. The generated fixtures call `register_user/1` with only an email. Task 1.7 fixes them.
- *Passwords showing in logs*: they shouldn't. `redact: true` on the field hides it. If you see a plain password in the server log, look for an `IO.inspect` you added.
- *Bcrypt's 72-byte limit*: the changeset checks length in bytes for bcrypt. Don't remove it; longer passwords get silently truncated.
- *Someone registers and never confirms, then forgets the password*: they're stuck, and re-registering says "email already taken". It's an accepted limitation for now; Task 9.5's cleanup job deletes unconfirmed accounts after a few days.
- *Optional hardening*: block password login until confirmed. In `get_user_by_email_and_password/2`, return `nil` unless `user.confirmed_at`. Do this only if you also fix the tests that log in unconfirmed users.

**Commit.** `git commit -am "Task 1.4: register with password; confirmation requires the password"`

### Task 1.5: Protect a page

**Why.** Protecting a page is two things: the router says "this route needs a user", and a plug/hook enforces it. Here you see both.

**Do it.**

1. Create `lib/quickslips_web/live/dashboard_live.ex`:

```elixir
defmodule QuickSlipsWeb.DashboardLive do
  use QuickSlipsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Dashboard")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="dashboard" class="mx-auto max-w-3xl px-4 py-10">
        <h1 class="text-2xl font-semibold">Dashboard</h1>
        <p class="mt-2 text-base-content/70">Signed in as {@current_scope.user.email}</p>
      </div>
    </Layouts.app>
    """
  end
end
```

2. In `router.ex`, find `live_session :require_authenticated_user, on_mount: [...] do` and add the route inside it, next to the Settings routes:

```elixir
      live "/dashboard", DashboardLive, :index
```

3. In `lib/quickslips_web/user_auth.ex`, find `signed_in_path/1`. Its fallback clause returns `~p"/"`. Make people land on the dashboard after logging in:

```elixir
  def signed_in_path(_), do: ~p"/dashboard"
```

**Check.**

- Logged out, visit http://localhost:4000/dashboard. You're redirected to `/users/log-in` with "You must log in to access this page."
- Log in; you land on `/dashboard` and see your email.
- `mix phx.routes | grep dashboard` shows the route.

**Add a test** (`test/quickslips_web/live/dashboard_live_test.exs`):

```elixir
defmodule QuickSlipsWeb.DashboardLiveTest do
  use QuickSlipsWeb.ConnCase

  import Phoenix.LiveViewTest

  test "redirects visitors to log in", %{conn: conn} do
    assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/dashboard")
    assert path == ~p"/users/log-in"
  end

  describe "when logged in" do
    setup :register_and_log_in_user

    test "shows the dashboard", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")
      assert has_element?(view, "#dashboard")
    end
  end
end
```

`register_and_log_in_user` is a helper that the generator added to `test/support/conn_case.ex`.

**Pitfalls.**

- *`@current_scope` is `nil` or a KeyError*: the route is outside the `require_authenticated_user` live_session. Move it inside (see the AGENTS.md rule about `current_scope` errors).
- *The page works logged out*: same cause.

**Commit.** `git add -A && git commit -m "Task 1.5: add protected /dashboard"`

### Task 1.6: Header links

**Why.** Visitors see "Log in / Sign up"; users see "Dashboard / Settings / Log out". The layout decides which, using `@current_scope`.

**Do it.** Open `lib/quickslips_web/components/layouts/root.html.heex`. The generator put a `<ul class="menu menu-horizontal ...">` right after the `<body>` tag. Replace the whole `<body>...</body>` with:

```heex
  <body class="min-h-screen bg-base-100 text-base-content">
    <header class="border-b border-base-300">
      <nav
        id="main-nav"
        aria-label="Main"
        class="mx-auto flex max-w-6xl items-center justify-between px-4 py-3 sm:px-6"
      >
        <.link href={~p"/"} class="text-lg font-semibold tracking-tight">QuickSlips</.link>

        <ul class="flex items-center gap-4 text-sm">
          <%= if @current_scope && @current_scope.user do %>
            <li><.link href={~p"/dashboard"} class="hover:underline">Dashboard</.link></li>
            <li><.link href={~p"/users/settings"} class="hover:underline">Settings</.link></li>
            <li>
              <.link href={~p"/users/log-out"} method="delete" class="hover:underline">
                Log out
              </.link>
            </li>
          <% else %>
            <li><.link href={~p"/users/log-in"} class="hover:underline">Log in</.link></li>
            <li>
              <.link
                href={~p"/users/register"}
                class="rounded-md bg-primary px-3 py-1.5 font-medium text-primary-content transition hover:opacity-90"
              >
                Sign up
              </.link>
            </li>
          <% end %>
        </ul>
      </nav>
    </header>

    {@inner_content}
  </body>
```

Details to understand:

- The root layout receives the connection's assigns, including `current_scope`, from the `fetch_current_scope_for_user` plug. That's why you don't pass it explicitly here (but the *app* layout `Layouts.app` does need `current_scope={@current_scope}` from each page).
- `method="delete"` on a link is handled by `phoenix_html`'s JS: it builds a hidden form with the CSRF token.
- If you ever render a page outside the `:browser` pipeline, `@current_scope` won't exist. Use `assigns[:current_scope]` there.

**Check.** Logged out: "Log in" and "Sign up". Logged in: "Dashboard", "Settings", "Log out". Click each. Resize the window to phone width; the row should not overflow.

**Pitfalls.**

- *Two headers*: your `Layouts.app` function still renders the Phoenix demo navbar (website / GitHub links). That's expected for now; Task 3.1 replaces it and moves the menu there.
- *Log out does nothing*: the app JS didn't load. Check the browser console and that `assets/js/app.js` imports `phoenix_html`.

**Commit.** `git commit -am "Task 1.6: header links for visitors and users"`

### Task 1.7: Run the tests

**Why.** The generator shipped tests. After Task 1.4 many fail, and *that's the point*: they describe the old behaviour. Fixing them is how you learn what each test protects.

**Do it.**

```bash
mix test
```

Expect a lot of red. Don't panic; there are only a few root causes. Work through them in this order:

**1. Fixtures** (`test/support/fixtures/accounts_fixtures.ex`). Registration now needs a password, and `user_fixture` used a magic link to confirm users, which our rule forbids for password users.

```elixir
  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password(),
      password_confirmation: valid_user_password()
    })
  end

  def user_fixture(attrs \\ %{}) do
    attrs
    |> unconfirmed_user_fixture()
    |> QuickSlips.Accounts.User.confirm_changeset()
    |> QuickSlips.Repo.update!()
  end
```

`unconfirmed_user_fixture/1` is already fine (it calls `register_user/1`, which now takes a password).

**2. The old "raises" test.** In `test/quickslips/accounts_test.exs` there's a test for the third case of `login_user_by_magic_link` that expects a `raise`. We replaced the raise, so change it to:

```elixir
assert {:error, :password_required} = Accounts.login_user_by_magic_link(token)
```

(Match the surrounding test code; the setup creates an unconfirmed user with a password.)

**3. Confirmation and session tests that confirm an unconfirmed user** (`confirmation_live_test.exs`, `user_session_controller_test.exs`). Where a test submits the confirmation form for an unconfirmed user, add `password: valid_user_password()` to the submitted params. Where the test only wants "some logged-in user", switch it to `user_fixture()` (now confirmed).

**4. Registration tests.** They should pass as-is because the form now has the password fields and `valid_user_attributes` supplies them. If the "creates account" test fails with a missing field error, check the `name`s of your inputs (`user[password]`, `user[password_confirmation]`).

Use these two commands while fixing:

```bash
mix test --failed                    # rerun only what failed last time
mix test test/quickslips_web/live/user_live/registration_test.exs:30   # one test by line
```

Then run the real gate:

```bash
mix precommit
```

(That compiles with warnings as errors, removes unused deps, formats, and runs the tests.)

**Check, the milestone's "Done when" end to end:**

1. Sign up with email + password → confirm via `/dev/mailbox` with that password → land on `/dashboard`.
2. Log out → log in with the password form → `/dashboard`.
3. Log out → `/users/log-in` → "Log in with email" → mailbox → click link → "Log in" → Settings → set a new password → log out → log in with the **new** password. This is the "forgot password" flow.
4. Visit `/dashboard` logged out → bounced to log-in.

**Pitfalls.**

- *`mix precommit` formats files*: it rewrites them. Commit afterwards.
- *Tests pass individually but fail together*: usually shared state. Phoenix tests run in a DB sandbox that rolls back each test, so look for something global (an ETS table, an env var).
- *Tests are slow*: bcrypt is slow on purpose. `config/test.exs` lowers the cost for tests (`log_rounds: 1`), so if tests crawl, check that setting exists.

**Commit.** `git add -A && git commit -m "Task 1.7: fix generated tests for password registration"`, then merge your branch and push.

**Milestone 1 is done when:** you can sign up with email and password, log in, see `/dashboard`, log out, and reset a forgotten password through the email link and Settings.

---

## Milestone 2: Continue with Google

**Goal:** a "Continue with Google" button that logs in an existing user with the same email, or creates a new confirmed user. Google only proves *who* the person is; the session code from Milestone 1 does everything else.

**Elixir you'll meet:** `cond`, plain maps as function arguments, `Ecto.Changeset.change/2`, controller plugs, environment variables in `runtime.exs`.

**The big picture (OAuth in one minute).**

```
1. User clicks "Continue with Google"        -> GET /auth/google
2. Ueberauth redirects the browser to Google  (with your client id and a random `state`)
3. User approves on Google's page
4. Google redirects back                      -> GET /auth/google/callback?code=...&state=...
5. Ueberauth swaps `code` for the user's profile (server to server) and
   puts it in conn.assigns.ueberauth_auth
6. Your controller: find/create the user, then UserAuth.log_in_user/3
```

You never see the user's Google password. You get a verified profile: a stable id (`sub`), email, name, picture.

### Task 2.1: Google Cloud setup

**Why.** Google must know your app exists and which URLs it may send users back to.

**Do it.** (Google moves its console around; the names below are what they've used for years.)

1. Go to https://console.cloud.google.com and create a project named `quickslips`.
2. **APIs & Services → OAuth consent screen** (newer consoles call this "Google Auth Platform"):
   - User type **External**.
   - App name `QuickSlips`, your support email, developer contact email.
   - Scopes: only `openid`, `email`, `profile`. These are "non-sensitive", so you don't need Google's verification process.
   - While the app is in **Testing** status, only emails you list as *test users* can log in. Add your own Gmail and one more to try the "new user" case.
3. **APIs & Services → Credentials → Create credentials → OAuth client ID.**
   - Application type **Web application**, name `quickslips-local`.
   - **Authorised redirect URI:** `http://localhost:4000/auth/google/callback` (exactly this: same scheme, host, port, path, no trailing slash).
   - Copy the **Client ID** and **Client secret**.
4. Store them in a git-ignored file. At the project root:

```bash
printf '\n# local secrets\n.env\n.env.*\n' >> .gitignore
cat > .env <<'EOF'
GOOGLE_CLIENT_ID=paste-your-client-id-here
GOOGLE_CLIENT_SECRET=paste-your-client-secret-here
EOF
chmod 600 .env
```

5. Phoenix doesn't read `.env` by itself. Start the server like this from now on:

```bash
set -a; source .env; set +a; mix phx.server
```

(`set -a` marks every variable defined afterwards as exported. Or use `direnv` if you know it.)

**Check.** `set -a; source .env; set +a; echo ${GOOGLE_CLIENT_ID:0:8}` prints the first 8 characters of your client id (never print the secret).

**Pitfalls.**

- *Never commit `.env`.* `git status` must not list it. If you ever do commit a secret, rotate it in the console. Deleting the commit isn't enough.
- *Test users only*: other accounts get "Access blocked". Publish the consent screen (move it to *In production*) before launch in Milestone 9; with only the three basic scopes this needs no review.
- *Use `localhost` consistently* (not `127.0.0.1`). The OAuth `state` cookie belongs to one hostname, and mixing them gives a "csrf_attack" failure later.

**Commit.** `git commit -am "Task 2.1: ignore .env files"` (only `.gitignore` changed).

### Task 2.2: Add the libraries

**Why.** Ueberauth is the OAuth plumbing (redirects, state check, token exchange). `ueberauth_google` is the Google-specific strategy.

**Do it.**

1. In `mix.exs`, add to `deps`:

```elixir
      {:ueberauth, "~> 0.10"},
      {:ueberauth_google, "~> 0.12"},
```

> ⚠️ Verify: check the current versions with `mix hex.info ueberauth` and `mix hex.info ueberauth_google`, and use what Hex recommends.

2. `mix deps.get`
3. `config/config.exs` (above the line that imports the environment config):

```elixir
config :ueberauth, Ueberauth,
  providers: [google: {Ueberauth.Strategy.Google, [default_scope: "email profile"]}]
```

4. `config/runtime.exs` (near the top, outside any `if config_env() ==` block, so it applies to dev, test and prod):

```elixir
config :ueberauth, Ueberauth.Strategy.Google.OAuth,
  client_id: System.get_env("GOOGLE_CLIENT_ID"),
  client_secret: System.get_env("GOOGLE_CLIENT_SECRET")
```

**Why two files?** `config.exs` is read at *compile time*; `runtime.exs` is read each time the app *starts*, which is where secrets belong. In a release you set environment variables on the server and never rebuild.

**Check.** `mix compile` succeeds. With the env vars set, `iex -S mix` then `Application.get_env(:ueberauth, Ueberauth.Strategy.Google.OAuth)` shows your client id.

**Pitfalls.** If the variables are missing, the app still boots; it only fails when someone visits `/auth/google` ("client_id missing"). That's why you load `.env` before `mix phx.server`.

**Commit.** `git commit -am "Task 2.2: add ueberauth and ueberauth_google"`

### Task 2.3: Migration and schema fields

**Why.** We need somewhere to store Google's stable user id (`google_uid`). Matching by email alone is fragile (people change emails); the id never changes.

**Do it.**

```bash
mix ecto.gen.migration add_google_to_users
```

Open the new file in `priv/repo/migrations/` and make it:

```elixir
defmodule QuickSlips.Repo.Migrations.AddGoogleToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :google_uid, :string
      add :name, :string
      add :avatar_url, :text
    end

    create unique_index(:users, [:google_uid])
  end
end
```

(`avatar_url` is `:text` because Google image URLs can be long. A unique index on a nullable column is fine in Postgres: many `NULL`s are allowed, but two identical ids are not.)

Then `mix ecto.migrate`.

In `lib/quickslips/accounts/user.ex`:

1. Add the fields inside the `schema "users" do` block:

```elixir
    field :google_uid, :string
    field :name, :string
    field :avatar_url, :string
```

2. Add two changesets below `confirm_changeset/1`:

```elixir
  @doc """
  Attaches a verified Google identity to a user.

  `info` is built by our own code from Google's response, never from form params,
  so we use `change/2` rather than `cast/3`.
  """
  def google_changeset(user_or_changeset, %{google_uid: uid} = info) when is_binary(uid) do
    changes =
      info
      |> Map.take([:google_uid, :name, :avatar_url])
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)

    user_or_changeset
    |> change(changes)
    |> unique_constraint(:google_uid)
  end

  @doc """
  A changeset for a brand new user who signed up with Google: email is already
  verified by Google, so the account starts confirmed and has no password.
  """
  def google_registration_changeset(%{email: email} = info) do
    %__MODULE__{}
    |> email_changeset(%{email: email})
    |> google_changeset(info)
    |> confirm_changeset()
  end
```

**Check.**

```bash
docker compose exec db psql -U postgres quickslips_dev -c '\d users'
# should list google_uid, name, avatar_url and the index users_google_uid_index
```

**Pitfalls.**

- *Changing a migration after running it* does nothing (it's recorded as done). Roll back with `mix ecto.rollback`, edit, and migrate again, but only on local data.
- *Why `change` and not `cast`?* The project rule in `AGENTS.md`: values set by our code (not typed by a user) aren't listed in `cast`.

**Commit.** `git add -A && git commit -m "Task 2.3: users get google_uid, name, avatar_url"`

### Task 2.4: Context function

**Why.** The decision "who is this Google person in *our* database?" is business logic, so it belongs in `Accounts`, not in the controller. We pass in a plain map (not Ueberauth's struct), which makes it easy to test without any web stack. The controller converts Google's data into that map (Task 2.5).

**The rules.**

1. Reject if Google doesn't say the email is verified.
2. If a user has this `google_uid` → that's them.
3. Else if a user has this email → link the `google_uid` to that user.
4. Else create a new, confirmed user.

**Security rule for step 3.** If the existing account is **unconfirmed**, someone may have pre-registered the email with a password the real owner doesn't know (see [Corrections](#corrections-to-the-plan), point 4). Google just proved the email is real, so we confirm the account, **erase the password**, and wipe old sessions.

**Do it.** In `lib/quickslips/accounts.ex`, add a section:

```elixir
  ## Google sign-in

  @doc """
  Finds, links or creates the user for a verified Google identity.

  `info` is a map: `%{google_uid: _, email: _, name: _, avatar_url: _, email_verified?: _}`.
  Returns `{:ok, user}` or `{:error, :email_not_verified | %Ecto.Changeset{}}`.
  """
  def get_or_register_google_user(%{email_verified?: true} = info) do
    cond do
      user = Repo.get_by(User, google_uid: info.google_uid) ->
        {:ok, user}

      user = get_user_by_email(info.email) ->
        link_google_account(user, info)

      true ->
        info
        |> User.google_registration_changeset()
        |> Repo.insert()
    end
  end

  def get_or_register_google_user(_info), do: {:error, :email_not_verified}

  # The account was never confirmed, so any password on it was set by someone who
  # did not prove they own the email. Google proved it; drop the password and
  # every existing session/token before handing the account over.
  defp link_google_account(%User{confirmed_at: nil} = user, info) do
    user
    |> User.google_changeset(info)
    |> User.confirm_changeset()
    |> Ecto.Changeset.change(hashed_password: nil)
    |> update_user_and_delete_all_tokens()
    |> case do
      {:ok, {user, _expired_tokens}} -> {:ok, user}
      {:error, _} = error -> error
    end
  end

  defp link_google_account(%User{} = user, info) do
    user
    |> User.google_changeset(info)
    |> Repo.update()
  end
```

What this shows:

- `cond` evaluates conditions top to bottom; `user = Repo.get_by(...)` is both an assignment and a test (`nil` is falsy), and `user` is usable in that branch.
- Two function clauses of `link_google_account/2` pick behaviour by pattern matching on `confirmed_at: nil`.
- `update_user_and_delete_all_tokens/1` is the *existing private helper* from the generator; we reuse it because it already does "update + wipe tokens" in one transaction.

**Check (in `iex -S mix`).**

```elixir
alias QuickSlips.Accounts
Accounts.get_or_register_google_user(%{
  google_uid: "test-123", email: "gina@example.com", name: "Gina", avatar_url: nil, email_verified?: true
})
# => {:ok, %QuickSlips.Accounts.User{confirmed_at: ~U[...], google_uid: "test-123", ...}}
```

Run it a second time: you get the same user back, not a duplicate.

**Pitfalls.**

- *`undefined function get_user_by_email/1`*: it exists in the generated context under that name; check the spelling in your file.
- *Don't skip the verified check.* Some Google accounts (for example Workspace accounts using a non-Google address) can carry unverified emails. Linking those by email would let someone take over an account.

**Commit.** `git commit -am "Task 2.4: get_or_register_google_user with unconfirmed-account protection"`

### Task 2.5: Controller and routes

**Why.** The controller is glue: let Ueberauth do the OAuth dance, turn the result into our map, call the context, and reuse `UserAuth.log_in_user/3` (the same function password login uses), so cookies, remember-me and token rules stay identical.

**Do it.**

1. Create `lib/quickslips_web/controllers/auth_controller.ex`:

```elixir
defmodule QuickSlipsWeb.AuthController do
  use QuickSlipsWeb, :controller

  alias QuickSlips.Accounts
  alias QuickSlipsWeb.UserAuth

  # Handles /auth/:provider (redirect to Google) and /auth/:provider/callback
  # (fills in conn.assigns.ueberauth_auth or ueberauth_failure) before the action runs.
  plug Ueberauth

  # Only reached for an unknown provider; Ueberauth halts the request for "google".
  def request(conn, _params) do
    conn
    |> put_status(:not_found)
    |> text("Unknown login provider")
  end

  def callback(%{assigns: %{ueberauth_failure: _failure}} = conn, _params) do
    conn
    |> put_flash(:error, "Google sign-in didn't complete. Please try again.")
    |> redirect(to: ~p"/users/log-in")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case Accounts.get_or_register_google_user(google_info(auth)) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Welcome!")
        |> UserAuth.log_in_user(user, %{"remember_me" => "true"})

      {:error, :email_not_verified} ->
        conn
        |> put_flash(:error, "Google says that email address isn't verified.")
        |> redirect(to: ~p"/users/log-in")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "We couldn't sign you in with Google. Please try again.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  # Translate Ueberauth's struct into the plain map the context expects.
  defp google_info(%Ueberauth.Auth{} = auth) do
    %{
      google_uid: auth.uid,
      email: auth.info.email,
      name: auth.info.name,
      avatar_url: auth.info.image,
      email_verified?: get_in(auth.extra.raw_info.user, ["email_verified"]) == true
    }
  end
end
```

> ⚠️ Verify: do this once in dev to confirm the shape of Google's data. Temporarily add `IO.inspect(auth, label: "GOOGLE")` at the top of the success `callback`, log in with Google once, read the terminal, then remove it (and don't paste real tokens anywhere). You're checking that `auth.uid` is a string, that `auth.info.email` is set, and that `auth.extra.raw_info.user["email_verified"]` exists. If that last one is missing, the strategy version stores it elsewhere and every Google login will be rejected as "not verified".

2. In `router.ex`, add a scope. Put it **above** any future catch-all route such as `get "/:slug"` (Task 3.5):

```elixir
  scope "/auth", QuickSlipsWeb do
    pipe_through :browser

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
  end
```

**Check.**

- `mix phx.routes | grep auth` shows both routes.
- Open http://localhost:4000/auth/google (server started with the `.env` loaded). Google's account chooser appears. Pick a test user → you land on `/dashboard`, logged in.

**Pitfalls.**

- *`Error 400: redirect_uri_mismatch`*: the URI in the console must equal `http://localhost:4000/auth/google/callback` exactly. The error page shows what the app actually sent.
- *"csrf_attack" / state mismatch*: you started on `127.0.0.1` but Google sent you back to `localhost` (or cookies are blocked). Use `localhost` throughout.
- *Logged in but `/dashboard` redirects to log-in*: `log_in_user/3` wasn't reached; check the terminal for a `ueberauth_failure` log.

**Commit.** `git add -A && git commit -m "Task 2.5: Google callback controller and routes"`

### Task 2.6: Buttons

**Why.** A visible entry point on both the login and registration pages.

**Do it.** In `lib/quickslips_web/live/user_live/login.ex` and `registration.ex`, add this inside the page's content `<div>`, **after the last form** (login: after the password form; registration: after the registration form):

```heex
        <div class="relative py-2 text-center text-xs uppercase tracking-wide text-base-content/50">
          <span class="relative z-10 bg-base-100 px-2">or</span>
          <span class="absolute inset-x-0 top-1/2 -z-0 border-t border-base-300"></span>
        </div>

        <.link
          id="google-login"
          href={~p"/auth/google"}
          class="flex w-full items-center justify-center gap-2 rounded-lg border border-base-300 px-4 py-2.5 text-sm font-medium transition hover:bg-base-200 focus-visible:outline-2 focus-visible:outline-offset-2"
        >
          Continue with Google
        </.link>
```

Notes:

- It uses `href`, not `navigate`/`patch`. The link leaves your app for Google, so LiveView must not try to handle it.
- If you add Google's logo, follow Google's sign-in branding rules for the button.

**Check.** Both `/users/log-in` and `/users/register` show the button; clicking it starts the flow.

**Commit.** `git commit -am "Task 2.6: Continue with Google buttons"`

### Task 2.7: Test the three cases

**Why.** Account-linking logic is where login bugs (and security holes) live. These tests pin the behaviour so you can refactor safely.

**Do it.** Create `test/quickslips/accounts_google_test.exs`:

```elixir
defmodule QuickSlips.AccountsGoogleTest do
  use QuickSlips.DataCase

  alias QuickSlips.Accounts
  alias QuickSlips.Accounts.User
  alias QuickSlips.Repo

  import QuickSlips.AccountsFixtures

  defp google_info(attrs \\ %{}) do
    Map.merge(
      %{
        google_uid: "g-#{System.unique_integer([:positive])}",
        email: unique_user_email(),
        name: "Gina Google",
        avatar_url: "https://example.com/gina.png",
        email_verified?: true
      },
      attrs
    )
  end

  describe "get_or_register_google_user/1" do
    test "case 1: a new Google user is created, confirmed, with no password" do
      info = google_info()

      assert {:ok, user} = Accounts.get_or_register_google_user(info)
      assert user.confirmed_at
      assert user.google_uid == info.google_uid
      assert is_nil(user.hashed_password)
    end

    test "case 2: an existing password user with the same email is linked, not duplicated" do
      existing = user_fixture()
      info = google_info(%{email: existing.email})

      assert {:ok, user} = Accounts.get_or_register_google_user(info)
      assert user.id == existing.id
      assert user.google_uid == info.google_uid
      assert Repo.aggregate(User, :count) == 1
      # their password still works
      assert Accounts.get_user_by_email_and_password(existing.email, valid_user_password())
    end

    test "case 3: a Google-only user can set a password later" do
      {:ok, user} = Accounts.get_or_register_google_user(google_info())

      {:ok, {user, _expired}} =
        Accounts.update_user_password(user, %{
          password: "a long enough password",
          password_confirmation: "a long enough password"
        })

      assert Accounts.get_user_by_email_and_password(user.email, "a long enough password")
    end

    test "a second login finds the same user by google_uid" do
      info = google_info()
      {:ok, first} = Accounts.get_or_register_google_user(info)
      {:ok, second} = Accounts.get_or_register_google_user(info)
      assert first.id == second.id
    end

    test "an unverified Google email is rejected" do
      assert {:error, :email_not_verified} =
               Accounts.get_or_register_google_user(google_info(%{email_verified?: false}))
    end

    test "linking an unconfirmed password account erases the unproven password" do
      unconfirmed = unconfirmed_user_fixture()
      assert unconfirmed.hashed_password

      info = google_info(%{email: unconfirmed.email})
      assert {:ok, user} = Accounts.get_or_register_google_user(info)

      assert user.confirmed_at
      assert is_nil(user.hashed_password)
      refute Accounts.get_user_by_email_and_password(unconfirmed.email, valid_user_password())
    end
  end
end
```

Run `mix test test/quickslips/accounts_google_test.exs`, then `mix precommit`.

(An end-to-end controller test is possible but fiddly because the `Ueberauth` plug owns the callback. These context tests cover the logic that matters; the manual run in 2.5 covers the plumbing.)

**Manual run of the three cases in the browser:**

1. A Google account that has never used the site → arrives at `/dashboard`.
2. Register with email+password for an address that is also a Google test user, confirm it, then use "Continue with Google": same user (check `Repo.all(User)` has one row).
3. Log in with Google, open Settings, set a password, log out and use the password form.

**Commit.** `git add -A && git commit -m "Task 2.7: tests for Google account linking"`, merge, push.

**Milestone 2 is done when:** both login methods land on `/dashboard` for the same account.

---

## Milestone 3: Layout and template catalogue

**Goal:** a home page listing bill types by category, and one page per bill type at a clean URL like `/fuel-bill`.

**Elixir you'll meet:** your first GenServer, `Enum.group_by`, `Path.wildcard`, `Jason`, function components, custom exceptions with `plug_status`.

**The design idea.** Each bill type is a **folder of data files**, not code. Adding the 15th bill type should mean copying a folder and editing JSON and a Typst file, with no Elixir changes. The `schema.json` drives the catalogue now, the form (Milestone 5) and the validator (Task 4.4).

### Task 3.1: Base layout

**Why.** Every page uses `Layouts.app`. Doing the header, footer and responsive width once means every later page looks consistent for free.

**Do it.**

1. **Put the nav in `Layouts.app`.** Open `lib/quickslips_web/components/layouts.ex`. Replace the body of `app/1` (the `~H"""` block) with your own header, main and footer. Keep the `attr`/`slot` declarations above it as they are, and keep the `flash_group` call (`AGENTS.md` only allows `<.flash_group>` inside this file):

```elixir
  def app(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col">
      <header class="border-b border-base-300 bg-base-100/80 backdrop-blur">
        <nav
          id="main-nav"
          aria-label="Main"
          class="mx-auto flex w-full max-w-6xl flex-wrap items-center justify-between gap-x-6 gap-y-2 px-4 py-3 sm:px-6"
        >
          <.link href={~p"/"} class="text-lg font-semibold tracking-tight">QuickSlips</.link>

          <ul class="flex flex-wrap items-center gap-x-4 gap-y-2 text-sm">
            <%= if @current_scope && @current_scope.user do %>
              <li><.link href={~p"/dashboard"} class="hover:underline">Dashboard</.link></li>
              <li><.link href={~p"/users/settings"} class="hover:underline">Settings</.link></li>
              <li>
                <.link href={~p"/users/log-out"} method="delete" class="hover:underline">
                  Log out
                </.link>
              </li>
            <% else %>
              <li><.link href={~p"/users/log-in"} class="hover:underline">Log in</.link></li>
              <li>
                <.link
                  href={~p"/users/register"}
                  class="rounded-md bg-primary px-3 py-1.5 font-medium text-primary-content transition hover:opacity-90"
                >
                  Sign up
                </.link>
              </li>
            <% end %>
            <li><.theme_toggle /></li>
          </ul>
        </nav>
      </header>

      <main class="mx-auto w-full max-w-6xl flex-1 px-4 py-8 sm:px-6">
        {render_slot(@inner_block)}
      </main>

      <footer class="border-t border-base-300 py-6 text-sm text-base-content/60">
        <div class="mx-auto max-w-6xl px-4 sm:px-6">
          <p>
            QuickSlips creates documents from the details you enter. You are responsible
            for their accuracy and for using them lawfully.
          </p>
        </div>
      </footer>

      <.flash_group flash={@flash} />
    </div>
    """
  end
```

2. **Remove the nav from `root.html.heex`.** Delete the `<header>...</header>` you added in Task 1.6, so the body is just `<body class="min-h-screen bg-base-100 text-base-content">{@inner_content}</body>`.
3. **Root layout head.** In `root.html.heex`, change the title suffix from `" · Phoenix Framework"` to `" · QuickSlips"` and add, next to the other `<meta>` tags:

```heex
    <meta
      name="description"
      content={assigns[:meta_description] || "Create bills and receipts as PDF in seconds."}
    />
```

4. **Make sure every page passes `current_scope`.** LiveViews and the home page use `<Layouts.app flash={@flash} current_scope={@current_scope}>`. The generated auth pages already do.

**Check.** At http://localhost:4000: header on every page, correct links logged in and out, footer sticks to the bottom on short pages. Narrow the window to about 375px (or use the browser's device toolbar) and confirm nothing scrolls sideways.

**Pitfalls.**

- *"key :current_scope not found"*: a page renders `Layouts.app` without passing `current_scope`. Add it.
- *A second theme toggle appears*: you kept an old one; there should be one `<.theme_toggle />`.
- *Colours look off*: `bg-base-100`, `text-primary-content` etc. come from the theme variables in `app.css`. Change the colours there (or define your own with `@theme`); don't scatter hex colours through templates.
- Add real Terms and Privacy pages before launch; the footer line is a placeholder.

**Commit.** `git commit -am "Task 3.1: app layout with header, main and footer"`

### Task 3.2: The templates folder

**Why.** Data-first design: a template is a folder with a *contract* (`schema.json`), an *example* (`sample.json`), and one or more *designs* (`t1.typ`, written in Milestone 4).

**Layout** (see [Corrections](#corrections-to-the-plan), point 5, for why it's under `priv/`):

```
priv/bill_templates/
  fuel-bill/
    schema.json
    sample.json
    t1.typ            <- Task 4.1
  rent-receipt/
    schema.json
    sample.json
    t1.typ            <- Task 4.1
```

**Do it.** Create these four files (shown in full so you can copy them).

`priv/bill_templates/fuel-bill/schema.json`:

```json
{
  "slug": "fuel-bill",
  "title": "Fuel Bill Generator",
  "category": "Vehicle & Fuel",
  "summary": "Create a petrol or diesel fuel bill as a PDF.",
  "description": "Generate a clean fuel bill with station name, date, fuel type, quantity and rate. Preview instantly and download as PDF.",
  "templates": [{ "id": "t1", "name": "Classic" }],
  "fields": [
    { "key": "station_name", "label": "Fuel station name", "type": "text", "required": true, "max_length": 80 },
    { "key": "station_address", "label": "Station address", "type": "textarea", "required": false, "max_length": 200 },
    { "key": "bill_number", "label": "Bill number", "type": "text", "required": true, "max_length": 30 },
    { "key": "date", "label": "Date", "type": "date", "required": true },
    { "key": "vehicle_number", "label": "Vehicle number", "type": "text", "required": false, "max_length": 20 },
    { "key": "fuel_type", "label": "Fuel type", "type": "select", "options": ["Petrol", "Diesel", "CNG"], "required": true },
    { "key": "quantity", "label": "Quantity (litres)", "type": "number", "required": true, "min": 0.01 },
    { "key": "rate", "label": "Rate per litre (₹)", "type": "number", "required": true, "min": 0.01 }
  ]
}
```

`priv/bill_templates/fuel-bill/sample.json`:

```json
{
  "station_name": "Sunrise Fuel Station",
  "station_address": "NH-48, Sector 12, Gurugram, Haryana",
  "bill_number": "FB-10482",
  "date": "2026-10-12",
  "vehicle_number": "HR 26 AB 1234",
  "fuel_type": "Petrol",
  "quantity": 28.5,
  "rate": 102.45
}
```

`priv/bill_templates/rent-receipt/schema.json`:

```json
{
  "slug": "rent-receipt",
  "title": "Rent Receipt Generator",
  "category": "Housing",
  "summary": "Monthly rent receipts, ready to submit for HRA.",
  "description": "Create a rent receipt with tenant, landlord, property and amount. Preview instantly and download as PDF.",
  "templates": [{ "id": "t1", "name": "Classic" }],
  "fields": [
    { "key": "tenant_name", "label": "Tenant name", "type": "text", "required": true, "max_length": 80 },
    { "key": "landlord_name", "label": "Landlord name", "type": "text", "required": true, "max_length": 80 },
    { "key": "landlord_pan", "label": "Landlord PAN (optional)", "type": "text", "required": false, "max_length": 10 },
    { "key": "property_address", "label": "Rented property address", "type": "textarea", "required": true, "max_length": 250 },
    { "key": "month", "label": "Rent for month", "type": "month", "required": true },
    { "key": "monthly_rent", "label": "Monthly rent (₹)", "type": "number", "required": true, "min": 1 },
    { "key": "payment_mode", "label": "Payment mode", "type": "select", "options": ["Bank transfer", "UPI", "Cash", "Cheque"], "required": true },
    { "key": "receipt_date", "label": "Receipt date", "type": "date", "required": true }
  ]
}
```

`priv/bill_templates/rent-receipt/sample.json`:

```json
{
  "tenant_name": "Asha Verma",
  "landlord_name": "Ramesh Gupta",
  "landlord_pan": "",
  "property_address": "Flat 402, Lotus Heights, Sector 21, Noida, Uttar Pradesh",
  "month": "2026-10",
  "monthly_rent": 25000,
  "payment_mode": "Bank transfer",
  "receipt_date": "2026-10-05"
}
```

**The schema format (this file's own contract; the plan's "section 5" may differ, adjust if so).**

| Key | Meaning |
|---|---|
| `slug` | URL name; must equal the folder name; lowercase letters, digits and `-` only |
| `title`, `summary`, `description` | page title, card text, SEO meta description |
| `category` | used to group cards on the home page |
| `templates` | the designs available (`t1`, later `t2`...) |
| `fields[].key` | the key in `data.json`; the Typst file reads it |
| `fields[].type` | one of `text`, `textarea`, `number`, `date` (`YYYY-MM-DD`), `month` (`YYYY-MM`), `select` |
| `fields[].required`, `max_length`, `min`, `options` | validation rules, used by both the server validator (4.4) and the browser form (5.1) |

Keep the types to this list. Each type you add must be implemented in three places (validator, form builder, Typst), so add them deliberately.

**Check.** Validate the JSON syntax from the terminal (macOS ships with Python 3):

```bash
for f in priv/bill_templates/*/*.json; do python3 -m json.tool "$f" > /dev/null && echo "ok  $f"; done
```

**Pitfalls.**

- *JSON has no comments and no trailing commas.* That's the usual cause of load errors.
- *The ₹ sign* is fine in JSON (UTF-8). It matters later in the PDF font (Task 4.1).

**Commit.** `git add -A && git commit -m "Task 3.2: fuel-bill and rent-receipt schemas and samples"`

### Task 3.3: The registry (your first GenServer)

**Why.** Reading and parsing JSON files on every page view is wasteful. A **GenServer** is a long-lived process that holds state in memory and answers messages. Reading the folder once when the app starts and keeping the result in a GenServer is the simplest real use of one.

The vocabulary:

- `start_link/1`: how the supervisor starts it.
- `init/1`: runs once in the new process; returns the initial **state**.
- `handle_call/3`: answers a synchronous request `GenServer.call(pid, msg)`; returns `{:reply, answer, new_state}`.
- State is never mutated. You return the new state.

**Do it.**

1. The context (the module the web layer will call), `lib/quickslips/templates.ex`:

```elixir
defmodule QuickSlips.Templates do
  @moduledoc """
  The catalogue of bill templates. Data lives in `priv/bill_templates/<slug>/`.
  """

  alias QuickSlips.Templates.Registry

  @doc "Directory that holds all template folders."
  def root_dir, do: Application.app_dir(:quickslips, "priv/bill_templates")

  @doc "Directory of one template."
  def template_dir(slug), do: Path.join(root_dir(), slug)

  def list, do: Registry.list()

  @doc "Categories for the home page: `[%{id: _, name: _, templates: [...]}, ...]`."
  def list_by_category, do: Registry.by_category()

  @doc "`{:ok, schema}` or `{:error, :not_found}`."
  def get(slug) when is_binary(slug), do: Registry.fetch(slug)
end
```

2. The GenServer, `lib/quickslips/templates/registry.ex`:

```elixir
defmodule QuickSlips.Templates.Registry do
  @moduledoc """
  Reads every `schema.json` once at start-up and keeps the result in memory.
  """
  use GenServer

  # Slugs that would collide with real routes.
  @reserved ~w(users auth dashboard dev api assets images fonts wasm uploads sitemap.xml)

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  def list(server \\ __MODULE__), do: GenServer.call(server, :list)

  def fetch(slug, server \\ __MODULE__), do: GenServer.call(server, {:fetch, slug})

  def by_category(server \\ __MODULE__) do
    server
    |> list()
    |> Enum.group_by(& &1["category"])
    |> Enum.sort_by(fn {category, _templates} -> category end)
    |> Enum.map(fn {category, templates} ->
      %{id: slugify(category), name: category, templates: templates}
    end)
  end

  ## Server callbacks

  @impl true
  def init(opts) do
    dir = Keyword.get(opts, :dir, QuickSlips.Templates.root_dir())
    {:ok, %{templates: load!(dir)}}
  end

  @impl true
  def handle_call(:list, _from, state) do
    templates = state.templates |> Map.values() |> Enum.sort_by(& &1["title"])
    {:reply, templates, state}
  end

  def handle_call({:fetch, slug}, _from, state) do
    case Map.fetch(state.templates, slug) do
      {:ok, schema} -> {:reply, {:ok, schema}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  ## Helpers

  defp load!(dir) do
    dir
    |> Path.join("*/schema.json")
    |> Path.wildcard()
    |> Map.new(fn path ->
      schema = path |> File.read!() |> Jason.decode!()
      folder = path |> Path.dirname() |> Path.basename()

      if schema["slug"] != folder do
        raise "#{path}: slug #{inspect(schema["slug"])} must equal the folder name #{inspect(folder)}"
      end

      if folder in @reserved or not Regex.match?(~r/^[a-z0-9-]+$/, folder) do
        raise "#{path}: #{inspect(folder)} is reserved or not a valid slug"
      end

      {folder, schema}
    end)
  end

  defp slugify(text) do
    text |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-") |> String.trim("-")
  end
end
```

3. Start it with the app. In `lib/quickslips/application.ex`, add it to `children`, after `QuickSlips.Repo`:

```elixir
      QuickSlips.Templates.Registry,
```

**Try it in `iex -S mix`.**

```elixir
QuickSlips.Templates.list() |> Enum.map(& &1["slug"])      # ["fuel-bill", "rent-receipt"]
QuickSlips.Templates.get("fuel-bill")                       # {:ok, %{"title" => "Fuel Bill Generator", ...}}
QuickSlips.Templates.get("nope")                            # {:error, :not_found}
QuickSlips.Templates.list_by_category() |> Enum.map(& &1.name)

# Let it crash:
pid = Process.whereis(QuickSlips.Templates.Registry)
Process.exit(pid, :kill)
Process.whereis(QuickSlips.Templates.Registry)              # a NEW pid: the supervisor restarted it
```

That last experiment is the heart of Elixir/OTP: processes are cheap, they crash in isolation, and supervisors restart them.

**Pitfalls.**

- *The app won't boot, with a `raise` from `load!/1`*: that's intentional ("fail fast"): a bad `schema.json` is caught at start-up, not when a customer visits. Read the message; it names the file.
- *Edits to `schema.json` don't show up in dev*: the data is read once at start. Restart the server (or recompile, which restarts the supervision tree in `iex`).
- *Design note:* for read-only data, `:persistent_term` or ETS is faster than `GenServer.call` (all callers queue through one process). With this little data and traffic, it doesn't matter, and the GenServer teaches you the pattern. Revisit only if you profile a bottleneck.

**Tests** (`test/quickslips/templates_test.exs`):

```elixir
defmodule QuickSlips.TemplatesTest do
  use ExUnit.Case, async: true

  alias QuickSlips.Templates

  test "lists the bundled templates" do
    slugs = Templates.list() |> Enum.map(& &1["slug"])
    assert "fuel-bill" in slugs
    assert "rent-receipt" in slugs
  end

  test "get/1" do
    assert {:ok, %{"title" => _}} = Templates.get("fuel-bill")
    assert {:error, :not_found} = Templates.get("does-not-exist")
  end

  test "every template folder has a sample that has every required field" do
    for schema <- Templates.list() do
      dir = Templates.template_dir(schema["slug"])
      sample = dir |> Path.join("sample.json") |> File.read!() |> Jason.decode!()

      for %{"key" => key, "required" => true} <- schema["fields"] do
        assert Map.has_key?(sample, key), "#{schema["slug"]} sample is missing #{key}"
      end
    end
  end
end
```

That last test will protect you as you add templates up to 15.

**Commit.** `git add -A && git commit -m "Task 3.3: Templates context and Registry GenServer"`

### Task 3.4: Home page

**Why.** The home page is both your storefront and your SEO landing page: a grid of cards grouped by category, each a plain link (crawlers and users both follow it).

**Do it.**

1. `lib/quickslips_web/controllers/page_controller.ex`:

```elixir
defmodule QuickSlipsWeb.PageController do
  use QuickSlipsWeb, :controller

  def home(conn, _params) do
    render(conn, :home,
      categories: QuickSlips.Templates.list_by_category(),
      page_title: "Free bill and receipt generator"
    )
  end
end
```

2. Replace everything in `lib/quickslips_web/controllers/page_html/home.html.heex` with:

```heex
<Layouts.app flash={@flash} current_scope={@current_scope}>
  <section class="py-10 text-center">
    <h1 class="text-3xl font-bold tracking-tight sm:text-4xl">Bills and receipts in seconds</h1>
    <p class="mx-auto mt-3 max-w-xl text-base-content/70">
      Pick a document, fill in the details, watch the preview update, and download a clean PDF.
    </p>
  </section>

  <section
    :for={category <- @categories}
    id={"category-#{category.id}"}
    class="mt-10"
  >
    <h2 class="text-lg font-semibold">{category.name}</h2>

    <div class="mt-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      <.link
        :for={template <- category.templates}
        id={"template-#{template["slug"]}"}
        href={~p"/#{template["slug"]}"}
        class="group flex flex-col rounded-xl border border-base-300 p-5 transition hover:-translate-y-0.5 hover:border-primary hover:shadow-md"
      >
        <span class="font-medium group-hover:text-primary">{template["title"]}</span>
        <span class="mt-1 text-sm text-base-content/70">{template["summary"]}</span>
      </.link>
    </div>
  </section>
</Layouts.app>
```

`<section :for={...}>` is the HEEx attribute form of a loop; each element gets a stable `id` so tests can find it.

3. The starter test asserts the old Phoenix welcome text. Replace `test/quickslips_web/controllers/page_controller_test.exs`:

```elixir
defmodule QuickSlipsWeb.PageControllerTest do
  use QuickSlipsWeb.ConnCase

  test "GET / lists templates by category", %{conn: conn} do
    conn = get(conn, ~p"/")
    document = conn |> html_response(200) |> LazyHTML.from_document()

    assert document |> LazyHTML.query("#template-fuel-bill") |> Enum.count() == 1
    assert document |> LazyHTML.query("#template-rent-receipt") |> Enum.count() == 1
  end
end
```

> ⚠️ Verify: `LazyHTML.from_document/1`, `LazyHTML.query/2` and `Enum.count/1` on the result are how I remember the API. If it complains, run `h LazyHTML` in `iex` and use whichever query function it lists.

**Check.** http://localhost:4000/ shows a heading and two cards grouped under "Housing" and "Vehicle & Fuel". Cards link to `/fuel-bill` and `/rent-receipt` (404 until the next task).

**Pitfalls.**

- `~p"/#{template["slug"]}"` will only compile once a route matching `/:slug` exists. If the compiler warns, finish Task 3.5 first.
- *Map access with `template["slug"]`* works because the JSON was decoded to a map with string keys. If you ever see `nil`, check key spelling in the JSON.

**Commit.** `git commit -am "Task 3.4: home page lists templates by category"`

### Task 3.5: Template page at `/:slug`

**Why.** One URL per bill type is what search engines index. The page must have its own `<title>` and meta description, and unknown slugs must return a real 404 status.

**Do it.**

1. The 404 exception, `lib/quickslips_web/not_found_error.ex`. Phoenix turns any exception that carries `plug_status: 404` into a 404 response:

```elixir
defmodule QuickSlipsWeb.NotFoundError do
  defexception message: "not found", plug_status: 404
end
```

2. The controller, `lib/quickslips_web/controllers/template_controller.ex`:

```elixir
defmodule QuickSlipsWeb.TemplateController do
  use QuickSlipsWeb, :controller

  alias QuickSlips.Templates

  def show(conn, %{"slug" => slug}) do
    case Templates.get(slug) do
      {:ok, schema} ->
        render(conn, :show,
          schema: schema,
          page_title: schema["title"],
          meta_description: schema["description"]
        )

      {:error, :not_found} ->
        raise QuickSlipsWeb.NotFoundError
    end
  end
end
```

3. The view module, `lib/quickslips_web/controllers/template_html.ex`:

```elixir
defmodule QuickSlipsWeb.TemplateHTML do
  use QuickSlipsWeb, :html

  embed_templates "template_html/*"
end
```

4. The template, `lib/quickslips_web/controllers/template_html/show.html.heex` (a placeholder until Milestone 5; it proves the schema drives the page):

```heex
<Layouts.app flash={@flash} current_scope={@current_scope}>
  <article id="template-page" class="mx-auto max-w-2xl">
    <h1 class="text-3xl font-bold tracking-tight">{@schema["title"]}</h1>
    <p class="mt-2 text-base-content/70">{@schema["description"]}</p>

    <h2 class="mt-8 text-lg font-semibold">Fields in this template</h2>
    <ul id="field-list" class="mt-3 divide-y divide-base-300 rounded-lg border border-base-300">
      <li :for={field <- @schema["fields"]} class="flex justify-between px-4 py-2 text-sm">
        <span>{field["label"]}</span>
        <span class="text-base-content/50">{field["type"]}</span>
      </li>
    </ul>

    <p class="mt-8 rounded-lg bg-base-200 p-4 text-sm">
      The live form and preview arrive in Milestone 5.
    </p>
  </article>
</Layouts.app>
```

5. The route, `router.ex`. **It must be the last route in the browser scope**, because `/:slug` matches any single-segment path and Phoenix picks the first route that matches:

```elixir
  scope "/", QuickSlipsWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/:slug", TemplateController, :show   # keep this LAST
  end
```

If your other routes (`/dashboard`, `/users/...`) are in earlier scopes in the file, they win. If you add new single-segment routes later, place them above this one.

**Check.**

- `/fuel-bill` shows the title and field list; view-source shows a `<title>Fuel Bill Generator · QuickSlips</title>` and a matching `<meta name="description">`.
- `/nope` returns 404 (in dev, Phoenix shows its debug error page; the status in the browser's Network tab is 404).
- `/dashboard` and `/users/log-in` still work (the catch-all didn't swallow them).

**Tests** (`test/quickslips_web/controllers/template_controller_test.exs`):

```elixir
defmodule QuickSlipsWeb.TemplateControllerTest do
  use QuickSlipsWeb.ConnCase

  test "shows a template", %{conn: conn} do
    conn = get(conn, ~p"/fuel-bill")
    assert html_response(conn, 200) =~ "Fuel Bill Generator"
  end

  test "unknown slug is a 404", %{conn: conn} do
    assert_error_sent 404, fn -> get(conn, ~p"/no-such-bill") end
  end
end
```

**SEO checklist for later.** One `<h1>` per page (done), unique title and description per template (done), a `/sitemap.xml` generated from `Templates.list/0`, a canonical `<link>`, and a readable `robots.txt` (already in `priv/static`). Page speed matters most on these pages; Milestone 5's caching task addresses it.

**Pitfalls.**

- *`/:slug` swallows something*: a new single-segment route declared after it. Move it above.
- *`Ecto.NoResultsError` instead of 404*: use the custom exception (or `Phoenix.Router.NoRouteError`); don't reuse an Ecto one for non-database misses.

**Commit.** `git add -A && git commit -m "Task 3.5: template pages at /:slug with 404"`; run `mix precommit`.

**Milestone 3 is done when:** `/` shows cards grouped by category, each card opens its own page with its own title and description, and unknown slugs return 404.

---

## Milestone 4: First PDF from the server

**Goal:** `POST /api/generate` with JSON returns a real PDF built by Typst.

**Elixir you'll meet:** `System.cmd/3`, `Task` with timeouts, `try/after`, `with` chains, `action_fallback`, JSON APIs, generating tests with `for`.

**The pipeline.**

```
POST {slug, template, data}
   |
   v   validate against schema.json          (Task 4.4)   -> 422 + field errors
   v   make a temp folder, copy t1.typ, write data.json   (Task 4.2)
   v   typst compile --root <tmp> ...  -> out.pdf
   v   read the bytes, delete the temp folder
   v   send the PDF as a download            (Task 4.3)
```

Why a temp folder per request? Typst reads `data.json` from disk. A fresh folder means concurrent requests can't see each other's data, and `--root` stops the template from reading anything outside it.

### Task 4.1: Write `t1.typ` and compile it by hand

**Why.** Get the *design* right in the terminal first, where the feedback loop is two seconds, before any Elixir touches it.

**Step 1: fonts.** The server must produce the same PDF as your Mac, so ship the fonts instead of relying on whatever is installed.

1. Download **Noto Sans** (free, SIL Open Font License) from Google Fonts: https://fonts.google.com/noto/specimen/Noto+Sans → "Get font" → "Download all".
2. From the zip's `static/` folder copy `NotoSans-Regular.ttf` and `NotoSans-Bold.ttf` into `priv/fonts/` (create the folder).
3. Check Typst sees them:

```bash
typst fonts --font-path priv/fonts --ignore-system-fonts | grep -i "noto sans"
```

If nothing prints, the files are in the wrong folder or are a *variable* font (a single file like `NotoSans[wdth,wght].ttf`); use the static files.

Why Noto Sans: it has the rupee sign `₹`. Not every font does, and a missing glyph shows as a box in your bill.

**Step 2: the template.** `priv/bill_templates/fuel-bill/t1.typ`:

```typst
// Fuel bill, design t1. Reads data.json (next to this file).
#let data = json("data.json")
#let preview = sys.inputs.at("mode", default: "final") == "preview"

#set page(
  paper: "a5",
  margin: (x: 14mm, y: 14mm),
  background: if preview {
    rotate(-30deg, text(size: 54pt, weight: "bold", fill: luma(225))[PREVIEW])
  },
)
#set text(font: "Noto Sans", size: 10pt)

// Optional fields may be missing or empty.
#let opt(key) = {
  let value = data.at(key, default: none)
  if value == none or value == "" { none } else { value }
}

#let fmt-date(iso) = {
  let (y, m, d) = iso.split("-").map(int)
  datetime(year: y, month: m, day: d).display("[day]/[month]/[year]")
}

// Display money as ₹ 1234.50 from a number of rupees.
#let money(n) = {
  let paise = int(calc.round(n * 100))
  let frac = calc.rem(paise, 100)
  "₹ " + str(calc.quo(paise, 100)) + "." + (if frac < 10 { "0" } else { "" }) + str(frac)
}

#align(center)[
  #text(size: 14pt, weight: "bold")[#data.station_name]
  #if opt("station_address") != none [ \ #opt("station_address")]
]

#v(2mm)
#line(length: 100%, stroke: 0.5pt + luma(180))
#v(3mm)

#grid(
  columns: (1fr, 1fr),
  row-gutter: 3mm,
  [*Bill no.* #data.bill_number], align(right)[*Date* #fmt-date(data.date)],
  [*Vehicle* #if opt("vehicle_number") != none [#opt("vehicle_number")] else [-]],
  align(right)[*Fuel* #data.fuel_type],
)

#v(4mm)

#table(
  columns: (1fr, auto, auto, auto),
  align: (left, right, right, right),
  stroke: none,
  inset: (x: 2mm, y: 3mm),
  table.hline(stroke: 0.5pt),
  [*Item*], [*Qty (L)*], [*Rate*], [*Amount*],
  table.hline(stroke: 0.5pt),
  [#data.fuel_type], [#data.quantity], [#money(data.rate)], [#money(data.quantity * data.rate)],
  table.hline(stroke: 0.5pt),
)

#v(2mm)
#align(right)[#text(size: 12pt, weight: "bold")[Total: #money(data.quantity * data.rate)]]

#place(bottom + center, text(size: 8pt, fill: luma(120))[Thank you. Visit again.])
```

And `priv/bill_templates/rent-receipt/t1.typ`:

```typst
// Rent receipt, design t1.
#let data = json("data.json")
#let preview = sys.inputs.at("mode", default: "final") == "preview"

#set page(
  paper: "a5",
  margin: (x: 16mm, y: 16mm),
  background: if preview {
    rotate(-30deg, text(size: 54pt, weight: "bold", fill: luma(225))[PREVIEW])
  },
)
#set text(font: "Noto Sans", size: 10.5pt)
#set par(leading: 0.7em)

#let opt(key) = {
  let value = data.at(key, default: none)
  if value == none or value == "" { none } else { value }
}

#let months = ("January", "February", "March", "April", "May", "June", "July",
  "August", "September", "October", "November", "December")
#let month-label(ym) = {
  let (y, m) = ym.split("-").map(int)
  months.at(m - 1) + " " + str(y)
}
#let fmt-date(iso) = {
  let (y, m, d) = iso.split("-").map(int)
  datetime(year: y, month: m, day: d).display("[day]/[month]/[year]")
}
#let money(n) = {
  let paise = int(calc.round(n * 100))
  let frac = calc.rem(paise, 100)
  "₹ " + str(calc.quo(paise, 100)) + "." + (if frac < 10 { "0" } else { "" }) + str(frac)
}

#align(center)[#text(size: 15pt, weight: "bold")[RENT RECEIPT]]
#v(2mm)
#line(length: 100%, stroke: 0.5pt + luma(180))
#v(4mm)

#align(right)[Date: #fmt-date(data.receipt_date)]
#v(2mm)

Received *#money(data.monthly_rent)* from *#data.tenant_name* towards the rent for the
month of *#month-label(data.month)* for the property situated at:

#pad(left: 5mm)[#data.property_address]

Payment mode: *#data.payment_mode*.

#v(14mm)

#align(right)[
  #line(length: 45mm, stroke: 0.5pt)
  #v(-2mm)
  *#data.landlord_name* \
  Landlord
  #if opt("landlord_pan") != none [ \ PAN: #opt("landlord_pan")]
]
```

**Step 3: compile by hand.** Run exactly what the server will do:

```bash
mkdir -p tmp
cp priv/bill_templates/fuel-bill/t1.typ tmp/main.typ
cp priv/bill_templates/fuel-bill/sample.json tmp/data.json
typst compile --root tmp --font-path priv/fonts --ignore-system-fonts tmp/main.typ tmp/fuel.pdf
open tmp/fuel.pdf
```

Repeat for `rent-receipt` (change the two folder names and the output file). Try the watermark:

```bash
typst compile --root tmp --font-path priv/fonts --ignore-system-fonts --input mode=preview tmp/main.typ tmp/fuel-preview.pdf
```

(`/tmp/` at the project root is already in `.gitignore`, so scratch files in `tmp/` won't get committed.)

**What to read in the template.**

- `sys.inputs` are the `--input key=value` flags. Browsers can't pass flags, but typst.ts offers an equivalent (Task 5.3), so the same template works in both places.
- `data.at("key", default: ...)` is safe access for optional fields.
- A string from JSON is *text*, never code. `[#data.station_name]` can't be tricked into running anything. Never feed user data to `eval(...)`.
- Money is computed here only for display. If you ever *store* totals, compute them in whole paise on the server.

**Check.** The PDF looks right: ₹ shows properly, amounts add up (28.5 × 102.45 = ₹ 2919.83), the date reads 12/10/2026, no "PREVIEW" in the final one. Edit values in `tmp/data.json` (long station name, missing vehicle number) and recompile to see how the layout copes.

**Pitfalls.**

- *`error: file not found (searched at tmp/data.json)`*: the data file must sit next to `main.typ`.
- *`unknown font family`* is only a warning; Typst falls back. Check `typst fonts --font-path priv/fonts`.
- *`error: expected expression`*: Typst syntax is strict about `#` and brackets. The error shows the exact line.
- *Typst version differences*: you have 0.15.1. When you reach Milestone 5, check the preview engine's Typst version matches closely (Task 5.2).

**Commit.** `git add -A && git commit -m "Task 4.1: Typst designs and fonts for fuel bill and rent receipt"`

### Task 4.2: The renderer module

**Why.** Wrap "run Typst" in one well-tested function that returns `{:ok, pdf_bytes}` or `{:error, reason}`. Everything else (the API, bulk jobs, the preview fallback) will call it.

**Do it.**

1. Config. In `config/config.exs` (above the environment import line), so production can point at a pinned binary later:

```elixir
config :quickslips, :typst_bin, "typst"
```

2. `lib/quickslips/render/renderer.ex`:

```elixir
defmodule QuickSlips.Render.Renderer do
  @moduledoc """
  Turns a template and its data into PDF bytes by running the Typst CLI in a
  throwaway folder.
  """
  require Logger

  alias QuickSlips.Templates

  @timeout_ms 15_000

  @doc """
  Renders `slug`/`template_id` with `data` (a map decoded from JSON).

  Options: `mode: :final | :preview` (preview adds the watermark).
  Returns `{:ok, pdf_binary}` or `{:error, reason}`.
  """
  def render(slug, template_id, data, opts \\ []) when is_map(data) do
    mode = Keyword.get(opts, :mode, :final)

    with {:ok, schema} <- Templates.get(slug),
         :ok <- ensure_template(schema, template_id),
         {:ok, typst} <- typst_executable() do
      run_in_tmp_dir(typst, slug, template_id, data, mode)
    end
  end

  # template_id comes from a user; only accept ids the schema lists. This also
  # makes path tricks like "../../etc/passwd" impossible.
  defp ensure_template(%{"templates" => templates}, template_id) do
    if Enum.any?(templates, &(&1["id"] == template_id)), do: :ok, else: {:error, :unknown_template}
  end

  defp typst_executable do
    bin = Application.get_env(:quickslips, :typst_bin, "typst")

    case System.find_executable(bin) do
      nil -> {:error, :typst_not_installed}
      path -> {:ok, path}
    end
  end

  defp run_in_tmp_dir(typst, slug, template_id, data, mode) do
    tmp = Path.join(System.tmp_dir!(), "quickslips-" <> random_id())
    File.mkdir_p!(tmp)

    try do
      File.cp!(Path.join(Templates.template_dir(slug), template_id <> ".typ"), Path.join(tmp, "main.typ"))
      File.write!(Path.join(tmp, "data.json"), Jason.encode!(data))
      compile(typst, tmp, mode)
    after
      File.rm_rf(tmp)
    end
  end

  defp compile(typst, tmp, mode) do
    out = Path.join(tmp, "out.pdf")

    args = [
      "compile",
      "--root", tmp,
      "--font-path", fonts_dir(),
      "--ignore-system-fonts",
      "--input", "mode=#{mode}",
      Path.join(tmp, "main.typ"),
      out
    ]

    task = Task.async(fn -> System.cmd(typst, args, stderr_to_stdout: true) end)

    case Task.yield(task, @timeout_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, {_output, 0}} ->
        File.read(out)

      {:ok, {output, status}} ->
        Logger.warning("typst exited with #{status}: #{String.slice(output, 0, 2000)}")
        {:error, :compile_failed}

      nil ->
        Logger.warning("typst timed out after #{@timeout_ms} ms")
        {:error, :timeout}

      {:exit, reason} ->
        {:error, {:crashed, reason}}
    end
  end

  defp fonts_dir, do: Application.app_dir(:quickslips, "priv/fonts")

  defp random_id, do: 9 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
end
```

What this shows:

- `with` chains three steps that each can fail, and returns the first failure unchanged.
- `try ... after` always deletes the temp folder, success or failure.
- `Task.yield/2` waits up to the timeout; `Task.shutdown/2` kills the task if it's still running. `System.cmd` has no timeout of its own, so we wrap it.
- `--ignore-system-fonts` makes your Mac and the server use only `priv/fonts`, so output is identical.

**Try it in `iex -S mix`.**

```elixir
data = "priv/bill_templates/fuel-bill/sample.json" |> File.read!() |> Jason.decode!()
{:ok, pdf} = QuickSlips.Render.Renderer.render("fuel-bill", "t1", data)
byte_size(pdf)
File.write!("tmp/from-elixir.pdf", pdf)    # then: open tmp/from-elixir.pdf

QuickSlips.Render.Renderer.render("fuel-bill", "t9", data)    # {:error, :unknown_template}
QuickSlips.Render.Renderer.render("fuel-bill", "t1", %{})     # {:error, :compile_failed}  (data fields missing)
```

**Pitfalls.**

- *`{:error, :typst_not_installed}`*: the server process doesn't see `/opt/homebrew/bin` on its `PATH`. Run `which typst`, and either start the server from a shell with that PATH or set `config :quickslips, :typst_bin, "/opt/homebrew/bin/typst"` for dev.
- *The timeout limit*: `Task.shutdown(:brutal_kill)` stops the Elixir task, but the `typst` OS process may continue until it finishes. Typst is quick, so this is acceptable now. Production-grade killing (using a `Port` and `kill -9` on its OS pid) is a hardening task for Milestone 9.
- *`compile_failed`*: the real Typst error is in the server log (`Logger.warning`). Read it; it names the line in `main.typ`.
- *Traffic spikes*: each request starts a process that uses a CPU core for a fraction of a second. If you ever need a cap on simultaneous compiles, run the call inside a `Task.Supervisor` with `max_children`.

**Commit.** `git add -A && git commit -m "Task 4.2: Renderer runs typst in a temp folder with a timeout"`

### Task 4.3: `POST /api/generate`

**Why.** The browser, `curl`, and later bulk jobs need a simple HTTP door to the renderer.

**Do it.**

1. Router. Uncomment or add the API scope (the `:api` pipeline already exists):

```elixir
  scope "/api", QuickSlipsWeb do
    pipe_through :api

    post "/generate", GenerateController, :create
  end
```

2. `lib/quickslips_web/controllers/generate_controller.ex`:

```elixir
defmodule QuickSlipsWeb.GenerateController do
  use QuickSlipsWeb, :controller

  alias QuickSlips.Render.Renderer

  action_fallback QuickSlipsWeb.FallbackController

  def create(conn, %{"slug" => slug, "template" => template, "data" => data}) when is_map(data) do
    with {:ok, pdf} <- Renderer.render(slug, template, data) do
      send_download(conn, {:binary, pdf},
        filename: "#{slug}.pdf",
        content_type: "application/pdf"
      )
    end
  end

  def create(_conn, _params), do: {:error, :bad_request}
end
```

3. `lib/quickslips_web/controllers/fallback_controller.ex`. When an action returns `{:error, ...}` instead of a `conn`, `action_fallback` hands it here, so every endpoint answers errors the same way:

```elixir
defmodule QuickSlipsWeb.FallbackController do
  use QuickSlipsWeb, :controller

  def call(conn, {:error, :bad_request}) do
    conn |> put_status(:bad_request) |> json(%{error: "expected slug, template and data"})
  end

  def call(conn, {:error, reason}) when reason in [:not_found, :unknown_template] do
    conn |> put_status(:not_found) |> json(%{error: "unknown template"})
  end

  def call(conn, {:error, {:validation, errors}}) do
    conn |> put_status(:unprocessable_entity) |> json(%{errors: errors})
  end

  def call(conn, {:error, _reason}) do
    conn |> put_status(:internal_server_error) |> json(%{error: "could not generate the document"})
  end
end
```

**Try it with `curl`.** Build the request body from your sample, then post it:

```bash
mkdir -p tmp
{ printf '{"slug":"fuel-bill","template":"t1","data":'; cat priv/bill_templates/fuel-bill/sample.json; printf '}'; } > tmp/request.json

curl -sS -X POST http://localhost:4000/api/generate \
  -H 'content-type: application/json' \
  --data @tmp/request.json \
  -o tmp/api.pdf -D -
open tmp/api.pdf
```

`-D -` prints the response headers: expect `HTTP/1.1 200`, `content-type: application/pdf`, and a `content-disposition: attachment; filename="fuel-bill.pdf"`.

Error cases:

```bash
curl -sS -X POST localhost:4000/api/generate -H 'content-type: application/json' -d '{"slug":"nope","template":"t1","data":{}}'
# {"error":"unknown template"}
curl -sS -X POST localhost:4000/api/generate -H 'content-type: application/json' -d '{"oops":1}'
# {"error":"expected slug, template and data"}
```

**Pitfalls.**

- *Request body is empty in the controller*: forgetting `-H 'content-type: application/json'` makes Phoenix ignore the body.
- *Returns 500*: the `{:error, :compile_failed}` fallback; read the server log for the Typst message. Missing fields trigger this until Task 4.4 adds validation.
- *CSRF*: the `:api` pipeline has no CSRF check, so `curl` works. In Milestone 6 this route moves to a pipeline with sessions and CSRF protection, and the browser sends a token header.

**Commit.** `git add -A && git commit -m "Task 4.3: POST /api/generate returns a PDF"`

### Task 4.4: Validate input against `schema.json`

**Why.** Never trust the browser. Without validation, a missing field produces an ugly Typst error and a 500, and a giant string could slow the compile. Validation also tells the form *which field* to highlight.

**Do it.** `lib/quickslips/templates/validator.ex`:

```elixir
defmodule QuickSlips.Templates.Validator do
  @moduledoc """
  Checks submitted data against the `fields` list in a template's schema.

  Returns `{:ok, clean}` (only known fields, trimmed, optional blanks removed) or
  `{:error, {:validation, %{"field_key" => ["message"]}}}`.
  """

  def validate(%{"fields" => fields}, data) when is_map(data) do
    {clean, errors} =
      Enum.reduce(fields, {%{}, %{}}, fn field, {clean, errors} ->
        key = field["key"]

        case validate_field(field, Map.get(data, key)) do
          :skip -> {clean, errors}
          {:ok, value} -> {Map.put(clean, key, value), errors}
          {:error, message} -> {clean, Map.put(errors, key, [message])}
        end
      end)

    if errors == %{}, do: {:ok, clean}, else: {:error, {:validation, errors}}
  end

  def validate(_schema, _data), do: {:error, {:validation, %{"data" => ["must be an object"]}}}

  defp validate_field(field, value) do
    cond do
      blank?(value) and field["required"] == true -> {:error, "is required"}
      blank?(value) -> :skip
      true -> check(field, value)
    end
  end

  defp blank?(nil), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_value), do: false

  defp check(%{"type" => type} = field, value) when type in ["text", "textarea"] do
    max = field["max_length"]

    cond do
      not is_binary(value) -> {:error, "must be text"}
      is_integer(max) and String.length(value) > max -> {:error, "must be at most #{max} characters"}
      true -> {:ok, String.trim(value)}
    end
  end

  defp check(%{"type" => "number"} = field, value) do
    cond do
      not is_number(value) -> {:error, "must be a number"}
      is_number(field["min"]) and value < field["min"] -> {:error, "must be at least #{field["min"]}"}
      is_number(field["max"]) and value > field["max"] -> {:error, "must be at most #{field["max"]}"}
      true -> {:ok, value}
    end
  end

  defp check(%{"type" => "date"}, value) do
    with true <- is_binary(value),
         {:ok, _date} <- Date.from_iso8601(value) do
      {:ok, value}
    else
      _ -> {:error, "must be a date like 2026-10-31"}
    end
  end

  defp check(%{"type" => "month"}, value) do
    if is_binary(value) and Regex.match?(~r/^\d{4}-(0[1-9]|1[0-2])$/, value),
      do: {:ok, value},
      else: {:error, "must be a month like 2026-10"}
  end

  defp check(%{"type" => "select", "options" => options}, value) do
    if value in options, do: {:ok, value}, else: {:error, "must be one of: #{Enum.join(options, ", ")}"}
  end

  defp check(_field, _value), do: {:error, "has an unsupported type"}
end
```

Then use it in the controller. Replace the first `create/2` clause:

```elixir
  def create(conn, %{"slug" => slug, "template" => template, "data" => data}) when is_map(data) do
    with {:ok, schema} <- Templates.get(slug),
         {:ok, clean} <- Validator.validate(schema, data),
         {:ok, pdf} <- Renderer.render(slug, template, clean) do
      send_download(conn, {:binary, pdf},
        filename: "#{slug}.pdf",
        content_type: "application/pdf"
      )
    end
  end
```

and add `alias QuickSlips.Templates` and `alias QuickSlips.Templates.Validator` at the top.

The fallback already knows `{:error, {:validation, errors}}` → **422**.

**Try it.**

```bash
curl -sS -X POST localhost:4000/api/generate -H 'content-type: application/json' \
  -d '{"slug":"fuel-bill","template":"t1","data":{"quantity":-1,"fuel_type":"Coal"}}'
# {"errors":{"bill_number":["is required"],"date":["is required"],"fuel_type":["must be one of: Petrol, Diesel, CNG"],"quantity":["must be at least 0.01"],"rate":["is required"],"station_name":["is required"]}}
```

**Tests** (`test/quickslips/templates/validator_test.exs`):

```elixir
defmodule QuickSlips.Templates.ValidatorTest do
  use ExUnit.Case, async: true

  alias QuickSlips.Templates
  alias QuickSlips.Templates.Validator

  setup do
    {:ok, schema} = Templates.get("fuel-bill")
    sample = "priv/bill_templates/fuel-bill/sample.json" |> File.read!() |> Jason.decode!()
    %{schema: schema, sample: sample}
  end

  test "the sample passes its own schema", %{schema: schema, sample: sample} do
    assert {:ok, _clean} = Validator.validate(schema, sample)
  end

  test "drops unknown keys", %{schema: schema, sample: sample} do
    {:ok, clean} = Validator.validate(schema, Map.put(sample, "evil", "x"))
    refute Map.has_key?(clean, "evil")
  end

  test "reports required, range and option errors", %{schema: schema, sample: sample} do
    bad = sample |> Map.delete("station_name") |> Map.put("quantity", 0) |> Map.put("fuel_type", "Coal")
    assert {:error, {:validation, errors}} = Validator.validate(schema, bad)
    assert errors["station_name"] == ["is required"]
    assert Map.has_key?(errors, "quantity")
    assert Map.has_key?(errors, "fuel_type")
  end
end
```

**Pitfalls.**

- *Numbers sent as strings* (`"28.5"`) are rejected with "must be a number". That's on purpose: the browser form (Task 5.1) converts before sending. If you later accept CSV (Milestone 8), convert in the CSV reader, not here.
- *Request size*: `Plug.Parsers` in `endpoint.ex` accepts bodies up to 8 MB by default. Consider `length: 200_000` if the form never sends big payloads.
- *Every new field `type` needs three implementations*: here, in the TS form (Task 5.1), and in how the template reads it.

**Commit.** `git add -A && git commit -m "Task 4.4: validate generate input against schema.json (422)"`

### Task 4.5: Tests: one per template

**Why.** When you have 15 templates, the sure way to catch a broken one is a test that compiles every `sample.json`. Adding a template folder adds a test automatically.

**Do it.** `test/quickslips/render/renderer_test.exs`:

```elixir
defmodule QuickSlips.Render.RendererTest do
  use ExUnit.Case, async: true

  alias QuickSlips.Render.Renderer
  alias QuickSlips.Templates
  alias QuickSlips.Templates.Validator

  # Needs the typst binary. Run `mix test --exclude typst` on a machine without it.
  @moduletag :typst

  # One test per (template folder, design) pair, generated when this file compiles.
  for path <- Path.wildcard("priv/bill_templates/*/schema.json") do
    slug = path |> Path.dirname() |> Path.basename()
    schema = path |> File.read!() |> Jason.decode!()

    for %{"id" => template_id} <- schema["templates"] do
      test "#{slug}/#{template_id} compiles its sample to a PDF" do
        slug = unquote(slug)
        template_id = unquote(template_id)

        sample = "priv/bill_templates/#{slug}/sample.json" |> File.read!() |> Jason.decode!()
        {:ok, schema} = Templates.get(slug)

        assert {:ok, _clean} = Validator.validate(schema, sample)
        assert {:ok, "%PDF" <> _ = pdf} = Renderer.render(slug, template_id, sample)
        assert byte_size(pdf) > 1_000
      end
    end
  end

  test "preview mode also compiles" do
    sample = "priv/bill_templates/fuel-bill/sample.json" |> File.read!() |> Jason.decode!()
    assert {:ok, "%PDF" <> _} = Renderer.render("fuel-bill", "t1", sample, mode: :preview)
  end

  test "an unknown design is rejected before any process is started" do
    assert {:error, :unknown_template} = Renderer.render("fuel-bill", "../../etc/passwd", %{})
  end
end
```

And a controller test, `test/quickslips_web/controllers/generate_controller_test.exs`:

```elixir
defmodule QuickSlipsWeb.GenerateControllerTest do
  use QuickSlipsWeb.ConnCase

  @moduletag :typst

  defp sample, do: "priv/bill_templates/fuel-bill/sample.json" |> File.read!() |> Jason.decode!()

  test "returns a PDF download", %{conn: conn} do
    conn = post(conn, ~p"/api/generate", %{slug: "fuel-bill", template: "t1", data: sample()})

    assert "%PDF" <> _ = response(conn, 200)
    assert [content_type] = get_resp_header(conn, "content-type")
    assert content_type =~ "application/pdf"
  end

  test "422 with field errors for bad data", %{conn: conn} do
    conn = post(conn, ~p"/api/generate", %{slug: "fuel-bill", template: "t1", data: %{}})
    assert %{"errors" => %{"station_name" => ["is required"]}} = json_response(conn, 422)
  end

  test "404 for an unknown template", %{conn: conn} do
    conn = post(conn, ~p"/api/generate", %{slug: "nope", template: "t1", data: %{}})
    assert json_response(conn, 404)
  end
end
```

Run `mix test`, then `mix precommit`.

**Pitfalls.**

- *The `unquote` inside `test`*: tests are created while the file compiles, so loop variables must be *unquoted* into the test body. If you see "undefined variable slug", that's the cause.
- *CI/other machines*: install Typst (same version as local) or `--exclude typst`.
- *Tests rely on the working directory being the project root* (they use relative `priv/...` paths). `mix test` always runs from there.

**Commit.** `git add -A && git commit -m "Task 4.5: tests compile every template sample"`; merge and push.

**Milestone 4 is done when:** `curl` returns a PDF for valid input, 422 with field errors for invalid input, and `mix test` compiles every template's sample.

---

## Milestone 5: Form and live WASM preview

**Goal:** typing in a form updates a watermarked preview instantly, in the browser, with no server round-trip. The Download button then asks the server for the real PDF.

**You'll meet:** TypeScript bundled by esbuild, Web Workers, debouncing, WebAssembly, `fetch` + blobs, a service worker.

**Architecture.**

```
 /fuel-bill  (controller page, plain HTML + our JS bundle)
 ┌───────────────────────────────┐    ┌─────────────────────────┐
 │ #bill-form  (built from       │    │ #bill-preview            │
 │ schema.json by form.ts)       │───▶│ <img> showing an SVG     │
 └──────────────┬────────────────┘    └────────────▲────────────┘
                │ debounced 300 ms                  │ svg
                ▼                                   │
        preview_worker.ts  (Web Worker + typst.ts WASM compiler)
                │
 Download ──────┴─▶ POST /api/generate  ──▶ real PDF (Milestone 4)
```

Why this split: the preview is *instant and free* (runs on the visitor's CPU, costs you nothing, and doesn't count against the daily quota). The PDF is *authoritative* (your pinned Typst version, your fonts, your server).

**The one rule that makes it work: parity.** The preview and the PDF must come from the same template source and the same fonts, and from compatible Typst versions. If they drift, people see one thing and download another.

> ⚠️ Verify before Task 5.2: typst.ts embeds its own build of the Typst compiler. Look up which Typst version your typst.ts release uses (see its docs/changelog) and compare with your CLI (`typst --version` is 0.15.1). If typst.ts is older, avoid newer syntax in templates, or install the CLI version that matches. Test by rendering the same sample both ways and comparing.

**Prerequisite: Node.** Phoenix's build doesn't need it, but typst.ts is an npm package:

```bash
brew install node
node --version
```

### Task 5.1: Form from schema (TypeScript)

**Why.** The schema already says what the fields are. A small function that turns `schema.json` into form inputs means template #15 needs no frontend work.

**Do it.**

1. Pass data to the page. Add `Templates.sample/1` to `lib/quickslips/templates.ex`:

```elixir
  @doc "`{:ok, sample_map}` for a template."
  def sample(slug) do
    with {:ok, _schema} <- get(slug) do
      {:ok, slug |> template_dir() |> Path.join("sample.json") |> File.read!() |> Jason.decode!()}
    end
  end
```

In `TemplateController.show/2`, fetch it and pass `sample: sample` to `render` (use `{:ok, sample} = Templates.sample(slug)` after the schema matched).

2. In `show.html.heex`, replace the placeholder section with the app root. Data goes in `data-*` attributes (HEEx escapes them):

```heex
    <div
      id="bill-app"
      data-slug={@schema["slug"]}
      data-template="t1"
      data-schema={Jason.encode!(@schema)}
      data-sample={Jason.encode!(@sample)}
      data-worker={~p"/assets/js/preview_worker.js"}
      class="mt-8 grid gap-8 lg:grid-cols-2"
    >
      <form id="bill-form" class="space-y-4" novalidate></form>

      <div>
        <div
          id="bill-preview"
          class="flex min-h-96 items-center justify-center rounded-lg border border-base-300 bg-base-200 p-2"
        >
          <p class="text-sm text-base-content/60">Preview loads here…</p>
        </div>
        <p id="bill-status" class="mt-2 text-sm text-base-content/60" role="status"></p>
        <button
          id="download-button"
          type="button"
          class="mt-4 w-full rounded-lg bg-primary px-4 py-2.5 font-medium text-primary-content transition hover:opacity-90 disabled:opacity-50"
        >
          Download PDF
        </button>
      </div>
    </div>
```

(You can widen the `max-w-2xl` on the `<article>` to `max-w-5xl` for the two-column layout.)

3. Create `assets/js/bill/form.ts`:

```ts
export type Field = {
  key: string
  label: string
  type: "text" | "textarea" | "number" | "date" | "month" | "select"
  required?: boolean
  max_length?: number
  min?: number
  options?: string[]
}
export type Schema = { slug: string; title: string; fields: Field[] }
export type BillData = Record<string, string | number>

type Control = HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement

const INPUT_CLASS =
  "w-full rounded-lg border border-base-300 bg-base-100 px-3 py-2 text-sm focus:border-primary focus:outline-2 focus:outline-primary"

function createControl(field: Field, id: string): Control {
  let control: Control
  if (field.type === "textarea") {
    control = document.createElement("textarea")
    control.rows = 3
  } else if (field.type === "select") {
    control = document.createElement("select")
    for (const option of field.options ?? []) {
      const el = document.createElement("option")
      el.value = option
      el.textContent = option
      control.append(el)
    }
  } else {
    control = document.createElement("input")
    control.type = field.type === "text" ? "text" : field.type // number | date | month
    if (field.type === "number") control.step = "any"
  }
  control.id = id
  control.name = field.key
  control.className = INPUT_CLASS
  if (field.max_length) control.maxLength = field.max_length
  if (field.min !== undefined && "min" in control) control.min = String(field.min)
  return control
}

/** Builds the form inside `form` and calls `onChange` with the current data after every edit. */
export function buildForm(
  form: HTMLFormElement,
  schema: Schema,
  initial: BillData,
  onChange: (data: BillData) => void,
) {
  const controls = new Map<string, Control>()
  const errorEls = new Map<string, HTMLElement>()

  for (const field of schema.fields) {
    const id = `field-${field.key}`
    const wrapper = document.createElement("div")

    const label = document.createElement("label")
    label.htmlFor = id
    label.className = "mb-1 block text-sm font-medium"
    label.textContent = field.label + (field.required ? " *" : "")

    const control = createControl(field, id)
    const initialValue = initial[field.key]
    if (initialValue !== undefined) control.value = String(initialValue)

    const error = document.createElement("p")
    error.id = `error-${field.key}`
    error.className = "mt-1 text-sm text-red-600"
    control.setAttribute("aria-describedby", error.id)

    wrapper.append(label, control, error)
    form.append(wrapper)
    controls.set(field.key, control)
    errorEls.set(field.key, error)
  }

  const read = (): BillData => {
    const data: BillData = {}
    for (const field of schema.fields) {
      const raw = controls.get(field.key)!.value.trim()
      if (raw === "") continue // optional and empty: omit
      data[field.key] = field.type === "number" ? Number(raw) : raw
    }
    return data
  }

  form.addEventListener("input", () => onChange(read()))

  return {
    read,
    /** Show server-side errors: `{ field_key: ["message"] }`. Pass {} to clear. */
    showErrors(errors: Record<string, string[]>) {
      for (const [key, el] of errorEls) el.textContent = (errors[key] ?? []).join(", ")
    },
  }
}
```

Note: everything uses `textContent`/DOM methods, never `innerHTML`, so user text can't inject markup.

4. `assets/js/bill/main.ts` (we'll grow it in later tasks):

```ts
import { buildForm, type BillData, type Schema } from "./form"

function init() {
  const root = document.getElementById("bill-app")
  if (!root) return // not on a template page

  const schema: Schema = JSON.parse(root.dataset.schema!)
  const sample: BillData = JSON.parse(root.dataset.sample!)
  const form = root.querySelector<HTMLFormElement>("#bill-form")!

  const ui = buildForm(form, schema, sample, (data) => console.log("changed", data))
  console.log("initial", ui.read())
}

document.addEventListener("DOMContentLoaded", init)
```

5. Load it from `assets/js/app.js`: add `import "./bill/main"` below the other imports. esbuild compiles TypeScript on its own (it only *strips* types).

6. Optional type checking (esbuild doesn't do it): `npx --prefix assets tsc --noEmit -p assets` once you've installed TypeScript with `npm install --prefix assets --save-dev typescript`.

**Check.** http://localhost:4000/fuel-bill shows a form pre-filled with the sample; typing logs the data object in the browser console. Required fields have an asterisk; selects show their options.

**Pitfalls.**

- *Nothing appears*: open the browser console. Usually the JSON attribute is malformed or `main.ts` isn't imported. Tailwind classes inside `.ts` files are picked up because `app.css` has `@source "../js"`.
- *Number fields send strings*: that's why `read()` converts with `Number(raw)`.
- *Page works only after a hard refresh in dev*: live reload covers `.ex/.heex` and built assets; if `app.js` didn't rebuild, check the esbuild watcher in the server output.

**Commit.** `git add -A && git commit -m "Task 5.1: schema-driven form in TypeScript"`

### Task 5.2: Web Worker with typst.ts

**Why.** Compiling a document takes tens to hundreds of milliseconds and the WASM module is large. In the main thread that would freeze typing; a **Web Worker** runs it on a separate thread.

> ⚠️ Verify: this task depends most heavily on a third-party library whose API changes between releases. Treat the code as a map, and check each call against the typst.ts documentation for the version you install. When you start this task, tell me the version `npm` installs and I'll adapt the code.

**Do it.**

1. Install the packages (names as I know them; check the typst.ts docs):

```bash
npm install --prefix assets @myriaddreamin/typst.ts @myriaddreamin/typst-ts-web-compiler @myriaddreamin/typst-ts-renderer
```

This creates `assets/package.json`, `assets/package-lock.json` and `assets/node_modules/` (already git-ignored). Commit the first two.

2. Serve the `.wasm` files. They're big, so *don't commit them*; copy them at build time. Add to `.gitignore`: `/priv/static/wasm/`. Then:

```bash
mkdir -p priv/static/wasm
cp assets/node_modules/@myriaddreamin/typst-ts-web-compiler/pkg/typst_ts_web_compiler_bg.wasm priv/static/wasm/
cp assets/node_modules/@myriaddreamin/typst-ts-renderer/pkg/typst_ts_renderer_bg.wasm priv/static/wasm/
```

Put those lines in a mix alias so a fresh clone can rebuild them (extend `assets.setup` in `mix.exs`, or add a small script `bin/copy_wasm` and call it from the alias).

Phoenix only serves listed folders. In `lib/quickslips_web.ex`, add `wasm` (and `sw.js` for Task 5.5) to `static_paths`:

```elixir
  def static_paths, do: ~w(assets fonts images wasm favicon.ico robots.txt sw.js)
```

3. Add the worker as a second esbuild entry. In `config/config.exs`, the esbuild `args` starts with `js/app.js`. Add the worker next to it:

```elixir
    args:
      ~w(js/app.js js/preview_worker.ts --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
```

esbuild now writes `app.js` and `preview_worker.js`. (The `data-worker={~p"/assets/js/preview_worker.js"}` we added in 5.1 gives the cache-busted URL in production.)

4. Serve template source to the browser: `GET /source/:slug/:template` returns the `.typ` text. In `router.ex`, **above** `get "/:slug"`:

```elixir
    get "/source/:slug/:template", TemplateSourceController, :show
```

```elixir
defmodule QuickSlipsWeb.TemplateSourceController do
  use QuickSlipsWeb, :controller

  alias QuickSlips.Templates

  def show(conn, %{"slug" => slug, "template" => template}) do
    with {:ok, %{"templates" => designs}} <- Templates.get(slug),
         true <- Enum.any?(designs, &(&1["id"] == template)) do
      conn
      |> put_resp_content_type("text/plain")
      |> put_resp_header("cache-control", "public, max-age=300")
      |> send_file(200, Path.join(Templates.template_dir(slug), template <> ".typ"))
    else
      _ -> raise QuickSlipsWeb.NotFoundError
    end
  end
end
```

(Only ids the schema lists are served, so no file-path tricks. Note this publishes your template designs to anyone; unavoidable when the browser compiles them.)

5. The worker, `assets/js/preview_worker.ts`:

```ts
import { $typst } from "@myriaddreamin/typst.ts"

type Job = { id: number; source: string; data: unknown }

// Tell typst.ts where to fetch its two WASM modules from (our own server).
$typst.setCompilerInitOptions({
  getModule: () => "/wasm/typst_ts_web_compiler_bg.wasm",
})
$typst.setRendererInitOptions({
  getModule: () => "/wasm/typst_ts_renderer_bg.wasm",
})

self.onmessage = async (event: MessageEvent<Job>) => {
  const { id, source, data } = event.data
  try {
    // Make data.json visible to the template, like the file next to main.typ on the server.
    await $typst.addSource("/data.json", JSON.stringify(data))
    const svg = await $typst.svg({ mainContent: source, inputs: { mode: "preview" } })
    self.postMessage({ id, svg })
  } catch (error) {
    self.postMessage({ id, error: String(error) })
  }
}
```

> ⚠️ Verify each of: `setCompilerInitOptions` / `setRendererInitOptions` with `getModule`, `addSource` for virtual files, and `svg({ mainContent, inputs })` (some versions name the last option differently or don't support `inputs`). **Fonts:** by default typst.ts downloads fonts from a public CDN. For parity with the server (and to avoid third-party requests), configure it to load the same `NotoSans-*.ttf` files from `/fonts/` (copy them into `priv/static/fonts/`). The docs call this "preload fonts" or `loadFonts`.

6. The client, `assets/js/bill/preview.ts`:

```ts
import type { BillData } from "./form"

type Reply = { id: number; svg?: string; error?: string }

export function createPreview(opts: {
  workerUrl: string
  slug: string
  template: string
  container: HTMLElement
  status: HTMLElement
}) {
  const worker = new Worker(opts.workerUrl)
  let source: string | null = null
  let latest = 0
  let timer: number | undefined
  let currentUrl: string | null = null

  const img = document.createElement("img")
  img.alt = "Document preview"
  img.className = "max-h-[75vh] w-auto bg-white shadow"

  worker.onmessage = (event: MessageEvent<Reply>) => {
    const { id, svg, error } = event.data
    if (id !== latest) return // an older render finished late; ignore it
    if (error || !svg) {
      opts.status.textContent = "Preview could not be rendered."
      console.error(error)
      return
    }
    // Show the SVG through <img> (not innerHTML): scripts inside an SVG never run there.
    const url = URL.createObjectURL(new Blob([svg], { type: "image/svg+xml" }))
    img.src = url
    if (currentUrl) URL.revokeObjectURL(currentUrl)
    currentUrl = url
    if (!img.isConnected) opts.container.replaceChildren(img)
    opts.status.textContent = ""
  }

  async function loadSource() {
    if (source) return source
    const res = await fetch(`/source/${opts.slug}/${opts.template}`)
    source = await res.text()
    return source
  }

  async function renderNow(data: BillData) {
    opts.status.textContent = "Updating preview…"
    const id = ++latest
    worker.postMessage({ id, source: await loadSource(), data })
  }

  return {
    renderNow,
    /** Re-render after the user stops typing for `delay` ms (Task 5.3). */
    schedule(data: BillData, delay = 300) {
      window.clearTimeout(timer)
      timer = window.setTimeout(() => renderNow(data), delay)
    },
  }
}
```

7. Wire it in `main.ts`: after creating the form,

```ts
import { createPreview } from "./preview"
// ...
const preview = createPreview({
  workerUrl: root.dataset.worker!,
  slug: schema.slug,
  template: root.dataset.template!,
  container: root.querySelector<HTMLElement>("#bill-preview")!,
  status: root.querySelector<HTMLElement>("#bill-status")!,
})
preview.renderNow(sample) // first render: the sample data
```

**Check.** Reload `/fuel-bill`: after a moment the sample bill appears with the PREVIEW watermark. If it doesn't, the browser console (and the Network tab, to see whether `/wasm/*.wasm` returned 200) tells you which step failed.

**Pitfalls.**

- *WASM 404*: the files aren't in `priv/static/wasm/` or `wasm` isn't in `static_paths`.
- *Typst compile errors in the console*: usually a version mismatch (see the parity note above) or a missing font; read the message, it names the template line.
- *Worker URL 404 in production*: use the `~p` value (digested) as we do, not a hard-coded `/assets/js/preview_worker.js`.
- *First load is slow* (several MB of WASM). Task 5.5 makes the second load fast.

**Commit.** `git add -A && git commit -m "Task 5.2: typst.ts web worker renders the sample to SVG"`

### Task 5.3: Live updates

**Why.** Re-rendering on every keystroke would waste CPU and flicker; **debouncing** waits until the user pauses for ~300 ms. The `latest` id in `preview.ts` also drops results from renders that finish out of order.

**Do it.** In `main.ts`, replace the `console.log` handler:

```ts
const ui = buildForm(form, schema, sample, (data) => preview.schedule(data))
```

(Declare `preview` *before* `buildForm`, or build the form first and pass a function that closes over `preview`.)

**The watermark.** It comes from `inputs: { mode: "preview" }` in the worker and the `preview` flag at the top of every template, so previews are watermarked and downloads aren't. A watermark on a preview is a *deterrent*, not security: anyone can screenshot it. The real protection is that the clean PDF only comes from `/api/generate`, where the quota applies (Milestone 6).

**Check.** Type in "Fuel station name": the preview updates about 0.3 s after you stop. Hold a key down: only one render at the end, not dozens. Set quantity to `40`: the total changes. Clear a required field: the preview should still render (validation is the server's job; the form only highlights errors after a download attempt).

**Pitfalls.**

- *Typing lags*: confirm the compile runs in the worker, not on the main thread (the Performance tab shows the worker thread).
- *Preview flickers*: you're swapping `img.src` before the new image loads. Setting a Blob URL is quick; if you see a flash, keep the old `<img>` visible until `onload` fires for the new one.
- *Invalid dates like `2026-13-45`*: `<input type="date">` prevents them in the browser, but Typst's `datetime(...)` will fail on strange values. The preview shows "could not be rendered" and keeps the last good image; that's acceptable.

**Commit.** `git commit -am "Task 5.3: debounced live preview"`

### Task 5.4: Download button

**Why.** The download is the authoritative result: your server's Typst, your fonts, no watermark.

**Do it.** `assets/js/bill/download.ts`:

```ts
import type { BillData } from "./form"

export type DownloadResult =
  | { ok: true }
  | { ok: false; status: number; errors?: Record<string, string[]>; message?: string }

export async function downloadPdf(slug: string, template: string, data: BillData): Promise<DownloadResult> {
  const csrf = document.querySelector<HTMLMetaElement>("meta[name='csrf-token']")?.content ?? ""

  const response = await fetch("/api/generate", {
    method: "POST",
    headers: { "content-type": "application/json", "x-csrf-token": csrf },
    body: JSON.stringify({ slug, template, data }),
  })

  if (!response.ok) {
    const body = await response.json().catch(() => ({}))
    return { ok: false, status: response.status, errors: body.errors, message: body.error }
  }

  const blob = await response.blob()
  const url = URL.createObjectURL(blob)
  const link = document.createElement("a")
  link.href = url
  link.download = `${slug}.pdf`
  document.body.append(link)
  link.click()
  link.remove()
  URL.revokeObjectURL(url)
  return { ok: true }
}
```

In `main.ts`, wire the button (`ui` is the object `buildForm` returned):

```ts
import { downloadPdf } from "./download"
// ...
const button = root.querySelector<HTMLButtonElement>("#download-button")!
const status = root.querySelector<HTMLElement>("#bill-status")!

button.addEventListener("click", async () => {
  button.disabled = true
  status.textContent = "Creating your PDF…"
  ui.showErrors({})
  const result = await downloadPdf(schema.slug, root.dataset.template!, ui.read())
  button.disabled = false

  if (result.ok) status.textContent = "Downloaded."
  else if (result.status === 422) {
    ui.showErrors(result.errors ?? {})
    status.textContent = "Please fix the highlighted fields."
  } else if (result.status === 429) status.textContent = "You've used today's free downloads. Please log in."
  else status.textContent = result.message ?? "Something went wrong. Please try again."
})
```

The `429` branch is for Milestone 6; leaving it now is harmless.

**CSRF note.** The `/api` scope currently has no CSRF protection, so the header is ignored. In Task 6.3 the route moves into a pipeline that checks it, which is why the header is already being sent.

**Check.** Click **Download PDF** → a `fuel-bill.pdf` downloads and matches the preview (minus the watermark). Blank the "Fuel station name" field and click again: the field shows "is required" under it and no file is downloaded.

**Pitfalls.**

- *Download opens in a tab instead of saving*: that's browser behaviour with some PDF settings; the `download` attribute normally forces a save.
- *`Unexpected token <` in the console*: the server returned an HTML error page, not JSON; check the route and the server log.

**Commit.** `git add -A && git commit -m "Task 5.4: download button posts the form to /api/generate"`

### Task 5.5: Cache WASM and fonts with a service worker

**Why.** The WASM files and fonts total many MB. A **service worker** can intercept requests and answer from a local cache, so the second visit loads them instantly (and offline).

**Do it.**

1. `priv/static/sw.js`:

```js
// Bump VERSION whenever a cached file (wasm/fonts) changes.
const VERSION = "v1"
const CACHE = `quickslips-static-${VERSION}`

self.addEventListener("install", (event) => {
  self.skipWaiting()
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys.filter((key) => key.startsWith("quickslips-static-") && key !== CACHE).map((key) => caches.delete(key)),
        ),
      )
      .then(() => self.clients.claim()),
  )
})

// Cache-first for the big static files; everything else goes straight to the network.
self.addEventListener("fetch", (event) => {
  const { request } = event
  const url = new URL(request.url)

  const cacheable = url.origin === location.origin && (url.pathname.startsWith("/wasm/") || url.pathname.startsWith("/fonts/"))
  if (request.method !== "GET" || !cacheable) return

  event.respondWith(
    caches.open(CACHE).then(async (cache) => {
      const hit = await cache.match(request)
      if (hit) return hit
      const response = await fetch(request)
      if (response.ok) cache.put(request, response.clone())
      return response
    }),
  )
})
```

2. Register it from `assets/js/app.js`, only in production builds (a caching worker makes development confusing):

```js
if ("serviceWorker" in navigator && process.env.NODE_ENV === "production") {
  navigator.serviceWorker.register("/sw.js").catch((error) => console.warn("sw failed", error))
}
```

(esbuild sets `NODE_ENV` to `production` when `--minify` is used, i.e. in `mix assets.deploy`.)

**Check.** Build a production-style bundle and serve it locally:

```bash
MIX_ENV=prod mix assets.deploy
```

then, in the browser, DevTools → Application → Service Workers shows `sw.js` as activated. Reload the template page twice: in Network, `.wasm` requests now say "(ServiceWorker)" and take ~0 ms. Throttle the network to "Slow 3G" and reload: the preview still appears quickly.

(To try the service worker in dev, temporarily remove the `NODE_ENV` check. Remember to put it back and clear the worker in DevTools afterwards.)

**Pitfalls.**

- *Stale files after an update*: you replaced a `.wasm` or font but users keep the cached copy. Bump `VERSION`.
- *"Service worker script has an unsupported MIME type"*: `sw.js` isn't in `static_paths`.
- *A service worker only runs on HTTPS or `localhost`*: fine in dev and production.
- *Scope*: `/sw.js` at the site root can control the whole site. We only intercept `/wasm/` and `/fonts/`, so a bug there can't break pages.

**Commit.** `git add -A && git commit -m "Task 5.5: service worker caches wasm and fonts"`; merge and push.

**Milestone 5 is done when:** typing updates a watermarked preview within about half a second, Download gives the real PDF, and a second page load is fast.

---

## Milestone 6: 2 free downloads a day

**Goal:** anonymous visitors get 2 PDFs per IST day, then are asked to log in. Logged-in users get a higher daily limit. Preview is always free.

**You'll meet:** plugs, signed cookies, atomic SQL (`INSERT ... ON CONFLICT`), time zones without a library, `Req` for an external API, and testing time-dependent code.

**The design.**

```
Anonymous request ──▶ cookie "vid" (random id)  ──┐
                                                  ├─▶ counters per (key, IST day):
Same request      ──▶ IP address                ──┤      "v:<vid>"  limit 2
                                                  │      "ip:<ip>"  limit 20   (stops cookie-clearing)
Logged-in request ──▶ "u:<user id>"             ──┘      "u:<id>"   limit 10
```

All limits are placeholders. Change them in one config line (Task 6.2). "Day" means the **IST calendar day** (UTC+5:30, no daylight saving), so the counter resets at midnight in India.

### Task 6.1: VisitorId plug

**Why.** Anonymous visitors need *some* identity to count against. A random id in a **signed** cookie (Phoenix signs it with your `secret_key_base`, so it can't be forged or edited) is the simplest.

**Do it.** `lib/quickslips_web/plugs/visitor_id.ex`:

```elixir
defmodule QuickSlipsWeb.Plugs.VisitorId do
  @moduledoc "Gives every browser an anonymous, signed `vid` cookie and assigns `:visitor_id`."
  import Plug.Conn

  @cookie "vid"
  @max_age 60 * 60 * 24 * 365

  def init(opts), do: opts

  def call(conn, _opts) do
    conn = fetch_cookies(conn, signed: [@cookie])

    case conn.cookies[@cookie] do
      vid when is_binary(vid) and vid != "" ->
        assign(conn, :visitor_id, vid)

      _missing_or_tampered ->
        vid = Ecto.UUID.generate()

        conn
        |> put_resp_cookie(@cookie, vid,
          sign: true,
          max_age: @max_age,
          http_only: true,
          same_site: "Lax"
        )
        |> assign(:visitor_id, vid)
    end
  end
end
```

Add it to the `:browser` pipeline in `router.ex`, after `:fetch_current_scope_for_user`:

```elixir
    plug QuickSlipsWeb.Plugs.VisitorId
```

A plug is just `init/1` plus `call/2`: it takes a `conn`, returns a `conn`.

**Check.** Open the site in a private window; DevTools → Application → Cookies shows `vid`. Reload: same value. Edit the cookie value by hand and reload: you get a *new* `vid` (the signature no longer matches).

**Pitfalls.**

- *Clearing cookies gives a fresh `vid`.* That's expected; the per-IP ceiling (Task 6.3) and Turnstile (Task 6.5) are the counter-measures.
- *In production* add `secure: true` (HTTPS only) once you're on HTTPS; with `http_only: true` JavaScript can't read it.
- *Privacy*: this is an anti-abuse cookie; mention it in your privacy policy.

**Commit.** `git add -A && git commit -m "Task 6.1: VisitorId plug (signed vid cookie)"`

### Task 6.2: `download_quota` table and `Quota.check_and_increment/3`

**Why.** The naive way, *read the count, check it, write count+1*, has a race: two simultaneous requests both read "1" and both get through. The fix is to let the **database** do check-and-increment as one atomic statement:

```sql
INSERT INTO download_quota (key, day, count) VALUES ($1, $2, 1)
ON CONFLICT (key, day) DO UPDATE SET count = download_quota.count + 1
  WHERE download_quota.count < $3
RETURNING count;
```

- No row yet → inserts `count = 1`.
- Row exists and below the limit → increments.
- Row exists and at the limit → the `WHERE` blocks the update, and **no row is returned**. That "nothing returned" is the "limit reached" signal.

**Do it.**

```bash
mix ecto.gen.migration create_download_quota
```

```elixir
defmodule QuickSlips.Repo.Migrations.CreateDownloadQuota do
  use Ecto.Migration

  def change do
    create table(:download_quota) do
      add :key, :string, null: false     # "v:<vid>", "u:<user id>" or "ip:<address>"
      add :day, :date, null: false       # the IST calendar day
      add :count, :integer, null: false, default: 0
      timestamps(type: :utc_datetime)
    end

    create unique_index(:download_quota, [:key, :day])
  end
end
```

`mix ecto.migrate`. Then the schema, `lib/quickslips/quota/counter.ex`:

```elixir
defmodule QuickSlips.Quota.Counter do
  use Ecto.Schema

  schema "download_quota" do
    field :key, :string
    field :day, :date
    field :count, :integer, default: 0
    timestamps(type: :utc_datetime)
  end
end
```

Limits in `config/config.exs`, and smaller numbers for tests in `config/test.exs`:

```elixir
# config.exs
config :quickslips, :quota, anonymous: 2, user: 10, ip: 20

# test.exs
config :quickslips, :quota, anonymous: 2, user: 3, ip: 5
```

The context, `lib/quickslips/quota.ex`:

```elixir
defmodule QuickSlips.Quota do
  @moduledoc """
  Daily download counters, one row per (key, IST day).
  """
  import Ecto.Query

  alias QuickSlips.Quota.Counter
  alias QuickSlips.Repo

  # IST is UTC+5:30 all year (no daylight saving), so no time zone database is needed.
  @ist_offset_seconds 5 * 3600 + 30 * 60

  def limits, do: Map.new(Application.fetch_env!(:quickslips, :quota))

  @doc "The current calendar date in India."
  def today_ist(now \\ DateTime.utc_now()) do
    now |> DateTime.add(@ist_offset_seconds, :second) |> DateTime.to_date()
  end

  @doc """
  Atomically uses one download for `key`. Returns `{:ok, remaining}` or
  `{:error, :limit_reached}`.
  """
  def check_and_increment(key, limit, now \\ DateTime.utc_now()) when limit > 0 do
    day = today_ist(now)
    stamp = DateTime.truncate(now, :second)

    on_conflict =
      from(c in Counter,
        where: c.count < ^limit,
        update: [inc: [count: 1], set: [updated_at: ^stamp]]
      )

    row = %{key: key, day: day, count: 1, inserted_at: stamp, updated_at: stamp}

    case Repo.insert_all(Counter, [row],
           on_conflict: on_conflict,
           conflict_target: [:key, :day],
           returning: [:count]
         ) do
      {1, [%{count: count}]} -> {:ok, limit - count}
      {0, _} -> {:error, :limit_reached}
    end
  end

  def check_and_increment(_key, _limit, _now), do: {:error, :limit_reached}

  @doc "Gives one download back (used when compilation fails)."
  def refund(key, now \\ DateTime.utc_now()) do
    day = today_ist(now)

    from(c in Counter, where: c.key == ^key and c.day == ^day and c.count > 0)
    |> Repo.update_all(inc: [count: -1])

    :ok
  end

  @doc "Downloads left today for `key` (read-only; for the badge)."
  def remaining(key, limit, now \\ DateTime.utc_now()) do
    day = today_ist(now)
    used = Repo.one(from c in Counter, where: c.key == ^key and c.day == ^day, select: c.count) || 0
    max(limit - used, 0)
  end
end
```

> ⚠️ Verify in `iex`: Ecto supports a `where` inside an `on_conflict` query for Postgres, but this is the first thing to prove. Run `Quota.check_and_increment("test", 2)` three times; you should see `{:ok, 1}`, `{:ok, 0}`, `{:error, :limit_reached}`. If the third call raises instead, use the fallback: increment unconditionally with `inc: [count: 1]`, read `count` from `returning`, and if it's above the limit call `refund/2` and return `{:error, :limit_reached}`. Still atomic per statement, just one extra write when blocked.

**Check.**

```elixir
alias QuickSlips.Quota
Quota.check_and_increment("v:demo", 2)   # {:ok, 1}
Quota.check_and_increment("v:demo", 2)   # {:ok, 0}
Quota.check_and_increment("v:demo", 2)   # {:error, :limit_reached}
Quota.today_ist()                        # today's date in India
```

**Pitfalls.**

- *Why not store `day` as a string or use `Date.utc_today()`?* UTC midnight is 5:30 am in India, so users would see their quota reset mid-morning. We shift the clock by +5:30 first.
- *Counters grow forever.* A cleanup job deletes rows older than a week (Task 9.5).

**Commit.** `git add -A && git commit -m "Task 6.2: download_quota table and atomic Quota.check_and_increment"`

### Task 6.3: Wire into `/api/generate`

**Why.** The decision "may this caller download?" belongs in a context (so it's testable without HTTP), the controller just asks.

**Do it.**

1. A `Downloads` context, `lib/quickslips/downloads.ex`, picks the counters for the caller:

```elixir
defmodule QuickSlips.Downloads do
  @moduledoc "Decides whether a caller may generate another PDF today."

  alias QuickSlips.Quota

  @type caller :: %{user: struct() | nil, visitor_id: String.t(), ip: String.t()}

  @doc """
  Reserves one download. Returns `{:ok, grant}` (pass it to `refund/1` if the render
  fails) or `{:error, {:limit_reached, :anonymous | :user}}`.
  """
  def reserve(%{user: %{id: id}}) do
    key = "u:#{id}"

    case Quota.check_and_increment(key, Quota.limits().user) do
      {:ok, remaining} -> {:ok, %{keys: [key], remaining: remaining}}
      {:error, :limit_reached} -> {:error, {:limit_reached, :user}}
    end
  end

  def reserve(%{visitor_id: vid, ip: ip}) do
    limits = Quota.limits()
    visitor_key = "v:#{vid}"
    ip_key = "ip:#{ip}"

    with {:ok, remaining} <- Quota.check_and_increment(visitor_key, limits.anonymous),
         :ok <- reserve_ip(ip_key, limits.ip, visitor_key) do
      {:ok, %{keys: [visitor_key, ip_key], remaining: remaining}}
    else
      {:error, :limit_reached} -> {:error, {:limit_reached, :anonymous}}
    end
  end

  # If the IP ceiling blocks the request, give the visitor's own count back.
  defp reserve_ip(ip_key, limit, visitor_key) do
    case Quota.check_and_increment(ip_key, limit) do
      {:ok, _remaining} ->
        :ok

      {:error, :limit_reached} = error ->
        Quota.refund(visitor_key)
        error
    end
  end

  def refund(%{keys: keys}), do: Enum.each(keys, &Quota.refund/1)

  @doc "Read-only status for the UI badge: `%{remaining: n, limit: n, tier: :anonymous | :user}`."
  def status(%{user: %{id: id}}) do
    limit = Quota.limits().user
    %{remaining: Quota.remaining("u:#{id}", limit), limit: limit, tier: :user}
  end

  def status(%{visitor_id: vid, ip: ip}) do
    limits = Quota.limits()

    remaining =
      min(Quota.remaining("v:#{vid}", limits.anonymous), Quota.remaining("ip:#{ip}", limits.ip))

    %{remaining: remaining, limit: limits.anonymous, tier: :anonymous}
  end
end
```

2. New pipeline in `router.ex`, replacing the `:api` pipeline on the generate route. It needs the session (to know the logged-in user), the visitor id, and CSRF protection:

```elixir
  pipeline :api_session do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :fetch_current_scope_for_user
    plug :protect_from_forgery
    plug QuickSlipsWeb.Plugs.VisitorId
  end

  scope "/api", QuickSlipsWeb do
    pipe_through :api_session

    post "/generate", GenerateController, :create
    get "/quota", QuotaController, :show
  end
```

3. Update the controller. Order matters: **validate → reserve → render → refund on failure**:

```elixir
  alias QuickSlips.Downloads

  def create(conn, %{"slug" => slug, "template" => template, "data" => data}) when is_map(data) do
    with {:ok, schema} <- Templates.get(slug),
         {:ok, clean} <- Validator.validate(schema, data),
         {:ok, grant} <- Downloads.reserve(caller(conn)),
         {:ok, pdf} <- render_or_refund(slug, template, clean, grant) do
      conn
      |> put_resp_header("x-downloads-remaining", Integer.to_string(grant.remaining))
      |> send_download({:binary, pdf}, filename: "#{slug}.pdf", content_type: "application/pdf")
    end
  end

  def create(_conn, _params), do: {:error, :bad_request}

  defp render_or_refund(slug, template, clean, grant) do
    case Renderer.render(slug, template, clean) do
      {:ok, pdf} ->
        {:ok, pdf}

      {:error, _reason} = error ->
        Downloads.refund(grant)
        error
    end
  end

  defp caller(conn) do
    scope = conn.assigns[:current_scope]

    %{
      user: scope && scope.user,
      visitor_id: conn.assigns.visitor_id,
      ip: conn.remote_ip |> :inet.ntoa() |> to_string()
    }
  end
```

(`caller/1` is shared with the quota endpoint in the next task, so you may want it in a small helper module.)

4. In `FallbackController`, add:

```elixir
  def call(conn, {:error, {:limit_reached, tier}}) do
    conn
    |> put_status(:too_many_requests)
    |> json(%{error: "daily limit reached", tier: tier})
  end
```

**Check.**

- In the browser, download the same document three times while logged out: the third gives HTTP 429 (Network tab). The form shows the "please log in" line from Task 5.4.
- Log in: you're counted under `u:<id>` with the bigger limit.
- Break the template on purpose (add a typo to `t1.typ`), try a download: you get a 500, and `select * from download_quota;` shows the count **didn't** go up (the refund worked). Fix the typo.

**Pitfalls.**

- *`curl` now gets 403/"invalid CSRF token"*: expected, because the route checks CSRF. Browser requests carry the header from Task 5.4. In tests, `Phoenix.ConnTest` skips CSRF for you.
- *Behind a proxy* (production), `conn.remote_ip` is the proxy's address, so *everyone* looks like one IP and hits the ceiling together. Milestone 9 adds `Plug.RewriteOn [:x_forwarded_for]`. Don't deploy before that's done.
- *Validate before reserving*: otherwise a typo in the form costs a download.
- *Race on refund*: a refund happens after the render; if the process crashes between reserve and refund the user loses one download. Acceptable.

**Commit.** `git add -A && git commit -m "Task 6.3: enforce daily quota on /api/generate; refund on failure"`

### Task 6.4: UI: badge and log-in prompt

**Why.** People should know where they stand *before* they hit the wall.

**Do it.**

1. `lib/quickslips_web/controllers/quota_controller.ex`:

```elixir
defmodule QuickSlipsWeb.QuotaController do
  use QuickSlipsWeb, :controller

  alias QuickSlips.Downloads

  def show(conn, _params) do
    scope = conn.assigns[:current_scope]

    status =
      Downloads.status(%{
        user: scope && scope.user,
        visitor_id: conn.assigns.visitor_id,
        ip: conn.remote_ip |> :inet.ntoa() |> to_string()
      })

    json(conn, status)
  end
end
```

2. In `show.html.heex`, above the Download button:

```heex
        <p id="quota-badge" class="mt-4 text-sm text-base-content/70" role="status"></p>
        <p id="login-prompt" class="mt-2 hidden rounded-lg bg-base-200 p-3 text-sm">
          You've used your free downloads for today.
          <.link href={~p"/users/log-in"} class="font-medium underline">Log in</.link>
          or <.link href={~p"/users/register"} class="font-medium underline">sign up</.link>
          to keep going, and come back tomorrow for more.
        </p>
```

3. In `main.ts`, add:

```ts
const badge = root.querySelector<HTMLElement>("#quota-badge")!
const loginPrompt = root.querySelector<HTMLElement>("#login-prompt")!

function showQuota(q: { remaining: number; limit: number; tier: string }) {
  badge.textContent =
    q.tier === "anonymous"
      ? `${q.remaining} of ${q.limit} free downloads left today`
      : `${q.remaining} of ${q.limit} downloads left today`
  loginPrompt.classList.toggle("hidden", !(q.tier === "anonymous" && q.remaining === 0))
}

fetch("/api/quota").then((r) => r.json()).then(showQuota)
```

and in the Download handler, in the `429` branch, call `loginPrompt.classList.remove("hidden")`. After a successful download, call `fetch("/api/quota")` again (or read the `x-downloads-remaining` header in `downloadPdf` and return it). The header approach saves a request.

**Check.** Fresh private window: "2 of 2 free downloads left today". Download once: "1 of 2". Twice: "0 of 2" and the prompt appears. Log in: the badge switches to the higher limit.

**Pitfalls.** The badge is a *courtesy*; the server decides. Never rely on the client count.

**Commit.** `git add -A && git commit -m "Task 6.4: download quota badge and log-in prompt"`

### Task 6.5: Cloudflare Turnstile and the per-IP ceiling

**Why.** Cookies are easy to clear, so a script could hammer `/api/generate` for unlimited free PDFs (and burn your CPU). **Turnstile** is Cloudflare's free, privacy-friendly CAPTCHA alternative: the browser proves it's a real browser, and your server verifies that proof. The per-IP counter from 6.3 is the second wall.

> ⚠️ Verify: check Cloudflare's current Turnstile docs for the exact widget options and the verification endpoint before relying on the code below.

**Do it.**

1. Cloudflare dashboard → **Turnstile** → add a widget for hostname `localhost` (add your domain in Milestone 9). Mode "Managed". Copy the **site key** (public) and **secret key** (private). Cloudflare also publishes *dummy* test keys (one set always passes, one always fails) in their docs; use those in tests and local dev if you want.
2. Add to `.env`: `TURNSTILE_SITE_KEY=...` and `TURNSTILE_SECRET_KEY=...`. In `config/runtime.exs`:

```elixir
config :quickslips, :turnstile,
  site_key: System.get_env("TURNSTILE_SITE_KEY"),
  secret_key: System.get_env("TURNSTILE_SECRET_KEY")
```

3. The server check, `lib/quickslips/turnstile.ex` (it uses `Req`, as `AGENTS.md` requires):

```elixir
defmodule QuickSlips.Turnstile do
  @moduledoc "Verifies a Cloudflare Turnstile token."

  @verify_url "https://challenges.cloudflare.com/turnstile/v0/siteverify"

  def verify(token, ip) when is_binary(token) and token != "" do
    secret = Application.get_env(:quickslips, :turnstile)[:secret_key]

    options =
      [url: @verify_url, form: [secret: secret, response: token, remoteip: ip], retry: false, receive_timeout: 5_000] ++
        Application.get_env(:quickslips, :turnstile_req_options, [])

    case Req.post(options) do
      {:ok, %{status: 200, body: %{"success" => true}}} -> :ok
      _ -> {:error, :turnstile_failed}
    end
  end

  def verify(_token, _ip), do: {:error, :turnstile_failed}
end
```

"Fail closed": if Cloudflare is unreachable, anonymous downloads are refused (logged-in users aren't affected, so tell people to log in).

4. Use it in the controller, **only for anonymous callers**, after validation and before reserving a download:

```elixir
         :ok <- verify_human(conn, params),
```

```elixir
  defp verify_human(conn, params) do
    case conn.assigns[:current_scope] do
      %{user: %{}} -> :ok
      _anonymous -> QuickSlips.Turnstile.verify(params["turnstile_token"], caller_ip(conn))
    end
  end
```

(`params` is the full params map; switch the `create` head to `create(conn, %{...} = params)`.) Add a fallback clause that maps `{:error, :turnstile_failed}` to `403` with `%{error: "verification failed"}`.

5. The widget. Cloudflare's script must come from Cloudflare, but `AGENTS.md` forbids `<script src>` in layouts, so load it from JavaScript when needed. `assets/js/bill/turnstile.ts`:

```ts
declare global {
  interface Window {
    turnstile?: {
      render: (el: HTMLElement, options: Record<string, unknown>) => string
      reset: (widgetId?: string) => void
    }
  }
}

const SRC = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit"
let loading: Promise<void> | null = null

function loadScript(): Promise<void> {
  loading ??= new Promise<void>((resolve, reject) => {
    const script = document.createElement("script")
    script.src = SRC
    script.async = true
    script.onload = () => resolve()
    script.onerror = () => reject(new Error("Turnstile failed to load"))
    document.head.append(script)
  })
  return loading
}

/** Renders the widget once and returns a function that resolves with a fresh token. */
export async function createTurnstile(container: HTMLElement, siteKey: string) {
  await loadScript()
  let pending: ((token: string) => void) | null = null
  let latest: string | null = null

  const widgetId = window.turnstile!.render(container, {
    sitekey: siteKey,
    appearance: "interaction-only", // visible only if Cloudflare needs the user to do something
    callback: (token: string) => {
      latest = token
      pending?.(token)
    },
  })

  return {
    token(): Promise<string> {
      if (latest) {
        const token = latest
        latest = null
        window.turnstile!.reset(widgetId) // tokens are single-use
        return Promise.resolve(token)
      }
      return new Promise((resolve) => (pending = resolve))
    },
  }
}
```

Pass the site key to the page via `data-turnstile-site-key={Application.get_env(:quickslips, :turnstile)[:site_key]}`, add a `<div id="turnstile-box">` near the button, and in `downloadPdf` include `turnstile_token` in the JSON body for anonymous visitors (the server ignores it for logged-in users).

6. In tests, stub Cloudflare instead of calling it. In `config/test.exs`:

```elixir
config :quickslips, :turnstile, site_key: "test", secret_key: "test"
config :quickslips, :turnstile_req_options, plug: {Req.Test, QuickSlips.Turnstile}
```

and in a test: `Req.Test.stub(QuickSlips.Turnstile, fn conn -> Req.Test.json(conn, %{"success" => true}) end)`.

**Check.** With real keys, an anonymous download works and the server log shows no Turnstile failure. In DevTools, edit the request body to remove `turnstile_token` and replay it: 403.

**Pitfalls.**

- *The token expires in ~5 minutes and works once.* Ask for a new one per download (the `reset` call does that).
- *Ad blockers / privacy extensions* can block the script. The UI should show a clear message ("couldn't verify; try logging in").
- *Skipping the server check*: client-side Turnstile alone proves nothing.
- *IPv6*: a visitor can rotate addresses within a /64. For a stricter IP ceiling, group IPv6 addresses by their first 64 bits.

**Commit.** `git add -A && git commit -m "Task 6.5: Turnstile verification for anonymous downloads"`

### Task 6.6: Tests: limits per tier and the IST reset

**Why.** Time-based logic is bug-prone and annoying to test by waiting, so we made `now` a parameter; tests can then *travel* in time.

**Do it.** `test/quickslips/quota_test.exs`:

```elixir
defmodule QuickSlips.QuotaTest do
  use QuickSlips.DataCase

  alias QuickSlips.Quota

  describe "today_ist/1" do
    test "the day rolls over at 18:30 UTC (midnight in India)" do
      assert Quota.today_ist(~U[2026-10-19 18:29:59Z]) == ~D[2026-10-19]
      assert Quota.today_ist(~U[2026-10-19 18:30:00Z]) == ~D[2026-10-20]
    end
  end

  describe "check_and_increment/3" do
    test "allows exactly `limit` downloads per day" do
      now = ~U[2026-10-19 06:00:00Z]
      assert {:ok, 1} = Quota.check_and_increment("v:a", 2, now)
      assert {:ok, 0} = Quota.check_and_increment("v:a", 2, now)
      assert {:error, :limit_reached} = Quota.check_and_increment("v:a", 2, now)
    end

    test "resets after midnight IST" do
      before_midnight = ~U[2026-10-19 18:29:00Z]
      after_midnight = ~U[2026-10-19 18:31:00Z]

      assert {:ok, 0} = Quota.check_and_increment("v:b", 1, before_midnight)
      assert {:error, :limit_reached} = Quota.check_and_increment("v:b", 1, before_midnight)
      assert {:ok, 0} = Quota.check_and_increment("v:b", 1, after_midnight)
    end

    test "keys are independent" do
      now = ~U[2026-10-19 06:00:00Z]
      assert {:ok, 0} = Quota.check_and_increment("v:c", 1, now)
      assert {:ok, 0} = Quota.check_and_increment("v:d", 1, now)
    end

    test "refund gives a download back" do
      now = ~U[2026-10-19 06:00:00Z]
      assert {:ok, 0} = Quota.check_and_increment("v:e", 1, now)
      Quota.refund("v:e", now)
      assert {:ok, 0} = Quota.check_and_increment("v:e", 1, now)
    end
  end
end
```

And the tiers, `test/quickslips/downloads_test.exs` (uses the small limits from `config/test.exs`: anonymous 2, user 3, ip 5):

```elixir
defmodule QuickSlips.DownloadsTest do
  use QuickSlips.DataCase

  alias QuickSlips.Downloads

  import QuickSlips.AccountsFixtures

  defp anon(vid, ip \\ "10.0.0.1"), do: %{user: nil, visitor_id: vid, ip: ip}

  test "anonymous visitors get 2 downloads, then are blocked" do
    assert {:ok, %{remaining: 1}} = Downloads.reserve(anon("vid-1"))
    assert {:ok, %{remaining: 0}} = Downloads.reserve(anon("vid-1"))
    assert {:error, {:limit_reached, :anonymous}} = Downloads.reserve(anon("vid-1"))
  end

  test "logged-in users get their own, larger allowance" do
    caller = %{user: user_fixture(), visitor_id: "vid-2", ip: "10.0.0.2"}

    for _ <- 1..3, do: assert({:ok, _} = Downloads.reserve(caller))
    assert {:error, {:limit_reached, :user}} = Downloads.reserve(caller)
  end

  test "the per-IP ceiling stops cookie-clearing" do
    # five different "visitors" from one IP use the ceiling of 5 ...
    for n <- 1..5, do: assert({:ok, _} = Downloads.reserve(anon("fresh-#{n}", "10.9.9.9")))

    # ... so a sixth brand-new visitor is refused, and not charged a visitor download
    assert {:error, {:limit_reached, :anonymous}} = Downloads.reserve(anon("fresh-6", "10.9.9.9"))
    assert {:ok, %{remaining: 1}} = Downloads.reserve(anon("fresh-6", "10.8.8.8"))
  end

  test "refund restores the download" do
    {:ok, grant} = Downloads.reserve(anon("vid-3", "10.0.0.3"))
    Downloads.refund(grant)
    assert %{remaining: 2} = Downloads.status(anon("vid-3", "10.0.0.3"))
  end
end
```

Run `mix test` and `mix precommit`.

**Pitfalls.** Don't test by calling `Process.sleep` until midnight (`AGENTS.md` bans sleeping in tests anyway); pass a `now`.

**Commit.** `git add -A && git commit -m "Task 6.6: quota tests incl. IST midnight reset"`; merge and push.

**Milestone 6 is done when:** an anonymous visitor's third download in an IST day gets a 429 and a log-in prompt, logged-in users get their own limit, compile failures don't use up a download, and the tests pass.

---

## Milestone 7: Account features

**Goal:** logged-in users get saved businesses that pre-fill forms, logo/signature uploads, a document history with "edit and regenerate", and a catalogue that grows to 15 bill types.

**You'll meet:** Phoenix 1.8 *scopes* in generators, LiveView uploads, file validation, LiveView streams, and the discipline of "never trust a user-supplied path".

**Scopes pay off here.** The generator makes every function take the `scope` and filter by `scope.user.id`. That's how "users can only see their own data" is enforced in the context, not remembered in each page.

### Task 7.1: Saved businesses

**Why.** Retyping your name, address and GSTIN on every bill is the most annoying part of the product. A saved business fills them in with one click.

**Do it.**

1. Generate the CRUD pages. The generator is scope-aware because `phx.gen.auth` configured a default scope in `config/config.exs` (look for `config :quickslips, :scopes`):

```bash
mix phx.gen.live Businesses Business businesses name:string address:text gstin:string
mix ecto.migrate
```

It creates the `Businesses` context (`list_businesses(scope)`, `get_business!(scope, id)`, `create_business(scope, attrs)`, ...), `BusinessLive.{Index,Show,Form}`, a migration with a `user_id` reference, and tests. It prints the routes to add. Put them **inside** `live_session :require_authenticated_user`, next to `/dashboard`:

```elixir
      live "/businesses", BusinessLive.Index, :index
      live "/businesses/new", BusinessLive.Form, :new
      live "/businesses/:id", BusinessLive.Show, :show
      live "/businesses/:id/edit", BusinessLive.Form, :edit
```

2. Read what it generated (it's the best lesson on scopes): open `lib/quickslips/businesses.ex` and see how every query starts from `scope.user.id`. Then run `mix test` and read the test that proves one user can't see another's businesses.

3. Validate the GSTIN in `lib/quickslips/businesses/business.ex`, inside `changeset/3`:

```elixir
    |> update_change(:gstin, fn
      nil -> nil
      gstin -> gstin |> String.trim() |> String.upcase()
    end)
    |> validate_format(:gstin, ~r/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$/,
      message: "is not a valid GSTIN (15 characters)"
    )
```

(A GSTIN is: 2-digit state code, the 10-character PAN, an entity digit, the letter `Z`, and a check character. This regex checks the *shape* only, not the checksum or whether the number is real. Optional empty values are skipped.)

4. Add a "Businesses" link to the header (inside the logged-in branch in `Layouts.app`) and to the dashboard.

5. **Pre-fill the bill form.** Add an optional `"prefill"` key to schema fields so the form knows which business value goes where, for example in `fuel-bill/schema.json`:

```json
{ "key": "station_name", ..., "prefill": "business.name" },
{ "key": "station_address", ..., "prefill": "business.address" }
```

In `TemplateController.show/2`, when `conn.assigns.current_scope` has a user, load `Businesses.list_businesses(scope)` and pass them to the template as `businesses` (a list of `%{id, name, address, gstin}` maps; build plain maps so you control what reaches the page). In `show.html.heex` add `data-businesses={Jason.encode!(@businesses)}` to `#bill-app` (use `[]` for logged-out visitors). In `form.ts`, extend `Field` with `prefill?: string`, and add a helper that renders a `<select id="business-select">` above the form and, on change, sets every control whose `prefill` is `business.<attr>` and calls `onChange`:

```ts
export type Business = { id: number; name: string; address: string | null; gstin: string | null }

export function addBusinessPicker(
  form: HTMLFormElement,
  schema: Schema,
  businesses: Business[],
  controls: Map<string, HTMLElement>,
  notify: () => void,
) {
  if (businesses.length === 0) return
  const select = document.createElement("select")
  select.id = "business-select"
  select.className = INPUT_CLASS
  select.append(new Option("Fill from a saved business…", ""))
  for (const b of businesses) select.append(new Option(b.name, String(b.id)))

  select.addEventListener("change", () => {
    const business = businesses.find((b) => String(b.id) === select.value)
    if (!business) return
    for (const field of schema.fields) {
      const attr = field.prefill?.startsWith("business.") ? field.prefill.slice(9) : null
      const value = attr ? (business as Record<string, unknown>)[attr] : null
      if (typeof value === "string") (controls.get(field.key) as HTMLInputElement).value = value
    }
    notify()
  })
  form.prepend(select)
}
```

(You'll need `buildForm` to return `controls` or call this inside it.)

**Check.** Log in → Businesses → New → save "Sunrise Fuel Station" with an address. Open `/fuel-bill`: a picker appears; choosing the business fills the station name/address and the preview updates. Log in as a *second* user: the first user's businesses don't appear anywhere.

**Pitfalls.**

- *Generator didn't scope the code*: check `config :quickslips, :scopes` exists. If not, regenerate with `--scope user`.
- *Sending too much to the page*: put only fields the form needs into `data-businesses`.
- *Forgetting a route is inside the right `live_session`*: a route outside it has no `@current_scope`.

**Commit.** `git add -A && git commit -m "Task 7.1: saved businesses with prefill"`

### Task 7.2: Logo and signature upload

**Why.** A logo and signature make a bill look real, and uploads are a classic place for security bugs, so we're strict.

**The rules we follow.**

1. Uploaded files are **not** stored in `priv/static`, which is public. They live in a private folder and are served by a controller that checks who is asking.
2. We never use the user's filename. We generate a random one.
3. We check the file's **magic bytes** (the first bytes of the file), not just its extension: a PNG starts with `89 50 4E 47 0D 0A 1A 0A`, a JPEG with `FF D8 FF`.
4. Only logged-in users, only PNG/JPEG, small files.
5. SVG is not allowed (it can contain scripts).

**Do it.**

1. Migration:

```bash
mix ecto.gen.migration add_images_to_businesses
```

```elixir
    alter table(:businesses) do
      add :logo_path, :string
      add :signature_path, :string
    end
```

Add `field :logo_path, :string` and `field :signature_path, :string` to the schema. **Do not add them to `cast`**; they're set by our upload code (the `AGENTS.md` rule).

2. Where files live. `config/config.exs`: `config :quickslips, :uploads_dir, Path.expand("../priv/uploads", __DIR__)`; `config/runtime.exs` (inside the `:prod` block): `config :quickslips, :uploads_dir, System.get_env("UPLOADS_DIR", "/data/uploads")`. Add `/priv/uploads/` to `.gitignore`.

3. `lib/quickslips/uploads.ex`:

```elixir
defmodule QuickSlips.Uploads do
  @moduledoc "Stores user images in a private folder after checking what they really are."

  def root, do: Application.fetch_env!(:quickslips, :uploads_dir)

  @doc "Absolute path for a stored relative path like \"12/a1b2c3.png\"."
  def path(relative), do: Path.join(root(), relative)

  @doc """
  Copies the uploaded temp file into the user's folder.
  Returns `{:ok, relative_path}` or `{:error, :unsupported_type}`.
  """
  def store(user_id, tmp_path) do
    with {:ok, ext} <- detect(tmp_path) do
      relative = Path.join(Integer.to_string(user_id), random_name() <> ext)
      destination = path(relative)
      File.mkdir_p!(Path.dirname(destination))
      File.cp!(tmp_path, destination)
      {:ok, relative}
    end
  end

  def delete(nil), do: :ok
  def delete(relative), do: File.rm(path(relative)) && :ok

  defp detect(file) do
    case File.read(file) do
      {:ok, <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, _::binary>>} -> {:ok, ".png"}
      {:ok, <<0xFF, 0xD8, 0xFF, _::binary>>} -> {:ok, ".jpg"}
      _ -> {:error, :unsupported_type}
    end
  end

  defp random_name, do: 8 |> :crypto.strong_rand_bytes() |> Base.encode16(case: :lower)
end
```

4. In `BusinessLive.Form` (generated): enable two uploads in `mount/3`:

```elixir
    socket
    |> allow_upload(:logo, accept: ~w(.png .jpg .jpeg), max_entries: 1, max_file_size: 1_000_000)
    |> allow_upload(:signature, accept: ~w(.png .jpg .jpeg), max_entries: 1, max_file_size: 1_000_000)
```

In the form (inside the `<.form>`):

```heex
      <div>
        <label class="mb-1 block text-sm font-medium">Logo (PNG or JPG, up to 1 MB)</label>
        <.live_file_input upload={@uploads.logo} />
        <div :for={entry <- @uploads.logo.entries} class="mt-2">
          <.live_img_preview entry={entry} class="h-16" />
          <p :for={err <- upload_errors(@uploads.logo, entry)} class="text-sm text-red-600">
            {Phoenix.Naming.humanize(err)}
          </p>
        </div>
      </div>
```

(Repeat for `:signature`.) In the `save` handler, before inserting or updating, consume the uploads and merge the resulting paths into the params:

```elixir
  defp save_uploads(socket, params) do
    user_id = socket.assigns.current_scope.user.id

    Enum.reduce([logo: "logo_path", signature: "signature_path"], params, fn {name, column}, acc ->
      results =
        consume_uploaded_entries(socket, name, fn %{path: tmp}, _entry ->
          {:ok, QuickSlips.Uploads.store(user_id, tmp)}
        end)

      case results do
        [{:ok, relative}] -> Map.put(acc, column, relative)
        _ -> acc
      end
    end)
  end
```

> The attrs go through the context function, whose changeset does not cast `logo_path`. Either add a dedicated `Business.image_changeset/2` that **does** `change(...)` those two columns, or have the context function `put_change` them. Delete the old file (`Uploads.delete/1`) when an image is replaced.

5. Serve files privately. In the authenticated scope in `router.ex`:

```elixir
    get "/uploads/:user_id/:file", UploadController, :show
```

```elixir
defmodule QuickSlipsWeb.UploadController do
  use QuickSlipsWeb, :controller

  def show(conn, %{"user_id" => user_id, "file" => file}) do
    owner? = Integer.to_string(conn.assigns.current_scope.user.id) == user_id
    safe? = Regex.match?(~r/^[a-f0-9]{16}\.(png|jpg)$/, file)

    if owner? and safe? do
      path = QuickSlips.Uploads.path(Path.join(user_id, file))
      if File.regular?(path), do: send_file(conn, 200, path), else: raise(QuickSlipsWeb.NotFoundError)
    else
      raise QuickSlipsWeb.NotFoundError
    end
  end
end
```

Show images in the business pages with `<img src={~p"/uploads/#{path}"}>`... (`path` is the relative `12/a1b2.png`; the route has two segments, so split it or store the two parts.)

6. **Use them in the PDF.** `Renderer.render/4` takes an option `assets: %{"logo.png" => "/abs/path"}`. Copy each file into the temp folder next to `main.typ`, and the controller (never the user) adds `"logo": "logo.png"` to the data map after validation:

```elixir
  # in Renderer.run_in_tmp_dir/5, after writing data.json
  for {name, source} <- Keyword.get(opts, :assets, %{}), do: File.cp!(source, Path.join(tmp, name))
```

In the template:

```typst
#let logo = data.at("logo", default: none)
#if logo != none [#align(center)[#image(logo, height: 14mm)]]
```

For the *browser* preview, typst.ts needs the image bytes too: fetch `/uploads/...` as an `ArrayBuffer` and register it with typst.ts's shadow filesystem (the call is named something like `mapShadow`; ⚠️ verify in the docs) before compiling.

7. For logged-in users, `GenerateController` accepts an optional `business_id`, loads it *through the scope* (`Businesses.get_business!(scope, id)`), and passes `assets:` for its logo and signature. A user can't use someone else's image because the lookup is scoped.

**Check.** Upload a real PNG → appears in the form preview. Rename a `.txt` file to `.png` and upload it: rejected (magic bytes). Upload a 3 MB image: "too large". Open `/uploads/<another user's id>/x.png`: 404. Generate a bill with a business that has a logo: logo shows in the PDF.

**Pitfalls.**

- *The uploads folder disappears on deploy*: in Docker it must be a mounted volume (`UPLOADS_DIR=/data/uploads` on a persistent volume). Task 9.1 covers that.
- *`consume_uploaded_entries` runs the function while the temp file still exists*: do the copy inside the function, as above.
- *EXIF/rotation*: phone photos may carry rotation data; stick to logos/signatures drawn or scanned.

**Commit.** `git add -A && git commit -m "Task 7.2: logo and signature uploads with private serving"`

### Task 7.3: Document history

**Why.** Users come back for last month's receipt. We store the **data**, not the PDF: it's a few hundred bytes, never goes stale, and re-rendering is fast and deterministic.

**Do it.**

1. Generate the context (scope-aware):

```bash
mix phx.gen.context Documents Document documents slug:string template:string title:string data:map
mix ecto.migrate
```

2. Save on successful download, in `GenerateController`, for logged-in users only (after the PDF was rendered):

```elixir
    if scope = conn.assigns[:current_scope], scope.user do
      QuickSlips.Documents.create_document(scope, %{
        "slug" => slug,
        "template" => template,
        "title" => history_title(schema, clean),
        "data" => clean
      })
    end
```

with, for example, `history_title(schema, clean)` returning `"#{schema["title"]} · #{clean["date"] || clean["month"] || ""}"`. Cap history per user (say 200) inside the context so nobody fills your database.

3. The page. A hand-written LiveView with a stream, as `AGENTS.md` requires for collections. `lib/quickslips_web/live/history_live.ex`:

```elixir
defmodule QuickSlipsWeb.HistoryLive do
  use QuickSlipsWeb, :live_view

  alias QuickSlips.Documents

  @impl true
  def mount(_params, _session, socket) do
    documents = Documents.list_documents(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, "History")
     |> assign(:empty?, documents == [])
     |> stream(:documents, documents)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    document = Documents.get_document!(scope, id)
    {:ok, _} = Documents.delete_document(scope, document)
    {:noreply, stream_delete(socket, :documents, document)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <h1 class="text-2xl font-semibold">History</h1>
      <p :if={@empty?} id="history-empty" class="mt-4 text-base-content/70">
        Documents you download while logged in appear here.
      </p>
      <ul id="documents" phx-update="stream" class="mt-6 divide-y divide-base-300">
        <li :for={{id, doc} <- @streams.documents} id={id} class="flex flex-wrap items-center justify-between gap-3 py-3">
          <div>
            <p class="font-medium">{doc.title}</p>
            <p class="text-sm text-base-content/60">{Calendar.strftime(doc.inserted_at, "%d %b %Y")}</p>
          </div>
          <div class="flex gap-4 text-sm">
            <.link href={~p"/history/#{doc.id}/download"}>Download again</.link>
            <.link href={~p"/#{doc.slug}?from=#{doc.id}"}>Edit and regenerate</.link>
            <button type="button" phx-click="delete" phx-value-id={doc.id} data-confirm="Delete this document?">
              Delete
            </button>
          </div>
        </li>
      </ul>
    </Layouts.app>
    """
  end
end
```

(The `@empty?` assign handles the empty state; streams can't be counted. If you delete the last item the message won't reappear until reload. Fine for now.)

4. Routes, inside the authenticated scope:

```elixir
      live "/history", HistoryLive, :index
    ...
    get "/history/:id/download", HistoryController, :download   # a normal controller route
```

`HistoryController.download/2` loads the document **through the scope** and renders it with `Renderer`, then `send_download`. Decide the policy: re-downloading your own saved document doesn't consume the daily quota (it's the same document).

5. "Edit and regenerate": in `TemplateController.show/2`, if `params["from"]` is present and a user is logged in, load that document through the scope and use `doc.data` as the form's initial data instead of `sample.json`. Nothing else changes: the same form, preview and download.

**Check.** Log in, download two documents, open `/history`: both appear. "Download again" works; "Edit and regenerate" opens the form pre-filled; Delete removes it. Log in as another user: you can't open the first user's `/history/<id>/download` (the scoped lookup raises, giving a 404).

**Pitfalls.**

- *Storing the PDF* costs disk, needs cleanup, and ties old documents to old templates. Storing data avoids all of that, and when you improve a template old documents re-render with the new design. If you want "exactly as issued" documents, store the PDF too.
- *`Document` data size*: the schema validator already caps field lengths. Keep it that way.

**Commit.** `git add -A && git commit -m "Task 7.3: document history with re-download and edit-and-regenerate"`

### Task 7.4: Add templates until you reach 15

**Why.** Reaching 15 is a repetition drill, and the data-first design makes each one cheap. This task is a *workflow*, not new code.

**The per-template checklist** (aim for 30 to 60 minutes each):

1. `cp -r priv/bill_templates/fuel-bill priv/bill_templates/<new-slug>` and clear the files.
2. Write `schema.json`: slug = folder name, a *specific* title and description (they're your search-result snippet), a category, the fields. Use only the six field types.
3. Write `sample.json` with realistic values for every required field.
4. Design `t1.typ`, compile by hand as in Task 4.1 until it looks right.
5. `mix test`: your Task 3.3 and 4.5 tests automatically cover it (`sample.json` has required fields, passes validation, compiles to PDF).
6. Look at it in the browser at `/<slug>` and download the PDF.
7. Commit: `Add <slug> template`.

**After the third template, extract the shared Typst helpers.** `money`, `fmt-date`, `opt` are duplicated in every file. Move them to `priv/bill_templates/_shared/helpers.typ`, copy that folder into the temp directory in `Renderer.run_in_tmp_dir/5`, and `#import "_shared/helpers.typ": *` in each template. (Also register that file with the browser preview's virtual filesystem.) The `_shared` folder has no `schema.json`, so the Registry ignores it.

**Ideas, grouped by category** (choose what your audience searches for; these are only suggestions):

| Category | Examples |
|---|---|
| Housing | rent receipt (done), security deposit receipt, maintenance/society receipt |
| Vehicle & Fuel | fuel bill (done), taxi/cab receipt, parking receipt |
| Business | GST invoice, simple invoice, purchase receipt, quotation |
| Payroll | salary slip, internet/phone reimbursement note |
| Education | tuition fee receipt, coaching receipt |
| Health | pharmacy bill, clinic receipt |
| Donations | donation receipt |

**Product hygiene.** Because these documents can be misused, keep the footer disclaimer from Task 3.1, publish Terms of Service that forbid using QuickSlips to deceive anyone or commit fraud, and consider a small, optional "Generated with QuickSlips" line on documents. These are product and legal decisions for you (and, for the Terms, a lawyer), not code.

**Pitfalls.**

- *Typst layout bugs only appear with long text*: put a deliberately long value in your `sample.json` copy while designing.
- *Fonts*: if a template needs a script other than Latin (for example Devanagari for Hindi), add a font that has the glyphs to `priv/fonts/` and to the browser preview.
- *Slug rules*: keep slugs descriptive and stable; they're your URLs.

**Milestone 7 is done when:** a logged-in user can save a business, attach a logo, generate a bill with it pre-filled, find it in History and re-open it; and the catalogue has 15 bill types whose tests pass.

<!-- NEXT -->
