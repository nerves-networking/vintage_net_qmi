# SPDX-FileCopyrightText: 2021 Frank Hunleth
# SPDX-FileCopyrightText: 2021 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNetQMI.CookbookTest do
  use ExUnit.Case

  alias VintageNetQMI.Cookbook

  test "simple/1" do
    assert {:ok, %{type: VintageNetQMI, vintage_net_qmi: %{service_providers: [%{apn: "super"}]}}} ==
             Cookbook.simple("super")
  end
end
