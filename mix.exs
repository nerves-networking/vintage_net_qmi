defmodule VintageNetQMI.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/smartrent/vintage_net_qmi"

  def project do
    [
      app: :vintage_net_qmi,
      version: @version,
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      preferred_cli_env: [
        docs: :docs,
        "hex.build": :docs,
        "hex.publish": :docs
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:vintage_net, "~> 0.10.0"},
      {:qmi, "~> 0.1.0", organization: "smartrent"},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.23", only: :docs, runtime: false},
      {:excoveralls, "~> 0.14", only: :test, runtime: false}
    ]
  end

  def docs do
    [
      assets: "assets",
      extras: ["README.md", "CHANGELOG.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  def package do
    [
      licenses: ["Proprietary"],
      links: %{"GitHub" => @source_url},
      files: [
        "lib",
        "src",
        "CHANGELOG.md",
        "mix.exs",
        "README.md"
      ],
      organization: "smartrent"
    ]
  end
end
