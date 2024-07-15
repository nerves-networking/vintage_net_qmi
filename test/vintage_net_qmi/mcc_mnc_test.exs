defmodule VintageNetQMI.MCCMNCTest do
  use ExUnit.Case, async: true
  alias VintageNetQMI.MCCMNC

  doctest MCCMNC

  describe "lookup_brand/2" do
    test "AT&T" do
      assert MCCMNC.lookup_brand("310", "410") == "AT&T"
    end

    test "T-Mobile" do
      assert MCCMNC.lookup_brand("310", "260") == "T-Mobile"
    end

    test "unknown MCC/MNC" do
      assert MCCMNC.lookup_brand("000", "000") == nil
    end
  end
end
