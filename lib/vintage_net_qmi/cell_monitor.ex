defmodule VintageNetQMI.CellMonitor do
  use GenServer

  @type arg() :: {:device, String.t()} | {:ifname, String.t()}

  alias VintageNet.PropertyTable
  alias QMI.Service.NetworkAccess

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl GenServer
  def init(args) do
    ifname = Keyword.fetch!(args, :ifname)
    device = Keyword.fetch!(args, :device)

    VintageNet.subscribe(["interface", ifname, "connection"])

    {:ok, nas} = QMI.get_control_point(device, NetworkAccess)

    _ = :timer.send_interval(25_000, :poll)

    {:ok, %{ifname: ifname, device: device, control_point: nas}, {:continue, :get_stats}}
  end

  @impl GenServer
  def handle_continue(:get_stats, state) do
    # PropertyTable.put(VintageNet, ["interface", ifname, "mobile", "mcc"], mcc)
    # PropertyTable.put(VintageNet, ["interface", ifname, "mobile", "mnc"], mnc)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(
        {VintageNet, ["interface", ifname, "connection"], _old, :internet, _meta},
        %{ifname: ifname} = state
      ) do
    {:noreply, state}
  end

  def handle_info(:poll, state) do
    %{control_point: control_point, ifname: ifname} = state

    # probably don't want home network
    {binary, decoder} = QMI.Service.NetworkAccess.get_home_network()

    {:ok, message} = QMI.send_binary(control_point, binary)

    %{mcc: mcc, mnc: mnc} = decoder.(message)

    PropertyTable.put(VintageNet, ["interface", ifname, "mobile", "mcc"], mcc)
    PropertyTable.put(VintageNet, ["interface", ifname, "mobile", "mnc"], mnc)

    {:noreply, state}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end
end
