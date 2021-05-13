defmodule VintageNetQMI.Connection do
  @moduledoc """
  Establish an connection with the QMI device
  """

  use GenServer

  alias QMI.WirelessData
  alias VintageNetQMI.Connectivity

  require Logger

  @try_connect_interval 20_000

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
    GenServer.start_link(__MODULE__, args)
  end

  @impl GenServer
  def init(args) do
    ifname = Keyword.fetch!(args, :ifname)
    service_providers = Keyword.fetch!(args, :service_providers)

    state = %{
      ifname: ifname,
      qmi: VintageNetQMI.qmi_name(ifname),
      service_providers: service_providers
    }

    VintageNet.subscribe(["interface", ifname, "addresses"])
    addresses = VintageNet.get(["interface", ifname, "addresses"], [])

    if Enum.any?(addresses, &ipv4?/1) do
      # If there's an IPv4 address, we're already connected. Maybe there was
      # a crash, but hey, it's connected, so we should be good.
      Connectivity.set_connectivity(ifname, :internet)
    else
      Connectivity.set_connectivity(ifname, :disconnected)

      :ok = start_connect_timer()
    end

    {:ok, state}
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

  def handle_info(
        {VintageNet, ["interface", ifname, "addresses"], _old, addresses, _meta},
        %{ifname: ifname} = state
      ) do
    if Enum.any?(addresses, &ipv4?/1) do
      # If there's an IPv4 address, then DHCP worked.
      Connectivity.set_connectivity(ifname, :internet)
    end

    {:noreply, state}
  end

  defp ipv4?(%{family: :inet}), do: true
  defp ipv4?(_), do: false

  defp start_connect_timer() do
    _ = Process.send_after(self(), :connect, @try_connect_interval)
    :ok
  end

  defp first_apn([%{apn: apn} | _rest]), do: apn
end
