defmodule OriginalCaseAudit do
  @moduledoc false
  @directory Path.expand("../verification/task-quality/original", __DIR__)

  def all, do: Eab.Inventory.read_json(Path.join(@directory, "config/benchmark.json"))["cases"]

  def map(ids, fun) do
    checksums = Eab.Inventory.read_json(Path.join(@directory, "sha256.json"))

    for {path, expected} <- checksums do
      unless Eab.Inventory.hash_file(Path.join(@directory, path)) == expected,
        do: raise("Changed archived audit input: #{path}")
    end

    Enum.map(ids, fn id ->
      unless id in all(), do: raise("Unknown original audit case: #{id}")
      Eab.Inventory.with_case(id, Path.join([@directory, "cases", id]), fn -> fun.(id) end)
    end)
  end
end
