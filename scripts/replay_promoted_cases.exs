# Replay the reviewed, case-specific challenges against the complete v3 grader.
# One workspace at a time; this script never calls a model or measures speed.
defmodule PromotedCaseReplay do
  alias Eab.{Grader, Inventory, Release, Sandbox, Store, TestAdapter}

  def run do
    {:ok, _} = Registry.start_link(keys: :duplicate, name: Eab.Commands)
    {:ok, _} = Application.ensure_all_started(:req)
    release = Release.freeze()
    ids = if System.argv() == [], do: Inventory.all(), else: System.argv()
    audit_file = Inventory.path("docs/verification/task-quality-evidence-2026-10-14.json")
    audits = Inventory.read_json(audit_file)["cases"] |> Map.new(&{&1["case"], &1})

    results =
      for id <- ids do
        Release.verify!(release, id)
        directory = Inventory.path("verification/task-quality/cases/#{id}")
        plan = Inventory.read_json(Path.join(directory, "audit.json"))
        control = Store.read("controls/#{id}.json")
        qualification = Grader.qualification_identity(id, Store.read("runtimes/#{id}.json"))

        unless control && control["valid"] && control["identity"] == qualification,
          do: raise("Missing current qualification: #{id}")

        identity = %{
          "release" => release["id"],
          "qualification" => qualification,
          "runner" => Inventory.hash_file(__ENV__.file),
          "audit_evidence" => Inventory.hash_file(audit_file),
          "plan" => plan
        }

        provenance = Eab.Provenance.verify(id, &IO.puts/1)

        Store.write("promotion-results/#{id}-provenance.json", %{
          "identity" => identity,
          "provenance" => provenance
        })

        variants =
          for variant <- plan["mutants"] ++ (plan["alternatives"] || []) do
            name = variant["name"]

            audited =
              Enum.find(audits[id]["audit_variants"], &(&1["name"] == name)) ||
                raise("Missing original audit variant: #{id}/#{name}")

            expected_failures = audited["distinguishing_behavioral_failures"]

            unless variant["expect"] == "pass" || expected_failures != [],
              do: raise("Missing intended failure identities: #{id}/#{name}")

            IO.puts("REPLAY #{id} #{name}")
            source = source_patch(id, variant)

            # Keep the old submitted tests for negative controls: the newly
            # promoted hidden assertions must detect their actual defects.
            # Positive controls may submit tests matching the revised contract.
            tests =
              if variant["expect"] == "pass",
                do: Inventory.file(id, "reference-tests.patch"),
                else:
                  File.read!(
                    Inventory.path(
                      "verification/task-quality/original/cases/#{id}/reference-tests.patch"
                    )
                  )

            patch = source <> tests
            output = "promotion-results/#{id}-#{name}.json"

            record =
              checked(output, Map.put(identity, "submission", Inventory.hash(patch)), fn ->
                grade =
                  Grader.grade(id, patch, "task-quality-promotion-replay",
                    expected: control["reference_patch"]
                  )

                distinguishing =
                  Grader.behavioral_failures(grade["hidden"] || %{})
                  |> Enum.filter(
                    &(control["reference_patch"]["hidden"]["test_results"][&1] == "passed")
                  )

                met =
                  if variant["expect"] == "pass",
                    do: grade["passed"],
                    else:
                      not grade["passed"] && grade["hidden"]["completed"] &&
                        Enum.any?(distinguishing, &(&1 in expected_failures))

                Store.write_text("promotion-patches/#{id}/#{name}.patch", patch)

                %{
                  "grade" => grade,
                  "expected" => variant["expect"] || "fail",
                  "expected_behavioral_failures" => expected_failures,
                  "distinguishing_behavioral_failures" => distinguishing,
                  "expectation_met" => met
                }
              end)

            IO.puts("REPLAY RESULT #{id} #{name}: #{record["expectation_met"]}")
            record["expectation_met"]
          end

        output = "promotion-results/#{id}-reference-seed101.json"

        repeated =
          checked(output, identity, fn ->
            result =
              Sandbox.with_box(id, "task-quality-promotion-repeat", fn box ->
                Sandbox.apply_patch(box, Inventory.file(id, "reference.patch"))
                Sandbox.apply_patch(box, Inventory.file(id, box.spec["acceptance_patch"]))
                TestAdapter.install(box)
                Grader.run_tests(box, box.spec["acceptance_command"] <> " --seed 101")
              end)
              |> Grader.control_tests(control["reference_patch"]["hidden"])

            %{"result" => result, "expectation_met" => result["passed"]}
          end)

        IO.puts("REFERENCE SEED101 #{id}: #{repeated["expectation_met"]}")
        Enum.all?(variants) && repeated["expectation_met"]
      end

    Release.verify!(release)
    unless Enum.all?(results), do: System.halt(1)
  end

  defp checked(output, identity, fun) do
    previous = Store.read(output)

    if previous && previous["identity"] == identity && previous["expectation_met"] do
      previous
    else
      record =
        try do
          fun.()
        rescue
          error ->
            %{
              "error" => Exception.format(:error, error, __STACKTRACE__),
              "expectation_met" => false
            }
        end
        |> Map.put("identity", identity)

      Store.write(output, record)
      record
    end
  end

  defp source_patch(id, variant) do
    Sandbox.with_box(id, "task-quality-promotion-source", fn box ->
      Sandbox.apply_patch(box, Inventory.file(id, "reference.patch"))

      for replacement <- variant["replacements"] do
        path = replacement["path"]

        unless String.starts_with?(path, ["lib/", "extra/lib/"]) &&
                 not String.contains?(path, ".."),
               do: raise("Invalid mutation path")

        body = Sandbox.command!(box, "cat " <> Eab.Command.quote(path), limit: 4_194_304)
        count = length(String.split(body, replacement["before"])) - 1

        unless count == replacement["count"],
          do: raise("Stale mutation: #{id}/#{variant["name"]}")

        changed = String.replace(body, replacement["before"], replacement["after"])

        unless String.ends_with?(body, "\n") && String.ends_with?(changed, "\n"),
          do: raise("Mutation requires newline-terminated source")

        old = body |> String.split("\n") |> Enum.drop(-1)
        new = changed |> String.split("\n") |> Enum.drop(-1)

        patch =
          "diff --git a/#{path} b/#{path}\n--- a/#{path}\n+++ b/#{path}\n@@ -1,#{length(old)} +1,#{length(new)} @@\n" <>
            Enum.map_join(old, "", &("-" <> &1 <> "\n")) <>
            Enum.map_join(new, "", &("+" <> &1 <> "\n"))

        Sandbox.apply_patch(box, patch)
      end

      Sandbox.patch(box)
    end)
  end
end

PromotedCaseReplay.run()
