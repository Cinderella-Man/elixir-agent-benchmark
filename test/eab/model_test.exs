defmodule Eab.ModelTest do
  use ExUnit.Case, async: false
  alias Eab.Model

  setup do
    on_exit(fn -> Application.delete_env(:eab, :http_request) end)
    :ok
  end

  defp endpoint(backend \\ "llama_cpp"),
    do: %{"backend" => backend, "model" => "test", "url" => "http://fixture", "context" => 32768}

  test "automatic budgets adapt to capacity and invalid overrides are rejected" do
    assert Model.settings(endpoint())["window_tokens"] == 32768
    assert Model.settings(%{"context" => 500_000})["window_tokens"] == 262_144

    assert_raise ArgumentError, fn ->
      Model.settings(endpoint(), %{"window_tokens" => "50000"})
    end

    assert_raise ArgumentError, fn -> Model.settings(endpoint(), %{"max_calls" => "1oops"}) end
  end

  test "stream accounting includes cached input and rejects missing or excessive usage" do
    strata =
      "data: " <>
        Jason.encode!(%{
          "type" => "message_delta",
          "usage" => %{
            "input_tokens" => 10,
            "cache_read_input_tokens" => 90,
            "output_tokens" => 12
          }
        }) <> "\n\ndata: {\"type\":\"message_stop\"}\n\n"

    assert Model.stream_usage(endpoint("strata"), strata, 100, 20)["output_tokens"] == 12
    assert_raise RuntimeError, fn -> Model.stream_usage(endpoint("strata"), strata, 10, 20) end
    assert_raise RuntimeError, fn -> Model.stream_usage(endpoint("strata"), strata, 100, 11) end

    llama =
      "data: " <>
        Jason.encode!(%{
          "choices" => [%{"finish_reason" => "stop"}],
          "usage" => %{"prompt_tokens" => 20, "completion_tokens" => 5}
        }) <> "\n\ndata: [DONE]\n\n"

    assert Model.stream_usage(endpoint(), llama, 20, 8)["output_tokens"] == 5
    assert_raise RuntimeError, fn -> Model.stream_usage(endpoint(), "data: [DONE]\n\n", 20, 8) end

    assert_raise RuntimeError, fn ->
      Model.stream_usage(endpoint(), String.replace(llama, "[DONE]", ""), 20, 8)
    end
  end

  test "discovery is non-generating and redacts credentials from returned metadata" do
    parent = self()

    Application.put_env(:eab, :http_request, fn opts ->
      send(parent, {:request, opts})

      body =
        case URI.parse(opts[:url]).path do
          "/health" ->
            %{"status" => "ok", "service" => "strata", "loaded" => true}

          "/v1/models" ->
            %{"data" => [%{"id" => "test", "note" => "secret-token"}]}

          "/props" ->
            %{"model_alias" => "test", "default_generation_settings" => %{"n_ctx" => 32768}}
        end

      {:ok, %{status: 200, body: body}}
    end)

    result = Model.discover("http://fixture/v1", "secret-token")
    assert result["backend"] == "strata"
    refute Jason.encode!(result) =~ "secret-token"

    for _ <- 1..3 do
      assert_receive {:request, opts}
      assert opts[:method] == :get
      assert opts[:redirect] == false
    end
  end

  test "URL parsing forbids embedded secrets and Strata counting is non-generating" do
    assert_raise ArgumentError, fn -> Model.normalize_url!("http://user:secret@host") end
    parent = self()

    Application.put_env(:eab, :http_request, fn opts ->
      send(parent, {:request, opts})
      {:ok, %{status: 200, body: %{"input_tokens" => 42}}}
    end)

    assert Model.count(endpoint("strata"), "", %{"messages" => []}) == 42
    assert_receive {:request, opts}
    assert opts[:url] == "http://fixture/v1/messages/count_tokens"
  end

  test "authentication failures explain the credentials field without blaming JSON or revealing keys" do
    Application.put_env(:eab, :http_request, fn _ ->
      {:ok,
       %{
         status: 401,
         body: %{
           "error" => %{"type" => "authentication_error", "message" => "missing or wrong API key"}
         }
       }}
    end)

    assert_raise RuntimeError,
                 "Endpoint /v1/models requires an API key (HTTP 401). Enter the server's API key under Server credentials and reconnect.",
                 fn ->
                   Model.http("http://fixture", "", :get, "/v1/models")
                 end

    assert_raise RuntimeError,
                 "Endpoint /v1/models rejected the API key (HTTP 401). Check Server credentials and reconnect.",
                 fn ->
                   Model.http("http://fixture", "private-key", :get, "/v1/models")
                 end
  end

  test "HTTP errors and successful non-JSON replies are reported separately" do
    Application.put_env(:eab, :http_request, fn _ ->
      {:ok, %{status: 503, body: "Unavailable"}}
    end)

    assert_raise RuntimeError, "Endpoint /props returned HTTP 503", fn ->
      Model.http("http://fixture", "", :get, "/props")
    end

    Application.put_env(:eab, :http_request, fn _ ->
      {:ok, %{status: 200, body: "<html>Login</html>"}}
    end)

    assert_raise RuntimeError,
                 "Endpoint /props returned HTTP 200 with an unexpected response format; expected a JSON object",
                 fn ->
                   Model.http("http://fixture", "", :get, "/props")
                 end
  end
end
