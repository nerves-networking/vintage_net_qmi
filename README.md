# VintageNetQMI

[![Hex version](https://img.shields.io/hexpm/v/vintage_net_qmi.svg "Hex version")](https://hex.pm/packages/vintage_net_qmi)
[![API docs](https://img.shields.io/hexpm/v/vintage_net_qmi.svg?label=hexdocs "API docs")](https://hexdocs.pm/vintage_net_qmi/VintageNetQMI.html)
[![CircleCI](https://dl.circleci.com/status-badge/img/gh/nerves-networking/vintage_net_qmi/tree/main.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/nerves-networking/vintage_net_qmi/tree/main)
[![REUSE status](https://api.reuse.software/badge/github.com/nerves-networking/vintage_net_qmi)](https://api.reuse.software/info/github.com/nerves-networking/vintage_net_qmi)

This library provides a `VintageNet` technology for cellular modems that
support the Qualcomm MSM Interface. This includes most USB cellular modems.
See [`VintageNetMobile`](https://github.com/nerves-networking/vintage_net_mobile)
if you have a modem that only supports an `AT` command interface.

To use this library, first add it to your project's dependency list:

```elixir
def deps do
  [
    {:vintage_net_qmi, "~> 0.3.2"}
  ]
end
```

You will then need to configure `VintageNet`. The easiest way to configure
a modem at runtime is by calling `VintageNetQMI.quick_configure("the_apn")`.
For example:

```elixir
iex> VintageNetQMI.quick_configure("the_apn")
:ok
# wait...
iex> VintageNet.info
Interface wwan0
  Type: VintageNetQMI
  Power: On (watchdog timeout in 51628 ms)
  Present: true
  State: :configured (0:41:09)
  Connection: :internet (0:40:28)
  Addresses: 100.79.205.206/30, fe80::723c:bdc9:10e4:d092/64
  Configuration:
    %{
      type: VintageNetQMI,
      vintage_net_qmi: %{service_providers: [%{apn: "the_apn"}]}
    }
```

You can't always call `quick_configure/1` convenience function so here's the
regular configuration. If you are moving code from `vintage_net_mobile`, you'll
notice that this format is very similar except that `Mobile` is now `QMI`.

```elixir
VintageNet.configure("wwan0", %{
      type: VintageNetQMI,
      vintage_net_qmi: %{
        service_providers: [%{apn: "the_apn"}]
      }
    })
```

The `:service_providers` key should be set to information provided by each of
your service providers. It is common that this is a list of one item.
Currently only one service provider is supported, so replace `"fill_in"` with
the APN that they gave you.

## Service provider APN selection via ICCID

If you're deploying SIMs from multiple service providers, you'll need to set
the APN based on what SIM was installed in the device. One way is to set
a configuration manually when you install the SIM. An easier way is to have
`VintageNetQMI` pick the APN based on the SIM's ICCID.

This featured is enabled by using the `:only_iccid_prefixes` option and listing
multiple service providers. `VintageNetQMI` looks at the `:service_providers`
list in order until one matches. Leave off the`:only_iccid_prefixes` option on
the final service provider to provide a catch-all APN.

Here's an example:

```elixir
VintageNet.configure("wwan0", %{
      type: VintageNetQMI,
      vintage_net_qmi: %{
        service_providers: [
          %{apn: "special_service_provider", only_iccid_prefixes: ["8973611", "8973612"]},
          %{apn: "default_apn"}
        ]
      }
    })
```

## Configure radio technologies

In some cases you might want to set to the radio access technology (RAT) to only
use a subset of what the modem is capable of using. To specify which RATs to use
you can set the optional configuration field `:only_radio_technologies`.

```elixir
VintageNet.configure("wwan0", %{
      type: VintageNetQMI,
      vintage_net_qmi: %{
        only_radio_technologies: [:lte, :umts],
        service_providers: [
          %{apn: "apn_name"}
        ]
      }
    })
```

The example above will limit the possible RATs used to `:lte` (4G) and `:umts`
(3G). For more information which radio technologies are available please see
the `:qmi` [documentation](https://hexdocs.pm/qmi/QMI.Codec.NetworkAccess.html#t:radio_interface/0).

If this configuration is provided, the modem will use the default configuration
that provided by the manufacturer.

## Configure roaming

Support for allowing roaming is set on a per-service provider basis using
the `:roaming_allowed?` key. In QMI, this field is optional and if unset here,
VintageNetQMI will not send any preference to the modem. The following
example shows a configuration where roaming is allowed:

```elixir
VintageNet.configure("wwan0", %{
      type: VintageNetQMI,
      vintage_net_qmi: %{
        only_radio_technologies: [:lte, :umts],
        service_providers: [
          %{apn: "apn_name", roaming_allowed?: true}
        ]
      }
    })
```

## VintageNet Properties

In addition to the common `vintage_net` properties for all interface types, this
technology the following:

| Property      | Values         | Description                   |
| ------------- | -------------- | ----------------------------- |
| `signal_asu`  | `0-31,99`      | Reported Arbitrary Strength Unit (ASU) |
| `signal_4bars` | `0-4`         | The signal level in "bars"    |
| `signal_dbm`  | `-144 - -44`   | The signal level in dBm. Interpretation depends on the connection technology. |
| `mcc`         | `0-999` | `nil`| Mobile Country Code for the network |
| `mnc`         | `0-999` | `nil`| Mobile Network Code for the network |
| `iccid`       | string         | The Integrated Circuit Card Identifier (ICCID) |
| `esn`         | string         | The Electronic Serial Number (ESN) |
| `imei`        | string         | International Mobile Equipment Identity (IMEI) |
| `meid`        | string         | The Mobile Equipment Identifier (MEID) |
| `imeisv_svn`  | string         | IMEI software version number |
| `provider`    | string | `nil` | The name of the service provider |
| `lac`         | `0-65533`      | The Location Area Code (lac) for the current cell |
| `cid`         | `0-268435455`  | The Cell ID (cid) for the current cell |
| `network_datetime` | `NaiveDateTime.t()` | The reported datetime from the network |
| `utc_offset`  | `Calendar.utc_offset()` | The UTC offset in seconds |
| `roaming`     | `boolean()`    | If the network is roaming or not |
| `std_offset`  | `Calendar.std_offset()` | The standard offset in seconds |
| `statistics`  | map            | Transmit and receive statistics (see below for details) |
| `access_technology` | atom     | The technology currently in use to connect to the network |
| `band`        | string         | The frequency band in use |
| `channel`     | integer        | An integer that indicates the channel that's in use |
| `manufacturer` | string        | The name of the manufacturer of the modem |
| `model`       | string         | The name of the model of the modem        |
| `apn`         | string         | The APN that VintageNetQMI configured the modem to use |
| `sim_rej_info`| atom           | The reason (if any) a SIM was rejected |

The following properties are TBD:

| Property      | Values         | Description                   |
| ------------- | -------------- | ----------------------------- |
| `imsi`        | string         | The International Mobile Subscriber Identity (IMSI) |

### Transmit and receive statistics

The `statistics` value is a map with the fields:

* `:timestamp` - the monotonic time for when these stats where last updated
* `:tx_bytes` - total bytes transmitted
* `:rx_bytes` - total bytes received
* `:tx_packets` - total packets transmitted without error
* `:rx_packets` - total packets received without error
* `:tx_errors` - total outgoing packets with framing errors
* `:rx_errors` - total incoming packets with framing errors
* `:tx_overflows` - total outing packets dropped due to buffer overflows
* `:rx_overflows` - total incoming packets dropped due to buffer overflows
* `:tx_drops` - total outgoing packets dropped
* `:rx_drops` - total incoming packets dropped

### Types of radio access technologies

* `:amps` - Advanced Mobile Phone System (legacy)
* `:gsm` - Global System for Mobile Communication (3G & 2G)
* `:umts` - Universal Mobile Telecommunications System (3G)
* `:lte` - Long-Term Evolution (4G)
* `:cdma_1x` - CDMA2000 1X (3G & 2G)
* `:cdma_1x_evdo` - CDMA2000 1xEV-DO (3G & 2G)

If you migrating from `VintageNetMobile` you will need to update any code that
uses this property to handle the above list of atoms.

## System requirements

These requirements are believed to be the minimum needed to be added to the
official Nerves systems.

### Linux kernel

Enable QMI and drivers for your modem:

```text
CONFIG_USB_USBNET=m
CONFIG_USB_NET_CDC_NCM=m
CONFIG_USB_NET_QMI_WWAN=m
CONFIG_USB_SERIAL_OPTION=m
```

If you're using a Huawei modem, you might also want:

```text
CONFIG_USB_NET_HUAWEI_CDC_NCM=m
```
