# SPDX-FileCopyrightText: 2022 Matt Ludwigs
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNetQMI.Connection.ConfigurationTest do
  use ExUnit.Case, async: true

  alias VintageNetQMI.Connection.Configuration

  setup do
    config = Configuration.new()

    {:ok, %{config: config}}
  end

  describe "running configuration function" do
    test "basic and ok", %{config: config} do
      {:ok, updated_config} = Configuration.run_configurations(config, fn _ -> :ok end)

      assert Configuration.completely_configured?(updated_config)
    end

    test "basic when a configuration errors", %{config: config} do
      config = Configuration.setting_configured(config, :reporting_connection_stats)

      {:error, _reason, :radio_technologies_set, updated_config} =
        Configuration.run_configurations(config, &bad_configure_callback/1)

      refute updated_config.radio_technologies_set
    end

    test "callback that is more than 1 arity", %{config: config} do
      {:ok, updated_config} =
        Configuration.run_configurations(config, &more_than_arity_callback(&1, :something_else))

      assert Configuration.completely_configured?(updated_config)
    end
  end

  describe "marking a setting configured" do
    test "reporting connection stats", %{config: config} do
      config = Configuration.setting_configured(config, :reporting_connection_stats)

      assert config.reporting_connection_stats == true
    end

    test "radio technologies set", %{config: config} do
      config = Configuration.setting_configured(config, :radio_technologies_set)

      assert config.radio_technologies_set == true
    end
  end

  describe "required setting are configured" do
    test "when they are not", %{config: config} do
      refute Configuration.required_configured?(config)
    end

    test "when they are", %{config: config} do
      updated_config = Configuration.setting_configured(config, :radio_technologies_set)

      assert Configuration.required_configured?(updated_config)
    end
  end

  describe "configuration completely configured" do
    test "when it's not", %{config: config} do
      setting_to_mark_configured =
        config
        |> Map.keys()
        |> Enum.random()

      updated_config = Configuration.setting_configured(config, setting_to_mark_configured)

      refute Configuration.completely_configured?(updated_config)
    end

    test "when it is", %{config: config} do
      {:ok, updated_config} = Configuration.run_configurations(config, fn _ -> :ok end)

      assert Configuration.completely_configured?(updated_config)
    end
  end

  defp bad_configure_callback(:radio_technologies_set) do
    {:error, :did_not_work}
  end

  defp more_than_arity_callback(_setting, _something_else) do
    :ok
  end
end
