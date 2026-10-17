defmodule Eab.MeasurementTest do
  use ExUnit.Case, async: false
  alias Eab.Measurement

  setup do
    on_exit(fn ->
      Application.delete_env(:eab, :performance_environment)
      Application.delete_env(:eab, :measurement_clock)
    end)
  end

  test "ordinary functional runs neither read a clock nor record performance" do
    Application.delete_env(:eab, :performance_environment)
    Application.put_env(:eab, :measurement_clock, fn -> flunk("Must not measure this run") end)
    assert Measurement.start() == nil
    assert Measurement.request(nil, fn -> :response end) == {:response, nil}
    assert Measurement.finish(nil) == nil
  end

  test "qualified measurements distinguish whole attempts from model requests using a synthetic clock" do
    Application.put_env(:eab, :performance_environment, "synthetic-test-environment")
    Process.put(:clock_values, [100, 200, 500, 700, 1100, 1600])

    Application.put_env(:eab, :measurement_clock, fn ->
      [now | rest] = Process.get(:clock_values)
      Process.put(:clock_values, rest)
      now
    end)

    measurement = Measurement.start()
    {:first, measurement} = Measurement.request(measurement, fn -> :first end)
    {:second, measurement} = Measurement.request(measurement, fn -> :second end)
    result = Measurement.finish(measurement)

    assert result == %{
             "environment" => "synthetic-test-environment",
             "attempt_ms" => 1500,
             "inference_ms" => 700
           }

    assert Eab.Evidence.compact(%{"status" => "completed", "measurement" => result})[
             "measurement"
           ] == result
  end
end
