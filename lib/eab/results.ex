defmodule Eab.Results do
  @moduledoc "Exports completed runs through a strict public schema and builds the static results page."
  alias Eab.{ModelIdentity, Results.Schema}

  def root,
    do:
      Application.get_env(:eab, :results_page_root) ||
        Path.join(Application.get_env(:eab, :root, File.cwd!()), "results-page")

  def read!(path), do: path |> File.read!() |> Jason.decode!()
  def write!(path, value), do: File.write!(path, Jason.encode!(value, pretty: true) <> "\n")
  def validate!(record), do: Schema.validate!(record)

  def fixture_hashes(case_id, case_root \\ nil) do
    Schema.require!(
      is_binary(case_id) and Regex.match?(~r/^[A-Za-z0-9_-]+$/, case_id),
      "Invalid case ID"
    )

    dir = Path.join(case_root || Path.join(project_root(), "cases"), case_id)

    dir
    |> File.ls!()
    |> Enum.sort()
    |> Enum.filter(&File.regular?(Path.join(dir, &1)))
    |> Map.new(&{&1, hash(File.read!(Path.join(dir, &1)))})
  end

  def export!(run, opts \\ []) do
    require!(is_map(run), "Expected a run.json object")
    require!(run["status"] == "completed", "Only completed runs can be published")

    require!(
      is_nil(run["selection"]),
      "Selected-case repeats and error retries are not full-run results"
    )

    ids = run["cases"]
    inventory = get_in(run, ["protocol", "inventory"]) || %{}

    require!(
      is_list(ids) and ids != [] and ids == inventory["cases"],
      "Run cases must match the full frozen inventory, in order"
    )

    require!(Enum.uniq(ids) == ids, "Duplicate case IDs")

    for id <- ids do
      attempt = get_in(run, ["attempts", id]) || %{}

      require!(
        attempt["status"] == "completed" and is_boolean(get_in(attempt, ["grade", "passed"])),
        "#{id}: missing, interrupted or errored outcome cannot be scored"
      )
    end

    selected = opts[:inventory] || inventory
    selected_ids = selected["cases"]
    fixtures = get_in(run, ["protocol", "fixtures"]) || %{}

    require!(
      is_list(selected_ids) and Enum.all?(selected_ids, &(&1 in ids)),
      "The run has not evaluated every current case"
    )

    if opts[:inventory] do
      for id <- selected_ids do
        require!(
          fixtures[id] == fixture_hashes(id, opts[:case_root]),
          "#{id}: recorded fixtures differ from the current case"
        )
      end
    end

    model = run["model"] || %{}
    identity = ModelIdentity.details(model)
    quant = Keyword.get(opts, :quantization, identity["quantization"])
    size = Keyword.get(opts, :size_bytes, identity["size_bytes"])

    resources =
      case Keyword.fetch(opts, :resources) do
        {:ok, value} -> value
        :error -> Eab.Results.Resources.from_run!(run["memory"])
      end

    record = %{
      "schema_version" => 3,
      "run_id" => run["id"],
      "created_at" => run["created_at"],
      "model" => %{
        "name" => opts[:model_label] || identity["name"],
        "backend" => model["backend"],
        "quantization" => quant,
        "quantization_source" => source(opts, :quantization, quant),
        "size_bytes" => size,
        "size_source" =>
          if(Keyword.has_key?(opts, :size_bytes),
            do: opts[:size_source] || "owner_supplied",
            else: source([], :size_bytes, size)
          ),
        "parameter_count" => identity["parameter_count"]
      },
      "benchmark" => selected["id"],
      "source_release_id" => run["release_id"],
      "settings" => run["settings"],
      "cases" =>
        Enum.map(selected_ids, fn id ->
          attempt = run["attempts"][id]

          %{
            "id" => id,
            "passed" => attempt["grade"]["passed"],
            "generated_tokens" => attempt["generated_tokens"],
            "model_calls" => attempt["calls"],
            "measurement" => attempt["measurement"]
          }
        end),
      "case_fixtures" => Map.new(selected_ids, &{&1, fixtures[&1] || %{}}),
      "resources" => resources,
      "evidence_url" => opts[:evidence_url],
      "note" => opts[:note] || ""
    }

    validate!(record)
  end

  def load!(directory \\ Path.join(root(), "results")) do
    records =
      Path.wildcard(Path.join(directory, "*.json"))
      |> Enum.sort()
      |> Enum.map(fn path ->
        try do
          path |> read!() |> validate!()
        rescue
          error -> raise ArgumentError, "#{Path.basename(path)}: #{Exception.message(error)}"
        end
      end)

    ids = Enum.map(records, & &1["run_id"])
    require!(Enum.uniq(ids) == ids, "Duplicate run ID")
    records
  end

  def added?(id),
    do:
      is_binary(id) and Regex.match?(~r/^[A-Za-z0-9_-]+$/, id) and
        File.regular?(Path.join([root(), "results", id <> ".json"]))

  @doc "Adds a completed run and rebuilds the page; repeated requests keep the existing public record."
  def publish!(run, opts \\ []) do
    page = opts[:page_root] || root()

    # Serialize dashboard requests so two tabs cannot rebuild over each other's results.
    :global.trans({{__MODULE__, Path.expand(page)}, self()}, fn ->
      inventory = opts[:inventory] || read!(Path.join(project_root(), "config/benchmark.json"))
      opts = Keyword.merge(opts, page_root: page, inventory: inventory)
      record = export!(run, opts)
      records = load!(Path.join(page, "results"))
      existing = Enum.find(records, &(&1["run_id"] == record["run_id"]))
      records = if existing, do: records, else: records ++ [record]

      stage =
        Path.join(
          page,
          ".publish-#{Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)}"
        )

      destination = Path.join([page, "results", record["run_id"] <> ".json"])

      try do
        # Validate every record and generate every asset before adding the result.
        build!(records, stage, opts)
        mkdir_owned!(Path.join(page, "results"), page)
        mkdir_owned!(Path.join(page, "dist"), page)

        unless existing do
          File.write!(destination, Jason.encode!(record, pretty: true) <> "\n", [:exclusive])
          inherit_owner!(destination, page)
        end

        # Replace complete files, with HTML last so it references the new asset hashes.
        for name <- ~w(styles.css app.js results.js results.json .nojekyll index.html) do
          source = Path.join(stage, name)
          inherit_owner!(source, page)
          File.rename!(source, Path.join([page, "dist", name]))
        end

        if existing, do: :already_added, else: :added
      after
        File.rm_rf!(stage)
      end
    end)
  end

  def build!(records, destination \\ Path.join(root(), "dist"), opts \\ []) do
    page = opts[:page_root] || root()
    inventory = opts[:inventory] || read!(Path.join(project_root(), "config/benchmark.json"))
    expected = Map.new(inventory["cases"], &{&1, fixture_hashes(&1, opts[:case_root])})

    for record <- records do
      validate!(record)

      require!(
        record["benchmark"] == inventory["id"] and
          Enum.map(record["cases"], & &1["id"]) == inventory["cases"] and
          record["case_fixtures"] == expected,
        "#{record["run_id"]}: result does not match the current cases; re-export or archive it"
      )
    end

    ids = Enum.map(records, & &1["run_id"])
    require!(Enum.uniq(ids) == ids, "Duplicate run ID")

    payload = %{
      "schema_version" => 3,
      "benchmark" => %{"id" => inventory["id"], "case_count" => length(inventory["cases"])},
      "results" =>
        Enum.map(
          records,
          &Map.merge(&1, %{
            "passed" => Enum.count(&1["cases"], fn c -> c["passed"] end),
            "total" => length(&1["cases"])
          })
        )
    }

    repository =
      opts[:repository] ||
        System.get_env("GITHUB_REPOSITORY", "Cinderella-Man/elixir-agent-benchmark")

    require!(
      Regex.match?(~r/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/, repository),
      "Invalid repository name"
    )

    File.mkdir_p!(destination)

    html =
      File.read!(Path.join(page, "index.html"))
      |> String.replace("__REPOSITORY_URL__", "https://github.com/#{repository}")

    html =
      Enum.reduce(~w(styles.css app.js), html, fn name, html ->
        body = File.read!(Path.join(page, name))
        File.write!(Path.join(destination, name), body)
        version_asset(html, name, body)
      end)

    body = Jason.encode!(payload, pretty: true)
    File.write!(Path.join(destination, "index.html"), version_asset(html, "results.js", body))
    File.write!(Path.join(destination, "results.json"), body <> "\n")

    File.write!(
      Path.join(destination, "results.js"),
      "window.BENCHMARK_DATA = " <> String.replace(body, "<", "\\u003c") <> ";\n"
    )

    File.touch!(Path.join(destination, ".nojekyll"))
    destination
  end

  defp version_asset(html, name, body),
    do: String.replace(html, ~s("#{name}"), ~s("#{name}?v=#{String.slice(hash(body), 0, 12)}"))

  defp source(opts, key, value),
    do:
      if(Keyword.has_key?(opts, key),
        do: "owner_supplied",
        else: if(is_nil(value), do: "not_reported", else: "reported")
      )

  defp hash(body), do: :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)
  defp require!(condition, message), do: Schema.require!(condition, message)

  defp project_root, do: Application.get_env(:eab, :root, File.cwd!())

  defp mkdir_owned!(path, page) do
    unless File.dir?(path) do
      File.mkdir_p!(path)
      inherit_owner!(path, page)
    end
  end

  # The Docker release runs as root; keep bind-mounted outputs editable by the checkout owner.
  defp inherit_owner!(path, page) do
    %{uid: uid, gid: gid} = File.stat!(page)
    File.chown!(path, uid)
    File.chgrp!(path, gid)
  end
end
