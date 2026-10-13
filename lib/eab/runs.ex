defmodule Eab.Runs do
  use GenServer
  alias Eab.{Checkpoints, Model, Pipeline, Release, Runner, Sandbox, Store}
  @terminal ~w(completed error cancelled interrupted corrupt)
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def subscribe, do: Phoenix.PubSub.subscribe(Eab.PubSub, "runs")
  def snapshot, do: GenServer.call(__MODULE__, :snapshot)

  def start(endpoint, key, settings),
    do: GenServer.call(__MODULE__, {:start, endpoint, key, settings}, 30_000)

  def resume(id, endpoint, key, settings),
    do: GenServer.call(__MODULE__, {:resume, id, endpoint, key, settings}, 30_000)

  def stop, do: GenServer.call(__MODULE__, :stop)
  def retry_cleanup, do: GenServer.call(__MODULE__, :retry_cleanup)

  @impl true
  def init(_) do
    Sandbox.installation()
    history = Store.runs()
    interrupted = Enum.reject(history, &(&1["status"] in @terminal))
    pending = Enum.filter(history, &(&1["cleanup_pending"] == true or &1 in interrupted))
    pending_ids = Enum.uniq(Enum.map(pending, & &1["id"]) ++ Eab.Retention.leased_runs())

    for run <- interrupted,
        do:
          persist(
            Map.merge(run, %{
              "status" => "interrupted",
              "phase" => "interrupted",
              "message" =>
                "Application restarted. Reconnect the same model to resume unfinished cases."
            })
          )

    # Reap owned containers in the background, never block website startup.
    task =
      if pending_ids != [],
        do:
          Task.Supervisor.async_nolink(Eab.Tasks, fn ->
            Enum.each(pending_ids, &cleanup/1)
          end)

    {:ok, %{active: nil, worker: nil, cleanup: task, cleanup_error: nil}}
  end

  @impl true
  def handle_call(:snapshot, _from, state),
    do:
      {:reply,
       %{
         active: state.active,
         history: Store.run_page().items,
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

    release = Release.freeze()
    settings = Model.settings(endpoint, settings)

    run = %{
      "id" => id,
      "created_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "status" => "running",
      "phase" => "starting",
      "message" => "Checking the model endpoint",
      "model" => endpoint,
      "settings" => settings,
      "cases" => release["protocol"]["inventory"]["cases"],
      "protocol" => release["protocol"],
      "release_id" => release["id"],
      "experiment_id" => Release.experiment(release["id"], endpoint, settings),
      "case_metadata" => Release.case_metadata(release),
      "attempts" => %{},
      "cleanup_pending" => true
    }

    launch(run, key, state)
  rescue
    error -> {:reply, {:error, Exception.message(error)}, state}
  end

  def handle_call({:resume, _, _, _, _}, _from, state)
      when not is_nil(state.active) or not is_nil(state.cleanup) or
             not is_nil(state.cleanup_error),
      do: {:reply, {:error, "Wait for the active run and container cleanup to finish"}, state}

  def handle_call({:resume, id, endpoint, key, settings}, _from, state) do
    run = Store.run(id) || raise "Run not found"

    unless run["status"] in ~w(interrupted cancelled error),
      do: raise("This run cannot be resumed")

    if run["cleanup_pending"] == true, do: raise("Container cleanup must finish before resume")
    Checkpoints.validate_run!(run, endpoint, Model.settings(endpoint, settings))
    plan = Checkpoints.plan(run)

    unless plan.restart != [] or map_size(plan.submissions) > 0,
      do:
        raise(
          "No unfinished cases to resume; completed failures and evaluation errors are preserved"
        )

    run = Checkpoints.archive_unfinished(run, plan.restart)

    run =
      Map.merge(run, %{
        "status" => "running",
        "phase" => "resuming",
        "current_case" => nil,
        "message" => "Resuming unfinished cases; completed outcomes are preserved",
        "attempts" =>
          Map.new(plan.retained, fn {id, record} -> {id, Eab.Evidence.compact(record)} end),
        "case_phases" => Map.new(plan.retained, fn {id, result} -> {id, result["status"]} end),
        "case_messages" => %{},
        "cleanup_pending" => true,
        "resume_count" => (run["resume_count"] || 0) + 1
      })

    Store.event(id, %{
      "phase" => "resuming",
      "completed_reused" => map_size(plan.retained),
      "saved_submissions" => map_size(plan.submissions),
      "fresh_attempts" => length(plan.restart)
    })

    launch(run, key, state)
  rescue
    error -> {:reply, {:error, Exception.message(error)}, state}
  end

  def handle_call(:stop, _from, %{active: nil} = state), do: {:reply, :ok, state}

  def handle_call(:retry_cleanup, _from, %{active: nil, cleanup: nil} = state) do
    task =
      Task.Supervisor.async_nolink(Eab.Tasks, fn ->
        pending = Store.runs() |> Enum.filter(& &1["cleanup_pending"]) |> Enum.map(& &1["id"])
        Enum.uniq(pending ++ Eab.Retention.leased_runs()) |> Enum.each(&cleanup/1)
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
        Pipeline.await_owner(owner)
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
          Map.take(event, ["phase", "message", "current_case", "case_phase"])
      end

    Store.event(id, log)

    run =
      case event do
        %{"case_result" => {case_id, result}} ->
          state.active
          |> put_in(["attempts", case_id], Eab.Evidence.compact(result))
          |> case_progress(case_id, result["status"], result["error"] || "Case finished")
          |> foreground()

        %{"case_phase" => %{"case" => case_id, "phase" => phase, "message" => message}} ->
          state.active |> case_progress(case_id, phase, message) |> foreground()

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

  defp launch(run, key, state) do
    Eab.Retention.lease(run["id"])
    id = run["id"]
    parent = self()
    runner = Application.get_env(:eab, :runner, &Runner.execute/3)

    task =
      try do
        persist(run)

        Store.write("runs/#{id}/release.json", %{
          "id" => run["release_id"],
          "protocol" => run["protocol"]
        })

        Task.Supervisor.async_nolink(Eab.Tasks, fn ->
          try do
            runner.(run, key, &send(parent, {:progress, id, Store.scrub(&1, key)}))
          rescue
            error -> {:error, Store.redact(Exception.message(error), key)}
          end
        end)
      rescue
        error ->
          Eab.Retention.release(id)
          reraise error, __STACKTRACE__
      end

    broadcast()
    {:reply, {:ok, id}, %{state | active: run, worker: task}}
  end

  defp finish(state, status, message) do
    run = Map.merge(state.active, %{"status" => status, "phase" => status, "message" => message})
    persist(run)
    owner = state.worker.pid

    task =
      Task.Supervisor.async_nolink(Eab.Tasks, fn ->
        Pipeline.await_owner(owner)
        cleanup(run["id"])
      end)

    broadcast()
    {:noreply, %{state | active: nil, worker: nil, cleanup: task}}
  end

  defp persist(run) do
    run = if run["status"] in @terminal, do: finalize_attempts(run), else: run
    run = Map.put(run, "score", Runner.score(run))
    Store.write("runs/#{run["id"]}/run.json", run)
    Store.index_run(run)
    if run["status"] in @terminal, do: Eab.Report.write(run)
  end

  defp finalize_attempts(run) do
    attempts =
      Map.new(run["cases"], fn id ->
        path = "runs/#{run["id"]}/#{id}/attempt.json"

        record = final_record(run, id, path)

        record =
          if is_map(record) and record["status"] in ["running", "submitted", "grading"] do
            status = if run["status"] == "completed", do: "error", else: run["status"]

            record =
              Map.merge(record, %{
                "status" => status,
                "interrupted_stage" => record["status"],
                "error" => run["message"]
              })

            Store.write(path, record)
            record
          else
            record
          end

        {id, Eab.Evidence.compact(record)}
      end)
      |> Map.reject(fn {_, value} -> is_nil(value) end)

    Map.put(run, "attempts", attempts)
  end

  defp final_record(run, id, path) do
    (run["experiment_id"] && Checkpoints.completed(run, id)) ||
      Store.read(path, get_in(run, ["attempts", id]))
  rescue
    error ->
      %{
        "case" => id,
        "status" => "error",
        "error" => "Saved evidence cannot be verified: #{Exception.message(error)}"
      }
  end

  defp broadcast, do: Phoenix.PubSub.broadcast(Eab.PubSub, "runs", :runs_changed)

  defp case_progress(run, id, phase, message) do
    phases =
      ~w(pending preparing prepared qualifying ready warming warm running submitted grading completed error)

    previous = get_in(run, ["case_phases", id]) || "pending"

    # Worker events may arrive after a later stage's event from another process.
    if Enum.find_index(phases, &(&1 == phase)) >= Enum.find_index(phases, &(&1 == previous)) do
      run
      |> Map.put("case_phases", Map.put(run["case_phases"] || %{}, id, phase))
      |> Map.put("case_messages", Map.put(run["case_messages"] || %{}, id, message))
    else
      run
    end
  end

  defp foreground(run) do
    priorities = ~w(running grading submitted warming qualifying preparing warm ready prepared)

    active =
      for id <- run["cases"],
          phase = get_in(run, ["case_phases", id]),
          phase in priorities,
          do: {Enum.find_index(priorities, &(&1 == phase)), id, phase}

    case Enum.min_by(active, &elem(&1, 0), fn -> nil end) do
      nil ->
        Map.merge(run, %{
          "current_case" => nil,
          "phase" => "waiting",
          "message" => "Finalizing results or waiting for the next case"
        })

      {_, id, phase} ->
        Map.merge(run, %{
          "current_case" => id,
          "phase" => phase,
          "message" => get_in(run, ["case_messages", id])
        })
    end
  end

  defp cleanup(id) do
    Application.get_env(:eab, :cleanup, &Sandbox.cleanup/1).(id)

    case Store.run(id) do
      nil -> :ok
      %{"status" => "corrupt"} -> :ok
      run -> persist(Map.put(run, "cleanup_pending", false))
    end

    Eab.Retention.release(id)
  end
end
