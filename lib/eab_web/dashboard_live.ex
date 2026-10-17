defmodule EabWeb.DashboardLive do
  use Phoenix.LiveView
  alias Eab.{Comparison, Evidence, Inventory, Model, Retention, Runner, Runs, Storage, Store}

  @defaults %{
    "window_tokens" => "",
    "response_tokens" => "",
    "max_tokens" => "65536",
    "seed" => "101",
    "reasoning_effort" => "high"
  }
  def mount(params, _, socket) do
    if connected?(socket) do
      Runs.subscribe()
      Process.send_after(self(), :poll_log, 1_000)
    end

    snapshot = Runs.snapshot()
    selected = (snapshot.active || List.first(snapshot.history) || %{})["id"]

    socket =
      assign(socket,
        snapshot: snapshot,
        endpoint: nil,
        url: "",
        local_url: "",
        local_key: "",
        chatgpt: false,
        accounts: Eab.ChatGPTAuth.accounts(),
        account: params["chatgpt"] || "",
        models: [],
        key: "",
        settings: @defaults,
        local_settings: @defaults,
        subscription_settings: Map.put(@defaults, "max_tokens", "262144"),
        error: Phoenix.Flash.get(socket.assigns.flash, :error),
        detecting: false,
        selected: selected,
        selected_run: if(selected, do: Store.run(selected)),
        history_offset: 0,
        comparison: nil,
        comparison_ids: [],
        comparison_offset: 0,
        history_page: Store.run_page(),
        case_offset: 0,
        cache_status: Retention.status(),
        cache_preview: nil,
        cache_busy: false,
        cache_message: nil,
        cache_failures: [],
        storage: nil,
        storage_busy: false,
        selected_case: nil,
        log_case: nil,
        case_attempt: nil,
        log_text: "",
        log_available: false,
        follow_output: true,
        evidence_links: [],
        report_available: false,
        cases: Enum.map(Inventory.all(), &Inventory.spec/1)
      )
      |> load_log()

    if params["chatgpt"],
      do:
        {:ok,
         discover_chatgpt(
           assign(socket,
             url: "https://api.openai.com",
             chatgpt: true,
             settings: Map.put(@defaults, "max_tokens", "262144")
           )
         )},
      else: {:ok, socket}
  end

  def handle_event("provider", %{"provider" => "chatgpt"}, socket) do
    Eab.ChatGPTAuth.retry_requests(socket.assigns.account)

    {:noreply,
     socket
     |> provider_settings(true)
     |> assign(chatgpt: true, url: "https://api.openai.com", key: "")
     |> discover_chatgpt()}
  end

  def handle_event("provider", %{"provider" => "local"}, socket) do
    handle_event(
      "connect",
      %{
        "connection" => %{
          "url" => socket.assigns.local_url,
          "key" => socket.assigns.local_key
        }
      },
      socket
    )
  end

  def handle_event("connect", %{"connection" => values}, socket) do
    url = values["url"] || ""
    key = values["key"] || ""

    socket =
      socket
      |> cancel_async(:discovery)
      |> assign(url: url, key: key, endpoint: nil, error: nil, detecting: String.trim(url) != "")

    if Eab.OpenAI.endpoint?(url) do
      Eab.ChatGPTAuth.retry_requests(socket.assigns.account)

      socket = provider_settings(socket, true)
      {:noreply, discover_chatgpt(assign(socket, chatgpt: true, key: ""))}
    else
      {:noreply,
       socket
       |> provider_settings(false)
       |> assign(chatgpt: false, models: [], local_url: url, local_key: key)
       |> start_async(:discovery, fn ->
         try do
           {:ok, if(String.trim(url) == "", do: nil, else: Model.discover(url, key))}
         rescue
           e -> {:error, Exception.message(e)}
         end
       end)}
    end
  end

  def handle_event("chatgpt_account", %{"account" => id}, socket) do
    Eab.ChatGPTAuth.retry_requests(id)
    {:noreply, discover_chatgpt(assign(socket, account: id, endpoint: nil))}
  end

  def handle_event("chatgpt_model", %{"model" => model}, socket) do
    row = Enum.find(socket.assigns.models, &(&1["slug"] == model))
    endpoint = if row, do: Eab.OpenAI.endpoint(socket.assigns.account, row)
    {:noreply, assign(socket, endpoint: endpoint)}
  end

  def handle_event("chatgpt_sign_out", _, socket) do
    active = socket.assigns.snapshot.active

    if active && get_in(active, ["model", "account_id"]) == socket.assigns.account,
      do: Runs.stop()

    message =
      case Eab.ChatGPTAuth.sign_out(socket.assigns.account) do
        {:ok, _} -> nil
        {:error, error} -> error
      end

    {:noreply,
     socket
     |> cancel_async(:discovery)
     |> assign(
       endpoint: nil,
       models: [],
       detecting: false,
       accounts: Eab.ChatGPTAuth.accounts(),
       error: message
     )}
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

  def handle_event("cache_preview", %{"cache" => %{"case" => id}}, socket) do
    try do
      {:noreply,
       assign(socket,
         cache_preview: Retention.preview(id),
         cache_message: nil,
         cache_failures: [],
         error: nil
       )}
    rescue
      error -> {:noreply, assign(socket, error: Exception.message(error))}
    end
  end

  def handle_event("storage", _, %{assigns: %{storage_busy: true}} = socket),
    do: {:noreply, socket}

  def handle_event("storage", _, socket) do
    {:noreply,
     socket
     |> assign(storage_busy: true)
     |> start_async(:storage, fn ->
       try do
         {:ok, Storage.read()}
       rescue
         error -> {:error, Exception.message(error)}
       end
     end)}
  end

  def handle_event("cache_remove", _, %{assigns: %{cache_preview: nil}} = socket),
    do: {:noreply, socket}

  def handle_event("cache_remove", _, socket) do
    plan = socket.assigns.cache_preview

    {:noreply,
     socket
     |> assign(cache_busy: true, error: nil)
     |> start_async(:cache_remove, fn ->
       try do
         {:ok, Retention.remove(plan["case"], plan["id"])}
       rescue
         error -> {:error, Exception.message(error)}
       end
     end)}
  end

  def handle_event("resume", _, %{assigns: %{endpoint: nil}} = socket),
    do: {:noreply, assign(socket, error: "Reconnect the same model before resuming")}

  def handle_event("resume", _, socket) do
    case Runs.resume(
           socket.assigns.selected,
           socket.assigns.endpoint,
           socket.assigns.key,
           socket.assigns.settings
         ) do
      {:ok, _} -> {:noreply, refresh(assign(socket, error: nil))}
      {:error, message} -> {:noreply, assign(socket, error: message)}
    end
  end

  def handle_event("history_page", %{"direction" => direction}, socket) do
    offset = max(socket.assigns.history_offset + if(direction == "next", do: 20, else: -20), 0)
    {:noreply, refresh(assign(socket, history_offset: offset))}
  end

  def handle_event("compare", params, socket) do
    try do
      ids = comparison_selection(socket, params)
      comparison = Comparison.load(ids)

      {:noreply,
       assign(socket,
         comparison: comparison,
         comparison_ids: ids,
         comparison_offset: 0,
         error: nil
       )}
    rescue
      error -> {:noreply, assign(socket, error: Exception.message(error))}
    end
  end

  def handle_event("comparison_select", params, socket),
    do: {:noreply, assign(socket, comparison_ids: comparison_selection(socket, params))}

  def handle_event("comparison_page", %{"direction" => direction}, socket) do
    offset = max(socket.assigns.comparison_offset + if(direction == "next", do: 25, else: -25), 0)
    {:noreply, assign(socket, comparison_offset: offset)}
  end

  def handle_event("case_page", %{"direction" => direction}, socket) do
    offset = max(socket.assigns.case_offset + if(direction == "next", do: 25, else: -25), 0)
    {:noreply, load_log(assign(socket, case_offset: offset, selected_case: nil))}
  end

  def handle_event("retry_cleanup", _, socket) do
    Runs.retry_cleanup()
    {:noreply, refresh(socket)}
  end

  def handle_event("select", %{"id" => id}, socket),
    do: {:noreply, refresh(assign(socket, selected: id, selected_case: nil, case_offset: 0))}

  def handle_event("select_case", %{"id" => id}, socket) do
    run = selected(socket.assigns)

    if run && id in run["cases"],
      do:
        {:noreply,
         load_log(
           assign(socket,
             selected_case: if(socket.assigns.selected_case == id, do: nil, else: id),
             follow_output: true
           )
         )},
      else: {:noreply, socket}
  end

  def handle_event("follow_output", _, socket),
    do: {:noreply, assign(socket, follow_output: not socket.assigns.follow_output)}

  def handle_async(:discovery, {:ok, {:catalog, rows}}, socket) do
    {:noreply, assign(socket, models: rows, detecting: false, error: nil)}
  end

  def handle_async(:discovery, {:ok, {:ok, endpoint}}, socket),
    do: {:noreply, assign(socket, endpoint: endpoint, detecting: false, error: nil)}

  def handle_async(:storage, {:ok, {:ok, storage}}, socket),
    do: {:noreply, assign(socket, storage: storage, storage_busy: false)}

  def handle_async(:storage, {:ok, {:error, error}}, socket),
    do: {:noreply, assign(socket, storage_busy: false, error: error)}

  def handle_async(:storage, {:exit, _}, socket),
    do: {:noreply, assign(socket, storage_busy: false, error: "Storage inspection stopped")}

  def handle_async(:cache_remove, {:ok, {:ok, result}}, socket) do
    message =
      "Removed #{result["removed_images"]} images. #{length(result["retained_images"])} images could not be removed and were left untouched."

    {:noreply,
     assign(socket,
       cache_busy: false,
       cache_preview: nil,
       cache_status: Retention.status(),
       cache_failures: result["retained_images"],
       cache_message: message
     )}
  end

  def handle_async(:cache_remove, {:ok, {:error, error}}, socket),
    do: {:noreply, assign(socket, cache_busy: false, error: error)}

  def handle_async(:cache_remove, {:exit, _}, socket),
    do:
      {:noreply,
       assign(socket,
         cache_busy: false,
         error: "Cache removal stopped; review the remaining artifacts before retrying"
       )}

  def handle_async(:discovery, {:ok, {:error, error}}, socket),
    do: {:noreply, assign(socket, detecting: false, error: error)}

  def handle_async(:discovery, {:exit, {:shutdown, :cancel}}, socket),
    do: {:noreply, socket}

  def handle_async(:discovery, {:exit, _}, socket),
    do:
      {:noreply,
       assign(socket, detecting: false, error: "Model discovery stopped. Try connecting again.")}

  def handle_info(:runs_changed, socket), do: {:noreply, refresh(socket)}

  def handle_info(:poll_log, socket) do
    Process.send_after(self(), :poll_log, 1_000)
    {:noreply, load_log(socket)}
  end

  defp provider_settings(socket, subscription) do
    cond do
      socket.assigns.chatgpt == subscription ->
        socket

      subscription ->
        assign(socket,
          local_settings: socket.assigns.settings,
          settings: socket.assigns.subscription_settings
        )

      true ->
        assign(socket,
          subscription_settings: socket.assigns.settings,
          settings: socket.assigns.local_settings
        )
    end
  end

  defp discover_chatgpt(socket) do
    accounts = Eab.ChatGPTAuth.accounts()
    account = socket.assigns.account
    selected = Enum.find(accounts, &(&1["id"] == account))

    socket =
      socket
      |> cancel_async(:discovery)
      |> assign(accounts: accounts, endpoint: nil, models: [], detecting: false, error: nil)

    if selected && selected["signed_in"] do
      socket
      |> assign(detecting: true)
      |> start_async(:discovery, fn ->
        try do
          {:catalog, Eab.OpenAI.catalog(account)}
        rescue
          e -> {:error, Exception.message(e)}
        end
      end)
    else
      # Replace the async reference too, so an already queued result from the
      # previous provider cannot reconnect it after the user switches away.
      start_async(socket, :discovery, fn -> {:ok, nil} end)
    end
  end

  defp refresh(socket) do
    snapshot = Runs.snapshot()
    selected = socket.assigns.selected || (snapshot.active && snapshot.active["id"])

    assign(socket,
      snapshot: snapshot,
      selected: selected,
      selected_run: if(selected && Store.valid_id?(selected), do: Store.run(selected)),
      history_page: Store.run_page(socket.assigns.history_offset),
      cache_status: Retention.status()
    )
    |> load_log()
  end

  defp comparison_selection(socket, params) do
    visible = Enum.map(socket.assigns.history_page.items, & &1["id"])
    selected = get_in(params, ["comparison", "ids"]) || []

    Enum.uniq(
      (socket.assigns.comparison_ids -- visible) ++ Enum.filter(selected, &(&1 in visible))
    )
  end

  defp load_log(socket) do
    run = selected(socket.assigns)
    id = run && socket.assigns.selected_case
    attempt = if run && id, do: case_attempt(run, id)
    socket = assign(socket, case_attempt: attempt)

    socket =
      assign(socket,
        evidence_links: if(run && id, do: Evidence.links(run["id"], id), else: []),
        report_available: run && match?({:ok, _}, Store.artifact(run["id"], "report.md"))
      )

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

  defp selected(assigns) do
    if assigns.snapshot.active && assigns.snapshot.active["id"] == assigns.selected,
      do: assigns.snapshot.active,
      else: assigns.selected_run
  end

  defp case_attempt(run, id) do
    record =
      if run["experiment_id"],
        do: Store.read("runs/#{run["id"]}/#{id}/attempt.json", get_in(run, ["attempts", id])),
        else: get_in(run, ["attempts", id])

    summary = get_in(run, ["attempts", id])

    if summary && summary["status"] == "error" && record && record["status"] != "error",
      do: summary,
      else: record
  rescue
    _ -> get_in(run, ["attempts", id])
  end

  defp outcome(nil), do: "Pending"
  defp outcome(%{"status" => "completed", "grade" => %{"passed" => true}}), do: "Passed"
  defp outcome(%{"status" => "completed", "grade" => %{"passed" => false}}), do: "Failed"
  defp outcome(attempt), do: String.capitalize(attempt["status"] || "incomplete")

  defp case_status(run, id) do
    phase = get_in(run, ["case_phases", id]) || if(run["current_case"] == id, do: run["phase"])

    if run["status"] == "running" do
      case phase do
        "preparing" -> "Preparing"
        "prepared" -> "Baseline saved"
        "qualifying" -> "Qualifying baseline"
        "ready" -> "Image ready"
        "warming" -> "Starting workspace"
        "warm" -> "Ready for Pi"
        "running" -> "Pi running"
        "submitted" -> "Waiting for grading"
        "grading" -> "Grading submission"
        _ -> outcome(run["attempts"][id])
      end
    else
      cond do
        run["status"] == "error" and run["current_case"] == id ->
          "Error"

        is_nil(run["attempts"][id]) ->
          "Not attempted"

        true ->
          outcome(run["attempts"][id])
      end
    end
  end

  defp case_tone(run, id) do
    case case_status(run, id) do
      "Passed" ->
        "passed"

      "Failed" ->
        "failed"

      "Error" ->
        "error"

      status
      when status in ["Pending", "Not attempted", "Incomplete", "Interrupted", "Cancelled"] ->
        "pending"

      _ ->
        "active"
    end
  end

  defp model_detail(endpoint, field) do
    metadata = endpoint["metadata"]["model"]
    get_in(metadata, ["meta", field]) || metadata[field] || "Not reported"
  end

  def render(assigns) do
    assigns = assign(assigns, run: selected(assigns))

    assigns =
      assign(assigns,
        case_count: length(assigns.cases),
        case_specs: Map.new(assigns.cases, &{&1["id"], &1}),
        score: if(assigns.run, do: Runner.score(assigns.run)),
        error_count:
          if(assigns.run,
            do: Enum.count(assigns.run["cases"], &(case_status(assigns.run, &1) == "Error")),
            else: 0
          ),
        project_counts: Enum.frequencies_by(assigns.cases, &(&1["project"] || &1["suite"]))
      )

    ~H"""
    <main>
      <header class="masthead">
        <a class="brand" href="/"><span class="mark">λ</span> ELIXIR / AGENT BENCHMARK</a>
        <span class="local"><i></i> LOCAL WORKSPACE</span>
      </header>
      <section class="intro">
        <div>
          <p class="eyebrow">MODEL EVALUATION</p>
          <h1>Benchmark dashboard</h1>
          <p class="lede">Real pull requests. Executable checks. Inspect every result.</p>
        </div>
        <div class="inventory-summary">
          <strong>{@case_count} cases</strong>
          <span>{Enum.map_join(Enum.sort(@project_counts), " · ", fn {project, count} ->
            "#{count} #{project}"
          end)}</span>
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
            <span class="section-icon" aria-hidden="true">⌘</span><h2>Run configuration</h2>
          </div>
          <form id="provider-choice" phx-change="provider">
            <fieldset class="provider-options">
              <legend>Model source</legend>
              <label class={["provider-option", @chatgpt && "is-selected"]}>
                <input type="radio" name="provider" value="chatgpt" checked={@chatgpt} />
                <svg
                  aria-hidden="true"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.6"
                >
                  <path d="M20 11a8 8 0 0 1-8 8H5l-4 3V11a9 9 0 0 1 9-9h2a8 8 0 0 1 8 9Z" />
                  <path d="M7 9h8M7 13h5" />
                </svg>
                <span><strong>ChatGPT</strong><small>Use your subscription</small></span>
              </label>
              <label class={["provider-option", not @chatgpt && "is-selected"]}>
                <input type="radio" name="provider" value="local" checked={not @chatgpt} />
                <svg
                  aria-hidden="true"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.6"
                >
                  <rect x="3" y="3" width="18" height="7" rx="2" /><rect
                    x="3"
                    y="14"
                    width="18"
                    height="7"
                    rx="2"
                  />
                  <path d="M7 6.5h.01M7 17.5h.01M11 6.5h6M11 17.5h6" stroke-linecap="round" />
                </svg>
                <span><strong>Local server</strong><small>llama.cpp or Strata</small></span>
              </label>
            </fieldset>
          </form>
          <form :if={not @chatgpt} id="connection" phx-change="connect" phx-submit="connect">
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
          <div :if={@chatgpt} class="chatgpt-connection" id="chatgpt-connection">
            <p class="muted">Sign in to choose a model available to your ChatGPT account.</p>
            <form :if={@accounts != []} id="chatgpt-account-form" phx-change="chatgpt_account">
              <label for="chatgpt-account">ChatGPT account / workspace</label>
              <select id="chatgpt-account" name="account">
                <option value="" selected={@account == ""}>Add an account or workspace</option>
                <option
                  :for={account <- @accounts}
                  value={account["id"]}
                  selected={@account == account["id"]}
                >
                  {account["label"]}{if account["signed_in"], do: "", else: " (sign in required)"}
                </option>
              </select>
            </form>
            <a
              class="secondary chatgpt-sign-in"
              href={EabWeb.ChatGPTController.base_url() <> "/auth/chatgpt?" <> URI.encode_query(%{"account" => @account})}
            >Continue with ChatGPT</a>
            <p class="fine-print">
              Use your usual sign-in method, including Google, on the next page.
            </p>
            <button
              :if={Enum.any?(@accounts, &(&1["id"] == @account and &1["signed_in"]))}
              type="button"
              class="secondary"
              phx-click="chatgpt_sign_out"
            >Sign out</button>
            <p class="fine-print">
              Uses your ChatGPT plan allowance.
              <a href="https://chatgpt.com/settings/usage" target="_blank" rel="noreferrer">Manage usage and access</a>
            </p>
            <form :if={@models != []} id="chatgpt-model-form" phx-change="chatgpt_model">
              <label for="chatgpt-model">Available model</label>
              <select id="chatgpt-model" name="model">
                <option value="" selected={is_nil(@endpoint)}>Choose a model</option>
                <option
                  :for={model <- @models}
                  value={model["slug"]}
                  selected={@endpoint && @endpoint["model"] == model["slug"]}
                >
                  {model["display_name"] || model["slug"]}
                </option>
              </select>
            </form>
          </div>
          <div :if={@detecting} class="model-card" role="status">Reading model details…</div>
          <div :if={@endpoint} class="model-card">
            <span class="badge">CONNECTED · {case @endpoint["backend"] do
              "openai_subscription" -> "CHATGPT"
              "strata" -> "STRATA"
              _ -> "LLAMA.CPP"
            end}</span>
            <h3>{Eab.ModelIdentity.label(@endpoint)}</h3>
            <dl :if={not @chatgpt}>
              <div>
                <dt>Context capacity</dt><dd>{@endpoint["context"]} tokens</dd>
              </div><div>
                <dt>Quantization</dt><dd>
                  {Eab.ModelIdentity.details(@endpoint)["quantization"] || "Not reported"}
                </dd>
              </div><div>
                <dt>Model weights</dt><dd>{Eab.ModelIdentity.size_label(@endpoint)}</dd>
              </div><div>
                <dt>Parameters</dt><dd>{model_detail(@endpoint, "n_params")}</dd>
              </div><div>
                <dt>Server build</dt><dd>{@endpoint["profile"]["build_info"] || "Not reported"}</dd>
              </div>
            </dl>
            <p class="fine-print">
              {@endpoint["identity_note"] ||
                "Server-reported metadata. Artifact identity is unverified."}
            </p>
          </div>
          <form id="settings" phx-change="settings">
            <details class="advanced">
              <summary>Advanced run settings</summary>
              <p :if={not @chatgpt} class="fine-print">
                Defaults use the detected context up to 262,144 tokens. Full history is retained.
                Model and tool calls are unlimited.
              </p>
              <p :if={@chatgpt} class="fine-print">
                Full history is retained. The generated-token threshold is checked between completed responses and can be exceeded by one response. OpenAI controls context and response limits; seed and strict response caps are unavailable. Reasoning tokens count toward the threshold.
              </p>
              <label :if={@chatgpt}>
                Reasoning effort
                <select name="settings[reasoning_effort]">
                  <option
                    :for={effort <- ~w(default low medium high xhigh)}
                    value={effort}
                    selected={@settings["reasoning_effort"] == effort}
                  >
                    {effort}
                  </option>
                </select>
              </label>
              <div class="settings-grid">
                <label :for={
                  {key, title} <-
                    if(@chatgpt,
                      do: [{"max_tokens", "Generated-token threshold per case"}],
                      else: [
                        {"window_tokens", "Context tokens (blank = automatic)"},
                        {"response_tokens", "Tokens per response (blank = up to 8,192)"},
                        {"max_tokens", "Generated tokens per case"},
                        {"seed", "Seed"}
                      ]
                    )
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
              is_nil(@endpoint) or @detecting or @cache_busy or not is_nil(@snapshot.active) or
                @snapshot.cleaning or
                not is_nil(@snapshot.cleanup_error)
            }
          >Run benchmark <span>↗</span></button>
          <p class="fine-print">
            Pi repairs one case at a time. Upcoming cases prepare in the background, and submitted repairs are graded independently. Prepared images and fixture checks are reused across runs.
          </p>
        </section>
        <section class="panel results">
          <div class="section-title">
            <span class="section-icon" aria-hidden="true">▤</span><h2>Benchmark results</h2><button
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
              <span class="badge">{String.upcase(@run["status"])}</span><code>{@run["id"]}</code>
            </div>
            <h3 class="run-model">{Eab.ModelIdentity.label(@run["model"])}</h3><p
              class="run-message"
              role="status"
            >
              {@run["message"]}
            </p>
            <p :if={@run["release_id"]} class="fine-print">
              Release <code>{String.slice(@run["release_id"], 0, 12)}</code>
              · Experiment <code>{String.slice(@run["experiment_id"], 0, 12)}</code>
              · {@run["resume_count"] || 0} resumptions
            </p>
            <p :if={@run["selection"]} class="fine-print">
              Partial run based on {@run["selection"]["source_run"]}. Original outcomes are preserved;
              this run has no full benchmark score.
            </p>
            <button
              :if={@run["release_id"] && @run["status"] in ["interrupted", "cancelled", "error"]}
              id="resume"
              class="secondary"
              phx-click="resume"
              disabled={
                is_nil(@endpoint) or @detecting or @cache_busy or not is_nil(@snapshot.active) or
                  @snapshot.cleaning or
                  not is_nil(@snapshot.cleanup_error)
              }
            >
              Resume unfinished cases
            </button>
            <div class="scoreboard" aria-label="Run score">
              <div class="metric passed">
                <span>Passed</span><strong>{@score["passed"]}</strong>
              </div>
              <div class="metric failed">
                <span>Failed</span><strong>{@score["failed"]}</strong>
              </div>
              <div class="metric error">
                <span>Errors</span><strong>{@error_count}</strong>
              </div>
              <div class="metric final-score">
                <span>Final score</span>
                <strong>{if @score["score_percent"], do: "#{@score["score_percent"]}%", else: "—"}</strong>
              </div>
            </div>
            <p :if={@run["memory"]} class="fine-print" id="run-memory">
              Sampled memory peaks: {Eab.MemoryMonitor.label(@run["memory"])}.
              <a href={"/artifacts/#{@run["id"]}/memory.json"} download>Summary</a>
              · <a href={"/artifacts/#{@run["id"]}/memory-samples.jsonl"} download>Samples</a>
            </p>
            <div class="progress-heading">
              <span>Cases graded</span><strong>{@score["passed"] + @score["failed"]}/{@score[
                "planned"
              ]}</strong>
            </div>
            <svg
              class="run-progress"
              viewBox={"0 0 #{max(@score["planned"], 1)} 1"}
              preserveAspectRatio="none"
              role="progressbar"
              aria-label="Cases graded"
              aria-valuenow={@score["passed"] + @score["failed"]}
              aria-valuemin="0"
              aria-valuemax={max(@score["planned"], 1)}
            >
              <rect class="progress-passed" width={@score["passed"]} height="1" />
              <rect class="progress-failed" x={@score["passed"]} width={@score["failed"]} height="1" />
            </svg>
            <div class="score-note">
              <p class="fine-print">Errors and incomplete attempts prevent a final score.</p>
              <a :if={@report_available} href={"/artifacts/#{@run["id"]}/report.md"} download>Download report ↓</a>
            </div>
            <div class="cases-heading">
              <h3>Cases <span>{@score["planned"]}</span></h3>
              <span>Expand a case to inspect its evidence</span>
            </div>
            <div class="case-list">
              <article
                :for={
                  {id, index} <-
                    Enum.with_index(Enum.slice(@run["cases"], @case_offset, 25), @case_offset + 1)
                }
                class={["case-item", id == @log_case && "is-expanded"]}
              >
                <h4 class="case-heading">
                  <button
                    id={"case-#{id}"}
                    class="case-toggle"
                    phx-click="select_case"
                    phx-value-id={id}
                    aria-controls={"case-panel-#{id}"}
                    aria-expanded={to_string(id == @log_case)}
                  >
                    <span class="case-index">{String.pad_leading(to_string(index), 2, "0")}</span>
                    <span class="case-name">
                      <span class="case-id">{id}</span>
                      <span :if={@case_specs[id]} class="case-description">{@case_specs[id]["title"]}</span>
                    </span>
                    <span class={"case-status " <> case_tone(@run, id)}><i aria-hidden="true"></i>{case_status(
                      @run,
                      id
                    )}</span>
                    <svg
                      class="case-chevron"
                      width="16"
                      height="16"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="1.8"
                      aria-hidden="true"
                    ><path d="m6 9 6 6 6-6" /></svg>
                  </button>
                </h4>
                <section
                  :if={id == @log_case}
                  id={"case-panel-#{id}"}
                  class="case-console"
                  role="region"
                  aria-labelledby={"case-#{id}"}
                >
                  <p
                    :if={@run["status"] == "running"}
                    class="fine-print"
                  >
                    {get_in(@run, ["case_messages", @log_case]) ||
                      if(@run["current_case"] == @log_case, do: @run["message"])}
                  </p>
                  <p :if={get_in(@run, ["attempts", @log_case, "error"])} class="notice error">
                    {get_in(@run, ["attempts", @log_case, "error"])}
                  </p>
                  <section id="case-verdict" aria-label="Case result explanation" tabindex="-1">
                    <h4>
                      {if is_nil(@case_attempt) and case_tone(@run, id) == "active",
                        do: "Awaiting evaluation",
                        else: Evidence.verdict(@case_attempt)}
                    </h4>
                    <p
                      :if={
                        @case_attempt && @case_attempt["status"] in ["completed", "error"] &&
                          is_integer(@case_attempt["generated_tokens"]) &&
                          is_integer(@run["settings"]["max_tokens"])
                      }
                      class="fine-print"
                    >
                      Generated tokens: {@case_attempt["generated_tokens"]} / {@run["settings"][
                        "max_tokens"
                      ]}.
                      <span :if={@run["settings"]["budget_policy"] == "response_boundary_soft_limit"}>Soft threshold, checked between responses. Context is provider-enforced.</span>
                      <span :if={@run["settings"]["budget_policy"] != "response_boundary_soft_limit"}>Context limit: {@run[
                        "settings"
                      ]["window_tokens"]} tokens.</span>
                      Prompt tokens include conversation history and tool output; the generation budget counts model output.
                    </p>
                    <p
                      :if={get_in(@run, ["case_phases", @log_case]) == "qualifying"}
                      class="fine-print"
                    >
                      Checking the unchanged application, reference repair and negative controls before Pi starts this case.
                    </p>
                    <p :if={get_in(@run, ["attempts", @log_case, "stop_reason"])} class="fine-print">
                      Pi stopped: {get_in(@run, ["attempts", @log_case, "stop_reason"])}
                    </p>
                    <div
                      :for={check <- Evidence.checks(@case_attempt)}
                      class="check-result"
                    >
                      <p>
                        <strong>{check["label"]}: {if check["passed"],
                          do: "passed",
                          else: "did not pass"}</strong><span :if={check["completed"] == false}> — check execution did not complete</span>
                      </p>
                      <p :if={check["reason"]}>{check["reason"]}</p>
                      <p :if={check["label"] == "Regression coverage"} class="fine-print">
                        This check runs submitted tests against the original broken code. Failing tests here are expected; they must pass with the submitted repair.
                      </p>
                      <ul :if={check["failures"] != []}>
                        <li :for={failure <- check["failures"]}>
                          <code>{failure["name"]}</code>: expected {failure["expected"]}, observed {failure[
                            "observed"
                          ]}
                        </li>
                      </ul>
                      <p :if={check["failure_count"] > length(check["failures"])} class="fine-print">
                        {check["failure_count"] - length(check["failures"])} additional failures in full grading evidence.
                      </p>
                      <details :if={check["excerpt"]}>
                        <summary>Error excerpt</summary><pre>{check["excerpt"]}</pre>
                      </details>
                    </div>
                    <ul class="artifacts">
                      <li :for={link <- @evidence_links}>
                        <a href={"/artifacts/#{@run["id"]}/#{link["path"]}"} download>{link["label"]} ↓</a>
                      </li>
                    </ul>
                  </section>
                  <div class="console-actions">
                    <span class="console-label">COMMAND OUTPUT</span>
                    <button
                      class="secondary"
                      phx-click="follow_output"
                      aria-pressed={to_string(@follow_output)}
                    >Follow output: {if @follow_output,
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
              </article>
            </div>
            <nav :if={length(@run["cases"]) > 25} aria-label="Case pages">
              <button
                class="secondary"
                phx-click="case_page"
                phx-value-direction="previous"
                disabled={@case_offset == 0}
              >Previous cases</button>
              <span>{@case_offset + 1}–{min(@case_offset + 25, length(@run["cases"]))} of {length(
                @run["cases"]
              )}</span>
              <button
                class="secondary"
                phx-click="case_page"
                phx-value-direction="next"
                disabled={@case_offset + 25 >= length(@run["cases"])}
              >Next cases</button>
            </nav>
            <details>
              <summary>Run settings and evidence</summary><pre>{Jason.encode!(@run["settings"], pretty: true)}</pre>
              <p class="fine-print">
                Select a case for its patch, transcript, environment and grading evidence. Resuming preserves completed failures and evaluation errors; it restarts only unfinished work.
              </p>
              <table :if={@run["case_metadata"]} aria-label="Results by project and task">
                <thead>
                  <tr>
                    <th>Group</th><th>Passed</th><th>Failed</th><th>Incomplete / error</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={row <- Runner.breakdowns(@run)}>
                    <td>{String.replace(row["value"], "_", " ")}</td>
                    <td>{row["passed"]}/{row["planned"]}</td>
                    <td>{row["failed"]}</td><td>{row["pending_or_error"]}</td>
                  </tr>
                </tbody>
              </table>
              <a href={"/artifacts/#{@run["id"]}/run.json"} download>Complete run record ↓</a>
              <p :if={@run["release_id"]}>
                <a href={"/artifacts/#{@run["id"]}/release.json"} download>Frozen release manifest ↓</a>
              </p>
              <div :if={(@run["attempt_history"] || []) != []}>
                <h4>Interrupted generations</h4>
                <p :for={entry <- @run["attempt_history"]}>
                  {entry["case"]}, generation {entry["generation"]}: {entry["generated_tokens"] ||
                    "unknown"} generated tokens, {entry["calls"] || "unknown"} model calls.
                  <a href={"/artifacts/#{@run["id"]}/#{entry["artifacts"]}/activity.log"} download>Prior activity log</a>
                </p>
              </div>
            </details>
          </div>
        </section>
      </div>
      <section class="history panel">
        <div class="section-title">
          <h2>Run history</h2><span class="muted">Each run stands on its own.</span>
        </div>
        <p :if={@history_page.total == 0} class="muted">
          Your completed and interrupted runs will be kept here.
        </p>
        <button
          :for={run <- @history_page.items}
          class="history-row"
          phx-click="select"
          phx-value-id={run["id"]}
        ><span><strong>{Eab.ModelIdentity.label(run["model"])}</strong><code>{run["id"]}</code></span><span>{run[
          "status"
        ]} →</span></button>
        <nav :if={@history_page.total > 20} aria-label="History pages">
          <button
            class="secondary"
            phx-click="history_page"
            phx-value-direction="previous"
            disabled={@history_offset == 0}
          >Newer runs</button>
          <button
            class="secondary"
            phx-click="history_page"
            phx-value-direction="next"
            disabled={@history_offset + 20 >= @history_page.total}
          >Older runs</button>
        </nav>
      </section>
      <details
        class="case-inventory"
        id="comparison"
        open={not is_nil(@comparison) or @comparison_ids != []}
      >
        <summary>Compare model runs</summary>
        <p class="fine-print">
          Choose runs with the same frozen release and effective settings. Repeated runs stay separate; incomplete runs have no final score. Model identities are server-reported.
        </p>
        <p class="fine-print">Selections stay checked when you change history pages.</p>
        <form id="compare-runs" phx-submit="compare" phx-change="comparison_select">
          <label
            :for={run <- @history_page.items}
            class="run-choice"
          >
            <input
              type="checkbox"
              name="comparison[ids][]"
              value={run["id"]}
              checked={run["id"] in @comparison_ids}
            />
            {Eab.ModelIdentity.label(run["model"])} · {run["id"]} · {run["status"]}
          </label>
          <button class="secondary" type="submit">Compare selected runs</button>
        </form>
        <div :if={@comparison}>
          <table aria-label="Selected model runs">
            <thead>
              <tr>
                <th>Run</th><th>Passed</th><th>Final score</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={run <- @comparison["runs"]}>
                <td>{run["model"]}<br /><code>{run["id"]}</code></td>
                <td>{run["score"]["passed"]}/{run["score"]["planned"]}</td>
                <td>
                  {if is_number(run["score"]["score_percent"]),
                    do: "#{run["score"]["score_percent"]}%",
                    else: "Incomplete / error"}
                </td>
              </tr>
            </tbody>
          </table>
          <div class="comparison-scroll">
            <table aria-label="Case outcomes across models">
              <thead>
                <tr>
                  <th>Case</th><th :for={run <- @comparison["runs"]}>
                    {run["model"]}<br /><code>{run["id"]}</code>
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr :for={row <- Enum.slice(@comparison["cases"], @comparison_offset, 25)}>
                  <td>{row["case"]}</td><td :for={outcome <- row["outcomes"]}>{outcome}</td>
                </tr>
              </tbody>
            </table>
          </div>
          <nav :if={length(@comparison["cases"]) > 25} aria-label="Comparison case pages">
            <button
              class="secondary"
              phx-click="comparison_page"
              phx-value-direction="previous"
              disabled={@comparison_offset == 0}
            >Previous cases</button>
            <button
              class="secondary"
              phx-click="comparison_page"
              phx-value-direction="next"
              disabled={@comparison_offset + 25 >= length(@comparison["cases"])}
            >Next cases</button>
          </nav>
        </div>
      </details>
      <details
        class="case-inventory"
        id="cache-controls"
        open={
          not is_nil(@cache_preview) or @cache_busy or not is_nil(@cache_message) or @storage_busy or
            not is_nil(@storage)
        }
      >
        <summary>Retained preparation</summary>
        <p :if={@cache_status["error"]} class="notice error">{@cache_status["error"]}</p>
        <p :if={!@cache_status["error"]}>
          {@cache_status["baselines"]} retained baseline records · {@cache_status["images"]} distinct image references. Shared layers are not summed as storage usage.
        </p>
        <p class="fine-print">
          Baselines persist across models. Removing a case's retained state may require preparation on its next run. Shared images and active work are protected. Engine images, package downloads and Docker build cache remain available.
        </p>
        <button class="secondary" phx-click="storage" disabled={@storage_busy}>Refresh storage usage</button>
        <p :if={@storage_busy} role="status">Reading Docker and controller storage…</p>
        <div :if={@storage}>
          <p>
            Unique to benchmark-tagged images: {Storage.bytes(@storage["owned_unique_bytes"])}. Docker image storage across all projects: {Storage.bytes(
              @storage["daemon_image_bytes"]
            )}.
          </p>
          <p class="fine-print">
            Shared layers are excluded from the unique figure, including layers shared only among benchmark images. Per-image shared sizes must not be added together. These figures are not an estimate of space freed by removal. Snapshot: {@storage[
              "recorded_at"
            ]}.
          </p>
          <table aria-label="Docker storage totals">
            <thead>
              <tr>
                <th>Docker area (all projects)</th><th>Reported size</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={row <- @storage["docker_totals"]}>
                <td>{row["Type"]}</td><td>{row["Size"]}</td>
              </tr>
            </tbody>
          </table>
          <table aria-label="Controller storage">
            <thead>
              <tr>
                <th>Controller area</th><th>Allocated storage</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={{name, bytes} <- Enum.sort(@storage["controller_areas"])}>
                <td>{name}</td><td>{Storage.bytes(bytes)}</td>
              </tr>
            </tbody>
          </table>
          <details>
            <summary>Shared and unique storage per image</summary>
            <table>
              <thead>
                <tr>
                  <th>Image</th><th>Shared</th><th>Unique</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={image <- @storage["images"]}>
                  <td><code>{String.slice(image["image"], 0, 19)}</code></td><td>
                    {Storage.bytes(image["shared"])}
                  </td><td>{Storage.bytes(image["unique"])}</td>
                </tr>
              </tbody>
            </table>
          </details>
        </div>
        <form id="cache-preview" phx-submit="cache_preview">
          <label>Choose cached state<select name="cache[case]">
            <option value="unused">Unreferenced application and database artifacts</option>
            <option :for={id <- @cache_status["releases"] || []} value={"release:" <> id}>
              Release {String.slice(id, 0, 12)}
            </option>
            <option :for={id <- @cache_status["cases"]} value={id}>{id}</option>
          </select></label>
          <button
            class="secondary"
            type="submit"
            disabled={@cache_busy or not is_nil(@cache_status["error"])}
          >Preview removal</button>
        </form>
        <div :if={@cache_preview}>
          <p>
            Remove {@cache_preview["case"]}: {length(@cache_preview["images"])} image references eligible; {@cache_preview[
              "shared_records_preserved"
            ]} shared artifact records preserved.
          </p>
          <p class="fine-print">
            Affected cases: {Enum.join(@cache_preview["affected_cases"], ", ")}. Other retained releases keep their shared artifacts.
          </p>
          <button
            class="danger"
            phx-click="cache_remove"
            disabled={@cache_busy or not is_nil(@snapshot.active) or @snapshot.cleaning}
          >Remove this cached state</button>
        </div>
        <p :if={@cache_busy} role="status">Removing unused cached state…</p>
        <p :if={@cache_message} role="status">{@cache_message}</p>
        <ul :if={@cache_failures != []}>
          <li :for={failure <- @cache_failures}>
            <code>{failure["image"]}</code>: {failure["reason"]}
          </li>
        </ul>
      </details>
      <details class="case-inventory">
        <summary>Explore the {@case_count} historical cases</summary><div class="case-grid">
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
