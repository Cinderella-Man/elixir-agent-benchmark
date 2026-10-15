# Capture the real initial Pi request locally; never forward it to a provider.
# The original Agent module is compiled under another name with only Pi.run
# redirected. Its prompt construction executes unchanged. The capture throws
# before submission/checkpointing, so this cannot be counted as a model attempt.
alias Eab.{AgentImage, Grader, Inventory, OpenAI, Pi, Release, Sandbox, Store}

{:ok, _} = Registry.start_link(keys: :duplicate, name: Eab.Commands)
{:ok, _} = Task.Supervisor.start_link(name: Eab.Tasks)
{:ok, _} = Application.ensure_all_started(:req)

defmodule FrozenInputCapture do
  alias Eab.{Command, Inventory, OpenAI, Pi, Sandbox, Store}

  def run(box, endpoint, _key, settings, prefix, prompt, instructions, _emit) do
    config = Pi.config(endpoint, settings, prompt, instructions)
    Store.write("#{prefix}/pi-config.json", config)
    Sandbox.copy_file(box, Store.path("#{prefix}/pi-config.json"), "/opt/eab-attempt/pi.json")

    handler = fn
      %{"type" => "request"} = frame, %{requests: []} = state ->
        unless frame["method"] == "POST" and frame["path"] == "/v1/responses",
          do: raise("Unexpected Pi route")

        request = OpenAI.payload(frame["body"], endpoint, settings)

        reply = %{
          "id" => frame["id"],
          "status" => 400,
          "content_type" => "application/json",
          "body" =>
            Jason.encode!(%{
              "error" => %{
                "message" => "Offline input capture complete",
                "type" => "invalid_request_error"
              }
            })
        }

        {reply, %{state | requests: [request]}}

      %{"type" => "request"}, _state ->
        raise("Capture unexpectedly retried")

      %{"type" => "event", "event" => %{"type" => "tool_execution_start"}}, _ ->
        raise("Capture must not execute solver tools")

      _frame, state ->
        {nil, state}
    end

    result =
      Command.exchange(
        "docker",
        [
          "exec",
          "-i",
          "-w",
          "/workspace",
          box.name,
          "/opt/pi/node",
          "/opt/pi/bridge.mjs",
          "/opt/eab-attempt/pi.json"
        ],
        %{requests: []},
        handler,
        timeout: 120
      )

    [request] = result["state"].requests
    unless Sandbox.patch(box) == "", do: raise("Input capture changed the workspace")

    facts =
      Sandbox.command!(box, """
      /opt/pi/node --input-type=module -e '
        import {execFileSync} from "node:child_process";
        import {readFileSync,existsSync} from "node:fs";
        import {createHash} from "node:crypto";
        const envKeys = ["LANG","LANGUAGE","LC_ALL","LC_CTYPE","TZ","TMPDIR","MIX_ENV","ERL_FLAGS","NODE_OPTIONS","HOME","USER"];
        const locks = ["mix.lock","package-lock.json","tracker/package-lock.json","assets/package-lock.json"];
        console.log(JSON.stringify({
          environment: Object.fromEntries(envKeys.map(k => [k,process.env[k] ?? null])),
          os_release: readFileSync("/etc/os-release","utf8"),
          timezone: execFileSync("date",["+%Z %z"],{encoding:"utf8"}).trim(),
          locale: Intl.DateTimeFormat().resolvedOptions().locale,
          node: process.version,
          pi_cli: execFileSync("/opt/pi/node",["/opt/pi/node_modules/@earendil-works/pi-coding-agent/dist/bundle/cli.js","--version"],{encoding:"utf8"}).trim(),
          elixir_otp: execFileSync("elixir",["--version"],{encoding:"utf8"}),
          dependency_locks: Object.fromEntries(locks.filter(existsSync).map(p => [p,createHash("sha256").update(readFileSync(p)).digest("hex")]))
        }));'
      """)
      |> Jason.decode!()

    throw(
      {:frozen_input,
       %{
         "prompt" => prompt,
         "instructions" => instructions,
         "pi_config" => config,
         "initial_request" => request,
         "environment" => facts,
         "agent_image" => box.runtime["image"],
         "provider_requests_sent" => 0,
         "agent_source_sha256" => Inventory.hash_file(Inventory.path("lib/eab/agent.ex"))
       }}
    )
  end
end

source = Inventory.path("lib/eab/agent.ex") |> File.read!() |> Code.string_to_quoted!()

{source, counts} =
  Macro.prewalk(source, %{module: 0, run: 0}, fn
    {:defmodule, meta, [{:__aliases__, am, [:Eab, :Agent]}, body]}, counts ->
      {{:defmodule, meta, [{:__aliases__, am, [:FreezeAgent]}, body]},
       %{counts | module: counts.module + 1}}

    {{:., dm, [{:__aliases__, am, [:Pi]}, :run]}, meta, args}, counts ->
      {{{:., dm, [{:__aliases__, am, [:FrozenInputCapture]}, :run]}, meta, args},
       %{counts | run: counts.run + 1}}

    node, counts ->
      {node, counts}
  end)

unless counts == %{module: 1, run: 1}, do: raise("Agent capture seam changed; inspect it")
Code.compile_quoted(source)

plan = Inventory.read_json(Path.join(__DIR__, "validation-plan.json"))
settings = OpenAI.settings(plan["settings"])

unless settings == plan["settings"],
  do: raise("Plan settings differ from the production provider")

endpoint = %{"url" => plan["endpoint"], "backend" => plan["provider"], "model" => plan["model"]}
release = Release.freeze()
repeat = Store.read("repeatability/result.json")

unless repeat && repeat["status"] == "repeatable",
  do: raise("Complete repeatability first")

qualified_release = Release.read!(repeat["release"])

unless qualified_release["protocol"]["fixtures"] == release["protocol"]["fixtures"],
  do: raise("Cases changed since repeatability checks")

unless String.contains?(Store.root(), "case-freeze-2026-10-15"), do: raise("Wrong data directory")

if File.exists?(Store.path("frozen-inputs")),
  do: raise("Existing capture evidence must be preserved")

for id <- Inventory.all() do
  :ok = Release.verify!(release, id)
  runtime = Store.read("runtimes/#{id}.json")

  for round <- 1..3 do
    control = Store.read("repeatability/round-#{round}/controls/#{id}.json")

    unless control["valid"] and control["identity"] == Grader.qualification_identity(id, runtime),
      do: raise("Executable qualification changed since round #{round}: #{id}")
  end

  IO.puts("CAPTURING INPUT #{id}")

  record =
    try do
      Sandbox.with_box(
        id,
        "case-freeze-input-capture",
        fn box ->
          FreezeAgent.submit(id, "case-freeze-input-capture", box, endpoint, "", settings, fn _ ->
            :ok
          end)
        end,
        agent: true
      )

      raise("Capture unexpectedly submitted an attempt")
    catch
      {:frozen_input, record} -> record
    end

  record =
    Map.merge(record, %{
      "case" => id,
      "release" => release["id"],
      "pi" => Pi.identity(),
      "qualification_release" => qualified_release["id"],
      "agent_image_inputs" => AgentImage.inputs(Inventory.spec(id), runtime["image"]),
      "plan_sha256" => Inventory.hash_file(Path.join(__DIR__, "validation-plan.json")),
      "capture_runner_sha256" => Inventory.hash_file(__ENV__.file)
    })

  Store.write("frozen-inputs/#{id}.json", record)
end

:ok = Release.verify!(release)
IO.puts("CAPTURE COMPLETE: 11 initial requests, no provider requests or model attempts")
