Code.require_file("original_case_audit.exs", __DIR__)

# Sequential, model-free baseline qualification in a separate EAB_DATA_DIR.
{:ok, _} = Registry.start_link(keys: :duplicate, name: Eab.Commands)
{:ok, _} = Application.ensure_all_started(:req)

ids = if System.argv() == [], do: OriginalCaseAudit.all(), else: System.argv()

results =
  OriginalCaseAudit.map(ids, fn id ->
    try do
      provenance = Eab.Provenance.verify(id, &IO.puts/1)
      runtime = Eab.Fixtures.ensure(id, &IO.puts/1, run_id: "task-audit-baseline")
      control = Eab.Grader.qualify(id, "task-audit-baseline", &IO.puts/1)

      Eab.Store.write("audit-results/#{id}-baseline.json", %{
        "case" => id,
        "runtime" => runtime,
        "provenance" => provenance,
        "control" => control
      })

      IO.puts("BASELINE VERIFIED #{id}")
      true
    rescue
      error ->
        Eab.Store.write("audit-results/#{id}-baseline-error.json", %{
          "error" => Exception.format(:error, error, __STACKTRACE__)
        })

        IO.puts("BASELINE ERROR #{id}: #{Exception.message(error)}")
        false
    end
  end)

unless Enum.all?(results), do: System.halt(1)
