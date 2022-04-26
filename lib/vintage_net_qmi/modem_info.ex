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

  @type init_arg() :: {:ifname, VintageNet.ifname()}

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
    send(self(), :get_serial_numbers)
    send(self(), :get_model)
    send(self(), :get_manufacturer)

    {:ok,
     %{ifname: ifname, iccid: false, serial_numbers: false, model: false, manufacturer: false}}
  end

  @impl GenServer
  def handle_info(:get_serial_numbers, state) do
    qmi = VintageNetQMI.qmi_name(state.ifname)

    case DeviceManagement.get_serial_numbers(qmi) do
      {:ok, serial_numbers} ->
        put_serial_numbers(serial_numbers, state)
        return_value(%{state | serial_numbers: true})

      {:error, reason} ->
        Logger.warn("[VintageNetQMI] unable to get serial numbers for #{inspect(reason)}")
        retry_and_return(:get_serial_numbers, state)
    end
  end

  def handle_info(:get_iccid, state) do
    qmi = VintageNetQMI.qmi_name(state.ifname)

    case UserIdentity.read_transparent(qmi, @iccid_file_id, @main_file_path) do
      {:ok, read_response} ->
        iccid = UserIdentity.parse_iccid(read_response.read_result)
        property_table_put("iccid", iccid, state)
        return_value(%{state | iccid: true})

      {:error, reason} ->
        Logger.warn("[VintageNetQMI] unable to get CCID for #{inspect(reason)}")
        retry_and_return(:get_iccid, state)
    end
  end

  def handle_info(:get_model, state) do
    qmi = VintageNetQMI.qmi_name(state.ifname)

    case DeviceManagement.get_model(qmi) do
      {:ok, model} ->
        property_table_put("model", model, state)
        return_value(%{state | model: true})

      {:error, reason} ->
        Logger.debug("[VintageNetQMI] unable to get modem model for #{inspect(reason)}")
        retry_and_return(:get_model, state)
    end
  end

  def handle_info(:get_manufacturer, state) do
    qmi = VintageNetQMI.qmi_name(state.ifname)

    case DeviceManagement.get_manufacturer(qmi) do
      {:ok, manufacturer} ->
        property_table_put("manufacturer", manufacturer, state)
        return_value(%{state | manufacturer: true})

      {:error, reason} ->
        Logger.debug("[VintageNetQMI] unable to get modem manufacturer for #{inspect(reason)}")
        retry_and_return(:get_manufacturer, state)
    end
  end

  defp put_serial_numbers(serial_numbers, state) do
    Enum.each(serial_numbers, fn
      {serial_number_name, serial_number} ->
        serial_number_name
        |> Atom.to_string()
        |> property_table_put(serial_number, state)
    end)
  end

  defp property_table_put(property, nil, state) do
    PropertyTable.delete(VintageNet, ["interface", state.ifname, "mobile", property])
  end

  defp property_table_put(property, value, state) do
    PropertyTable.put(VintageNet, ["interface", state.ifname, "mobile", property], value)
  end

  defp retry_and_return(name, state) do
    retry(name)
    return_value(state)
  end

  defp return_value(%{iccid: true, serial_numbers: true, model: true, manufacturer: true} = state) do
    {:stop, :normal, state}
  end

  defp return_value(state) do
    {:noreply, state}
  end

  defp retry(name) do
    Process.send_after(self(), name, 1_000)
  end

  @impl GenServer
  def terminate(_reason, _state), do: :ok
end
