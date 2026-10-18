defmodule Eab.ResultsTest do
  use ExUnit.Case, async: true
  alias Eab.Results

  setup do
    dir = Path.join(System.tmp_dir!(), "eab-results-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    %{dir: dir}
  end

  defp run do
    %{
      "id" => "test-run",
      "created_at" => "2026-10-17T12:00:00Z",
      "status" => "completed",
      "model" => %{
        "model" => "volta-a",
        "backend" => "llama_cpp",
        "url" => "http://private-host",
        "account_id" => "private-account",
        "profile" => %{
          "model_ftype" => "Q4_K - Medium",
          "model_path" => "/models/Swift-1.5-Qwen3.8-27B-Q4_K_M.gguf"
        },
        "metadata" => %{"model" => %{"meta" => %{"size" => 17_431_404_544}}}
      },
      "release_id" => String.duplicate("a", 64),
      "cases" => ~w(case-a case-b),
      "protocol" => %{
        "inventory" => %{"id" => "example-v1", "cases" => ~w(case-a case-b)},
        "fixtures" => %{
          "case-a" => %{"case.json" => String.duplicate("a", 64)},
          "case-b" => %{"case.json" => String.duplicate("b", 64)}
        }
      },
      "settings" => %{"max_tokens" => 65536, "seed" => 101, "compaction" => false},
      "attempts" => %{
        "case-a" => %{
          "status" => "completed",
          "grade" => %{"passed" => true},
          "trace" => "private-trace"
        },
        "case-b" => %{"status" => "completed", "grade" => %{"passed" => false}}
      }
    }
  end

  defp current do
    inventory = Results.read!("config/benchmark.json")

    Map.merge(run(), %{
      "cases" => inventory["cases"],
      "protocol" => %{
        "inventory" => inventory,
        "fixtures" => Map.new(inventory["cases"], &{&1, Results.fixture_hashes(&1)})
      },
      "attempts" =>
        Map.new(
          inventory["cases"],
          &{&1, %{"status" => "completed", "grade" => %{"passed" => true}}}
        )
    })
  end

  defp snapshot do
    %{
      "kind" => "loaded_snapshot",
      "observed_at" => "2026-10-17T12:00:00Z",
      "model_artifact" => "Swift-1.5-Qwen3.8-27B-Q4_K_M.gguf",
      "backend" => "llama_cpp",
      "backend_version" => "fixture",
      "context_tokens" => 262_144,
      "kv_cache" => "f16",
      "cpu" => "fixture",
      "gpus" => [%{"name" => "Fixture GPU", "capacity_bytes" => 1000, "used_bytes" => 800}],
      "ram_rss_bytes" => 100,
      "ram_lifetime_peak_bytes" => 200,
      "service_ram_bytes" => nil,
      "service_ram_lifetime_peak_bytes" => nil
    }
  end

  test "public export uses exact artifact identity, outcomes and weight size, and omits private data" do
    result = Results.export!(run())
    assert Enum.map(result["cases"], & &1["passed"]) == [true, false]
    assert result["model"]["name"] == "Swift-1.5-Qwen3.8-27B"
    assert result["model"]["quantization"] == "Q4_K_M"
    assert result["model"]["size_bytes"] == 17_431_404_544
    assert result["model"]["size_source"] == "reported"

    for private <- ["private-host", "private-account", "private-trace", "/models/"],
        do: refute(Jason.encode!(result) =~ private)
  end

  test "preserves tokens and only explicit measurements" do
    source =
      run()
      |> put_in(["attempts", "case-a", "generated_tokens"], 1234)
      |> put_in(["attempts", "case-a", "calls"], 12)
      |> put_in(["attempts", "case-a", "measurement"], %{
        "environment" => "synthetic",
        "attempt_ms" => 120_000,
        "inference_ms" => 45000
      })

    [a, b] = Results.export!(source)["cases"]
    assert a["generated_tokens"] == 1234 and a["model_calls"] == 12
    assert a["measurement"]["attempt_ms"] == 120_000
    assert b["measurement"] == nil and b["generated_tokens"] == nil
    bad = put_in(source, ["attempts", "case-a", "measurement", "inference_ms"], 120_001)
    assert_raise ArgumentError, ~r/exceeds attempt/, fn -> Results.export!(bad) end
  end

  test "snapshots must match artifact, backend and context" do
    source = put_in(run(), ["settings", "window_tokens"], 262_144)
    assert Results.export!(source, resources: snapshot())["resources"] == snapshot()

    for {key, value} <- [
          {"context_tokens", 65536},
          {"model_artifact", "Other-Q4_K_M.gguf"},
          {"backend", "strata"},
          {"kind", "benchmark_peak"},
          {"api_key", "private"}
        ] do
      assert_raise ArgumentError, fn ->
        Results.export!(source, resources: Map.put(snapshot(), key, value))
      end
    end
  end

  test "run memory exports simultaneous peaks without private host, service or GPU identity" do
    identity =
      Map.take(snapshot(), ~w(model_artifact backend backend_version context_tokens kv_cache cpu))
      |> Map.merge(%{"host" => "private-machine", "service" => "private.service"})

    session = %{
      "identity" => identity,
      "started_at" => "2026-10-18T00:00:00Z",
      "finished_at" => "2026-10-18T00:00:02Z",
      "sample_count" => 2,
      "interval_ms" => 1000,
      "gap_count" => 0,
      "gpus" => [
        %{
          "uuid" => "private-gpu",
          "name" => "fixture",
          "capacity_bytes" => 1000,
          "used_bytes" => 100
        }
      ]
    }

    memory = %{
      "kind" => "run_samples",
      "status" => "complete",
      "sessions" => [session],
      "sample_count" => 2,
      "peaks" => %{
        "vram_bytes" => 100,
        "service_ram_bytes" => 80,
        "process_rss_bytes" => 90,
        "combined_bytes" => 120
      }
    }

    source = run() |> put_in(["settings", "window_tokens"], 262_144) |> Map.put("memory", memory)
    result = Results.export!(source)
    assert result["resources"]["peak_combined_bytes"] == 120

    for private <- ~w(private-machine private.service private-gpu),
        do: refute(Jason.encode!(result) =~ private)

    assert Results.export!(put_in(source, ["memory", "status"], "partial"))["resources"][
             "coverage"
           ] == "partial"

    other = put_in(session, ["identity", "host"], "another-machine")

    assert_raise ArgumentError, ~r/different deployments/, fn ->
      Results.export!(put_in(source, ["memory", "sessions"], [session, other]))
    end

    other = put_in(session, ["gpus", Access.at(0), "uuid"], "another-gpu")

    assert_raise ArgumentError, ~r/physical GPUs/, fn ->
      Results.export!(put_in(source, ["memory", "sessions"], [session, other]))
    end
  end

  test "incomplete, partial, mismatched and duplicated runs cannot be published" do
    variants = [
      Map.put(run(), "status", "error"),
      put_in(run(), ["attempts", "case-b", "status"], "error"),
      update_in(run(), ["attempts"], &Map.delete(&1, "case-b")),
      put_in(run(), ["attempts", "case-b", "grade"], %{}),
      Map.put(run(), "selection", %{"kind" => "case_repeat"}),
      Map.put(run(), "cases", ["case-a"]),
      run()
      |> Map.put("cases", ~w(case-a case-a))
      |> put_in(["protocol", "inventory", "cases"], ~w(case-a case-a))
    ]

    for source <- variants, do: assert_raise(ArgumentError, fn -> Results.export!(source) end)
  end

  test "sharded artifacts and publisher overrides keep provenance; aliases do not imply quantization" do
    source =
      Map.put(run(), "model", %{
        "model" => "flash-next",
        "backend" => "strata",
        "profile" => %{
          "model_path" =>
            "/models/Qwen3.8-Flash-Next-GSQ-RCO-abliterated-IQ3_S-00001-of-00002.gguf"
        }
      })

    model = Results.export!(source)["model"]

    assert model["name"] == "Qwen3.8-Flash-Next-GSQ-RCO-abliterated" and
             model["quantization"] == "IQ3_S"

    assert model["size_bytes"] == nil

    assert Results.export!(source, size_bytes: 83_863_586_496, size_source: "artifact_files")[
             "model"
           ]["size_source"] == "artifact_files"

    assert_raise ArgumentError, fn -> Results.export!(source, size_bytes: 0) end

    source =
      Map.put(run(), "model", %{"model" => "Name-that-mentions-Q8", "backend" => "llama_cpp"})

    assert Results.export!(source)["model"]["quantization"] == nil

    assert Results.export!(source, quantization: "Q6_K")["model"]["quantization_source"] ==
             "owner_supplied"
  end

  test "current-case projection excludes retired cases and rejects changed fixtures" do
    source = current()
    inventory = source["protocol"]["inventory"]
    ids = source["cases"] ++ ~w(retired-a retired-b)

    source =
      source
      |> Map.put("cases", ids)
      |> put_in(["protocol", "inventory"], %{"id" => "older", "cases" => ids})

    source =
      Enum.reduce(~w(retired-a retired-b), source, fn id, acc ->
        acc
        |> put_in(["attempts", id], %{"status" => "completed", "grade" => %{"passed" => false}})
        |> put_in(["protocol", "fixtures", id], %{"case.json" => String.duplicate("a", 64)})
      end)

    result = Results.export!(source, inventory: inventory)
    assert length(result["cases"]) == 9 and Enum.all?(result["cases"], & &1["passed"])
    refute Jason.encode!(result) =~ "retired-"
    assert length(source["cases"]) == 11

    bad =
      put_in(
        source,
        ["protocol", "fixtures", hd(inventory["cases"]), "ticket.md"],
        String.duplicate("b", 64)
      )

    assert_raise ArgumentError, ~r/fixtures differ/, fn ->
      Results.export!(bad, inventory: inventory)
    end
  end

  test "private records, unexpected settings and unsafe links are rejected" do
    assert_raise ArgumentError, fn -> Results.validate!(run()) end

    for key <- ["resources", "evidence_url"] do
      assert_raise ArgumentError, fn ->
        Results.export!(run()) |> Map.put(key, false) |> Results.validate!()
      end
    end

    assert_raise ArgumentError, fn -> Results.export!(run(), resources: false) end

    assert_raise ArgumentError, fn ->
      put_in(run(), ["attempts", "case-a", "measurement"], false) |> Results.export!()
    end

    assert_raise ArgumentError, fn ->
      Results.export!(run()) |> Map.put("account_id", "secret") |> Results.validate!()
    end

    assert_raise ArgumentError, fn ->
      Results.export!(put_in(run(), ["settings", "api_key"], "secret"))
    end

    for url <- ["javascript:alert(1)", "https://user:password@example.com/results"],
        do: assert_raise(ArgumentError, fn -> Results.export!(run(), evidence_url: url) end)
  end

  test "build validates duplicates and fixtures, escapes script data, and supports an empty page",
       %{dir: dir} do
    record = Results.export!(current(), model_label: "<img src=x onerror=alert(1)>")
    Results.write!(Path.join(dir, "first.json"), record)
    Results.write!(Path.join(dir, "second.json"), record)
    assert_raise ArgumentError, ~r/Duplicate/, fn -> Results.load!(dir) end
    File.rm!(Path.join(dir, "second.json"))
    output = Path.join(dir, "dist")
    Results.build!(Results.load!(dir), output)
    [built] = Results.read!(Path.join(output, "results.json"))["results"]
    assert built["passed"] == 9 and built["total"] == 9
    refute File.read!(Path.join(output, "results.js")) =~ "<img"

    assert Enum.sort(File.ls!(output)) ==
             Enum.sort(~w(index.html app.js styles.css results.js results.json .nojekyll))

    assert File.read!(Path.join(output, "index.html")) =~ ~r/styles\.css\?v=[a-f0-9]{12}/

    altered =
      put_in(
        record,
        ["case_fixtures", hd(record["cases"])["id"], "ticket.md"],
        String.duplicate("b", 64)
      )

    assert_raise ArgumentError, ~r/does not match/, fn -> Results.build!([altered], output) end
    Results.build!([], output)
    assert Results.read!(Path.join(output, "results.json"))["results"] == []
  end

  test "publication builds the page, keeps overrides on repeat clicks and leaves private data out",
       %{dir: dir} do
    source = current()
    page = page(dir)
    opts = [page_root: page, inventory: source["protocol"]["inventory"]]
    assert Results.publish!(source, opts) == :added
    dest = Path.join([page, "results", source["id"] <> ".json"])
    record = Results.read!(dest)
    assert record["run_id"] == source["id"]
    Results.write!(dest, Map.put(record, "note", "Reviewed note"))
    assert Results.publish!(source, opts) == :already_added
    [built] = Results.read!(Path.join(page, "dist/results.json"))["results"]
    assert built["note"] == "Reviewed note"
    assert built["passed"] == 9 and built["total"] == 9
    refute Jason.encode!(built) =~ "private-host"
    refute Jason.encode!(built) =~ "private-account"
    refute Jason.encode!(built) =~ "private-trace"
    assert File.stat!(dest).uid == File.stat!(page).uid
    assert Path.wildcard(Path.join(page, ".publish-*")) == []
  end

  test "concurrent publication retains every result and duplicate requests are harmless", %{
    dir: dir
  } do
    page = page(dir)
    source = current()
    runs = [source, source, Map.put(source, "id", "second-run")]

    tasks =
      Enum.map(runs, fn run -> Task.async(fn -> Results.publish!(run, page_root: page) end) end)

    assert Enum.sort(Enum.map(tasks, &Task.await/1)) == [:added, :added, :already_added]
    records = Results.read!(Path.join(page, "dist/results.json"))["results"]
    assert Enum.sort(Enum.map(records, & &1["run_id"])) == ["second-run", "test-run"]
    assert length(Path.wildcard(Path.join(page, "results/*.json"))) == 2
  end

  test "invalid runs and failed builds never leave a new public record", %{dir: dir} do
    page = page(dir)
    source = current()

    assert_raise ArgumentError, fn ->
      Results.publish!(Map.put(source, "status", "running"), page_root: page)
    end

    File.rm!(Path.join(page, "app.js"))
    assert_raise File.Error, fn -> Results.publish!(source, page_root: page) end
    refute File.exists?(Path.join(page, "results/test-run.json"))
    assert Path.wildcard(Path.join(page, ".publish-*")) == []
  end

  test "preview serves only public generated files", %{dir: dir} do
    output = Path.join(dir, "dist")
    Results.build!([], output)
    File.write!(Path.join(output, "private.json"), "secret")
    opts = Eab.Results.Preview.init(output)
    assert Eab.Results.Preview.call(Plug.Test.conn(:get, "/"), opts).status == 200
    assert Eab.Results.Preview.call(Plug.Test.conn(:get, "/styles.css?v=123"), opts).status == 200
    assert Eab.Results.Preview.call(Plug.Test.conn(:get, "/private.json"), opts).status == 404
  end

  defp page(dir) do
    page = Path.join(dir, "page")
    File.mkdir_p!(page)

    for file <- ~w(index.html styles.css app.js),
        do: File.cp!(Path.join(Results.root(), file), Path.join(page, file))

    page
  end
end
