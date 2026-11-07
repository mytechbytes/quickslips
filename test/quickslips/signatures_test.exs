defmodule QuickSlips.SignaturesTest do
  use QuickSlips.DataCase

  alias QuickSlips.Signatures
  alias QuickSlips.Signatures.Signature
  alias QuickSlips.Uploads

  import QuickSlips.AccountsFixtures, only: [user_scope_fixture: 0]
  import QuickSlips.DocumentsFixtures
  import QuickSlips.SignaturesFixtures
  import QuickSlips.UploadsFixtures

  # Everything a user stored, so a test can tell whether a file was kept or thrown away.
  defp stored_files(scope) do
    Path.join([Uploads.root(), Integer.to_string(scope.user.id), "*"]) |> Path.wildcard()
  end

  setup do
    scope = user_scope_fixture()
    # The folder of the user is removed when the test ends, whichever files it holds.
    folder = Path.join(Uploads.root(), Integer.to_string(scope.user.id))
    on_exit(fn -> File.rm_rf(folder) end)
    %{scope: scope}
  end

  describe "create_signature/3" do
    test "keeps the picture and the name", %{scope: scope} do
      assert {:ok, %Signature{} = signature} =
               Signatures.create_signature(scope, %{name: "Owner"}, tmp_file(png_bytes()))

      assert signature.name == "Owner"
      assert signature.user_id == scope.user.id
      assert signature.path =~ ~r/^#{scope.user.id}\/[a-f0-9]{16}\.png$/
      assert File.read!(Uploads.path(signature.path)) == png_bytes()
    end

    test "takes a JPEG too, and trims the name", %{scope: scope} do
      assert {:ok, %Signature{name: "Manager", path: path}} =
               Signatures.create_signature(scope, %{name: "  Manager  "}, tmp_file(jpg_bytes()))

      assert path =~ ~r/\.jpg$/
    end

    test "needs a name, and keeps no file without one", %{scope: scope} do
      assert {:error, changeset} =
               Signatures.create_signature(scope, %{name: "   "}, tmp_file(png_bytes()))

      assert %{name: ["can't be blank"]} = errors_on(changeset)
      assert stored_files(scope) == []
    end

    test "the name is at most 40 letters", %{scope: scope} do
      long = String.duplicate("a", 41)

      assert {:error, changeset} =
               Signatures.create_signature(scope, %{name: long}, tmp_file(png_bytes()))

      assert %{name: ["should be at most 40 character(s)"]} = errors_on(changeset)
    end

    test "two signatures of a user can't have the same name, whatever the capitals", %{
      scope: scope
    } do
      first = signature_fixture(scope, %{name: "Owner"})

      assert {:error, changeset} =
               Signatures.create_signature(scope, %{name: "owner"}, tmp_file(png_bytes()))

      assert %{name: ["is already used by another of your signatures"]} = errors_on(changeset)

      # The second picture was not kept: only the first one is on disk.
      assert stored_files(scope) == [Uploads.path(first.path)]
      assert Signatures.count_signatures(scope) == 1
    end

    test "another user may use the same name", %{scope: scope} do
      signature_fixture(scope, %{name: "Owner"})
      other = user_scope_fixture()

      assert {:ok, _} =
               Signatures.create_signature(other, %{name: "Owner"}, tmp_file(png_bytes()))

      File.rm_rf(Path.join(Uploads.root(), Integer.to_string(other.user.id)))
    end

    test "turns down a file that is not a picture", %{scope: scope} do
      assert {:error, :unsupported_type} =
               Signatures.create_signature(scope, %{name: "Owner"}, tmp_file("only text"))

      assert Signatures.count_signatures(scope) == 0
      assert stored_files(scope) == []
    end

    test "turns down a picture with too many pixels", %{scope: scope} do
      assert {:error, :too_large} =
               Signatures.create_signature(scope, %{name: "Owner"}, tmp_file(png_of_size(4_001)))
    end

    test "turns down a file over 1 MB", %{scope: scope} do
      big = png_bytes() <> :binary.copy(<<0>>, Uploads.max_file_size())

      assert {:error, :file_too_large} =
               Signatures.create_signature(scope, %{name: "Owner"}, tmp_file(big))

      assert stored_files(scope) == []
    end

    test "keeps at most #{Signatures.max_per_user()} per user", %{scope: scope} do
      for n <- 1..Signatures.max_per_user(), do: signature_fixture(scope, %{name: "Sig #{n}"})

      assert {:error, :limit_reached} =
               Signatures.create_signature(scope, %{name: "One more"}, tmp_file(png_bytes()))

      assert Signatures.count_signatures(scope) == Signatures.max_per_user()
    end

    test "tells the user's other tabs", %{scope: scope} do
      Signatures.subscribe_signatures(scope)
      signature = signature_fixture(scope)

      assert_receive {:created, ^signature}
    end
  end

  describe "listing and finding" do
    test "list_signatures/1 is the user's own, by name without capitals", %{scope: scope} do
      b = signature_fixture(scope, %{name: "beta"})
      a = signature_fixture(scope, %{name: "Alpha"})
      c = signature_fixture(scope, %{name: "Charlie"})
      signature_fixture(user_scope_fixture(), %{name: "Not mine"})

      assert Signatures.list_signatures(scope) == [a, b, c]
      assert Signatures.count_signatures(scope) == 3
    end

    test "get_signature!/2 raises for somebody else's", %{scope: scope} do
      mine = signature_fixture(scope)
      theirs = signature_fixture(user_scope_fixture())

      assert Signatures.get_signature!(scope, mine.id) == mine

      assert_raise Ecto.NoResultsError, fn -> Signatures.get_signature!(scope, theirs.id) end
    end

    test "get_signature/2 gives nil for somebody else's, for nothing and for rubbish", %{
      scope: scope
    } do
      mine = signature_fixture(scope)
      theirs = signature_fixture(user_scope_fixture())

      assert Signatures.get_signature(scope, mine.id) == mine
      assert Signatures.get_signature(scope, Integer.to_string(mine.id)) == mine
      assert Signatures.get_signature(scope, theirs.id) == nil
      assert Signatures.get_signature(scope, nil) == nil
      assert Signatures.get_signature(scope, "") == nil
      assert Signatures.get_signature(scope, "rubbish") == nil

      assert Signatures.owned?(scope, mine.id)
      refute Signatures.owned?(scope, theirs.id)
    end
  end

  describe "delete_signature/2" do
    test "deletes the row and the file", %{scope: scope} do
      signature = signature_fixture(scope)
      Signatures.subscribe_signatures(scope)

      assert {:ok, _} = Signatures.delete_signature(scope, signature)

      assert Signatures.get_signature(scope, signature.id) == nil
      refute File.exists?(Uploads.path(signature.path))
      assert_receive {:deleted, %Signature{id: id}} when id == signature.id
    end

    test "leaves the businesses and documents that used it, without the picture", %{scope: scope} do
      signature = signature_fixture(scope)

      {:ok, business} =
        QuickSlips.Businesses.create_business(scope, %{name: "Shop", signature_id: signature.id})

      document = document_fixture(scope, %{}, nil, signature)
      assert document.signature_id == signature.id

      assert {:ok, _} = Signatures.delete_signature(scope, signature)

      assert Repo.reload!(business).signature_id == nil
      assert Repo.reload!(document).signature_id == nil
    end

    test "is not allowed on somebody else's signature", %{scope: scope} do
      theirs = signature_fixture(user_scope_fixture())

      assert_raise MatchError, fn -> Signatures.delete_signature(scope, theirs) end
      assert File.exists?(Uploads.path(theirs.path))
    end

    test "deleting a user takes the signatures along", %{scope: scope} do
      signature_fixture(scope)
      Repo.delete!(scope.user)

      assert Repo.aggregate(Signature, :count) == 0
    end
  end

  describe "render_assets/1" do
    test "names the picture and says where its file is", %{scope: scope} do
      signature = signature_fixture(scope, %{}, jpg_bytes())

      assert %{data: %{"signature" => "signature.jpg"}, files: %{"signature.jpg" => file}} =
               Signatures.render_assets(signature)

      assert file == Uploads.path(signature.path)
    end

    test "gives nothing for no signature, or for one whose file is gone", %{scope: scope} do
      signature = signature_fixture(scope)
      File.rm!(Uploads.path(signature.path))

      assert Signatures.render_assets(nil) == %{data: %{}, files: %{}}
      assert Signatures.render_assets(signature) == %{data: %{}, files: %{}}
    end
  end
end
