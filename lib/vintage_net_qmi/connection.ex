defmodule VintageNetQMI.Connection do
  use GenServer

  # GenServer for the connection
  # needs to handle control point management

  alias QMI.WirelessData

  require Logger

  @type arg() ::
          {:service_provider, String.t()}

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl GenServer
  def init(args) do
    service_provider = Keyword.fetch!(args, :service_provider)

    Process.sleep(10_000)

    state = %{
      service_provider: service_provider
    }

    connect(state)

    {:ok, state}
  end

  defp connect(state) do
    case WirelessData.start_network_interface(VintageNetQMI.qmi_name(),
           apn: state.service_provider
         ) do
      {:ok, _} ->
        :ok

      {:error, _reason} ->
        Logger.warn("[VintageNetQMI]: could not connect, trying again.")
        Process.sleep(5_000)
        connect(state)
    end
  end

  @impl GenServer
  def handle_info(message, state) do
    require Logger

    Logger.warn("#{inspect(message)}")
    {:noreply, state}
  end
end
