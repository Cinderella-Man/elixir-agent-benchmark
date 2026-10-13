defmodule Eab.DatabaseSeed do
  @moduledoc "Conservative migration/dependency identities for pristine database reuse."
  alias Eab.{Cache, Inventory}

  @repos %{"postgres" => "priv/repo/migrations", "clickhouse" => "priv/ingest_repo/migrations"}

  def describe(source, spec) do
    files = Path.wildcard(Path.join(source, "{lib,extra,src}/**/*.{ex,exs,erl,hrl}"))

    modules =
      Enum.reduce(files, %{}, fn file, index ->
        Regex.scan(~r/\bdefmodule\s+([A-Z][A-Za-z0-9_.]*)\b/, File.read!(file))
        |> Enum.reduce(index, fn [_, name], acc -> Map.put(acc, name, file) end)
      end)

    shared =
      (["mix.exs", "mix.lock"] |> Enum.map(&Path.join(source, &1))) ++
        Path.wildcard(Path.join(source, "config/**/*")) ++
        Path.wildcard(Path.join(source, "priv/**/*")) ++
        Path.wildcard(Path.join(source, "src/**/*"))

    shared =
      shared
      |> Enum.filter(&File.regular?/1)
      |> Enum.reject(fn file ->
        Enum.any?(Map.values(@repos), &String.starts_with?(file, Path.join(source, &1) <> "/"))
      end)

    migrations =
      Map.new(@repos, fn {service, directory} ->
        entries =
          Path.wildcard(Path.join([source, directory, "*.exs"]))
          |> Enum.sort()
          |> Enum.map(fn file ->
            [_, version] = Regex.run(~r/^(\d+)_/, Path.basename(file))
            dependencies = closure([file], modules, MapSet.new())
            # Dynamic module loading cannot be proven independent of the rest
            # of the application. Hash all source in that case, never guess.
            dependencies =
              if opaque?(dependencies), do: Enum.uniq(dependencies ++ files), else: dependencies

            %{
              "version" => String.to_integer(version),
              "file" => Path.relative_to(file, source),
              "content" => Inventory.hash_file(file),
              "dependencies" => fingerprint(dependencies -- [file], source),
              "cross_service" =>
                service == "postgres" and
                  Enum.any?(dependencies, &String.contains?(File.read!(&1), "IngestRepo"))
            }
          end)
          |> Enum.sort_by(& &1["version"])

        versions = Enum.map(entries, & &1["version"])

        unless length(Enum.uniq(versions)) == length(versions),
          do: raise("Duplicate migration versions")

        {service, entries}
      end)

    %{
      "version" => 1,
      "repository" => spec["repository"]["url"],
      "environment" => spec["runtime"]["environment"] || %{},
      "shared" => fingerprint(shared, source),
      "migrations" => migrations
    }
  end

  def compatible?(seed, target) when is_map(seed) and is_map(target) do
    is_map(seed["migrations"]) and is_map(target["migrations"]) and
      Map.drop(seed, ["migrations"]) == Map.drop(target, ["migrations"]) and
      Enum.all?(@repos, fn {service, _} ->
        before = get_in(seed, ["migrations", service]) || []
        after_ = get_in(target, ["migrations", service]) || []
        prefix? = Enum.take(after_, length(before)) == before
        suffix = Enum.drop(after_, length(before))
        prefix? and not Enum.any?(suffix, & &1["cross_service"])
      end)
  end

  def compatible?(_, _), do: false

  def migration_count(description) do
    description["migrations"] |> Map.values() |> Enum.map(&length/1) |> Enum.sum()
  end

  defp fingerprint(files, root) do
    files
    |> Enum.uniq()
    |> Enum.sort()
    |> Map.new(&{Path.relative_to(&1, root), Inventory.hash_file(&1)})
    |> Cache.key()
  end

  defp closure([], _modules, visited), do: MapSet.to_list(visited)

  defp closure([file | rest], modules, visited) do
    if MapSet.member?(visited, file) do
      closure(rest, modules, visited)
    else
      text = File.read!(file)
      names = aliases(text)

      # Resolve aliases conservatively across scopes, including shortened and
      # renamed namespace prefixes. Extra dependencies only reduce reuse.
      children =
        Enum.flat_map(modules, fn {name, path} ->
          if Enum.any?(names, fn alias_name ->
               name == alias_name or String.ends_with?(name, "." <> alias_name) or
                 String.ends_with?(alias_name, "." <> name) or
                 String.starts_with?(name, alias_name <> ".")
             end),
             do: [path],
             else: []
        end)

      closure(rest ++ children, modules, MapSet.put(visited, file))
    end
  end

  defp aliases(text) do
    case Code.string_to_quoted(text) do
      {:ok, ast} ->
        {_, names} =
          Macro.prewalk(ast, [], fn
            {{:., _, [{:__aliases__, _, prefix}, :{}]}, _, children} = node, names ->
              joined =
                for {:__aliases__, _, suffix} <- children, do: Enum.join(prefix ++ suffix, ".")

              {node, joined ++ names}

            {:__aliases__, _, parts} = node, names ->
              if Enum.all?(parts, &is_atom/1),
                do: {node, [Enum.join(parts, ".") | names]},
                else: {node, names}

            node, names ->
              {node, names}
          end)

        names

      _ ->
        []
    end
  end

  defp opaque?(files) do
    Enum.any?(files, fn file ->
      text = File.read!(file)

      match?({:error, _}, Code.string_to_quoted(text)) or
        Regex.match?(
          ~r/\b(apply\s*\(|Module\.concat|Code\.(eval|require|compile)|File\.|System\.|__MODULE__|unquote|quote\b)/,
          text
        ) or dynamic_call?(text)
    end)
  end

  defp dynamic_call?(text) do
    case Code.string_to_quoted(text) do
      {:ok, ast} ->
        {_, dynamic?} =
          Macro.prewalk(ast, false, fn
            {:use, _, [{:__aliases__, _, [:Ecto, :Migration]}]} = node, found -> {node, found}
            {:use, _, _} = node, _ -> {node, true}
            {{:., _, [{:__aliases__, _, _}, _]}, _, _} = node, found -> {node, found}
            {{:., _, _}, _, _} = node, _ -> {node, true}
            node, found -> {node, found}
          end)

        dynamic?

      _ ->
        true
    end
  end
end
