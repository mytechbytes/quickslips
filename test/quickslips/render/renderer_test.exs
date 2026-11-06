defmodule QuickSlips.Render.RendererTest do
  use ExUnit.Case, async: true

  import QuickSlips.UploadsFixtures

  alias QuickSlips.Locales
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

  # The same, with the logo and the signature of a saved business drawn on it.
  for path <- Path.wildcard("priv/bill_templates/*/schema.json") do
    slug = path |> Path.dirname() |> Path.basename()

    test "#{slug} draws a logo and a signature" do
      slug = unquote(slug)
      logo = tmp_file(png_bytes())
      signature = tmp_file(jpg_bytes())
      data = Map.merge(sample(slug), %{"logo" => "logo.png", "signature" => "signature.jpg"})

      assert {:ok, "%PDF" <> _} =
               Renderer.render(slug, "t1", data,
                 assets: %{"logo.png" => logo, "signature.jpg" => signature}
               )
    end

    test "#{slug} compiles with only its required fields" do
      slug = unquote(slug)
      {:ok, schema} = Templates.get(slug)
      required = for %{"key" => key, "required" => true} <- schema["fields"], do: key
      data = Map.take(sample(slug), required)

      assert {:ok, ^data} = Validator.validate(schema, data)
      assert {:ok, "%PDF" <> _} = Renderer.render(slug, "t1", data)
    end

    test "#{slug} compiles with every field as full as it may be" do
      slug = unquote(slug)
      {:ok, schema} = Templates.get(slug)
      data = filled_up(schema, sample(slug))

      assert {:ok, _clean} = Validator.validate(schema, data)
      assert {:ok, "%PDF" <> _} = Renderer.render(slug, "t1", data)
    end
  end

  # Text as long as the field allows, the biggest number it allows, the last option of a list.
  defp filled_up(schema, sample) do
    for field <- schema["fields"], into: %{} do
      value =
        case field do
          # a number that has a fixed shape (a licence number, a tax id) is the sample's own
          %{"type" => "tax_id"} ->
            sample[field["key"]]

          %{"type" => "text", "pattern" => _} ->
            sample[field["key"]]

          %{"type" => "tax_rate"} ->
            List.last(field["rates"])

          %{"type" => type} when type in ["text", "textarea"] ->
            "Lorem ipsum dolor sit amet "
            |> String.duplicate(12)
            |> String.slice(0, field["max_length"])

          %{"type" => "number"} ->
            field["max"] || 9_999_999.99

          %{"type" => "select", "options" => options} ->
            List.last(options)

          %{"type" => "items"} ->
            # as many rows as the table may have, with the longest name and the biggest numbers
            long = String.duplicate("x", field["name_max_length"] || 80)

            List.duplicate(
              %{"name" => long, "qty" => 9_999.99, "rate" => 9_999_999.99},
              field["max_rows"] || 30
            )

          %{"type" => "month"} ->
            sample[field["key"]] || "2026-12"

          %{"type" => "date"} ->
            sample[field["key"]] || "2026-12-31"
        end

      {field["key"], value}
    end
  end

  test "preview mode also compiles" do
    sample = "priv/bill_templates/fuel-bill/sample.json" |> File.read!() |> Jason.decode!()
    assert {:ok, "%PDF" <> _} = Renderer.render("fuel-bill", "t1", sample, mode: :preview)
  end

  describe "pictures" do
    defp sample(slug),
      do: "priv/bill_templates/#{slug}/sample.json" |> File.read!() |> Jason.decode!()

    test "a template draws the logo and signature that were copied next to it" do
      logo = tmp_file(png_bytes())
      signature = tmp_file(jpg_bytes())

      data =
        Map.merge(sample("fuel-bill"), %{"logo" => "logo.png", "signature" => "signature.jpg"})

      assert {:ok, "%PDF" <> _} =
               Renderer.render("fuel-bill", "t1", data,
                 assets: %{"logo.png" => logo, "signature.jpg" => signature}
               )
    end

    @tag :capture_log
    test "the picture really is read from the file" do
      data = Map.put(sample("fuel-bill"), "logo", "logo.png")

      assert {:error, :compile_failed} = Renderer.render("fuel-bill", "t1", data)
    end

    test "a picture is drawn only when the data names it" do
      logo = tmp_file(png_bytes())
      without = sample("rent-receipt")
      with_signature = Map.put(without, "signature", "signature.png")

      {:ok, plain} =
        Renderer.render("rent-receipt", "t1", without, assets: %{"signature.png" => logo})

      {:ok, signed} =
        Renderer.render("rent-receipt", "t1", with_signature, assets: %{"signature.png" => logo})

      assert byte_size(signed) > byte_size(plain)
    end

    test "a path in an asset name can't write outside the working folder" do
      logo = tmp_file(png_bytes())

      marker =
        Path.join(
          System.tmp_dir!(),
          "quickslips-escape-#{System.unique_integer([:positive])}.png"
        )

      on_exit(fn -> File.rm(marker) end)

      Renderer.render("fuel-bill", "t1", sample("fuel-bill"),
        assets: %{"../#{Path.basename(marker)}" => logo}
      )

      refute File.exists?(marker)
    end
  end

  describe "languages" do
    for code <- ["en-in", "hi-in", "es-es"] do
      test "fuel-bill/t1 compiles its sample in #{code}" do
        code = unquote(code)
        {:ok, sample} = Templates.sample("fuel-bill", Locales.fetch!(code))

        assert {:ok, "%PDF" <> _ = pdf} = Renderer.render("fuel-bill", "t1", sample, locale: code)
        assert byte_size(pdf) > 1_000
      end
    end

    test "the language and the country make a different document" do
      render = fn code ->
        {:ok, sample} = Templates.sample("fuel-bill", Locales.fetch!(code))
        {:ok, pdf} = Renderer.render("fuel-bill", "t1", sample, locale: code)
        byte_size(pdf)
      end

      assert render.("en-in") != render.("hi-in")
      assert render.("en-in") != render.("es-es")
    end

    test "a document may use another currency than its country's" do
      {:ok, sample} = Templates.sample("fuel-bill")

      assert {:ok, "%PDF" <> _} = Renderer.render("fuel-bill", "t1", sample, currency: "EUR")
    end

    test "a locale that is not live is refused" do
      assert {:error, :unknown_locale} = Renderer.render("fuel-bill", "t1", %{}, locale: "es-mx")
      assert {:error, :unknown_locale} = Renderer.render("fuel-bill", "t1", %{}, locale: "nope")
    end

    test "a template that is not in the language is refused" do
      assert {:error, :unsupported_language} =
               Renderer.render("rent-receipt", "t1", sample("rent-receipt"), locale: "hi-in")
    end

    test "a currency that does not exist is refused" do
      assert {:error, :unknown_currency} =
               Renderer.render("fuel-bill", "t1", sample("fuel-bill"), currency: "XXX")
    end
  end

  test "an unknown design is rejected before any process is started" do
    assert {:error, :unknown_template} = Renderer.render("fuel-bill", "../../etc/passwd", %{})
  end
end
