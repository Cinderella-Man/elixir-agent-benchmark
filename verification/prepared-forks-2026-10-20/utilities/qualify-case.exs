alias Eab.{Cache, Candidates, Command, Fixtures, Grader, Inventory, Provenance, Runs, Sandbox, Store}
Code.require_file("qualification-outcomes.exs", __DIR__)
job = Inventory.read_json(Path.join(__DIR__, "job.json"))
id = job["case"]
%{active: nil, cleaning: false, cleanup_error: nil} = Runs.snapshot()
unless Inventory.all() == [], do: raise("Qualification requires empty active inventory")
draft = Path.join(__DIR__, "draft")
hashes = Map.new(File.ls!(draft), &{&1, Inventory.hash_file(Path.join(draft, &1))})
unless hashes == job["draft_hashes"], do: raise("Draft changed since independent source review")
unless not Map.has_key?(hashes, "environment.patch") and not Map.has_key?(hashes, "admission.json"),
  do: raise("Expected prepared source and an unadmitted draft")
spec = Inventory.read_json(Path.join(draft, "case.json"))
Eab.TaskContract.read(spec)
review = Inventory.read_json(Path.join(__DIR__, "review.json"))
unless review["decision"] == "approve" and review["author"] != review["reviewer"] and
    review["requirements_read_before_checks"] and review["assertion_mapping_checked"],
  do: raise("Independent source/contract review missing")
ref = if spec["schema_version"] == 2 do
  ref = Candidates.import(draft)
  Candidates.review(ref, review)
  ref
else
  %{"id" => id, "version" => Cache.key(hashes)}
end
prefix = "fork-migration/#{id}/#{ref["version"]}"
files = Store.path("#{prefix}/files")
for {file, hash} <- hashes do
  body = File.read!(Path.join(draft, file))
  unless Inventory.hash(body) == hash, do: raise("Draft changed while copying")
  Store.write_text("#{prefix}/files/#{file}", body)
end
Store.write("#{prefix}/manifest.json", %{"candidate" => ref, "files" => hashes, "schema_version" => spec["schema_version"]})
Store.write("#{prefix}/review.json", review)
Store.write("fork-migration/current.json", ref)
run_id = "fork-migration-#{id}"
Eab.Retention.lease(run_id)
try do
  Inventory.with_case(id, files, fn ->
    source = Provenance.verify(id, &IO.puts/1)
    runtime = Fixtures.ensure(id, &IO.puts/1, run_id: run_id)
    provenance = Inventory.read_json(Inventory.case_path(id, "provenance.json"))
    actual_tree = Command.run!("docker", ["run", "--rm", "--read-only", "--network=none",
      "--cap-drop=ALL", "--cpus=1", "--memory=256m", "--entrypoint", "git", "-w", "/workspace",
      runtime["image"], "rev-parse", "HEAD^{tree}"], timeout: 60) |> String.trim()
    unless actual_tree == provenance["broken_tree"],
      do: raise("Runtime setup changed the prepared source tree")
    Store.write("#{prefix}/prepared-source-tree.json", %{"image" => runtime["image"], "tree" => actual_tree, "matches_pinned_fork" => true})
    identity = Grader.qualification_identity(id, runtime)
    cache = "qualifications/#{Cache.key(identity)}.json"
    for round <- 1..3 do
      destination = "#{prefix}/qualification-round-#{round}.json"
      proof = case Store.read(destination) do
        nil ->
          if File.exists?(Store.path(cache)) do
            body = File.read!(Store.path(cache))
            archive = "#{prefix}/qualification-cache-before-round-#{round}-#{Inventory.hash(body)}.json"
            Store.write_text(archive, body)
            File.rm!(Store.path(cache))
          end
          proof = if spec["schema_version"] == 2 do
            Candidates.qualify(ref, &IO.puts/1)
            Store.read("candidates/#{id}/#{ref["version"]}/qualification.json")
          else
            controls = Grader.qualify(id, run_id, &IO.puts/1)
            proof = %{"candidate" => ref, "source" => source, "runtime" => runtime,
              "controls" => controls, "grader" => Inventory.qualification_hash()}
            Map.put(proof, "checksum", Cache.key(proof))
          end
          Store.write(destination, proof)
          IO.puts("FRESH_QUALIFICATION_ROUND #{round}")
          proof
        saved ->
          IO.puts("VERIFYING_RETAINED_FRESH_ROUND #{round}")
          saved
      end
      unless proof["checksum"] == Cache.key(Map.delete(proof, "checksum")) and
          proof["candidate"] == ref and proof["controls"]["identity"] == identity and
          proof["controls"]["valid"] and proof["grader"] == Inventory.qualification_hash(),
        do: raise("Qualification proof does not match current source/runtime/grader")
      first = Store.read("#{prefix}/qualification-round-1.json")
      unless ForkMigration.Outcomes.normalize(proof) == ForkMigration.Outcomes.normalize(first),
        do: raise("Named outcomes, completion, phases or failure types differ")
    end
    first = Store.read("#{prefix}/qualification-round-1.json")
    Store.write("#{prefix}/matching-controls.json", ForkMigration.Outcomes.normalize(first))
    output = Path.join(__DIR__, "export/#{id}")
    if File.exists?(output), do: raise("Export destination exists")
    if spec["schema_version"] == 2 do
      Candidates.export(ref, output)
    else
      File.mkdir_p!(output)
      for {file, _} <- hashes, do: File.cp!(Path.join(files, file), Path.join(output, file))
    end
    evidence = Path.join(__DIR__, "evidence")
    File.mkdir_p!(evidence)
    for round <- 1..3 do
      path = "#{prefix}/qualification-round-#{round}.json"
      proof = Store.read(path)
      normalized = ForkMigration.Outcomes.normalize(proof)
      summary = %{"candidate" => ref, "round" => round, "fresh_controls" => true,
        "valid" => proof["controls"]["valid"], "source" => proof["source"],
        "grader" => proof["grader"], "runtime" => Map.take(proof["runtime"], ~w(image services baseline base_image toolchain_image)),
        "named_outcomes" => normalized, "named_outcomes_hash" => Cache.key(normalized),
        "private_receipt_sha256" => Inventory.hash_file(Store.path(path))}
      File.write!(Path.join(evidence, "qualification-round-#{round}.json"), Jason.encode!(summary, pretty: true) <> "\n")
    end
    File.write!(Path.join(evidence, "prepared-source-tree.json"), Jason.encode!(Store.read("#{prefix}/prepared-source-tree.json"), pretty: true) <> "\n")
    IO.puts("THREE_FRESH_MATCHING_ROUNDS_AND_BUNDLE_EXPORTED " <> Jason.encode!(ref))
  end)
after
  Sandbox.cleanup(run_id)
  Eab.Retention.release(run_id)
end
