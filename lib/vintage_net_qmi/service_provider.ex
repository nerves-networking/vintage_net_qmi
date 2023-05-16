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
  @spec select_provider_by_iccid([t()], binary()) :: t() | nil
  def select_provider_by_iccid(providers, iccid) do
    Enum.reduce_while(providers, nil, fn
      %{only_iccid_prefixes: prefixes} = provider, default ->
        if is_binary(iccid) && String.starts_with?(iccid, prefixes) do
          {:halt, provider}
        else
          {:cont, default}
        end

      provider, _default ->
        {:cont, provider}
    end)
  end
end
