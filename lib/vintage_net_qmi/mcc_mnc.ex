defmodule VintageNetQMI.MCCMNC do
  @moduledoc """
  MCC/MNC database

  This database uses data from https://s3.amazonaws.com/mcc-mnc.net/mcc-mnc.csv.
  """

  @doc """
  Look up the specified MCC/MNC and return information for the first match
  """
  @spec lookup(String.t(), String.t()) :: {:ok, map()} | :error
  def lookup(mcc, mnc) do
    key = "#{mcc};#{mnc};"

    first_match =
      database_file()
      |> File.stream!()
      |> Stream.drop_while(fn line -> not String.starts_with?(line, key) end)
      |> Stream.take(1)
      |> Enum.to_list()

    case first_match do
      [line] -> {:ok, parse!(line)}
      [] -> :error
    end
  end

  defp parse!(line) do
    # MCC;MNC;PLMN;Region;Country;ISO;Operator;Brand;TADIG;Bands
    [mcc, mnc, plmn, region, country, iso, operator, brand, tadig, bands] =
      String.split(line, ";")

    %{
      mcc: mcc,
      mnc: mnc,
      plmn: plmn,
      region: region,
      country: country,
      iso: iso,
      operator: operator,
      brand: brand,
      tadig: tadig,
      bands: String.trim(bands)
    }
  end

  defp database_file, do: Application.app_dir(:vintage_net_qmi, ["priv", "mcc-mnc.csv"])
end
