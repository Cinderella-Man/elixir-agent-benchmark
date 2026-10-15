# Read-only verification of the public freeze. No model or Docker calls.
alias Eab.{Cache, Grader, Inventory, OpenAI, Release, TaskContract}
read = fn file -> Inventory.read_json(Path.join(__DIR__, file)) end
release = read.("release.json")
evidence = read.("evidence.json")
outcomes = read.("qualification-outcomes.json")
plan = read.("validation-plan.json")

unless Cache.key(release["protocol"]) == release["id"] and evidence["release"] == release["id"],
  do: raise("Invalid release identity")

unless evidence["execution_environment"]["deployed_release"] == release["id"],
  do: raise("Recorded deployment differs from the frozen release")

:ok = Release.verify!(release)

unless evidence["model_plan"] == plan and OpenAI.settings(plan["settings"]) == plan["settings"],
  do: raise("Validation plan changed")

connection = read.(plan["readiness"]["inference_check"])

unless plan["readiness"]["account_catalog_verified"] and plan["readiness"]["inference_verified"] and
         connection["status"] == "completed" and connection["http_status"] == 200 and
         connection["model"] == plan["model"] and connection["case_attempts"] == 0 and
         connection["payload"]["reasoning"]["effort"] == plan["settings"]["reasoning_effort"] and
         Enum.any?(connection["catalog"], &(&1["slug"] == plan["model"])),
       do: raise("Invalid subscription eligibility record")

for {file, hash} <- evidence["artifacts_sha256"] do
  unless Path.basename(file) == file and Inventory.hash_file(Path.join(__DIR__, file)) == hash,
    do: raise("Freeze artifact changed: #{file}")
end

for {file, hash} <- evidence["implementation_files"] do
  unless Inventory.hash_file(Inventory.path(file)) == hash,
    do: raise("Benchmark implementation changed: #{file}")
end

for {file, hash} <- evidence["execution_environment"]["build_configuration_sha256"] do
  unless Inventory.hash_file(Inventory.path(file)) == hash,
    do: raise("Build configuration changed: #{file}")
end

unless Inventory.hash_file(Inventory.path("compose.yaml")) ==
         evidence["execution_environment"]["compose_configuration_sha256"],
       do: raise("Compose configuration changed")

ids = Inventory.all()

repetitions = evidence["repeatability"]

unless repetitions["fresh_rounds"] == 3 and repetitions["cases"] == length(ids) and
         repetitions["expected_control_outcomes"] == 3 * 4 * length(ids) and
         repetitions["named_test_outcomes_identical"] and
         repetitions["qualification_receipts_reused"] == false and
         Enum.map(repetitions["rounds"], & &1["round"]) == [1, 2, 3],
       do: raise("Invalid repetition record")

for round <- repetitions["rounds"] do
  unless Enum.sort(Map.keys(round["raw_receipt_sha256"])) == Enum.sort(ids) and
           round["expected_control_outcomes"] == 4 * length(ids),
         do: raise("Incomplete round receipts")
end

recorded_outcomes_hash = Inventory.hash(Jason.encode!(outcomes, pretty: true) <> "\n")

unless Enum.all?(
         repetitions["rounds"],
         &(&1["normalized_outcomes_sha256"] == recorded_outcomes_hash)
       ),
       do: raise("Round outcome hashes disagree with the exported named outcomes")

before =
  Enum.reduce(
    evidence["implementation_changes_after_qualification"],
    evidence["implementation_files"],
    fn change, files ->
      unless files[change["path"]] == change["after"], do: raise("Invalid implementation delta")
      Map.put(files, change["path"], change["before"])
    end
  )

before_hash =
  before |> Enum.sort() |> Enum.map_join(fn {path, hash} -> path <> hash end) |> Inventory.hash()

qualification_protocol = Map.put(release["protocol"], "implementation", before_hash)

unless Cache.key(qualification_protocol) == evidence["qualification_release"],
  do: raise("Qualification release does not match the recorded implementation changes")

unless Enum.map(evidence["cases"], & &1["case"]) == ids and map_size(outcomes) == length(ids),
  do: raise("Wrong case inventory")

for row <- evidence["cases"] do
  id = row["case"]
  unless row["fixture_sha256"] == Inventory.fixture_hashes(id), do: raise("Case changed: #{id}")

  unless row["test_contract"] ==
           Map.take(
             Inventory.spec(id),
             ~w(acceptance_command regression_command acceptance_patch required_acceptance_tests
              permitted_exclusion_tags require_regression_test test_timeout)
           ),
         do: raise("Test contract changed: #{id}")

  unless Inventory.hash_file(Path.join(__DIR__, "inputs/#{id}.json")) ==
           row["input_capture_sha256"],
         do: raise("Captured input changed: #{id}")

  control = outcomes[id]

  unless control["valid"] and control["identity"] == row["qualification_identity"] and
           Grader.qualification_identity(id, row["runtime"]) == control["identity"],
         do: raise("Qualification identity changed: #{id}")

  unless Grader.valid_controls?(
           TaskContract.read(Inventory.spec(id)),
           control["empty_patch"],
           control["reference_patch"],
           control["early_exit"],
           control["partial_repair"]
         ),
         do: raise("Invalid recorded controls: #{id}")
end

IO.puts(
  "Verified frozen release #{release["id"]}: #{length(ids)} cases and recorded three-round evidence."
)

IO.puts("Validation model: #{plan["model"]}; #{plan["model_status"]}.")
IO.puts("This identity check does not rerun tests or establish model solvability.")
