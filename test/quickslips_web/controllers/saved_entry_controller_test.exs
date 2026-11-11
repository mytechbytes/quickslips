defmodule QuickSlipsWeb.SavedEntryControllerTest do
  use QuickSlipsWeb.ConnCase

  alias QuickSlips.SavedEntries

  @slug "driver-salary-receipt"
  @employee %{
    "employer_name" => "Anil Kapoor",
    "employee_code" => "EMP-7",
    "employer_address" => "Delhi",
    "driver_name" => "ignored: not in this section"
  }

  defp save(conn, group, data, id \\ nil),
    do: post(conn, ~p"/api/saved-entries", %{slug: @slug, group: group, data: data, id: id})

  test "a visitor is told to log in", %{conn: conn} do
    assert %{"error" => "log in first"} = json_response(save(conn, "business", @employee), 401)
  end

  describe "when logged in" do
    setup :register_and_log_in_user

    test "saves the whole section under the name of its first required field", %{
      conn: conn,
      scope: scope
    } do
      conn = save(conn, "business", @employee)

      assert %{"outcome" => "created", "entry" => %{"name" => "Anil Kapoor", "data" => data}} =
               json_response(conn, 200)

      assert data == Map.delete(@employee, "driver_name")
      assert %{"business" => [%{name: "Anil Kapoor"}]} = SavedEntries.list_entries(scope, @slug)
    end

    test "Update, with the id of an entry, changes that entry and may rename it", %{
      conn: conn,
      scope: scope
    } do
      %{"entry" => %{"id" => id}} = json_response(save(conn, "business", @employee), 200)

      conn =
        save(
          conn,
          "business",
          %{@employee | "employer_name" => "A. Kapoor", "employee_code" => "EMP-8"},
          id
        )

      assert %{"outcome" => "updated", "entry" => %{"id" => ^id, "name" => "A. Kapoor"}} =
               json_response(conn, 200)

      assert %{"business" => [%{data: %{"employee_code" => "EMP-8"}}]} =
               SavedEntries.list_entries(scope, @slug)
    end

    test "Create new makes another entry, but not with a name that is saved, whatever the capitals",
         %{conn: conn, scope: scope} do
      save(conn, "business", @employee)
      conn = save(conn, "business", %{@employee | "employer_name" => "ANIL KAPOOR"})
      assert %{"code" => "name_taken"} = json_response(conn, 422)

      conn = save(conn, "business", %{@employee | "employer_name" => "Sunita Rao"})
      assert %{"outcome" => "created"} = json_response(conn, 200)
      assert %{"business" => [_, _]} = SavedEntries.list_entries(scope, @slug)
    end

    test "Update cannot take the name of another entry, nor change somebody else's", %{conn: conn} do
      save(conn, "business", @employee)

      %{"entry" => %{"id" => id}} =
        json_response(save(conn, "business", %{@employee | "employer_name" => "Other"}), 200)

      assert %{"code" => "name_taken"} = json_response(save(conn, "business", @employee, id), 422)

      assert %{"code" => "not_found"} =
               json_response(save(conn, "business", @employee, id + 1000), 422)
    end

    test "the vehicle is a section too, named by its number although the number is optional", %{
      conn: conn,
      scope: scope
    } do
      conn = save(conn, "details", %{"vehicle_number" => "DL 3C AB 1234"})

      assert %{"entry" => %{"name" => "DL 3C AB 1234"}} = json_response(conn, 200)
      assert %{"details" => [_]} = SavedEntries.list_entries(scope, @slug)
    end

    test "the drivers are kept apart from the employees", %{conn: conn, scope: scope} do
      save(conn, "business", @employee)
      save(conn, "customer", %{"driver_name" => "Ravi Kumar"})

      assert %{"business" => [_], "customer" => [%{name: "Ravi Kumar"}]} =
               SavedEntries.list_entries(scope, @slug)
    end

    test "a section that may not be saved, an unknown bill and a blank name are turned down", %{
      conn: conn
    } do
      assert %{"code" => "not_saved"} =
               json_response(save(conn, "charges", %{"basic_salary" => "1"}), 422)

      assert %{"code" => "not_saved"} =
               json_response(
                 post(conn, ~p"/api/saved-entries", %{slug: "nope", group: "business", data: %{}}),
                 422
               )

      assert %{"code" => "name_blank"} =
               json_response(save(conn, "business", %{"employer_name" => "  "}), 422)
    end

    test "stops at the limit", %{conn: conn} do
      for n <- 1..SavedEntries.max_per_key(),
          do: save(conn, "customer", %{"driver_name" => "Driver #{n}"})

      assert %{"code" => "limit_reached"} =
               json_response(save(conn, "customer", %{"driver_name" => "One more"}), 422)
    end
  end
end
