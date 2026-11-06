defmodule QuickSlips.Render.Renderer do
  @moduledoc """
  Turns a template and its data into PDF bytes by running the Typst CLI in a
  throwaway folder.
  """
  require Logger

  alias QuickSlips.Locales
  alias QuickSlips.Regions
  alias QuickSlips.Templates

  @timeout_ms 15_000

  @doc """
  Renders `slug`/`template_id` with `data` (a map decoded from JSON).

  Options:

    * `mode: :final | :preview` (preview adds the watermark).
    * `assets: %{"logo.png" => "/abs/path/to/the/file"}`: pictures to copy next to the template, so it can
      draw them with `#image("logo.png")`. The names come from our code, never from a user.
    * `locale: "hi-in"`: the language of the words and the country of the numbers and dates (default `en-in`).
    * `currency: "EUR"`: a currency other than the country's own.

  Returns `{:ok, pdf_binary}` or `{:error, reason}`.
  """
  def render(slug, template_id, data, opts \\ []) when is_map(data) do
    mode = Keyword.get(opts, :mode, :final)
    assets = Keyword.get(opts, :assets, %{})

    with {:ok, schema} <- Templates.get(slug),
         :ok <- ensure_template(schema, template_id),
         {:ok, locale} <- fetch_locale(Keyword.get(opts, :locale, Locales.default().code)),
         {:ok, text} <- fetch_text(slug, locale),
         {:ok, region} <- Regions.build(locale.country, Keyword.get(opts, :currency)),
         {:ok, typst} <- typst_executable() do
      words = %{"text.json" => text, "region.json" => region}
      run_in_tmp_dir(typst, slug, template_id, data, words, mode, assets)
    end
  end

  defp fetch_locale(code) do
    case Locales.fetch(code) do
      {:ok, locale} -> {:ok, locale}
      :error -> {:error, :unknown_locale}
    end
  end

  # The template must be in the language of the locale; the words it prints come from there.
  defp fetch_text(slug, locale) do
    case Templates.print_text(slug, locale) do
      nil -> {:error, :unsupported_language}
      text -> {:ok, text}
    end
  end

  # template_id comes from a user; only accept ids the schema lists. This also
  # makes path tricks like "../../etc/passwd" impossible.
  defp ensure_template(%{"templates" => templates}, template_id) do
    if Enum.any?(templates, &(&1["id"] == template_id)),
      do: :ok,
      else: {:error, :unknown_template}
  end

  defp typst_executable do
    bin = Application.get_env(:quickslips, :typst_bin, "typst")

    case System.find_executable(bin) do
      nil -> {:error, :typst_not_installed}
      path -> {:ok, path}
    end
  end

  defp run_in_tmp_dir(typst, slug, template_id, data, words, mode, assets) do
    tmp = Path.join(System.tmp_dir!(), "quickslips-" <> random_id())
    File.mkdir_p!(tmp)

    try do
      File.cp!(
        Path.join(Templates.template_dir(slug), template_id <> ".typ"),
        Path.join(tmp, "main.typ")
      )

      File.write!(Path.join(tmp, "data.json"), Jason.encode!(data))

      # The words and the region of the document, which the helpers read (`text.json`, `region.json`).
      for {name, content} <- words, do: File.write!(Path.join(tmp, name), Jason.encode!(content))
      # The helpers every template imports (`#import "_shared/helpers.typ": *`).
      File.cp_r!(Path.join(Templates.root_dir(), "_shared"), Path.join(tmp, "_shared"))

      for {name, source} <- assets, do: File.cp!(source, Path.join(tmp, Path.basename(name)))

      compile(typst, tmp, mode)
    after
      File.rm_rf(tmp)
    end
  end

  defp compile(typst, tmp, mode) do
    out = Path.join(tmp, "out.pdf")

    args = [
      "compile",
      "--root",
      tmp,
      "--font-path",
      fonts_dir(),
      "--ignore-system-fonts",
      "--input",
      "mode=#{mode}",
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
