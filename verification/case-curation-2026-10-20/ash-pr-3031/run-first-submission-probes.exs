alias Eab.{Checkpoints, Grader, Inventory, Runs, Sandbox, Store}
%{active: nil, cleaning: false, cleanup_error: nil} = Runs.snapshot()
id = "ash-pr-3031"
run = Store.run("20261020-145143-810635d8")
{:ok, {_record, model_patch}} = Checkpoints.submission(run, id)
results = for {name, patch} <- [{"pristine", ""}, {"reference", File.read!(Inventory.path("cases/#{id}/reference.patch"))}, {"model", model_patch}], into: %{} do
  result = Sandbox.with_box(id, "ash-review-probe-#{name}", fn box ->
    Sandbox.apply_patch(box, patch)
    body = File.read!(Path.join(__DIR__, "first-submission-probes.exs"))
    lines = String.split(String.trim_trailing(body, "\n"), "\n")
    probe = "diff --git a/test/benchmark/review_probe_test.exs b/test/benchmark/review_probe_test.exs\nnew file mode 100644\n--- /dev/null\n+++ b/test/benchmark/review_probe_test.exs\n@@ -0,0 +1,#{length(lines)} @@\n" <> Enum.map_join(lines, "\n", &("+" <> &1)) <> "\n"
    Sandbox.apply_patch(box, probe)
    Sandbox.formatter(box)
    Grader.run_tests(box, "mix test test/benchmark/review_probe_test.exs")
  end)
  Store.write("curation/#{id}/review-probes/#{name}.json", result)
  IO.puts(Jason.encode!(%{variant: name, result: Map.take(result, ~w(passed completed returncode test_results failure_phases failure_types))}))
  {name, result}
end
Store.write("curation/#{id}/review-probes/results.json", results)
