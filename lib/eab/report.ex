defmodule Eab.Report do
  alias Eab.{Evidence, Runner, Store}

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

        "| #{id} | #{outcome} | #{attempt["calls"] || 0} | #{escape(Evidence.verdict(attempt))} |"
      end)

    evidence =
      Enum.map_join(run["cases"], "\n\n", fn id ->
        links =
          Evidence.links(run["id"], id)
          |> Enum.map_join(" · ", &"[#{&1["label"]}](#{&1["path"]})")

        "### #{id}\n\n#{links}"
      end)

    breakdowns =
      Runner.breakdowns(run)
      |> Enum.map_join("\n", fn row ->
        "| #{row["dimension"]} | #{escape(row["value"])} | #{row["passed"]}/#{row["planned"]} | #{row["failed"]} | #{row["pending_or_error"]} |"
      end)

    Store.write_text("runs/#{run["id"]}/report.md", """
    # Benchmark report

    - Run: #{run["id"]}
    - Model: #{escape(model["model"] || "Unknown")}
    - Backend: #{model["backend"] || "Unknown"}
    - Release: #{run["release_id"] || "Historical protocol only"}
    - Experiment: #{run["experiment_id"] || "Not sealed"}
    - Resumptions: #{run["resume_count"] || 0}
    - Archived interrupted generations: #{length(run["attempt_history"] || [])}
    - Status: #{run["status"]}
    - Passed: #{score["passed"]}/#{score["planned"]}
    - Failed: #{score["failed"]}
    - Pending or error: #{score["pending_or_error"]}
    - Final score: #{final_score}

    #{escape(run["message"] || "")}

    Effective settings (subscription thresholds and local strict caps are distinct policies):

    ```json
    #{Jason.encode!(run["settings"] || %{}, pretty: true)}
    ```

    | Case | Result | Model calls | Explanation |
    | --- | --- | ---: | --- |
    #{rows}

    | Group | Value | Passed | Failed | Incomplete/error |
    | --- | --- | ---: | ---: | ---: |
    #{breakdowns}

    Case directories contain command output, Pi transcripts, patches and grading evidence. Infrastructure errors are not scored as failed repairs.

    #{evidence}
    """)
  end

  defp escape(text), do: text |> String.replace("|", "\\|") |> String.replace(~r/[\r\n]+/, " ")
end
