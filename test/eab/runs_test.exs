defmodule Eab.RunsTest do
  use ExUnit.Case, async: false
  alias Eab.{Runs, Store}

  setup do
    keys = [:data_dir, :runner, :cleanup]
    old = Map.new(keys, &{&1, Application.get_env(:eab, &1)})
    Supervisor.terminate_child(Eab.Supervisor, Runs)
    root = Path.join(System.tmp_dir!(), "eab-run-test-#{System.unique_integer([:positive])}")
    Application.put_env(:eab, :data_dir, root)
    Application.put_env(:eab, :cleanup, fn _ -> :ok end)
    Supervisor.restart_child(Eab.Supervisor, Runs)

    on_exit(fn ->
      Runs.stop()
      Supervisor.terminate_child(Eab.Supervisor, Runs)

      for {k, v} <- old do
        if v == nil, do: Application.delete_env(:eab, k), else: Application.put_env(:eab, k, v)
      end

      Supervisor.restart_child(Eab.Supervisor, Runs)
      File.rm_rf!(root)
    end)

    :ok
  end

  defp endpoint, do: %{"model" => "fixture", "context" => 32768}

  test "concurrent starts admit one run; cancellation preserves history and stops the worker" do
    parent = self()

    Application.put_env(:eab, :runner, fn run, _, _ ->
      id = hd(run["cases"])
      Store.write("runs/#{run["id"]}/#{id}/attempt.json", %{"status" => "running", "case" => id})
      Store.write_text("runs/#{run["id"]}/#{id}/model.patch", "saved work")
      send(parent, {:worker, self()})

      receive do
        :finish -> :ok
      end
    end)

    replies = for _ <- 1..2, do: Task.async(fn -> Runs.start(endpoint(), "", %{}) end)
    replies = Enum.map(replies, &Task.await/1)
    assert Enum.count(replies, &match?({:ok, _}, &1)) == 1
    assert Enum.count(replies, &match?({:error, _}, &1)) == 1
    assert_receive {:worker, worker}
    ref = Process.monitor(worker)
    assert :ok = Runs.stop()
    assert_receive {:DOWN, ^ref, :process, ^worker, _}
    [saved] = Store.runs()
    assert saved["status"] == "cancelled"
    assert saved["score"]["score_percent"] == nil
    report = File.read!(Store.path("runs/#{saved["id"]}/report.md"))
    assert report =~ "Status: cancelled"
    assert report =~ "Unavailable: run incomplete or contains errors"
    id = hd(saved["cases"])
    assert saved["attempts"][id]["status"] == "cancelled"
    assert Store.read("runs/#{saved["id"]}/#{id}/attempt.json")["status"] == "cancelled"
    assert File.read!(Store.path("runs/#{saved["id"]}/#{id}/model.patch")) == "saved work"
  end

  test "restart marks persisted active work interrupted without resuming" do
    Store.write("runs/old/run.json", %{
      "id" => "old",
      "created_at" => "2026-01-01",
      "status" => "running",
      "phase" => "running",
      "cases" => ["a"],
      "attempts" => %{}
    })

    Store.write("runs/old/a/attempt.json", %{"status" => "running", "case" => "a"})

    Supervisor.terminate_child(Eab.Supervisor, Runs)
    Supervisor.restart_child(Eab.Supervisor, Runs)
    assert Store.read("runs/old/run.json")["status"] == "interrupted"
    assert Store.read("runs/old/a/attempt.json")["status"] == "interrupted"
    assert Store.read("runs/old/run.json")["attempts"]["a"]["status"] == "interrupted"
    assert Runs.snapshot().active == nil
  end

  test "worker errors are saved without the API credential" do
    Application.put_env(:eab, :runner, fn _, _, _ -> raise "echoed secret-key" end)
    Runs.subscribe()
    assert {:ok, id} = Runs.start(endpoint(), "secret-key", %{})
    await_terminal(id)
    run = Store.read("runs/#{id}/run.json")
    assert run["status"] == "error"
    refute Jason.encode!(run) =~ "secret-key"
    assert run["message"] =~ "[REDACTED]"
    refute File.read!(Store.path("runs/#{id}/report.md")) =~ "secret-key"
  end

  test "background progress cannot replace active Pi or regress a case phase" do
    parent = self()

    Application.put_env(:eab, :runner, fn _, _, _ ->
      send(parent, {:worker, self()})

      receive do
        :finish -> :ok
      end
    end)

    assert {:ok, id} = Runs.start(endpoint(), "", %{})
    assert_receive {:worker, _}
    [a, b, c | _] = Runs.snapshot().active["cases"]

    progress = fn case_id, phase, message ->
      send(
        Runs,
        {:progress, id,
         %{"case_phase" => %{"case" => case_id, "phase" => phase, "message" => message}}}
      )
    end

    progress.(a, "running", "Pi editing")
    progress.(b, "qualifying", "Checking next case")
    progress.(c, "preparing", "Building later case")
    run = Runs.snapshot().active
    assert run["current_case"] == a
    assert run["message"] == "Pi editing"
    assert run["case_phases"][b] == "qualifying"
    assert run["case_phases"][c] == "preparing"

    progress.(a, "grading", "Grading submitted patch")
    progress.(b, "running", "Pi editing next case")
    progress.(b, "ready", "Delayed earlier event")
    run = Runs.snapshot().active
    assert run["current_case"] == b
    assert run["case_phases"][a] == "grading"
    assert run["case_phases"][b] == "running"
    assert run["case_messages"][b] == "Pi editing next case"

    send(
      Runs,
      {:progress, id,
       %{"case_result" => {a, %{"status" => "completed", "grade" => %{"passed" => true}}}}}
    )

    progress.(a, "grading", "Delayed grader event")
    assert Runs.snapshot().active["case_phases"][a] == "completed"
  end

  test "restart finalizes submitted and grading attempts as interrupted" do
    Store.write("runs/handoff/run.json", %{
      "id" => "handoff",
      "created_at" => "2026-01-01",
      "status" => "running",
      "cases" => ["a", "b"],
      "attempts" => %{}
    })

    for {id, status} <- [{"a", "submitted"}, {"b", "grading"}] do
      Store.write("runs/handoff/#{id}/attempt.json", %{"case" => id, "status" => status})
      Store.write_text("runs/handoff/#{id}/model.patch", "saved #{id}")
    end

    Supervisor.terminate_child(Eab.Supervisor, Runs)
    Supervisor.restart_child(Eab.Supervisor, Runs)

    for id <- ["a", "b"] do
      assert Store.read("runs/handoff/#{id}/attempt.json")["status"] == "interrupted"
      assert File.read!(Store.path("runs/handoff/#{id}/model.patch")) == "saved #{id}"
    end

    assert Store.read("runs/handoff/run.json")["score"]["score_percent"] == nil
  end

  test "stop drains all pipeline workers before installation container cleanup" do
    parent = self()

    Application.put_env(:eab, :runner, fn _, _, _ ->
      Eab.Pipeline.run(["a", "b"], %{
        prepare: fn
          "a" ->
            :ready

          "b" ->
            send(parent, {:preparing, self()})

            receive do
              :never -> :ready
            end
        end,
        workspace: fn _, use -> use.(:box) end,
        attempt: fn _, _, _ ->
          send(parent, {:pi, self()})

          receive do
            :never -> :submission
          end
        end
      })
    end)

    Application.put_env(:eab, :cleanup, fn id -> send(parent, {:cleanup, id}) end)
    assert {:ok, id} = Runs.start(endpoint(), "", %{})
    assert_receive {:pi, pi}, 3000
    assert_receive {:preparing, preparing}, 3000
    Runs.stop()
    assert_receive {:cleanup, ^id}, 3000
    refute Process.alive?(pi)
    refute Process.alive?(preparing)
    assert Store.read("runs/#{id}/run.json")["status"] == "cancelled"
  end

  defp await_terminal(id) do
    if Store.read("runs/#{id}/run.json")["status"] == "running" do
      receive do
        :runs_changed -> await_terminal(id)
      after
        2000 -> flunk("Worker did not finish")
      end
    end
  end
end
