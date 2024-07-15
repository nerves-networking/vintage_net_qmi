defmodule VintageNetQMI.MCCMNC do
  @moduledoc """
  Automatically generated file based on https://s3.amazonaws.com/mcc-mnc.net/mcc-mnc.csv
  """

  @doc """
  Get the provider name for a network id.

  ## Examples

        iex> VintageNetQMI.MCCMNC.provider("310", "410")
        "AT&T"

        iex> VintageNetQMI.MCCMNC.provider("000", "000")
        nil
  """
  @spec provider(String.t(), String.t()) :: String.t() | nil
  def provider(mcc, mnc) do
    database_file()
    |> File.read!()
    |> String.trim()
    |> String.split("\r\n")
    |> Enum.map(&String.split(&1, ";"))
    |> tl()
    |> Enum.map(fn [mcc, mnc, _, _, _, _, _, pro, _, _ | _] -> {mcc, mnc, pro} end)
    |> Enum.uniq_by(fn {mcc, mnc, _} -> {mcc, mnc} end)
    |> Enum.find_value(fn
      {^mcc, ^mnc, provider} -> provider
      _ -> false
    end)
  end

  defp database_file, do: Application.app_dir(:vintage_net_qmi, ["priv", "mcc-mnc.csv"])
end
