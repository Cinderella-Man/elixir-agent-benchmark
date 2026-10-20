alias Eab.{Candidates, ChatGPTAuth, Inventory, OpenAI, Runs, Store}
id = "ash-pr-3031"
ref = Store.read("curation/#{id}-current.json")
prefix = "curation/#{id}/#{ref["version"]}"
unless Store.read("#{prefix}/preflight.json"), do: raise("Preflight missing")
unless Inventory.all() == [id], do: raise("Expected singleton candidate inventory")
Candidates.verify_admission!(id)
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
