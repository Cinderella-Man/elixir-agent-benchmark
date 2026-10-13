defmodule Eab.Store do
  def root, do: Application.fetch_env!(:eab, :data_dir) |> Path.expand()
  def path(relative), do: Path.join(root(), relative)

  def read(relative, default \\ nil) do
    case File.read(path(relative)) do
      {:ok, body} -> Jason.decode!(body)
      {:error, :enoent} -> default
      {:error, why} -> raise File.Error, reason: why, action: "read", path: relative
    end
  end

  def write(relative, data, secret \\ "") do
    write_text(relative, Jason.encode!(scrub(data, secret), pretty: true) <> "\n")
  end

  def write_text(relative, body, secret \\ "") do
    dest = path(relative)
    File.mkdir_p!(Path.dirname(dest))
    File.chmod!(Path.dirname(dest), 0o700)
    temp = dest <> ".#{System.unique_integer([:positive])}.tmp"
    File.write!(temp, redact(body, secret))
    File.chmod!(temp, 0o600)
    File.rename!(temp, dest)
    :ok
  end

  def redact(text, ""), do: text
  def redact(text, secret), do: String.replace(text, secret, "[REDACTED]")
  def scrub(data, ""), do: data
  def scrub(data, key) when is_binary(data), do: redact(data, key)
  def scrub(data, key) when is_list(data), do: Enum.map(data, &scrub(&1, key))

  def scrub(data, key) when is_tuple(data),
    do: data |> Tuple.to_list() |> Enum.map(&scrub(&1, key)) |> List.to_tuple()

  def scrub(data, key) when is_map(data),
    do: Map.new(data, fn {k, v} -> {scrub(k, key), scrub(v, key)} end)

  def scrub(data, _), do: data

  def event(id, event) do
    file = path("runs/#{id}/events.jsonl")

    File.write!(
      file,
      Jason.encode!(Map.put(event, "at", DateTime.utc_now() |> DateTime.to_iso8601())) <> "\n",
      [:append]
    )

    File.chmod!(file, 0o600)
  end

  def runs do
    Path.wildcard(path("runs/*/run.json"))
    |> Enum.map(&Eab.Inventory.read_json/1)
    |> Enum.sort_by(& &1["created_at"], :desc)
  end

  def artifact(id, relative) do
    if valid_id?(id) and is_binary(relative) and not String.starts_with?(relative, "/") and
         Enum.all?(Path.split(relative), &(&1 not in ["..", "."])) do
      file = path("runs/#{id}/#{relative}")

      parts = ["runs", id] ++ Path.split(relative)

      safe =
        Enum.reduce_while(parts, root(), fn part, parent ->
          next = Path.join(parent, part)

          case File.lstat(next) do
            {:ok, %{type: type}} when type in [:directory, :regular] -> {:cont, next}
            _ -> {:halt, :error}
          end
        end)

      if safe == file and File.regular?(file), do: {:ok, file}, else: :error
    else
      :error
    end
  end

  def artifacts(id) do
    if valid_id?(id) do
      base = path("runs/#{id}")

      Path.wildcard(base <> "/**/*")
      |> Enum.filter(&File.regular?/1)
      |> Enum.map(&Path.relative_to(&1, base))
    else
      []
    end
  end

  def tail_artifact(id, relative, limit \\ 131_072) do
    with {:ok, path} <- artifact(id, relative),
         {:ok, file} <- :file.open(String.to_charlist(path), [:read, :binary, :raw]) do
      try do
        {:ok, size} = :file.position(file, :eof)
        offset = max(size - limit, 0)

        body =
          case :file.pread(file, offset, limit) do
            {:ok, body} -> body
            :eof -> ""
          end

        # A byte tail can start or end in the middle of an encoded character.
        body = for <<c::utf8 <- body>>, into: "", do: <<c::utf8>>

        {:ok,
         if(offset > 0, do: "[Earlier output omitted; download the full log]\n", else: "") <> body}
      after
        :file.close(file)
      end
    else
      _ -> :error
    end
  end

  def valid_id?(id), do: is_binary(id) and Regex.match?(~r/^[a-z0-9-]+$/, id)
end
