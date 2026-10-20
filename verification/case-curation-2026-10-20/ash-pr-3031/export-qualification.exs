alias Eab.{Cache, Inventory, Store}
ref = Store.read("curation/ash-pr-3031-current.json")
prefix = "curation/#{ref["id"]}/#{ref["version"]}"
out = "/tmp/ash-curation-evidence"
File.mkdir_p!(out)
matching = Store.read("#{prefix}/matching-controls.json")
Code.require_file("qualification-outcomes.exs", __DIR__)
normalize = &AshCuration.Outcomes.normalize/1
for round <- 1..3 do
  path = "#{prefix}/qualification-round-#{round}.json"
  proof = Store.read(path)
  outcomes = normalize.(proof)
  unless outcomes == matching, do: raise("Round differs from checked outcome comparison")
  record = %{
    "candidate" => ref,
    "round" => round,
    "fresh_controls" => true,
    "valid" => proof["controls"]["valid"],
    "source" => proof["source"],
    "grader" => proof["grader"],
    "runtime" => Map.take(proof["runtime"], ~w(image services baseline base_image toolchain_image)),
    "named_outcomes" => outcomes,
    "named_outcomes_hash" => Cache.key(outcomes),
    "private_receipt_sha256" => Inventory.hash_file(Store.path(path))
  }
  File.write!(Path.join(out, "qualification-round-#{round}.json"), Jason.encode!(record, pretty: true) <> "\n")
end
IO.puts("Exported three functional qualification summaries")
