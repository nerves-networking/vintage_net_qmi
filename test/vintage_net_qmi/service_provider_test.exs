defmodule VintageNetQMI.ServiceProviderTest do
  use ExUnit.Case, async: true

  alias VintageNetQMI.ServiceProvider

  describe "Selecting provider for a service provider based off ICCID" do
    test "when no prefixes are provided" do
      provider = %{apn: "fake"}
      iccid = "891004234814455936F"

      assert provider == ServiceProvider.select_provider_by_iccid([provider], iccid)
    end

    test "when prefix option matches the ICCID prefixes" do
      providers = [
        %{apn: "first one", only_iccid_prefixes: ["8910042"]},
        %{apn: "second one", only_iccid_prefixes: ["891114", "898823"]}
      ]

      first_iccid = "891004234814455936F"
      second_iccid = "898823454545458F651"

      [first_provider, second_provider | _] = providers

      assert first_provider == ServiceProvider.select_provider_by_iccid(providers, first_iccid)
      assert second_provider == ServiceProvider.select_provider_by_iccid(providers, second_iccid)
    end

    test "when prefix option does not match ICCID prefix" do
      provider = %{apn: "not me", only_iccid_prefixes: ["89171717"]}
      iccid = "891004234814455936F"

      assert nil ==
               ServiceProvider.select_provider_by_iccid([provider], iccid)
    end

    test "when no prefixes are provided first" do
      providers = [
        %{apn: "not me"},
        %{apn: "this one", only_iccid_prefixes: ["89171717"]}
      ]

      iccid = "8917171711111111FF"

      [_, this_one | _] = providers

      assert this_one == ServiceProvider.select_provider_by_iccid(providers, iccid)
    end

    test "default to service provider with out ICCID selection when non match" do
      providers = [
        %{apn: "this one"},
        %{apn: "not me", only_iccid_prefixes: ["89171717"]}
      ]

      iccid = "8947571711111111FF"

      assert List.first(providers) == ServiceProvider.select_provider_by_iccid(providers, iccid)
    end
  end
end
