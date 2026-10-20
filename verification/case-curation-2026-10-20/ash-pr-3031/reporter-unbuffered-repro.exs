Code.require_file("../../../lib/eab/grader.ex", __DIR__)
name = "Fixture::test assertion"
encoded = Base.encode64(name)
base = "EAB_TEST:failed:#{encoded}\nEAB_FAILURE_TYPES:#{encoded}:#{Base.encode64("Elixir.ExUnit.AssertionError")}\nEAB_FAILURE_PHASE:#{encoded}:test\nEAB_SUITE_FINISHED:1\n"
for {label, output} <- [{"clean", base}, {"progress_dot", String.replace(base, "EAB_FAILURE_PHASE:", ".EAB_FAILURE_PHASE:")}] do
  parsed = Eab.Grader.parse(%{"output" => output, "output_truncated" => false, "returncode" => 2})
  IO.inspect({label, parsed["completed"], parsed["test_results"][name], parsed["failure_types"][name], parsed["failure_phases"][name]})
end
interleaved = Eab.Grader.parse(%{"output" => String.replace(base, "EAB_FAILURE_PHASE:", ".EAB_FAILURE_PHASE:"), "output_truncated" => false, "returncode" => 2})
unless interleaved["failure_phases"][name] == "test", do: raise("Reproduced: CLI progress prefix loses a real test-body failure phase")
