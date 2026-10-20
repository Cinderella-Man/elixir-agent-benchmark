Code.require_file("line-buffered-io.exs", __DIR__)
Code.require_file("../../../lib/eab/grader.ex", __DIR__)
Code.require_file("../../../priv/fixtures/grade_formatter.exs", __DIR__)

original = Process.group_leader()
{:ok, sink} = StringIO.open("")
Process.group_leader(self(), sink)
proxy = Ash.Test.LineBufferedIO.install()

ExUnit.start(
  autorun: false,
  seed: 0,
  max_cases: 2,
  formatters: [ExUnit.CLIFormatter, ElixirAgentBenchmark.TrustedFormatter]
)

defmodule AshCuration.ReporterFixture do
  use ExUnit.Case, async: true

  for n <- 1..40 do
    @n n
    test "mixed result #{n}" do
      assert rem(@n, 2) == 0
    end
  end
end

%{total: 40, failures: 20} = ExUnit.run()
:ok = Ash.Test.LineBufferedIO.flush(proxy)
{"", output} = StringIO.contents(sink)
Process.group_leader(self(), original)

unless String.contains?(output, "Running ExUnit with seed: 0, max_cases: 2"),
  do: raise("CLI formatter did not write through the proxy")

parsed = Eab.Grader.parse(%{"output" => output, "returncode" => 2, "output_truncated" => false})

unless parsed["completed"] and map_size(parsed["test_results"]) == 40 and
         map_size(parsed["failure_phases"]) == 20 and map_size(parsed["failure_types"]) == 20 and
         Enum.all?(parsed["failure_phases"], fn {_, phase} -> phase == "test" end) and
         not parsed["passed"],
       do: raise("Trusted formatter records were lost or changed")

IO.puts(
  "Both actual formatters captured: 40 completed, 20 assertion failures, all phases/types retained"
)
