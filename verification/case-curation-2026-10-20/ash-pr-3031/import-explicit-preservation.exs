alias Eab.{Cache, Candidates, Fixtures, Grader, Inventory, Runs, Store}
%{active: nil, cleaning: false, cleanup_error: nil} = Runs.snapshot()
unless Eab.Retention.leased_runs() == [] and
    Registry.lookup(Eab.Commands, {:cache_users, Store.root()}) == [] and
    Registry.lookup(Eab.Commands, {:cache_removal, Store.root()}) == [],
  do: raise("Standalone work or leases remain")
unless Inventory.all() == [], do: raise("Expected empty inventory")
draft = "/tmp/ash-explicit-draft"
expected = Inventory.read_json(Path.join(__DIR__, "final-draft-hashes.json"))
actual = Map.new(File.ls!(draft), &{&1, Inventory.hash_file(Path.join(draft, &1))})
unless actual == expected, do: raise("Draft differs from independently reviewed version")
old = Store.read("curation/ash-pr-3031-current.json")
unless old["version"] == "923f2acf250e8b9e79afbda9cd56fce6e383aed747224b1081a4806f4617d88b",
  do: raise("Unexpected previous version")
prior = Enum.map(~w(astra-1.json astra-amended-1.json),
  &Inventory.read_json(Path.join(__DIR__, &1)))
unless Enum.all?(prior, &(&1["accepted_validation_success"] == false)) and
    List.last(prior)["official_grading_passed"] == false,
  do: raise("Prior attempt dispositions missing")
ref = Candidates.import(draft)
unless ref["version"] == "09528c895206c98feddc652314bef1da31dd72ee7e870218b187bb1ec704f394",
  do: raise("Unexpected clarified candidate")
prefix = "curation/ash-pr-3031/#{ref["version"]}"
Store.write("curation/ash-pr-3031-current.json", ref)
Store.write("#{prefix}/prior-attempts.json", prior)
Candidates.review(ref, %{
  "author" => "/root", "reviewer" => "/root/contract_review", "decision" => "approve",
  "requirements_read_before_checks" => true, "assertion_mapping_checked" => true,
  "rationale" => "Independent requirements-first review approved explicit observable typed-comparison and nil-tuple/default preservation wording, with no repair recipe. Only ticket and requirement descriptions changed; all checks, source, runtime and controls remain unchanged. Review SHA256 " <>
    Inventory.hash_file(Path.join(__DIR__, "explicit-preservation-review.md")) <>
    ". Both earlier attempts are retained on their original versions; three fresh controls and a new blind pair remain required."
})
Inventory.with_case(ref["id"], draft, fn ->
  runtime = Fixtures.ensure(ref["id"], &IO.puts/1)
  cache = Store.path("qualifications/#{Cache.key(Grader.qualification_identity(ref["id"], runtime))}.json")
  if File.exists?(cache) do
    destination = Store.path("#{prefix}/qualification-cache-before-round-1.json")
    unless not File.exists?(destination), do: raise("First-round archive exists")
    File.mkdir_p!(Path.dirname(destination))
    File.rename!(cache, destination)
  end
end)
IO.puts("IMPORTED_EXPLICIT_PRESERVATION " <> Jason.encode!(ref))
Candidates.qualify(ref, &IO.puts/1)
Code.eval_file(Path.join(__DIR__, "repeat-qualification.exs"))
Code.eval_file(Path.join(__DIR__, "export-qualification.exs"))
