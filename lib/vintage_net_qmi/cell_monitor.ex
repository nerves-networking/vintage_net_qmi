# SPDX-FileCopyrightText: 2021 Frank Hunleth
# SPDX-FileCopyrightText: 2021 Matt Ludwigs
# SPDX-FileCopyrightText: 2024 Connor Rigby
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNetQMI.CellMonitor do
  @moduledoc false

  alias VintageNetQMI.MCCMNC

  use GenServer

  @type arg() :: {:ifname, binary(), poll_interval: non_neg_integer()}

  require Logger

  alias QMI.NetworkAccess

  defp init_state(ifname, poll_interval) do
    %{
      ifname: ifname,
      qmi: VintageNetQMI.qmi_name(ifname),
      poll_interval: poll_interval,
      poll_reference: nil
    }
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl GenServer
  def init(args) do
    ifname = Keyword.fetch!(args, :ifname)
    poll_interval = Keyword.get(args, :poll_interval, 25_000)

    VintageNet.subscribe(["interface", ifname, "connection"])

    {:ok, init_state(ifname, poll_interval)}
  end

  @impl GenServer
  def handle_info(
        {VintageNet, ["interface", ifname, "connection"], _old, :internet, _meta},
        %{ifname: ifname} = state
      ) do
    {:ok, poll_ref} = :timer.send_interval(state.poll_interval, :poll)

    state =
      NetworkAccess.get_sys_info(state.qmi)
      |> maybe_post_lte_sys_info(state)
      |> put_poll_ref(poll_ref)

    {:noreply, state}
  end

  def handle_info(:poll, state) do
    state =
      NetworkAccess.get_sys_info(state.qmi)
      |> maybe_post_lte_sys_info(state)

    {:noreply, state}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  defp maybe_post_lte_sys_info({:ok, %{lte_sys_info: %{mcc: mcc, mnc: mnc}}}, state) do
    PropertyTable.put_many(VintageNet, [
      {["interface", state.ifname, "mobile", "mcc"], mcc},
      {["interface", state.ifname, "mobile", "mnc"], mnc},
      {["interface", state.ifname, "mobile", "provider"], MCCMNC.lookup_brand(mcc, mnc)}
    ])

    state
  end

  defp maybe_post_lte_sys_info(
         {:ok, %{srv_reg_restriction: :unrestricted, sim_rej_info: reject_info}},
         state
       ) do
    PropertyTable.put_many(VintageNet, [
      {["interface", state.ifname, "mobile", "sim_rej_info"], reject_info},
      {["interface", state.ifname, "mobile", "mcc"], nil},
      {["interface", state.ifname, "mobile", "mnc"], nil},
      {["interface", state.ifname, "mobile", "provider"], nil}
    ])

    state
  end

  defp maybe_post_lte_sys_info({:ok, unhandled}, state) do
    Logger.warning("[VintageNetQMI] Unhandled LTE SYS info: #{inspect(unhandled)}")
    state
  end

  defp maybe_post_lte_sys_info({:error, _reason} = error, state) do
    Logger.warning("[VintageNetQMI] failed getting home network: #{inspect(error)}")
    state
  end

  defp put_poll_ref(state, poll_ref) do
    %{state | poll_reference: poll_ref}
  end
end
