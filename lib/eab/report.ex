defmodule Eab.Report do
  alias Eab.{Runner, Store}

  def write(run) do
    score = Runner.score(run)
    model = run["model"] || %{}

    final_score =
      if is_number(score["score_percent"]),
        do: "#{score["score_percent"]}%",
        else: "Unavailable: run incomplete or contains errors"

    rows =
      Enum.map_join(run["cases"], "\n", fn id ->
        attempt = get_in(run, ["attempts", id]) || %{}

        outcome =
          case attempt do
            %{"status" => "completed", "grade" => %{"passed" => true}} -> "Passed"
            %{"status" => "completed", "grade" => %{"passed" => false}} -> "Failed"
            _ -> attempt["status"] || "Not attempted"
          end

        "| #{id} | #{outcome} | #{attempt["calls"] || 0} | #{escape(attempt["error"] || attempt["stop_reason"] || "")} |"
      end)

    Store.write_text("runs/#{run["id"]}/report.md", """
    # Benchmark report

    - Run: #{run["id"]}
    - Model: #{escape(model["model"] || "Unknown")}
    - Backend: #{model["backend"] || "Unknown"}
    - Status: #{run["status"]}
    - Passed: #{score["passed"]}/#{score["planned"]}
    - Failed: #{score["failed"]}
    - Pending or error: #{score["pending_or_error"]}
    - Final score: #{final_score}

    #{escape(run["message"] || "")}

    | Case | Result | Model calls | Stop reason or error |
    | --- | --- | ---: | --- |
    #{rows}

    Case directories contain command output, Pi transcripts, patches and grading evidence. Infrastructure errors are not scored as failed repairs.
    """)
  end

  defp escape(text), do: text |> String.replace("|", "\\|") |> String.replace(~r/[\r\n]+/, " ")
end
