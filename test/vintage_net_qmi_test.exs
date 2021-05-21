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
           indication_callback: :anonymous_functions_dont_work_for_unit_tests
         ]},
        {VintageNetQMI.Connectivity, [ifname: "wwan0"]},
        {VintageNetQMI.Connection, [{:ifname, "wwan0"}, service_providers: [%{apn: "super"}]]},
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

    {expected_children, expected_no_children} = Map.pop(expected, :child_specs)
    {created_children, created_no_children} = Map.pop(created, :child_specs)

    assert expected_no_children == created_no_children
    assert Enum.all?(Enum.zip(expected_children, created_children), &expected_child?/1)
  end

  defp expected_child?({{QMI.Supervisor, e_opts}, {QMI.Supervisor, c_opts}}) do
    e_opts[:ifname] == c_opts[:ifname] and e_opts[:name] == c_opts[:name] and
      is_function(c_opts[:indication_callback])
  end

  defp expected_child?({same, same}), do: true
  defp expected_child?(_), do: false
end
