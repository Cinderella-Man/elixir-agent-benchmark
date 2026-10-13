defmodule Eab.Runner do
  alias Eab.{Activity, Agent, Fixtures, Grader, Inventory, Model, Pipeline, Sandbox, Store}

  def execute(run, key, emit) do
    endpoint = run["model"]
    Model.unchanged!(endpoint, key)
    protocol = run["protocol"]

    context = fn id, fun -> Activity.with_case(run["id"], id, key, fun) end

    callbacks = %{
      prepare: fn id ->
        context.(id, fn ->
          verify!(protocol, endpoint, key)
          prepare(run, id, key, emit)
        end)
      end,
      workspace: fn id, use ->
        context.(id, fn ->
          progress(emit, "warming", id, "Starting workspace and services for #{id}")

          Sandbox.with_box(
            id,
            run["id"],
            fn box ->
              progress(emit, "warm", id, "Workspace ready for Pi")
              use.(box)
            end,
            agent: true
          )
        end)
      end,
      attempt: fn id, box, _control ->
        verify!(protocol, endpoint, key)
        progress(emit, "running", id, "Starting Pi for #{id}")

        submission =
          Agent.submit(
            id,
            run["id"],
            box,
            endpoint,
            key,
            run["settings"],
            &progress(emit, "running", id, &1)
          )

        progress(emit, "submitted", id, "Submission saved; waiting for grading")
        submission
      end,
      grade: fn id, submission, control ->
        context.(id, fn ->
          verify!(protocol, endpoint, key)

          Agent.grade(
            id,
            run["id"],
            submission,
            endpoint,
            key,
            control,
            &progress(emit, "grading", id, &1)
          )
        end)
      end,
      error: fn id, message ->
        context.(id, fn -> Agent.error(id, run["id"], message, key) end)
      end,
      result: fn id, result -> emit.(%{"case_result" => {id, result}}) end
    }

    results = Pipeline.run(run["cases"], callbacks, Application.get_env(:eab, :pipeline, []))

    verify!(protocol, endpoint, key)

    if Enum.all?(results, &(&1["status"] == "completed")),
      do: :ok,
      else: {:error, "One or more cases could not be evaluated. See their saved errors."}
  end

  defp prepare(run, id, key, emit) do
    progress(emit, "preparing", id, "Preparing #{id}")

    try do
      Fixtures.ensure(id, &progress(emit, "preparing", id, &1), run_id: run["id"])
      control = Grader.qualify(id, run["id"], &progress(emit, "qualifying", id, &1))
      Store.write("runs/#{run["id"]}/#{id}/qualification.json", control)
      progress(emit, "ready", id, "Image and fixture checks ready for #{id}")
      control
    rescue
      error ->
        Activity.note("ERROR: " <> Exception.message(error))
        reraise error, __STACKTRACE__
    after
      for {source, target} <- [
            {(Store.read("runtimes/#{id}.json") || %{})["build_log"] || "build/#{id}/build.log",
             "build.log"},
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
    emit.(%{"case_phase" => %{"case" => id, "phase" => phase, "message" => message}})
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
