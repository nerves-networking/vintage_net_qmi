defmodule VintageNetQMI.Connectivity do
  @moduledoc false

  # Helpers for connectivity functionality

  alias VintageNet.{PropertyTable, RouteManager}

  @doc """
  Set the connectivity of the interface
  """
  @spec set_connectivity(String.t(), VintageNet.Interface.Classification.connection_status()) ::
          :ok
  def set_connectivity(ifname, connectivity) do
    RouteManager.set_connection_status(ifname, connectivity)
    PropertyTable.put(VintageNet, ["interface", ifname, "connection"], connectivity)
  end
end
