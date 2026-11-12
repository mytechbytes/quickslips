defmodule QuickSlips.Render.RendererTest do
  use ExUnit.Case, async: true

  import QuickSlips.UploadsFixtures

  alias QuickSlips.Locales
  alias QuickSlips.Render.Renderer
  alias QuickSlips.Templates
  alias QuickSlips.Templates.Validator

  # Needs the typst binary. Run `mix test --exclude typst` on a machine without it.
  @moduletag :typst

  defp sample(slug),
    do: "priv/bill_templates/#{slug}/sample.json" |> File.read!() |> Jason.decode!()

  defp media_box(pdf),
    do:
      Regex.run(~r|/MediaBox\[0 0 ([\d.]+) ([\d.]+)\]|, pdf, capture: :all_but_first)
      |> Enum.map(&(&1 |> Float.parse() |> elem(0)))

  describe "the sheet" do
    test "is the layout's own, unless one is chosen" do
      # the gym receipt is made for an A5 sheet
      gym = sample("gym-membership-receipt")
      {:ok, own} = Renderer.render("gym-membership-receipt", "t1", gym)

      {:ok, a4} =
        Renderer.render("gym-membership-receipt", "t1", Map.put(gym, "paper_size", "a4"))

      {:ok, letter} =
        Renderer.render("gym-membership-receipt", "t1", Map.put(gym, "paper_size", "us-letter"))

      # A5, A4 and US Letter, in points
      assert [420.0, 595.0] = media_box(own) |> Enum.map(&Float.round(&1))
      assert [595.0, 842.0] = media_box(a4) |> Enum.map(&Float.round(&1))
      assert [612.0, 792.0] = media_box(letter) |> Enum.map(&Float.round(&1))
    end

    test "puts a slip at the top of the chosen sheet, at its own width" do
      {:ok, slip} = Renderer.render("fuel-bill", "t1", sample("fuel-bill"))

      {:ok, a4} =
        Renderer.render("fuel-bill", "t1", Map.put(sample("fuel-bill"), "paper_size", "a4"))

      [slip_width, _] = media_box(slip)
      assert slip_width < 595
      assert [595.0, 842.0] = media_box(a4) |> Enum.map(&Float.round(&1))
    end

    test "is not changed for a roll receipt, which keeps its width" do
      {:ok, roll} = Renderer.render("fuel-bill", "t2", sample("fuel-bill"))

      {:ok, chosen} =
        Renderer.render("fuel-bill", "t2", Map.put(sample("fuel-bill"), "paper_size", "a4"))

      assert media_box(roll) |> Enum.at(0) == media_box(chosen) |> Enum.at(0)
      assert media_box(chosen) |> Enum.at(0) < 200
    end
  end

  test "can draw the first page as a picture" do
    assert {:ok, <<0x89, "PNG", _::binary>> = png} =
             Renderer.render("rent-receipt", "t1", sample("rent-receipt"), format: :png, ppi: 40)

    assert byte_size(png) > 1_000
  end

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

          %{"type" => "periods"} ->
            sample[field["key"]]

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
    "electronics-bill" => %{
      designs: ~w(t1),
      optional:
        ~w(branch seller_address seller_state seller_phone seller_email seller_tax_id seller_pan cin copy_label
           place_of_supply supply reverse_charge do_number financier bill_care_of bill_address bill_state bill_pin
           bill_phone bill_tax_id ship_code ship_auth_code ship_address ship_state ship_phone ship_tax_id
           payment_reference payment_date amount_paid remarks bank_details bank_account bank_ifsc customer_care
           delivery_helpline signatory_for thank_you),
      long: %{
        "company_name" => String.duplicate("Vision Electronics Retail ", 4),
        "seller_address" => String.duplicate("Shop 3, Corporate Park, Andheri East, ", 6),
        "bill_name" => String.duplicate("Ramakrishnan ", 5),
        "bill_address" => String.duplicate("Flat 12, Sunrise Apartments, Station Road, ", 6),
        "ship_address" => String.duplicate("Warehouse 9, Logistics Park, Bhiwandi, ", 6),
        "remarks" => String.duplicate("Keep this invoice for the warranty. ", 8),
        "amount_paid" => 99_999_999.99,
        "items" =>
          List.duplicate(
            %{
              "name" => String.duplicate("Smartphone 128 GB midnight black ", 3),
              "code" => "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123",
              "hsn" => "ABCDEFGHIJ01",
              "qty" => 9_999.99,
              "rate" => 9_999_999.99,
              "tax" => 18
            },
            14
          )
      }
    },
    "newspaper-bill" => %{
      designs: ~w(t1),
      optional: ~w(agency_mobile agency_phone name_prefix service_charge),
      long: %{
        "agency_name" => String.duplicate("Quick City News Agency ", 4),
        "agency_address" => String.duplicate("Shop 2, Market Road, Nashik, ", 7),
        "customer_name" => String.duplicate("Ramakrishnan ", 5),
        "service_charge" => 99_999_999.99,
        "items" =>
          List.duplicate(
            %{
              "name" => String.duplicate("Morning Chronicle daily edition ", 3),
              "rate" => 9_999_999.99,
              "qty" => 9_999.99
            },
            12
          )
      }
    },
    "lta-bill" => %{
      designs: ~w(t1 t2),
      optional:
        ~w(seller_tax_id pnr_number departure_time dropping_time tax_percent cancellation_charge),
      long: %{
        "travel_name" => String.duplicate("Evergreen Travels ", 4),
        "location" => String.duplicate("Madiwala Bus Stop, Bengaluru, ", 6),
        "landmark" => String.duplicate("Opposite the Metro station, ", 6),
        "boarding_address" => String.duplicate("Hosur Road, Madiwala, Bengaluru, ", 6),
        "dropping_address" => String.duplicate("Jubilee Bus Station, Secunderabad, ", 6),
        "passenger_details" => String.duplicate("Rohan Mehta, 34, Male; ", 6),
        "amount" => 99_999_999.99,
        "cancellation_charge" => 99_999_999.99
      }
    },
    "hotel-invoice" => %{
      designs: ~w(t1 t2 t3),
      optional:
        ~w(hotel_address gstin registration_number reservation_number guest_gender guest_age nationality guest_address room_description room_number check_in_time check_out_time extra_charges gst_percent advance_amount),
      long: %{
        "hotel_name" => String.duplicate("Lotus Residency ", 2),
        "hotel_address" => String.duplicate("4, Beach Road, Candolim, Goa ", 2),
        "guest_name" => String.duplicate("Ramakrishnan ", 2),
        "guest_address" => String.duplicate("22, Hill Road, Bandra West, Mumbai ", 2),
        "room_description" => String.duplicate("Sea-facing room with breakfast ", 2),
        "tariff_per_night" => 99_999_999.99,
        "advance_amount" => 99_999_999.99,
        "items" =>
          List.duplicate(
            %{
              "name" => String.duplicate("Extra bed with linen and breakfast ", 2),
              "rate" => 9_999_999.99,
              "qty" => 9_999.99
            },
            3
          )
      }
    },
    "gym-membership-receipt" => %{
      designs: ~w(t1 t2),
      optional:
        ~w(gym_address gym_email gym_phone gstin member_phone customer_number user_number member_address billing_cycle joining_fee gst_percent remarks instructions),
      long: %{
        "gym_name" => "IronWorks Fitness",
        "gym_address" => "2nd Floor, City Mall, Noida",
        "member_name" => "Vikram Rao",
        "member_address" => String.duplicate("B-14, Sector 62, Noida, ", 2),
        "remarks" => String.duplicate("Freeze requests need 7 days notice. ", 2),
        "instructions" => String.duplicate("Warm-up: start with a 5-10 minute warm-up. \n", 2),
        "fee" => 99_999_999.99,
        "items" =>
          List.duplicate(
            %{
              "name" => "Personal training",
              "qty" => 9_999.99,
              "rate" => 9_999_999.99
            },
            2
          )
      }
    },
    "general-bill" => %{
      designs: ~w(t1),
      optional: ~w(seller_tax_id order_number),
      long: %{
        "shop_name" => String.duplicate("Sharma General Store ", 4),
        "shop_address" => String.duplicate("12, Gandhi Road, Jaipur, ", 7),
        "customer_name" => String.duplicate("Ramakrishnan ", 5),
        "shipping_address" => String.duplicate("Flat 5, Lotus Apartments, C-Scheme, ", 6),
        "items" =>
          List.duplicate(
            %{
              "name" => String.duplicate("Steel kitchen container set ", 3),
              "qty" => 9_999.99,
              "rate" => 9_999_999.99,
              "tax" => 18
            },
            12
          )
      }
    },
    "donation-receipt" => %{
      designs: ~w(t1),
      optional: ~w(registration_number email website phone received_by donation_description),
      long: %{
        "organisation_name" => String.duplicate("The Discovery and Restoration Trust ", 3),
        "address" => String.duplicate("21, Heritage Lane, Pune, ", 7),
        "donor_name" => String.duplicate("Ramakrishnan ", 5),
        "donation_description" =>
          String.duplicate("Donation towards the restoration of the heritage library. ", 5),
        "received_by" => String.duplicate("Meera Iyer, Treasurer ", 3),
        "amount" => 99_999_999.99
      }
    },
    "laundry-bill" => %{
      designs: ~w(t1 t2),
      optional: ~w(laundry_address customer_address terms),
      long: %{
        "laundry_name" => String.duplicate("Sparkle Dry Cleaning ", 4),
        "laundry_address" => String.duplicate("Shop 9, Station Road, Thane, ", 6),
        "customer_name" => String.duplicate("Ramakrishnan ", 5),
        "customer_address" => String.duplicate("Flat 12, Sunrise Apartments, Station Road, ", 6),
        "terms" => String.duplicate("All garments are handled with the greatest care.\n", 12),
        "items" =>
          List.duplicate(
            %{
              "name" => String.duplicate("Trousers dry clean with pressing ", 3),
              "qty" => 9_999.99,
              "rate" => 9_999_999.99
            },
            12
          )
      }
    },
    "school-fee-receipt" => %{
      designs: ~w(t1 t2),
      optional:
        ~w(school_address school_phone admission_number parent_name transport_fee other_fee),
      long: %{
        "school_name" => String.duplicate("Sunrise Public School ", 2),
        "school_address" => String.duplicate("Sector 14, Chandigarh, ", 2),
        "student_name" => String.duplicate("Aarav Gupta ", 2),
        "parent_name" => String.duplicate("Neha Gupta ", 2),
        "fee_period" => String.duplicate("Term 2, 2026-27 ", 2),
        "amount_in_words" => String.duplicate("Twelve thousand five hundred rupees only ", 2),
        "tuition_fee" => 99_999_999.99
      }
    },
    "child-education-allowance-bill" => %{
      designs: ~w(t1),
      optional: ~w(child2_name child2_dob child2_standard child2_school),
      long: %{
        "name_rank" => String.duplicate("Major Arvind Kumar ", 5),
        "designation" => String.duplicate("Staff Officer ", 6),
        "unit" => String.duplicate("Headquarters, 21 Corps, Pune ", 4),
        "spouse_employed" => String.duplicate("Employed with a private organisation ", 3),
        "spouse_office" => String.duplicate("Senior manager, head office ", 5),
        "child1_school" => String.duplicate("Sunrise Public School, Pune ", 5),
        "child2_school" => String.duplicate("Sunrise Public School, Pune ", 5)
      }
    },
    "cash-voucher" => %{
      designs: ~w(t1),
      optional: ~w(resident_certificate received_date place),
      long: %{
        "paid_to" => String.duplicate("Ramesh Kulkarni ", 5),
        "address" => String.duplicate("14, Shivaji Nagar, Pune, ", 7),
        "prepared_by" => String.duplicate("S. Joshi ", 6),
        "checked_by" => String.duplicate("M. Iyer ", 6),
        "approved_by" => String.duplicate("A. Deshmukh ", 6),
        "place" => String.duplicate("Pune ", 10),
        "items" =>
          List.duplicate(
            %{
              "name" =>
                String.duplicate("Stationery purchase for the office, long description ", 3),
              "rate" => 9_999_999.99
            },
            14
          )
      }
    },
    "recharge-bill" => %{
      designs: ~w(t1),
      optional:
        ~w(provider_address seller_tax_id time customer_address landmark alternative_number email email_banner
           offer_title offer_text pay_options previous_balance adjustment tax_percent amount_after_due),
      long: %{
        "provider_name" => String.duplicate("Zing Mobile ", 6),
        "provider_address" => String.duplicate("Tower B, Tech Park, Andheri East, ", 6),
        "customer_name" => String.duplicate("Ramakrishnan ", 5),
        "customer_address" => String.duplicate("Flat 12, Sunrise Apartments, Station Road, ", 6),
        "email_banner" => String.duplicate("To get your monthly bill on email ", 4),
        "offer_title" => String.duplicate("Get 10 GB ", 4),
        "offer_text" => String.duplicate("Broadband data with every connection ", 2),
        "pay_options" => String.duplicate("Pay using the official website\n", 8),
        "amount" => 99_999_999.99,
        "previous_balance" => 99_999_999.99
      }
    },
    "internet-bill" => %{
      designs: ~w(t1 t2 t3 t4),
      optional:
        ~w(provider_address provider_email registered_office gstin due_date customer_address user_name plan_speed
           plan_package plan_validity service_description other_charges discount gst_percent payments_received
           payment_mode terms),
      long: %{
        "provider_name" => String.duplicate("Skyline Broadband ", 4),
        "provider_address" => String.duplicate("Plot 18, Hi-Tech City, Hyderabad, ", 6),
        "registered_office" => String.duplicate("Skyline Broadband Pvt. Ltd., Plot 18, ", 8),
        "customer_name" => String.duplicate("Ramakrishnan ", 5),
        "customer_address" => String.duplicate("Flat 9B, Green Heights, Kondapur, ", 6),
        "plan_name" => String.duplicate("Fibre 200 Mbps unlimited ", 3),
        "service_description" => String.duplicate("Fibre broadband subscription ", 3),
        "plan_charge" => 99_999_999.99,
        "terms" =>
          String.duplicate(
            "A late fee will be charged if the bill is paid after the due date.\n",
            12
          )
      }
    },
    "stationery-bill" => %{
      designs: ~w(t1),
      optional: ~w(seller_tax_id tax_percent remarks),
      long: %{
        "shop_name" => String.duplicate("Quill & Co. Stationers ", 4),
        "shop_address" => String.duplicate("Shop 6, College Road, Pune, ", 7),
        "customer_name" => String.duplicate("Ramakrishnan ", 5),
        "customer_address" => String.duplicate("Flat 12, Sunrise Apartments, Station Road, ", 6),
        "remarks" => String.duplicate("Please keep the receipt for exchanges. ", 5),
        "tax_percent" => 18,
        "items" =>
          List.duplicate(
            %{
              "name" => String.duplicate("Spiral notebook 200 pages ", 4),
              "qty" => 9_999.99,
              "rate" => 9_999_999.99
            },
            16
          )
      }
    },
    "ecommerce-bill" => %{
      designs: ~w(t1 t2 t3 t4),
      optional:
        ~w(seller_address seller_phone platform_name platform_website seller_tax_id order_number order_date
           customer_phone billing_address shipping_charge signatory_name return_policy),
      long: %{
        "seller_name" => String.duplicate("Bright Cart Retail ", 4),
        "seller_address" => String.duplicate("Unit 5, Logistics Park, Bhiwandi, ", 6),
        "platform_name" => String.duplicate("BrightCart ", 6),
        "customer_name" => String.duplicate("Ramakrishnan ", 5),
        "shipping_address" => String.duplicate("Flat 12, Sunrise Apartments, Station Road, ", 6),
        "billing_address" => String.duplicate("Office 3, Business Bay, Andheri East, ", 6),
        "shipping_charge" => 99_999_999.99,
        "return_policy" =>
          String.duplicate("We strive to deliver perfectly on every order. ", 12),
        "items" =>
          List.duplicate(
            %{
              "name" => String.duplicate("Wireless earbuds with charging case ", 3),
              "qty" => 9_999.99,
              "rate" => 9_999_999.99,
              "tax" => 18
            },
            16
          )
      }
    },
    "book-receipt" => %{
      designs: ~w(t1 t2),
      optional: ~w(store_address author description),
      long: %{
        "store_name" => String.duplicate("Page & Leaf Books ", 4),
        "store_address" => String.duplicate("Shop 4, Station Road, Pune, ", 6),
        "customer_name" => String.duplicate("Ramakrishnan ", 5),
        "book_name" => String.duplicate("The Guide to Everything ", 4),
        "author" => String.duplicate("R. K. Narayan ", 5),
        "publisher" => String.duplicate("Sunrise Press ", 6),
        "description" => String.duplicate("Paperback, 2nd edition, illustrated. ", 5),
        "quantity" => 9_999_999,
        "book_price" => 99_999_999.99
      }
    },
    "hypermarket-bill" => %{
      designs: ~w(t1),
      optional:
        ~w(company_address phone email website cin seller_tax_id fssai order_number order_date delivery_date
           delivery_time customer_name customer_phone delivery_address savings payment_note),
      long: %{
        "brand_name" => String.duplicate("FreshMart Ready ", 4),
        "company_name" => String.duplicate("FreshMart Retail Private Limited ", 3),
        "company_address" => String.duplicate("Building 2, Corporate Park, Andheri East, ", 5),
        "website" => String.duplicate("www.freshmart.example/terms/", 4),
        "delivery_time" => String.duplicate("6:00 PM - 9:00 PM ", 2),
        "customer_name" => String.duplicate("Ramakrishnan ", 5),
        "delivery_address" => String.duplicate("Flat 12, Sunrise Apartments, Station Road, ", 5),
        "payment_note" => String.duplicate("Pay on delivery ", 3),
        "savings" => 99_999_999.99,
        "items" =>
          List.duplicate(
            %{
              "name" => String.duplicate("Basmati rice premium pack ", 3),
              "hsn" => "ABCDEFGHIJ01",
              "qty" => 9_999.99,
              "rate" => 9_999_999.99,
              "tax" => 18
            },
            16
          )
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
      designs: ~w(t1 t2 t3 t5 t6),
      optional:
        ~w(employer_address employee_code vehicle_number declaration overtime allowance deductions),
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
      designs: ~w(t1 t2 t4),
      optional: ~w(landlord_pan received_by receiver_name),
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

  describe "the driver salary receipt for several months" do
    @tag :typst
    test "is a page for each period chosen, in every design" do
      sample = sample("driver-salary-receipt")
      months = ["2026-01", "2026-02", "2026-03"]

      for design <- ~w(t1 t2 t3 t5 t6) do
        many =
          Map.put(sample, "periods", %{
            "bill_by" => "Monthly",
            "months" => months,
            "dates" => ["", "", ""]
          })

        assert {:ok, pdf} = Renderer.render("driver-salary-receipt", design, many)
        assert length(Regex.scan(~r{/Type\s*/Page[^s]}, pdf)) == 3, design

        quarter =
          Map.put(sample, "periods", %{
            "bill_by" => "Quarterly",
            "months" => ["2026-04"],
            "dates" => [""]
          })

        assert {:ok, pdf} = Renderer.render("driver-salary-receipt", design, quarter)
        assert length(Regex.scan(~r{/Type\s*/Page[^s]}, pdf)) == 1, design

        two_quarters =
          Map.put(sample, "periods", %{
            "bill_by" => "Quarterly",
            "months" => ["2026-04", "2026-07"],
            "dates" => ["2026-06-30", ""]
          })

        assert {:ok, pdf} = Renderer.render("driver-salary-receipt", design, two_quarters)
        assert length(Regex.scan(~r{/Type\s*/Page[^s]}, pdf)) == 2, design
      end
    end
  end

  describe "the driver salary receipt on a sheet of the user's choice" do
    @tag :typst
    test "is a page for each period in every design, on every paper and with every margin" do
      sample = sample("driver-salary-receipt")

      many =
        Map.put(sample, "periods", %{
          "bill_by" => "Monthly",
          "months" => ["2026-01", "2026-02"],
          "dates" => ["", ""]
        })

      for design <- ~w(t1 t2 t3 t5 t6),
          paper <- ["a4", "a5", "us-letter"],
          margin <- ["" | Templates.margins()] do
        data = Map.merge(many, %{"paper_size" => paper, "margin_size" => margin})
        assert {:ok, pdf} = Renderer.render("driver-salary-receipt", design, data)
        assert length(Regex.scan(~r{/Type\s*/Page[^s]}, pdf)) >= 2, "#{design} #{paper} #{margin}"
      end
    end
  end

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

    test "the rent receipt and the daily helper receipt make a page for each period chosen" do
      for {slug, designs} <- [
            {"rent-receipt", ~w(t1 t2 t4)},
            {"daily-helper-receipt", ~w(t1 t2 t3)}
          ],
          design <- designs do
        sample = sample(slug)

        months = fn count, by ->
          starts = Enum.take(["2026-01", "2026-04", "2026-07", "2026-10"], count)

          Map.put(sample, "periods", %{
            "bill_by" => by,
            "months" => starts,
            "dates" => List.duplicate("", count)
          })
        end

        {:ok, pdf} = Renderer.render(slug, design, months.(1, "Monthly"))
        assert pages(pdf) == 1, "#{slug}/#{design}"

        {:ok, pdf} = Renderer.render(slug, design, months.(4, "Quarterly"))
        assert pages(pdf) == 4, "#{slug}/#{design}"
      end
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
