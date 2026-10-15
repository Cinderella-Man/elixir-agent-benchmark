# Functional repeatability only. Each round starts without qualification receipts.
# Prepared immutable images may be reused; model calls and speed measurements are absent.
alias Eab.{Grader, Inventory, Qualification, Release, Store}

{:ok, _} = Registry.start_link(keys: :duplicate, name: Eab.Commands)
{:ok, _} = Task.Supervisor.start_link(name: Eab.Tasks)
{:ok, _} = Application.ensure_all_started(:req)

unless String.contains?(Store.root(), "case-freeze-2026-10-15"),
  do: raise("Use the isolated case-freeze-2026-10-15 data directory")

for path <- ["qualifications", "controls", "repeatability"] do
  if File.exists?(Store.path(path)), do: raise("Existing evidence must be preserved: #{path}")
end

release = Release.freeze()
Store.write("repeatability/plan.json", %{
  "release" => release["id"],
  "rounds" => 3,
  "test_seed" => 0,
  "lookahead" => 1,
  "preparation_workers" => 1,
  "qualification_receipt_reuse" => false,
  "runner_sha256" => Inventory.hash_file(__ENV__.file)
})

# Exclude raw output and ordering of equivalent detected-test lists. Keep every
# named test state, exclusion, failure phase/type and coverage decision.
normalize = fn normalize, value ->
  cond do
    is_map(value) ->
      value
      |> Map.drop(["output"])
      |> Map.new(fn
        {key, values} when key in ["detected_tests", "submitted_test_files", "auxiliary_files"] ->
          {key, Enum.sort(values)}

        {key, child} -> {key, normalize.(normalize, child)}
      end)

    is_list(value) -> Enum.map(value, &normalize.(normalize, &1))
    true -> value
  end
end

for round <- 1..3 do
  :ok = Release.verify!(release)
  IO.puts("REPEATABILITY ROUND #{round}/3")
  report = Qualification.run(&IO.puts/1,
    id: "case-freeze-round-#{round}", lookahead: 1, preparation_workers: 1)

  unless report["status"] == "qualified" and report["release"] == release["id"],
    do: raise("Round #{round} did not qualify the frozen release; keep failed evidence")

  summaries = Map.new(Inventory.all(), fn id ->
    control = Store.read("controls/#{id}.json")
    runtime = Store.read("runtimes/#{id}.json")
    unless control["valid"] and control["identity"] == Grader.qualification_identity(id, runtime),
      do: raise("Stale qualification for #{id}")
    {id, normalize.(normalize, control)}
  end)

  Store.write("repeatability/round-#{round}/outcomes.json", summaries)
  File.rename!(Store.path("controls"), Store.path("repeatability/round-#{round}/controls"))
  File.rename!(Store.path("qualifications"), Store.path("repeatability/round-#{round}/qualifications"))

  if round > 1 do
    first = Store.read("repeatability/round-1/outcomes.json")
    unless summaries == first do
      changed = for {id, row} <- summaries, first[id] != row, do: id
      Store.write("repeatability/disagreement-round-#{round}.json", %{"cases" => changed})
      raise("Qualification outcomes differ: #{inspect(changed)}; retain every result")
    end
  end
  IO.puts("REPEATABILITY ROUND #{round} COMPLETE: 44 expected control outcomes")
end

:ok = Release.verify!(release)
Store.write("repeatability/result.json", %{
  "release" => release["id"],
  "status" => "repeatable",
  "rounds" => 3,
  "cases" => Inventory.all(),
  "expected_control_outcomes" => 132,
  "named_test_outcomes_identical" => true,
  "test_seed" => 0,
  "model_calls" => 0
})
IO.puts("REPEATABILITY COMPLETE: 11 cases, 3 fresh rounds, 132 expected controls")
