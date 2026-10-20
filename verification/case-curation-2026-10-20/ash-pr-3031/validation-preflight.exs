alias Eab.{Cache, Candidates, Inventory, Store}
id = "ash-pr-3031"
ref = Store.read("curation/#{id}-current.json")
prefix = "curation/#{id}/#{ref["version"]}"
unless Inventory.all() == [id], do: raise("Expected singleton candidate inventory")
Candidates.verify_admission!(id)
unless Inventory.read_json(Inventory.case_path(id, "admission.json"))["candidate"] == ref,
  do: raise("Active admission differs from current candidate pointer")
s = Eab.Runs.snapshot()
unless is_nil(s.active) and not s.cleaning and is_nil(s.cleanup_error), do: raise("Controller busy")
unless Eab.Measurement.start() == :disabled and
  Eab.Measurement.finish(:disabled) == %{"disabled" => "functional_validation_machine_policy"},
  do: raise("Timing observer must be disabled")
proofs = for n <- 1..3, do: Store.read("#{prefix}/qualification-round-#{n}.json")
unless Enum.all?(proofs, &(&1["candidate"] == ref and &1["controls"]["valid"] and
  &1["grader"] == Inventory.qualification_hash() and
  &1["checksum"] == Cache.key(Map.delete(&1, "checksum")))), do: raise("Invalid qualification receipts")
unless Enum.uniq(Enum.map(proofs, & &1["controls"]["identity"])) |> length() == 1,
  do: raise("Qualification inputs differ")
Code.require_file("qualification-outcomes.exs", __DIR__)
matching = Store.read("#{prefix}/matching-controls.json")
unless Enum.all?(proofs, &(AshCuration.Outcomes.normalize(&1) == matching)),
  do: raise("Named qualification outcomes differ")
record = %{
  "case" => id, "candidate" => ref,
  "main_commit" => "d9684ec85319e3c86be384f534ddd19af4b10562",
  "qualification_hash" => Inventory.qualification_hash(),
  "three_fresh_qualification_rounds_verified" => true,
  "named_outcomes_hash" => Cache.key(Store.read("#{prefix}/matching-controls.json")),
  "runtime" => Map.take(hd(proofs)["runtime"], ~w(image services baseline base_image toolchain_image)),
  "source" => hd(proofs)["source"],
  "measurement_observer" => %{
    "disabled" => true,
    "reason" => "Shared-machine policy permits functional validation and prohibits speed measurement.",
    "source_sha256" => Inventory.hash_file(Inventory.path("lib/eab/measurement.ex"))
  }
}
Store.write("#{prefix}/preflight.json", record)
Store.write_text("#{prefix}/measurement.ex", File.read!(Inventory.path("lib/eab/measurement.ex")))
IO.puts("PREFLIGHT_OK")
