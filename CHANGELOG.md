# Changelog

## [v0.3.3] - 2023-01-23

### Changed

* Allow `:vintage_net` `v0.13.0` to be used
* Add some more information when QMI reports no internet

## [v0.3.2] - 2022-05-02

### Changed

* `:vintage_net` `v0.12.0` and up is now required

## [v0.3.1] - 2022-04-27

### Added

* Add support for `:roaming_allowed?` field in a service provider configuration
  to allow or disallow roaming when using the configured service provider.

## [v0.3.0] - 2022-02-10

There was a fix that changed the property reported in the property table from
`"manufacture"` to `"manufacturer"`. To upgrade you will want to change any
code that this is subscribe to this property to have the correct spelling.

### Added

* Add support to configure which radio technologies you want the modem to use

### Fixes

* References to manufacturer
* Infinite retrying to establish connection after the connection has been
  established
* Report selected APN before connection attempt

## [v0.2.14] - 2022-1-13

### Added

* Show the configured APN in the property table

## [v0.2.13] - 2022-1-4

### Added

* Allow APN selection based off ICCID when deploying SIMs from multiple service
  providers

## [v0.2.12] - 2021-12-20

### Added

* Property named `"manufacturer"` for the manufacturer name of the modem
* Property named `"model"` for the product name of the modem

## [v0.2.11] - 2021-11-18

### Fixes

- When there is no signal VintageNetQMI would report 1 bar of signal rather than
  0 bars

## [v0.2.10] - 2021-11-17

### Changes

- Power manager timer was petting the watch dog every 60 miliseconds, now it
  will pet the watch dog every 30 seconds.
- Ignore sync indications from QMI so they are not logged.

### Fixes

- A crash that happened when the interface would stop but there was no IP
  address on the interface.
- Internet connectivity checker being enabled when it should not have been

## [v0.2.9] - 2021-09-21

### Added

* Property named `"statistics"` that contains a map of transmit and receive
  stats. The fields are:
  * `:timestamp` - monotonic time for when the stats were last updated
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
* Property `"band"` for the frequency band being used by the radio interface
* Property `"channel"` for the channel being used by the radio interface
* Property `"access_technology"` for the radio interface that is active

## v0.2.8

* Added
  * Location and time properties:
    * `lac` - The Location Area Code (lac) for the current cell
    * `cid` - The Cell ID (cid) for the current cell
    * `network_datetime` - The reported datetime from the network
    * `utc_offset` - The UTC offset in seconds
    * `roaming` - If the network is roaming or not
    * `std_offset` - The standard offset in seconds

## v0.2.7

* Added
  * Support `VintageNet` v0.11.x
  * Serial number properties:
    * `esn` - Electronic Serial Number (ESN)
    * `imei` - International Mobile Equipment Identity (IMEI)
    * `meid` - Mobile Equipment Identifier (MEID)
    * `imeisv_svn` - IMEI software version number
  * The `provider` property to get the service provider name

* Fixes
  * When packet data connection is disconnected set the connection status to
    `:disconnected`
  * Check connectivity status to know if the modem should power cycle

## v0.2.6

* Fixes
  * Fix lease renewal ending in stuck lan connectivity

## v0.2.5

* Updates
  * Support `qmi` v0.6.0

## v0.2.4

* Improvements
  * Support `iccid` property

* Updates
  * Support `qmi` v0.5.1

## v0.2.3

* Fixes
  * `VintageNetQMI.quick_configure/1` updated to use the passed in argument
    for the APN instead of always using hardcoded `"apn"` value

## v0.2.2

* Improvements
  * Add `VintageNetQMI.quick_configure/1` to easily configure `VintageNet` at
    runtime.

* Updates
  * Support `vintage_net` v0.10.2
  * Better handling of connection status

## v0.2.1

* Updates
  * Set connection based on QMI notifications

## v0.2.0

* Updates
  * Change configuration to match VintageNetMobile (backwards incompatible)
  * Don't require IPv4 configuration

## v0.1.3

* Updates
  * Support `qmi` v0.3.1

* Fixes
  * Connection code blocking supervision initialization

## v0.1.2

* Updates
  * Support `qmi` v0.2.0

## v0.1.1

* Updates
  * Support vintage_net v0.10.0

## v0.1.0

Initial Release

[v0.3.3]: https://github.com/nerves-networking/vintage_net_qmi/compare/v0.3.2...v0.3.3
[v0.3.2]: https://github.com/nerves-networking/vintage_net_qmi/compare/v0.3.1...v0.3.2
[v0.3.1]: https://github.com/nerves-networking/vintage_net_qmi/compare/v0.3.0...v0.3.1
[v0.3.0]: https://github.com/nerves-networking/vintage_net_qmi/compare/v0.2.14...v0.3.0
[v0.2.14]: https://github.com/nerves-networking/vintage_net_qmi/compare/v0.2.13...v0.2.14
[v0.2.13]: https://github.com/nerves-networking/vintage_net_qmi/compare/v0.2.12...v0.2.13
[v0.2.12]: https://github.com/nerves-networking/vintage_net_qmi/compare/v0.2.11...v0.2.12
[v0.2.11]: https://github.com/nerves-networking/vintage_net_qmi/compare/v0.2.10...v0.2.11
[v0.2.10]: https://github.com/nerves-networking/vintage_net_qmi/compare/v0.2.9...v0.2.10
[v0.2.9]: https://github.com/nerves-networking/vintage_net_qmi/compare/v0.2.8...v0.2.9
