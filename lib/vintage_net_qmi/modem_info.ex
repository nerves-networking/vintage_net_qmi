defmodule VintageNetQMI.ModemInfo do
  @moduledoc false

  # For more information about the transparent file used to read ICCID see
  # https://www.etsi.org/deliver/etsi_gts/11/1111/05.03.00_60/gsmts_1111v050300p.pdf
  # Section 10.1.1

  @iccid_file_id 0x2FE2
  @main_file_path 0x3F00

  use GenServer, restart: :transient

  require Logger

  alias QMI.UserIdentity
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

    {:ok, %{ifname: ifname}}
  end

  @impl GenServer
  def handle_info(:get_iccid, state) do
    qmi = VintageNetQMI.qmi_name(state.ifname)

    case UserIdentity.read_transparent(qmi, @iccid_file_id, @main_file_path) do
      {:ok, read_response} ->
        iccid = UserIdentity.parse_iccid(read_response.read_result)
        PropertyTable.put(VintageNet, ["interface", state.ifname, "mobile", "iccid"], iccid)
        {:stop, :normal, state}

      {:error, reason} ->
        Logger.warn("[VintageNetQMI] unable to get CCID for #{inspect(reason)}")
        Process.send_after(self(), :get_iccid, 1_000)
        {:noreply, state}
    end
  end

  @impl GenServer
  def terminate(_reason, _state), do: :ok
end
