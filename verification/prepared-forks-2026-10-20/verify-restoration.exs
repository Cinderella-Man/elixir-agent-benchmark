alias Eab.{Candidates, Checkpoints, Inventory, Release, Runs, Store}
%{active: nil, cleaning: false, cleanup_error: nil} = Runs.snapshot()
unless Eab.Retention.leased_runs() == [] and
    Registry.lookup(Eab.Commands, {:cache_users, Store.root()}) == [] and
    Registry.lookup(Eab.Commands, {:cache_removal, Store.root()}) == [],
  do: raise("Standalone work or retained leases present; inspect before restoration")

audit = Inventory.read_json(Path.join(__DIR__, "restored-source-audit.json"))
expected = Map.new(audit["cases"], &{&1["case"], &1["bundle_hashes"]})
unless Enum.sort(Inventory.all()) == Enum.sort(Map.keys(expected)),
  do: raise("Restored inventory does not match the audited approved versions")
for {id, hashes} <- expected do
  unless Inventory.fixture_hashes(id) == hashes, do: raise("Bundle changed: #{id}")
end

normal = Inventory.hash_file(Path.join(__DIR__, "repository-measurement.ex"))
unless Inventory.hash_file(Inventory.path("lib/eab/measurement.ex")) == normal and
    normal != Inventory.hash_file(Path.join(__DIR__, "utilities/validation-measurement.ex")),
  do: raise("Normal repository measurement source was not restored")
{:ok, {Eab.Measurement, beam_md5}} = :beam_lib.md5(:code.which(Eab.Measurement))
unless Eab.Measurement.module_info(:md5) == beam_md5,
  do: raise("Loaded measurement module differs from its rebuilt beam")
unless Eab.Measurement.label(%{"attempt_ms" => 1000}) == "1.0 s",
  do: raise("Loaded observer still has disabled behavior")

Code.require_file("utilities/qualification-outcomes.exs", __DIR__)
Code.require_file("utilities/evidence-binding.exs", __DIR__)
verified = for id <- Inventory.all() do
  if Inventory.spec(id)["schema_version"] == 2, do: Candidates.verify_admission!(id)
  directory = if id == "ash-pr-3031", do: "ash-evidence", else: id
  results = Inventory.read_json(Path.join([__DIR__, directory, "astra-results.json"]))
  ref = hd(results["runs"])["candidate"]
  prefix = if id == "ash-pr-3031", do: "curation/#{id}/#{ref["version"]}",
    else: "fork-migration/#{id}/#{ref["version"]}"
  binding = Curation.EvidenceBinding.preflight!(id, ref, prefix, &ForkMigration.Outcomes.normalize/1)
  for result <- results["runs"] do
    run = Store.run(result["run_id"])
    unless run["status"] == "completed" and run["cleanup_pending"] == false and
        Checkpoints.completed(run, id)["grade"]["passed"],
      do: raise("Missing sealed completed solver success: #{id}")
    base = "runs/#{run["id"]}/#{id}"
    Curation.EvidenceBinding.verify_run!(base, binding, &ForkMigration.Outcomes.normalize/1)
    unless Inventory.hash_file(Store.path("#{base}/model.patch")) == result["patch_sha256"],
      do: raise("Sealed solver patch differs from independent review: #{id}")
    for {name, hash} <- result["frozen_hashes"] do
      unless Inventory.hash_file(Store.path("#{base}/#{name}")) == hash,
        do: raise("Saved solver inputs changed: #{id}/#{name}")
    end
  end
  %{"case" => id, "candidate" => ref, "runtime" => binding["runtime"],
    "prepared_source_tree" => binding["prepared_source_tree"],
    "three_rounds_and_two_sealed_runs_reverified" => true}
end

release = Release.freeze()
Release.verify!(release)
record = %{"inventory" => Inventory.all(), "case_count" => length(Inventory.all()),
  "cases" => verified, "restored_release_id" => release["id"],
  "implementation_hash" => Inventory.implementation_hash(),
  "qualification_hash" => Inventory.qualification_hash(),
  "repository_observer_source_sha256" => normal,
  "loaded_observer_matches_rebuilt_module" => true,
  "normal_observer_behavior_verified_without_reading_a_clock" => true,
  "controller_idle_and_clean" => true, "model_run_started_for_restoration" => false}
File.write!(Path.join(__DIR__, "restoration.json"), Jason.encode!(record, pretty: true) <> "\n")
IO.puts("FULL_PREPARED_FORK_INVENTORY_RESTORED_AND_VERIFIED")
