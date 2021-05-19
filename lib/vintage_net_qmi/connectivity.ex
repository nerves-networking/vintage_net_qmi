defmodule VintageNetQMI.Connectivity do
  @moduledoc false

  use GenServer

  alias VintageNet.RouteManager

  @typedoc """
  Connectivity server initial arguments

  * `:ifname` - the interface name the connectivity server will manage
  """
  @type init_arg() :: {:ifname, String.t()}

  @doc """
  Start the Connectivity server
  """
  @spec start_link([init_arg()]) :: GenServer.on_start()
  def start_link(args) do
    ifname = Keyword.fetch!(args, :ifname)
    GenServer.start_link(__MODULE__, args, name: name(ifname))
  end

  defp name(ifname) do
    Module.concat(__MODULE__, ifname)
  end

  @doc """
  Report a serving system change to the connectivity server
  """
  @spec serving_system_change(String.t(), map()) :: :ok
  def serving_system_change(ifname, serving_system) do
    GenServer.call(name(ifname), {:serving_system_change, serving_system})
  end

  @impl GenServer
  def init(args) do
    ifname = Keyword.fetch!(args, :ifname)

    VintageNet.subscribe(["interface", ifname, "connection"])
    connection_status = VintageNet.get(["interface", ifname, "connection"])

    if connection_status == :lan && has_address?(ifname) do
      RouteManager.set_connection_status(ifname, :internet)
    end

    {:ok, %{ifname: ifname}}
  end

  @impl GenServer
  def handle_call({:serving_system_change, serving_system}, _from, state) do
    case connection_from_indication(serving_system) do
      :internet ->
        # The serving system can be reporting that a connection has happened
        # DCHP hasn't ran yet, so only set internet if there are IP addresses.
        if has_address?(state.ifname) do
          RouteManager.set_connection_status(state.ifname, :internet)
        end

      :disconnected ->
        RouteManager.set_connection_status(state.ifname, :disconnected)

      _ ->
        nil
    end

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_info(
        {VintageNet, ["interface", ifname, "connection"], :disconnected, :lan, _meta},
        %{ifname: ifname} = state
      ) do
    RouteManager.set_connection_status(ifname, :internet)

    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp has_address?(ifname) do
    VintageNet.get(["interface", ifname, "addresses"])
    |> Enum.any?(&ipv4?/1)
  end

  defp ipv4?(%{family: :inet}), do: true
  defp ipv4?(_), do: false

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
         serving_system_selected_network: network
       })
       when network != :network_unknown do
    if Enum.empty?(radio_ifs) do
      nil
    else
      :internet
    end
  end

  defp connection_from_indication(_indication), do: nil
end
