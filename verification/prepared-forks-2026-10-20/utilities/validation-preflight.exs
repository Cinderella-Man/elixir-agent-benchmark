alias Eab.{Cache, Candidates, Inventory, Store}
ref = Store.read("fork-migration/current.json")
id = ref["id"]
prefix = "fork-migration/#{id}/#{ref["version"]}"
manifest = Store.read("#{prefix}/manifest.json")
unless Inventory.all() == [id], do: raise("Expected singleton candidate inventory")
unless Map.delete(Inventory.fixture_hashes(id), "admission.json") == manifest["files"] and
    Cache.key(manifest["files"]) == ref["version"], do: raise("Active bundle differs from reviewed version")
if Inventory.spec(id)["schema_version"] == 2, do: Candidates.verify_admission!(id)
%{active: nil, cleaning: false, cleanup_error: nil} = Eab.Runs.snapshot()
unless Eab.Measurement.start() == :disabled and
    Eab.Measurement.finish(:disabled) == %{"disabled" => "functional_validation_machine_policy"},
  do: raise("Timing observer must be disabled")
Code.require_file("qualification-outcomes.exs", __DIR__)
Code.require_file("evidence-binding.exs", __DIR__)
binding = Curation.EvidenceBinding.preflight!(id, ref, prefix, &ForkMigration.Outcomes.normalize/1)
record = %{
  "case" => id, "candidate" => ref, "qualification_hash" => Inventory.qualification_hash(),
  "three_fresh_qualification_rounds_verified" => true, "named_outcomes_hash" => binding["named_outcomes_hash"],
  "runtime" => binding["runtime"],
  "source" => binding["source"], "prepared_source_tree" => binding["prepared_source_tree"],
  "measurement_observer" => %{"disabled" => true,
    "reason" => "Shared-machine policy permits functional validation and prohibits speed measurement.",
    "source_sha256" => Inventory.hash_file(Inventory.path("lib/eab/measurement.ex"))}
}
record = Map.merge(record, binding)
Store.write("#{prefix}/preflight.json", record)
Store.write_text("#{prefix}/measurement.ex", File.read!(Inventory.path("lib/eab/measurement.ex")))
IO.puts("PREFLIGHT_OK " <> id)
