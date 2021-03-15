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

    _ = :timer.send_interval(30_000, :poll)

    {:ok, %{ifname: ifname, device: device, control_point: nas}, {:continue, :get_stats}}
  end

  @impl GenServer
  def handle_continue(:get_stats, state) do
    %{ifname: ifname, device: device, control_point: control_point} = state

    resp = NetworkAccess.get_sys_info(device, {0x03, control_point.client_id})

    require Logger

    Logger.warn("#{inspect(resp)}")

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
    {:noreply, state}
  end
end
