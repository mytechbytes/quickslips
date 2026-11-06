defmodule QuickSlips.Templates.RegistryTest do
  use ExUnit.Case, async: true

  alias QuickSlips.Templates.Registry

  @moduletag :tmp_dir

  defp write_schema(dir, slug, fields) do
    File.mkdir_p!(Path.join(dir, slug))
    schema = %{slug: slug, title: "Test", category: "Work", templates: [], fields: fields}
    File.write!(Path.join([dir, slug, "schema.json"]), Jason.encode!(schema))
  end

  test "loads every folder that has a schema, and ignores folders that have none", %{tmp_dir: dir} do
    write_schema(dir, "one", [])
    File.mkdir_p!(Path.join(dir, "_shared"))

    registry = start_supervised!({Registry, dir: dir, name: :registry_ok})

    assert [%{"slug" => "one"}] = Registry.list(registry)
  end

  test "refuses a field named like a business picture", %{tmp_dir: dir} do
    Process.flag(:trap_exit, true)

    for key <- ["logo", "signature"] do
      write_schema(dir, "bad", [%{key: key, label: "Picture", type: "text"}])

      assert {:error, {%RuntimeError{message: message}, _stacktrace}} =
               Registry.start_link(dir: dir, name: :registry_bad)

      assert message =~ "reserved for business pictures"
    end
  end
end
