Code.require_file("line-buffered-io.exs", __DIR__)
Code.require_file("../../../lib/eab/grader.ex", __DIR__)
ExUnit.start(seed: 0, max_cases: 2)

defmodule AshCuration.LineBufferedIOTest do
  use ExUnit.Case, async: false
  alias Ash.Test.LineBufferedIO

  test "a departed partial writer cannot corrupt another writer's complete records" do
    {:ok, sink} = StringIO.open("")
    proxy = LineBufferedIO.start(sink)
    id = Base.encode64("Fixture::test assertion")
    :ok = :io.put_chars(proxy, "EAB_TEST:failed:#{id}\n")

    :ok =
      :io.put_chars(
        proxy,
        "EAB_FAILURE_TYPES:#{id}:#{Base.encode64("Elixir.ExUnit.AssertionError")}\n"
      )

    {_pid, monitor} = spawn_monitor(fn -> :ok = :io.put_chars(proxy, ".") end)
    assert_receive {:DOWN, ^monitor, :process, _, :normal}
    :ok = :io.put_chars(proxy, "EAB_FAILURE_PHASE:#{id}:test\nEAB_SUITE_FINISHED:1\n")

    {_, output} = StringIO.contents(sink)
    refute String.starts_with?(output, ".")
    assert String.ends_with?(output, "EAB_SUITE_FINISHED:1\n")

    parsed =
      Eab.Grader.parse(%{"output" => output, "returncode" => 2, "output_truncated" => false})

    assert parsed["completed"]
    assert parsed["failure_phases"]["Fixture::test assertion"] == "test"
    assert parsed["failure_types"]["Fixture::test assertion"] == ["Elixir.ExUnit.AssertionError"]
    refute parsed["passed"]

    assert :ok = LineBufferedIO.flush(proxy)
    assert {_, final} = StringIO.contents(sink)
    assert final == output <> "."
  end

  test "Unicode, iodata, legacy and MFA writes retain each writer's order" do
    {:ok, sink} = StringIO.open("")
    proxy = LineBufferedIO.start(sink)
    assert :ok = :io.request(proxy, {:put_chars, :unicode, ["é", [?λ], ["x"]]})

    assert :ok =
             :io.request(
               proxy,
               {:requests,
                [
                  {:put_chars, :unicode, :io_lib, :format, ["~ts", ["終\n"]]},
                  {:put_chars, [?a]},
                  {:put_chars, :io_lib, :format, ["~s", ["b\n"]]}
                ]}
             )

    assert {"", "éλx終\nab\n"} = StringIO.contents(sink)
  end

  test "reads, options, geometry and mixed batched requests are delegated" do
    {:ok, sink} = StringIO.open("abc")
    proxy = LineBufferedIO.start(sink)
    assert :io.getopts(proxy) == :io.getopts(sink)

    assert :io.request(proxy, {:get_geometry, :columns}) ==
             :io.request(sink, {:get_geometry, :columns})

    assert :io.request(proxy, {:setopts, [encoding: :unicode]}) == :ok
    assert :io.request(proxy, {:get_chars, :unicode, "", 1}) == "a"

    assert :io.request(
             proxy,
             {:requests,
              [
                :getopts,
                {:put_chars, :unicode, "line\n"},
                {:get_chars, :unicode, "", 2}
              ]}
           ) == "bc"

    assert {"", "line\n"} = StringIO.contents(sink)
  end

  test "write and final-flush errors propagate" do
    sink = spawn_link(fn -> reject_requests() end)
    proxy = LineBufferedIO.start(sink)
    assert :io.request(proxy, {:put_chars, :unicode, "whole\n"}) == {:error, :closed}
    assert :io.put_chars(proxy, "partial") == :ok
    assert LineBufferedIO.flush(proxy) == {:error, :closed}
  end

  test "a failed proxy makes finalization fail instead of waiting forever" do
    {:ok, sink} = StringIO.open("")
    proxy = LineBufferedIO.start(sink)
    Process.unlink(proxy)
    monitor = Process.monitor(proxy)
    Process.exit(proxy, :kill)
    assert_receive {:DOWN, ^monitor, :process, ^proxy, :killed}
    assert catch_exit(LineBufferedIO.flush(proxy)) == {:line_buffered_io_down, :noproc}
  end

  defp reject_requests do
    receive do
      {:io_request, from, ref, _request} ->
        send(from, {:io_reply, ref, {:error, :closed}})
        reject_requests()
    end
  end
end
