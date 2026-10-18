defmodule Eab.ModelIdentityTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint EabWeb.Endpoint

  test "discovery records the artifact identity and size while preserving the request alias" do
    Application.put_env(:eab, :http_request, fn opts ->
      body =
        case URI.parse(opts[:url]).path do
          "/health" ->
            %{"status" => "ok"}

          "/v1/models" ->
            %{
              "data" => [
                %{
                  "id" => "volta-a",
                  "meta" => %{"size" => 17_431_404_544, "n_params" => 27_320_697_856}
                }
              ]
            }

          "/props" ->
            %{
              "model_alias" => "volta-a",
              "model_path" => "/models/Swift-1.5-Qwen3.8-27B-Q4_K_M.gguf",
              "default_generation_settings" => %{"n_ctx" => 262_144}
            }
        end

      {:ok, %{status: 200, body: body}}
    end)

    on_exit(fn -> Application.delete_env(:eab, :http_request) end)
    endpoint = Eab.Model.discover("http://fixture")
    assert endpoint["model"] == "volta-a"
    assert endpoint["identity"]["name"] == "Swift-1.5-Qwen3.8-27B"
    assert endpoint["identity"]["quantization"] == "Q4_K_M"
    assert endpoint["identity"]["size_bytes"] == 17_431_404_544
    assert Eab.ModelIdentity.size_label(endpoint) == "17.4 GB"
    assert :ok == Eab.Model.unchanged!(endpoint, "")
  end

  test "shard suffixes do not become model names and unknown sizes are not guessed" do
    model = %{
      "model" => "flash-next-uncensored",
      "profile" => %{
        "model_path" => "/models/Qwen3.8-Flash-Next-GSQ-RCO-abliterated-IQ3_S-00001-of-00002.gguf"
      }
    }

    assert Eab.ModelIdentity.label(model) == "Qwen3.8-Flash-Next-GSQ-RCO-abliterated · IQ3_S"
    assert Eab.ModelIdentity.details(model)["size_bytes"] == nil
    assert Eab.ModelIdentity.details(%{"model" => "gpt-6-astra"})["quantization"] == nil
  end

  test "saved runs show the artifact name and quantization rather than their routing alias" do
    id = "identity-display-test"

    run = %{
      "id" => id,
      "created_at" => "9999-01-01T00:00:00Z",
      "status" => "completed",
      "cases" => [],
      "attempts" => %{},
      "settings" => %{},
      "model" => %{
        "model" => "volta-a",
        "backend" => "llama_cpp",
        "profile" => %{
          "model_path" => "/models/Swift-1.5-Qwen3.8-27B-Q4_K_M.gguf",
          "model_ftype" => "Q4_K - Medium"
        },
        "metadata" => %{"model" => %{"meta" => %{"size" => 17_431_404_544}}}
      }
    }

    Eab.Store.write("runs/#{id}/run.json", run)
    Eab.Store.index_run(run)
    # Reproduce an already indexed legacy history entry with its metadata stripped.
    Eab.Store.write(
      "runs/#{id}/summary.json",
      Map.take(run, ~w(id created_at status)) |> Map.put("model", %{"model" => "volta-a"})
    )

    on_exit(fn -> File.rm_rf!(Eab.Store.path("runs/#{id}")) end)

    {:ok, view, _} = live(build_conn(), "/")
    assert has_element?(view, ".run-model", "Swift-1.5-Qwen3.8-27B · Q4_K_M")
    assert has_element?(view, ".history-row strong", "Swift-1.5-Qwen3.8-27B · Q4_K_M")
    refute has_element?(view, ".run-model", "volta-a")
    summary = Eab.Store.read("runs/#{id}/summary.json")
    assert summary["model"]["identity"]["quantization"] == "Q4_K_M"
    assert summary["model"]["identity"]["size_bytes"] == 17_431_404_544
    refute Map.has_key?(summary["model"], "metadata")
    assert Eab.Store.read("runs/#{id}/run.json") == run

    Eab.Report.write(run)
    assert File.read!(Eab.Store.path("runs/#{id}/report.md")) =~ "Swift-1.5-Qwen3.8-27B · Q4_K_M"
  end
end
