defmodule QuickSlips.Templates.RegistryTest do
  use ExUnit.Case, async: true

  alias QuickSlips.Templates.Registry

  @moduletag :tmp_dir

  defp write_schema(dir, slug, fields, extra \\ %{}) do
    File.mkdir_p!(Path.join(dir, slug))

    schema =
      Map.merge(
        %{slug: slug, title: "Test", category: "Work", templates: [], fields: fields},
        extra
      )

    File.write!(Path.join([dir, slug, "schema.json"]), Jason.encode!(schema))

    # Every design has a layout file, as in a real folder (the registry reads it to see if there is a place to sign).
    for %{id: id} <- schema.templates, do: write_layout(dir, slug, id, "#text[Hello]")
  end

  defp write_layout(dir, slug, id, source) do
    File.write!(Path.join([dir, slug, id <> ".typ"]), source)
  end

  defp write_text(dir, slug, name, text) do
    File.mkdir_p!(Path.join([dir, slug, "text"]))
    File.write!(Path.join([dir, slug, "text", name <> ".json"]), Jason.encode!(text))
  end

  defp write_shared(dir, name, text) do
    File.mkdir_p!(Path.join([dir, "_shared", "text"]))
    File.write!(Path.join([dir, "_shared", "text", name <> ".json"]), Jason.encode!(text))
  end

  # Starts a registry that is expected to refuse the folder, and returns what it says.
  defp start_error(dir) do
    Process.flag(:trap_exit, true)

    assert {:error, {%RuntimeError{message: message}, _stacktrace}} =
             Registry.start_link(dir: dir, name: :registry_bad)

    message
  end

  test "loads every folder that has a schema, and ignores folders that have none", %{tmp_dir: dir} do
    write_schema(dir, "one", [])
    File.mkdir_p!(Path.join(dir, "_shared"))

    registry = start_supervised!({Registry, dir: dir, name: :registry_ok})

    assert [%{"slug" => "one"}] = Registry.list(registry)
  end

  test "refuses a field named like a business picture", %{tmp_dir: dir} do
    for key <- ["logo", "signature", "stamp", "paper_size"] do
      write_schema(dir, "bad", [%{key: key, label: "Picture", type: "text"}])

      assert start_error(dir) =~ "reserved for business pictures"
    end
  end

  test "refuses a slug that is an address of the site", %{tmp_dir: dir} do
    # /sitemap and the legal pages are pages of their own, above /:locale
    for slug <- ["sitemap", "terms", "privacy", "disclaimer"] do
      File.rm_rf!(dir)
      write_schema(dir, slug, [])

      assert start_error(dir) =~ ~s("#{slug}" is reserved or not a valid slug)
    end
  end

  test "refuses a slug that is a locale, since that address is a catalogue", %{tmp_dir: dir} do
    write_schema(dir, "en-in", [])

    assert start_error(dir) =~ "reserved or not a valid slug"
  end

  describe "words" do
    test "a template without text files is in English, with its schema's own words", %{
      tmp_dir: dir
    } do
      write_schema(dir, "old", [], %{
        public_slug: "old-bill-generator",
        title: "Old Bill Generator"
      })

      registry = start_supervised!({Registry, dir: dir, name: :registry_old})

      assert {:ok, %{schema: schema}} = Registry.view("old", "en-in", registry)
      assert schema["title"] == "Old Bill Generator"
      assert schema["name"] == "Old Bill"
      assert schema["public_slug"] == "old-bill-generator"

      # ...and nothing else: a Hindi page of it would only be English under another address.
      assert {:error, :not_found} = Registry.view("old", "hi-in", registry)
      assert Registry.list_for("hi-in", registry) == []
    end

    test "the public slug defaults to the slug", %{tmp_dir: dir} do
      write_schema(dir, "plain", [])
      registry = start_supervised!({Registry, dir: dir, name: :registry_plain})

      assert {:ok, "plain"} = Registry.fetch_by_public_slug("en-in", "plain", registry)
    end

    test "text files are laid over the schema, the most specific last", %{tmp_dir: dir} do
      write_schema(
        dir,
        "bill",
        [%{key: "kind", label: "Kind", type: "select", options: ["A", "B"]}],
        %{languages: ["en", "hi"], templates: [%{id: "t1"}]}
      )

      write_text(dir, "bill", "en", %{
        title: "Bill Generator",
        public_slug: "bill-generator",
        designs: %{t1: "Classic"},
        fields: %{kind: %{label: "Kind of bill", options: %{A: "Type A"}}},
        print: %{total: "Total"}
      })

      write_text(dir, "bill", "hi", %{
        title: "बिल जनरेटर",
        public_slug: "bill-generator",
        designs: %{t1: "क्लासिक"},
        fields: %{kind: %{label: "बिल का प्रकार", options: %{A: "प्रकार क"}}},
        print: %{total: "कुल"}
      })

      write_shared(dir, "en", %{months: ["Jan"], categories: %{Work: "Work"}})
      write_shared(dir, "hi", %{months: ["जन."], categories: %{Work: "कार्य"}})

      registry = start_supervised!({Registry, dir: dir, name: :registry_words})

      assert {:ok, %{schema: english, print: print}} = Registry.view("bill", "en-in", registry)
      assert english["title"] == "Bill Generator"
      assert [%{"id" => "t1", "name" => "Classic"}] = english["templates"]
      assert [%{"label" => "Kind of bill", "option_labels" => labels}] = english["fields"]
      assert labels == %{"A" => "Type A", "B" => "B"}
      assert print["print"] == %{"total" => "Total"}
      assert print["lang"] == "en"

      assert {:ok, %{schema: hindi, print: print}} = Registry.view("bill", "hi-in", registry)
      assert hindi["title"] == "बिल जनरेटर"
      assert hindi["category_name"] == "कार्य"
      assert print["print"] == %{"total" => "कुल"}
      assert print["options"] == %{"kind" => %{"A" => "प्रकार क", "B" => "B"}}
      assert print["months"] == ["जन."]
      assert print["lang"] == "hi"
    end

    test "a declared language that is not translated completely stops the start", %{tmp_dir: dir} do
      write_schema(dir, "bill", [], %{languages: ["en", "hi"]})
      write_text(dir, "bill", "en", %{title: "Bill", fields: %{rate: %{label: "Rate"}}})
      write_text(dir, "bill", "hi", %{title: "बिल"})

      assert start_error(dir) =~ "text/hi.json is missing fields"
    end

    test "a declared language with no file at all stops the start", %{tmp_dir: dir} do
      write_schema(dir, "bill", [], %{languages: ["en", "es"]})
      write_text(dir, "bill", "en", %{title: "Bill"})

      assert start_error(dir) =~ "text/es.json is missing title"
    end

    test "shared words must be in every language a template is in", %{tmp_dir: dir} do
      write_schema(dir, "bill", [], %{languages: ["en", "es"]})
      write_text(dir, "bill", "en", %{title: "Bill"})
      write_text(dir, "bill", "es", %{title: "Factura"})
      write_shared(dir, "en", %{months: ["Jan"]})
      write_shared(dir, "es", %{})

      assert start_error(dir) =~ "_shared/text/es.json is missing months"
    end
  end

  describe "the page of a design" do
    test "is read from its layout: a roll for a thermal printer, a slip of another width, a named sheet",
         %{tmp_dir: dir} do
      write_schema(dir, "bill", [], %{templates: for(n <- 1..5, do: %{id: "t#{n}"})})

      write_layout(
        dir,
        "bill",
        "t1",
        ~S|#show: base.with(width: 80mm, margin: (x: 5mm, y: 6mm), size: 8pt)|
      )

      write_layout(dir, "bill", "t2", ~S|#show: base.with(width: 90mm, margin: 3mm)|)

      write_layout(
        dir,
        "bill",
        "t3",
        ~S|#show: base.with(width: 120.5mm, margin: (x: 8mm, y: 8mm))|
      )

      write_layout(
        dir,
        "bill",
        "t4",
        ~S|#show: base.with(paper: "a4", margin: 18mm, size: 10.5pt)|
      )

      write_layout(dir, "bill", "t5", "#text[no page line]")
      registry = start_supervised!({Registry, dir: dir, name: :registry_page})

      assert {:ok, schema} = Registry.fetch("bill", registry)

      pages =
        Map.new(schema["templates"], &{&1["id"], {&1["thermal"], &1["slip_width"], &1["paper"]}})

      assert pages == %{
               "t1" => {true, 80.0, nil},
               "t2" => {true, 90.0, nil},
               "t3" => {false, 120.5, nil},
               "t4" => {false, nil, "a4"},
               "t5" => {false, nil, nil}
             }
    end

    test "is told for every design that exists: the roll receipts are the ones made for 64 to 86 mm" do
      rolls =
        for %{"slug" => slug} <- QuickSlips.Templates.list(),
            {:ok, schema} = QuickSlips.Templates.get(slug),
            %{"thermal" => true, "id" => id, "slip_width" => width} <- schema["templates"],
            do: {slug, id, width}

      assert length(rolls) == 8
      assert Enum.all?(rolls, fn {_, _, width} -> width >= 64 and width <= 86 end)
      assert {"parking-receipt", "t1", 74.0} in rolls
    end
  end

  describe "a place for a revenue stamp" do
    test "a design has one when its layout uses the revenue-stamp helper", %{tmp_dir: dir} do
      write_schema(dir, "bill", [], %{templates: [%{id: "t1"}, %{id: "t2"}]})
      write_layout(dir, "bill", "t1", ~S|#revenue-stamp(data, t.revenue_stamp)|)
      write_layout(dir, "bill", "t2", ~S|// a time stamp: stamp("check_in")|)
      registry = start_supervised!({Registry, dir: dir, name: :registry_stamp})

      assert {:ok, schema} = Registry.fetch("bill", registry)

      assert Map.new(schema["templates"], &{&1["id"], &1["stamp"]}) ==
               %{"t1" => true, "t2" => false}
    end

    test "is true for the designs of the receipts that have the box, and for no other bill" do
      {:ok, rent} = QuickSlips.Templates.get("rent-receipt")
      {:ok, fuel} = QuickSlips.Templates.get("fuel-bill")

      assert Map.new(rent["templates"], &{&1["id"], &1["stamp"]}) ==
               %{"t1" => true, "t2" => true, "t3" => true, "t4" => false}

      refute Enum.any?(fuel["templates"], & &1["stamp"])
    end
  end

  describe "a place to sign" do
    test "a design has one when its layout uses the signature block or the signature picture",
         %{tmp_dir: dir} do
      write_schema(dir, "bill", [], %{
        templates: [%{id: "t1"}, %{id: "t2"}, %{id: "t3"}, %{id: "t4"}]
      })

      write_layout(dir, "bill", "t1", ~S|#signature-block(data, "Signatory")|)
      write_layout(dir, "bill", "t2", ~S|#let mark = picture(data, "signature", 8mm)|)

      write_layout(
        dir,
        "bill",
        "t3",
        "// the server adds `signature` to the data, but this layout never draws it"
      )

      write_layout(dir, "bill", "t4", "#text[Thank you]")
      registry = start_supervised!({Registry, dir: dir, name: :registry_signature})

      assert {:ok, schema} = Registry.fetch("bill", registry)

      assert Map.new(schema["templates"], &{&1["id"], &1["signature"]}) ==
               %{"t1" => true, "t2" => true, "t3" => false, "t4" => false}
    end

    test "a design has a place for the driver's signature when its layout reads that picture", %{
      tmp_dir: dir
    } do
      write_schema(dir, "bill", [], %{templates: [%{id: "t1"}, %{id: "t2"}]})

      write_layout(
        dir,
        "bill",
        "t1",
        ~S|#signature-block(data, "Driver", key: "driver_signature")|
      )

      write_layout(dir, "bill", "t2", ~S|#signature-block(data, "Signatory")|)
      registry = start_supervised!({Registry, dir: dir, name: :registry_driver_signature})

      assert {:ok, schema} = Registry.fetch("bill", registry)

      assert Map.new(schema["templates"], &{&1["id"], &1["driver_signature"]}) ==
               %{"t1" => true, "t2" => false}
    end

    test "is said in every locale the template is in", %{tmp_dir: dir} do
      write_schema(dir, "bill", [], %{templates: [%{id: "t1"}], languages: ["en", "hi"]})
      write_layout(dir, "bill", "t1", ~S|#signature-block(data, t.signatory)|)
      write_text(dir, "bill", "en", %{title: "Bill"})
      write_text(dir, "bill", "hi", %{title: "बिल"})
      write_shared(dir, "en", %{})
      write_shared(dir, "hi", %{})
      registry = start_supervised!({Registry, dir: dir, name: :registry_signature_locales})

      for code <- ["en-in", "hi-in"] do
        assert {:ok, %{schema: %{"templates" => [%{"signature" => true}]}}} =
                 Registry.view("bill", code, registry)
      end
    end

    test "a design whose layout file is missing stops the start", %{tmp_dir: dir} do
      write_schema(dir, "bill", [], %{templates: [%{id: "t1"}]})
      File.rm!(Path.join([dir, "bill", "t1.typ"]))

      assert start_error(dir) =~ ~s(the layout of the design "t1" can't be read)
    end
  end

  describe "public slugs" do
    test "two templates can't have the same one in a locale", %{tmp_dir: dir} do
      write_schema(dir, "one", [], %{public_slug: "same-generator"})
      write_schema(dir, "two", [], %{public_slug: "same-generator"})

      assert start_error(dir) =~ ~r/have the same public slug "same-generator" in en-/
    end

    test "must be lowercase letters, digits and hyphens", %{tmp_dir: dir} do
      write_schema(dir, "one", [], %{public_slug: "Not A Slug"})

      assert start_error(dir) =~ "must be lowercase letters, digits and hyphens"
    end

    test "lead to the template, and a template lists its own in each locale", %{tmp_dir: dir} do
      write_schema(dir, "one", [], %{public_slug: "one-generator", languages: ["en", "hi"]})
      write_text(dir, "one", "en", %{title: "One"})
      write_text(dir, "one", "hi", %{title: "एक", public_slug: "ek-generator"})
      write_shared(dir, "en", %{})
      write_shared(dir, "hi", %{})
      registry = start_supervised!({Registry, dir: dir, name: :registry_slugs})

      assert {:ok, "one"} = Registry.fetch_by_public_slug("en-in", "one-generator", registry)
      assert {:ok, "one"} = Registry.fetch_by_public_slug("hi-in", "ek-generator", registry)

      assert {:error, :not_found} =
               Registry.fetch_by_public_slug("hi-in", "one-generator", registry)

      assert {:error, :not_found} =
               Registry.fetch_by_public_slug("es-es", "one-generator", registry)

      assert Registry.public_slugs("one", registry) == %{
               "en-in" => "one-generator",
               "en-us" => "one-generator",
               "en-gb" => "one-generator",
               "en-ca" => "one-generator",
               "hi-in" => "ek-generator"
             }

      assert Registry.public_slugs("nope", registry) == %{}
    end
  end
end
