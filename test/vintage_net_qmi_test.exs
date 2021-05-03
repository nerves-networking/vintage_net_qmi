defmodule VintageNetQMITest do
  use ExUnit.Case
  alias VintageNet.Interface.RawConfig

  test "create a wired ethernet configuration" do
    input = %{
      type: VintageNetQMI,
      vintage_net_qmi: %{service_provider: "super", device: "/dev/cdc-wdm0"},
      ipv4: %{method: :dhcp},
      hostname: "unit_test"
    }

    output = %RawConfig{
      ifname: "wwan0",
      type: VintageNetQMI,
      source_config: input,
      required_ifnames: ["wwan0"],
      child_specs: [
        {QMI, [ifname: "wwan0", name: :"Elixir.VintageNetQMI.QMI.wwan0"]},
        {VintageNetQMI.Connection, [{:ifname, "wwan0"}, {:service_provider, "super"}]},
        {VintageNetQMI.CellMonitor, [ifname: "wwan0"]},
        {VintageNetQMI.SignalMonitor, [ifname: "wwan0"]},
        Utils.udhcpc_child_spec("wwan0", "unit_test"),
        {VintageNet.Interface.InternetConnectivityChecker, "wwan0"}
      ],
      down_cmds: [
        {:run_ignore_errors, "ip", ["addr", "flush", "dev", "wwan0", "label", "wwan0"]},
        {:run, "ip", ["link", "set", "wwan0", "down"]}
      ],
      up_cmds: [
        {:fun, QMI, :configure_linux, ["wwan0"]},
        {:run, "ip", ["link", "set", "wwan0", "up"]}
      ]
    }

    assert output == VintageNetQMI.to_raw_config("wwan0", input, Utils.default_opts())
  end
end
