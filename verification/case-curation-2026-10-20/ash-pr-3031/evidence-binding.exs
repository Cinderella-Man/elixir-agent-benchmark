defmodule Curation.EvidenceBinding do
  alias Eab.{Cache, Command, Fixtures, Grader, Inventory, Store}
  @runtime_fields ~w(image services baseline base_image node_image toolchain_image inputs source_receipt)

  def preflight!(id, ref, prefix, normalize) do
    proofs = for n <- 1..3, do: Store.read("#{prefix}/qualification-round-#{n}.json")
    matching = Store.read("#{prefix}/matching-controls.json")
    runtime = Fixtures.ensure(id, &IO.puts/1)
    identity = Grader.qualification_identity(id, runtime)
    environment = Map.take(runtime, @runtime_fields)

    for proof <- proofs do
      unless proof["candidate"] == ref and proof["controls"]["valid"] and
          proof["grader"] == Inventory.qualification_hash() and
          proof["checksum"] == Cache.key(Map.delete(proof, "checksum")) and
          proof["controls"]["identity"] == identity and
          Map.take(proof["runtime"], @runtime_fields) == environment and
          normalize.(proof) == matching,
        do: raise("Qualification rounds do not match the current runtime and named outcomes")
    end

    provenance = Inventory.read_json(Inventory.case_path(id, "provenance.json"))
    actual_tree = Command.run!("docker", ["run", "--rm", "--read-only", "--network=none",
      "--cap-drop=ALL", "--cpus=1", "--memory=256m", "--entrypoint", "git", "-w", "/workspace",
      runtime["image"], "rev-parse", "HEAD^{tree}"], timeout: 60) |> String.trim()
    unless actual_tree == provenance["broken_tree"] and
        Enum.all?(proofs, &(&1["source"]["broken"]["tree"] == actual_tree)),
      do: raise("Prepared runtime source tree differs from the pinned qualified source")
    source_tree = %{"image" => runtime["image"], "tree" => actual_tree, "matches_pinned_fork" => true}
    prior_tree = Store.read("#{prefix}/prepared-source-tree.json")
    if prior_tree && prior_tree != source_tree, do: raise("Previously verified source image changed")
    Store.write("#{prefix}/prepared-source-tree.json", source_tree)

    binding = %{
      "qualification_identity" => identity,
      "qualification_identity_hash" => Cache.key(identity),
      "qualification_receipts" => for(n <- 1..3,
        do: Inventory.hash_file(Store.path("#{prefix}/qualification-round-#{n}.json"))),
      "named_outcomes_hash" => Cache.key(matching),
      "runtime" => environment,
      "source" => hd(proofs)["source"],
      "prepared_source_tree" => source_tree
    }
    prior = Store.read("#{prefix}/preflight.json")
    if prior && Map.take(prior, Map.keys(binding)) != binding,
      do: raise("Evidence binding changed between solver launches")
    binding
  end

  def verify_run!(base, binding, normalize) do
    controls = Store.read("#{base}/qualification.json")
    runtime = Store.read("#{base}/runtime.json")
    unless controls["valid"] and controls["identity"] == binding["qualification_identity"] and
        Cache.key(normalize.(%{"controls" => controls})) == binding["named_outcomes_hash"] and
        Map.take(runtime, @runtime_fields) == binding["runtime"] and
        runtime["image"] == binding["prepared_source_tree"]["image"],
      do: raise("Solver evidence does not match the three reviewed qualification rounds")
    %{
      "qualification_identity_hash" => binding["qualification_identity_hash"],
      "qualification_receipts" => binding["qualification_receipts"],
      "named_outcomes_hash" => binding["named_outcomes_hash"],
      "prepared_source_tree" => binding["prepared_source_tree"]
    }
  end
end
