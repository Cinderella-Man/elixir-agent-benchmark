alias Eab.{Candidates, Inventory, Release, Runs}

snapshot = Runs.snapshot()
unless is_nil(snapshot.active) and not snapshot.cleaning and is_nil(snapshot.cleanup_error),
  do: raise("Controller must be idle and clean")

original = Inventory.read_json(Path.join(__DIR__, "original-inventory.json"))
added = Inventory.read_json(Path.join(__DIR__, "bundle-sha256.json"))
expected = Map.put(original, "ash-pr-3031", added)
unless Enum.sort(Inventory.all()) == Enum.sort(Map.keys(expected)),
  do: raise("Restored controller inventory differs")

for {id, hashes} <- expected do
  unless Inventory.fixture_hashes(id) == hashes,
    do: raise("Restored case differs: #{id}")
end

schema_v2 = Enum.filter(Inventory.all(), &(Inventory.spec(&1)["schema_version"] == 2))
Enum.each(schema_v2, &Candidates.verify_admission!/1)

normal_observer = Inventory.hash_file(Path.join(__DIR__, "repository-measurement.ex"))
unless Inventory.hash_file(Inventory.path("lib/eab/measurement.ex")) == normal_observer and
    normal_observer != Inventory.hash_file(Path.join(__DIR__, "validation-measurement.ex")),
  do: raise("Repository timing observer was not restored")

# Inspect the rebuilt module identity without starting a timing observation.
beam_path = :code.which(Eab.Measurement) |> List.to_string()
{:ok, {Eab.Measurement, beam_md5}} = :beam_lib.md5(String.to_charlist(beam_path))
unless Eab.Measurement.module_info(:md5) == beam_md5,
  do: raise("Loaded observer differs from the rebuilt module")

release = Release.freeze()
Release.verify!(release)
record = %{
  "inventory" => Inventory.all(),
  "case_count" => length(Inventory.all()),
  "original_bundle_count" => map_size(original),
  "original_bundles_unchanged" => true,
  "accepted_bundle_unchanged" => true,
  "schema_v2_admissions_verified" => schema_v2,
  "restored_release_id" => release["id"],
  "implementation_hash" => Inventory.implementation_hash(),
  "qualification_hash" => Inventory.qualification_hash(),
  "repository_observer_source_sha256" => normal_observer,
  "loaded_observer_matches_rebuilt_module" => true,
  "controller_idle_and_clean" => true,
  "model_run_started_for_restoration" => false
}
File.write!(Path.join(__DIR__, "restoration.json"), Jason.encode!(record, pretty: true) <> "\n")
IO.puts("RESTORED_INVENTORY_VERIFIED")
