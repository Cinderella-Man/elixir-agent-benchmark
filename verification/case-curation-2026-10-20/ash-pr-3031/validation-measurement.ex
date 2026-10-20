defmodule Eab.Measurement do
  @moduledoc "Observer disabled for functional validation on the shared machine."

  def start, do: :disabled
  def finish(:disabled), do: %{"disabled" => "functional_validation_machine_policy"}
  def label(_), do: "Not measured"
end
