defmodule Eab.ModelIdentity do
  @moduledoc "Human-readable artifact identity, separate from the API routing alias."
  @quant ~r/(?:^|[-.])((?:UD-)?(?:IQ|Q|TQ|MXFP|NVFP|BF|FP|F)\d[A-Z0-9_]*)(?:$)/i

  def details(%{"identity" => %{"version" => 1} = identity}), do: identity

  def details(endpoint) when is_map(endpoint) do
    profile = endpoint["profile"] || %{}
    props = get_in(endpoint, ["metadata", "props"]) || %{}
    row = get_in(endpoint, ["metadata", "model"]) || %{}
    meta = row["meta"] || %{}
    path = present(profile["model_path"]) || present(props["model_path"])
    artifact = if path, do: Path.basename(path)

    stem =
      if artifact do
        artifact
        |> String.replace(~r/\.gguf$/i, "")
        |> String.replace(~r/-\d{5}-of-\d{5}$/, "")
      end

    file_quant = if stem, do: Regex.run(@quant, stem, capture: :all_but_first)

    quant =
      case file_quant do
        [value] -> String.upcase(value)
        _ -> normalize_quant(meta["ftype"] || row["ftype"] || profile["model_ftype"])
      end

    name =
      cond do
        stem && stem not in ["model", "weights"] -> String.replace(stem, @quant, "")
        present(meta["name"]) -> meta["name"]
        present(props["model_name"]) -> props["model_name"]
        true -> endpoint["model"] || "Unknown model"
      end

    %{
      "version" => 1,
      "name" => name,
      "quantization" => quant,
      "artifact" => artifact,
      "source" => if(artifact, do: "reported_artifact", else: "reported_name"),
      "size_bytes" => positive(meta["size"] || row["size"] || props["model_size_bytes"]),
      "parameter_count" => positive(meta["n_params"] || row["n_params"])
    }
  end

  def details(_), do: details(%{})

  def attach(endpoint), do: Map.put(endpoint || %{}, "identity", details(endpoint))

  def label(endpoint) do
    identity = details(endpoint)

    if identity["quantization"],
      do: identity["name"] <> " · " <> identity["quantization"],
      else: identity["name"]
  end

  def size_label(endpoint) do
    case details(endpoint)["size_bytes"] do
      bytes when is_number(bytes) -> "#{Float.round(bytes / 1_000_000_000, 1)} GB"
      _ -> "Not reported"
    end
  end

  defp normalize_quant(value) when is_binary(value) do
    value
    |> String.upcase()
    |> String.replace(~r/\s*-\s*MEDIUM$/, "_M")
    |> String.replace(~r/\s*-\s*SMALL$/, "_S")
    |> String.replace(~r/\s*-\s*LARGE$/, "_L")
    |> present()
  end

  defp normalize_quant(_), do: nil
  defp present(value) when is_binary(value), do: if(String.trim(value) != "", do: value)
  defp present(_), do: nil
  defp positive(value) when is_integer(value) and value > 0, do: value
  defp positive(_), do: nil
end
