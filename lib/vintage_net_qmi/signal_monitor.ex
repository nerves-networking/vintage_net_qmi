defmodule VintageNetQMI.SignalMonitor do
  @moduledoc """

  """

  use GenServer

  @type arg() :: {:ifname, VintageNet.ifname()}

  @doc """
  Start the SignalMonitor server
  """
  @spec start_link([arg()]) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl GenServer
  def init(args) do
    ifname = Keyword.fetch!(args, :ifname)

    Process.send_after(self(), :signal_check, 5_000)
    {:ok, ifname}
  end

  @impl GenServer
  def handle_info(:signal_check, ifname) do
    {:noreply, ifname}
  end
end
