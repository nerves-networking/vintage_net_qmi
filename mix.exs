defmodule VintageNetQmi.MixProject do
  use Mix.Project

  def project do
    [
      app: :vintage_net_qmi,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:vintage_net, "~> 0.9.2"},
      {:qmi, "~> 0.1.0", organization: "smartrent"},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.23", only: :docs, runtime: false},
      {:excoveralls, "~> 0.14", only: :test, runtime: false}
    ]
  end
end
