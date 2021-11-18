defmodule VintageNetQMI.Connection do
  @moduledoc """
  Establish an connection with the QMI device
  """

  use GenServer

  alias QMI.WirelessData
  alias VintageNet.PropertyTable

  require Logger

  @try_connect_interval 20_000
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
    service_providers = Keyword.fetch!(args, :service_providers)

    state =
      %{
        ifname: ifname,
        qmi: VintageNetQMI.qmi_name(ifname),
        service_providers: service_providers
      }
      |> try_configure_connection_stats_reporting()

    :ok = start_connect_timer()
    :ok = maybe_retry_configure_connection_stats(state)

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
  def handle_info(:connect, state) do
    case WirelessData.start_network_interface(state.qmi,
           apn: first_apn(state.service_providers)
         ) do
      {:ok, _} ->
        Logger.warn("[VintageNetQMI]: network started. Waiting on DHCP")
        # Internet connectivity is determined once DHCP returns so this is not
        {:noreply, state}

      {:error, reason} ->
        Logger.warn("[VintageNetQMI]: could not connect for #{inspect(reason)}.")
        start_connect_timer()
        {:noreply, state}
    end
  end

  def handle_info(:configure_connection_stats, state) do
    new_state = try_configure_connection_stats_reporting(state)

    :ok = maybe_retry_configure_connection_stats(new_state)

    {:noreply, new_state}
  end

  defp start_connect_timer() do
    _ = Process.send_after(self(), :connect, @try_connect_interval)
    :ok
  end

  def maybe_retry_configure_connection_stats(%{connection_stats_configured: true}), do: :ok

  def maybe_retry_configure_connection_stats(%{connection_stats_configured: false}) do
    _ = Process.send_after(self(), :configure_connection_stats, @configure_connection_stats_retry)

    :ok
  end

  defp first_apn([%{apn: apn} | _rest]), do: apn
end
