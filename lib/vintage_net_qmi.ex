defmodule VintageNetQMI do
  @moduledoc """
  %{type: VintageNetQMI, vintage_net_qmi: %{service_provider: ""}, ipv4: %{method: :dhcp}}
  """

  @behaviour VintageNet.Technology

  alias VintageNet.Interface.RawConfig
  alias VintageNet.IP.{DhcpdConfig, IPv4Config}

  @doc """
  Name of the the QMI server that VintageNetQMI uses
  """
  @spec qmi_name() :: QMI.nme()
  def qmi_name(), do: QMI

  @impl VintageNet.Technology
  def normalize(config) do
    config
    |> IPv4Config.normalize()
    |> DhcpdConfig.normalize()
  end

  @impl VintageNet.Technology
  def to_raw_config(
        ifname,
        %{type: __MODULE__, vintage_net_qmi: qmi} = config,
        opts
      ) do
    normalized_config = normalize(config)

    up_cmds = [
      {:fun, QMI, :configure_linux, [ifname]}
    ]

    child_specs = [
      {QMI, [ifname: "wwan0", name: qmi_name()]},
      {VintageNetQMI.Connection, [service_provider: qmi.service_provider]},
      {VintageNetQMI.CellMonitor, [ifname: ifname]},
      {VintageNetQMI.SignalMonitor, [ifname: ifname]}
    ]

    config =
      %RawConfig{
        ifname: ifname,
        type: __MODULE__,
        source_config: config,
        required_ifnames: [ifname],
        up_cmds: up_cmds,
        child_specs: child_specs
      }
      |> IPv4Config.add_config(normalized_config, opts)
      |> DhcpdConfig.add_config(normalized_config, opts)

    config
  end

  @impl VintageNet.Technology
  def check_system(_), do: {:error, "unimplemented"}

  @impl VintageNet.Technology
  def ioctl(_ifname, _command, _args), do: {:error, :unsupported}
end
