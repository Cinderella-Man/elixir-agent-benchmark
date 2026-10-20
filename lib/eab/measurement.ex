defmodule Eab.Measurement do
  @moduledoc "Elapsed case time from Pi startup through completion, before independent grading."

  def start do
    clock = Application.get_env(:eab, :measurement_clock, &clock/0)
    %{clock: clock, started: clock.()}
  end

  def finish(measurement) do
    %{"attempt_ms" => measurement.clock.() - measurement.started}
  end

  defp clock, do: System.monotonic_time(:millisecond)

  def label(%{"attempt_ms" => ms}) when is_integer(ms),
    do: "#{Float.round(ms / 1000, 3)} s"

  def label(_), do: "Not measured"
end
