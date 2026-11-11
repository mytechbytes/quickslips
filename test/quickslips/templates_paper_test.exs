defmodule QuickSlips.TemplatesPaperTest do
  use ExUnit.Case, async: true

  alias QuickSlips.Templates

  # The choice of a sheet: what it adds to the data of a document, and when it adds nothing.

  setup do
    {:ok, fuel} = Templates.get("fuel-bill")
    %{fuel: fuel}
  end

  test "offers A4, A5 and US Letter" do
    assert Templates.papers() == ["a4", "a5", "us-letter"]
  end

  test "adds the sheet for a design that is not a roll", %{fuel: fuel} do
    for paper <- Templates.papers() do
      assert Templates.paper_data(fuel, "t1", paper) == %{"paper_size" => paper}
    end
  end

  test "adds nothing for a design made for a thermal roll", %{fuel: fuel} do
    assert Templates.paper_data(fuel, "t2", "a4") == %{}
  end

  test "adds nothing for no choice, for a sheet that is not offered, or for a design that does not exist",
       %{fuel: fuel} do
    assert Templates.paper_data(fuel, "t1", "") == %{}
    assert Templates.paper_data(fuel, "t1", nil) == %{}
    assert Templates.paper_data(fuel, "t1", "a0") == %{}
    assert Templates.paper_data(fuel, "t1", "../../etc/passwd") == %{}
    assert Templates.paper_data(fuel, "nope", "a4") == %{}
  end
end
