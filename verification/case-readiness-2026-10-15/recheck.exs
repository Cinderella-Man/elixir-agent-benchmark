# Case-readiness audit: functional checks only, one case at a time.
# Run with mix run --no-start and a separate EAB_DATA_DIR. No model calls.
alias Eab.{Grader, Inventory, Qualification, Sandbox, Store}

{:ok, _} = Registry.start_link(keys: :duplicate, name: Eab.Commands)
{:ok, _} = Task.Supervisor.start_link(name: Eab.Tasks)
{:ok, _} = Application.ensure_all_started(:req)

report =
  Qualification.run(&IO.puts/1,
    id: "case-readiness-2026-10-15",
    lookahead: 1,
    preparation_workers: 1
  )

unless report["status"] == "qualified", do: raise("Qualification incomplete")

# This repair preserves an existing same-site association for malformed input.
# The older, detailed ticket prohibited that behavior; today's short ticket
# does not settle it. Replay it to establish the actual scoring consequence.
id = "plausible-pr-6449"
plan = Inventory.read_json(Inventory.path("verification/task-quality/cases/#{id}/audit.json"))
[variant] = plan["mutants"]
[replacement] = variant["replacements"]

source =
  Sandbox.with_box(id, "readiness-policy-alternative", fn box ->
    Sandbox.apply_patch(box, Inventory.file(id, "reference.patch"))
    path = replacement["path"]
    before = Sandbox.command!(box, "cat " <> Eab.Command.quote(path), limit: 4_194_304)
    count = length(String.split(before, replacement["before"])) - 1
    unless count == replacement["count"], do: raise("Stale alternative")
    after_ = String.replace(before, replacement["before"], replacement["after"])
    old = before |> String.split("\n") |> Enum.drop(-1)
    new = after_ |> String.split("\n") |> Enum.drop(-1)

    patch =
      "diff --git a/#{path} b/#{path}\n--- a/#{path}\n+++ b/#{path}\n@@ -1,#{length(old)} +1,#{length(new)} @@\n" <>
        Enum.map_join(old, "", &("-" <> &1 <> "\n")) <>
        Enum.map_join(new, "", &("+" <> &1 <> "\n"))

    Sandbox.apply_patch(box, patch)
    Sandbox.patch(box)
  end)

submitted_tests =
  File.read!(Inventory.path("verification/task-quality/original/cases/#{id}/reference-tests.patch"))

patch = source <> submitted_tests
control = Store.read("controls/#{id}.json")
result = Grader.grade(id, patch, "readiness-policy-alternative", expected: control["reference_patch"])
failures = Grader.behavioral_failures(result["hidden"] || %{})
intended = "Elixir.Plausible.Benchmark.AuditSharedLinkEditingTest::test malformed and nonexistent segment selections clear existing associations on edit"

record = %{
  "case" => id,
  "variant" => variant,
  "release" => report["release"],
  "fixtures" => Inventory.fixture_hashes(id),
  "qualification" => control["identity"],
  "script" => Inventory.hash_file(__ENV__.file),
  "submission_sha256" => Inventory.hash(patch),
  "grade" => result,
  "behavioral_failures" => failures,
  "expected_policy_rejection_observed" =>
    result["passed"] == false and result["hidden"]["completed"] == true and
      intended in failures and result["submission"]["passed"] == true and
      result["regression"]["passed"] == true
}

Store.write_text("readiness/policy-alternative.patch", patch)
Store.write("readiness/policy-alternative.json", record)
IO.puts("POLICY ALTERNATIVE REJECTED: #{record["expected_policy_rejection_observed"]}")
unless record["expected_policy_rejection_observed"], do: raise("Policy probe needs investigation")
