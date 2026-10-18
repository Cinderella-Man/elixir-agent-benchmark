defmodule Eab.Measurement do
  @moduledoc "Opt-in attempt measurements for an explicitly configured performance environment."

  # Disabled for ordinary functional runs. Never infer qualification from a hostname.
  def start do
    case Application.get_env(:eab, :performance_environment) do
      environment when is_binary(environment) and environment != "" ->
        clock = Application.get_env(:eab, :measurement_clock, &clock/0)
        %{environment: environment, clock: clock, started: clock.(), inference_ms: 0}

      _ ->
        nil
    end
  end

  def request(nil, fun), do: {fun.(), nil}

  def request(measurement, fun) do
    started = measurement.clock.()
    result = fun.()
    elapsed = measurement.clock.() - started
    {result, %{measurement | inference_ms: measurement.inference_ms + elapsed}}
  end

  def finish(nil), do: nil

  def finish(measurement) do
    %{
      "environment" => measurement.environment,
      "attempt_ms" => measurement.clock.() - measurement.started,
      "inference_ms" => measurement.inference_ms
    }
  end

  defp clock, do: System.monotonic_time(:millisecond)
end
