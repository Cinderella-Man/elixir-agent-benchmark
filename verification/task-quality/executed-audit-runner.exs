# Run with `mix run --no-start scripts/audit_cases.exs [case-id ...]` in the
# tooling image. EAB_DATA_DIR must point to a separate audit data directory.
# Preparation records and immutable images may be reused; never share the
# active controller's writable data directory. This is correctness work only.
defmodule CaseAudit do
  alias Eab.{Grader, Inventory, Sandbox, Store, TestAdapter}

  def run do
    {:ok, _} = Registry.start_link(keys: :duplicate, name: Eab.Commands)
    {:ok, _} = Application.ensure_all_started(:req)
    plans = System.fetch_env!("EAB_AUDIT_PLANS")
    ids = if System.argv() == [], do: Inventory.all(), else: System.argv()
    runner_hash = Inventory.hash_file(__ENV__.file)

    outcomes =
      for id <- ids do
        directory = Path.join(plans, id)
        plan = Inventory.read_json(Path.join(directory, "audit.json"))

        variants =
          [
            %{"name" => "starting", "expect" => "fail", "reference" => false},
            %{"name" => "reference", "expect" => "pass", "reference" => true}
          ] ++
            Enum.map(
              plan["mutants"] ++ (plan["alternatives"] || []),
              &Map.put(&1, "reference", true)
            )

        for variant <- variants do
          name = variant["name"]

          identity = %{
            "case_files" => Inventory.fixture_hashes(id),
            "runtime" =>
              Map.take(Store.read("runtimes/#{id}.json"), ["image", "services", "baseline"]),
            "grader" => Inventory.qualification_hash(),
            "runner" => runner_hash,
            "plan" => plan,
            "variant" => variant,
            "files" =>
              Map.new(
                Path.wildcard(Path.join(directory, "*.patch")),
                &{Path.basename(&1), Inventory.hash_file(&1)}
              )
          }

          output = "audit-results/#{id}-#{name}.json"
          previous = Store.read(output)

          if previous && previous["identity"] == identity && previous["expectation_met"] do
            IO.puts("AUDIT REUSE #{id} #{name}")
          else
            IO.puts("AUDIT START #{id} #{name}")

            record =
              try do
                result = probe(id, directory, plan, variant)
                expected = variant["expect"] || "fail"
                failures = Grader.behavioral_failures(result)

                met =
                  if expected == "pass",
                    do: result["passed"],
                    else: result["completed"] && failures != []

                %{
                  "identity" => identity,
                  "result" => result,
                  "behavioral_failures" => failures,
                  "expectation_met" => met
                }
              rescue
                error ->
                  %{
                    "identity" => identity,
                    "error" => Exception.format(:error, error, __STACKTRACE__),
                    "expectation_met" => false
                  }
              end

            Store.write(output, record)
            IO.puts("AUDIT RESULT #{id} #{name}: #{record["expectation_met"]}")
          end

          Store.read(output)["expectation_met"]
        end
      end

    unless Enum.all?(List.flatten(outcomes)), do: System.halt(1)
  end

  defp probe(id, directory, plan, variant) do
    Sandbox.with_box(id, "task-quality-audit", fn box ->
      if variant["reference"], do: Sandbox.apply_patch(box, Inventory.file(id, "reference.patch"))

      for replacement <- variant["replacements"] || [] do
        path = replacement["path"]

        unless String.starts_with?(path, ["lib/", "extra/lib/"]) &&
                 not String.contains?(path, ".."), do: raise("Invalid mutation path")

        body = Sandbox.command!(box, "cat " <> Eab.Command.quote(path), limit: 4_194_304)
        count = length(String.split(body, replacement["before"])) - 1

        unless count == replacement["count"],
          do:
            raise(
              "Stale mutation #{variant["name"]}: #{path}, expected #{replacement["count"]}, got #{count}"
            )

        changed = String.replace(body, replacement["before"], replacement["after"])
        # Apply as the workspace owner. Container root has no DAC capabilities
        # and must not be used to overwrite agent-owned source directories.
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

      Store.write_text("audit-patches/#{id}/#{variant["name"]}.patch", Sandbox.patch(box))
      TestAdapter.install(box)

      legacy =
        if variant["expect"] == "pass" && variant["name"] != "reference" do
          preservation = Grader.run_tests(box, box.spec["regression_command"])
          Sandbox.apply_patch(box, Inventory.file(id, box.spec["acceptance_patch"]))
          acceptance = Grader.run_tests(box, box.spec["acceptance_command"])

          Sandbox.command!(
            box,
            "git restore --source=HEAD --staged --worktree -- test && git clean -fd -- test"
          )

          %{"preservation" => preservation, "acceptance" => acceptance}
        end

      replacement = Path.join(directory, "replacement-acceptance.patch")

      acceptance =
        if File.regular?(replacement),
          do: File.read!(replacement),
          else: Inventory.file(id, box.spec["acceptance_patch"])

      Sandbox.apply_patch(box, acceptance)
      extra = Path.join(directory, "acceptance.patch")
      if File.regular?(extra), do: Sandbox.apply_patch(box, File.read!(extra))

      command =
        box.spec["acceptance_command"] <>
          " " <> Enum.map_join(plan["test_files"] || [], " ", &Eab.Command.quote/1)

      Grader.run_tests(box, command) |> Map.put("legacy_oracle", legacy)
    end)
  end
end

CaseAudit.run()
