# SPDX-FileCopyrightText: 2024 Connor Rigby
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNetQMI.MCCMNC do
  @moduledoc """
  MCC/MNC database lookups

  This database uses data from https://s3.amazonaws.com/mcc-mnc.net/mcc-mnc.csv.
  MCC-MNC.net is licensed under the MIT Open Source license.
  """

  @doc """
  Look up the specified MCC/MNC and return the service provider's brand name

  ## Examples

      iex> VintageNetQMI.MCCMNC.lookup_brand("310", "410")
      "AT&T"
  """
  @spec lookup_brand(String.t(), String.t()) :: String.t() | nil
  def lookup_brand(mcc, mnc) do
    key = "#{mcc}#{mnc};"

    first_match =
      database_file()
      |> File.stream!()
      |> Stream.drop_while(fn line -> not String.starts_with?(line, key) end)
      |> Stream.take(1)
      |> Enum.to_list()

    with [line] <- first_match,
         [_, brand] <- String.split(line, ";") do
      String.trim(brand)
    else
      _ -> nil
    end
  end

  defp database_file(), do: Application.app_dir(:vintage_net_qmi, ["priv", "mcc-mnc.csv"])
end
