alias Eab.{Candidates, Inventory, Runs, Store}
ref = Store.read("curation/ash-pr-3031-current.json")
unless ref["version"] == "66b3546266deff378786cf94a92d5b2257978678ef948e38c8eb2952e8093a5b", do: raise("Wrong final candidate")
unless Inventory.all() == [], do: raise("Expected empty inventory before export")
s = Runs.snapshot()
unless is_nil(s.active) and not s.cleaning and is_nil(s.cleanup_error), do: raise("Controller busy")
Code.require_file("qualification-outcomes.exs", __DIR__)
prefix = "curation/#{ref["id"]}/#{ref["version"]}"
matching = Store.read("#{prefix}/matching-controls.json") || raise("Three-round comparison is not complete")
for round <- 1..3 do
  proof = Store.read("#{prefix}/qualification-round-#{round}.json") || raise("Missing qualification round")
  unless proof["candidate"] == ref and proof["controls"]["valid"] and
      AshCuration.Outcomes.normalize(proof) == matching, do: raise("Qualification rounds differ")
end
Candidates.export(ref, "/tmp/ash-admitted/ash-pr-3031")
IO.puts("FINAL_FORK_ADMISSION_EXPORTED")
