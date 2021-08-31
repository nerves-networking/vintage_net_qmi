# Changelog

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
