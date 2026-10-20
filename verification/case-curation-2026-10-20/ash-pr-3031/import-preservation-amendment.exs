alias Eab.{Candidates, Inventory, Runs, Store}
%{active: nil, cleaning: false, cleanup_error: nil} = Runs.snapshot()
unless Inventory.all() == [], do: raise("Expected empty inventory before draft import")
draft = "/tmp/ash-amended-draft"
expected = Inventory.read_json(Path.join(__DIR__, "final-draft-hashes.json"))
actual = Map.new(File.ls!(draft), &{&1, Inventory.hash_file(Path.join(draft, &1))})
unless actual == expected, do: raise("Draft differs from reviewed hashes")
old_ref = Store.read("curation/ash-pr-3031-current.json")
unless old_ref["version"] == "66b3546266deff378786cf94a92d5b2257978678ef948e38c8eb2952e8093a5b", do: raise("Unexpected previous candidate")
first = Inventory.read_json(Path.join(__DIR__, "astra-1.json"))
unless first["official_grading_passed"] and first["review_disposition"] == "rejected_preservation_regressions", do: raise("First attempt disposition missing")
ref = Candidates.import(draft)
Store.write("curation/ash-pr-3031-current.json", ref)
Store.write("curation/ash-pr-3031/#{ref["version"]}/prior-attempts.json", [first])
Candidates.review(ref, %{
  "author" => "/root", "reviewer" => "/root/contract_review", "decision" => "approve",
  "requirements_read_before_checks" => true, "assertion_mapping_checked" => true,
  "rationale" => "Independent requirements-first review of two additional public-behavior checks under unchanged visible requirements. Preservation amendment review SHA256 " <> Inventory.hash_file(Path.join(__DIR__, "preservation-amendment-review.md")) <> ". Source and reference are unchanged. Diagnostic confirms reference passes both, pristine nil/default passes, and sealed first submission fails both in test bodies; original passing grade is retained with review rejection. Three fresh full control rounds and two new blind model runs remain required."
})
IO.puts("IMPORTED_AMENDMENT " <> Jason.encode!(ref))
Candidates.qualify(ref, &IO.puts/1)
Code.eval_file(Path.join(__DIR__, "repeat-qualification.exs"))
Code.eval_file(Path.join(__DIR__, "export-qualification.exs"))
