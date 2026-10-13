defmodule Eab.MixProject do
  use Mix.Project

  def project do
    [
      app: :eab,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: ["lib"],
      aliases: [assets: &assets/1]
    ]
  end

  def application do
    [mod: {Eab.Application, []}, extra_applications: [:logger, :crypto, :runtime_tools]]
  end

  defp deps do
    [
      {:phoenix, "~> 1.8.15"},
      {:phoenix_live_view, "~> 1.2.12"},
      {:phoenix_html, "~> 4.2"},
      {:bandit, "~> 1.8"},
      {:jason, "~> 1.4"},
      {:req, "~> 0.5"},
      {:lazy_html, ">= 0.0.0", only: :test}
    ]
  end

  defp assets(_) do
    File.mkdir_p!("priv/static/assets")
    deps = Mix.Project.deps_path()
    File.cp!(Path.join(deps, "phoenix/priv/static/phoenix.mjs"), "priv/static/assets/phoenix.mjs")

    File.cp!(
      Path.join(deps, "phoenix_live_view/priv/static/phoenix_live_view.esm.js"),
      "priv/static/assets/phoenix_live_view.esm.js"
    )
  end
end
