defmodule VintageNetQMI.SignalMonitor do
  use GenServer

  alias VintageNet.PropertyTable
  alias VintageNetQMI.ASUCalculator

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl GenServer
  def init(args) do
    interval = Keyword.get(args, :signal_check_interval, 5_000)
    device = Keyword.get(args, :device)
    ifname = Keyword.fetch!(args, :ifname)

    Process.send_after(self(), :signal_check, interval)

    {:ok, control_point} = QMI.get_control_point(device, QMI.Service.NetworkAccess)

    state = %{
      ifname: ifname,
      signal_check_interval: interval,
      control_point: control_point
    }

    :ok = get_signal_stats(state)

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:signal_check, state) do
    :ok = get_signal_stats(state)

    Process.send_after(self(), :signal_check, state.signal_check_interval)

    {:noreply, state}
  end

  defp get_signal_stats(state) do
    {:ok, message} =
      QMI.Service.NetworkAccess.get_signal_strength(
        state.control_point.device,
        {0x03, state.control_point.client_id}
      )

    message
    |> to_rssi()
    |> maybe_pet_power_control(state.ifname)
    |> post_signal_rssi(state.ifname)

    :ok
  end

  defp to_rssi(%QMI.Message{tlvs: tlvs}) do
    Enum.reduce(tlvs, nil, fn
      %{rssi: rssi}, nil ->
        ASUCalculator.from_lte_rssi(rssi)

      _, acc ->
        acc
    end)
  end

  defp maybe_pet_power_control(%{bars: bars} = report, ifname) when bars > 0 do
    VintageNet.PowerManager.PMControl.pet_watchdog(ifname)
    report
  end

  defp post_signal_rssi(%{asu: asu, dbm: dbm, bars: bars}, ifname) do
    PropertyTable.put(VintageNet, ["interface", ifname, "mobile", "signal_asu"], asu)
    PropertyTable.put(VintageNet, ["interface", ifname, "mobile", "signal_dbm"], dbm)
    PropertyTable.put(VintageNet, ["interface", ifname, "mobile", "signal_4bars"], bars)
  end
end
