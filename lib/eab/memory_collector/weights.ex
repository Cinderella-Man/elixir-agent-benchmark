defmodule Eab.MemoryCollector.Weights do
  @moduledoc false

  # Only count the exact GGUF file or its complete, numbered shard set.
  # Optional metadata must not prevent memory collection when files are unavailable.
  def read(path) when is_binary(path) do
    files = paths(path)

    if files != [] do
      observations =
        Enum.reduce_while(files, [], fn file, acc ->
          case File.stat(file) do
            {:ok, %{type: :regular, size: size}} when size > 0 ->
              {:cont, [%{"name" => Path.basename(file), "size_bytes" => size} | acc]}

            _ ->
              {:halt, nil}
          end
        end)

      if observations do
        %{
          "size_bytes" => Enum.sum(Enum.map(observations, & &1["size_bytes"])),
          "files" => Enum.reverse(observations)
        }
      end
    end
  end

  def read(_), do: nil

  defp paths(path) do
    case Regex.run(~r/\A(.*)-(\d{5})-of-(\d{5})\.gguf\z/, path) do
      [_, prefix, index, count] ->
        count_number = String.to_integer(count)

        # Bound work for malformed metadata; real model shard sets are much smaller.
        if count_number in 1..1024 and String.to_integer(index) in 1..count_number do
          for i <- 1..count_number,
              do: "#{prefix}-#{String.pad_leading(to_string(i), 5, "0")}-of-#{count}.gguf"
        else
          []
        end

      nil ->
        if Path.extname(path) == ".gguf", do: [path], else: []
    end
  end
end
