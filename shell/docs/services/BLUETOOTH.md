# Bluetooth Service

`Bluetooth.qml` is N0ctOS's centralized Bluetooth adapter and device service.

It gives every shell component one consistent place to read Bluetooth state and control adapters and devices without touching BlueZ or Quickshell Bluetooth objects directly.

The service supports multi-adapter tracking, filtered device collections, active-device resolution, battery normalization, per-device icons, adapter icons, JSON serialization, and a full IPC interface.

The normal usage pattern is:

```text
Component
    │
    ▼
Bluetooth (N0ctOS service)
    │
    ├── adapter state
    ├── filtered device models
    ├── active device
    └── icons / serialization
    │
    ▼
Quickshell.Bluetooth
    │
    ▼
BlueZ
```

---

# 1. What does it do?

`Bluetooth.qml` wraps Quickshell's global Bluetooth backend for the shell.

It exposes the default adapter as simple properties:

```json
{
    "adapter": "MyMachine",
    "adapterId": "hci0",
    "isEnabled": true,
    "isDiscovering": false,
    "state": "Enabled"
}
```

and every tracked device as a serializable object:

```json
{
    "name": "WH-1000XM5",
    "address": "AA:BB:CC:DD:EE:FF",
    "isConnected": true,
    "isPaired": true,
    "batteryText": "82%"
}
```

A component can simply do:

```qml
Bluetooth.isEnabled
```

or:

```qml
Bluetooth.connectedDeviceCount
```

and not care which BlueZ adapter or `Device1` object the value came from.

Filtered collections are resolved in memory:

```text
Bluetooth.devices.values
    ↓
connected / paired / bonded / battery
    ↓
connectedDeviceList
pairedDeviceList
bondedDeviceList
batteryDeviceList
```

So a component can bind directly to:

```qml
Bluetooth.connectedDeviceList
```

The active device is resolved as the first connected device:

```text
deviceList
    ↓
first device.connected
    ↓
activeDevice
```

A component can therefore do:

```qml
Bluetooth.activeDeviceName
```

without scanning the device list itself.

If no adapter exists, adapter properties return safe fallbacks (`""`, `0`, `false`) and `stateName` returns `"Disabled"`.

If no device is connected, `activeDevice` is `null` and `activeDeviceName` is `""`.

---

# 2. UI API

Import normally:

```qml
import QtQuick
import Quickshell

import qs.services
```

## Core API

### Backend / adapter state

| How to call | What does it do |
| --- | --- |
| `Bluetooth.adapters` | Raw `Bluetooth.adapters` ObjectModel from Quickshell. |
| `Bluetooth.adapterList` | `Bluetooth.adapters.values` as a plain list. |
| `Bluetooth.adapterCount` | Number of adapters. |
| `Bluetooth.defaultAdapter` | Raw Quickshell default adapter object, or null. |
| `Bluetooth.isAvailable` | True when at least one adapter exists and a default adapter is set. |
| `Bluetooth.isEnabled` | True when the default adapter exists and `enabled` is true. |
| `Bluetooth.isPowered` | Alias of `isEnabled`. |
| `Bluetooth.isBlocked` | True when default adapter state is `Blocked`. |
| `Bluetooth.isEnabling` | True when default adapter state is `Enabling`. |
| `Bluetooth.isDisabling` | True when default adapter state is `Disabling`. |
| `Bluetooth.stateName` | `BluetoothAdapterState.toString(state)`, or `"Disabled"` when no adapter. |
| `Bluetooth.adapterName` | Default adapter `name`, or `""`. |
| `Bluetooth.adapterId` | Default adapter `adapterId` (for example `hci0`), or `""`. |
| `Bluetooth.adapterDbusPath` | Default adapter `dbusPath`, or `""`. |
| `Bluetooth.isDiscoverable` | Default adapter `discoverable`. |
| `Bluetooth.isDiscovering` | Default adapter `discovering`. |
| `Bluetooth.isPairable` | Default adapter `pairable`. |
| `Bluetooth.discoverableTimeout` | Default adapter `discoverableTimeout`, or `0`. |
| `Bluetooth.pairableTimeout` | Default adapter `pairableTimeout`, or `0`. |

### Device collections

| How to call | What does it do |
| --- | --- |
| `Bluetooth.devices` | Raw `Bluetooth.devices` global ObjectModel across all adapters. |
| `Bluetooth.deviceList` | `Bluetooth.devices.values` as a plain list. |
| `Bluetooth.deviceCount` | Number of tracked devices. |
| `Bluetooth.connectedDevices` | ScriptModel of devices where `connected` is true. |
| `Bluetooth.connectedDeviceList` | Plain list of connected devices. |
| `Bluetooth.connectedDeviceCount` | Number of connected devices. |
| `Bluetooth.pairedDevices` | ScriptModel of devices where `paired` is true. |
| `Bluetooth.pairedDeviceList` | Plain list of paired devices. |
| `Bluetooth.pairedDeviceCount` | Number of paired devices. |
| `Bluetooth.bondedDevices` | ScriptModel of devices where `bonded` is true. |
| `Bluetooth.bondedDeviceList` | Plain list of bonded devices. |
| `Bluetooth.bondedDeviceCount` | Number of bonded devices. |
| `Bluetooth.batteryDevices` | ScriptModel of devices where `batteryAvailable` is true. |
| `Bluetooth.batteryDeviceList` | Plain list of battery-reporting devices. |
| `Bluetooth.batteryDeviceCount` | Number of battery-reporting devices. |
| `Bluetooth.connectedBatteryDevices` | ScriptModel of devices where `connected` and `batteryAvailable` are true. |
| `Bluetooth.connectedBatteryDeviceList` | Plain list of connected battery devices. |
| `Bluetooth.connectedBatteryDeviceCount` | Number of connected battery devices. |

### Active device

| How to call | What does it do |
| --- | --- |
| `Bluetooth.activeDevice` | First connected device, or `null`. |
| `Bluetooth.activeDeviceName` | Display name of the active device, or `""`. |
| `Bluetooth.activeDeviceAddress` | MAC address of the active device, or `""`. |
| `Bluetooth.isDeviceConnected` | True when an active device exists. |
| `Bluetooth.hasDeviceBattery` | True when the active device reports battery. |
| `Bluetooth.activeDeviceBattery` | Active device battery in `0` to `100` range, or `0`. |
| `Bluetooth.activeDeviceBatteryRounded` | Rounded battery percent. |
| `Bluetooth.activeDeviceBatteryText` | Battery text such as `"82%"`, or `""`. |

### Icons

| How to call | What does it do |
| --- | --- |
| `Bluetooth.icon` | Nerd Font glyph for the current adapter state. |
| `Bluetooth.iconKey` | Stable icon key for the current adapter state. |

### Adapter control

| How to call | What does it do |
| --- | --- |
| `Bluetooth.setEnabled(enabled)` | Sets `defaultAdapter.enabled`. No-op when no adapter exists. |
| `Bluetooth.startDiscovery()` | Sets `discovering = true` on every enabled adapter. |
| `Bluetooth.stopDiscovery()` | Sets `discovering = false` on every adapter. |
| `Bluetooth.setDiscoverable(enabled)` | Sets `defaultAdapter.discoverable`. No-op when no adapter exists. |
| `Bluetooth.setDiscoverableTimeout(seconds)` | Sets `discoverableTimeout` clamped to `>= 0`. |
| `Bluetooth.setPairable(enabled)` | Sets `defaultAdapter.pairable`. No-op when no adapter exists. |
| `Bluetooth.setPairableTimeout(seconds)` | Sets `pairableTimeout` clamped to `>= 0`. |

### Device lookup

| How to call | What does it do |
| --- | --- |
| `Bluetooth.findDevice(address)` | Finds a device by MAC address, case-insensitive. Returns `null` for `""` or no match. |
| `Bluetooth.findDeviceByName(name)` | Finds a device by display name, case-insensitive. Returns `null` for `""` or no match. |
| `Bluetooth.findFirstConnectedDevice()` | Returns the first connected device, or `null`. |

|Example|Result|
|---|---|
|`Bluetooth.findDevice("AA:BB:CC:DD:EE:FF")`|device object, or `null` when unknown|
|`Bluetooth.findDeviceByName("WH-1000XM5")`|device object, or `null` when no name matches|
|`Bluetooth.findFirstConnectedDevice()`|first connected device, or `null`|

### Device connection control

| How to call | What does it do |
| --- | --- |
| `Bluetooth.connectDevice(address)` | Connects the matching device. Skips unknown or blocked devices. |
| `Bluetooth.disconnectDevice(address)` | Disconnects the matching device. |
| `Bluetooth.pairDevice(address)` | Pairs the matching device. Skips unknown, already paired, or currently pairing devices. |
| `Bluetooth.cancelPairDevice(address)` | Cancels pairing, only when the device is currently pairing. |
| `Bluetooth.forgetDevice(address)` | Forgets/removes the matching device. |

|Example|Result|
|---|---|
|`Bluetooth.connectDevice("AA:BB:CC:DD:EE:FF")`|device starts connecting (skipped when unknown or blocked)|
|`Bluetooth.disconnectDevice("AA:BB:CC:DD:EE:FF")`|device disconnects|
|`Bluetooth.pairDevice("AA:BB:CC:DD:EE:FF")`|pairing starts (skipped when unknown, paired, or pairing)|
|`Bluetooth.cancelPairDevice("AA:BB:CC:DD:EE:FF")`|pairing cancelled (only while pairing)|
|`Bluetooth.forgetDevice("AA:BB:CC:DD:EE:FF")`|device removed|

### Device policy control

| How to call | What does it do |
| --- | --- |
| `Bluetooth.setDeviceTrusted(address, trusted)` | Sets `device.trusted`. |
| `Bluetooth.setDeviceBlocked(address, blocked)` | Sets `device.blocked`. |
| `Bluetooth.setDeviceWakeAllowed(address, allowed)` | Sets `device.wakeAllowed`. |
| `Bluetooth.setDeviceName(address, name)` | Sets `device.name` (alias). |

|Example|Result|
|---|---|
|`Bluetooth.setDeviceTrusted("AA:BB:CC:DD:EE:FF", true)`|device becomes trusted|
|`Bluetooth.setDeviceBlocked("AA:BB:CC:DD:EE:FF", false)`|device becomes unblocked|
|`Bluetooth.setDeviceWakeAllowed("AA:BB:CC:DD:EE:FF", true)`|device may wake the system|
|`Bluetooth.setDeviceName("AA:BB:CC:DD:EE:FF", "Headphones")`|device alias becomes `"Headphones"`|

### Display / battery / state helpers

| How to call | What does it do |
| --- | --- |
| `Bluetooth.displayName(device)` | `device.name` trimmed, else `device.deviceName`, else `""`. Returns `""` for null. |
| `Bluetooth.batteryPercent(device)` | Converts Quickshell `0.0` to `1.0` battery to `0` to `100`. Returns `0` for missing, unavailable, or non-finite values. |
| `Bluetooth.deviceStateName(device)` | `BluetoothDeviceState.toString(state)`, or `"Unknown"` for null. |
| `Bluetooth.isDeviceConnecting(device)` | True when device state is `Connecting`. |
| `Bluetooth.isDeviceDisconnecting(device)` | True when device state is `Disconnecting`. |

|Example|Result|
|---|---|
|`Bluetooth.displayName(device)`|`"WH-1000XM5"` (name, else deviceName, else `""`)|
|`Bluetooth.batteryPercent(device)`|`82` (0–100, `0` when unavailable)|
|`Bluetooth.deviceStateName(device)`|state string, e.g. `"Connected"` (`"Unknown"` when null)|
|`Bluetooth.isDeviceConnecting(device)`|`true` while state is `Connecting`|
|`Bluetooth.isDeviceDisconnecting(device)`|`true` while state is `Disconnecting`|

### Device and adapter icons

| How to call | What does it do |
| --- | --- |
| `Bluetooth.deviceIconKey(device)` | Stable key from `device.icon` plus display name: `headphones`, `speaker`, `keyboard`, `mouse`, `gamepad`, `phone`, `tablet`, `laptop`, `printer`, `camera`, `television`, or `bluetooth`. |
| `Bluetooth.deviceIcon(device)` | Nerd Font glyph for the device icon key. |
| `Bluetooth.iconForState()` | Adapter glyph based on availability, block, transition, discovery, connection, and power. |
| `Bluetooth.iconKeyForState()` | Adapter key: `bluetooth-off`, `bluetooth-blocked`, `bluetooth-discovering`, `bluetooth-connected`, `bluetooth`. |

### Serialization

| How to call | What does it do |
| --- | --- |
| `Bluetooth.deviceInfo(device)` | Returns a plain JSON-safe object for one device. Returns `{}` for null. |
| `Bluetooth.adapterInfo(adapter)` | Returns a plain JSON-safe object for one adapter including its connected devices. Returns `{}` for null. |
| `Bluetooth.statusInfo()` | Returns the complete service status object used by IPC `getStatus`. |

### Signals

| Signal | When it fires |
| --- | --- |
| `adapterAdded(var adapter)` | A BlueZ adapter object was inserted. |
| `adapterRemoved(var adapter)` | A BlueZ adapter object was removed. |
| `deviceAdded(var device)` | A BlueZ device object was inserted. |
| `deviceRemoved(var device)` | A BlueZ device object was removed. |
| `stateChangedExternally()` | Default adapter, adapter list, or device list changed underneath the service. |
| `adapterListUpdated()` | Adapter model changed or default adapter changed. |
| `deviceListUpdated()` | Device model changed. |

For example:

```qml
Connections {
    target: Bluetooth

    function onDeviceAdded(device) {
        console.log(
            "added:",
            Bluetooth.displayName(device)
        )
    }

    function onDeviceListUpdated() {
        console.log(
            "devices:",
            Bluetooth.deviceCount
        )
    }
}
```

### Typical component usage

A panel toggle only needs the headline properties:

```qml
readonly property bool available:
    Bluetooth.isAvailable

readonly property bool enabled:
    Bluetooth.isEnabled

readonly property string icon:
    Bluetooth.icon

readonly property string activeName:
    Bluetooth.activeDeviceName
```

A device row only needs lookup plus one action:

```qml
readonly property var device:
    Bluetooth.findDevice(
        "AA:BB:CC:DD:EE:FF"
    )

readonly property string name:
    Bluetooth.displayName(
        device
    )

readonly property bool connected:
    device
        ? device.connected
        : false
```

That is the intended everyday usage.

Components normally should not need to touch raw `Quickshell.Bluetooth` models directly.

---

# 3. IPC API

IPC target:

```text
n0ctos-bluetooth
```

## Core adapter and discovery

| How to call | What does it do |
| --- | --- |
| `getStatus` | Returns `statusInfo()` as a JSON string. |
| `getState` | Returns `stateName`. |
| `getIcon` | Returns the adapter icon glyph. |
| `getAdapter` | Returns `adapterName`. |
| `getAdapterId` | Returns `adapterId`. |
| `getEnabled` | Returns `"true"` or `"false"`. |
| `setEnabled <true\|false>` | Sets adapter power. |
| `toggle` | Flips the current power state. |
| `getDiscovering` | Returns `"true"` or `"false"`. |
| `startDiscovery` | Starts discovery on every enabled adapter. |
| `stopDiscovery` | Stops discovery on every adapter. |
| `getDiscoverable` | Returns `"true"` or `"false"`. |
| `setDiscoverable <true\|false>` | Sets discoverable mode. |
| `setDiscoverableTimeout <seconds>` | Sets discoverable timeout. |
| `getPairable` | Returns `"true"` or `"false"`. |
| `setPairable <true\|false>` | Sets pairable mode. |
| `setPairableTimeout <seconds>` | Sets pairable timeout. |

| Example | Result |
| --- | --- |
| `qs ipc call n0ctos-bluetooth getStatus` | JSON status object |
| `qs ipc call n0ctos-bluetooth getState` | state string, e.g. `"Enabled"` (`"Disabled"` with no adapter) |
| `qs ipc call n0ctos-bluetooth getIcon` | adapter Nerd Font glyph |
| `qs ipc call n0ctos-bluetooth getAdapter` | adapter name, or `""` |
| `qs ipc call n0ctos-bluetooth getAdapterId` | `"hci0"`, or `""` |
| `qs ipc call n0ctos-bluetooth getEnabled` | `"true"` or `"false"` |
| `qs ipc call n0ctos-bluetooth setEnabled true` | adapter powers on |
| `qs ipc call n0ctos-bluetooth toggle` | power state flips |
| `qs ipc call n0ctos-bluetooth getDiscovering` | `"true"` or `"false"` |
| `qs ipc call n0ctos-bluetooth startDiscovery` | discovery starts on enabled adapters |
| `qs ipc call n0ctos-bluetooth stopDiscovery` | discovery stops |
| `qs ipc call n0ctos-bluetooth getDiscoverable` | `"true"` or `"false"` |
| `qs ipc call n0ctos-bluetooth setDiscoverable true` | adapter becomes discoverable |
| `qs ipc call n0ctos-bluetooth setDiscoverableTimeout 120` | timeout becomes 120 s |
| `qs ipc call n0ctos-bluetooth getPairable` | `"true"` or `"false"` |
| `qs ipc call n0ctos-bluetooth setPairable true` | adapter becomes pairable |
| `qs ipc call n0ctos-bluetooth setPairableTimeout 0` | timeout becomes 0 (no timeout) |

Boolean arguments use QML bools over IPC:

```bash
qs ipc call n0ctos-bluetooth setEnabled true
```

```bash
qs ipc call n0ctos-bluetooth setEnabled false
```

Timeouts are integers in seconds:

```bash
qs ipc call n0ctos-bluetooth setDiscoverableTimeout 120
```

```bash
qs ipc call n0ctos-bluetooth setPairableTimeout 0
```

Toggle needs no argument:

```bash
qs ipc call n0ctos-bluetooth toggle
```

## Other operations

| How to call | What does it do |
| --- | --- |
| `getDevices` | Returns every tracked device as a JSON array of `deviceInfo()` objects. |
| `getConnectedDevices` | Returns connected devices as a JSON array. |
| `getPairedDevices` | Returns paired devices as a JSON array. |
| `connect <address>` | Connects one device by MAC address. |
| `disconnect <address>` | Disconnects one device by MAC address. |
| `pair <address>` | Pairs one device by MAC address. |
| `cancelPair <address>` | Cancels an in-progress pairing. |
| `forget <address>` | Forgets one device by MAC address. |
| `setTrusted <address> <true\|false>` | Sets the trusted flag. |
| `setBlocked <address> <true\|false>` | Sets the blocked flag. |
| `setWakeAllowed <address> <true\|false>` | Sets wake-allowed. |
| `setName <address> <name>` | Sets the device alias. |

| Example | Result |
| --- | --- |
| `qs ipc call n0ctos-bluetooth getDevices` | JSON array of `deviceInfo()` objects |
| `qs ipc call n0ctos-bluetooth getConnectedDevices` | JSON array of connected devices |
| `qs ipc call n0ctos-bluetooth getPairedDevices` | JSON array of paired devices |
| `qs ipc call n0ctos-bluetooth connect AA:BB:CC:DD:EE:FF` | device starts connecting |
| `qs ipc call n0ctos-bluetooth disconnect AA:BB:CC:DD:EE:FF` | device disconnects |
| `qs ipc call n0ctos-bluetooth pair AA:BB:CC:DD:EE:FF` | pairing starts |
| `qs ipc call n0ctos-bluetooth cancelPair AA:BB:CC:DD:EE:FF` | in-progress pairing cancelled |
| `qs ipc call n0ctos-bluetooth forget AA:BB:CC:DD:EE:FF` | device removed |
| `qs ipc call n0ctos-bluetooth setTrusted AA:BB:CC:DD:EE:FF true` | device becomes trusted |
| `qs ipc call n0ctos-bluetooth setBlocked AA:BB:CC:DD:EE:FF false` | device becomes unblocked |
| `qs ipc call n0ctos-bluetooth setWakeAllowed AA:BB:CC:DD:EE:FF true` | device may wake the system |
| `qs ipc call n0ctos-bluetooth setName AA:BB:CC:DD:EE:FF Headphones` | alias becomes `Headphones` |

Device addresses are case-insensitive:

```bash
qs ipc call n0ctos-bluetooth connect AA:BB:CC:DD:EE:FF
```

```bash
qs ipc call n0ctos-bluetooth disconnect aa:bb:cc:dd:ee:ff
```

Policy flags use bools:

```bash
qs ipc call n0ctos-bluetooth setTrusted \
    AA:BB:CC:DD:EE:FF \
    true
```

```bash
qs ipc call n0ctos-bluetooth setBlocked \
    AA:BB:CC:DD:EE:FF \
    false
```

```bash
qs ipc call n0ctos-bluetooth setWakeAllowed \
    AA:BB:CC:DD:EE:FF \
    true
```

Rename:

```bash
qs ipc call n0ctos-bluetooth setName \
    AA:BB:CC:DD:EE:FF \
    Headphones
```

List operations return JSON strings. Pipe through `jq` when available:

```bash
qs ipc call n0ctos-bluetooth getDevices | jq .
```

```bash
qs ipc call n0ctos-bluetooth getConnectedDevices | jq .
```

```bash
qs ipc call n0ctos-bluetooth getStatus | jq .
```

---

# 4. Features / limitations

## Features

### Multi-adapter tracking

The service exposes both the raw adapter model and convenient shortcuts:

```text
adapters
adapterList
adapterCount
defaultAdapter
```

Discovery operates across adapters:

```text
startDiscovery
    ↓
every enabled adapter
    discovering = true
```

```text
stopDiscovery
    ↓
every adapter
    discovering = false
```

This handles machines with more than one Bluetooth controller.

### Filtered device collections

The global device model is filtered into ready-to-bind lists:

```text
devices
    ├── connectedDevices
    ├── pairedDevices
    ├── bondedDevices
    ├── batteryDevices
    └── connectedBatteryDevices
```

Each collection exposes three forms:

```text
connectedDevices
connectedDeviceList
connectedDeviceCount
```

A component can bind to the count for a pill, the list for a menu, or the model for a view.

### Active device

The service resolves one headline device:

```text
first device.connected
    ↓
activeDevice
```

with derived properties:

```text
activeDeviceName
activeDeviceAddress
isDeviceConnected
hasDeviceBattery
activeDeviceBattery
activeDeviceBatteryRounded
activeDeviceBatteryText
```

A status bar therefore needs only:

```qml
Bluetooth.activeDeviceName
```

### Battery normalization

Quickshell reports battery as:

```text
0.0 -> 1.0
```

The service converts it to the public range:

```text
0 -> 100
```

For example:

```qml
Bluetooth.batteryPercent(
    device
)
```

returns a clamped percent, or `0` when battery is unavailable or non-finite.

`deviceInfo()` therefore contains:

```json
{
    "isBatteryAvailable": true,
    "battery": 82.0,
    "batteryRounded": 82,
    "batteryText": "82%"
}
```

and `null` battery fields when no battery is available.

### Per-device icons

Device icons are derived from both BlueZ icon text and the display name:

```qml
Bluetooth.deviceIconKey(
    device
)
```

The supported keys are:

```text
headphones
speaker
keyboard
mouse
gamepad
phone
tablet
laptop
printer
camera
television
bluetooth
```

For example, any source text containing:

```text
headset
headphone
earbud
```

maps to:

```text
headphones
```

`deviceIcon()` then maps each key to a Nerd Font glyph.

### Adapter icons

The headline icon reflects priority state:

```text
no adapter -> off
blocked -> off
disabling -> off
enabling -> on
discovering -> on
connected device -> connected
enabled -> on
otherwise -> off
```

Both forms are available:

```qml
Bluetooth.icon
```

```qml
Bluetooth.iconKey
```

### JSON serialization

Three serializers produce IPC- and UI-safe data:

```text
deviceInfo(device)
adapterInfo(adapter)
statusInfo()
```

A device object looks like:

```json
{
    "name": "WH-1000XM5",
    "deviceName": "WH-1000XM5",
    "address": "AA:BB:CC:DD:EE:FF",
    "dbusPath": "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF",
    "adapter": "hci0",
    "adapterName": "MyMachine",
    "state": "Connected",
    "isConnected": true,
    "isConnecting": false,
    "isDisconnecting": false,
    "isPaired": true,
    "isBonded": true,
    "isPairing": false,
    "isTrusted": true,
    "isBlocked": false,
    "isWakeAllowed": true,
    "isBatteryAvailable": true,
    "battery": 82.0,
    "batteryRounded": 82,
    "batteryText": "82%",
    "icon": "󰋋",
    "iconKey": "headphones"
}
```

An adapter object looks like:

```json
{
    "name": "MyMachine",
    "adapterId": "hci0",
    "dbusPath": "/org/bluez/hci0",
    "state": "Enabled",
    "isEnabled": true,
    "isDiscoverable": false,
    "isDiscovering": false,
    "isPairable": true,
    "discoverableTimeout": 0,
    "pairableTimeout": 0,
    "deviceCount": 3,
    "connectedDeviceCount": 1,
    "connectedDevices": []
}
```

A status object looks like:

```json
{
    "isAvailable": true,
    "isEnabled": true,
    "isPowered": true,
    "isBlocked": false,
    "isEnabling": false,
    "isDisabling": false,
    "state": "Enabled",
    "adapter": "MyMachine",
    "adapterId": "hci0",
    "isDiscoverable": false,
    "isDiscovering": false,
    "isPairable": true,
    "discoverableTimeout": 0,
    "pairableTimeout": 0,
    "adapterCount": 1,
    "deviceCount": 3,
    "connectedDeviceCount": 1,
    "pairedDeviceCount": 2,
    "bondedDeviceCount": 2,
    "batteryDeviceCount": 1,
    "activeDevice": "WH-1000XM5",
    "activeDeviceAddress": "AA:BB:CC:DD:EE:FF",
    "hasDeviceBattery": true,
    "activeDeviceBattery": 82,
    "icon": "󰂱",
    "iconKey": "bluetooth-connected"
}
```

### Reactive signals

Adapter and device insertions propagate immediately:

```text
BlueZ change
    │
    ▼
Quickshell model signal
    │
    ▼
Bluetooth signal
    │
    ▼
component binding reevaluates
```

Components can listen for:

```text
adapterAdded
adapterRemoved
deviceAdded
deviceRemoved
stateChangedExternally
adapterListUpdated
deviceListUpdated
```

### Guarded control

Control functions fail safely:

```text
setEnabled
setDiscoverable
setPairable
    ↓
no default adapter -> return
```

```text
connectDevice
    ↓
unknown address -> return
blocked device -> return
```

```text
pairDevice
    ↓
unknown -> return
already paired -> return
already pairing -> return
```

```text
cancelPairDevice
    ↓
not pairing -> return
```

This prevents common BlueZ errors from throwing in QML.

### Case-insensitive lookup

Both lookup helpers normalize case:

```qml
Bluetooth.findDevice(
    "aa:bb:cc:dd:ee:ff"
)
```

matches:

```text
AA:BB:CC:DD:EE:FF
```

and:

```qml
Bluetooth.findDeviceByName(
    "wh-1000xm5"
)
```

matches:

```text
WH-1000XM5
```

### No polling

The service does not repeatedly scan BlueZ.

It relies on Quickshell's reactive adapter/device models and `Connections` handlers.

### No Config dependency

The service does not use `Config`.

There is no:

```text
bluetooth profile
bluetooth persistence
homeConfig section
```

Bluetooth state lives in BlueZ, not in N0ctOS configuration files.

---

## Limitations

### Requires a Bluetooth adapter

Without hardware or BlueZ:

```text
adapterCount = 0
defaultAdapter = null
isAvailable = false
stateName = "Disabled"
icon = off
activeDevice = null
```

Control calls become no-ops.

Check `isAvailable` before showing controls that assume hardware exists.

### Default-adapter writes

Power, discoverable, and pairable controls target:

```text
defaultAdapter
```

only.

For example:

```qml
Bluetooth.setEnabled(
    true
)
```

does not power every adapter individually.

Discovery is the exception: it iterates `adapterList`.

### Discovery only starts on enabled adapters

`startDiscovery()` skips adapters where:

```text
enabled = false
```

A disabled adapter therefore stays non-discovering even after a global start request.

### Blocked devices cannot connect

`connectDevice()` returns early when:

```text
device.blocked = true
```

Unblock the device first:

```qml
Bluetooth.setDeviceBlocked(
    address,
    false
)
```

then connect.

### Pairing guards are silent

`pairDevice()` ignores:

```text
unknown address
already paired
already pairing
```

and `cancelPairDevice()` ignores devices that are not pairing.

There is no returned error. Inspect device state when pairing behavior matters:

```qml
Bluetooth.isDeviceConnecting(
    device
)
```

```qml
Bluetooth.deviceStateName(
    device
)
```

### Active device is first-connected only

`activeDevice` is:

```text
the first device with connected = true
```

It is not a user-selected favorite, most-recent device, or audio-routing choice.

With multiple connected devices, only the first is surfaced as active.

### Display name is a fallback chain

`displayName()` uses:

```text
device.name trimmed
    ↓
device.deviceName
    ↓
""
```

An empty or whitespace-only alias therefore falls through to `deviceName`.

`findDeviceByName()` matches against that resolved display name, not the raw alias alone.

### Battery requires availability

`batteryPercent()` returns `0` unless:

```text
device.batteryAvailable = true
```

and the value is finite.

`deviceInfo()` uses `null` for `battery` and `batteryRounded` when unavailable, so UI code must handle:

```json
{
    "battery": null
}
```

### Serialized objects are snapshots

`deviceInfo()`, `adapterInfo()`, and `statusInfo()` return plain cloned data.

For example:

```qml
Bluetooth.deviceInfo(
    device
).isConnected
```

does not update when the device disconnects.

Bind to live properties such as:

```qml
device.connected
```

or:

```qml
Bluetooth.connectedDeviceCount
```

for reactive UI.

### No auto-reconnect or agent handling

The service does not implement:

```text
auto-reconnect policy
pairing-agent prompts
PIN handling
audio-profile switching
```

Those remain BlueZ / desktop responsibilities.

---

# 5. Example use cases

## 5.1 A panel toggle

A status pill only needs power, icon, and availability:

```qml
import QtQuick
import Quickshell

import qs.services

Item {
    readonly property bool available:
        Bluetooth.isAvailable

    readonly property bool enabled:
        Bluetooth.isEnabled

    readonly property string icon:
        Bluetooth.icon

    readonly property string label:
        !available
            ? "No Bluetooth"
            : enabled
                ? Bluetooth.activeDeviceName !== ""
                    ? Bluetooth.activeDeviceName
                    : "On"
                : "Off"
}
```

Toggle on click:

```qml
MouseArea {
    anchors.fill:
        parent

    enabled:
        Bluetooth.isAvailable

    onClicked:
        Bluetooth.setEnabled(
            !Bluetooth.isEnabled
        )
}
```

The icon updates automatically through:

```text
isAvailable
isBlocked
isEnabling / isDisabling
isDiscovering
connectedDeviceCount
isEnabled
```

---

## 5.2 A connected-device list

Bind directly to the filtered list:

```qml
import QtQuick
import Quickshell

import qs.services

Column {
    spacing: 8

    Repeater {
        model:
            Bluetooth.connectedDeviceList

        delegate: Row {
            required property var modelData

            spacing: 8

            Text {
                text:
                    Bluetooth.deviceIcon(
                        modelData
                    )
            }

            Text {
                text:
                    Bluetooth.displayName(
                        modelData
                    )
            }

            Text {
                visible:
                    modelData.batteryAvailable

                text:
                    Bluetooth.batteryPercent(
                        modelData
                    ).toFixed(0) + "%"
            }
        }
    }
}
```

For a paired-device settings page, use:

```qml
model:
    Bluetooth.pairedDeviceList
```

For a battery-only view, use:

```qml
model:
    Bluetooth.connectedBatteryDeviceList
```

---

## 5.3 Showing the active device and battery

The headline device needs no list scan:

```qml
Text {
    visible:
        Bluetooth.isDeviceConnected

    text:
        Bluetooth.activeDeviceName
}
```

```qml
Text {
    visible:
        Bluetooth.hasDeviceBattery

    text:
        Bluetooth.activeDeviceBatteryText
}
```

The rounded value is useful for progress display:

```qml
ProgressBar {
    visible:
        Bluetooth.hasDeviceBattery

    from: 0
    to: 100

    value:
        Bluetooth.activeDeviceBatteryRounded
}
```

When no device is connected:

```text
activeDevice = null
activeDeviceName = ""
isDeviceConnected = false
hasDeviceBattery = false
activeDeviceBatteryText = ""
```

so gate battery UI on `hasDeviceBattery`.

---

## 5.4 Connecting and disconnecting one device

Connect by address:

```qml
Bluetooth.connectDevice(
    "AA:BB:CC:DD:EE:FF"
)
```

Disconnect:

```qml
Bluetooth.disconnectDevice(
    "AA:BB:CC:DD:EE:FF"
)
```

A row button might look like:

```qml
MouseArea {
    anchors.fill:
        parent

    onClicked: {
        if (modelData.connected) {
            Bluetooth.disconnectDevice(
                modelData.address
            )
        } else {
            Bluetooth.connectDevice(
                modelData.address
            )
        }
    }
}
```

Blocked devices refuse to connect. Unblock first:

```qml
Bluetooth.setDeviceBlocked(
    "AA:BB:CC:DD:EE:FF",
    false
)
```

---

## 5.5 Pairing workflow

Pair a discovered device:

```qml
Bluetooth.pairDevice(
    "AA:BB:CC:DD:EE:FF"
)
```

Cancel an in-progress pairing:

```qml
Bluetooth.cancelPairDevice(
    "AA:BB:CC:DD:EE:FF"
)
```

Forget it entirely:

```qml
Bluetooth.forgetDevice(
    "AA:BB:CC:DD:EE:FF"
)
```

Pairing state can be shown with:

```qml
readonly property string state:
    Bluetooth.deviceStateName(
        device
    )

readonly property bool busy:
    Bluetooth.isDeviceConnecting(
        device
    ) || Bluetooth.isDeviceDisconnecting(
        device
    ) || (device
        ? device.pairing
        : false)
```

---

## 5.6 Device policy controls

Trust a device for easier reconnection:

```qml
Bluetooth.setDeviceTrusted(
    "AA:BB:CC:DD:EE:FF",
    true
)
```

Block or unblock:

```qml
Bluetooth.setDeviceBlocked(
    "AA:BB:CC:DD:EE:FF",
    false
)
```

Allow wake from the device:

```qml
Bluetooth.setDeviceWakeAllowed(
    "AA:BB:CC:DD:EE:FF",
    true
)
```

Rename its alias:

```qml
Bluetooth.setDeviceName(
    "AA:BB:CC:DD:EE:FF",
    "Headphones"
)
```

Lookup is case-insensitive, so lower-case addresses work.

---

## 5.7 Reacting to adapter and device changes

Log hotplug and discovery results:

```qml
Connections {
    target: Bluetooth

    function onAdapterAdded(adapter) {
        console.log(
            "adapter added:",
            Bluetooth.adapterInfo(adapter).adapterId
        )
    }

    function onAdapterRemoved(adapter) {
        console.log("adapter removed")
    }

    function onDeviceAdded(device) {
        console.log(
            "device found:",
            Bluetooth.displayName(device),
            Bluetooth.deviceStateName(device)
        )
    }

    function onDeviceRemoved(device) {
        console.log("device removed")
    }

    function onDeviceListUpdated() {
        console.log(
            "devices:",
            Bluetooth.deviceCount,
            "connected:",
            Bluetooth.connectedDeviceCount
        )
    }
}
```

Use `adapterListUpdated` for adapter-count UI and `deviceListUpdated` for list refresh side effects.

---

## 5.8 Inspecting serialized state

A developer can inspect one device:

```qml
Text {
    text:
        JSON.stringify(
            Bluetooth.deviceInfo(
                Bluetooth.activeDevice
            ),
            null,
            2
        )
}
```

or the whole service:

```qml
Text {
    text:
        JSON.stringify(
            Bluetooth.statusInfo(),
            null,
            2
        )
}
```

For example:

```json
{
    "isAvailable": true,
    "isEnabled": true,
    "state": "Enabled",
    "adapter": "MyMachine",
    "deviceCount": 3,
    "connectedDeviceCount": 1,
    "activeDevice": "WH-1000XM5",
    "iconKey": "bluetooth-connected"
}
```

This is useful when debugging IPC output or device filtering.

---

## 5.9 Terminal workflow

Inspect the complete service:

```bash
qs ipc call n0ctos-bluetooth getStatus | jq .
```

Check power and identity:

```bash
qs ipc call n0ctos-bluetooth getEnabled
```

```bash
qs ipc call n0ctos-bluetooth getAdapter
```

```bash
qs ipc call n0ctos-bluetooth getAdapterId
```

```bash
qs ipc call n0ctos-bluetooth getState
```

Toggle power:

```bash
qs ipc call n0ctos-bluetooth toggle
```

Scan for devices:

```bash
qs ipc call n0ctos-bluetooth startDiscovery
```

```bash
qs ipc call n0ctos-bluetooth getDevices | jq .
```

```bash
qs ipc call n0ctos-bluetooth stopDiscovery
```

Connect and manage one device:

```bash
qs ipc call n0ctos-bluetooth connect AA:BB:CC:DD:EE:FF
```

```bash
qs ipc call n0ctos-bluetooth getConnectedDevices | jq .
```

```bash
qs ipc call n0ctos-bluetooth disconnect AA:BB:CC:DD:EE:FF
```

Pair and trust:

```bash
qs ipc call n0ctos-bluetooth pair AA:BB:CC:DD:EE:FF
```

```bash
qs ipc call n0ctos-bluetooth setTrusted AA:BB:CC:DD:EE:FF true
```

```bash
qs ipc call n0ctos-bluetooth forget AA:BB:CC:DD:EE:FF
```

---

# 6. Detailed architecture

This section is for developers working on `Bluetooth.qml` and the services/components that consume it.

---

## 6.1 Overall architecture

The service is a hardware-state layer over Quickshell Bluetooth.

```text
BlueZ (adapters + Device1 objects)
             │
             ▼
Quickshell.Bluetooth
   ├── Bluetooth.adapters
   ├── Bluetooth.defaultAdapter
   └── Bluetooth.devices
             │
             ▼
N0ctOS Bluetooth.qml
   ├── adapter properties
   ├── ScriptModel filters
   ├── active device
   ├── control functions
   ├── helpers / icons
   └── serialization + IPC
             │
             ▼
N0ctOS Component / terminal
```

There are effectively two responsibilities:

```text
Quickshell.Bluetooth
    BlueZ access and object models

N0ctOS Bluetooth.qml
    shell-friendly properties and actions
```

The N0ctOS service should not reimplement BlueZ discovery, pairing, or D-Bus handling.

---

## 6.2 Backend layer

The backend section exposes Quickshell objects directly:

```text
adapters
adapterList
adapterCount
defaultAdapter
devices
deviceList
deviceCount
```

Derived state is computed from the default adapter:

```text
isAvailable
isEnabled / isPowered
isBlocked
isEnabling
isDisabling
stateName
```

For example:

```text
isAvailable
    =
adapterCount > 0
    AND
defaultAdapter exists
```

and:

```text
stateName
    =
defaultAdapter
    ? BluetoothAdapterState.toString(state)
    : "Disabled"
```

This gives components safe values even on machines without Bluetooth.

---

## 6.3 Default-adapter properties

Adapter identity and mode come from the default adapter:

```text
adapterName
adapterId
adapterDbusPath
isDiscoverable
isDiscovering
isPairable
discoverableTimeout
pairableTimeout
```

Missing hardware returns:

```text
"" for strings
0 for timeouts
false for bools
```

Timeouts are numeric:

```text
Number(adapter.discoverableTimeout)
```

so QML bindings always see an `int`.

---

## 6.4 Filtered device models

Five `ScriptModel` objects filter the global device list:

```text
connectedDeviceModel
    device.connected

pairedDeviceModel
    device.paired

bondedDeviceModel
    device.bonded

batteryDeviceModel
    device.batteryAvailable

connectedBatteryDeviceModel
    device.connected
        AND
    device.batteryAvailable
```

Each filter exposes:

```text
<name>
<name>List
<name>Count
```

For example:

```text
connectedDevices
connectedDeviceList
connectedDeviceCount
```

The filters are reactive: when `deviceList` changes, each model reevaluates.

---

## 6.5 Active device

The active device is derived:

```text
deviceList
    │
    ▼
findFirstConnectedDevice()
    │
    ▼
activeDevice
```

Derived properties follow:

```text
activeDevice
    ├── activeDeviceName = displayName(activeDevice)
    ├── activeDeviceAddress = address
    ├── isDeviceConnected = !!activeDevice
    ├── hasDeviceBattery = batteryAvailable
    ├── activeDeviceBattery = batteryPercent(activeDevice)
    ├── activeDeviceBatteryRounded = round(battery)
    └── activeDeviceBatteryText = rounded + "%"
```

When no device is connected:

```text
activeDevice = null
activeDeviceName = ""
activeDeviceAddress = ""
isDeviceConnected = false
```

---

## 6.6 Signal tracking

Two `Connections` blocks watch adapters:

```text
Bluetooth.onDefaultAdapterChanged
    ↓
stateChangedExternally()
adapterListUpdated()

Bluetooth.adapters.onObjectInsertedPost
    ↓
adapterAdded(adapter)
adapterListUpdated()
stateChangedExternally()

Bluetooth.adapters.onObjectRemovedPost
    ↓
adapterRemoved(adapter)
adapterListUpdated()
stateChangedExternally()
```

One block watches devices:

```text
Bluetooth.devices.onObjectInsertedPost
    ↓
deviceAdded(device)
deviceListUpdated()
stateChangedExternally()

Bluetooth.devices.onObjectRemovedPost
    ↓
deviceRemoved(device)
deviceListUpdated()
stateChangedExternally()
```

Per-device property changes (such as `connected` flipping) flow through Quickshell model reactivity rather than explicit N0ctOS signals.

---

## 6.7 Adapter control semantics

`setEnabled()` is a guarded write:

```text
setEnabled(enabled)
    │
    ▼
defaultAdapter exists?
    │
┌───┴───┐
no     yes
│        │
▼        ▼
return  adapter.enabled = Boolean(enabled)
```

`setDiscoverable()` and `setPairable()` follow the same pattern.

Timeouts clamp negatives:

```text
Math.max(0, Number(seconds))
```

Discovery iterates rather than targeting one adapter:

```text
startDiscovery
    │
    ▼
for each adapter
    │
    ▼
enabled?
    │
┌───┴───┐
no     yes
│        │
▼        ▼
skip   discovering = true
```

```text
stopDiscovery
    │
    ▼
for each adapter
    discovering = false
```

---

## 6.8 Device lookup semantics

`findDevice()` normalizes both sides:

```text
String(address || "")
    ↓
lowercase compare
    ↓
device.address
```

Empty input returns:

```text
null
```

`findDeviceByName()` compares resolved display names:

```text
displayName(device).toLowerCase()
    ===
wanted.toLowerCase()
```

This means a search for:

```text
wh-1000xm5
```

finds:

```text
WH-1000XM5
```

---

## 6.9 Connection and pairing guards

Connection refuses blocked hardware:

```text
connectDevice(address)
    │
    ▼
findDevice()
    │
┌───┴───┐
null   found
│        │
▼        ▼
return  blocked?
            │
        ┌───┴───┐
       yes      no
        │        │
        ▼        ▼
      return  device.connect()
```

Pairing has three guards:

```text
pairDevice(address)
    │
    ▼
unknown -> return
paired -> return
pairing -> return
    │
    ▼
device.pair()
```

Cancellation is the inverse:

```text
cancelPairDevice(address)
    │
    ▼
not pairing -> return
    │
    ▼
device.cancelPair()
```

`disconnectDevice()` and `forgetDevice()` only guard unknown addresses.

---

## 6.10 Policy control

Policy writes are thin wrappers:

```text
setDeviceTrusted(address, trusted)
    → device.trusted = Boolean(trusted)

setDeviceBlocked(address, blocked)
    → device.blocked = Boolean(blocked)

setDeviceWakeAllowed(address, allowed)
    → device.wakeAllowed = Boolean(allowed)

setDeviceName(address, name)
    → device.name = String(name || "")
```

Each one returns silently when the address is unknown.

---

## 6.11 Display and battery helpers

`displayName()` implements:

```text
device = null -> ""
name.trim() !== "" -> name
otherwise -> deviceName
otherwise -> ""
```

`batteryPercent()` implements:

```text
null -> 0
!batteryAvailable -> 0
non-finite -> 0
otherwise -> clamp(value * 100, 0, 100)
```

The multiplication exists because Quickshell uses:

```text
0.0 -> 1.0
```

while the shell uses:

```text
0 -> 100
```

---

## 6.12 Device state helpers

`deviceStateName()` wraps:

```qml
BluetoothDeviceState.toString(
    device.state
)
```

and returns `"Unknown"` for null.

Connection transitions expose:

```text
isDeviceConnecting
    state === Connecting

isDeviceDisconnecting
    state === Disconnecting
```

These are useful for spinners and disabled buttons during BlueZ transitions.

---

## 6.13 Icon mapping

Device icon keys match substrings in:

```text
(device.icon + " " + displayName).toLowerCase()
```

The match order is:

```text
headset / headphone / earbud -> headphones
speaker -> speaker
keyboard -> keyboard
mouse -> mouse
gamepad / joystick -> gamepad
phone / smartphone -> phone
tablet -> tablet
computer / laptop -> laptop
printer -> printer
camera -> camera
tv / display -> television
otherwise -> bluetooth
```

`deviceIcon()` maps each key to one glyph.

Adapter icons use priority order:

```text
!isAvailable -> off
isBlocked -> off
isDisabling -> off
isEnabling -> on
isDiscovering -> on
connectedDeviceCount > 0 -> connected
isEnabled -> on
otherwise -> off
```

Icon keys use stable names for theming:

```text
bluetooth-off
bluetooth-blocked
bluetooth-discovering
bluetooth-connected
bluetooth
```

---

## 6.14 Serialization architecture

Serializers convert live Quickshell objects into plain data:

```text
live device object
    │
    ▼
deviceInfo()
    │
    ▼
plain object
    │
    ▼
JSON.stringify for IPC
```

`deviceInfo()` includes:

```text
name
deviceName
address
dbusPath
adapter
adapterName
state
isConnected
isConnecting
isDisconnecting
isPaired
isBonded
isPairing
isTrusted
isBlocked
isWakeAllowed
isBatteryAvailable
battery
batteryRounded
batteryText
icon
iconKey
```

`adapterInfo()` includes its own connected-device snapshots:

```text
adapter.devices.values
    ↓
filter connected
    ↓
deviceInfo(each)
    ↓
connectedDevices[]
```

`statusInfo()` aggregates headline state plus counts:

```text
adapter state
discovery state
adapterCount
deviceCount
connectedDeviceCount
pairedDeviceCount
bondedDeviceCount
batteryDeviceCount
activeDevice
icon
iconKey
```

---

## 6.15 Discovery lifecycle

A full scan follows:

```text
startDiscovery()
        │
        ▼
enabled adapters discovering = true
        │
        ▼
BlueZ reports devices
        │
        ▼
Bluetooth.devices inserts objects
        │
        ▼
deviceAdded()
deviceListUpdated()
        │
        ▼
filtered models reevaluate
        │
        ▼
stopDiscovery()
        │
        ▼
adapters discovering = false
```

Components should start discovery when a Bluetooth page opens and stop it when the page closes.

---

## 6.16 Connection lifecycle

A connection follows:

```text
connectDevice(address)
        │
        ▼
device.connect()
        │
        ▼
device.state = Connecting
        │
        ▼
device.connected = true
        │
        ▼
connectedDeviceList changes
        │
        ▼
activeDevice may change
        │
        ▼
icon may change to connected
```

Disconnection follows the reverse path and may clear `activeDevice`.

---

## 6.17 Pairing lifecycle

Pairing follows:

```text
pairDevice(address)
        │
        ▼
device.pair()
        │
        ▼
device.pairing = true
        │
        ▼
BlueZ agent / confirmation
        │
        ▼
device.paired = true
device.pairing = false
```

Cancellation interrupts it:

```text
cancelPairDevice(address)
        │
        ▼
device.cancelPair()
        │
        ▼
device.pairing = false
```

Forgetting removes the object:

```text
forgetDevice(address)
        │
        ▼
device.forget()
        │
        ▼
deviceRemoved()
```

---

## 6.18 IPC architecture

IPC is a thin external interface over the same service API.

Conceptually:

```text
terminal
   │
   ▼
n0ctos-bluetooth
   │
   ▼
Bluetooth.qml
   │
   ▼
Quickshell.Bluetooth
   │
   ▼
BlueZ
```

For example:

```bash
qs ipc call n0ctos-bluetooth connect AA:BB:CC:DD:EE:FF
```

becomes conceptually:

```qml
Bluetooth.connectDevice(
    "AA:BB:CC:DD:EE:FF"
)
```

The IPC layer serializes bools as `"true"`/`"false"` strings and device lists as JSON strings.

---

## 6.19 Why IPC stays high-level

IPC should expose useful Bluetooth operations, not internal implementation.

External callers do not need to know about:

```text
raw ObjectModel
ScriptModel filters
Connections handlers
battery 0.0 -> 1.0 conversion
icon substring matching
first-connected resolution
```

They only need:

```text
getStatus
getState
getEnabled / setEnabled / toggle
startDiscovery / stopDiscovery
getDevices
connect / disconnect
pair / cancelPair / forget
setTrusted / setBlocked / setWakeAllowed / setName
```

This keeps the IPC interface stable even if the internal filtering changes.

---

## 6.20 Performance model

Bluetooth is intended to be cheap during normal UI operation.

A component read such as:

```qml
Bluetooth.connectedDeviceCount
```

does not perform D-Bus I/O.

D-Bus is handled by Quickshell.

The N0ctOS service operates on already-loaded reactive models.

Normal runtime work is therefore:

```text
QML binding
    ↓
Bluetooth
    ↓
in-memory model lookup
```

rather than:

```text
QML binding
    ↓
D-Bus
    ↓
BlueZ scan
    ↓
lookup
```

---

## 6.21 No polling

Bluetooth does not use a polling timer to detect devices.

There is no:

```qml
Timer {
    interval: 1000
    repeat: true

    onTriggered:
        reloadBluetooth()
}
```

Changes propagate through Quickshell's reactive Bluetooth models.

This avoids unnecessary CPU and radio activity.

---

## 6.22 Service boundaries

The responsibilities are intentionally divided:

```text
N0ctOS Bluetooth.qml
    adapter properties
    filtered collections
    active device
    control actions
    display and icon helpers
    serialization
    IPC

Quickshell.Bluetooth
    adapter objects
    device objects
    D-Bus communication
    discovery implementation
    connection implementation

BlueZ
    hardware control
    pairing state
    audio and HID handling
```

N0ctOS code should not duplicate BlueZ protocol handling.

---

## 6.23 No Config ownership

Unlike configuration services, Bluetooth owns no config section.

There is no:

```text
bluetooth.profile
bluetooth.settings
homeConfig section
```

Device trust, pairing, and adapter power live in BlueZ.

The service is therefore stateless across restarts except for what BlueZ itself remembers.

---

## 6.24 What UI / service code should not do

Components should not:

```text
import Quickshell.Bluetooth directly for common tasks

scan Bluetooth.devices.values manually when a filter exists

reimplement battery 0.0 -> 100 conversion

reimplement display-name fallback

reimplement device icon matching

mutate deviceInfo() output and expect hardware changes

assume activeDevice is non-null

assume an adapter always exists

poll BlueZ on a timer
```

Instead:

```qml
Bluetooth.isEnabled
Bluetooth.connectedDeviceList
Bluetooth.activeDeviceName
Bluetooth.batteryPercent(device)
Bluetooth.displayName(device)
Bluetooth.deviceIcon(device)
Bluetooth.connectDevice(address)
Bluetooth.deviceInfo(device)
```

should be the normal interface.

---

## 6.25 Final architecture summary

The entire system can be viewed as:

```text
                         Component
                            │
                            │ properties / actions
                            ▼
                    ┌─────────────────┐
                    │    Bluetooth    │
                    │                 │
                    │ adapter state   │
                    │ device filters  │
                    │ active device   │
                    │ control         │
                    │ helpers / icons │
                    │ serialization   │
                    │ IPC             │
                    └────────┬────────┘
                             │
                             │ Quickshell API
                             ▼
                    ┌─────────────────┐
                    │ Quickshell      │
                    │ Bluetooth       │
                    │                 │
                    │ adapters        │
                    │ devices         │
                    │ D-Bus / BlueZ   │
                    └────────┬────────┘
                             │
                             ▼
                            BlueZ
```

The core rule is:

> **Components describe what Bluetooth state or action they need; `Bluetooth.qml` resolves it from Quickshell models and BlueZ; Quickshell handles how hardware communication actually happens.**
