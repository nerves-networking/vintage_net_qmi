defmodule VintageNetQMI.SignalMonitor do
  @moduledoc false

  use GenServer

  alias QMI.NetworkAccess
  alias VintageNet.PowerManager.PMControl
  alias VintageNet.PropertyTable
  alias VintageNetQMI.ASUCalculator

  @type opt() :: {:ifname, binary()} | {:interval, non_neg_integer()}

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl GenServer
  def init(args) do
    interval = Keyword.get(args, :interval, 30_000)
    ifname = Keyword.fetch!(args, :ifname)

    Process.send_after(self(), :signal_check, interval)

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

    Process.send_after(self(), :signal_check, state.interval)

    {:noreply, state}
  end

  defp get_signal_stats(state) do
    {:ok, %{rssi_reports: [rssi_data]}} = NetworkAccess.get_signal_strength(state.qmi)

    rssi_data
    |> to_rssi()
    |> maybe_pet_power_control(state.ifname)
    |> post_signal_rssi(state.ifname)
  end

  defp to_rssi(%{rssi: rssi}) do
    ASUCalculator.from_lte_rssi(rssi)
  end

  defp maybe_pet_power_control(%{bars: bars} = report, ifname) when bars > 0 do
    PMControl.pet_watchdog(ifname)
    report
  end

  defp post_signal_rssi(%{asu: asu, dbm: dbm, bars: bars}, ifname) do
    PropertyTable.put(VintageNet, ["interface", ifname, "mobile", "signal_asu"], asu)
    PropertyTable.put(VintageNet, ["interface", ifname, "mobile", "signal_dbm"], dbm)
    PropertyTable.put(VintageNet, ["interface", ifname, "mobile", "signal_4bars"], bars)
  end
end
