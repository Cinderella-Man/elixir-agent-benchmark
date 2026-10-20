alias Eab.{Inventory, Store}
Code.require_file("qualification-outcomes.exs", __DIR__)
ref = %{
  "id" => "ash-pr-3031",
  "version" => "8a1b0882a61f1a172d54bedac4854c316ac1f37784eaf2776bf7e543aa922d38"
}
prefix = "curation/#{ref["id"]}/#{ref["version"]}"
name = "Elixir.Ash.Test.Calculations.CalculationArgumentExprTest::test normalized literal calculation arguments preserve constrained custom values without recasting them"
marker = "EAB_FAILURE_PHASE:" <> Base.encode64(name) <> ":test"
rounds =
  for n <- 1..2 do
    path = "#{prefix}/qualification-round-#{n}.json"
    proof = Store.read(path)
    probe = proof["controls"]["reference_patch"]["regression_coverage"]["broken_test_probe"]
    line = probe["output"] |> String.split("\n") |> Enum.find(&String.contains?(&1, marker))
    %{
      "round" => n,
      "valid" => proof["controls"]["valid"],
      "source" => proof["source"],
      "grader" => proof["grader"],
      "runtime" => Map.take(proof["runtime"], ~w(image services baseline base_image toolchain_image)),
      "named_outcomes" => AshCuration.Outcomes.normalize(proof),
      "private_receipt_sha256" => Inventory.hash_file(Store.path(path)),
      "relevant_raw_output_line" => line,
      "probe_output_truncated" => probe["output_truncated"]
    }
  end

record = %{
  "candidate" => ref,
  "three_round_repeatability_gate" => "failed",
  "model_attempts" => [],
  "diagnosis" => "CLI progress dot prefixed a trusted failure-phase line. The strict parser lost one test-body phase and its derived regression-detection entry. Test states/types and all acceptance/preservation outcomes matched; this is nevertheless scoring-relevant metadata loss.",
  "disposition" => "Superseded by a reviewed environment correction. Neither receipt counts toward the corrected version's qualification.",
  "rounds" => rounds
}
File.write!("/tmp/ash-reporter-interleaving.json", Jason.encode!(record, pretty: true) <> "\n")
IO.puts("Retained both unbuffered qualification receipts and exact reporting discrepancy")
