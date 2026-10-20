defmodule Eab.Results.Schema do
  @moduledoc false
  @fields ~w(schema_version run_id created_at model benchmark source_release_id settings cases case_fixtures resources evidence_url note)
  @model_fields ~w(name backend quantization quantization_source size_bytes size_source parameter_count)
  @nullable_int ~w(window_tokens response_tokens seed)
  @integer ~w(safety_tokens max_tokens)
  @text ~w(budget_policy context_policy reasoning_effort reasoning_effort_source thinking_policy)

  def validate!(r) do
    fields!(r, @fields, "Expected a public v4 result; export the original run.json with add")
    require!(r["schema_version"] === 4, "Unsupported result schema")
    require!(Regex.match?(~r/^[A-Za-z0-9_-]+$/, text!(r["run_id"], "run_id")), "Invalid run ID")
    date!(r["created_at"])
    text!(r["benchmark"], "benchmark")

    require!(
      is_binary(r["source_release_id"]) and
        Regex.match?(~r/^[a-f0-9]{64}$/, r["source_release_id"]),
      "A frozen source release ID is required"
    )

    model = r["model"]
    fields!(model, @model_fields, "Unexpected model fields")
    for key <- ~w(name backend), do: text!(model[key], key)

    require!(
      model["quantization_source"] in ~w(reported owner_supplied not_reported),
      "Invalid quantization source"
    )

    if model["quantization_source"] == "not_reported",
      do: require!(is_nil(model["quantization"]), "Unreported quantization must be null"),
      else: text!(model["quantization"], "quantization")

    for key <- ~w(size_bytes parameter_count),
        do:
          require!(
            is_nil(model[key]) or positive?(model[key]),
            "#{key} must be a positive integer or null"
          )

    require!(
      model["size_source"] in ~w(reported artifact_files owner_supplied not_reported),
      "Invalid size source"
    )

    require!(
      is_nil(model["size_bytes"]) == (model["size_source"] == "not_reported"),
      "Size and its source must agree"
    )

    settings = r["settings"]
    require!(is_map(settings) and map_size(settings) > 0, "Effective settings are required")

    Enum.each(settings, fn {key, value} ->
      valid =
        cond do
          key in @nullable_int -> is_nil(value) or is_integer(value)
          key in @integer -> is_integer(value)
          key in @text -> is_binary(value)
          key == "compaction" -> is_boolean(value)
          true -> false
        end

      require!(valid, "Invalid or unknown setting: #{key}")
    end)

    if Map.has_key?(settings, "thinking_policy") do
      require!(settings["thinking_policy"] == "server_preset", "Invalid thinking policy")
      text!(settings["reasoning_effort"], "reasoning_effort")

      require!(
        settings["reasoning_effort_source"] in ~w(server_reported operator_declared not_reported),
        "Invalid thinking source"
      )

      if settings["reasoning_effort_source"] == "not_reported",
        do:
          require!(
            settings["reasoning_effort"] == "unknown",
            "Unreported thinking must be unknown"
          )
    end

    cases = r["cases"]
    require!(is_list(cases) and cases != [], "At least one case is required")

    for c <- cases do
      fields!(c, ~w(id passed generated_tokens model_calls measurement), "Unexpected case fields")
      text!(c["id"], "case.id")
      require!(is_boolean(c["passed"]), "Every case needs a final pass/fail outcome")

      for key <- ~w(generated_tokens model_calls),
          do:
            require!(
              is_nil(c[key]) or nonnegative?(c[key]),
              "#{key} must be a nonnegative integer or null"
            )

      if not is_nil(c["measurement"]) do
        m = c["measurement"]
        fields!(m, ~w(attempt_ms), "Unexpected measurement fields")
        require!(nonnegative?(m["attempt_ms"]), "Invalid measured duration")
      end
    end

    ids = Enum.map(cases, & &1["id"])
    require!(Enum.uniq(ids) == ids, "Duplicate case IDs")
    fields!(r["case_fixtures"], ids, "Case fixture identities are required")

    for files <- Map.values(r["case_fixtures"]) do
      require!(is_map(files) and map_size(files) > 0, "Missing fixture hashes")

      Enum.each(files, fn {name, digest} ->
        require!(
          is_binary(name) and Path.basename(name) == name and is_binary(digest) and
            Regex.match?(~r/^[a-f0-9]{64}$/, digest),
          "Invalid fixture identity"
        )
      end)
    end

    require!(is_binary(r["note"]), "note must be text")

    if not is_nil(r["resources"]),
      do: Eab.Results.Resources.validate!(r["resources"], model, settings)

    if not is_nil(r["evidence_url"]) do
      url = r["evidence_url"]
      uri = URI.parse(text!(url, "evidence_url"))

      require!(
        uri.scheme in ~w(https http) and is_binary(uri.host) and uri.host != "" and
          is_nil(uri.userinfo),
        "Evidence must be a public HTTP(S) link without embedded credentials"
      )
    end

    r
  end

  def fields!(value, names, message),
    do: require!(is_map(value) and Enum.sort(Map.keys(value)) == Enum.sort(names), message)

  def positive?(value), do: is_integer(value) and value > 0
  def nonnegative?(value), do: is_integer(value) and value >= 0

  def text!(value, name) do
    require!(is_binary(value) and String.trim(value) != "", "#{name} must be nonempty text")
    value
  end

  def date!(value) do
    require!(
      is_binary(value) and match?({:ok, _, _}, DateTime.from_iso8601(value)),
      "Timestamp must include its timezone"
    )
  end

  def require!(condition, message) do
    unless condition, do: raise(ArgumentError, message)
    :ok
  end
end
