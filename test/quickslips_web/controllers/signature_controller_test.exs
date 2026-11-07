defmodule QuickSlipsWeb.SignatureControllerTest do
  use QuickSlipsWeb.ConnCase

  import QuickSlips.SignaturesFixtures
  import QuickSlips.UploadsFixtures

  alias QuickSlips.Signatures

  defp upload(bytes, name \\ "sign.png", type \\ "image/png") do
    %Plug.Upload{path: tmp_file(bytes), filename: name, content_type: type}
  end

  test "a visitor is told to log in, and nothing is saved", %{conn: conn} do
    conn = post(conn, ~p"/api/signatures", %{name: "Owner", file: upload(png_bytes())})

    assert %{"error" => "log in first"} = json_response(conn, 401)
    assert QuickSlips.Repo.aggregate(Signatures.Signature, :count) == 0
  end

  describe "when logged in" do
    setup :register_and_log_in_user

    setup %{user: user} do
      on_exit(fn ->
        File.rm_rf(Path.join(QuickSlips.Uploads.root(), Integer.to_string(user.id)))
      end)
    end

    test "saves the signature and answers with what the page needs", %{
      conn: conn,
      user: user,
      scope: scope
    } do
      conn = post(conn, ~p"/api/signatures", %{name: "Owner", file: upload(png_bytes())})

      assert %{"signature" => %{"id" => id, "name" => "Owner", "url" => url} = signature} =
               json_response(conn, 201)

      assert Map.keys(signature) |> Enum.sort() == ["id", "name", "url"]
      assert url =~ ~r|^/uploads/#{user.id}/[a-f0-9]{16}\.png$|
      assert [%{id: ^id, name: "Owner"}] = Signatures.list_signatures(scope)
    end

    test "the picture is served at that address, to its owner", %{conn: conn} do
      conn = post(conn, ~p"/api/signatures", %{name: "Owner", file: upload(jpg_bytes())})
      %{"signature" => %{"url" => url}} = json_response(conn, 201)

      conn = get(recycle(conn), url)

      assert response(conn, 200) == jpg_bytes()
      assert ["image/jpeg" <> _] = get_resp_header(conn, "content-type")
    end

    test "trims the name", %{conn: conn} do
      conn = post(conn, ~p"/api/signatures", %{name: "  Manager ", file: upload(png_bytes())})

      assert %{"signature" => %{"name" => "Manager"}} = json_response(conn, 201)
    end

    test "says name_blank for a missing or empty name, and keeps nothing", %{
      conn: conn,
      scope: scope
    } do
      for params <- [%{file: upload(png_bytes())}, %{name: "  ", file: upload(png_bytes())}] do
        conn = post(conn, ~p"/api/signatures", params)
        assert %{"code" => "name_blank"} = json_response(conn, 422)
      end

      assert Signatures.count_signatures(scope) == 0
    end

    test "says name_taken for a name the user has, whatever the capitals", %{
      conn: conn,
      scope: scope
    } do
      signature_fixture(scope, %{name: "Owner"})

      conn = post(conn, ~p"/api/signatures", %{name: "OWNER", file: upload(png_bytes())})

      assert %{"code" => "name_taken"} = json_response(conn, 422)
      assert Signatures.count_signatures(scope) == 1
    end

    test "says name_too_long for 41 letters", %{conn: conn} do
      conn =
        post(conn, ~p"/api/signatures", %{
          name: String.duplicate("a", 41),
          file: upload(png_bytes())
        })

      assert %{"code" => "name_too_long"} = json_response(conn, 422)
    end

    test "says unsupported_type for a file that is not a picture", %{conn: conn} do
      conn = post(conn, ~p"/api/signatures", %{name: "Owner", file: upload("only text")})

      assert %{"code" => "unsupported_type"} = json_response(conn, 422)
    end

    test "says too_large for a picture with too many pixels", %{conn: conn} do
      conn = post(conn, ~p"/api/signatures", %{name: "Owner", file: upload(png_of_size(4_001))})

      assert %{"code" => "too_large"} = json_response(conn, 422)
    end

    test "says file_too_large for a file over 1 MB", %{conn: conn} do
      big = png_bytes() <> :binary.copy(<<0>>, QuickSlips.Uploads.max_file_size())
      conn = post(conn, ~p"/api/signatures", %{name: "Owner", file: upload(big)})

      assert %{"code" => "file_too_large"} = json_response(conn, 422)
    end

    test "says no_file when no file came with the name", %{conn: conn} do
      conn = post(conn, ~p"/api/signatures", %{name: "Owner"})

      assert %{"code" => "no_file"} = json_response(conn, 422)
    end

    test "says limit_reached when the user keeps the most", %{conn: conn, scope: scope} do
      for n <- 1..Signatures.max_per_user(), do: signature_fixture(scope, %{name: "Sig #{n}"})

      conn = post(conn, ~p"/api/signatures", %{name: "One more", file: upload(png_bytes())})

      assert %{"code" => "limit_reached"} = json_response(conn, 422)
    end
  end
end
