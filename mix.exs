defmodule TDNS00.MixProject do
  use Mix.Project

  def project do
    [
      app: :tdns00,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {TDNS00.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      #      {:tenbin_dns, path: "../tenbin_dns"}
      {:tenbin_dns, git: "https://github.com/toshi0806/tenbin_dns.git", tag: "0.2.4"}
    ]
  end
end
