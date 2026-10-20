alias Eab.{Candidates, ChatGPTAuth, Inventory, OpenAI, Runs, Store}
ref = Store.read("fork-migration/current.json")
id = ref["id"]
prefix = "fork-migration/#{id}/#{ref["version"]}"
unless Store.read("#{prefix}/preflight.json"), do: raise("Preflight missing")
unless Inventory.all() == [id], do: raise("Expected singleton candidate inventory")
if Inventory.spec(id)["schema_version"] == 2, do: Candidates.verify_admission!(id)
unless Store.read("#{prefix}/preflight.json")["candidate"] == ref and
    Map.delete(Inventory.fixture_hashes(id), "admission.json") == Store.read("#{prefix}/manifest.json")["files"],
  do: raise("Candidate pointer, bundle and preflight differ")
unless Eab.Measurement.start() == :disabled, do: raise("Elapsed-time observer must be disabled")
snapshot = Runs.snapshot()
unless is_nil(snapshot.active) and not snapshot.cleaning and is_nil(snapshot.cleanup_error), do: raise("Controller busy")
path = "#{prefix}/astra-runs.json"
record = Store.read(path) || %{"runs" => []}
unless length(record["runs"]) < 2, do: raise("Two requested attempts already started; review before any retry")
accounts = Enum.filter(ChatGPTAuth.accounts(), &(&1["signed_in"] && &1["plan_enabled"]))
unless length(accounts) == 1, do: raise("Need an unambiguous signed-in benchmark account")
account = hd(accounts)
row = OpenAI.catalog(account["id"]) |> Enum.find(&(&1["slug"] == "gpt-6-astra"))
unless row, do: raise("Astra is unavailable through the benchmark connection")
endpoint = OpenAI.endpoint(account["id"], row)
{:ok, run_id} = Runs.start(endpoint, "", %{"max_tokens" => 262144, "reasoning_effort" => "high"})
Store.write(path, %{"runs" => record["runs"] ++ [run_id]})
IO.puts("ASTRA_FRESH_RUN " <> run_id)
