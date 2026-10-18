defmodule Eab.MemoryCollectorTest do
  use ExUnit.Case, async: true
  alias Eab.MemoryCollector, as: Collector

  setup do
    root =
      Path.join(System.tmp_dir!(), "eab-memory-counters-#{System.unique_integer([:positive])}")

    proc = Path.join(root, "proc")
    group = Path.join(root, "groups/model.service")
    File.mkdir_p!(group)

    for pid <- [10, 11] do
      File.mkdir_p!(Path.join(proc, to_string(pid)))

      File.write!(
        Path.join([proc, to_string(pid), "stat"]),
        "#{pid} (model process) " <> Enum.join(List.duplicate("0", 19) ++ ["1234"], " ")
      )

      File.write!(Path.join([proc, to_string(pid), "cgroup"]), "0::/model.service\n")
      File.write!(Path.join([proc, to_string(pid), "status"]), "VmRSS: 20 kB\nVmHWM: 80 kB\n")
    end

    File.write!(Path.join(proc, "cpuinfo"), "model name: Fixture CPU\n")
    File.write!(Path.join(proc, "meminfo"), "MemTotal: 1000 kB\nMemAvailable: 600 kB\n")
    File.write!(Path.join(group, "cgroup.procs"), "10\n11\n")
    File.write!(Path.join(group, "memory.current"), "50000\n")
    File.write!(Path.join(group, "memory.peak"), "90000000\n")
    File.write!(Path.join(group, "memory.stat"), "anon 30000\nfile 18000\nkernel 2000\n")

    command = fn
      "ss", _ ->
        "LISTEN 0 2048 127.0.0.1:8414 0.0.0.0:* users:((\"server\",pid=10,fd=11))"

      "nvidia-smi", ["--query-gpu=uuid,name,memory.total", _] ->
        "b, 3090, 24576\na, 3090, 24576\n"

      "nvidia-smi", ["--query-compute-apps=gpu_uuid,pid,used_gpu_memory", _] ->
        "b, 11, 100\na, 11, 200\na, 99, 500\n"
    end

    http = fn _, _, route ->
      case route do
        "/health" ->
          %{"service" => "strata", "loaded" => true}

        "/props" ->
          %{
            "model_path" => "/private/model-Q4_K_M.gguf",
            "build_info" => "Strata fixture",
            "default_generation_settings" => %{"n_ctx" => 262_144}
          }

        "/metrics" ->
          %{"engine" => %{"kv" => "int8"}}
      end
    end

    on_exit(fn -> File.rm_rf!(root) end)

    %{
      request: %{
        "port" => 8414,
        "artifact" => "model-Q4_K_M.gguf",
        "context_tokens" => 262_144,
        "backend" => "strata"
      },
      opts: [
        proc_root: proc,
        cgroup_root: Path.join(root, "groups"),
        command: command,
        http: http
      ],
      proc: proc,
      group: group
    }
  end

  test "service samples exclude unrelated GPU processes and lifetime peaks", ctx do
    state = Collector.open(ctx.request, ctx.opts)
    assert Collector.identity(state)["context_tokens"] == 262_144
    {sample, state} = Collector.sample(state)
    assert sample["vram_bytes"] == 300 * 1_048_576
    assert sample["service_ram_bytes"] == 50000
    assert sample["combined_bytes"] == 300 * 1_048_576 + 50000
    assert sample["process_rss_bytes"] == 40 * 1024
    assert sample["ram_file_bytes"] == 18000
    assert Enum.map(sample["gpus"], & &1["uuid"]) == ~w(a b)
    refute Map.has_key?(sample, "service_ram_lifetime_peak_bytes")
    File.write!(Path.join(ctx.group, "memory.current"), "60000")
    assert elem(Collector.sample(state), 0)["service_ram_bytes"] == 60000
  end

  test "identity, context and process restarts fail closed", ctx do
    for {key, value} <- [
          {"artifact", "other.gguf"},
          {"context_tokens", 65536},
          {"backend", "llama_cpp"}
        ] do
      assert_raise Collector.Error, fn ->
        Collector.open(Map.put(ctx.request, key, value), ctx.opts)
      end
    end

    {_, state} = Collector.open(ctx.request, ctx.opts) |> Collector.sample()

    File.write!(
      Path.join([ctx.proc, "11", "stat"]),
      "11 (replacement) " <> Enum.join(List.duplicate("0", 19) ++ ["9999"], " ")
    )

    assert_raise Collector.Error, ~r/process disappeared or changed/, fn ->
      Collector.sample(state)
    end
  end

  test "GPU allocations aggregate service processes by physical UUID and reject unavailable counters" do
    cards = [["b", "3090", "24576"], ["a", "3090", "24576"]]
    apps = [["b", "10", "100"], ["a", "10", "200"], ["a", "11", "30"], ["a", "99", "500"]]
    result = Collector.gpu_usage(MapSet.new([10, 11]), cards, apps)

    assert Enum.map(result, &{&1["uuid"], &1["used_bytes"]}) == [
             {"a", 230 * 1_048_576},
             {"b", 100 * 1_048_576}
           ]

    assert_raise Collector.Error, fn ->
      Collector.gpu_usage(MapSet.new([10]), cards, [["a", "10", "[N/A]"]])
    end
  end

  test "listener ignores Tailscale forwarder and rejects ambiguous listeners" do
    rows =
      "LISTEN 0 2048 127.0.0.1:8414 0.0.0.0:* users:((\"server\",pid=10,fd=11))\nLISTEN 0 4096 100.70.151.84:8414 0.0.0.0:* users:((\"tailscaled\",pid=1881,fd=27))"

    assert Collector.listener(rows, 8414) == 10

    assert_raise Collector.Error, fn ->
      Collector.listener(
        rows <> "\nLISTEN 0 2048 0.0.0.0:8414 0.0.0.0:* users:((\"server\",pid=11,fd=11))",
        8414
      )
    end
  end

  test "standalone snapshot stays distinct from run samples and omits private identifiers", ctx do
    snapshot = Collector.snapshot(Map.put(ctx.request, "pid", 11), ctx.opts)
    assert snapshot["kind"] == "loaded_snapshot"
    assert snapshot["ram_lifetime_peak_bytes"] == 80 * 1024
    assert snapshot["service_ram_lifetime_peak_bytes"] == 90_000_000
    assert snapshot["model_artifact"] == "model-Q4_K_M.gguf"
    refute JSON.encode!(snapshot) =~ "uuid"
    refute JSON.encode!(snapshot) =~ "/private/"
    assert length(snapshot["gpus"]) == 2
  end
end
