# SPDX-FileCopyrightText: 2021 Frank Hunleth
# SPDX-FileCopyrightText: 2021 Jon Carstens
# SPDX-FileCopyrightText: 2021 Matt Ludwigs
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNetQMITest do
  use ExUnit.Case
  alias VintageNet.Interface.RawConfig

  test "create a simple qmi configuration" do
    input = %{
      type: VintageNetQMI,
      vintage_net_qmi: %{service_providers: [%{apn: "super"}]},
      hostname: "unit_test"
    }

    expected = %RawConfig{
      ifname: "wwan0",
      type: VintageNetQMI,
      source_config: input,
      required_ifnames: ["wwan0"],
      child_specs: [
        {VintageNetQMI.Indications, [ifname: "wwan0"]},
        {QMI.Supervisor,
         [
           ifname: "wwan0",
           name: :"Elixir.VintageNetQMI.QMI.wwan0",
           indication_callback: VintageNetQMI.indication_callback("wwan0")
         ]},
        {VintageNetQMI.Connectivity, [ifname: "wwan0"]},
        {VintageNetQMI.Connection,
         [{:ifname, "wwan0"}, service_providers: [%{apn: "super"}], radio_technologies: nil]},
        {VintageNetQMI.CellMonitor, [ifname: "wwan0"]},
        {VintageNetQMI.SignalMonitor, [ifname: "wwan0"]},
        {VintageNetQMI.ModemInfo, [ifname: "wwan0"]},
        Utils.udhcpc_child_spec("wwan0", "unit_test")
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

    created = VintageNetQMI.to_raw_config("wwan0", input, Utils.default_opts())

    assert created == expected
  end
end
