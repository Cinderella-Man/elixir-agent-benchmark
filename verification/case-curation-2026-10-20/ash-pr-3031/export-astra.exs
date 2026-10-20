alias Eab.{Cache, Checkpoints, Evidence, Inventory, Release, Store}
id = "ash-pr-3031"
ref = Store.read("curation/#{id}-current.json")
prefix = "curation/#{id}/#{ref["version"]}"
run_ids = Store.read("#{prefix}/astra-runs.json")["runs"]
unless length(run_ids) == 2, do: raise("Expected two new model runs")
out = "/tmp/ash-astra-evidence"
File.mkdir_p!(out)

records = for {run_id, n} <- Enum.with_index(run_ids, 1) do
  run = Store.run(run_id)
  unless run["status"] == "completed" and run["cleanup_pending"] == false,
    do: raise("Run is not complete and clean")
  unless run["cases"] == [id] and is_nil(run["selection"]) and (run["resume_count"] || 0) == 0,
    do: raise("Expected a fresh ordinary run of only the new case")
  release = Release.read!(run["release_id"])
  unless Store.read("releases/#{release["id"]}/cases/#{id}/admission.json")["candidate"] == ref,
    do: raise("Frozen run admission differs from current candidate")
  Checkpoints.validate_cases!(run, release)
  attempt = Checkpoints.completed(run, id) || raise("No verified completion receipt")
  unless attempt["grade"]["passed"], do: raise("Astra attempt failed")
  unless attempt["measurement"] == %{"disabled" => "functional_validation_machine_policy"},
    do: raise("Unexpected timing data")
  base = "runs/#{run_id}/#{id}"
  for file <- ~w(attempt.json agent-progress.json) do
    saved = Store.read("#{base}/#{file}")
    unless saved["measurement"] == %{"disabled" => "functional_validation_machine_policy"} and
        not String.contains?(Jason.encode!(saved), "\"attempt_ms\""),
      do: raise("Attempt/progress record contains unexpected timing data")
  end
  pi_config = Store.read("#{base}/pi-config.json")
  unless get_in(pi_config, ["settings", "compaction", "enabled"]) == false and
      get_in(pi_config, ["settings", "retry", "enabled"]) == false and
      get_in(pi_config, ["settings", "retry", "provider", "maxRetries"]) == 0,
    do: raise("Unexpected compaction/retry policy")
  unless run["settings"]["max_tokens"] == 262144 and
      run["settings"]["budget_policy"] == "response_boundary_soft_limit",
    do: raise("Unexpected generated-token budget policy")
  grade = Store.read("#{base}/grade.json")
  usages = Path.wildcard(Store.path("#{base}/usage-*.json")) |> Enum.map(&Inventory.read_json/1)
  output = Enum.sum(Enum.map(usages, & &1["output_tokens"]))
  unless output == attempt["generated_tokens"] and length(usages) == attempt["calls"],
    do: raise("Usage ledger mismatch")
  initial = Store.read("#{base}/request-0000.json") |> Map.delete("prompt_cache_key")
  unless initial["model"] == "gpt-6-astra" and initial["reasoning"]["effort"] == "high",
    do: raise("Unexpected model/settings")
  unless Enum.map(initial["input"], & &1["role"]) == ["developer", "user"],
    do: raise("Initial request contains prior context")
  unless grade["regression_coverage"]["passed"], do: raise("No behavioral regression coverage")
  File.cp!(Store.path("#{base}/model.patch"), Path.join(out, "astra-success-#{n}.patch"))
  %{
    "run_id" => run_id, "status" => run["status"], "case" => id,
    "candidate" => ref, "release_id" => run["release_id"], "experiment_id" => run["experiment_id"],
    "scope" => run["cases"], "model" => run["model"]["model"], "settings" => run["settings"],
    "agent" => attempt["agent"], "agent_image" => attempt["agent_image"],
    "calls" => attempt["calls"], "generated_tokens" => output,
    "completion_receipt_verified" => true, "usage_ledger_verified" => true,
    "measurement" => attempt["measurement"],
    "compaction_enabled" => false, "automatic_retries" => 0,
    "initial_request_roles" => Enum.map(initial["input"], & &1["role"]),
    "grade" => Evidence.summarize(grade),
    "named_results" => Map.new(~w(hidden regression submission),
      &{&1, Map.take(grade[&1], ~w(passed completed test_results failure_phases failure_types))}),
    "regression_coverage" => grade["regression_coverage"]
      |> Map.take(~w(passed policy reason detected_tests))
      |> Map.put("test_probe",
        Map.take(grade["regression_coverage"]["test_probe"],
          ~w(passed completed test_results failure_phases failure_types)))
      |> Map.put("broken_test_probe",
        Map.take(grade["regression_coverage"]["broken_test_probe"],
          ~w(passed completed test_results failure_phases failure_types))),
    "frozen_hashes" => Map.new(~w(prompt.md instructions.md pi-config.json runtime.json qualification.json),
      &{&1, Inventory.hash_file(Store.path("#{base}/#{&1}"))}),
    "receipt_hashes" => Map.new(~w(attempt.json submission.json grade.json agent-progress.json),
      &{&1, Inventory.hash_file(Store.path("#{base}/#{&1}"))}),
    "completion_receipt_sha256" => Inventory.hash_file(Store.path("runs/#{run_id}/checkpoints/#{id}.json")),
    "initial_request_without_session_hash" => Cache.key(initial),
    "patch_sha256" => Inventory.hash_file(Store.path("#{base}/model.patch"))
  }
end
[first, second] = records
for key <- ~w(release_id experiment_id scope model settings agent agent_image frozen_hashes initial_request_without_session_hash) do
  unless first[key] == second[key], do: raise("Frozen inputs differ: #{key}")
end
[a, b] = Enum.map(run_ids, &Store.read("runs/#{&1}/#{id}/request-0000.json"))
unless is_binary(a["prompt_cache_key"]) and is_binary(b["prompt_cache_key"]) and
    a["prompt_cache_key"] != b["prompt_cache_key"],
  do: raise("Expected distinct fresh session keys")
preflight = Store.read("#{prefix}/preflight.json")
record = %{
  "schema" => 1, "functional_validation_only" => true,
  "two_fresh_blind_runs" => true, "distinct_session_keys" => true,
  "matching_frozen_inputs" => true, "serving_revision_available" => false,
  "prior_attempts" => [Inventory.read_json(Path.join(__DIR__, "astra-1.json"))],
  "runs" => records
}
File.write!(Path.join(out, "astra-results.json"), Jason.encode!(record, pretty: true) <> "\n")
File.write!(Path.join(out, "validation-preflight.json"), Jason.encode!(preflight, pretty: true) <> "\n")
File.cp!(Store.path("#{prefix}/measurement.ex"), Path.join(out, "validation-measurement.ex"))
File.write!(Path.join(out, "bundle-sha256.json"),
  Jason.encode!(Inventory.fixture_hashes(id), pretty: true) <> "\n")
IO.puts("Verified and exported two fresh Astra solver successes, matching frozen inputs, and disabled timing observer")
