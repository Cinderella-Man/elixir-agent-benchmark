defmodule Eab.Runs do
  use GenServer
  alias Eab.{Inventory, Model, Runner, Sandbox, Store}
  @terminal ~w(completed error cancelled interrupted)
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def subscribe, do: Phoenix.PubSub.subscribe(Eab.PubSub, "runs")
  def snapshot, do: GenServer.call(__MODULE__, :snapshot)

  def start(endpoint, key, settings),
    do: GenServer.call(__MODULE__, {:start, endpoint, key, settings}, 30_000)

  def stop, do: GenServer.call(__MODULE__, :stop)
  def retry_cleanup, do: GenServer.call(__MODULE__, :retry_cleanup)

  @impl true
  def init(_) do
    Sandbox.installation()
    history = Store.runs()
    interrupted = Enum.reject(history, &(&1["status"] in @terminal))
    pending = Enum.filter(history, &(&1["cleanup_pending"] == true or &1 in interrupted))

    for run <- interrupted,
        do:
          persist(
            Map.merge(run, %{
              "status" => "interrupted",
              "phase" => "interrupted",
              "message" => "Application restarted. Start a fresh run."
            })
          )

    # Reap owned containers in the background, never block website startup.
    task =
      if pending != [],
        do:
          Task.Supervisor.async_nolink(Eab.Tasks, fn ->
            Enum.each(pending, &cleanup(&1["id"]))
          end)

    {:ok, %{active: nil, worker: nil, cleanup: task, cleanup_error: nil}}
  end

  @impl true
  def handle_call(:snapshot, _from, state),
    do:
      {:reply,
       %{
         active: state.active,
         history: Store.runs(),
         cleanup_error: state.cleanup_error,
         cleaning: state.cleanup != nil
       }, state}

  def handle_call({:start, _, _, _}, _from, %{active: active} = state) when not is_nil(active),
    do: {:reply, {:error, "A run is already active"}, state}

  def handle_call({:start, _, _, _}, _from, %{cleanup: task} = state) when not is_nil(task),
    do: {:reply, {:error, "Previous containers are still being cleaned up"}, state}

  def handle_call({:start, _, _, _}, _from, %{cleanup_error: error} = state)
      when not is_nil(error),
      do: {:reply, {:error, "Container cleanup needs attention: #{error}"}, state}

  def handle_call({:start, endpoint, key, settings}, _from, state) do
    id = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M%S-")
    id = id <> Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)

    run = %{
      "id" => id,
      "created_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "status" => "running",
      "phase" => "starting",
      "message" => "Checking the model endpoint",
      "model" => endpoint,
      "settings" => Model.settings(endpoint, settings),
      "cases" => Inventory.all(),
      "protocol" => Inventory.protocol(),
      "attempts" => %{},
      "cleanup_pending" => true
    }

    persist(run)
    parent = self()
    runner = Application.get_env(:eab, :runner, &Runner.execute/3)

    task =
      Task.Supervisor.async_nolink(Eab.Tasks, fn ->
        try do
          runner.(run, key, &send(parent, {:progress, id, Store.scrub(&1, key)}))
        rescue
          error -> {:error, Store.redact(Exception.message(error), key)}
        end
      end)

    broadcast()
    {:reply, {:ok, id}, %{state | active: run, worker: task}}
  rescue
    error -> {:reply, {:error, Exception.message(error)}, state}
  end

  def handle_call(:stop, _from, %{active: nil} = state), do: {:reply, :ok, state}

  def handle_call(:retry_cleanup, _from, %{active: nil, cleanup: nil} = state) do
    task =
      Task.Supervisor.async_nolink(Eab.Tasks, fn ->
        Store.runs() |> Enum.filter(& &1["cleanup_pending"]) |> Enum.each(&cleanup(&1["id"]))
      end)

    {:reply, :ok, %{state | cleanup: task, cleanup_error: nil}}
  end

  def handle_call(:retry_cleanup, _from, state), do: {:reply, :ok, state}

  def handle_call(:stop, _from, state) do
    owner = state.worker.pid
    Task.shutdown(state.worker, :brutal_kill)

    run =
      Map.merge(state.active, %{
        "status" => "cancelled",
        "phase" => "cancelled",
        "message" => "Stopped. This run remains incomplete."
      })

    persist(run)

    task =
      Task.Supervisor.async_nolink(Eab.Tasks, fn ->
        Eab.Command.await_owner(owner)
        cleanup(run["id"])
      end)

    broadcast()
    {:reply, :ok, %{state | active: nil, worker: nil, cleanup: task}}
  end

  @impl true
  def handle_info({:progress, id, event}, %{active: %{"id" => id}} = state) do
    log =
      case event do
        %{"case_result" => {case_id, result}} ->
          %{
            "case" => case_id,
            "status" => result["status"],
            "passed" => get_in(result, ["grade", "passed"])
          }

        _ ->
          Map.take(event, ["phase", "message", "current_case"])
      end

    Store.event(id, log)

    run =
      case event do
        %{"case_result" => {case_id, result}} ->
          put_in(state.active, ["attempts", case_id], result)

        _ ->
          Map.merge(state.active, event)
      end

    run =
      if event["current_case"] && event["phase"] do
        phases = Map.put(run["case_phases"] || %{}, event["current_case"], event["phase"])
        Map.put(run, "case_phases", phases)
      else
        run
      end

    persist(run)
    broadcast()
    {:noreply, %{state | active: run}}
  end

  def handle_info({ref, result}, %{worker: %{ref: ref}} = state) do
    Process.demonitor(ref, [:flush])

    {status, message} =
      case result do
        :ok -> {"completed", "Run finished"}
        {:error, error} -> {"error", error}
      end

    finish(state, status, message)
  end

  def handle_info({:DOWN, ref, :process, _, _reason}, %{worker: %{ref: ref}} = state),
    do: finish(state, "error", "Run worker stopped unexpectedly")

  def handle_info({ref, _}, %{cleanup: %{ref: ref}} = state) do
    Process.demonitor(ref, [:flush])
    broadcast()
    {:noreply, %{state | cleanup: nil}}
  end

  def handle_info({:DOWN, ref, :process, _, reason}, %{cleanup: %{ref: ref}} = state) do
    broadcast()
    {:noreply, %{state | cleanup: nil, cleanup_error: inspect(reason)}}
  end

  def handle_info(_, state), do: {:noreply, state}

  defp finish(state, status, message) do
    run = Map.merge(state.active, %{"status" => status, "phase" => status, "message" => message})
    persist(run)
    task = Task.Supervisor.async_nolink(Eab.Tasks, fn -> cleanup(run["id"]) end)
    broadcast()
    {:noreply, %{state | active: nil, worker: nil, cleanup: task}}
  end

  defp persist(run) do
    run = if run["status"] in @terminal, do: finalize_attempts(run), else: run
    Store.write("runs/#{run["id"]}/run.json", Map.put(run, "score", Runner.score(run)))
    if run["status"] in @terminal, do: Eab.Report.write(run)
  end

  defp finalize_attempts(run) do
    attempts =
      Map.new(run["cases"], fn id ->
        path = "runs/#{run["id"]}/#{id}/attempt.json"
        record = Store.read(path, get_in(run, ["attempts", id]))

        record =
          if is_map(record) and record["status"] == "running" do
            status = if run["status"] == "completed", do: "error", else: run["status"]
            record = Map.merge(record, %{"status" => status, "error" => run["message"]})
            Store.write(path, record)
            record
          else
            record
          end

        {id, record}
      end)
      |> Map.reject(fn {_, value} -> is_nil(value) end)

    Map.put(run, "attempts", attempts)
  end

  defp broadcast, do: Phoenix.PubSub.broadcast(Eab.PubSub, "runs", :runs_changed)

  defp cleanup(id) do
    Application.get_env(:eab, :cleanup, &Sandbox.cleanup/1).(id)

    if run = Store.read("runs/#{id}/run.json"),
      do: persist(Map.put(run, "cleanup_pending", false))
  end
end
