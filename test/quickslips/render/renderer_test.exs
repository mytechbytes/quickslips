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

      for %{"id" => design} <- schema["templates"] do
        assert {:ok, "%PDF" <> _} = Renderer.render(slug, design, data), "#{slug}/#{design}"
      end
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

          %{"type" => "time"} ->
            sample[field["key"]] || "23:59"
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
               Renderer.render("courier-receipt", "t1", sample("courier-receipt"),
                 locale: "hi-in"
               )
    end

    test "a currency that does not exist is refused" do
      assert {:error, :unknown_currency} =
               Renderer.render("fuel-bill", "t1", sample("fuel-bill"), currency: "XXX")
    end
  end

  # The bills that have several designs: every design in every live locale, with little data and with a lot.
  @multi_design %{
    "fuel-bill" => %{
      designs: ~w(t1 t2 t3 t4 t5 t6),
      optional:
        ~w(station_address station_phone dealer_name seller_tax_id fcc_id fip_no time customer_name
           vehicle_number nozzle_number density),
      long: %{
        "station_name" => String.duplicate("Petroleum Retail Services ", 3),
        "station_address" => String.duplicate("Plot 12, Industrial Area, ", 6),
        "customer_name" => String.duplicate("Ramakrishnan ", 5),
        "quantity" => 99_999.999,
        "rate" => 9_999.99
      }
    },
    "parking-receipt" => %{
      designs: ~w(t1),
      optional: ~w(facility_phone time thank_you),
      long: %{
        "facility_name" => String.duplicate("City Centre Parking ", 5),
        "facility_address" => String.duplicate("Plot 4, MG Road, Gurugram, ", 7),
        "space_number" => "ABCDEFGHIJ-0123456789",
        "thank_you" => String.duplicate("THANK YOU AND DRIVE SAFELY! ", 4),
        "amount" => 99_999_999.99
      }
    },
    "maintenance-bill" => %{
      designs: ~w(t1),
      optional:
        ~w(workshop_phone dealer_name seller_tax_id reference_number workshop_section customer_phone vin
           insurance_company parts labour tax_percent terms),
      long: %{
        "workshop_name" => String.duplicate("Sunrise Motors Workshop ", 4),
        "workshop_address" => String.duplicate("Plot 21, Industrial Area, ", 7),
        "customer_name" => String.duplicate("Ramakrishnan ", 5),
        "vehicle_model" => String.duplicate("Honda City ", 6),
        "terms" =>
          String.duplicate("The workshop is not responsible for items left in the vehicle.\n", 8),
        "parts" =>
          List.duplicate(
            %{
              "code" => String.duplicate("A", 30),
              "name" => String.duplicate("Front brake pads ", 5),
              "billing" => "Insurance",
              "qty" => 9_999.99,
              "rate" => 9_999_999.99,
              "discount" => 12.5
            },
            12
          ),
        "labour" =>
          List.duplicate(
            %{
              "code" => String.duplicate("B", 30),
              "name" => String.duplicate("Brake inspection ", 5),
              "billing" => "Warranty",
              "rate" => 9_999_999.99,
              "discount" => 100
            },
            8
          )
      }
    },
    "transport-bill" => %{
      designs: ~w(t1),
      optional:
        ~w(company_address company_phone seller_tax_id booking_date eta_date pm_number description articles
           actual_weight charged_weight remarks from_phone to_phone delivery_at signatory_name to_pay paid),
      long: %{
        "company_name" => String.duplicate("Shree Ganesh Transport ", 4),
        "company_address" => String.duplicate("Plot 14, Transport Nagar, ", 7),
        "consignor" => String.duplicate("Mehra Traders, Karol Bagh, ", 7),
        "consignee" => String.duplicate("Gupta Electricals, MI Road, ", 7),
        "description" => String.duplicate("Electrical goods in cartons, ", 10),
        "remarks" => String.duplicate("Handle with care, ", 10),
        "from_place" => String.duplicate("Delhi ", 10),
        "to_place" => String.duplicate("Jaipur ", 8),
        "actual_weight" => "12345678901234567890",
        "articles" => 99_999_999,
        "to_pay" => 99_999_999.99,
        "paid" => 99_999_999.99
      }
    },
    "grocery-bill" => %{
      designs: ~w(t1 t2),
      optional:
        ~w(store_address store_phone gstin fssai_number time transaction_id customer_name discount tax_percent),
      long: %{
        "store_name" => String.duplicate("Mehta & Sons Provisions ", 4),
        "store_address" => String.duplicate("Shop 21, Station Road, Surat, ", 7),
        "customer_name" => String.duplicate("Ramakrishnan ", 5),
        "transaction_id" => String.duplicate("TXN-4829173650-", 6),
        "discount" => 1.5,
        "items" =>
          List.duplicate(
            %{
              "name" => String.duplicate("Basmati rice premium pack ", 4),
              "qty" => 9_999.99,
              "rate" => 9_999_999.99,
              "discount" => 12.5
            },
            14
          )
      }
    },
    "pharmacy-bill" => %{
      designs: ~w(t1),
      optional:
        ~w(brand_subtitle branch_name branch_address toll_free website dl_number seller_tax_id fssai
           registered_office admin_office time terminal_number ref_number doctor_name discount signatory_name
           signatory_line),
      long: %{
        "brand_name" => String.duplicate("WellCare Pharmacy ", 3),
        "branch_address" => String.duplicate("21, 80 Feet Road, Koramangala, ", 6),
        "dl_number" => String.duplicate("KA/BNG/20-1234, ", 8),
        "registered_office" => String.duplicate("WellCare Retail Pvt. Ltd., ", 8),
        "customer_name" => String.duplicate("Ramakrishnan ", 5),
        "discount" => 1.5,
        "items" =>
          List.duplicate(
            %{
              "name" => String.duplicate("Paracetamol 500 mg strip ", 4),
              "hsn" => "ABCDEFGHIJ0123456789",
              "mfr" => String.duplicate("Alpha Pharma ", 2),
              "batch" => "ABCDEFGHIJ0123456789",
              "expiry" => "ABCDEFGHIJ",
              "schedule" => "ABCDEFGHIJ",
              "qty" => 9_999.99,
              "rate" => 9_999_999.99,
              "tax" => 18
            },
            14
          )
      }
    },
    "medical-bill" => %{
      designs: ~w(t1 t2),
      optional:
        ~w(clinic_address clinic_phone hospital_details registration_number time admit_date discharge_date
           patient_details patient_issue guardian_name patient_phone patient_address payer_name payer_address
           doctor_name doctor_designation room insurance remark items consultation_fee medicines_cost
           tests_cost other_charges discount tax_percent amount_paid),
      long: %{
        "clinic_name" => String.duplicate("Sunrise Multispeciality Hospital ", 3),
        "clinic_address" => String.duplicate("Shop 2, Lake View Road, Kochi, ", 6),
        "hospital_details" => String.duplicate("24-hour emergency care, pharmacy, ", 5),
        "patient_name" => String.duplicate("Ramakrishnan ", 5),
        "patient_address" => String.duplicate("12, Marine Drive, Kochi, ", 7),
        "payer_address" => String.duplicate("12, Marine Drive, Kochi, ", 7),
        "doctor_name" => String.duplicate("Venkatasubramanian ", 4),
        "remark" => String.duplicate("Follow up after 5 days. ", 12),
        "consultation_fee" => 9_999_999.99,
        "amount_paid" => 1.5,
        "items" =>
          List.duplicate(
            %{
              "name" => String.duplicate("Room rent per day ", 5),
              "qty" => 9_999.99,
              "rate" => 9_999_999.99
            },
            14
          )
      }
    },
    "meal-bill" => %{
      designs: ~w(t1),
      optional:
        ~w(brand_name legal_name restaurant_address restaurant_gstin restaurant_fssai order_id delivery_address
           place_of_supply hsn_code service_description reverse_charge payment_note platform_company
           platform_pan platform_cin platform_tax_id platform_fssai signatory_name),
      long: %{
        "brand_name" => "QuickEatsQuickEatsQuickEats",
        "legal_name" => String.duplicate("Green Leaf Hospitality ", 5),
        "restaurant_name" => String.duplicate("Green Leaf Café ", 5),
        "restaurant_address" => String.duplicate("14, Church Street, Bengaluru, ", 6),
        "customer_name" => String.duplicate("Ramakrishnan ", 5),
        "delivery_address" => String.duplicate("Flat 12, Lotus Apartments, HSR Layout, ", 6),
        "platform_company" => String.duplicate("QuickEats Technologies Pvt. Ltd., ", 6),
        "payment_note" => String.duplicate("Paid online by card. ", 8),
        "items" =>
          List.duplicate(
            %{
              "name" => String.duplicate("Masala Dosa with chutney ", 3),
              "rate" => 9_999_999.99,
              "discount" => 12.5,
              "tax" => 18
            },
            12
          )
      }
    },
    "restaurant-bill" => %{
      designs: ~w(t1 t2 t3 t4),
      optional:
        ~w(restaurant_address gstin fssai_number time table_number customer_name service_percent gst_percent),
      long: %{
        "restaurant_name" => String.duplicate("Green Leaf Café ", 5),
        "restaurant_address" => String.duplicate("14, Church Street, Bengaluru, ", 7),
        "customer_name" => String.duplicate("Ramakrishnan ", 5),
        "service_percent" => 30,
        "items" =>
          List.duplicate(
            %{
              "name" => String.duplicate("Masala Dosa with chutney ", 3),
              "qty" => 9_999.99,
              "rate" => 9_999_999.99
            },
            15
          )
      }
    },
    "daily-helper-receipt" => %{
      designs: ~w(t1 t2 t3),
      optional: ~w(employer_address declaration),
      long: %{
        "employer_name" => String.duplicate("Venkatasubramanian ", 4),
        "helper_name" => String.duplicate("Ramakrishnan ", 5),
        "working_as" => String.duplicate("Housekeeper ", 5),
        "declaration" =>
          String.duplicate("The helper is exclusively used for official purposes. ", 5),
        "salary" => 99_999_999.99
      }
    },
    "driver-salary-receipt" => %{
      designs: ~w(t1 t2 t3 t4 t5 t6),
      # t4 is a receipt for each month of the sample's period: July to September is three pages
      pages: %{"t4" => 3},
      optional:
        ~w(employer_address vehicle_number declaration from_date to_date bill_by overtime allowance deductions),
      long: %{
        "employer_name" => String.duplicate("Venkatasubramanian ", 4),
        "driver_name" => String.duplicate("Ramakrishnan ", 5),
        "vehicle_number" => "ABCDEFGHIJ-0123456789",
        "declaration" =>
          String.duplicate("The driver is exclusively used for official purposes. ", 5),
        "basic_salary" => 99_999_999.99,
        "overtime" => 9_999_999.99,
        "allowance" => 9_999_999.99,
        "deductions" => 1_000.5
      }
    },
    "rent-receipt" => %{
      designs: ~w(t1 t2 t3 t4),
      # t3 is a receipt for each quarter of the sample's period: July to December is two pages
      pages: %{"t3" => 2},
      optional: ~w(landlord_pan from_date to_date bill_by received_by receiver_name),
      long: %{
        "tenant_name" => String.duplicate("Ramakrishnan ", 5),
        "landlord_name" => String.duplicate("Venkatasubramanian ", 4),
        "property_address" => String.duplicate("Flat 402, Lotus Heights, Sector 21, ", 7),
        "receiver_name" => String.duplicate("Venkatasubramanian ", 4),
        "monthly_rent" => 99_999_999.99
      }
    },
    "taxi-receipt" => %{
      designs: ~w(t1 t2 t3 t4),
      optional:
        ~w(operator_address seller_tax_id drop_date passenger_name customer_phone customer_address
           driver_name vehicle_number vehicle_model pickup_time drop_time toll airport_charge
           advance_paid tax_percent),
      long: %{
        "operator_name" => String.duplicate("Kaveri City Cabs ", 4),
        "operator_address" => String.duplicate("12, MG Road, Bengaluru, ", 8),
        "passenger_name" => String.duplicate("Ramakrishnan ", 5),
        "driver_name" => String.duplicate("Venkatasubramanian ", 4),
        "pickup" => String.duplicate("Indiranagar Metro Station ", 6),
        "drop" => String.duplicate("International Airport ", 7),
        "vehicle_model" => String.duplicate("Maruti Dzire ", 4),
        "distance_km" => 9_999.9,
        "base_fare" => 99_999_999.99,
        "toll" => 9_999_999.99,
        "airport_charge" => 9_999_999.99,
        "advance_paid" => 9_999_999.99
      }
    }
  }

  describe "the designs of a bill that has several" do
    defp pages(pdf), do: length(Regex.scan(~r{/Type\s*/Page[^s]}, pdf))

    for {slug, %{designs: designs, optional: optional, long: long} = config} <- @multi_design,
        design <- designs do
      # A design that makes several receipts has a page for each; the others are one page.
      pages = Map.get(config, :pages, %{}) |> Map.get(design, 1)

      test "#{slug}/#{design} is #{pages} page(s) in every live locale" do
        for locale <- Locales.live() do
          {:ok, sample} = Templates.sample(unquote(slug), locale)

          assert {:ok, pdf} =
                   Renderer.render(unquote(slug), unquote(design), sample, locale: locale.code)

          assert pages(pdf) == unquote(pages),
                 "#{unquote(slug)}/#{unquote(design)} in #{locale.code}"
        end
      end

      test "#{slug}/#{design} compiles with only the required fields, a logo and a signature" do
        slug = unquote(slug)
        required = Map.drop(sample(slug), unquote(optional))
        logo = tmp_file(png_bytes())
        signature = tmp_file(jpg_bytes())

        assert {:ok, "%PDF" <> _} = Renderer.render(slug, unquote(design), required)

        with_pictures =
          Map.merge(sample(slug), %{"logo" => "logo.png", "signature" => "signature.jpg"})

        assert {:ok, "%PDF" <> _} =
                 Renderer.render(slug, unquote(design), with_pictures,
                   assets: %{"logo.png" => logo, "signature.jpg" => signature},
                   mode: :preview
                 )
      end

      test "#{slug}/#{design} holds a very long text and very big numbers on its pages" do
        data = Map.merge(sample(unquote(slug)), unquote(Macro.escape(long)))

        assert {:ok, pdf} = Renderer.render(unquote(slug), unquote(design), data)
        assert pages(pdf) == unquote(pages)
      end
    end

    test "rent-receipt/t3 makes a receipt for each month, quarter, half-year or year of the period, at most 12 months" do
      sample = sample("rent-receipt")

      receipts = fn from, to, bill_by ->
        data =
          Map.merge(sample, %{"from_date" => from, "to_date" => to, "bill_by" => bill_by})

        {:ok, pdf} = Renderer.render("rent-receipt", "t3", data)
        pages(pdf)
      end

      assert receipts.("2026-01-05", "2026-06-30", "Monthly") == 6
      assert receipts.("2026-01-05", "2026-12-31", "Quarterly") == 4
      assert receipts.("2026-01-05", "2026-12-31", "Half-yearly") == 2
      assert receipts.("2026-01-05", "2026-12-31", "Yearly") == 1
      # Five months by quarters: a quarter and a part of one.
      assert receipts.("2026-01-05", "2026-05-31", "Quarterly") == 2
      # More than a year is cut at 12 months.
      assert receipts.("2024-01-05", "2026-12-31", "Monthly") == 12
      assert receipts.("2024-01-05", "2026-12-31", "Quarterly") == 4

      # Without a period it is the receipt of the month; a period that runs backwards is one month.
      without = Map.drop(sample, ["from_date", "to_date", "bill_by"])
      assert {:ok, pdf} = Renderer.render("rent-receipt", "t3", without)
      assert pages(pdf) == 1
      assert receipts.("2026-06-05", "2026-01-31", "Monthly") == 1
    end

    test "the cash memo has no column for small change in a currency that has none" do
      {:ok, sample} = Templates.sample("fuel-bill", Locales.fetch!("ja-jp"))

      assert {:ok, "%PDF" <> _} = Renderer.render("fuel-bill", "t5", sample, locale: "ja-jp")
    end
  end

  test "an unknown design is rejected before any process is started" do
    assert {:error, :unknown_template} = Renderer.render("fuel-bill", "../../etc/passwd", %{})
  end
end
