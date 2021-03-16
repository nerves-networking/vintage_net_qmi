defmodule VintageNetQMI do
  @moduledoc """
  %{type: VintageNetQMI, vintage_net_qmi: %{service_provider: ""}, ipv4: %{method: :dhcp}}
  """

  @behaviour VintageNet.Technology

  alias VintageNet.Interface.RawConfig
  alias VintageNet.IP.{DhcpdConfig, IPv4Config}

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
      # This might not be true for all modems as some support 802.3 IP framing,
      # however, on the EC25 supports raw IP framing. This feature can be detected
      # and is probably a better solution that just forcing the raw IP framing.
      {:fun, fn -> File.write!("/sys/class/net/#{ifname}/qmi/raw_ip", "Y") end}
    ]

    child_specs = [
      {VintageNetQMI.Connection,
       [ifname: ifname, device: qmi.device, service_provider: qmi.service_provider]},
      {VintageNetQMI.CellMonitor, [ifname: ifname, device: qmi.device]},
      {VintageNetQMI.SignalMonitor, [ifname: ifname, device: qmi.device]}
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
