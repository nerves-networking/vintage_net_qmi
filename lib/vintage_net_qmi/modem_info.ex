defmodule VintageNetQMI.ModemInfo do
  @moduledoc false

  # For more information about the transparent file used to read ICCID see
  # https://www.etsi.org/deliver/etsi_gts/11/1111/05.03.00_60/gsmts_1111v050300p.pdf
  # Section 10.1.1

  @iccid_file_id 0x2FE2
  @main_file_path 0x3F00

  use GenServer, restart: :transient

  require Logger

  alias QMI.{DeviceManagement, UserIdentity}
  alias VintageNet.PropertyTable

  @type init_arg() :: {:ifname, String.t()}

  @doc """
  Start the ModemInfo server
  """
  @spec start_link([init_arg()]) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl GenServer
  def init(args) do
    ifname = Keyword.fetch!(args, :ifname)
    send(self(), :get_iccid)
    send(self(), :get_manufacturer)
    send(self(), :get_model)

    {:ok, %{ifname: ifname, manufacturer: nil, model: nil, ccid: nil}}
  end

  @impl GenServer
  def handle_info(:get_iccid, state) do
    qmi = VintageNetQMI.qmi_name(state.ifname)

    case UserIdentity.read_transparent(qmi, @iccid_file_id, @main_file_path) do
      {:ok, read_response} ->
        iccid = UserIdentity.parse_iccid(read_response.read_result)
        PropertyTable.put(VintageNet, ["interface", state.ifname, "mobile", "iccid"], iccid)
        reply_value(%{state | ccid: iccid})

      {:error, reason} ->
        Logger.warn("[VintageNetQMI] unable to get CCID for #{inspect(reason)}")
        retry_after(:get_ccid, 1_000)
        reply_value(state)
    end
  end

  def handle_info(:get_manufacturer, state) do
    qmi = VintageNetQMI.qmi_name(state.ifname)

    case DeviceManagement.get_manufacturer(qmi) do
      {:ok, manufacturer} ->
        PropertyTable.put(
          VintageNet,
          ["interface", state.ifname, "mobile", "manufacturer"],
          manufacturer
        )

        reply_value(%{state | manufacturer: manufacturer})

      {:error, reason} ->
        Logger.warn("[VintageNetQMI] unable to get manufacturer for #{inspect(reason)}")
        retry_after(:get_manufacturer, 1_200)
        reply_value(state)
    end
  end

  def handle_info(:get_model, state) do
    qmi = VintageNetQMI.qmi_name(state.ifname)

    case DeviceManagement.get_model(qmi) do
      {:ok, model} ->
        PropertyTable.put(VintageNet, ["interface", state.ifname, "mobile", "model"], model)
        reply_value(%{state | model: model})

      {:error, reason} ->
        Logger.warn("[VintageNetQMI] unable to get model for #{inspect(reason)}")
        retry_after(:get_model, 1_500)
        reply_value(state)
    end
  end

  defp retry_after(message, wait) do
    Process.send_after(self(), message, wait)
  end

  defp reply_value(state) do
    if Enum.any?(Map.values(state), &(&1 == nil)) do
      {:noreply, state}
    else
      {:stop, :normal, state}
    end
  end

  @impl GenServer
  def terminate(_reason, _state), do: :ok
end
