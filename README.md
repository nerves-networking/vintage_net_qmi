# VintageNetQMI

[![Hex version](https://img.shields.io/hexpm/v/vintage_net_qmi.svg "Hex version")](https://hex.pm/packages/vintage_net_qmi)
[![API docs](https://img.shields.io/hexpm/v/vintage_net_qmi.svg?label=hexdocs "API docs")](https://hexdocs.pm/vintage_net_qmi/VintageNetQMI.html)
[![CircleCI](https://circleci.com/gh/nerves-networking/vintage_net_qmi.svg?style=svg)](https://circleci.com/gh/nerves-networking/vintage_net_qmi)
[![Coverage Status](https://coveralls.io/repos/github/nerves-networking/vintage_net_qmi/badge.svg?branch=main)](https://coveralls.io/github/nerves-networking/vintage_net_qmi?branch=main)

This library provides a `VintageNet` technology for cellular modems that
support the Qualcomm MSM Interface. This includes most USB cellular modems.
See [`VintageNetMobile`](https://github.com/nerves-networking/vintage_net_mobile)
if you have a modem that only supports an `AT` command interface.

To use this library, first add it to your project's dependency list:

```elixir
def deps do
  [
    {:vintage_net_qmi, "~> 0.1.0"}
  ]
end
```

You will then need to configure `VintageNet`. The cellular modem should show
up on "wwan0", so configurations look like this:

```elixir
VintageNet.configure("wwan0", %{
      type: VintageNetQMI,
      vintage_net_qmi: %{
        service_providers: [%{apn: "fill_in"}]
      }
    })
```

The `:service_providers` key should be set to information provided by each of
your service providers. It is common that this is a list of one item.
Currently only one service provider is supported, so replace `"fill_in"` with
the APN that they gave you.

## VintageNet Properties

In addition to the common `vintage_net` properties for all interface types, this
technology the following:

| Property      | Values         | Description                   |
| ------------- | -------------- | ----------------------------- |
| `signal_asu`  | `0-31,99`      | Reported Arbitrary Strength Unit (ASU) |
| `signal_4bars` | `0-4`         | The signal level in "bars"    |
| `signal_dbm`  | `-144 - -44`   | The signal level in dBm. Interpretation depends on the connection technology. |
| `mcc`         | `0-999`        | Mobile Country Code for the network |
| `mnc`         | `0-999`        | Mobile Network Code for the network |

The following properties are TBD:

| Property      | Values         | Description                   |
| ------------- | -------------- | ----------------------------- |
| `network`     | string         | The network operator's name |
| `lac`         | `0-65533`      | The Location Area Code (lac) for the current cell |
| `cid`         | `0-268435455`  | The Cell ID (cid) for the current cell |
| `access_technology` | string   | The technology currently in use to connect to the network |
| `band`        | string         | The frequency band in use |
| `channel`     | integer        | An integer that indicates the channel that's in use |
| `iccid`       | string         | The Integrated Circuit Card Identifier (ICCID) |
| `imsi`        | string         | The International Mobile Subscriber Identity (IMSI) |

## System requirements

These requirements are believed to be the minimum needed to be added to the
official Nerves systems.

### Linux kernel

Enable QMI and drivers for your modem:

```text
CONFIG_USB_NET_CDC_NCM=m
CONFIG_USB_NET_HUAWEI_CDC_NCM=m
CONFIG_USB_NET_QMI_WWAN=m
CONFIG_USB_SERIAL_OPTION=m
```
