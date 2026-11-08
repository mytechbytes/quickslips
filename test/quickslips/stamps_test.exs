defmodule QuickSlips.StampsTest do
  use QuickSlips.DataCase

  alias QuickSlips.Stamps
  alias QuickSlips.Stamps.Stamp
  alias QuickSlips.Uploads

  import QuickSlips.AccountsFixtures, only: [user_scope_fixture: 0]
  import QuickSlips.DocumentsFixtures
  import QuickSlips.StampsFixtures
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

  describe "create_stamp/3" do
    test "keeps the picture and the name", %{scope: scope} do
      assert {:ok, %Stamp{} = stamp} =
               Stamps.create_stamp(scope, %{name: "Owner"}, tmp_file(png_bytes()))

      assert stamp.name == "Owner"
      assert stamp.user_id == scope.user.id
      assert stamp.path =~ ~r/^#{scope.user.id}\/[a-f0-9]{16}\.png$/
      assert File.read!(Uploads.path(stamp.path)) == png_bytes()
    end

    test "takes a JPEG too, and trims the name", %{scope: scope} do
      assert {:ok, %Stamp{name: "Manager", path: path}} =
               Stamps.create_stamp(scope, %{name: "  Manager  "}, tmp_file(jpg_bytes()))

      assert path =~ ~r/\.jpg$/
    end

    test "needs a name, and keeps no file without one", %{scope: scope} do
      assert {:error, changeset} =
               Stamps.create_stamp(scope, %{name: "   "}, tmp_file(png_bytes()))

      assert %{name: ["can't be blank"]} = errors_on(changeset)
      assert stored_files(scope) == []
    end

    test "the name is at most 40 letters", %{scope: scope} do
      long = String.duplicate("a", 41)

      assert {:error, changeset} =
               Stamps.create_stamp(scope, %{name: long}, tmp_file(png_bytes()))

      assert %{name: ["should be at most 40 character(s)"]} = errors_on(changeset)
    end

    test "two stamps of a user can't have the same name, whatever the capitals", %{
      scope: scope
    } do
      first = stamp_fixture(scope, %{name: "Owner"})

      assert {:error, changeset} =
               Stamps.create_stamp(scope, %{name: "owner"}, tmp_file(png_bytes()))

      assert %{name: ["is already used by another of your stamps"]} = errors_on(changeset)

      # The second picture was not kept: only the first one is on disk.
      assert stored_files(scope) == [Uploads.path(first.path)]
      assert Stamps.count_stamps(scope) == 1
    end

    test "another user may use the same name", %{scope: scope} do
      stamp_fixture(scope, %{name: "Owner"})
      other = user_scope_fixture()

      assert {:ok, _} =
               Stamps.create_stamp(other, %{name: "Owner"}, tmp_file(png_bytes()))

      File.rm_rf(Path.join(Uploads.root(), Integer.to_string(other.user.id)))
    end

    test "turns down a file that is not a picture", %{scope: scope} do
      assert {:error, :unsupported_type} =
               Stamps.create_stamp(scope, %{name: "Owner"}, tmp_file("only text"))

      assert Stamps.count_stamps(scope) == 0
      assert stored_files(scope) == []
    end

    test "turns down a picture with too many pixels", %{scope: scope} do
      assert {:error, :too_large} =
               Stamps.create_stamp(scope, %{name: "Owner"}, tmp_file(png_of_size(4_001)))
    end

    test "turns down a file over 1 MB", %{scope: scope} do
      big = png_bytes() <> :binary.copy(<<0>>, Uploads.max_file_size())

      assert {:error, :file_too_large} =
               Stamps.create_stamp(scope, %{name: "Owner"}, tmp_file(big))

      assert stored_files(scope) == []
    end

    test "keeps at most #{Stamps.max_per_user()} per user", %{scope: scope} do
      for n <- 1..Stamps.max_per_user(), do: stamp_fixture(scope, %{name: "Sig #{n}"})

      assert {:error, :limit_reached} =
               Stamps.create_stamp(scope, %{name: "One more"}, tmp_file(png_bytes()))

      assert Stamps.count_stamps(scope) == Stamps.max_per_user()
    end

    test "tells the user's other tabs", %{scope: scope} do
      Stamps.subscribe_stamps(scope)
      stamp = stamp_fixture(scope)

      assert_receive {:created, ^stamp}
    end
  end

  describe "listing and finding" do
    test "list_stamps/1 is the user's own, by name without capitals", %{scope: scope} do
      b = stamp_fixture(scope, %{name: "beta"})
      a = stamp_fixture(scope, %{name: "Alpha"})
      c = stamp_fixture(scope, %{name: "Charlie"})
      stamp_fixture(user_scope_fixture(), %{name: "Not mine"})

      assert Stamps.list_stamps(scope) == [a, b, c]
      assert Stamps.count_stamps(scope) == 3
    end

    test "get_stamp!/2 raises for somebody else's", %{scope: scope} do
      mine = stamp_fixture(scope)
      theirs = stamp_fixture(user_scope_fixture())

      assert Stamps.get_stamp!(scope, mine.id) == mine

      assert_raise Ecto.NoResultsError, fn -> Stamps.get_stamp!(scope, theirs.id) end
    end

    test "get_stamp/2 gives nil for somebody else's, for nothing and for rubbish", %{
      scope: scope
    } do
      mine = stamp_fixture(scope)
      theirs = stamp_fixture(user_scope_fixture())

      assert Stamps.get_stamp(scope, mine.id) == mine
      assert Stamps.get_stamp(scope, Integer.to_string(mine.id)) == mine
      assert Stamps.get_stamp(scope, theirs.id) == nil
      assert Stamps.get_stamp(scope, nil) == nil
      assert Stamps.get_stamp(scope, "") == nil
      assert Stamps.get_stamp(scope, "rubbish") == nil

      assert Stamps.get_stamp(scope, mine.id)
      refute Stamps.get_stamp(scope, theirs.id)
    end
  end

  describe "delete_stamp/2" do
    test "deletes the row and the file", %{scope: scope} do
      stamp = stamp_fixture(scope)
      Stamps.subscribe_stamps(scope)

      assert {:ok, _} = Stamps.delete_stamp(scope, stamp)

      assert Stamps.get_stamp(scope, stamp.id) == nil
      refute File.exists?(Uploads.path(stamp.path))
      assert_receive {:deleted, %Stamp{id: id}} when id == stamp.id
    end

    test "leaves the documents that used it, without the picture", %{scope: scope} do
      stamp = stamp_fixture(scope)
      document = document_fixture(scope, %{}, nil, nil, stamp)
      assert document.stamp_id == stamp.id

      assert {:ok, _} = Stamps.delete_stamp(scope, stamp)

      assert Repo.reload!(document).stamp_id == nil
    end

    test "is not allowed on somebody else's stamp", %{scope: scope} do
      theirs = stamp_fixture(user_scope_fixture())

      assert_raise MatchError, fn -> Stamps.delete_stamp(scope, theirs) end
      assert File.exists?(Uploads.path(theirs.path))
    end

    test "deleting a user takes the stamps along", %{scope: scope} do
      stamp_fixture(scope)
      Repo.delete!(scope.user)

      assert Repo.aggregate(Stamp, :count) == 0
    end
  end

  describe "system_stamps/0" do
    test "are the pictures in priv/images/stamps, with a name made of the file name" do
      assert %{
               id: "india-rupee-one-revenue-stamp",
               name: "India rupee one revenue stamp",
               file: file,
               path: path
             } =
               Stamps.system_stamp("india-rupee-one-revenue-stamp")

      assert file == "india-rupee-one-revenue-stamp.jpeg"
      assert File.regular?(path)
      assert Enum.all?(Stamps.system_stamps(), &(Path.extname(&1.file) in ~w(.png .jpg .jpeg)))
      assert Stamps.system_stamp("../../etc/passwd") == nil
    end
  end

  describe "render_assets/1" do
    test "names the picture and says where its file is", %{scope: scope} do
      stamp = stamp_fixture(scope, %{}, jpg_bytes())

      assert %{data: %{"stamp" => "stamp.jpg"}, files: %{"stamp.jpg" => file}} =
               Stamps.render_assets(stamp)

      assert file == Uploads.path(stamp.path)
    end

    test "names the picture of a stamp the site provides, and says where its file is" do
      assert %{data: %{"stamp" => "stamp.jpeg"}, files: %{"stamp.jpeg" => file}} =
               Stamps.render_assets({:system, "india-rupee-one-revenue-stamp"})

      assert File.regular?(file)
      assert Stamps.render_assets({:system, "nothing-like-it"}) == %{data: %{}, files: %{}}
    end

    test "gives nothing for no stamp, or for one whose file is gone", %{scope: scope} do
      stamp = stamp_fixture(scope)
      File.rm!(Uploads.path(stamp.path))

      assert Stamps.render_assets(nil) == %{data: %{}, files: %{}}
      assert Stamps.render_assets(stamp) == %{data: %{}, files: %{}}
    end
  end
end
