# SPDX-FileCopyrightText: 2021 Frank Hunleth
# SPDX-FileCopyrightText: 2021 Matt Ludwigs
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNetQMI.Connectivity do
  @moduledoc false

  use GenServer

  alias VintageNet.PowerManager.PMControl
  alias VintageNet.RouteManager

  # Serving system reports say which cell ID we're connected to
  # and various statuses. Moving between cell IDs causes the status
  # to look like the modem is disconnected, but then it reconnects
  # quickly. The grace period lets things settle.
  @serving_system_down_grace_period 1000

  @typedoc """
  Connectivity server initial arguments

  * `:ifname` - the interface name the connectivity server will manage
  """
  @type init_arg() :: {:ifname, VintageNet.ifname()}

  defstruct [
    :ifname,
    :reported_status,
    :derived_status,
    :grace_timer,
    :lan?,
    :ip_address?,
    :serving_system,
    :packet_data_connection?
  ]

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
  @spec serving_system_change(VintageNet.ifname(), map()) :: :ok
  def serving_system_change(ifname, serving_system) do
    GenServer.cast(name(ifname), {:serving_system_change, serving_system})
  end

  @doc """
  Report a packet data connection status change
  """
  @spec connection_status_change(VintageNet.ifname(), map()) :: :ok
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
    has_ipv4? = has_ipv4_address?(addresses)

    # If the GenServer crashed and recovered, try to guess the status even though
    # we don't know the serving system info.
    guessed_status =
      if connection_status == :internet and has_ipv4?, do: :internet, else: :disconnected

    RouteManager.set_connection_status(ifname, guessed_status, "Initial state")

    state = %__MODULE__{
      ifname: ifname,
      reported_status: guessed_status,
      derived_status: guessed_status,
      grace_timer: nil,
      # The following keep track of all of the conditions that need to be
      # true for the modem to have internet access
      lan?: connection_status == :lan or connection_status == :internet,
      ip_address?: has_ipv4?,
      serving_system: %{
        serving_system_cs_attach_state: :detached,
        serving_system_ps_attach_state: :detached,
        serving_system_radio_interfaces: [],
        serving_system_registration_state: :unregistered,
        serving_system_selected_network: :network_unknown
      },
      # The packet data connection status reported from QMI. Being connected
      # does not mean that the IP address has been assigned only that
      # IP address configuration can commence.
      packet_data_connection?: guessed_status == :internet
    }

    _ = :timer.send_interval(30_000, :check_connectivity)

    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:serving_system_change, serving_system}, state) do
    new_state =
      %{state | serving_system: serving_system}
      |> update_derived_status()
      |> update_connection_status()
      |> update_time_location_properties()

    {:noreply, new_state}
  end

  def handle_cast({:connection_status_change, connection_status}, state) do
    new_state =
      %{state | packet_data_connection?: connection_status.status == :connected}
      |> update_derived_status()
      |> update_connection_status()

    {:noreply, new_state}
  end

  defp update_time_location_properties(state) do
    fields = [
      :cell_id,
      :location_area_code,
      :network_datetime,
      :roaming,
      :utc_offset,
      :std_offset
    ]

    properties =
      Enum.flat_map(fields, &maybe_time_location_property(state.serving_system, &1, state))

    PropertyTable.put_many(VintageNet, properties)
    state
  end

  defp maybe_time_location_property(serving_system, field, state) do
    if value = serving_system[field] do
      prop_name = prop_name_for_serving_system_field(field)
      [{["interface", state.ifname, "mobile", prop_name], value}]
    else
      []
    end
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
      %{state | lan?: true}
      |> update_derived_status()
      |> update_connection_status()

    {:noreply, new_state}
  end

  def handle_info(
        {VintageNet, ["interface", ifname, "addresses"], _old, addresses, _meta},
        %{ifname: ifname} = state
      ) do
    new_state =
      %{state | ip_address?: has_ipv4_address?(addresses)}
      |> update_derived_status()
      |> update_connection_status()

    {:noreply, new_state}
  end

  def handle_info(:grace_timeout, state) do
    if state.derived_status == :going_down do
      new_state =
        %{state | derived_status: :disconnected, grace_timer: nil}
        |> update_connection_status()

      {:noreply, new_state}
    else
      {:noreply, %{state | grace_timer: nil}}
    end
  end

  def handle_info(:check_connectivity, state) do
    if state.reported_status == :internet do
      PMControl.pet_watchdog(state.ifname)
    end

    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp update_derived_status(state) do
    new_derived_status = derive_status(state)

    new_grace_timer =
      case new_derived_status do
        :going_down ->
          # If the connection might be going down, start the timer
          # unless it's already going. If it's already going, we
          # count from that point.
          state.grace_timer || schedule_grace_timer()

        _ ->
          # If the connection is definitely up or down, make sure
          # the grace timeout gets cancelled.
          if state.grace_timer do
            _ = :timer.cancel(state.grace_timer)
            nil
          end
      end

    %{state | derived_status: new_derived_status, grace_timer: new_grace_timer}
  end

  defp schedule_grace_timer() do
    {:ok, tid} = :timer.send_after(@serving_system_down_grace_period, self(), :grace_timeout)
    tid
  end

  # Derive whether LTE is connected or not.
  # The first three cases are obviously disconnected.
  defp derive_status(%{lan?: false}), do: :disconnected
  defp derive_status(%{ip_address?: false}), do: :disconnected
  defp derive_status(%{packet_data_connection?: false}), do: :disconnected

  # At this point, we have the basics. Check that there's a network and we're
  # registered. Here's a report when connected:
  #
  # %{
  #   cell_id: 142_495_091,
  #   indication_id: 36,
  #   name: :serving_system_indication,
  #   service_id: 3,
  #   serving_system_cs_attach_state: :attached,
  #   serving_system_ps_attach_state: :attached,
  #   serving_system_radio_interfaces: [:lte],
  #   serving_system_registration_state: :registered,
  #   serving_system_selected_network: :network_3gpp
  # }
  defp derive_status(%{
         serving_system: %{
           serving_system_cs_attach_state: :attached,
           serving_system_ps_attach_state: :attached,
           serving_system_radio_interfaces: radio_ifs,
           serving_system_registration_state: :registered,
           serving_system_selected_network: network
         }
       })
       when network != :network_unknown and
              radio_ifs != [] do
    :internet
  end

  # This last catch-all is for any serving system information change that's not
  # connected. For example, when transitioning between cell ids, something like
  # this will come through:
  #
  # %{
  #   indication_id: 36,
  #   name: :serving_system_indication,
  #   service_id: 3,
  #   serving_system_cs_attach_state: :detached,
  #   serving_system_ps_attach_state: :detached,
  #   serving_system_radio_interfaces: [:lte],
  #   serving_system_registration_state: :registered,
  #   serving_system_selected_network: :network_3gpp
  # }
  defp derive_status(_state), do: :going_down

  defp update_connection_status(
         %{reported_status: :disconnected, derived_status: :internet} = state
       ) do
    RouteManager.set_connection_status(
      state.ifname,
      :internet,
      "QMI reports Internet-connectivity"
    )

    %{state | reported_status: :internet}
  end

  defp update_connection_status(
         %{reported_status: :internet, derived_status: :disconnected} = state
       ) do
    RouteManager.set_connection_status(
      state.ifname,
      :disconnected,
      "QMI(#{inspect(state)}}"
    )

    %{state | reported_status: :disconnected}
  end

  defp update_connection_status(state), do: state

  defp has_ipv4_address?(nil), do: false

  defp has_ipv4_address?(addresses) do
    Enum.any?(addresses, &ipv4?/1)
  end

  defp ipv4?(%{family: :inet}), do: true
  defp ipv4?(_), do: false
end
