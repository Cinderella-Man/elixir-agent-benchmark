# Functional positive control after recheck.exs; one isolated workspace.
alias Eab.{Fixtures, Grader, Inventory, Store}
{:ok, _} = Registry.start_link(keys: :duplicate, name: Eab.Commands)
{:ok, _} = Application.ensure_all_started(:req)

id = "plausible-pr-5956"
Fixtures.ensure(id, &IO.puts/1)
control = Store.read("controls/#{id}.json")
unless control["valid"] and
         control["identity"] == Grader.qualification_identity(id, Store.read("runtimes/#{id}.json")),
       do: raise("Requires current qualification from recheck.exs")

source = File.read!(Path.join(__DIR__, "plausible-5956-alternative.patch"))
patch = source <> Inventory.file(id, "reference-tests.patch")
grade = Grader.grade(id, patch, "readiness-minimal-tracker", expected: control["reference_patch"])

record = %{
  "case" => id,
  "fixtures" => Inventory.fixture_hashes(id),
  "qualification" => control["identity"],
  "script" => Inventory.hash_file(__ENV__.file),
  "source_sha256" => Inventory.hash(source),
  "submission_sha256" => Inventory.hash(patch),
  "grade" => grade
}
Store.write("readiness/tracker-alternative.json", record)
IO.puts("TWO-FILE TRACKER ALTERNATIVE PASSED: #{grade["passed"]}")
unless grade["passed"], do: System.halt(1)
