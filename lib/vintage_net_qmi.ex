# SPDX-FileCopyrightText: 2021 Frank Hunleth
# SPDX-FileCopyrightText: 2021 Matt Ludwigs
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNetQMI do
  @moduledoc """
  Use a QMI-enabled cellular modem with VintageNet

  This module is not intended to be called directly but via calls to `VintageNet`. Here's an
  example:

  ```elixir
  VintageNet.configure(
    "wwan0",
    %{
      type: VintageNetQMI,
      vintage_net_qmi: %{
        service_providers: [
          %{apn: "favorite_apn", only_iccid_prefixes: ["1234"]},
          %{apn: "second_favorite_apn", only_iccid_prefixes: ["56789"]},
          %{apn: "last_resort_apn"}
        ],
        only_radio_technologies: [:lte]
      }
    }
  )
  ```

  The following keys are supported

  * `:service_providers` - This is a list of service provider information

  The `:service_providers` key should be set to information provided by each of
  your service providers.

  Information for each service provider is a map with some or all of the following
  fields:

  * `:apn` (required) - e.g., `"access_point_name"`
  * `:only_iccid_prefixes` (optional) - only use this APN if the one of the strings
    in the list is a prefix of the ICCID. E.g, `["1234"]`

  When multiple entries are specified, the first allowed service provider is used.

  Your service provider should provide you with the information that you need to
  connect. Often it is just an APN. The Gnome project provides a database of
  [service provider
  information](https://wiki.gnome.org/Projects/NetworkManager/MobileBroadband/ServiceProviders)
  that may also be useful.
  """

  @behaviour VintageNet.Technology

  alias VintageNet.Interface.RawConfig
  alias VintageNet.IP.IPv4Config
  alias VintageNetQMI.Cookbook

  @doc """
  Name of the the QMI server that VintageNetQMI uses
  """
  @spec qmi_name(VintageNet.ifname()) :: atom()
  def qmi_name(ifname), do: Module.concat(__MODULE__.QMI, ifname)

  @impl VintageNet.Technology
  def normalize(%{type: __MODULE__, vintage_net_qmi: _qmi} = config) do
    require_a_service_provider(config)
  end

  def normalize(_config) do
    raise ArgumentError,
          "specify vintage_net_qmi options (e.g., %{vintage_net_qmi: %{service_providers: [%{apn: \"super\"}]}})"
  end

  defp require_a_service_provider(
         %{type: __MODULE__, vintage_net_qmi: qmi} = config,
         required_fields \\ [:apn]
       ) do
    case Map.get(qmi, :service_providers, []) do
      [] ->
        service_provider =
          for field <- required_fields, into: %{} do
            {field, to_string(field)}
          end

        new_config = %{
          config
          | vintage_net_qmi: Map.put(qmi, :service_providers, [service_provider])
        }

        raise ArgumentError,
              """
              At least one service provider is required for #{__MODULE__}.

              For example:

              #{inspect(new_config)}
              """

      [service_provider | _rest] ->
        missing =
          Enum.find(required_fields, fn field -> not Map.has_key?(service_provider, field) end)

        if missing do
          raise ArgumentError,
                """
                The service provider '#{inspect(service_provider)}' is missing the `inspect(missing)' field.
                """
        end

        config
    end
  end

  @impl VintageNet.Technology
  def to_raw_config(
        ifname,
        %{type: __MODULE__} = config,
        _opts
      ) do
    normalized_config = normalize(config)
    radio_technologies_preference = normalized_config.vintage_net_qmi[:only_radio_technologies]

    up_cmds = [
      {:fun, QMI, :configure_linux, [ifname]}
    ]

    child_specs = [
      {VintageNetQMI.Indications, ifname: ifname},
      {QMI.Supervisor,
       [
         ifname: ifname,
         name: qmi_name(ifname),
         indication_callback: indication_callback(ifname)
       ]},
      {VintageNetQMI.Connectivity, ifname: ifname},
      {VintageNetQMI.Connection,
       [
         ifname: ifname,
         service_providers: normalized_config.vintage_net_qmi.service_providers,
         radio_technologies: radio_technologies_preference
       ]},
      {VintageNetQMI.CellMonitor, [ifname: ifname]},
      {VintageNetQMI.SignalMonitor, [ifname: ifname]},
      {VintageNetQMI.ModemInfo, ifname: ifname},
      {VintageNetQMI.MtuManager, ifname: ifname}
    ]

    # QMI uses DHCP to report IP addresses, gateway, DNS, etc.
    ipv4_config = %{ipv4: %{method: :dhcp}, hostname: Map.get(config, :hostname)}

    config =
      %RawConfig{
        ifname: ifname,
        type: __MODULE__,
        source_config: config,
        required_ifnames: [ifname],
        up_cmds: up_cmds,
        child_specs: child_specs
      }
      |> IPv4Config.add_config(ipv4_config, [])
      |> remove_connectivity_detector()

    config
  end

  defp remove_connectivity_detector(raw_config) do
    new_child_specs =
      Enum.reject(raw_config.child_specs, fn
        # Old internet connectivity checker module
        {VintageNet.Interface.InternetConnectivityChecker, _ifname} -> true
        # New internet connectivity checker module
        {VintageNet.Connectivity.InternetChecker, _ifname} -> true
        _ -> false
      end)

    %{raw_config | child_specs: new_child_specs}
  end

  @impl VintageNet.Technology
  def check_system(_), do: {:error, "unimplemented"}

  @impl VintageNet.Technology
  def ioctl(_ifname, _command, _args), do: {:error, :unsupported}

  @doc """
  Configure a cellular modem using an APN

  ```
  iex> VintageNetQMI.quick_configure("an_apn")
  :ok
  ```
  """
  @spec quick_configure(String.t()) :: :ok | {:error, term()}
  def quick_configure(apn) do
    with {:ok, config} <- Cookbook.simple(apn) do
      VintageNet.configure("wwan0", config)
    end
  end

  # For unit test purposes
  @doc false
  @spec indication_callback(VintageNet.ifname()) :: function()
  def indication_callback(ifname) do
    &VintageNetQMI.Indications.handle(ifname, &1)
  end
end
