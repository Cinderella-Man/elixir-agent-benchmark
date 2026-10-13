defmodule Eab.Fixtures do
  alias Eab.{Command, Inventory, Pi, Store}

  def ensure(id, emit) do
    spec = Inventory.spec(id)
    inputs = inputs(id, spec)
    runtime = Store.read("runtimes/#{id}.json")

    if runtime && runtime["inputs"] == inputs && image_exists?(runtime["image"]) &&
         Enum.all?(Map.values(runtime["services"]), &image_exists?/1) do
      runtime = Map.put(runtime, "fixture_hashes", Inventory.fixture_hashes(id))
      Store.write("runtimes/#{id}.json", runtime)
      runtime
    else
      emit.("Building #{id}")
      prepare(id, spec, inputs)
    end
  end

  defp inputs(id, spec) do
    %{
      "repository" => spec["repository"],
      "runtime" => spec["runtime"],
      "services" => spec["services"] || %{},
      "recipe_version" => 3,
      "pi" => Pi.identity(),
      "pi_node_image" => Pi.node_image(spec),
      "pi_bridge" => Inventory.hash_file(Inventory.path("priv/pi/bridge.mjs")),
      "patches" =>
        Map.new(["environment.patch"], fn file ->
          path = Inventory.case_path(id, file)
          {file, if(File.exists?(path), do: Inventory.hash_file(path), else: nil)}
        end)
    }
  end

  defp prepare(id, spec, inputs) do
    dest = Store.path("build/#{id}")
    File.rm_rf!(dest)
    source = Path.join(dest, "source")
    File.mkdir_p!(source)
    File.mkdir_p!(Path.join(dest, "pi"))

    for file <- ["package.json", "package-lock.json", "bridge.mjs"],
        do: File.cp!(Inventory.path("priv/pi/#{file}"), Path.join(dest, "pi/#{file}"))

    repo = spec["repository"]

    unless Regex.match?(~r/^[a-f0-9]{40}$/, repo["revision"]) and
             String.starts_with?(repo["url"], "https://github.com/"),
           do: raise("Unpinned repository")

    Command.run!("git", ["init", "--quiet", source])

    Command.run!("git", ["fetch", "--quiet", "--depth=1", repo["url"], repo["revision"]],
      cd: source
    )

    Command.run!("git", ["checkout", "--quiet", "--detach", "FETCH_HEAD"], cd: source)
    File.rm_rf!(Path.join(source, ".git"))

    for file <- ["environment.patch"],
        File.exists?(Inventory.case_path(id, file)),
        File.stat!(Inventory.case_path(id, file)).size > 0 do
      Command.run!("git", ["apply", Inventory.case_path(id, file)], cd: source)
    end

    base = pin(spec["runtime"]["image"])
    node = if spec["runtime"]["node_image"], do: pin(spec["runtime"]["node_image"])
    recipe = dockerfile(spec, base, node)
    File.write!(Path.join(dest, "Dockerfile"), recipe)
    tag = "elixir-agent-benchmark:#{id}"

    result =
      Command.run("docker", ["build", "-t", tag, dest],
        timeout: 3600,
        limit: 2_000_000
      )

    Store.write_text("build/#{id}/build.log", result["output"])
    if result["returncode"] != 0, do: raise("Fixture build failed for #{id}: #{result["output"]}")

    image =
      Command.run!("docker", ["image", "inspect", tag, "--format", "{{.Id}}"], timeout: 30)
      |> String.trim()

    services =
      Map.new(spec["services"] || %{}, fn {name, config} -> {name, pin(config["image"])} end)

    runtime = %{
      "image" => image,
      "inputs" => inputs,
      "base_image" => base,
      "node_image" => node,
      "pi" => Pi.identity(),
      "pi_node_image" => Pi.node_image(spec),
      "services" => services,
      "fixture_hashes" => Inventory.fixture_hashes(id),
      "dockerfile" => recipe
    }

    Store.write("runtimes/#{id}.json", runtime)
    runtime
  end

  def image_exists?(image),
    do: Command.run("docker", ["image", "inspect", image], timeout: 30)["returncode"] == 0

  defp pin(image) do
    Command.run!("docker", ["pull", "--quiet", image], timeout: 1200)
    [info] = Command.run!("docker", ["image", "inspect", image]) |> Jason.decode!()
    List.first(info["RepoDigests"] || []) || raise "Image has no immutable digest"
  end

  def dockerfile(spec, base, node \\ nil) do
    runtime = spec["runtime"]

    env =
      Map.merge(
        %{
          "MIX_ENV" => "test",
          "MIX_HOME" => "/opt/mix",
          "HEX_HOME" => "/opt/hex",
          "ERL_FLAGS" => "+S 2:2"
        },
        runtime["environment"] || %{}
      )

    lines =
      [
        "FROM #{Pi.node_image(spec)} AS pi",
        "WORKDIR /opt/pi",
        "COPY pi/package.json pi/package-lock.json ./",
        "RUN npm ci --ignore-scripts --no-audit --no-fund",
        "COPY pi/bridge.mjs ./"
      ] ++
        if(node, do: ["FROM #{node} AS nodejs"], else: []) ++
        [
          "FROM #{base}",
          "USER root",
          "RUN if command -v apk; then apk add --no-cache git bash ca-certificates build-base brotli libstdc++ cmake grep ripgrep coreutils findutils diffutils; else apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends git bash ca-certificates build-essential brotli cmake grep ripgrep coreutils findutils diffutils && rm -rf /var/lib/apt/lists/*; fi",
          "RUN if command -v useradd; then existing=$(getent passwd 1000 | cut -d: -f1); groupadd -f agent; if [ -n \"$existing\" ]; then usermod -l agent -d /home/agent -m -g agent \"$existing\"; else useradd -m -u 1000 -g agent agent; fi; else adduser -D -u 1000 agent; fi",
          "COPY --from=pi /opt/pi /opt/pi",
          "COPY --from=pi /usr/local/bin/node /opt/pi/node",
          "RUN /opt/pi/node /opt/pi/node_modules/@earendil-works/pi-coding-agent/dist/bundle/cli.js --version"
        ]

    lines =
      lines ++
        if(node,
          do: [
            "COPY --from=nodejs /usr/local/bin/node /usr/local/bin/node",
            "COPY --from=nodejs /usr/local/lib/node_modules /usr/local/lib/node_modules",
            "RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx"
          ],
          else: []
        )

    lines =
      lines ++
        [
          "WORKDIR /workspace",
          "RUN mkdir -p /opt/mix /opt/hex && chown agent:agent /workspace /opt/mix /opt/hex",
          "USER agent"
        ] ++
        Enum.map(Enum.sort(env), fn {k, v} -> "ENV #{k}=#{Jason.encode!(v)}" end) ++
        ["RUN mix local.hex --force && mix local.rebar --force"]

    lines =
      lines ++
        if runtime["profile"] == "plausible_ce" do
          [
            "COPY --chown=agent:agent source/mix.exs source/mix.lock ./",
            "COPY --chown=agent:agent source/config/ config/",
            "RUN mix deps.get --only ce_test && mix deps.compile",
            "COPY --chown=agent:agent source/tracker/package.json source/tracker/package-lock.json tracker/",
            "RUN npm ci --prefix tracker --no-audit --no-fund"
          ]
        else
          []
        end

    Enum.join(
      lines ++
        ["COPY --chown=agent:agent source/ /workspace/"] ++
        Enum.map(
          runtime["setup_commands"] || ["mix deps.get", "mix deps.compile"],
          &("RUN " <> &1)
        ) ++
        [
          "RUN rm -rf .git && git init && git config user.name Benchmark && git config user.email benchmark@localhost && git add . && git commit -m 'Initial task workspace'",
          "CMD [\"sleep\", \"infinity\"]"
        ],
      "\n"
    ) <> "\n"
  end
end
