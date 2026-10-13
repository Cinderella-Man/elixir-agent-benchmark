defmodule EabWeb.DashboardLive do
  use Phoenix.LiveView
  alias Eab.{Inventory, Model, Runner, Runs, Store}

  @defaults %{
    "window_tokens" => "",
    "response_tokens" => "",
    "max_calls" => "32",
    "max_tokens" => "65536",
    "seed" => "101"
  }
  def mount(_, _, socket) do
    if connected?(socket) do
      Runs.subscribe()
      Process.send_after(self(), :poll_log, 1_000)
    end

    snapshot = Runs.snapshot()
    selected = (snapshot.active || List.first(snapshot.history) || %{})["id"]

    {:ok,
     assign(socket,
       snapshot: snapshot,
       endpoint: nil,
       url: "",
       key: "",
       settings: @defaults,
       error: nil,
       detecting: false,
       selected: selected,
       selected_case: nil,
       log_case: nil,
       log_text: "",
       log_available: false,
       follow_output: true,
       artifacts: if(selected, do: Store.artifacts(selected), else: []),
       cases: Enum.map(Inventory.all(), &Inventory.spec/1)
     )
     |> load_log()}
  end

  def handle_event("connect", %{"connection" => values}, socket) do
    url = values["url"] || ""
    key = values["key"] || ""

    socket =
      socket
      |> cancel_async(:discovery)
      |> assign(url: url, key: key, endpoint: nil, error: nil, detecting: String.trim(url) != "")

    {:noreply,
     start_async(socket, :discovery, fn ->
       try do
         {:ok, if(String.trim(url) == "", do: nil, else: Model.discover(url, key))}
       rescue
         e -> {:error, Exception.message(e)}
       end
     end)}
  end

  def handle_event("settings", %{"settings" => values}, socket),
    do: {:noreply, assign(socket, settings: Map.merge(socket.assigns.settings, values))}

  def handle_event("run", _, %{assigns: %{endpoint: nil}} = socket),
    do: {:noreply, assign(socket, error: "Connect to a model first")}

  def handle_event("run", _, socket) do
    case Runs.start(socket.assigns.endpoint, socket.assigns.key, socket.assigns.settings) do
      {:ok, id} ->
        {:noreply, refresh(assign(socket, selected: id, selected_case: nil, error: nil))}

      {:error, message} ->
        {:noreply, assign(socket, error: message)}
    end
  end

  def handle_event("stop", _, socket) do
    Runs.stop()
    {:noreply, refresh(socket)}
  end

  def handle_event("retry_cleanup", _, socket) do
    Runs.retry_cleanup()
    {:noreply, refresh(socket)}
  end

  def handle_event("select", %{"id" => id}, socket),
    do: {:noreply, refresh(assign(socket, selected: id, selected_case: nil))}

  def handle_event("select_case", %{"id" => id}, socket) do
    run = selected(socket.assigns)

    if run && id in run["cases"],
      do: {:noreply, load_log(assign(socket, selected_case: id))},
      else: {:noreply, socket}
  end

  def handle_event("follow_output", _, socket),
    do: {:noreply, assign(socket, follow_output: not socket.assigns.follow_output)}

  def handle_async(:discovery, {:ok, {:ok, endpoint}}, socket),
    do: {:noreply, assign(socket, endpoint: endpoint, detecting: false, error: nil)}

  def handle_async(:discovery, {:ok, {:error, error}}, socket),
    do: {:noreply, assign(socket, detecting: false, error: error)}

  def handle_async(:discovery, {:exit, _}, socket),
    do:
      {:noreply,
       assign(socket, detecting: false, error: "Model discovery stopped. Try connecting again.")}

  def handle_info(:runs_changed, socket), do: {:noreply, refresh(socket)}

  def handle_info(:poll_log, socket) do
    Process.send_after(self(), :poll_log, 1_000)
    {:noreply, load_log(socket)}
  end

  defp refresh(socket) do
    snapshot = Runs.snapshot()
    selected = socket.assigns.selected || (snapshot.active && snapshot.active["id"])

    assign(socket,
      snapshot: snapshot,
      selected: selected,
      artifacts: if(selected, do: Store.artifacts(selected), else: [])
    )
    |> load_log()
  end

  defp load_log(socket) do
    run = selected(socket.assigns)
    id = run && (socket.assigns.selected_case || run["current_case"] || List.first(run["cases"]))

    case run && id && Store.tail_artifact(run["id"], "#{id}/activity.log") do
      {:ok, text} ->
        assign(socket, log_case: id, log_text: text, log_available: true)

      _ ->
        assign(socket,
          log_case: id,
          log_text: "No command output has been recorded for this case yet.",
          log_available: false
        )
    end
  end

  defp selected(assigns),
    do:
      Enum.find(assigns.snapshot.history, &(&1["id"] == assigns.selected)) ||
        List.first(assigns.snapshot.history)

  defp outcome(nil), do: "Pending"
  defp outcome(%{"status" => "completed", "grade" => %{"passed" => true}}), do: "Passed"
  defp outcome(%{"status" => "completed", "grade" => %{"passed" => false}}), do: "Failed"
  defp outcome(attempt), do: String.capitalize(attempt["status"] || "incomplete")

  defp case_status(run, id) do
    if run["status"] == "running" and run["current_case"] == id do
      case run["phase"] do
        "preparing" -> "Preparing"
        "qualifying" -> "Checking tests"
        "running" -> "Pi running"
        "grading" -> "Grading"
        _ -> outcome(run["attempts"][id])
      end
    else
      cond do
        run["status"] == "error" and run["current_case"] == id ->
          "Error"

        is_nil(run["attempts"][id]) and get_in(run, ["case_phases", id]) == "ready" ->
          "Ready for Pi"

        true ->
          outcome(run["attempts"][id])
      end
    end
  end

  defp model_detail(endpoint, field) do
    metadata = endpoint["metadata"]["model"]
    get_in(metadata, ["meta", field]) || metadata[field] || "Not reported"
  end

  def render(assigns) do
    assigns = assign(assigns, run: selected(assigns))

    ~H"""
    <main>
      <header class="masthead">
        <a class="brand" href="/"><span class="mark">λ</span> ELIXIR / AGENT BENCHMARK</a>
        <span class="local"><i></i> LOCAL WORKSPACE</span>
      </header>
      <section class="intro">
        <div>
          <p class="eyebrow">REAL REPOSITORIES. REAL REPAIRS.</p><h1>
            Put your model<br />to the test.
          </h1>
          <p class="lede">
            Twelve historical pull requests. Pi in Docker.<br />Executable results you can inspect.
          </p>
        </div>
        <div class="inventory-number">
          <strong>12</strong><span>PR CASES</span><p>06 Plausible · 06 Livebook</p>
        </div>
      </section>
      <div :if={@error} class="notice error" role="alert">{@error}</div>
      <div :if={@snapshot.cleanup_error} class="notice error" role="alert">
        Container cleanup needs attention: {@snapshot.cleanup_error}
        <button class="secondary" phx-click="retry_cleanup">Retry cleanup</button>
      </div>
      <div class="workspace">
        <section class="panel setup">
          <div class="section-title">
            <span class="step">01</span><h2>Connect a model</h2>
          </div>
          <p class="muted">
            A running llama.cpp or Strata server. We’ll read its model details automatically.
          </p>
          <form id="connection" phx-change="connect" phx-submit="connect">
            <label for="endpoint">Server endpoint</label>
            <div class="input-row">
              <input
                id="endpoint"
                name="connection[url]"
                type="url"
                placeholder="http://localhost:8080"
                value={@url}
                phx-debounce="600"
                required
                autocomplete="url"
              /><button type="submit" class="secondary" disabled={@detecting}>Connect</button>
            </div>
            <details>
              <summary>Server credentials</summary><label for="key">API key
              <span class="muted">— optional, kept in memory</span></label><input
                id="key"
                name="connection[key]"
                type="password"
                value={@key}
                phx-debounce="600"
                autocomplete="off"
              />
            </details>
          </form>
          <div :if={@detecting} class="model-card" role="status">Reading model details…</div>
          <div :if={@endpoint} class="model-card">
            <span class="badge">CONNECTED · {if @endpoint["backend"] == "strata",
              do: "STRATA",
              else: "LLAMA.CPP"}</span>
            <h3>{@endpoint["model"]}</h3>
            <dl>
              <div>
                <dt>Context capacity</dt><dd>{@endpoint["context"]} tokens</dd>
              </div><div>
                <dt>Quantization</dt><dd>{model_detail(@endpoint, "ftype")}</dd>
              </div><div>
                <dt>Parameters</dt><dd>{model_detail(@endpoint, "n_params")}</dd>
              </div><div>
                <dt>Server build</dt><dd>{@endpoint["profile"]["build_info"] || "Not reported"}</dd>
              </div>
            </dl>
            <p class="fine-print">Server-reported metadata. Artifact identity is unverified.</p>
          </div>
          <form id="settings" phx-change="settings">
            <details class="advanced">
              <summary>Advanced run settings</summary>
              <p class="fine-print">
                Defaults use the detected context up to 262,144 tokens. Full history is retained.
              </p>
              <div class="settings-grid">
                <label :for={
                  {key, title} <- [
                    {"window_tokens", "Context tokens (blank = automatic)"},
                    {"response_tokens", "Tokens per response (blank = up to 8,192)"},
                    {"max_calls", "Model calls per case"},
                    {"max_tokens", "Generated tokens per case"},
                    {"seed", "Seed"}
                  ]
                }>{title}<input
                  type="number"
                  min={if key == "seed", do: "0", else: "1"}
                  name={"settings[#{key}]"}
                  value={@settings[key]}
                /></label>
              </div>
            </details>
          </form>
          <button
            id="run"
            class="primary"
            phx-click="run"
            disabled={
              is_nil(@endpoint) or @detecting or not is_nil(@snapshot.active) or @snapshot.cleaning or
                not is_nil(@snapshot.cleanup_error)
            }
          >Run benchmark <span>↗</span></button>
          <p class="fine-print">
            Each case is prepared, attempted by Pi and graded before the next starts. First setup downloads the required images and dependencies.
          </p>
        </section>
        <section class="panel results">
          <div class="section-title">
            <span class="step">02</span><h2>Follow the run</h2><button
              :if={@snapshot.active}
              class="danger"
              phx-click="stop"
            >Stop run</button>
          </div>
          <div :if={is_nil(@run)} class="empty">
            <div class="empty-glyph">⌘</div><h3>Ready when you are.</h3><p>
              Connect your model and start a run.<br />Progress and results will appear here.
            </p>
          </div>
          <div :if={@run}>
            <div class="run-heading">
              <span class="badge">{String.upcase(@run["phase"])}</span><code>{@run["id"]}</code>
            </div>
            <h3>{@run["model"]["model"]}</h3><p role="status">{@run["message"]}</p>
            <div class="scoreboard">
              <div>
                <strong>{Runner.score(@run)["passed"]}<small>/12</small></strong><span>Passed</span>
              </div><div><strong>{Runner.score(@run)["failed"]}</strong><span>Failed</span></div><div>
                <strong>{if Runner.score(@run)["score_percent"],
                  do: "#{Runner.score(@run)["score_percent"]}%",
                  else: "—"}</strong><span>Final score</span>
              </div>
            </div>
            <p class="fine-print">Errors and incomplete attempts prevent a final score.</p>
            <p :if={"report.md" in @artifacts}>
              <a href={"/artifacts/#{@run["id"]}/report.md"} download>Download report ↓</a>
            </p>
            <table>
              <thead>
                <tr>
                  <th>Case</th><th>Result</th>
                </tr>
              </thead><tbody>
                <tr :for={id <- @run["cases"]} class={if id == @log_case, do: "selected-case"}>
                  <td>
                    <button
                      id={"case-#{id}"}
                      class="case-link"
                      phx-click={
                        Phoenix.LiveView.JS.push("select_case")
                        |> Phoenix.LiveView.JS.focus(to: "#case-log")
                      }
                      phx-value-id={id}
                      aria-controls="case-console"
                      aria-pressed={id == @log_case}
                    >{id} <span aria-hidden="true">↗</span></button>
                  </td><td>
                    <span class={"outcome " <> String.downcase(outcome(@run["attempts"][id]))}>{case_status(
                      @run,
                      id
                    )}</span>
                  </td>
                </tr>
              </tbody>
            </table>
            <section
              :if={@log_case}
              id="case-console"
              class="case-console"
              aria-label="Case command output"
            >
              <div class="console-heading">
                <div>
                  <span class="eyebrow">COMMAND OUTPUT</span><h3>{@log_case}</h3>
                </div><span class="badge">{case_status(@run, @log_case)}</span>
              </div>
              <p
                :if={@run["status"] == "running" and @run["current_case"] == @log_case}
                class="fine-print"
              >
                {@run["message"]}
              </p>
              <p :if={get_in(@run, ["attempts", @log_case, "error"])} class="notice error">
                {get_in(@run, ["attempts", @log_case, "error"])}
              </p>
              <div class="console-actions">
                <button class="secondary" phx-click="follow_output" aria-pressed={@follow_output}>Follow output: {if @follow_output,
                  do: "on",
                  else: "off"}</button>
                <a
                  :if={@log_available}
                  id="case-log-download"
                  href={"/artifacts/#{@run["id"]}/#{@log_case}/activity.log"}
                  download
                >Download full log ↓</a>
              </div>
              <pre
                id="case-log"
                phx-hook="LogTail"
                data-follow={to_string(@follow_output)}
                data-case={"#{@run["id"]}/#{@log_case}"}
                tabindex="0"
              >{@log_text}</pre>
              <p class="fine-print">
                Updates every second. Docker setup, test output, model responses and Pi tool commands appear here.
              </p>
            </section>
            <details>
              <summary>Run settings and evidence</summary><pre>{Jason.encode!(@run["settings"], pretty: true)}</pre>
              <p class="fine-print">
                Transcripts, submitted patches, fixture controls and grading output.
              </p>
              <ul class="artifacts">
                <li :for={file <- @artifacts}>
                  <a href={"/artifacts/#{@run["id"]}/#{URI.encode(file)}"} download>{file}</a>
                </li>
              </ul>
            </details>
          </div>
        </section>
      </div>
      <section class="history panel">
        <div class="section-title">
          <h2>Run history</h2><span class="muted">Each run stands on its own.</span>
        </div>
        <p :if={@snapshot.history == []} class="muted">
          Your completed and interrupted runs will be kept here.
        </p>
        <button
          :for={run <- @snapshot.history}
          class="history-row"
          phx-click="select"
          phx-value-id={run["id"]}
        ><span><strong>{run["model"]["model"]}</strong><code>{run["id"]}</code></span><span>{run[
          "status"
        ]} →</span></button>
      </section>
      <details class="case-inventory">
        <summary>Explore the twelve historical cases</summary><div class="case-grid">
          <article :for={spec <- @cases}>
            <span class="eyebrow">{spec["id"]}</span><h3>{spec["title"]}</h3><a
              href={spec["source_inspiration"]["url"]}
              target="_blank"
              rel="noopener noreferrer"
            >Upstream pull request ↗</a>
          </article>
        </div>
      </details>
      <footer>
        ELIXIR AGENT BENCHMARK <span>Behavioral checks. No AI judge. No speed score.</span>
      </footer>
    </main>
    """
  end
end
