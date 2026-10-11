defmodule Benchmark.CancelledDemandTest do
  use ExUnit.Case, async: true

  defmodule DeferredProducer do
    use GenStage
    def start_link(_), do: GenStage.start_link(__MODULE__, nil)
    def init(_), do: {:producer, %{requests: [], cancellations: 0}}

    def handle_demand(count, state) do
      {:noreply, [], %{state | requests: state.requests ++ [count]}}
    end

    def handle_cancel(_reason, _from, state) do
      {:noreply, [], %{state | cancellations: state.cancellations + 1}}
    end

    def handle_call(:snapshot, _from, state), do: {:reply, state, [], state}
    def handle_call({:deliver, events}, _from, state), do: {:reply, :ok, events, state}
  end

  defmodule ManualConsumer do
    use GenStage
    def start_link(owner), do: GenStage.start_link(__MODULE__, owner)
    def init(owner), do: {:consumer, %{owner: owner, subscription: nil}}

    def handle_subscribe(:producer, _opts, from, state) do
      {:manual, %{state | subscription: from}}
    end

    def handle_call({:ask, count}, _from, state) do
      {producer, _} = state.subscription
      GenStage.ask(state.subscription, count)
      snapshot = GenStage.call(producer, :snapshot)
      {:reply, snapshot, [], state}
    end

    def handle_call(:cancel, _from, state) do
      {producer, _} = state.subscription
      GenStage.cancel(state.subscription, :normal)
      snapshot = GenStage.call(producer, :snapshot)
      {:reply, snapshot, [], state}
    end

    def handle_cancel(_reason, _from, state), do: {:noreply, [], state}

    def handle_events(events, _from, state) do
      send(state.owner, {:delivered, self(), events})
      {:noreply, [], state}
    end
  end

  defp producer do
    start_supervised!({DeferredProducer, nil})
  end

  defp consumer(producer, id) do
    pid = start_supervised!({ManualConsumer, self()}, id: id)
    {:ok, _ref} = GenStage.sync_subscribe(pid, to: producer, cancel: :temporary)
    pid
  end

  defp ask(consumer, amount), do: GenStage.call(consumer, {:ask, amount})
  defp cancel(consumer), do: GenStage.call(consumer, :cancel)

  test "replacement demand reuses in-flight work before requesting its uncovered remainder" do
    p = producer()
    old = consumer(p, :old)
    assert ask(old, 6).requests == [6]
    assert cancel(old).cancellations == 1
    replacement = consumer(p, :replacement)

    assert ask(replacement, 4).requests == [6]
    assert ask(replacement, 5).requests == [6, 3]
    assert :ok = GenStage.call(p, {:deliver, Enum.to_list(1..9)})
    assert_receive {:delivered, ^replacement, events}, 1_000
    assert events == Enum.to_list(1..9)
    refute_received {:delivered, ^old, _}

    assert ask(replacement, 2).requests == [6, 3, 2]
    assert :ok = GenStage.call(p, {:deliver, [10, 11]})
    assert_receive {:delivered, ^replacement, [10, 11]}, 1_000
  end

  test "cancellation does not erase a surviving consumer's demand" do
    p = producer()
    first = consumer(p, :first)
    survivor = consumer(p, :survivor)
    assert ask(first, 5).requests == [5]
    assert ask(survivor, 3).requests == [5, 3]
    assert cancel(first).cancellations == 1

    replacement = consumer(p, :replacement)
    assert ask(replacement, 5).requests == [5, 3]
    assert :ok = GenStage.call(p, {:deliver, Enum.to_list(1..8)})
    assert_receive {:delivered, ^replacement, [1, 2, 3, 4, 5]}, 1_000
    assert_receive {:delivered, ^survivor, [6, 7, 8]}, 1_000
    refute_received {:delivered, ^first, _}
    assert ask(survivor, 1).requests == [5, 3, 1]
  end

  test "multiple cancellations accumulate credit and buffering consumes it only once" do
    p = producer()
    a = consumer(p, :a)
    b = consumer(p, :b)
    assert ask(a, 4).requests == [4]
    assert ask(b, 3).requests == [4, 3]
    assert cancel(a).cancellations == 1
    assert cancel(b).cancellations == 2

    # Events arrive while no consumer exists. They must remain available.
    assert :ok = GenStage.call(p, {:deliver, Enum.to_list(1..7)})
    c = consumer(p, :c)
    assert ask(c, 7).requests == [4, 3]
    assert_receive {:delivered, ^c, [1, 2, 3, 4, 5, 6, 7]}, 1_000
    assert ask(c, 2).requests == [4, 3, 2]
  end

  test "cancelling an idle subscription does not suppress legitimate new work" do
    p = producer()
    idle = consumer(p, :idle)
    assert cancel(idle).cancellations == 1
    replacement = consumer(p, :replacement)
    assert ask(replacement, 3).requests == [3]
    assert :ok = GenStage.call(p, {:deliver, [:alpha, :beta, :gamma]})
    assert_receive {:delivered, ^replacement, [:alpha, :beta, :gamma]}, 1_000
  end
end
