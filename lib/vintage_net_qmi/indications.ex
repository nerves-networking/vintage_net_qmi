defmodule VintageNetQMI.Indications do
  @moduledoc false

  # Server that handles incoming indications

  use GenServer

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
  @spec handle(String.t(), map()) :: :ok
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
end
