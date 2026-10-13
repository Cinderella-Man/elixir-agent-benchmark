defmodule Eab.PiTest do
  use ExUnit.Case, async: false
  alias Eab.{Command, Model, Pi, PiGateway, Store}

  setup do
    prefix = "runs/pi-test-#{System.unique_integer([:positive])}/case"
    Store.write("#{prefix}/attempt.json", %{})

    on_exit(fn ->
      Application.delete_env(:eab, :http_request)
      File.rm_rf!(Store.path(Path.dirname(prefix)))
    end)

    %{prefix: prefix}
  end

  defp endpoint(backend),
    do: %{
      "url" => "http://synthetic",
      "backend" => backend,
      "model" => "synthetic-model",
      "context" => 32768
    }

  test "real Pi edits a workspace and finishes using both native adapters, without a setup prompt",
       %{prefix: prefix} do
    parent = self()

    for backend <- ["llama_cpp", "strata"] do
      model = endpoint(backend)
      settings = Model.settings(model)
      path = "#{prefix}/#{backend}"
      workspace = Store.path("#{path}/workspace")
      File.mkdir_p!(workspace)

      config =
        Pi.config(
          model,
          settings,
          "Write repaired.txt containing fixed, then summarize.",
          "Use the write tool."
        )

      Store.write("#{path}/config.json", config)

      Application.put_env(:eab, :http_request, fn opts ->
        payload = opts[:json]

        if String.ends_with?(opts[:url], "tokens") do
          {:ok, %{status: 200, body: %{"input_tokens" => 42}}}
        else
          send(parent, {:generation, backend, payload})

          tool_done =
            Enum.any?(payload["messages"], fn message ->
              message["role"] == "tool" or
                (is_list(message["content"]) and
                   Enum.any?(message["content"], &(&1["type"] == "tool_result")))
            end)

          {:ok, %{status: 200, body: response(backend, tool_done)}}
        end
      end)

      state = Pi.state(model, "secret", settings, path, fn _ -> :ok end)

      run_id = prefix |> String.split("/") |> Enum.at(1)

      result =
        Eab.Activity.with_case(run_id, backend, "secret", fn ->
          Command.exchange(
            "/opt/pi/node",
            ["/opt/pi/bridge.mjs", Store.path("#{path}/config.json")],
            state,
            &Pi.handle/2,
            cd: workspace,
            timeout: 45
          )
        end)

      assert Pi.finish(result) == %{
               "calls" => 2,
               "generated_tokens" => 24,
               "stop_reason" => "agent_completed"
             }

      assert File.read!(Path.join(workspace, "repaired.txt")) == "fixed"
      activity = File.read!(Store.path("runs/#{run_id}/#{backend}/activity.log"))
      assert activity =~ "write"
      assert activity =~ "repaired.txt"
      assert activity =~ "Model call 1"
      assert_receive {:generation, ^backend, first}

      if backend == "strata" do
        assert first["thinking"]["type"] == "enabled"
        assert first["thinking"]["budget_tokens"] > 0
        refute Map.has_key?(first, "reasoning_budget_tokens")
      end

      assert Jason.encode!(first["messages"]) =~ "Write repaired.txt"
      refute Jason.encode!(first["messages"]) =~ "echo with value ready"
      assert_receive {:generation, ^backend, second}
      assert Jason.encode!(second["messages"]) =~ "repaired.txt"
      assert Jason.encode!(second["messages"]) =~ "Investigating the ticket"
      refute_receive {:generation, ^backend, _}
      assert File.read!(Store.path("#{path}/pi-events.jsonl")) =~ "tool_execution_end"
      refute File.read!(Store.path("#{path}/config.json")) =~ "secret"
    end
  end

  test "real Pi stops at the call budget without retrying and keeps the edited file", %{
    prefix: prefix
  } do
    model = endpoint("llama_cpp")
    settings = Model.settings(model, %{"max_calls" => 1})
    workspace = Store.path("#{prefix}/workspace")
    File.mkdir_p!(workspace)

    Store.write(
      "#{prefix}/config.json",
      Pi.config(model, settings, "Repair the file.", "Use write.")
    )

    Application.put_env(:eab, :http_request, fn opts ->
      body =
        if String.ends_with?(opts[:url], "tokens"),
          do: %{"input_tokens" => 42},
          else: response("llama_cpp", false)

      {:ok, %{status: 200, body: body}}
    end)

    opts = [cd: workspace, timeout: 45]

    result =
      Command.exchange(
        "/opt/pi/node",
        ["/opt/pi/bridge.mjs", Store.path("#{prefix}/config.json")],
        Pi.state(model, "", settings, prefix, fn _ -> :ok end),
        &Pi.handle/2,
        opts
      )

    assert Pi.finish(result)["stop_reason"] == "call_budget"
    assert Pi.finish(result)["calls"] == 1
    assert File.read!(Path.join(workspace, "repaired.txt")) == "fixed"
  end

  test "budgets stop forwarding, count exact Pi requests and retain endpoint errors", %{
    prefix: prefix
  } do
    model = endpoint("llama_cpp")
    settings = Model.settings(model)

    frame = %{
      "type" => "request",
      "id" => "1",
      "method" => "POST",
      "path" => "/v1/chat/completions",
      "body" => %{"messages" => [%{"role" => "user", "content" => "ticket"}], "tools" => []}
    }

    state = Pi.state(model, "private-key", settings, prefix, fn _ -> :ok end)

    Application.put_env(:eab, :http_request, fn _ ->
      flunk("Budget must prevent network access")
    end)

    for {state, reason} <- [
          {%{state | calls: settings["max_calls"]}, "call_budget"},
          {%{state | generated_tokens: settings["max_tokens"]}, "token_budget"}
        ] do
      {reply, stopped} = PiGateway.request(frame, state)
      assert reply["status"] == 429
      assert stopped.stop_reason == reason
    end

    Application.put_env(:eab, :http_request, fn opts ->
      assert String.ends_with?(opts[:url], "input_tokens")
      {:ok, %{status: 200, body: %{"input_tokens" => settings["window_tokens"]}}}
    end)

    {_, stopped} = PiGateway.request(frame, state)
    assert stopped.stop_reason == "context_budget"
    assert stopped.calls == 0

    Application.put_env(:eab, :http_request, fn _ -> raise "server failure private-key" end)
    {reply, failed} = PiGateway.request(frame, state)
    assert reply["status"] == 502
    assert failed.error == "server failure [REDACTED]"
    assert Store.read("#{prefix}/agent-progress.json")["error"] == failed.error
  end

  test "Pi config cannot inherit credentials, compaction, retries or extra tools" do
    config =
      Pi.config(endpoint("strata"), Model.settings(endpoint("strata")), "ticket", "instructions")

    refute Jason.encode!(config) =~ "http://synthetic"
    assert config["settings"]["compaction"]["enabled"] == false
    assert config["settings"]["retry"]["enabled"] == false
    assert config["settings"]["retry"]["provider"]["maxRetries"] == 0
    assert config["models"]["providers"]["benchmark"]["api"] == "anthropic-messages"
  end

  defp sse(events), do: Enum.map_join(events, fn e -> "data: " <> Jason.encode!(e) <> "\n\n" end)

  defp response("llama_cpp", done) do
    delta =
      if done,
        do: %{"role" => "assistant", "content" => "Done."},
        else: %{
          "role" => "assistant",
          "tool_calls" => [
            %{
              "index" => 0,
              "id" => "call_1",
              "type" => "function",
              "function" => %{
                "name" => "write",
                "arguments" => Jason.encode!(%{"path" => "repaired.txt", "content" => "fixed"})
              }
            }
          ]
        }

    sse([
      %{
        "id" => "synthetic",
        "choices" => [
          %{
            "index" => 0,
            "delta" => %{"reasoning_content" => "Investigating the ticket"},
            "finish_reason" => nil
          }
        ]
      },
      %{
        "id" => "synthetic",
        "choices" => [%{"index" => 0, "delta" => delta, "finish_reason" => nil}]
      },
      %{
        "id" => "synthetic",
        "choices" => [
          %{
            "index" => 0,
            "delta" => %{},
            "finish_reason" => if(done, do: "stop", else: "tool_calls")
          }
        ],
        "usage" => %{"prompt_tokens" => 42, "completion_tokens" => 12}
      }
    ]) <> "data: [DONE]\n\n"
  end

  defp response("strata", done) do
    block =
      if done,
        do: %{"type" => "text", "text" => ""},
        else: %{"type" => "tool_use", "id" => "call_1", "name" => "write", "input" => %{}}

    delta =
      if done,
        do: %{"type" => "text_delta", "text" => "Done."},
        else: %{
          "type" => "input_json_delta",
          "partial_json" => Jason.encode!(%{"path" => "repaired.txt", "content" => "fixed"})
        }

    events = [
      %{
        "type" => "message_start",
        "message" => %{
          "id" => "synthetic",
          "type" => "message",
          "role" => "assistant",
          "content" => [],
          "model" => "synthetic-model",
          "usage" => %{"input_tokens" => 42, "output_tokens" => 0}
        }
      },
      %{
        "type" => "content_block_start",
        "index" => 0,
        "content_block" => %{"type" => "thinking", "thinking" => "", "signature" => ""}
      },
      %{
        "type" => "content_block_delta",
        "index" => 0,
        "delta" => %{"type" => "thinking_delta", "thinking" => "Investigating the ticket"}
      },
      %{"type" => "content_block_stop", "index" => 0},
      %{"type" => "content_block_start", "index" => 1, "content_block" => block},
      %{"type" => "content_block_delta", "index" => 1, "delta" => delta},
      %{"type" => "content_block_stop", "index" => 1},
      %{
        "type" => "message_delta",
        "delta" => %{
          "stop_reason" => if(done, do: "end_turn", else: "tool_use"),
          "stop_sequence" => nil
        },
        "usage" => %{"input_tokens" => 32, "cache_read_input_tokens" => 10, "output_tokens" => 12}
      },
      %{"type" => "message_stop"}
    ]

    Enum.map_join(events, fn e -> "event: " <> e["type"] <> "\n" <> sse([e]) end)
  end
end
