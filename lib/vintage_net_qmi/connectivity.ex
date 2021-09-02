defmodule VintageNetQMI.Connectivity do
  @moduledoc false

  use GenServer

  alias VintageNet.PowerManager.PMControl
  alias VintageNet.{PropertyTable, RouteManager}

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
    GenServer.cast(name(ifname), {:serving_system_change, serving_system})
  end

  @doc """
  Report a packet data connection status change
  """
  @spec connection_status_change(String.t(), map()) :: :ok
  def connection_status_change(ifname, connection_status) do
    GenServer.cast(name(ifname), {:connection_status_change, connection_status})
  end

  @impl GenServer
  def init(args) do
    ifname = Keyword.fetch!(args, :ifname)

    VintageNet.subscribe(["interface", ifname, "connection"])
    VintageNet.subscribe(["interface", ifname, "addresses"])
    connection_status = VintageNet.get(["interface", ifname, "connection"])
    addresses = VintageNet.get(["interface", ifname, "addresses"])

    state =
      %{
        ifname: ifname,
        # Set the cached status to internet since the logic for updating the
        # connection status always updates the RouteManager in this state.
        cached_status: :internet,
        # The following keep track of all of the conditions that need to be
        # true for the modem to have internet access
        lan?: connection_status == :lan or connection_status == :internet,
        ip_address?: has_ipv4_address?(addresses),
        serving_system?: true,
        # The packet data connection status reported from QMI. Being connected
        # does not mean that the IP address has been assigned only that
        # IP address configuration can commence.
        packet_data_connection: :disconnected
      }
      |> update_connection_status()

    _ = :timer.send_interval(60, :check_connectivity)

    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:serving_system_change, serving_system}, state) do
    new_state =
      state
      |> Map.put(:serving_system?, serving_system_connected?(serving_system))
      |> update_connection_status()

    update_time_location_properties(serving_system, state)

    {:noreply, new_state}
  end

  def handle_cast({:connection_status_change, connection_status}, state) do
    new_state =
      state
      |> Map.put(:packet_data_connection, connection_status.status)
      |> update_connection_status()

    {:noreply, new_state}
  end

  defp update_time_location_properties(serving_system, state) do
    fields = [
      :cell_id,
      :location_area_code,
      :network_datetime,
      :roaming,
      :utc_offset,
      :std_offset
    ]

    Enum.each(fields, &maybe_update_time_location_property(serving_system, &1, state))
  end

  defp maybe_update_time_location_property(serving_system, field, state) do
    if value = serving_system[field] do
      prop_name = prop_name_for_serving_system_field(field)
      PropertyTable.put(VintageNet, ["interface", state.ifname, "mobile", prop_name], value)
    end

    :ok
  end

  defp prop_name_for_serving_system_field(:location_area_code), do: "lac"
  defp prop_name_for_serving_system_field(:cell_id), do: "cid"
  defp prop_name_for_serving_system_field(other), do: Atom.to_string(other)

  @impl GenServer
  def handle_info(
        {VintageNet, ["interface", ifname, "connection"], _, :lan, _meta},
        %{ifname: ifname} = state
      ) do
    new_state =
      state
      |> Map.put(:lan?, true)
      |> update_connection_status()

    {:noreply, new_state}
  end

  def handle_info(
        {VintageNet, ["interface", ifname, "addresses"], _old, addresses, _meta},
        %{ifname: ifname} = state
      ) do
    new_state =
      state
      |> Map.put(:ip_address?, has_ipv4_address?(addresses))
      |> update_connection_status()

    {:noreply, new_state}
  end

  def handle_info(:check_connectivity, state) do
    if state.cached_status == :internet do
      PMControl.pet_watchdog(state.ifname)
    end

    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp update_connection_status(
         %{
           lan?: true,
           serving_system?: true,
           ip_address?: true,
           packet_data_connection: :connected
         } = state
       ) do
    RouteManager.set_connection_status(state.ifname, :internet)
    %{state | cached_status: :internet}
  end

  defp update_connection_status(%{cached_status: :internet} = state) do
    RouteManager.set_connection_status(state.ifname, :disconnected)
    %{state | cached_status: :disconnected}
  end

  defp update_connection_status(state), do: state

  defp has_ipv4_address?(addresses) do
    Enum.any?(addresses, &ipv4?/1)
  end

  defp ipv4?(%{family: :inet}), do: true
  defp ipv4?(_), do: false

  defp serving_system_connected?(%{
         serving_system_cs_attach_state: :attached,
         serving_system_ps_attach_state: :attached,
         serving_system_radio_interfaces: radio_ifs,
         serving_system_registration_state: :registered,
         serving_system_selected_network: network
       })
       when network != :network_unknown and
              radio_ifs != [] do
    true
  end

  defp serving_system_connected?(_indication), do: false
end
