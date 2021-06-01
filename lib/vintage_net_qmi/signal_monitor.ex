defmodule VintageNetQMI.SignalMonitor do
  @moduledoc false

  use GenServer

  alias QMI.NetworkAccess
  alias VintageNetQMI.ASUCalculator

  require Logger

  @type opt() :: {:ifname, binary()} | {:interval, non_neg_integer()}

  @spec start_link([opt()]) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl GenServer
  def init(args) do
    interval = Keyword.get(args, :interval, 30_000)
    ifname = Keyword.fetch!(args, :ifname)

    send_msgs([:signal_check, :band_and_channel_check], interval)

    state = %{
      ifname: ifname,
      qmi: VintageNetQMI.qmi_name(ifname),
      interval: interval
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:signal_check, state) do
    :ok = get_signal_stats(state)

    send_msgs([:signal_check], state.interval)

    {:noreply, state}
  end

  def handle_info(:band_and_channel_check, state) do
    case NetworkAccess.get_rf_band_info(state.qmi) do
      {:ok, [band_and_channel]} ->
        post_band_and_channel_info(band_and_channel, state)
        send_msgs([:band_and_channel_check], state.interval * 2)

      {:error, _reason} ->
        Logger.debug("[VintageNetQMI] unable to get band and channel information, retrying.")
        send_msgs([:band_and_channel_check], state.interval)
    end

    {:noreply, state}
  end

  defp get_signal_stats(state) do
    {:ok, %{rssi_reports: [rssi_data]}} = NetworkAccess.get_signal_strength(state.qmi)

    rssi_data
    |> to_rssi()
    |> Map.put(:rssi, rssi_data.rssi)
    |> post_signal_rssi(state)
    |> execute_telemetry_event(state)
  end

  defp to_rssi(%{rssi: rssi}) do
    ASUCalculator.from_lte_rssi(rssi)
  end

  defp post_signal_rssi(%{asu: asu, dbm: dbm, bars: bars}, ifname) do
    PropertyTable.put_many(VintageNet, [
      to_property(ifname, "signal_asu", asu),
      to_property(ifname, "signal_dbm", dbm),
      to_property(ifname, "signal_4bars", bars)
    ])
  end

  defp post_band_and_channel_info(
         %{band: band, channel: channel, interface: access_technology},
         state
       ) do
    PropertyTable.put_many(VintageNet, [
      to_property(state.ifname, "band", band),
      to_property(state.ifname, "channel", channel),
      to_property(state.ifname, "access_technology", access_technology)
    ])
  end

  defp to_property(ifname, prop_name, prop_value) do
    {["interface", ifname, "mobile", prop_name], prop_value}
  end

  defp send_msgs(messages, interval) do
    Enum.each(messages, &Process.send_after(self(), &1, interval))
  end

  defp execute_telemetry_event(signal_measurements, state) do
    :telemetry.execute(
      [:vintage_net_qmi, :signal_strength],
      signal_measurements,
      %{ifname: state.ifname}
    )
  end
end
