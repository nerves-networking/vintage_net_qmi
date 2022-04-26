defmodule VintageNetQMI.CellMonitor do
  @moduledoc false

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
      NetworkAccess.get_home_network(state.qmi)
      |> maybe_post_home_network(state)
      |> put_poll_ref(poll_ref)

    {:noreply, state}
  end

  def handle_info(:poll, state) do
    state =
      NetworkAccess.get_home_network(state.qmi)
      |> maybe_post_home_network(state)

    {:noreply, state}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  defp maybe_post_home_network({:ok, home_network}, state) do
    PropertyTable.put_many(VintageNet, [
      {["interface", state.ifname, "mobile", "mcc"], home_network.mcc},
      {["interface", state.ifname, "mobile", "mnc"], home_network.mnc},
      {["interface", state.ifname, "mobile", "provider"], home_network.provider}
    ])

    state
  end

  defp maybe_post_home_network({:error, _reason} = error, state) do
    Logger.warn("[VintageNetQMI] failed getting home network: #{inspect(error)}")
    state
  end

  defp put_poll_ref(state, poll_ref) do
    %{state | poll_reference: poll_ref}
  end
end
