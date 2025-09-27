# SPDX-FileCopyrightText: 2025 Jose Rodriguez (josev01@gmail.com)
# SPDX-License-Identifier: Apache-2.0

defmodule VintageNetQMI.MtuManager do
  @moduledoc false

  use GenServer

  require Logger

  @type opt() :: {:ifname, binary()} | {:refresh_ms, non_neg_integer()}

  @default_refresh 300_000

  @spec start_link([opt()]) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl GenServer
  def init(args) do
    ifname = Keyword.fetch!(args, :ifname)
    refresh_ms = Keyword.get(args, :refresh_ms, @default_refresh)

    VintageNet.subscribe(["interface", ifname, "connection"])

    state = %{
      ifname: ifname,
      qmi: VintageNetQMI.qmi_name(ifname),
      refresh_ms: refresh_ms,
      refresh_ref: nil
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_info(
        {VintageNet, ["interface", ifname, "connection"], _old, status, _meta},
        %{ifname: ifname} = state
      )
      when status in [:lan, :internet] do
    _ = apply_mtu_and_mss(state)
    {:ok, ref} = :timer.send_interval(state.refresh_ms, :refresh)
    {:noreply, %{state | refresh_ref: ref}}
  end

  def handle_info(
        {VintageNet, ["interface", ifname, "connection"], _old, _status, _meta},
        %{ifname: ifname, refresh_ref: ref} = state
      ) do
    if is_reference(ref), do: Process.cancel_timer(ref)
    {:noreply, %{state | refresh_ref: nil}}
  end

  def handle_info(:refresh, state) do
    _ = apply_mtu_and_mss(state)
    {:noreply, state}
  end

  defp apply_mtu_and_mss(%{ifname: ifname, qmi: qmi}) do
    opts = [extended_mask: 0xFFFF_FFFF]

    mtu =
      case QMI.WirelessData.get_current_settings(qmi, 6, opts) do
        {:ok, m} when is_map(m) and map_size(m) > 0 ->
          m[:ipv6_mtu] || m[:ipv4_mtu]

        _ ->
          case QMI.WirelessData.get_current_settings(qmi, 4, opts) do
            {:ok, m} when is_map(m) and map_size(m) > 0 -> m[:ipv4_mtu] || m[:ipv6_mtu]
            _ -> nil
          end
      end

    if is_integer(mtu) and mtu > 0 do
      set_mtu_linux(ifname, mtu)
      :ok
    else
      Logger.debug("[VintageNetQMI] MTU not available yet for #{ifname}")
      :noop
    end
  end

  defp set_mtu_linux(ifname, mtu) do
    System.cmd("ip", ["link", "set", "dev", ifname, "mtu", Integer.to_string(mtu)])
  end
end
