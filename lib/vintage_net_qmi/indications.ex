defmodule VintageNetQMI.Indications do
  @moduledoc false

  # Server that handles incoming indications

  use GenServer

  require Logger

  def start_link(args) do
    ifname = Keyword.fetch!(args, :ifname)

    GenServer.start_link(__MODULE__, args, name: name(ifname))
  end

  defp name(ifname) do
    Module.concat(__MODULE__, ifname)
  end

  @doc """
  Handle an incoming indication for a interface
  """
  @spec handle(VintageNet.ifname(), map()) :: :ok
  def handle(ifname, indication) do
    GenServer.cast(name(ifname), {:indication, indication})
  end

  @impl GenServer
  def init(args) do
    ifname = Keyword.fetch!(args, :ifname)

    {:ok, %{ifname: ifname}}
  end

  @impl GenServer
  def handle_cast({:indication, %{name: :serving_system_indication} = indication}, state) do
    VintageNetQMI.Connectivity.serving_system_change(state.ifname, indication)

    {:noreply, state}
  end

  def handle_cast({:indication, %{name: :packet_status_indication} = indication}, state) do
    VintageNetQMI.Connectivity.connection_status_change(state.ifname, indication)
    {:noreply, state}
  end

  def handle_cast({:indication, %{name: :event_report_indication} = indication}, state) do
    VintageNetQMI.Connection.process_stats(state.ifname, indication)
    {:noreply, state}
  end

  def handle_cast({:indication, %{name: :sync_indication}}, state) do
    # Silently ignore sync indications
    {:noreply, state}
  end

  def handle_cast({:indication, indication}, state) do
    Logger.info("VintageNetQMI: ignoring indication: #{inspect(indication)}")
    {:noreply, state}
  end
end
