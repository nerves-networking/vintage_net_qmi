# SPDX-FileCopyrightText: 2021 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNetQMI.ASUCalculatorTest do
  use ExUnit.Case
  alias VintageNetQMI.ASUCalculator

  test "computes gsm dbm" do
    assert ASUCalculator.from_gsm_asu(2).dbm == -109
    assert ASUCalculator.from_gsm_asu(9).dbm == -95
    assert ASUCalculator.from_gsm_asu(15).dbm == -83
    assert ASUCalculator.from_gsm_asu(30).dbm == -53

    assert ASUCalculator.from_gsm_asu(99).dbm == -113

    # Bad values
    assert ASUCalculator.from_gsm_asu(-100).dbm == -113
    assert ASUCalculator.from_gsm_asu(31).dbm == -53
  end

  test "computes gsm bars" do
    assert ASUCalculator.from_gsm_asu(2).bars == 1
    assert ASUCalculator.from_gsm_asu(9).bars == 1
    assert ASUCalculator.from_gsm_asu(14).bars == 2
    assert ASUCalculator.from_gsm_asu(15).bars == 3
    assert ASUCalculator.from_gsm_asu(30).bars == 4
    assert ASUCalculator.from_gsm_asu(99).bars == 0
  end

  test "computes lte asu" do
    # The calculator only supports values 0-31 and 99, so
    # check that it doesn't return anything out of range.
    assert ASUCalculator.from_lte_rssi(-200).asu == 99
    assert ASUCalculator.from_lte_rssi(-113).asu == 99
    assert ASUCalculator.from_lte_rssi(-112).asu == 0
    assert ASUCalculator.from_lte_rssi(-52).asu == 30
    assert ASUCalculator.from_lte_rssi(-49).asu == 31
    assert ASUCalculator.from_lte_rssi(0).asu == 31
  end

  test "computes lte bars" do
    assert ASUCalculator.from_lte_rssi(-64).bars == 4
    assert ASUCalculator.from_lte_rssi(-74).bars == 3
    assert ASUCalculator.from_lte_rssi(-84).bars == 2
    assert ASUCalculator.from_lte_rssi(-112).bars == 1
    assert ASUCalculator.from_lte_rssi(-113).bars == 0
  end
end
