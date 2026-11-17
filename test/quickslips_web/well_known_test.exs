defmodule QuickSlipsWeb.WellKnownTest do
  use QuickSlipsWeb.ConnCase, async: true

  # What other services fetch from the site to check something about it. Azure asks for this file when the domain is
  # confirmed as the publisher of the app that is registered for "Continue with Microsoft" (see the README).
  describe "/.well-known/microsoft-identity-association.json" do
    test "is the file itself, as JSON, with the id of the app registered with Microsoft", %{
      conn: conn
    } do
      conn = get(conn, "/.well-known/microsoft-identity-association.json")

      # Azure needs the file at that address, not a redirect to a language or to another one
      assert conn.status == 200
      assert ["application/json" <> _] = get_resp_header(conn, "content-type")

      assert %{"associatedApplications" => [%{"applicationId" => id}]} =
               Jason.decode!(response(conn, 200))

      assert id =~ ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
    end
  end
end
