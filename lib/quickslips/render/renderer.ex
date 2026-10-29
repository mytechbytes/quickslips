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

  defp run_in_tmp_dir(typst, slug, template_id, data, mode) do
    tmp = Path.join(System.tmp_dir!(), "quickslips-" <> random_id())
    File.mkdir_p!(tmp)

    try do
      File.cp!(
        Path.join(Templates.template_dir(slug), template_id <> ".typ"),
        Path.join(tmp, "main.typ")
      )

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
