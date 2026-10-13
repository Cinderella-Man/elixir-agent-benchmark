defmodule Eab.Runner do
  alias Eab.{Activity, Agent, Fixtures, Grader, Inventory, Model, Store}

  def execute(run, key, emit) do
    endpoint = run["model"]
    Model.unchanged!(endpoint, key)
    protocol = run["protocol"]

    results =
      Enum.map(run["cases"], fn id ->
        Activity.with_case(run["id"], id, key, fn ->
          verify!(protocol, endpoint, key)
          control = prepare(run, id, key, emit)
          progress(emit, "running", id, "Starting Pi for #{id}")

          result =
            Agent.attempt(
              id,
              run["id"],
              endpoint,
              key,
              run["settings"],
              control,
              &progress(
                emit,
                if(String.starts_with?(&1, "Grading"), do: "grading", else: "running"),
                id,
                &1
              )
            )

          emit.(%{"case_result" => {id, result}})
          result
        end)
      end)

    verify!(protocol, endpoint, key)

    if Enum.all?(results, &(&1["status"] == "completed")),
      do: :ok,
      else: {:error, "One or more cases could not be evaluated. See their saved errors."}
  end

  defp prepare(run, id, key, emit) do
    progress(emit, "preparing", id, "Preparing #{id}")

    try do
      Fixtures.ensure(id, &progress(emit, "preparing", id, &1))
      control = Grader.qualify(id, run["id"], &progress(emit, "qualifying", id, &1))
      Store.write("runs/#{run["id"]}/#{id}/qualification.json", control)
      progress(emit, "ready", id, "#{id} is ready for Pi")
      control
    rescue
      error ->
        Activity.note("ERROR: " <> Exception.message(error))
        reraise error, __STACKTRACE__
    after
      for {source, target} <- [
            {"build/#{id}/build.log", "build.log"},
            {"runtimes/#{id}.json", "runtime.json"},
            {"controls/#{id}.json", "qualification.json"}
          ] do
        case File.read(Store.path(source)) do
          {:ok, content} -> Store.write_text("runs/#{run["id"]}/#{id}/#{target}", content, key)
          _ -> :ok
        end
      end
    end
  end

  defp progress(emit, phase, id, message) do
    Activity.note(message)
    emit.(%{"phase" => phase, "message" => message, "current_case" => id})
  end

  defp verify!(protocol, endpoint, key) do
    unless protocol == Inventory.protocol(), do: raise("Benchmark inputs changed during the run")
    Model.unchanged!(endpoint, key)
  end

  def score(run) do
    attempts = Enum.map(run["cases"], &get_in(run, ["attempts", &1]))

    passed =
      Enum.count(
        attempts,
        &(is_map(&1) and &1["status"] == "completed" and get_in(&1, ["grade", "passed"]) == true)
      )

    failed =
      Enum.count(
        attempts,
        &(is_map(&1) and &1["status"] == "completed" and get_in(&1, ["grade", "passed"]) == false)
      )

    total = length(attempts)
    complete = total > 0 and passed + failed == total and run["status"] == "completed"

    %{
      "passed" => passed,
      "failed" => failed,
      "pending_or_error" => total - passed - failed,
      "planned" => total,
      "score_percent" => if(complete, do: Float.round(100 * passed / total, 2), else: nil)
    }
  end
end
