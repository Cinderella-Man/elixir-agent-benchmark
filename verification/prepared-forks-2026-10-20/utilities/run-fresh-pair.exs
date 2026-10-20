alias Eab.{Checkpoints, Inventory, Runs, Store}
ref = Store.read("fork-migration/current.json")
prefix = "fork-migration/#{ref["id"]}/#{ref["version"]}"
unless is_nil(Store.read("#{prefix}/astra-runs.json")), do: raise("Pair already started; inspect retained attempts")
frozen = Inventory.protocol()

wait = fn wait, run_id, previous ->
  run = Store.run(run_id)
  snapshot = Runs.snapshot()
  state = Map.take(run, ~w(status phase cleanup_pending))
  if state != previous, do: IO.puts(Jason.encode!(%{run_id: run_id, state: state}))
  if snapshot.cleanup_error, do: raise("Run cleanup failed; inspect before continuing")

  if run["status"] in ["completed", "error", "cancelled", "interrupted"] and
      is_nil(snapshot.active) and not snapshot.cleaning and run["cleanup_pending"] == false do
    unless run["status"] == "completed", do: raise("Run did not complete; retain and diagnose")
    completed = Checkpoints.completed(run, ref["id"]) || raise("Missing sealed completion")
    unless completed["grade"]["passed"], do: raise("Graded failure; retain and review before another attempt")
    IO.puts("OFFICIAL_GRADE_PASSED_PENDING_PATCH_REVIEW " <> run_id)
  else
    Process.sleep(30_000)
    wait.(wait, run_id, state)
  end
end

for n <- 1..2 do
  unless Inventory.protocol() == frozen, do: raise("Frozen inputs changed")
  Code.eval_file(Path.join(__DIR__, "validation-preflight.exs"))
  Code.eval_file(Path.join(__DIR__, "start-astra.exs"))
  ids = Store.read("#{prefix}/astra-runs.json")["runs"]
  unless length(ids) == n, do: raise("Unexpected number of fresh attempts")
  wait.(wait, List.last(ids), nil)
end
unless Inventory.protocol() == frozen, do: raise("Frozen inputs changed during pair")
Code.eval_file(Path.join(__DIR__, "export-astra.exs"))
IO.puts("TWO_OFFICIAL_PASSES_EXPORTED_PENDING_INDEPENDENT_PATCH_REVIEW")
