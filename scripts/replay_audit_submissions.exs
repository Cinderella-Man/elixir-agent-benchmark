Code.require_file("original_case_audit.exs", __DIR__)

# Check whether a supplemental-test survivor actually passes the original
# complete grader, including preservation and the submitted-test requirement.
{:ok, _} = Registry.start_link(keys: :duplicate, name: Eab.Commands)
{:ok, _} = Application.ensure_all_started(:req)
plans = System.fetch_env!("EAB_AUDIT_PLANS")
ids = if System.argv() == [], do: OriginalCaseAudit.all(), else: System.argv()

OriginalCaseAudit.map(ids, fn id ->
  plan = Eab.Inventory.read_json(Path.join([plans, id, "audit.json"]))
  baseline = Eab.Store.read("audit-results/#{id}-baseline.json")
  original_names = baseline["control"]["reference_patch"]["hidden"]["test_results"]

  for mutant <- plan["mutants"] do
    name = mutant["name"]
    audit = Eab.Store.read("audit-results/#{id}-#{name}.json")

    # Only claim an old-oracle gap when all original acceptance identities
    # passed in the augmented run and a supplemental behavioral check failed.
    survived =
      audit && audit["expectation_met"] &&
        Enum.all?(original_names, fn {test, state} ->
          audit["result"]["test_results"][test] == state
        end)

    if survived do
      source = Eab.Store.path("audit-patches/#{id}/#{name}.patch")
      patch = File.read!(source) <> Eab.Inventory.file(id, "reference-tests.patch")

      identity = %{
        "submission" => Eab.Inventory.hash(patch),
        "qualification" =>
          Eab.Grader.qualification_identity(id, Eab.Store.read("runtimes/#{id}.json"))
      }

      output = "audit-results/#{id}-#{name}-full-grade.json"
      saved = Eab.Store.read(output)

      unless saved && saved["identity"] == identity && saved["grade"] do
        IO.puts("FULL GRADE #{id} #{name}")

        result =
          try do
            %{
              "identity" => identity,
              "grade" => Eab.Grader.grade(id, patch, "task-audit-scoring")
            }
          rescue
            error ->
              %{
                "identity" => identity,
                "error" => Exception.format(:error, error, __STACKTRACE__)
              }
          end

        Eab.Store.write(output, result)
        IO.puts("FULL GRADE RESULT #{id} #{name}: #{get_in(result, ["grade", "passed"])}")
      end
    end
  end
end)
