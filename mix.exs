defmodule MixGrispIo.MixProject do
  use Mix.Project

  @source_url "https://github.com/grisp/mix_grisp_io"

  def project do
    [
      app: :mix_grisp_io,
      version: "1.0.0",
      description: "Mix plug-in for publishing GRiSP software updates to GRiSP.io",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      source_url: @source_url
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto, :hackney]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:mix_grisp, "~> 1.1"},
      {:hackney, "~> 4.7"},
      {:jsx, "~> 3.1"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* CHANGELOG*),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end
end
