Code.require_file("original_case_audit.exs", __DIR__)

# A second test order in fresh offline workspaces; no timing measurements.
{:ok, _} = Registry.start_link(keys: :duplicate, name: Eab.Commands)
{:ok, _} = Application.ensure_all_started(:req)
ids = if System.argv() == [], do: OriginalCaseAudit.all(), else: System.argv()

results =
  OriginalCaseAudit.map(ids, fn id ->
    IO.puts("REFERENCE REPEAT #{id}")

    try do
      result =
        Eab.Sandbox.with_box(id, "task-audit-repeat", fn box ->
          Eab.Sandbox.apply_patch(box, Eab.Inventory.file(id, "reference.patch"))
          Eab.Sandbox.apply_patch(box, Eab.Inventory.file(id, box.spec["acceptance_patch"]))
          Eab.TestAdapter.install(box)
          Eab.Grader.run_tests(box, box.spec["acceptance_command"] <> " --seed 101")
        end)

      expected = Eab.Store.read("controls/#{id}.json")["reference_patch"]["hidden"]
      result = Eab.Grader.control_tests(result, expected)
      Eab.Store.write("audit-results/#{id}-reference-seed101.json", result)
      IO.puts("REFERENCE RESULT #{id} #{result["passed"]}")
      result["passed"]
    rescue
      error ->
        Eab.Store.write("audit-results/#{id}-reference-seed101.json", %{
          "error" => Exception.message(error),
          "passed" => false
        })

        IO.puts("REFERENCE ERROR #{id}: #{Exception.message(error)}")
        false
    end
  end)

unless Enum.all?(results), do: System.halt(1)
