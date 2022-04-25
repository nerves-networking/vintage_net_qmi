defmodule VintageNetQMI.ServiceProvider do
  @moduledoc false

  # Helper module for working with service provider configurations

  @typedoc """
  Configuration for a service provider

  * `:apn` - the APN for the service provider
  * `:only_iccid_prefixes` - a list of ICCID prefixes to validate the SIM's
    ICCID against. If this configuration is not provided, then the SIM's ICCID
    will not be checked.
  * :disable_roaming - boolean flag to disable roaming for a provider, defaults
    to `false` to allow roaming
  """
  @type t() :: %{
          required(:apn) => binary(),
          optional(:only_iccid_prefixes) => [binary()],
          optional(:disable_roaming) => boolean()
        }

  @doc """
  Select the APN from a list of service providers based off the ICCID
  """
  @spec select_apn_by_iccid([t()], binary()) :: binary() | nil
  def select_apn_by_iccid(providers, iccid) do
    Enum.reduce_while(providers, nil, fn
      %{only_iccid_prefixes: prefixes} = provider, default ->
        if String.starts_with?(iccid, prefixes) do
          {:halt, provider.apn}
        else
          {:cont, default}
        end

      provider, _default ->
        {:cont, provider.apn}
    end)
  end

  @doc """
  Select the provider by the iccid
  """
  @spec select_provider_by_iccid([t()], binary()) :: t() | nil
  def select_provider_by_iccid(providers, iccid) do
    Enum.reduce_while(providers, nil, fn
      %{only_iccid_prefixes: prefixes} = provider, default ->
        if String.starts_with?(iccid, prefixes) do
          {:halt, provider}
        else
          {:cont, default}
        end

      provider, _default ->
        {:cont, provider}
    end)
  end
end
