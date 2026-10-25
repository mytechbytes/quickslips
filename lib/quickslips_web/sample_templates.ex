defmodule QuickSlipsWeb.SampleTemplates do
  @moduledoc """
  TEMPORARY. The fifteen templates of the design, in the same shape as a `schema.json` map
  (string keys), so the home page can be built before the real catalogue exists.

  Task 4.4 swaps this module for `QuickSlips.Templates` and deletes it.
  """

  @templates [
    %{
      "slug" => "fuel-bill",
      "title" => "Fuel bill",
      "icon" => "hero-fire",
      "category" => "Travel",
      "summary" => "Petrol, diesel or CNG fill-up"
    },
    %{
      "slug" => "rent-receipt",
      "title" => "Rent receipt",
      "icon" => "hero-home",
      "category" => "Home & utilities",
      "summary" => "Rent paid to a landlord"
    },
    %{
      "slug" => "medical-bill",
      "title" => "Medical bill",
      "icon" => "hero-heart",
      "category" => "Health & learning",
      "summary" => "Clinic, pharmacy or lab charges"
    },
    %{
      "slug" => "restaurant-bill",
      "title" => "Restaurant bill",
      "icon" => "hero-cake",
      "category" => "Food & shopping",
      "summary" => "Dine-in or takeaway"
    },
    %{
      "slug" => "taxi-receipt",
      "title" => "Taxi receipt",
      "icon" => "hero-map-pin",
      "category" => "Travel",
      "summary" => "Cab or auto trip fare"
    },
    %{
      "slug" => "hotel-invoice",
      "title" => "Hotel invoice",
      "icon" => "hero-building-office-2",
      "category" => "Travel",
      "summary" => "Room stay and tariff"
    },
    %{
      "slug" => "grocery-bill",
      "title" => "Grocery bill",
      "icon" => "hero-shopping-cart",
      "category" => "Food & shopping",
      "summary" => "Items, quantities and totals"
    },
    %{
      "slug" => "internet-bill",
      "title" => "Internet bill",
      "icon" => "hero-wifi",
      "category" => "Home & utilities",
      "summary" => "Broadband or fibre plan"
    },
    %{
      "slug" => "driver-salary-receipt",
      "title" => "Driver salary receipt",
      "icon" => "hero-identification",
      "category" => "Work",
      "summary" => "Monthly pay for a driver"
    },
    %{
      "slug" => "service-invoice",
      "title" => "Service invoice",
      "icon" => "hero-wrench-screwdriver",
      "category" => "Work",
      "summary" => "Charges for work or a service"
    },
    %{
      "slug" => "mobile-bill",
      "title" => "Mobile bill",
      "icon" => "hero-device-phone-mobile",
      "category" => "Home & utilities",
      "summary" => "Prepaid recharge or postpaid plan"
    },
    %{
      "slug" => "electricity-bill",
      "title" => "Electricity bill",
      "icon" => "hero-bolt",
      "category" => "Home & utilities",
      "summary" => "Units used and charges"
    },
    %{
      "slug" => "school-fee-receipt",
      "title" => "School fee receipt",
      "icon" => "hero-academic-cap",
      "category" => "Health & learning",
      "summary" => "Tuition or term fee"
    },
    %{
      "slug" => "gym-membership-receipt",
      "title" => "Gym membership receipt",
      "icon" => "hero-trophy",
      "category" => "Health & learning",
      "summary" => "Membership or monthly fee"
    },
    %{
      "slug" => "courier-receipt",
      "title" => "Courier receipt",
      "icon" => "hero-truck",
      "category" => "Travel",
      "summary" => "Parcel booking and delivery charge"
    }
  ]

  def list, do: @templates

  @doc "The categories in the order they first appear."
  def categories, do: @templates |> Enum.map(& &1["category"]) |> Enum.uniq()
end
