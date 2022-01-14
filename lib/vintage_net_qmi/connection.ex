defmodule VintageNetQMI.Connection do
  @moduledoc """
  Establish an connection with the QMI device
  """

  use GenServer

  alias QMI.WirelessData
  alias VintageNet.PropertyTable
  alias VintageNetQMI.ServiceProvider

  require Logger

  @configure_connection_stats_retry 10_000

  @typedoc """
  Options for to establish the connection

  `:apn` - The Access Point Name of the service provider
  """
  @type arg() :: {:service_provider, String.t()}

  @doc """
  Start the Connection server
  """
  @spec start_link([arg()]) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: name(args[:ifname]))
  end

  defp name(ifname) do
    Module.concat(__MODULE__, ifname)
  end

  @doc """
  Process connection stats

  This will post the updated stats as properties.
  """
  @spec process_stats(VintageNet.ifname(), map()) :: :ok
  def process_stats(ifname, event_report_indication) do
    stats = Map.drop(event_report_indication, [:name])
    GenServer.cast(name(ifname), {:process_stats, stats})
  end

  @impl GenServer
  def init(args) do
    ifname = Keyword.fetch!(args, :ifname)
    providers = Keyword.fetch!(args, :service_providers)

    VintageNet.subscribe(["interface", ifname, "mobile", "iccid"])
    iccid = VintageNet.get(["interface", ifname, "mobile", "iccid"])

    state =
      %{
        ifname: ifname,
        qmi: VintageNetQMI.qmi_name(ifname),
        service_providers: providers,
        iccid: iccid,
        connect_retry_interval: 30_000
      }
      |> try_configure_connection_stats_reporting()
      |> maybe_retry_configure_connection_stats()
      |> maybe_start_try_to_connect_timer()

    {:ok, state}
  end

  defp try_configure_connection_stats_reporting(state) do
    case WirelessData.set_event_report(state.qmi) do
      :ok ->
        Map.put(state, :connection_stats_configured, true)

      {:error, _reason} ->
        Map.put(state, :connection_stats_configured, false)
    end
  end

  @impl GenServer
  def handle_cast({:process_stats, stats}, state) do
    timestamp = System.monotonic_time()
    stats_with_timestamp = Map.put(stats, :timestamp, timestamp)

    PropertyTable.put(
      VintageNet,
      ["interface", state.ifname, "mobile", "statistics"],
      stats_with_timestamp
    )

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(
        {VintageNet, ["interface", ifname, "mobile", "iccid"], nil, iccid, _meta},
        %{ifname: ifname} = state
      ) do
    new_state = %{state | iccid: iccid}

    {:noreply, try_to_connect(new_state)}
  end

  def handle_info(:try_to_connect, state) do
    {:noreply, try_to_connect(state)}
  end

  def handle_info(:configure_connection_stats, state) do
    new_state =
      state
      |> try_configure_connection_stats_reporting()
      |> maybe_retry_configure_connection_stats()

    {:noreply, new_state}
  end

  defp try_to_connect(state) do
    with apn when apn != nil <-
           ServiceProvider.select_apn_by_iccid(state.service_providers, state.iccid),
         :ok <- PropertyTable.put(VintageNet, ["interface", state.ifname, "mobile", "apn"], apn),
         {:ok, _} <- WirelessData.start_network_interface(state.qmi, apn: apn) do
      Logger.info("[VintageNetQMI]: network started. Waiting on DHCP")
      state
    else
      nil ->
        Logger.warn(
          "[VintageNetQMI]: cannot select an APN to use from the configured service providers, check your configuration for VintageNet."
        )

        state

      {:error, :no_effect} ->
        # no effect means that a network connection as already be established
        # so we don't need to try to connect again.
        state

      {:error, reason} ->
        Logger.warn(
          "[VintageNetQMI]: could not connect for #{inspect(reason)}. Retrying in #{inspect(state.connect_retry_interval)} ms."
        )

        start_try_to_connect_timer(state)
    end
  end

  defp maybe_start_try_to_connect_timer(%{iccid: nil} = state), do: state

  defp maybe_start_try_to_connect_timer(state), do: start_try_to_connect_timer(state)

  defp start_try_to_connect_timer(state) do
    _ = Process.send_after(self(), :try_to_connect, state.connect_retry_interval)
    state
  end

  def maybe_retry_configure_connection_stats(%{connection_stats_configured: true} = state),
    do: state

  def maybe_retry_configure_connection_stats(%{connection_stats_configured: false} = state) do
    _ = Process.send_after(self(), :configure_connection_stats, @configure_connection_stats_retry)

    state
  end
end
