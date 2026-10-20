alias Eab.{Inventory, Store}
Code.require_file("qualification-outcomes.exs", __DIR__)
Code.require_file("evidence-binding.exs", __DIR__)
ref = Store.read("curation/ash-pr-3031-current.json")
prefix = "curation/ash-pr-3031/#{ref["version"]}"
binding = Store.read("#{prefix}/preflight.json")
proof = Store.read("#{prefix}/qualification-round-3.json")
base = "#{prefix}/binding-diagnostic"
unless not File.exists?(Store.path(base)), do: raise("Diagnostic destination exists")

variants = [
  {"matching_reviewed_receipts", proof["controls"], proof["runtime"], true},
  {"changed_project_image", proof["controls"], Map.put(proof["runtime"], "image", "changed"), false},
  {"changed_service_images", proof["controls"], Map.put(proof["runtime"], "services", %{"changed" => true}), false},
  {"changed_database_baseline", proof["controls"], Map.put(proof["runtime"], "baseline", %{"changed" => true}), false},
  {"changed_qualification_identity", Map.put(proof["controls"], "identity", %{}), proof["runtime"], false},
  {"changed_named_outcome",
    put_in(proof["controls"], ["reference_patch", "hidden", "test_results"], %{"changed" => "passed"}),
    proof["runtime"], false}
]

try do
  results = for {name, controls, runtime, expected} <- variants do
    Store.write("#{base}/qualification.json", controls)
    Store.write("#{base}/runtime.json", runtime)
    accepted = try do
      Curation.EvidenceBinding.verify_run!(base, binding, &AshCuration.Outcomes.normalize/1)
      true
    rescue
      error in RuntimeError ->
        unless error.message == "Solver evidence does not match the three reviewed qualification rounds",
          do: reraise(error, __STACKTRACE__)
        false
    end
    unless accepted == expected, do: raise("Evidence binding diagnostic failed: #{name}")
    %{"check" => name, "accepted" => accepted, "expected" => expected, "passed" => true}
  end
  File.write!(Path.join(__DIR__, "evidence-binding-checks.json"),
    Jason.encode!(%{"candidate" => ref, "all_passed" => true, "checks" => results,
      "scope" => "Private diagnostic copies of actual qualification artifacts; no solver artifacts changed."},
      pretty: true) <> "\n")
  IO.puts("EVIDENCE_BINDING_CHECKS_PASSED")
after
  File.rm_rf!(Store.path(base))
end
