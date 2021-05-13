defmodule VintageNetQMI.Indications do
  @moduledoc false

  # Server that handles incoming indications

  use GenServer

  alias VintageNetQMI.Connectivity

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
    indication
    |> connection_from_indication()
    |> maybe_set_connectivity(state.ifname)

    {:noreply, state}
  end

  defp maybe_set_connectivity(nil, _ifname), do: :ok
  defp maybe_set_connectivity(status, ifname), do: Connectivity.set_connectivity(ifname, status)

  defp connection_from_indication(%{
         serving_system_cs_attach_state: :detached,
         serving_system_ps_attach_state: :detached,
         serving_system_radio_interfaces: [:no_service],
         serving_system_registration_state: :not_registered,
         serving_system_selected_network: :network_unknown
       }) do
    :disconnected
  end

  defp connection_from_indication(%{
         serving_system_cs_attach_state: :attached,
         serving_system_ps_attach_state: :attached,
         serving_system_radio_interfaces: radio_ifs,
         serving_system_registration_state: :registered,
         serving_system_selected_network: :network_3gpp
       }) do
    if Enum.empty?(radio_ifs) do
      nil
    else
      :internet
    end
  end

  defp connection_from_indication(_indication), do: nil
end
