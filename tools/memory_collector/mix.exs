defmodule EabMemoryCollector.MixProject do
  use Mix.Project

  def project do
    [
      app: :eab_memory_collector,
      version: "0.1.0",
      elixir: "~> 1.19",
      elixirc_paths: [Path.expand("../../lib/eab/memory_collector", __DIR__)],
      deps: [],
      releases: [eab_memory_collector: [include_executables_for: [:unix]]]
    ]
  end

  def application, do: [extra_applications: [:inets, :ssl]]
end
