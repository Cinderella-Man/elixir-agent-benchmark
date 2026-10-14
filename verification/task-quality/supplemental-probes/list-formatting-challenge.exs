{:ok, _} = Registry.start_link(keys: :duplicate, name: Eab.Commands)
{:ok, _} = Application.ensure_all_started(:req)
id = "livebook-pr-2663"
result = Eab.Sandbox.with_box(id, "task-audit-list-fairness", fn box ->
  Eab.Sandbox.apply_patch(box, Eab.Inventory.file(id, "reference.patch"))
  patch = """
  diff --git a/lib/livebook/live_markdown/markdown_helpers.ex b/lib/livebook/live_markdown/markdown_helpers.ex
  --- a/lib/livebook/live_markdown/markdown_helpers.ex
  +++ b/lib/livebook/live_markdown/markdown_helpers.ex
  @@ -382,7 +382,7 @@
   
     defp render_ordered_list(content) do
       marker_fun = fn index -> "\#{index + 1}. " end
  -    indent_fun = fn index -> number_of_digits(index + 1) + 2 end
  +    indent_fun = fn index -> number_of_digits(index + 1) + 2 + if(index >= 9, do: 1, else: 0) end
       render_list(content, marker_fun, indent_fun)
     end
   
  """
  Eab.Sandbox.apply_patch(box, patch)
  Eab.TestAdapter.install(box)
  preservation = Eab.Grader.run_tests(box, box.spec["regression_command"])
  Eab.Sandbox.apply_patch(box, Eab.Inventory.file(id, box.spec["acceptance_patch"]))
  acceptance = Eab.Grader.run_tests(box, box.spec["acceptance_command"])
  Eab.Sandbox.apply_patch(box, File.read!("verification/task-quality/cases/#{id}/acceptance.patch"))
  semantic = Eab.Grader.run_tests(box, "mix test test/benchmark_list_structure_test.exs")
  %{"preservation" => preservation, "acceptance" => acceptance, "semantic" => semantic}
end)
Eab.Store.write("audit-results/livebook-pr-2663-additional-fairness-probe.json", result)
IO.inspect(Map.new(result, fn {k,v} -> {k,v["passed"]} end))
