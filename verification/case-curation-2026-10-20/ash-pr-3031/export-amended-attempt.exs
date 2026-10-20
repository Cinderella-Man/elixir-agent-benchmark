alias Eab.{Cache, Checkpoints, Evidence, Inventory, Store}
id = "ash-pr-3031"
run_id = "20261020-160506-224bb2fa"
run = Store.run(run_id)
unless run["status"] == "completed" and run["cleanup_pending"] == false, do: raise("Attempt still active")
a = Checkpoints.completed(run, id) || raise("Missing sealed completion")
{:ok, {submission, patch}} = Checkpoints.submission(run, id)
base = "runs/#{run_id}/#{id}"
g = Store.read("#{base}/grade.json")
Code.require_file("qualification-outcomes.exs", __DIR__)
Code.require_file("evidence-binding.exs", __DIR__)
ref = Store.read("releases/#{run["release_id"]}/cases/#{id}/admission.json")["candidate"]
prefix = "curation/#{id}/#{ref["version"]}"
binding = Curation.EvidenceBinding.verify_run!(base, Store.read("#{prefix}/preflight.json"), &AshCuration.Outcomes.normalize/1)
usages = Path.wildcard(Store.path("#{base}/usage-*.json")) |> Enum.map(&Inventory.read_json/1)
unless Enum.sum(Enum.map(usages, & &1["output_tokens"])) == a["generated_tokens"] and length(usages) == a["calls"], do: raise("Usage ledger mismatch")
unless a["measurement"] == %{"disabled" => "functional_validation_machine_policy"}, do: raise("Unexpected measurement")
record = %{
  "run_id" => run_id, "qualification_binding" => binding,
  "review_disposition" => "rejected_preservation_regressions", "accepted_validation_success" => false,
  "usage_ledger_verified" => true,
  "candidate" => Store.read("releases/#{run["release_id"]}/cases/#{id}/admission.json")["candidate"],
  "status" => run["status"], "cleanup_pending" => run["cleanup_pending"],
  "release_id" => run["release_id"], "experiment_id" => run["experiment_id"],
  "model" => run["model"]["model"], "settings" => run["settings"],
  "calls" => a["calls"], "generated_tokens" => a["generated_tokens"],
  "measurement" => a["measurement"],
  "completion_receipt_verified" => true, "submission_receipt_verified" => true,
  "patch_sha256" => Inventory.hash(patch), "official_grading_passed" => g["passed"],
  "named_results" => Map.new(~w(hidden regression submission), &{&1, Map.take(g[&1], ~w(passed completed test_results failure_phases failure_types))}),
  "regression_coverage" => Map.take(g["regression_coverage"], ~w(passed policy reason detected_tests)) |> Map.put("test_probe", Map.take(g["regression_coverage"]["test_probe"], ~w(passed completed test_results failure_phases failure_types))) |> Map.put("broken_test_probe", Map.take(g["regression_coverage"]["broken_test_probe"], ~w(passed completed test_results failure_phases failure_types))),
  "receipt_hashes" => Map.new(~w(attempt.json submission.json grade.json agent-progress.json), &{&1, Inventory.hash_file(Store.path("#{base}/#{&1}"))})
}
File.write!("/tmp/ash-amended-attempt.json", Jason.encode!(record, pretty: true) <> "\n")
File.write!("/tmp/ash-amended-attempt.patch", patch)
IO.puts("Verified sealed completion and submission; exported amended-version attempt")
