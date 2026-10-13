defmodule Eab.StoreTest do
  use ExUnit.Case, async: false

  test "redaction precedes JSON encoding, including quotes and newlines" do
    secret = "key\"line\nnext"
    data = %{"nested" => [%{"echo" => "before " <> secret <> " after"}]}

    assert Eab.Store.scrub(data, secret) == %{
             "nested" => [%{"echo" => "before [REDACTED] after"}]
           }

    assert Eab.Store.scrub(%{"case_result" => {"case", data}}, secret) == %{
             "case_result" => {"case", %{"nested" => [%{"echo" => "before [REDACTED] after"}]}}
           }
  end

  test "artifact access rejects traversal and symlinked parents" do
    base = Eab.Store.path("runs/artifact-test")
    File.mkdir_p!(base)
    File.write!(Path.join(base, "valid.json"), "{}")
    File.ln_s!(System.tmp_dir!(), Path.join(base, "escape"))
    on_exit(fn -> File.rm_rf!(base) end)
    assert {:ok, _} = Eab.Store.artifact("artifact-test", "valid.json")
    assert :error = Eab.Store.artifact("artifact-test", "../session-secret")
    assert :error = Eab.Store.artifact("../artifact-test", "valid.json")
    assert :error = Eab.Store.artifact("artifact-test", "escape/example.txt")
  end
end
