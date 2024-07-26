defmodule VintageNetQMI.MixProject do
  use Mix.Project

  @version "0.4.0"
  @source_url "https://github.com/nerves-networking/vintage_net_qmi"

  def project do
    [
      app: :vintage_net_qmi,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      aliases: [compile: ["compile", &build_mcc_mnc_csv/1]],
      deps: deps(),
      description: description(),
      dialyzer: dialyzer(),
      docs: docs(),
      package: package(),
      preferred_cli_env: [
        docs: :docs,
        "hex.build": :docs,
        "hex.publish": :docs
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:vintage_net, "~> 0.12.0 or ~> 0.13.0"},
      {:qmi, "~> 0.9.0"},
      {:credo, "~> 1.5", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4.1", only: :dev, runtime: false},
      {:ex_doc, "~> 0.23", only: :docs, runtime: false}
    ]
  end

  defp description do
    "VintageNet Support for QMI Cellular Modems"
  end

  defp dialyzer() do
    [
      flags: [:missing_return, :extra_return, :unmatched_returns, :error_handling, :underspecs]
    ]
  end

  def docs do
    [
      assets: %{"assets" => "assets"},
      extras: ["README.md", "CHANGELOG.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  def package do
    [
      files: [
        "lib",
        "CHANGELOG.md",
        "LICENSE",
        "mix.exs",
        "README.md",
        "mcc-mnc.csv"
      ],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  # Reduce the size of the original csv to contain only the used fields and
  # sort so the output looks less haphazard. No optimizations currently take
  # advantage of the sort.
  defp build_mcc_mnc_csv(_) do
    input_path = "mcc-mnc.csv"
    priv_dir = Path.join(Mix.Project.app_path(), "priv")
    out_path = Path.join(priv_dir, "mcc-mnc.csv")

    _ = File.mkdir_p(priv_dir)

    File.stream!(input_path)
    |> Stream.drop(1)
    |> Stream.map(&String.split(&1, ";"))
    |> Stream.map(fn [_mcc, _mnc, plmn, _, _, _, _, brand, _, _ | _] ->
      [String.to_integer(plmn), brand]
    end)
    |> Stream.reject(fn [_, brand] -> brand == "" end)
    |> Stream.uniq_by(fn [plmn | _] -> plmn end)
    |> Enum.sort()
    |> Enum.map(fn [plmn, brand] -> [Integer.to_string(plmn), ";", brand, "\n"] end)
    |> then(&File.write!(out_path, &1))
  end
end
