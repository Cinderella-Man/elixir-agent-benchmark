defmodule Eab.Agent do
  @moduledoc "One Pi attempt followed by independent grading in fresh containers."
  alias Eab.{Grader, Inventory, Model, Pi, Sandbox, Store}

  def attempt(id, run_id, endpoint, key, settings, control, emit) do
    prefix = "runs/#{run_id}/#{id}"
    spec = Inventory.spec(id)
    prompt = Inventory.file(id, "ticket.md")

    instructions = """
    Repair the ticket in /workspace. Investigate the source, edit it, add a regression test and run the relevant tests.
    Dependencies are prepared. The workspace is offline. Preserve existing behavior and do not weaken tests.
    Allowed edit prefixes: #{Enum.join(spec["allowed_edit_prefixes"], ", ")}.
    Test command: #{spec["regression_command"]}.
    Add or change a *_test.exs test that fails behaviorally on broken source and passes after repair. Compilation/setup failures do not count.
    When finished, give a short summary. Your current patch is then checked in a fresh workspace.
    Limits: #{settings["max_calls"]} model calls, #{settings["max_tokens"]} generated tokens total,
    #{settings["window_tokens"]} context tokens including up to #{settings["response_tokens"]} response tokens.
    History is never compacted. If a budget is exhausted, the current patch is graded.
    Task details: #{Jason.encode!(spec["clarifications"] || %{})}
    """

    base = %{
      "case" => id,
      "settings" => settings,
      "agent" => Pi.identity(),
      "calls" => 0,
      "generated_tokens" => 0,
      "status" => "running",
      "model" => endpoint
    }

    Store.write("#{prefix}/attempt.json", base, key)
    Store.write_text("#{prefix}/prompt.md", prompt, key)
    Store.write_text("#{prefix}/instructions.md", instructions, key)

    {record, patch} =
      Sandbox.with_box(id, run_id, fn box ->
        try do
          result = Pi.run(box, endpoint, key, settings, prefix, prompt, instructions, emit)
          {Map.merge(base, result), Sandbox.patch(box)}
        after
          try do
            Store.write_text("#{prefix}/model.patch", Sandbox.patch(box), key)
          rescue
            _ -> :ok
          end
        end
      end)

    Store.write_text("#{prefix}/model.patch", patch, key)
    emit.("Grading #{id}")
    grade = Grader.grade(id, patch, run_id, expected: control["reference_patch"])
    Model.unchanged!(endpoint, key)
    record = Map.merge(record, %{"status" => "completed", "grade" => grade})
    Store.write("#{prefix}/attempt.json", record, key)
    record
  rescue
    error ->
      prefix = "runs/#{run_id}/#{id}"

      record =
        Store.read("#{prefix}/attempt.json", %{"case" => id})
        |> Map.merge(Store.read("#{prefix}/agent-progress.json", %{}))
        |> Map.merge(%{
          "status" => "error",
          "error" => Store.redact(Exception.message(error), key)
        })

      Store.write("#{prefix}/attempt.json", record, key)
      Eab.Activity.note("ERROR: " <> record["error"])
      record
  end
end
