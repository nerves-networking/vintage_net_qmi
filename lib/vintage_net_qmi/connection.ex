defmodule VintageNetQMI.Connection do
  use GenServer

  # GenServer for the connection
  # needs to handle control point management

  alias QMI.Service.WirelessData

  require Logger

  @type arg() ::
          {:ifname, VintageNet.ifname()} | {:device, String.t()} | {:service_provider, String.t()}

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl GenServer
  def init(args) do
    ifname = Keyword.fetch!(args, :ifname)
    device = Keyword.fetch!(args, :device)
    service_provider = Keyword.fetch!(args, :service_provider)

    Process.sleep(10_000)

    case QMI.get_control_point(device, WirelessData) do
      {:ok, cp} ->
        state = %{
          ifname: ifname,
          device: device,
          service_provider: service_provider,
          control_point: cp
        }

        connect(state)

        {:ok, state}

      error ->
        Logger.warn("CP Error: #{inspect(error)}")

        {:stop, error}
    end
  end

  defp connect(%{device: device, control_point: cp, service_provider: apn} = state) do
    case WirelessData.start_network_interface(device, {1, cp.client_id}, apn: apn) do
      {:ok, _message} ->
        :ok

      # this error is when the device has already started the network connection
      {:error, %{error: :no_effect}} ->
        :ok

      {:error, :timeout} ->
        connect(state)
    end
  end

  @impl GenServer
  def handle_continue(:make_connection, state) do
    Process.sleep(10_000)

    require Logger

    %{control_point: cp, device: device, service_provider: service_provider} = state

    case WirelessData.start_network_interface(device, {3, cp.client_id}, apn: service_provider) do
      {:ok, message} ->
        Logger.warn("Connected: #{inspect(message)}")
        {:noreply, state}

      error ->
        Logger.warn("Connection Error: #{inspect(error)}")
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info(message, state) do
    require Logger

    Logger.warn("#{inspect(message)}")
    {:noreply, state}
  end
end
