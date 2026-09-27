# Network Service

`Network.qml` is N0ctOS's centralized network and connectivity service.

It gives every shell component one consistent place to read backend state, Wi-Fi state, connectivity state, devices, Wi-Fi networks, active connections, signal strength, and icons, and to control Wi-Fi, scanning, connections, devices, and connectivity checks without touching Quickshell's `Networking` API directly.

The service supports backend detection, Wi-Fi enable/hardware/available state, network-side airplane mode, connectivity states, raw and filtered device models, flattened Wi-Fi and connected-network models, active Wi-Fi/wired/network selection, signal normalization, Nerd Font icons, freedesktop icon keys, lookups, serialization helpers, hotplug signals, and a full IPC interface.

The normal usage pattern is:

```text
Component
    │
    ▼
Network
    │
    ├── backend state
    ├── Wi-Fi + connectivity state
    ├── device / network models
    └── resolved text + icons
    │
    ▼
Quickshell Networking
    │
    ▼
NetworkManager / system network hardware
```

---

# 1. What does it do?

`Network.qml` exposes the current network state for the shell.

A component can read a simple value:

```qml
Network.statusText
```

or a simple state flag:

```qml
Network.isNetworkConnected
```

or a ready-made icon:

```qml
Network.icon
```

More detailed state is also available:

```json
{
    "isNetworkConnected": true,
    "isInternetAvailable": true,
    "connectivity": "Full",
    "activeNetwork": "HomeWifi",
    "activeWifiSignal": 72,
    "activeConnectionType": "wifi",
    "icon": "󰤥"
}
```

The effective status text is resolved in this order:

```text
activeNetworkName (e.g. "HomeWifi")
    ↓
connectivityName (when connected but unnamed)
    ↓
"Disconnected"
```

So a component can simply do:

```qml
Text {
    text:
        Network.statusText
}
```

and not care where the value came from.

If no network hardware or connection exists, the service returns safe fallbacks (`""`, `0`, `false`, `null`, `"Disconnected"`, `"network-off"`) instead of failing.

---

# 2. UI API

Import normally:

```qml
import QtQuick
import Quickshell

import qs.services
```

## Core API

| How to read | What does it do |
| ----------- | --------------- |
| `Network.isAvailable` | `true` when `Networking.backend !== NetworkBackendType.None`. |
| `Network.backend` | Raw `Networking.backend` enum value. |
| `Network.backendName` | `NetworkBackendType.toString(backend)`, e.g. `"NetworkManager"`. |
| `Network.isWifiSupported` | `true` when at least one Wi-Fi device exists. |
| `Network.isWifiEnabled` | `Networking.wifiEnabled`. |
| `Network.isWifiHardwareEnabled` | `Networking.wifiHardwareEnabled`. |
| `Network.isWifiAvailable` | Supported and software- and hardware-enabled. |
| `Network.isAirplaneMode` | Supported and Wi-Fi software-disabled. Network-side only; Bluetooth is untouched. |
| `Network.canCheckConnectivity` | `Networking.canCheckConnectivity`. |
| `Network.isConnectivityCheckEnabled` | `Networking.connectivityCheckEnabled`. |
| `Network.connectivity` | Raw `Networking.connectivity` enum value. |
| `Network.connectivityName` | `NetworkConnectivity.toString(connectivity)`, e.g. `"Full"`. |
| `Network.isConnectivityKnown` | `true` when `connectivity !== NetworkConnectivity.Unknown`. |
| `Network.isNetworkConnected` | `true` when `connectedDeviceCount > 0`. |
| `Network.isInternetAvailable` | `true` when `connectivity === NetworkConnectivity.Full`. |
| `Network.isCaptivePortal` | `true` when `connectivity === NetworkConnectivity.Portal`. |
| `Network.isLimitedConnectivity` | `true` when `connectivity === NetworkConnectivity.Limited`. |
| `Network.devices` | Raw `Networking.devices` `ObjectModel`, usable directly as `model: Network.devices`. |
| `Network.deviceList` | Plain JS array of `Networking.devices.values`. |
| `Network.deviceCount` | Number of devices. |
| `Network.wifiDevices` | `ScriptModel` of Wi-Fi devices for `ListView`. |
| `Network.wifiDeviceList` | Plain JS array of Wi-Fi devices. |
| `Network.wifiDeviceCount` | Number of Wi-Fi devices. |
| `Network.wiredDevices` | `ScriptModel` of wired devices for `ListView`. |
| `Network.wiredDeviceList` | Plain JS array of wired devices. |
| `Network.wiredDeviceCount` | Number of wired devices. |
| `Network.connectedDevices` | `ScriptModel` of connected devices for `ListView`. |
| `Network.connectedDeviceList` | Plain JS array of connected devices. |
| `Network.connectedDeviceCount` | Number of connected devices. |
| `Network.wifiNetworks` | `ScriptModel` of flattened Wi-Fi networks for `ListView`. Native `WifiNetwork` objects. |
| `Network.wifiNetworkList` | Plain JS array of flattened Wi-Fi networks. |
| `Network.wifiNetworkCount` | Number of visible Wi-Fi networks. |
| `Network.connectedNetworks` | `ScriptModel` of connected networks for `ListView`. |
| `Network.connectedNetworkList` | Plain JS array of connected networks. |
| `Network.connectedNetworkCount` | Number of connected networks. |
| `Network.activeWifiNetwork` | First connected Wi-Fi network, or `null`. |
| `Network.activeWifiName` | SSID of `activeWifiNetwork`, or `""`. |
| `Network.activeWifiSignal` | Signal 0 -> 100 from `activeWifiNetwork`, or `0`. |
| `Network.activeWifiSignalRounded` | `Math.round(activeWifiSignal)`. |
| `Network.activeWifiSignalText` | `"72%"` style text, or `""` when no active Wi-Fi network. |
| `Network.activeWiredDevice` | First connected wired device, or `null`. |
| `Network.activeWiredName` | Name of `activeWiredDevice`, or `""`. |
| `Network.activeWiredLinkSpeed` | `linkSpeed` when the active wired device has link, otherwise `0`. |
| `Network.activeNetwork` | Primary connected network following NetworkManager device ordering, or `null`. |
| `Network.activeNetworkName` | Name of `activeNetwork`, or `""`. |
| `Network.isWifiActive` | `true` when `activeWifiNetwork` exists. |
| `Network.isWiredActive` | `true` when `activeWiredDevice` exists and is connected. |
| `Network.activeConnectionType` | `"wifi"`, `"ethernet"`, `"none"`, or `"unknown"`. |
| `Network.statusText` | `activeNetworkName`, else `connectivityName` when connected, else `"Disconnected"`. |
| `Network.icon` | Nerd Font glyph for the current state. |
| `Network.iconKey` | Freedesktop icon name (`wifi-3`, `ethernet`, `airplane-mode`, `network-off`, etc.). |
| `Network.isScanning` | `true` when any Wi-Fi device has `scannerEnabled`. |

## Helpers and signals

| How to call | What does it do |
| ----------- | --------------- |
| `Network.setWifiEnabled(enabled)` | Sets `Networking.wifiEnabled` to `Boolean(enabled)`. |
| `Network.setAirplaneMode(enabled)` | Network-side airplane mode: disables Wi-Fi when `true`, enables it when `false`. Bluetooth is untouched. |
| `Network.scan()` | Enables `scannerEnabled` on every Wi-Fi device. No-op when Wi-Fi is unsupported, hardware-disabled, or software-disabled. |
| `Network.setConnectivityCheckEnabled(enabled)` | Sets `Networking.connectivityCheckEnabled`. No-op when `canCheckConnectivity` is `false`. |
| `Network.checkConnectivity()` | Calls `Networking.checkConnectivity()`. No-op when `canCheckConnectivity` is `false`. |
| `Network.connectNetwork(name)` | Finds the network by SSID and calls `connect()`. No-op when not found. |
| `Network.connectNetworkWithPsk(name, psk)` | Finds the network by SSID and calls `connectWithPsk(String(psk))` when that function exists. No-op when not found or unsupported. |
| `Network.disconnectNetwork(name)` | Finds the network by SSID and calls `disconnect()`. No-op when not found. |
| `Network.forgetNetwork(name)` | Finds the network by SSID and calls `forget()`. No-op when not found. |
| `Network.disconnectDevice(name)` | Finds the device by name and calls `disconnect()`. No-op when not found. |
| `Network.setDeviceAutoconnect(name, enabled)` | Finds the device by name and sets `autoconnect`. No-op when not found. |
| `Network.setDeviceManaged(name, managed)` | Finds the device by name and sets `nmManaged` when that property exists. No-op when not found or unsupported. |
| `Network.findDevice(name)` | Returns the device whose `name` matches exactly, or `null`. |
| `Network.findNetwork(name)` | Prefers a connected Wi-Fi match, then the first SSID match, then a wired `device.network` match. Returns `null` when nothing matches. |
| `Network.findActiveWifiNetwork()` | Returns the first connected Wi-Fi network, or `null`. |
| `Network.findActiveWiredDevice()` | Returns the first connected wired device, or `null`. |
| `Network.findActiveNetwork()` | Returns the primary connected network following NetworkManager device ordering, or `null`. |
| `Network.getActiveConnectionType()` | Returns `"none"`, `"unknown"`, `"wifi"`, or `"ethernet"` for `activeNetwork`. |
| `Network.collectWifiNetworks()` | Flattens every Wi-Fi device's networks into one deduplicated array. |
| `Network.collectConnectedNetworks()` | Collects connected Wi-Fi networks plus connected wired `device.network` objects into one deduplicated array. |
| `Network.signalPercent(network)` | `signalStrength * 100`, clamped 0 -> 100. `0` when null or non-finite. |
| `Network.signalBucket(network)` | Maps signal to `4, 3, 2, 1, 0` at thresholds `75 / 50 / 25 / >0`. |
| `Network.wifiIcon(signalPercent, connected, disabled)` | Returns the Nerd Font glyph for the given signal and state. |
| `Network.iconForNetwork(network)` | Returns the Nerd Font glyph for one network. `"󰤯"` when null, `"󰈀"` for wired. |
| `Network.iconKeyForNetwork(network)` | Returns the freedesktop icon name for one network. `"network-off"` when null, `"ethernet"` for wired, `"wifi-off"` / `"wifi-1..4"` for Wi-Fi. |
| `Network.iconForState()` | Returns the current shell glyph: airplane, active Wi-Fi, active wired, or disconnected. |
| `Network.iconKeyForState()` | Returns the current shell icon key: `airplane-mode`, `wifi-1..4` / `wifi-off`, `ethernet`, or `network-off`. |
| `Network.hasProperty(object, propertyName)` | `false` when null, otherwise `propertyName in object`. |
| `Network.securityName(network)` | `WifiSecurityType.toString(network.security)`, or `""` when null/unsupported. |
| `Network.stateName(object)` | `ConnectionState.toString(object.state)`, or `"Unknown"` when null/unsupported. |
| `Network.networkInfo(network)` | Returns a plain info object for one network, `{}` when null. |
| `Network.deviceInfo(device)` | Returns a plain info object for one device, `{}` when null. |
| `Network.statusInfo()` | Returns the full normalized status as a plain object. |
| `Network.deviceAdded(device)` | Signal emitted when a `Networking.devices` object is inserted. |
| `Network.deviceRemoved(device)` | Signal emitted when a `Networking.devices` object is removed. |
| `Network.networkListUpdated()` | Signal emitted when the device topology changes. |
| `Network.stateChangedExternally()` | Signal emitted when Wi-Fi, hardware, connectivity, or topology changes. |

| Example | Result |
| ------- | ------ |
| `Network.wifiIcon(72, true, false)` | `"󰤥"` |
| `Network.wifiIcon(72, true, true)` | `"󰤭"` (disabled takes precedence) |
| `Network.wifiIcon(10, false, false)` | `"󰤟"` |
| `Network.findDevice("wlan0")` | matching device object, or `null` when no match |
| `Network.findNetwork("HomeWifi")` | matching network object (connected match preferred), or `null` when no match |
| `Network.connectNetworkWithPsk("HomeWifi", "secret123")` | starts a PSK connection, no return value; no-op when not found or unsupported |
| `Network.setDeviceAutoconnect("wlan0", false)` | sets `autoconnect` to `false`, no return value; no-op when not found |
| `Network.networkInfo(null)` | `{}` |
| `Network.deviceInfo(null)` | `{}` |
| `Network.stateName(null)` | `"Unknown"` |

### Typical component usage

```qml
Text {
    text:
        Network.statusText
}

Text {
    visible:
        Network.isWifiActive

    text:
        Network.activeWifiName +
        " " +
        Network.activeWifiSignalText
}

Text {
    text:
        Network.icon
}
```

That is the intended everyday usage.

Components normally should not need to know how `Networking.devices`, flattened Wi-Fi networks, device ordering, buckets, or NetworkManager state work.

---

# 3. IPC API

IPC target:

```text
n0ctos-network
```

## Status

| How to call | What does it do |
| ----------- | --------------- |
| `getStatus` | Returns the full normalized status as a JSON string. |
| `getIcon` | Returns the current Nerd Font icon glyph. |
| `getState` | Returns `statusText`, e.g. `"HomeWifi"` or `"Disconnected"`. |
| `getConnectivity` | Returns `connectivityName`, e.g. `"Full"`. |

| Example | Result |
| ------- | ------ |
| `qs ipc call n0ctos-network getStatus` | JSON status object (see below) |
| `qs ipc call n0ctos-network getIcon` | Nerd Font glyph for the current state |
| `qs ipc call n0ctos-network getState` | `"HomeWifi"`, or `"Disconnected"` when offline |
| `qs ipc call n0ctos-network getConnectivity` | `"Full"`, `"Limited"`, `"Portal"`, `"Unknown"`, etc. |

For example:

```bash
qs ipc call n0ctos-network getState
```

returns:

```text
HomeWifi
```

or when offline:

```text
Disconnected
```

```bash
qs ipc call n0ctos-network getConnectivity
```

returns:

```text
Full
```

```bash
qs ipc call n0ctos-network getIcon
```

returns the current glyph, for example:

```text
󰤥
```

`getStatus` returns:

```json
{
    "isAvailable": true,
    "backend": "NetworkManager",
    "isNetworkConnected": true,
    "isInternetAvailable": true,
    "isCaptivePortal": false,
    "isLimitedConnectivity": false,
    "connectivity": "Full",
    "isWifiSupported": true,
    "isWifiEnabled": true,
    "isWifiHardwareEnabled": true,
    "isWifiAvailable": true,
    "isAirplaneMode": false,
    "wifiDeviceCount": 1,
    "wiredDeviceCount": 1,
    "deviceCount": 2,
    "connectedDeviceCount": 1,
    "wifiNetworkCount": 8,
    "connectedNetworkCount": 1,
    "isWifiActive": true,
    "isWiredActive": false,
    "activeConnectionType": "wifi",
    "activeNetwork": "HomeWifi",
    "activeWifi": "HomeWifi",
    "activeWifiSignal": 72,
    "activeWired": "",
    "activeWiredLinkSpeed": 0,
    "statusText": "HomeWifi",
    "icon": "󰤥",
    "iconKey": "wifi-3"
}
```

## Wi-Fi control

| How to call | What does it do |
| ----------- | --------------- |
| `getWifiEnabled` | Returns `"true"` / `"false"` for `isWifiEnabled`. |
| `setWifiEnabled <true\|false>` | Enables or disables Wi-Fi. |
| `toggleWifi` | Enables Wi-Fi when disabled, disables it when enabled. |
| `getAirplaneMode` | Returns `"true"` / `"false"` for `isAirplaneMode`. |
| `setAirplaneMode <true\|false>` | Network-side airplane mode: `true` disables Wi-Fi, `false` enables it. |

| Example | Result |
| ------- | ------ |
| `qs ipc call n0ctos-network getWifiEnabled` | `"true"` or `"false"` |
| `qs ipc call n0ctos-network setWifiEnabled false` | disables Wi-Fi, no return value |
| `qs ipc call n0ctos-network toggleWifi` | flips Wi-Fi state, no return value |
| `qs ipc call n0ctos-network getAirplaneMode` | `"true"` or `"false"` |
| `qs ipc call n0ctos-network setAirplaneMode true` | disables Wi-Fi, no return value |

For example:

```bash
qs ipc call n0ctos-network getWifiEnabled
```

returns:

```text
true
```

```bash
qs ipc call n0ctos-network setWifiEnabled false
```

disables the Wi-Fi radio.

```bash
qs ipc call n0ctos-network toggleWifi
```

flips the current Wi-Fi state.

```bash
qs ipc call n0ctos-network setAirplaneMode true
```

enables network-side airplane mode by disabling Wi-Fi.

## Scanning

| How to call | What does it do |
| ----------- | --------------- |
| `scan` | Enables `scannerEnabled` on every Wi-Fi device. No-op when Wi-Fi is unavailable. |
| `isScanning` | Returns `"true"` / `"false"` for `isScanning`. |

| Example | Result |
| ------- | ------ |
| `qs ipc call n0ctos-network scan` | starts a scan, no return value; no-op when Wi-Fi is unavailable |
| `qs ipc call n0ctos-network isScanning` | `"true"` or `"false"` |

For example:

```bash
qs ipc call n0ctos-network scan
```

```bash
qs ipc call n0ctos-network isScanning
```

returns:

```text
false
```

when no scanner is active.

## Network connection

| How to call | What does it do |
| ----------- | --------------- |
| `connect <name>` | Connects to the network with the given SSID. No-op when not found. |
| `connectPsk <name> <psk>` | Connects with a pre-shared key. No-op when not found or unsupported. |
| `disconnect <name>` | Disconnects the network with the given SSID. No-op when not found. |
| `forget <name>` | Forgets the network with the given SSID. No-op when not found. |

| Example | Result |
| ------- | ------ |
| `qs ipc call n0ctos-network connect HomeWifi` | starts a connection, no return value; no-op when not found |
| `qs ipc call n0ctos-network connectPsk HomeWifi secret123` | starts a PSK connection, no return value; no-op when not found or unsupported |
| `qs ipc call n0ctos-network disconnect HomeWifi` | disconnects the network, no return value; no-op when not found |
| `qs ipc call n0ctos-network forget HomeWifi` | forgets the network, no return value; no-op when not found |

For example:

```bash
qs ipc call n0ctos-network connect HomeWifi
```

```bash
qs ipc call n0ctos-network connectPsk HomeWifi secret123
```

```bash
qs ipc call n0ctos-network disconnect HomeWifi
```

```bash
qs ipc call n0ctos-network forget HomeWifi
```

## Device control

| How to call | What does it do |
| ----------- | --------------- |
| `disconnectDevice <name>` | Disconnects the device with the given name. No-op when not found. |
| `setAutoconnect <name> <true\|false>` | Sets `autoconnect` on the device. No-op when not found. |
| `setManaged <name> <true\|false>` | Sets `nmManaged` when that property exists. No-op when not found or unsupported. |

| Example | Result |
| ------- | ------ |
| `qs ipc call n0ctos-network disconnectDevice wlan0` | disconnects the device, no return value; no-op when not found |
| `qs ipc call n0ctos-network setAutoconnect wlan0 false` | sets `autoconnect` to `false`, no return value; no-op when not found |
| `qs ipc call n0ctos-network setManaged wlan0 true` | sets `nmManaged` to `true`, no return value; no-op when not found or unsupported |

For example:

```bash
qs ipc call n0ctos-network disconnectDevice wlan0
```

```bash
qs ipc call n0ctos-network setAutoconnect wlan0 false
```

```bash
qs ipc call n0ctos-network setManaged wlan0 true
```

## Connectivity check

| How to call | What does it do |
| ----------- | --------------- |
| `checkConnectivity` | Calls `Networking.checkConnectivity()`. No-op when checking is unsupported. |
| `setConnectivityCheck <true\|false>` | Enables or disables periodic connectivity checking. No-op when unsupported. |

| Example | Result |
| ------- | ------ |
| `qs ipc call n0ctos-network checkConnectivity` | triggers one connectivity check, no return value; no-op when unsupported |
| `qs ipc call n0ctos-network setConnectivityCheck true` | enables connectivity checking, no return value; no-op when unsupported |

For example:

```bash
qs ipc call n0ctos-network checkConnectivity
```

```bash
qs ipc call n0ctos-network setConnectivityCheck true
```

## Data

| How to call | What does it do |
| ----------- | --------------- |
| `getDevices` | Returns one info object per device as a JSON string. |
| `getWifiNetworks` | Returns one info object per visible Wi-Fi network as a JSON string. |
| `getConnectedNetworks` | Returns one info object per connected network as a JSON string. |

| Example | Result |
| ------- | ------ |
| `qs ipc call n0ctos-network getDevices` | JSON array with one info object per device |
| `qs ipc call n0ctos-network getWifiNetworks` | JSON array with one info object per visible Wi-Fi network |
| `qs ipc call n0ctos-network getConnectedNetworks` | JSON array with one info object per connected network |

`getWifiNetworks` returns:

```json
[
    {
        "name": "HomeWifi",
        "connected": true,
        "known": true,
        "state": "Activated",
        "stateChanging": false,
        "isWifi": true,
        "deviceName": "wlan0",
        "signal": 72,
        "security": "Wpa2",
        "icon": "󰤥",
        "iconKey": "wifi-3",
        "nmSettings": [
            {
                "id": "HomeWifi",
                "uuid": "00000000-0000-0000-0000-000000000000"
            }
        ]
    }
]
```

`getDevices` returns:

```json
[
    {
        "name": "wlan0",
        "address": "AA:BB:CC:DD:EE:FF",
        "type": "Wifi",
        "isWifi": true,
        "isWired": false,
        "isConnected": true,
        "state": "Activated",
        "isAutoconnect": true,
        "isNmManaged": true,
        "icon": "󰤥",
        "iconKey": "wifi-3",
        "networks": [],
        "scannerEnabled": true,
        "scanning": true
    }
]
```

When no hardware exists, `getDevices` returns:

```json
[]
```

and `getConnectedNetworks` returns:

```json
[]
```

---

# 4. Features / limitations

## Features

### Backend detection

Backend state comes from:

```text
Networking.backend
```

and is exposed as:

```text
isAvailable = backend !== None
backendName = NetworkBackendType.toString(backend)
```

This gives panels a stable way to hide network UI when no backend exists.

### Wi-Fi enable, hardware, and availability

Three flags are kept separate:

```text
isWifiSupported        -> wifiDeviceList.length > 0
isWifiEnabled          -> Networking.wifiEnabled
isWifiHardwareEnabled  -> Networking.wifiHardwareEnabled
```

Availability combines them:

```text
supported
    +
enabled
    +
hardware-enabled
    ↓
isWifiAvailable
```

Components can therefore distinguish "no Wi-Fi card", "Wi-Fi turned off", and "Wi-Fi blocked by hardware switch".

### Network-side airplane mode

Airplane mode maps to NetworkManager's wireless radio state:

```text
supported && !enabled
    ↓
isAirplaneMode
```

Bluetooth is intentionally not controlled here. Bluetooth has its own service and remains independently managed.

### Connectivity states

Connectivity comes from:

```text
Networking.connectivity
```

and is exposed both raw and normalized:

```text
Full    -> isInternetAvailable
Portal  -> isCaptivePortal
Limited -> isLimitedConnectivity
Unknown -> !isConnectivityKnown
```

`isNetworkConnected` is separate and means:

```text
connectedDeviceCount > 0
```

so a link-local connection and full internet access are not confused.

### Raw device model passthrough

Quickshell exposes:

```text
Networking.devices as ObjectModel
```

The service keeps that model intact:

```qml
model:
    Network.devices
```

No conversion is forced on consumers that already know how to use native devices.

### Filtered ScriptModels

Raw devices are also exposed filtered:

```text
deviceList
    ↓
wifiDeviceList (type === Wifi)
wiredDeviceList (type === Wired)
connectedDeviceList (connected)
```

and each filter is exposed twice:

```text
wifiDevices      -> ScriptModel for ListView
wifiDeviceList   -> plain JS array for loops
wifiDeviceCount  -> array length
```

The same triple exists for wired, connected-device, Wi-Fi-network, and connected-network models.

### Flattened Wi-Fi networks

Each Wi-Fi device owns its own network `ObjectModel`. The service flattens them:

```text
wifiDeviceList[].networks.values
    ↓
deduplicated array
    ↓
wifiNetworks / wifiNetworkList / wifiNetworkCount
```

The actual objects remain native Quickshell `WifiNetwork` objects.

### Connected networks

Connected networks include both transports:

```text
connected Wi-Fi networks
    +
connected wired device.network objects
    ↓
connectedNetworks / connectedNetworkList
```

### Active selection by device order

`activeNetwork` prefers NetworkManager device ordering:

```text
deviceList in order
    ↓
first connected device
    ↓
its connected Wi-Fi network or wired device.network
```

This avoids pretending that N0ctOS knows routing priority when Quickshell does not expose the default route.

Dedicated helpers also exist:

```text
activeWifiNetwork -> first connected Wi-Fi network
activeWiredDevice -> first connected wired device
```

### Signal normalization

Quickshell exposes:

```text
WifiNetwork.signalStrength: 0.0 -> 1.0
```

The service exposes:

```text
activeWifiSignal: 0 -> 100
```

The conversion is:

```text
Number(signalStrength) * 100
    ↓
clamp 0 -> 100
    ↓
signal
    ↓
round -> activeWifiSignalRounded
    ↓
String + "%" -> activeWifiSignalText
```

When no Wi-Fi network is active, signal is `0` and signal text is `""`. Non-finite values also become `0`.

### Bucketed signal and icons

`signalBucket()` maps signal to:

```text
>= 75 -> 4
>= 50 -> 3
>= 25 -> 2
> 0   -> 1
else  -> 0
```

`icon` then selects a Nerd Font glyph, with airplane mode taking precedence over Wi-Fi and wired:

```text
airplane (without wired) -> 󰀝
active Wi-Fi             -> 󰤨 / 󰤥 / 󰤢 / 󰤟 / 󰤯
active wired             -> 󰈀
limited / disconnected   -> 󰤯
```

`iconKey` selects the matching freedesktop name:

```text
airplane-mode
wifi-4 / wifi-3 / wifi-2 / wifi-1 / wifi-off
ethernet
network-off
```

### Serialization helpers

`networkInfo()` and `deviceInfo()` convert native objects into plain JSON-safe data.

A network becomes:

```json
{
    "name": "HomeWifi",
    "connected": true,
    "known": true,
    "state": "Activated",
    "stateChanging": false,
    "isWifi": true,
    "deviceName": "wlan0",
    "signal": 72,
    "security": "Wpa2",
    "icon": "󰤥",
    "iconKey": "wifi-3",
    "nmSettings": []
}
```

A device becomes plain data plus transport-specific fields (`scannerEnabled`/`scanning` for Wi-Fi, `hasLink`/`linkSpeed` for wired).

The same functions back IPC `getDevices()`, `getWifiNetworks()`, and `getConnectedNetworks()`.

### Hotplug and state signals

The service watches:

```text
Networking.devices
```

and emits:

```text
deviceAdded(device)
deviceRemoved(device)
networkListUpdated()
stateChangedExternally()
```

Wi-Fi, hardware, and connectivity changes also emit `stateChangedExternally()`.

### No polling

The service does not repeatedly query NetworkManager on a timer.

It relies on Quickshell's reactive `Networking` bindings and `Connections` handlers.

### No configuration persistence

The service owns no `Config` section.

It does not read or write:

```text
homeConfig
```

All state comes from live `Networking` objects.

---

## Limitations

### Backend is required

If the backend is `None`:

```text
isAvailable = false
deviceCount = 0
wifiNetworkCount = 0
activeNetwork = null
statusText = "Disconnected"
```

Callers must handle the empty case. The service does not emulate networks.

### Airplane mode is Wi-Fi only

`setAirplaneMode(true)` only disables:

```text
Networking.wifiEnabled
```

It never touches Bluetooth. A component that wants full airplane behavior must coordinate with the Bluetooth service separately.

### Wired lookup is limited to device.network

`findNetwork()` searches wired networks only through:

```text
wiredDeviceList[].network
```

If a wired device has no `network` object, it is skipped. Wi-Fi SSIDs have richer search (connected match preferred, then first SSID match).

### PSK and managed writes are capability-guarded

`connectNetworkWithPsk()` only calls:

```qml
network.connectWithPsk(...)
```

when that function exists on the object.

`setDeviceManaged()` only writes:

```qml
device.nmManaged
```

when `nmManaged` exists on the object. This guards NetworkManager-specific API differences.

### Connectivity checks can be unsupported

When:

```text
canCheckConnectivity = false
```

both:

```qml
Network.setConnectivityCheckEnabled(...)
Network.checkConnectivity()
```

are no-ops. IPC `checkConnectivity` and `setConnectivityCheck` behave the same way.

### Scan is guarded

`scan()` does nothing when:

```text
!isWifiSupported
!isWifiHardwareEnabled
!isWifiEnabled
```

There is no queued scan. The caller must enable Wi-Fi first.

### Only the first active object has dedicated properties

Top-level properties such as:

```text
activeWifiName
activeWiredName
activeNetworkName
```

describe the first matching object.

Additional connections are only visible through:

```qml
Network.connectedNetworkList
```

or:

```bash
qs ipc call n0ctos-network getConnectedNetworks
```

### Control functions are fire-and-forget

Functions such as:

```text
connectNetwork
disconnectNetwork
forgetNetwork
disconnectDevice
```

return no value and perform no validation beyond a null/`""` guard.

A missing name is a silent no-op, not an error.

---

# 5. Example use cases

## 5.1 A panel showing status and icon

A panel only needs two bindings:

```qml
import QtQuick
import Quickshell

import qs.services

Row {
    spacing: 6

    Text {
        text:
            Network.icon
    }

    Text {
        text:
            Network.statusText
    }
}
```

The component does not need to know whether the values came from:

```text
connected Wi-Fi
connected Ethernet
limited connectivity
a captive portal
a disconnected machine
```

It only receives the effective value.

---

## 5.2 A Wi-Fi toggle with airplane awareness

Wi-Fi state is already resolved:

```qml
import QtQuick

import qs.services

Row {
    spacing: 8

    Text {
        text:
            Network.isWifiEnabled
                ? "Wi-Fi on"
                : "Wi-Fi off"
    }

    Text {
        visible:
            Network.isAirplaneMode

        text:
            "Airplane"
    }

    MouseArea {
        anchors.fill:
            parent

        onClicked:
            Network.setWifiEnabled(
                !Network.isWifiEnabled
            )
    }
}
```

No manual check of hardware flags is needed for the basic toggle. `isAirplaneMode` already means "supported but software-disabled".

For explicit airplane control:

```qml
Network.setAirplaneMode(true)
```

disables Wi-Fi, while:

```qml
Network.setAirplaneMode(false)
```

enables it again.

---

## 5.3 Listing visible Wi-Fi networks

`wifiNetworks` is a QML model, `wifiNetworkList` is a plain array:

```qml
import QtQuick

import qs.services

ListView {
    model:
        Network.wifiNetworks

    delegate: Text {
        required property var modelData

        text:
            Network.networkInfo(
                modelData
            ).name +
            " " +
            Network.networkInfo(
                modelData
            ).signal +
            "%"
    }
}
```

For imperative code, use the array form:

```qml
for (
    let i = 0;
    i < Network.wifiNetworkList.length;
    ++i
) {
    const info =
        Network.networkInfo(
            Network.wifiNetworkList[i]
        )

    console.log(
        info.name,
        info.signal,
        info.connected
    )
}
```

---

## 5.4 Connecting to a network, with and without a key

A known network needs only its SSID:

```qml
Network.connectNetwork("HomeWifi")
```

A new protected network needs its pre-shared key:

```qml
Network.connectNetworkWithPsk(
    "HomeWifi",
    "secret123"
)
```

Disconnecting and forgetting use the same lookup:

```qml
Network.disconnectNetwork("HomeWifi")
Network.forgetNetwork("HomeWifi")
```

`findNetwork()` prefers the already-connected object when several objects share one SSID, so disconnect targets the live connection first.

---

## 5.5 Showing the active transport

The primary transport is already resolved:

```qml
import QtQuick

import qs.services

Text {
    text: {
        if (Network.activeConnectionType === "wifi")
            return Network.activeWifiName +
                " " +
                Network.activeWifiSignalText

        if (Network.activeConnectionType === "ethernet")
            return Network.activeWiredName +
                " " +
                Network.activeWiredLinkSpeed +
                " Mb/s"

        return Network.statusText
    }
}
```

The result is:

```text
wifi, "HomeWifi", 72% -> "HomeWifi 72%"
ethernet, "enp0s31f6"  -> "enp0s31f6 1000 Mb/s"
offline                -> "Disconnected"
```

---

## 5.6 Reacting to hotplug

Device topology changes emit explicit signals:

```qml
import QtQuick

import qs.services

Connections {
    target:
        Network

    function onDeviceAdded(device) {
        console.log(
            "added",
            Network.deviceInfo(device).name
        )
    }

    function onDeviceRemoved(device) {
        console.log(
            "removed",
            Network.deviceInfo(device).name
        )
    }

    function onNetworkListUpdated() {
        console.log(
            "networks:",
            Network.wifiNetworkCount
        )
    }
}
```

Individual native objects remain reactive themselves; these signals cover topology changes.

---

## 5.7 Terminal workflow

Read the status:

```bash
qs ipc call n0ctos-network getState
```

Read connectivity:

```bash
qs ipc call n0ctos-network getConnectivity
```

Read the icon:

```bash
qs ipc call n0ctos-network getIcon
```

Check Wi-Fi and scanning:

```bash
qs ipc call n0ctos-network getWifiEnabled
qs ipc call n0ctos-network isScanning
```

Connect and disconnect:

```bash
qs ipc call n0ctos-network connect HomeWifi
qs ipc call n0ctos-network connectPsk HomeWifi secret123
qs ipc call n0ctos-network disconnect HomeWifi
```

Control a device:

```bash
qs ipc call n0ctos-network disconnectDevice wlan0
qs ipc call n0ctos-network setAutoconnect wlan0 false
```

Inspect the complete service:

```bash
qs ipc call n0ctos-network getStatus
```

Inspect devices and networks:

```bash
qs ipc call n0ctos-network getDevices
qs ipc call n0ctos-network getWifiNetworks
qs ipc call n0ctos-network getConnectedNetworks
```

---

# 6. Detailed architecture

This section is for developers working on `Network.qml` and the services/components that consume it.

---

## 6.1 Overall architecture

The service is a normalization layer built on top of Quickshell's `Networking` service.

```text
N0ctOS Component / Service
            │
            ▼
      Network.qml
            │
     ┌──────┼────────┐
     │      │        │
     ▼      ▼        ▼
 backend  models   derived
 state   active   text/icons
     │      │        │
     └──────┴────────┘
            │
            ▼
  Quickshell Networking
            │
            ▼
 NetworkManager / hardware
```

There are effectively two responsibilities:

```text
Network
    N0ctOS-friendly normalization

Networking
    hardware detection and raw state
```

Network should not duplicate the hardware detection already provided by Networking.

---

## 6.2 Backend layer

Backend state is a direct pass-through:

```text
Networking.backend
    ↓
isAvailable = backend !== None
backendName = NetworkBackendType.toString(backend)
```

When no backend exists, every model is empty and every active object is `null`. The service does not synthesize placeholder devices.

---

## 6.3 Wi-Fi state derivation

Three independent inputs produce two derived flags:

```text
wifiDeviceList.length > 0      -> isWifiSupported
Networking.wifiEnabled         -> isWifiEnabled
Networking.wifiHardwareEnabled -> isWifiHardwareEnabled
```

Then:

```text
supported && enabled && hardware-enabled -> isWifiAvailable
supported && !enabled                    -> isAirplaneMode
```

A machine with no Wi-Fi card therefore reports:

```text
isWifiSupported = false
isAirplaneMode = false
```

while a laptop with Wi-Fi turned off reports:

```text
isWifiSupported = true
isAirplaneMode = true
```

---

## 6.4 Connectivity derivation

Raw connectivity is passed through:

```text
Networking.connectivity
    ↓
connectivity / connectivityName
```

Boolean flags split it:

```text
Full    -> isInternetAvailable
Portal  -> isCaptivePortal
Limited -> isLimitedConnectivity
!Unknown -> isConnectivityKnown
```

Connection presence is independent:

```text
connectedDeviceCount > 0 -> isNetworkConnected
```

A connected device with `Limited` connectivity therefore reports both `isNetworkConnected` and `isLimitedConnectivity` as `true`.

---

## 6.5 Device models

The raw model is preserved:

```text
Networking.devices (ObjectModel)
    ↓
Network.devices
```

Filtered views are derived reactively:

```text
deviceList
    ↓
filter type === Wifi  -> wifiDeviceModel
filter type === Wired -> wiredDeviceModel
filter connected      -> connectedDeviceModel
```

Each view is exposed as:

```text
wifiDevices      -> ScriptModel for ListView
wifiDeviceList   -> plain JS array
wifiDeviceCount  -> array length
```

`ScriptModel.values` drives reactivity: when `deviceList` changes, each filter reevaluates.

---

## 6.6 Network models

Wi-Fi networks are flattened from every radio:

```text
wifiDeviceList
    ↓
each device.networks.values
    ↓
deduplicated collectWifiNetworks()
    ↓
wifiNetworks / wifiNetworkList / wifiNetworkCount
```

Connected networks add wired links:

```text
each connected WifiNetwork
    +
each connected wired device.network
    ↓
deduplicated collectConnectedNetworks()
    ↓
connectedNetworks / connectedNetworkList
```

Native objects are kept, not copied, so `network.connect()` still works on list entries.

---

## 6.7 Active selection

Three helpers pick the primary objects:

```text
wifiNetworkList, first connected  -> activeWifiNetwork
wiredDeviceList, first connected  -> activeWiredDevice
deviceList in NM order, first connected device's network -> activeNetwork
```

The wired branch of `findActiveNetwork()` returns:

```text
device.network
```

directly, because wired devices expose a single network object rather than a network list.

Derived booleans are:

```text
!!activeWifiNetwork                  -> isWifiActive
!!activeWiredDevice && connected     -> isWiredActive
```

---

## 6.8 statusText and activeConnectionType

Status text has a fixed precedence:

```text
activeNetworkName !== "" -> activeNetworkName
isNetworkConnected       -> connectivityName
otherwise                -> "Disconnected"
```

Connection type inspects the active network's device:

```text
no activeNetwork       -> "none"
no network.device      -> "unknown"
device.type === Wifi   -> "wifi"
device.type === Wired  -> "ethernet"
otherwise              -> "unknown"
```

Both are pure derivations with no side effects.

---

## 6.9 Signal normalization

Signal conversion guards every bad input:

```text
null              -> 0
non-finite        -> 0
Number(signalStrength) * 100
    ↓
clamp 0 -> 100
    ↓
signalPercent
```

Then:

```text
signalPercent
    ↓
round -> activeWifiSignalRounded
    ↓
active network ? rounded + "%" : ""
```

`signalBucket()` thresholds the same value:

```text
>= 75 -> 4
>= 50 -> 3
>= 25 -> 2
> 0   -> 1
else  -> 0
```

---

## 6.10 Icon resolution

Shell icon selection has a fixed precedence:

```text
airplane without wired
    ↓
active Wi-Fi
    ↓
active wired
    ↓
disconnected
```

Concretely:

```text
isAirplaneMode && !isWiredActive -> 󰀝 / airplane-mode
activeWifiNetwork                -> wifiIcon(activeSignal, true, false)
activeWiredDevice                -> 󰈀 / ethernet
otherwise                        -> 󰤯 / network-off
```

Per-network icons reuse the same helper:

```text
null          -> 󰤯 / network-off
wired         -> 󰈀 / ethernet
Wi-Fi         -> wifiIcon(signal, connected, !isWifiEnabled)
```

`wifiIcon()` itself is:

```text
disabled    -> 󰤭
>= 75       -> 󰤨
>= 50       -> 󰤥
>= 25       -> 󰤢
> 0         -> 󰤟
else        -> 󰤯
```

for both connected and disconnected inputs.

---

## 6.11 Info serialization

`networkInfo()` converts one native network into JSON-safe data:

```json
{
    "name": "",
    "connected": false,
    "known": false,
    "state": "Unknown",
    "stateChanging": false,
    "isWifi": false,
    "deviceName": "",
    "signal": 0,
    "security": "",
    "icon": "󰤯",
    "iconKey": "network-off",
    "nmSettings": []
}
```

Wired networks report `signal: 0` and `security: ""` because those fields are Wi-Fi only.

`deviceInfo()` converts one native device:

```json
{
    "name": "",
    "address": "",
    "type": "",
    "isWifi": false,
    "isWired": false,
    "isConnected": false,
    "state": "Unknown",
    "isAutoconnect": false,
    "isNmManaged": true,
    "icon": "󰖩",
    "iconKey": "network",
    "networks": []
}
```

with Wi-Fi additions:

```text
scannerEnabled
scanning (= scannerEnabled)
```

and wired additions:

```text
hasLink
linkSpeed
```

Both return `{}` for null input so QML and IPC callers never need null checks on the info shape.

---

## 6.12 Control flows

Wi-Fi control is a direct assignment:

```text
setWifiEnabled(enabled)
    ↓
Networking.wifiEnabled = Boolean(enabled)
```

Airplane mode inverts it:

```text
setAirplaneMode(enabled)
    ↓
setWifiEnabled(!enabled)
```

Scanning fans out:

```text
scan()
    ↓
guard supported && hardware && enabled
    ↓
each wifi device: scannerEnabled = true
```

Connectivity control is capability-guarded:

```text
canCheckConnectivity ?
    set / check
    : no-op
```

Network and device control share one pattern:

```text
find by name
    ↓
missing ? no-op
    ↓
call native method / assign property
```

---

## 6.13 Lookup semantics

`findDevice()` is an exact match:

```text
String(device.name) === String(wanted)
```

`findNetwork()` has three passes:

```text
1. connected Wi-Fi with matching SSID
2. first Wi-Fi with matching SSID
3. wired device.network with matching name
```

This means disconnect prefers the live object when duplicate SSIDs are visible, while connect falls back to the first visible object.

---

## 6.14 Reactive state and signals

The service consumes reactive `Networking` state:

```text
Networking changes
        │
        ▼
Network properties reevaluate
        │
        ▼
component bindings reevaluate
```

Topology changes use explicit signals:

```text
Networking.devices insert/remove
        │
        ▼
deviceAdded / deviceRemoved
        │
        ▼
networkListUpdated + stateChangedExternally
```

A component does not need to manually rescan or reload network state.

For example:

```qml
readonly property string status:
    Network.statusText
```

can react to backend, device, and connectivity changes through the service.

---

## 6.15 IPC architecture

IPC is a thin external interface over the same service API.

Conceptually:

```text
terminal
   │
   ▼
n0ctos-network
   │
   ▼
Network.qml
   │
   ▼
Quickshell Networking
```

For example:

```bash
qs ipc call n0ctos-network connect HomeWifi
```

becomes conceptually:

```qml
Network.connectNetwork("HomeWifi")
```

and:

```bash
qs ipc call n0ctos-network getStatus
```

becomes conceptually:

```qml
JSON.stringify(Network.statusInfo())
```

The IPC layer serializes values as strings for terminal use (`"true"`/`"false"` for booleans, JSON for objects).

---

## 6.16 No polling and no Config

Network does not use a polling timer to detect changes.

There is no:

```qml
Timer {
    interval: 1000
    repeat: true

    onTriggered:
        reloadNetworks()
}
```

Changes propagate through Quickshell's reactive `Networking` bindings and `Connections` handlers.

The service also owns no configuration section. It should not create its own:

```qml
FileView
```

and should not read or write:

```text
homeConfig
```

All state is live hardware state, not persisted shell configuration.

---

## 6.17 What UI / service code should not do

Components should not:

```text
read Networking.devices filtering inline in every panel

flatten wifi device networks manually

track active Wi-Fi vs wired priority manually

reimplement signal clamping or buckets

reimplement icon precedence

call native connect/disconnect without null guards

poll NetworkManager on a timer

assume Wi-Fi always exists

assume airplane mode covers Bluetooth
```

Instead:

```qml
Network.statusText
Network.icon
Network.activeWifiName
Network.wifiNetworks
Network.connectNetwork(...)
Network.setWifiEnabled(...)
```

should be the normal interface.

---

## 6.18 Final architecture summary

The entire system can be viewed as:

```text
                         Component
                            │
                            │ property binding / control call
                            ▼
                    ┌─────────────────┐
                    │     Network     │
                    │                 │
                    │ backend         │
                    │ wifi + airplane │
                    │ connectivity    │
                    │ device models   │
                    │ network models  │
                    │ active + icons  │
                    │ info + lookups  │
                    └────────┬────────┘
                             │
                             │ Networking API
                             ▼
                    ┌─────────────────┐
                    │   Networking    │
                    │                 │
                    │ backend         │
                    │ devices         │
                    │ wifi networks   │
                    │ connectivity    │
                    │ wifi control    │
                    └────────┬────────┘
                             │
                             ▼
                 NetworkManager / hardware
```

The core rule is:

> **Components read what network state they need; `Network.qml` decides which device or network it comes from and how it is normalized; `Networking` handles how hardware state is detected and changed.**
