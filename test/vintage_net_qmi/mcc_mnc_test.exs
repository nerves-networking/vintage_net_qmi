defmodule VintageNetQMI.MCCMNCTest do
  use ExUnit.Case, async: true
  alias VintageNetQMI.MCCMNC

  doctest MCCMNC

  describe "lookup/2" do
    test "AT&T" do
      {:ok, info} = MCCMNC.lookup("310", "410")

      assert info == %{
               bands: "GSM 850 / GSM 1900 / UMTS 850 / UMTS 1900",
               brand: "AT&T",
               country: "United States of America",
               iso: "US",
               mcc: "310",
               mnc: "410",
               operator: "AT&T Mobility",
               plmn: "310410",
               region: "North America and the Caribbean",
               tadig: "USACG"
             }
    end

    test "T-Mobile" do
      {:ok, info} = MCCMNC.lookup("310", "260")

      assert info == %{
               bands:
                 "GSM 1900 / UMTS 1900 / UMTS 1700 / LTE 850 / LTE 700 / LTE 1900 / LTE 1700 / 5G 600",
               brand: "T-Mobile",
               country: "United States of America",
               iso: "US",
               mcc: "310",
               mnc: "260",
               operator: "T-Mobile USA",
               plmn: "310260",
               region: "North America and the Caribbean",
               tadig: "USAW6"
             }
    end

    test "unknown MCC/MNC" do
      assert :error = MCCMNC.lookup("000", "000")
    end
  end
end
