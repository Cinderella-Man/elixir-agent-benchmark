defmodule EabWeb.DashboardTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint EabWeb.Endpoint
  test "a retired case in a saved run still shows and follows its command output" do
    id = "live-log-test"
    case_id = "plausible-pr-6300"

    Eab.Store.write("runs/#{id}/run.json", %{
      "id" => id,
      "created_at" => "9999-01-01T00:00:00Z",
      "status" => "running",
      "phase" => "qualifying",
      "message" => "Checking tests",
      "current_case" => case_id,
      "cases" => [case_id],
      "attempts" => %{},
      "settings" => %{},
      "model" => %{"model" => "synthetic"}
    })

    Eab.Store.write_text("runs/#{id}/#{case_id}/activity.log", "$ mix test\nCompiling project\n")
    on_exit(fn -> File.rm_rf!(Eab.Store.path("runs/#{id}")) end)
    {:ok, view, _} = live(build_conn(), "/")
    assert has_element?(view, "#case-#{case_id}[aria-expanded=false]")
    refute has_element?(view, "#case-log")
    view |> element("#case-#{case_id}") |> render_click()
    assert has_element?(view, "#case-#{case_id}[aria-expanded=true]")
    assert has_element?(view, "#case-panel-#{case_id} #case-log", "Compiling project")
    assert has_element?(view, "#case-log", "$ mix test")

    Eab.Store.write_text(
      "runs/#{id}/#{case_id}/activity.log",
      "$ mix test\nCompiling project\nTests finished\n"
    )

    send(view.pid, :poll_log)
    assert render(view) =~ "Tests finished"

    assert has_element?(
             view,
             "#case-log-download[href='/artifacts/#{id}/#{case_id}/activity.log']"
           )

    view |> element("#case-#{case_id}") |> render_click()
    assert has_element?(view, "#case-#{case_id}[aria-expanded=false]")
    refute has_element?(view, "#case-panel-#{case_id}")
    send(view.pid, :poll_log)
    refute has_element?(view, "#case-log")
    view |> element("#case-#{case_id}") |> render_click()
    assert has_element?(view, "#case-panel-#{case_id} #case-log", "Tests finished")
  end

  test "local setup page shows ten PR cases and waits for a model connection" do
    {:ok, view, html} = live(build_conn(), "/")
    assert html =~ "Benchmark dashboard"
    assert html =~ "Model and tool calls are unlimited."
    refute has_element?(view, "input[name='settings[max_calls]']")
    assert has_element?(view, "#run[disabled]")
    assert html =~ "plausible-pr-5939"
    refute html =~ "plausible-pr-6300"
    refute html =~ "plausible-pr-6763"
    assert length(Eab.Inventory.all()) == 10
  end

  test "run summary separates failed repairs from evaluation errors" do
    id = "score-summary-test"
    [a, b, c | _] = Eab.Inventory.all()

    Eab.Store.write("runs/#{id}/run.json", %{
      "id" => id,
      "created_at" => "9999-01-01T00:00:00Z",
      "status" => "completed",
      "cases" => [a, b, c],
      "attempts" => %{
        a => %{"status" => "completed", "grade" => %{"passed" => true}},
        b => %{"status" => "completed", "grade" => %{"passed" => false}},
        c => %{"status" => "error", "error" => "Endpoint unavailable"}
      },
      "settings" => %{},
      "model" => %{"model" => "synthetic"}
    })

    on_exit(fn -> File.rm_rf!(Eab.Store.path("runs/#{id}")) end)
    {:ok, view, _} = live(build_conn(), "/")
    assert has_element?(view, ".metric.passed strong", "1")
    assert has_element?(view, ".metric.failed strong", "1")
    assert has_element?(view, ".metric.error strong", "1")
    assert has_element?(view, ".metric.final-score strong", "—")
    assert has_element?(view, "[role=progressbar][aria-valuenow='2'][aria-valuemax='3']")
    view |> element("#case-#{c}") |> render_click()
    assert has_element?(view, "#case-panel-#{c}", "Endpoint unavailable")
    assert has_element?(view, "#case-panel-#{c} #case-verdict", "Evaluation error")
  end

  test "concurrent case stages and selected background messages remain visible" do
    id = "concurrent-progress-test"
    [a, b, c | _] = Eab.Inventory.all()

    Eab.Store.write("runs/#{id}/run.json", %{
      "id" => id,
      "created_at" => "9999-01-01T00:00:00Z",
      "status" => "running",
      "phase" => "running",
      "message" => "Pi editing",
      "current_case" => a,
      "cases" => [a, b, c],
      "attempts" => %{},
      "settings" => %{},
      "model" => %{"model" => "synthetic"},
      "case_phases" => %{a => "running", b => "qualifying", c => "grading"},
      "case_messages" => %{
        a => "Pi editing",
        b => "Checking upcoming fixture",
        c => "Grading prior patch"
      }
    })

    Eab.Store.write_text("runs/#{id}/#{b}/activity.log", "qualification output")
    on_exit(fn -> File.rm_rf!(Eab.Store.path("runs/#{id}")) end)
    {:ok, view, html} = live(build_conn(), "/")
    assert html =~ "Pi running"
    assert html =~ "Qualifying baseline"
    assert html =~ "Grading"
    view |> element("#case-#{b}") |> render_click()
    assert render(view) =~ "Checking upcoming fixture"
    assert has_element?(view, "#case-panel-#{b} #case-log", "qualification output")
    view |> element("button[phx-click=follow_output]") |> render_click()
    assert has_element?(view, "#case-log[data-follow=false]")
    view |> element("#case-#{a}") |> render_click()
    refute has_element?(view, "#case-panel-#{b}")
    assert has_element?(view, "#case-#{b}[aria-expanded=false]")
    assert has_element?(view, "#case-panel-#{a}", "Pi editing")
    assert has_element?(view, "#case-log[data-follow=true]")
  end

  test "a connected model enables Run without host configuration" do
    Application.put_env(:eab, :http_request, fn opts ->
      body =
        case URI.parse(opts[:url]).path do
          "/health" ->
            %{"status" => "ok"}

          "/v1/models" ->
            %{"data" => [%{"id" => "test-model"}]}

          "/props" ->
            %{"model_alias" => "test-model", "default_generation_settings" => %{"n_ctx" => 32768}}
        end

      {:ok, %{status: 200, body: body}}
    end)

    on_exit(fn -> Application.delete_env(:eab, :http_request) end)
    {:ok, view, _} = live(build_conn(), "/")
    view |> form("#connection", connection: %{url: "http://fixture", key: ""}) |> render_change()
    assert render_async(view) =~ "test-model"
    assert has_element?(view, "#run:not([disabled])")
  end

  test "clearing an endpoint cancels pending discovery and cannot restore its stale model" do
    parent = self()

    Application.put_env(:eab, :http_request, fn _ ->
      send(parent, {:discovering, self()})

      receive do
        :release -> {:error, :unavailable}
      end
    end)

    on_exit(fn -> Application.delete_env(:eab, :http_request) end)
    {:ok, view, _} = live(build_conn(), "/")
    view |> form("#connection", connection: %{url: "http://fixture", key: ""}) |> render_change()
    assert_receive {:discovering, pid}
    ref = Process.monitor(pid)
    view |> form("#connection", connection: %{url: "", key: ""}) |> render_change()
    assert_receive {:DOWN, ^ref, :process, ^pid, _}
    html = render_async(view)
    refute html =~ "Reading model details"
    refute html =~ "Model discovery stopped"
    assert has_element?(view, "#run[disabled]")
  end

  test "entering server credentials recovers from Strata's authentication error" do
    Application.put_env(:eab, :http_request, fn opts ->
      if URI.parse(opts[:url]).path == "/health" or
           {"authorization", "Bearer synthetic-key"} in opts[:headers] do
        body =
          case URI.parse(opts[:url]).path do
            "/health" ->
              %{"status" => "ok", "service" => "strata", "loaded" => true}

            "/v1/models" ->
              %{"data" => [%{"id" => "test-model"}]}

            "/props" ->
              %{
                "model_alias" => "test-model",
                "default_generation_settings" => %{"n_ctx" => 32768}
              }
          end

        {:ok, %{status: 200, body: body}}
      else
        {:ok, %{status: 401, body: %{"error" => %{"message" => "missing or wrong API key"}}}}
      end
    end)

    on_exit(fn -> Application.delete_env(:eab, :http_request) end)
    {:ok, view, _} = live(build_conn(), "/")
    view |> form("#connection", connection: %{url: "http://fixture", key: ""}) |> render_change()
    assert render_async(view) =~ "requires an API key (HTTP 401)"
    assert has_element?(view, "#run[disabled]")

    view
    |> form("#connection", connection: %{url: "http://fixture", key: "synthetic-key"})
    |> render_change()

    assert render_async(view) =~ "CONNECTED · STRATA"
    refute has_element?(view, "[role=alert]")
    assert has_element?(view, "#run:not([disabled])")
  end

  test "a large synthetic inventory is paginated and failures explain named checks before raw logs" do
    id = "large-inventory-test"
    cases = for n <- 1..500, do: "synthetic-#{n}"

    grade =
      Eab.Evidence.summarize(%{
        "passed" => false,
        "hidden" => %{
          "passed" => false,
          "completed" => true,
          "test_results" => %{"required behavior" => "failed"},
          "output" => "  1) required behavior\nAssertion failed"
        }
      })

    Eab.Store.write("runs/#{id}/run.json", %{
      "id" => id,
      "created_at" => "9999-01-01T00:00:00Z",
      "status" => "cancelled",
      "phase" => "cancelled",
      "cases" => cases,
      "attempts" => %{"synthetic-1" => %{"status" => "completed", "grade" => grade}},
      "settings" => %{},
      "model" => %{"model" => "fixture"}
    })

    Eab.Store.write("runs/#{id}/synthetic-1/grade.json", %{"full" => "output"})
    on_exit(fn -> File.rm_rf!(Eab.Store.path("runs/#{id}")) end)
    {:ok, view, html} = live(build_conn(), "/")
    assert html =~ "/500"
    assert has_element?(view, "#case-synthetic-25")
    refute has_element?(view, "#case-synthetic-26")
    view |> element("#case-synthetic-1") |> render_click()
    assert has_element?(view, "#case-panel-synthetic-1 #case-verdict", "Acceptance did not pass")
    assert has_element?(view, "#case-verdict", "required behavior")
    assert has_element?(view, "#case-verdict a[href='/artifacts/#{id}/synthetic-1/grade.json']")
    view |> element("button[phx-click='case_page'][phx-value-direction='next']") |> render_click()
    assert has_element?(view, "#case-synthetic-26")
    refute has_element?(view, "#case-synthetic-1")
    refute has_element?(view, "#case-log")
  end

  test "comparison keeps choices across history pages and paginates case outcomes" do
    cases = for n <- 1..26, do: "synthetic-#{n}"
    ids = for n <- 1..21, do: "comparison-ui-#{n}"
    on_exit(fn -> Enum.each(ids, &File.rm_rf!(Eab.Store.path("runs/#{&1}"))) end)

    for {id, n} <- Enum.with_index(ids, 1) do
      Eab.Store.write("runs/#{id}/run.json", %{
        "id" => id,
        "created_at" => "9999-01-#{String.pad_leading(to_string(n), 2, "0")}T00:00:00Z",
        "status" => "completed",
        "cases" => cases,
        "attempts" =>
          Map.new(cases, &{&1, %{"status" => "completed", "grade" => %{"passed" => n == 21}}}),
        "settings" => %{"max_tokens" => 65536},
        "release_id" => String.duplicate("a", 64),
        "experiment_id" => String.duplicate("b", 64),
        "model" => %{"model" => "Synthetic #{n}"}
      })
    end

    {:ok, view, _} = live(build_conn(), "/")
    view |> form("#compare-runs", comparison: %{ids: ["comparison-ui-21"]}) |> render_change()

    view
    |> element("button[phx-click='history_page'][phx-value-direction='next']")
    |> render_click()

    view |> form("#compare-runs", comparison: %{ids: ["comparison-ui-1"]}) |> render_change()
    view |> form("#compare-runs", comparison: %{ids: ["comparison-ui-1"]}) |> render_submit()
    assert has_element?(view, "table[aria-label='Selected model runs']", "Synthetic 21")
    assert has_element?(view, "table[aria-label='Selected model runs']", "Synthetic 1")
    assert has_element?(view, "table[aria-label='Case outcomes across models']", "Passed")
    assert has_element?(view, "table[aria-label='Case outcomes across models']", "Failed")
    refute has_element?(view, "table[aria-label='Case outcomes across models']", "synthetic-26")

    view
    |> element("button[phx-click='comparison_page'][phx-value-direction='next']")
    |> render_click()

    assert has_element?(view, "table[aria-label='Case outcomes across models']", "synthetic-26")

    view
    |> element("button[phx-click='history_page'][phx-value-direction='previous']")
    |> render_click()

    assert has_element?(view, "input[value='comparison-ui-21'][checked]")
  end
end
