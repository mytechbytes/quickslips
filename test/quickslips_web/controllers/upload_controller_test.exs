defmodule QuickSlipsWeb.UploadControllerTest do
  use QuickSlipsWeb.ConnCase

  import QuickSlips.AccountsFixtures
  import QuickSlips.UploadsFixtures

  alias QuickSlipsWeb.UploadController

  describe "path/1" do
    test "turns a stored path into the URL of two segments" do
      assert UploadController.path("12/a1b2c3d4e5f60718.png") ==
               "/uploads/12/a1b2c3d4e5f60718.png"

      assert UploadController.path(nil) == nil
    end
  end

  describe "show" do
    setup :register_and_log_in_user

    test "gives the owner the picture", %{conn: conn, user: user} do
      relative = stored_image(user.id)

      conn = get(conn, UploadController.path(relative))

      assert response(conn, 200) == png_bytes()
      assert ["image/png"] = get_resp_header(conn, "content-type")
      assert ["private, max-age=86400"] = get_resp_header(conn, "cache-control")
    end

    test "tells a JPEG by its extension", %{conn: conn, user: user} do
      relative = stored_image(user.id, jpg_bytes())

      conn = get(conn, UploadController.path(relative))

      assert ["image/jpeg"] = get_resp_header(conn, "content-type")
    end

    test "is a 404 for somebody else's picture", %{conn: conn} do
      other = user_fixture()
      relative = stored_image(other.id)

      assert_error_sent 404, fn -> get(conn, UploadController.path(relative)) end
    end

    test "is a 404 for a name we never made, even in the user's own folder", %{
      conn: conn,
      user: user
    } do
      stored_image(user.id)

      File.write!(
        Path.join([QuickSlips.Uploads.root(), Integer.to_string(user.id), "notes.txt"]),
        "secret"
      )

      assert_error_sent 404, fn -> get(conn, ~p"/uploads/#{user.id}/notes.txt") end
      assert_error_sent 404, fn -> get(conn, ~p"/uploads/#{user.id}/0000000000000000.png") end
    end
  end

  test "visitors are sent to the log-in page", %{conn: conn} do
    conn = get(conn, ~p"/uploads/1/a1b2c3d4e5f60718.png")
    assert redirected_to(conn) == ~p"/users/log-in"
  end
end
