defmodule Eab.Inventory do
  def root, do: Application.fetch_env!(:eab, :root)
  def path(relative), do: Path.join(root(), relative)
  def read_json(path), do: path |> File.read!() |> Jason.decode!()
  def all, do: read_json(path("config/benchmark.json"))["cases"]

  def spec(id) do
    unless id in all(), do: raise(ArgumentError, "Unknown benchmark case")
    read_json(case_path(id, "case.json"))
  end

  def case_path(id, file), do: path("cases/#{id}/#{file}")
  def file(id, file), do: File.read!(case_path(id, file))
  def hash_file(path), do: path |> File.read!() |> hash()
  def hash(data), do: :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)

  def fixture_hashes(id) do
    Path.wildcard(case_path(id, "*"))
    |> Enum.filter(&File.regular?/1)
    |> Map.new(&{Path.basename(&1), hash_file(&1)})
  end

  def implementation_hash do
    files =
      Path.wildcard(path("lib/**/*.ex")) ++
        Enum.filter(Path.wildcard(path("priv/pi/*")), &File.regular?/1) ++
        [path("mix.lock")] ++ Path.wildcard(path("priv/fixtures/*.exs"))

    files
    |> Enum.sort()
    |> Enum.map_join(fn p -> Path.relative_to(p, root()) <> hash_file(p) end)
    |> hash()
  end

  def qualification_hash do
    # Agent, endpoint and presentation changes cannot change fixture controls.
    # Runtime image identities independently invalidate controls after rebuilds.
    files = ~w(command grader inventory sandbox)

    (Enum.map(files, &path("lib/eab/#{&1}.ex")) ++
       [
         path("mix.lock"),
         path("priv/fixtures/grade_formatter.exs")
       ])
    |> Enum.sort()
    |> Enum.map_join(fn p -> Path.relative_to(p, root()) <> hash_file(p) end)
    |> hash()
  end

  def qualification_inputs(id) do
    spec = spec(id)

    %{
      # Unknown future manifest fields invalidate controls by default. Only
      # known descriptive fields and inputs already covered by the images are
      # excluded; a new grading rule must never silently reuse old controls.
      "contract" =>
        Map.drop(spec, ~w(id title family suite project domains repository runtime services
          clarifications source_inspiration)),
      "before_test_commands" => spec["runtime"]["before_test_commands"] || [],
      "files" => Map.drop(fixture_hashes(id), ["case.json", "ticket.md", "provenance.json"])
    }
  end

  def protocol do
    %{
      "inventory" => read_json(path("config/benchmark.json")),
      "agent" => Eab.Pi.identity(),
      "implementation" => implementation_hash(),
      "fixtures" => Map.new(all(), &{&1, fixture_hashes(&1)})
    }
  end
end
