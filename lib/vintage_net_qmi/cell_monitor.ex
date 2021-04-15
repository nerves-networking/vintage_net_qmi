defmodule VintageNetQMI.CellMonitor do
  use GenServer

  @type arg() :: {:ifname, binary()}

  alias VintageNet.PropertyTable
  alias QMI.NetworkAccess

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl GenServer
  def init(args) do
    ifname = Keyword.fetch!(args, :ifname)

    VintageNet.subscribe(["interface", ifname, "connection"])

    _ = :timer.send_interval(25_000, :poll)

    {:ok, %{ifname: ifname}}
  end

  @impl GenServer
  def handle_info(
        {VintageNet, ["interface", ifname, "connection"], _old, :internet, _meta},
        %{ifname: ifname} = state
      ) do
    {:noreply, state}
  end

  def handle_info(:poll, state) do
    case NetworkAccess.get_home_network(VintageNetQMI.qmi_name()) do
      {:ok, %{mcc: mcc, mnc: mnc}} ->
        PropertyTable.put(VintageNet, ["interface", state.ifname, "mobile", "mcc"], mcc)
        PropertyTable.put(VintageNet, ["interface", state.ifname, "mobile", "mnc"], mnc)

      {:ok, _} ->
        {:noreply, state}
    end

    {:noreply, state}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end
end
