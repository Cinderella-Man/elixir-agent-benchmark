defmodule ElixirAgentBenchmark.TrustedFormatter do
  use GenServer

  def init(_opts), do: {:ok, 0}

  def handle_cast({:test_finished, test}, count) do
    state =
      case test.state do
        nil -> "passed"
        {:failed, _} -> "failed"
        {:skipped, _} -> "skipped"
        {:excluded, _} -> "excluded"
        _ -> "unknown"
      end

    identity = Atom.to_string(test.module) <> "::" <> Atom.to_string(test.name)
    IO.puts("\nEAB_TEST:" <> state <> ":" <> Base.encode64(identity))
    {:noreply, count + 1}
  end

  def handle_cast({:suite_finished, _timings}, count) do
    IO.puts("\nEAB_SUITE_FINISHED:" <> Integer.to_string(count))
    {:noreply, count}
  end

  def handle_cast(_event, count), do: {:noreply, count}
end
