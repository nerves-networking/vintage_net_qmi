# SPDX-FileCopyrightText: 2021 Matt Ludwigs
# SPDX-FileCopyrightText: 2023 Mike McCall
# SPDX-FileCopyrightText: 2024 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNetQMI.ServiceProvider do
  @moduledoc false

  # Helper module for working with service provider configurations

  @typedoc """
  Configuration for a service provider

  * `:apn` - the APN for the service provider
  * `:only_iccid_prefixes` - a list of ICCID prefixes to validate the SIM's
    ICCID against. If this configuration is not provided, then the SIM's ICCID
    will not be checked.
  * `:roaming_allowed?` - set if the modem is allowed to use roaming. By default
    this will used the modem's provided roaming configuration.
  """
  @type t() :: %{
          required(:apn) => binary(),
          optional(:only_iccid_prefixes) => [binary()],
          optional(:roaming_allowed?) => boolean()
        }

  @doc """
  Select the provider by the iccid
  """
  @spec select_provider_by_iccid([t()], binary()) :: {:ok, t()} | {:error, :no_provider}
  def select_provider_by_iccid(providers, iccid) do
    Enum.reduce_while(providers, {:error, :no_provider}, fn
      %{only_iccid_prefixes: prefixes} = provider, best ->
        if is_binary(iccid) && String.starts_with?(iccid, prefixes) do
          {:halt, {:ok, provider}}
        else
          {:cont, best}
        end

      provider, _default ->
        {:cont, {:ok, provider}}
    end)
  end
end
