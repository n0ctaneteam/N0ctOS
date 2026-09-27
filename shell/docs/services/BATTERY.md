# Battery Service

`Battery.qml` is N0ctOS's centralized battery and power-state service.

It gives every shell component one consistent place to read battery charge, charging state, time estimates, health, icons, and the physical battery list without touching UPower directly.

The service supports aggregate display-device state, physical-battery health, low/critical thresholds, bucketed Nerd Font icons, freedesktop icon keys, duration formatting, per-device info, hotplug signals, and a read-only IPC interface.

The normal usage pattern is:

```text
Component
    │
    ▼
Battery
    │
    ├── display device state
    ├── physical battery health
    └── resolved text + icons
    │
    ▼
UPower
    │
    ▼
system power hardware
```

---

# 1. What does it do?

`Battery.qml` exposes the current power state for the shell.

A component can read a simple value:

```qml
Battery.percentText
```

or a simple state flag:

```qml
Battery.isCharging
```

or a ready-made icon:

```qml
Battery.icon
```

More detailed state is also available:

```json
{
    "percent": 72,
    "state": "discharging",
    "timeRemainingText": "2h 15m",
    "health": 91.0,
    "icon": "󰂀"
}
```

The effective charge is resolved in this order:

```text
UPower.displayDevice.percentage (0.0 -> 1.0)
    ↓
clamp 0 -> 100
    ↓
Battery.percent / percentRounded / percentText
```

So a component can simply do:

```qml
Text {
    text:
        Battery.percentText
}
```

and not care where the value came from.

If no battery hardware exists, the service returns safe fallbacks (`0`, `""`, `false`) instead of failing.

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
| `Battery.percent` | Charge 0 -> 100, clamped, from `displayDevice.percentage * 100`. `0` when not ready. |
| `Battery.percentRounded` | `Math.round(percent)`. |
| `Battery.percentText` | `"72%"` style text. |
| `Battery.isReady` | `true` when `displayDevice` exists and is ready. |
| `Battery.isPresent` | `true` when a physical laptop battery exists and is present. |
| `Battery.isOnBattery` | `UPower.onBattery`. |
| `Battery.isPluggedIn` | Battery present and not on battery. |
| `Battery.isCharging` | State is `Charging` or `PendingCharge`. |
| `Battery.isDischarging` | State is `Discharging` or `PendingDischarge`. |
| `Battery.isFull` | State is `FullyCharged` or `percent >= 99`. |
| `Battery.isLow` | Present, not charging, `percent <= 20`, and not critical. |
| `Battery.isCritical` | Present, not charging, `percent <= 10`. |
| `Battery.lowThreshold` | Low-battery threshold (`20`). |
| `Battery.criticalThreshold` | Critical-battery threshold (`10`). |
| `Battery.timeToEmpty` | Seconds to empty from `displayDevice`, `0` when not ready. |
| `Battery.timeToFull` | Seconds to full from `displayDevice`, `0` when not ready. |
| `Battery.timeRemaining` | `timeToFull` when charging, otherwise `timeToEmpty`. |
| `Battery.timeRemainingText` | `"2h 15m"` / `"45m"` / `""` when unknown. |
| `Battery.energy` | Current energy from `displayDevice`, `0` when not ready. |
| `Battery.energyCapacity` | Design energy from `displayDevice`, `0` when not ready. |
| `Battery.changeRate` | Charge/discharge rate from `displayDevice`, `0` when not ready. |
| `Battery.isHealthSupported` | `true` when the physical battery reports health. |
| `Battery.health` | Health 0 -> 100 from the physical battery, `0` when unsupported. |
| `Battery.healthRounded` | `Math.round(health)`. |
| `Battery.healthText` | `"91%"` when supported, `""` when unsupported. |
| `Battery.state` | Raw `UPowerDeviceState` enum, `Unknown` when not ready. |
| `Battery.stateName` | `"charging"`, `"discharging"`, `"fully-charged"`, etc. |
| `Battery.model` | Display-device model string, `""` when not ready. |
| `Battery.nativePath` | Display-device native path, `""` when not ready. |
| `Battery.icon` | Nerd Font glyph for current charge/state. |
| `Battery.iconKey` | Freedesktop icon name (`battery-70`, `battery-charging-60`, etc.). |
| `Battery.device` | Raw `UPower.displayDevice` object. |
| `Battery.primaryBattery` | First physical laptop battery, or `null`. |
| `Battery.batteries` | `ScriptModel` of laptop batteries for `ListView`. |
| `Battery.batteryList` | Plain JS array of laptop batteries. |
| `Battery.batteryCount` | Number of physical laptop batteries. |

## Helpers and signals

| How to call | What does it do |
| ----------- | --------------- |
| `Battery.percentBucket(percent)` | Maps 0 -> 100 to `0, 10, 20, ... 90, 100`. |
| `Battery.iconFor(percent, charging, critical, full)` | Returns the Nerd Font glyph for the given state. |
| `Battery.iconKeyFor(percent, charging, critical, full)` | Returns the freedesktop icon name for the given state. |
| `Battery.formatDuration(seconds)` | Formats seconds as `"2h 15m"` / `"45m"`, `""` when unknown. |
| `Battery.deviceInfo(device)` | Returns a plain info object for one UPower device, `{}` when null. |
| `Battery.deviceAdded(device)` | Signal emitted when a UPower device appears. |
| `Battery.deviceRemoved(device)` | Signal emitted when a UPower device disappears. |
| `Battery.stateChangedExternally()` | Declared signal for external state changes. |

| Example | Result |
| ------- | ------ |
| `Battery.percentBucket(72)` | `70` |
| `Battery.iconFor(72, false, false, false)` | Nerd Font glyph for 70 % discharging |
| `Battery.iconKeyFor(72, false, false, false)` | `"battery-70"` |
| `Battery.formatDuration(8100)` | `"2h 15m"` |
| `Battery.deviceInfo(Battery.primaryBattery)` | `{model, percent, state, ...}` info object, `{}` when null |

### Typical component usage

```qml
Text {
    text:
        Battery.percentText
}

Text {
    visible:
        Battery.isCharging ||
        Battery.isDischarging

    text:
        Battery.timeRemainingText
}

Text {
    text:
        Battery.icon
}
```

That is the intended everyday usage.

Components normally should not need to know how `displayDevice`, physical batteries, buckets, or UPower enums work.

---

# 3. IPC API

IPC target:

```text
n0ctos-battery
```

The service is read-only. There are no `set` / `remove` operations.

## Core reads

| How to call | What does it do |
| ----------- | --------------- |
| `getPercent` | Returns `percentText`, e.g. `"72%"`. |
| `getState` | Returns `stateName`, e.g. `"discharging"`. |
| `getTimeRemaining` | Returns `timeRemainingText`, e.g. `"2h 15m"` or `""`. |
| `getHealth` | Returns `healthText`, e.g. `"91%"` or `""`. |
| `getIcon` | Returns the current Nerd Font icon glyph. |

| Example | Result |
| ------- | ------ |
| `qs ipc call n0ctos-battery getPercent` | `"72%"` |
| `qs ipc call n0ctos-battery getState` | `"discharging"` |
| `qs ipc call n0ctos-battery getTimeRemaining` | `"2h 15m"`, or `""` when unknown |
| `qs ipc call n0ctos-battery getHealth` | `"91%"`, or `""` when unsupported |
| `qs ipc call n0ctos-battery getIcon` | Nerd Font glyph for the current charge/state |

For example:

```bash
qs ipc call n0ctos-battery getPercent
```

returns:

```text
72%
```

```bash
qs ipc call n0ctos-battery getState
```

returns:

```text
discharging
```

```bash
qs ipc call n0ctos-battery getTimeRemaining
```

returns:

```text
2h 15m
```

or an empty string when the estimate is unknown.

## Other operations

| How to call | What does it do |
| ----------- | --------------- |
| `getStatus` | Returns the full normalized status as a JSON string. |
| `getDevices` | Returns one info object per physical laptop battery as a JSON string. |

| Example | Result |
| ------- | ------ |
| `qs ipc call n0ctos-battery getStatus` | JSON status object (see below) |
| `qs ipc call n0ctos-battery getDevices` | JSON array with one info object per physical battery |

`getStatus` returns:

```json
{
    "isPresent": true,
    "isReady": true,
    "isOnBattery": true,
    "isPluggedIn": false,
    "isCharging": false,
    "isDischarging": true,
    "isFull": false,
    "isLow": false,
    "isCritical": false,
    "isHealthSupported": true,
    "percent": 72,
    "state": "discharging",
    "timeRemaining": 8100,
    "timeRemainingText": "2h 15m",
    "health": 91.0,
    "healthText": "91%",
    "icon": "󰂀"
}
```

When health is unsupported, `health` is `null` and `healthText` is `""`.

`getDevices` returns:

```json
[
    {
        "nativePath": "/org/freedesktop/UPower/devices/battery_BAT0",
        "model": "PABAS0241231",
        "type": "battery",
        "isReady": true,
        "isPresent": true,
        "isLaptopBattery": true,
        "isHealthSupported": true,
        "percent": 72,
        "health": 91.0,
        "isCharging": false,
        "isDischarging": true,
        "state": "discharging",
        "energy": 42.5,
        "energyCapacity": 50.0,
        "changeRate": 12.3,
        "timeToEmpty": 8100,
        "timeToFull": 0
    }
]
```

On a desktop with no battery, `getDevices` returns:

```json
[]
```

---

# 4. Features / limitations

## Features

### Aggregate display device

Charge, state, time, energy, and rate come from:

```text
UPower.displayDevice
```

This is the correct desktop-wide aggregate, not one raw kernel battery.

### Physical-battery health

Health comes from the real laptop battery:

```text
batteryList[0].healthPercentage
```

and never from:

```text
UPower.displayDevice.healthPercentage
```

because the aggregate device may not provide physical capacity data.

### Low and critical thresholds

The service defines:

```text
lowThreshold = 20
criticalThreshold = 10
```

`isLow` means:

```text
present
    +
not charging
    +
percent <= 20
    +
not critical
```

`isCritical` means:

```text
present
    +
not charging
    +
percent <= 10
```

This gives panels and notifications stable flags without reimplementing comparisons.

### Safe desktop fallbacks

On a desktop with no battery:

```text
percent = 0
percentText = "0%"
healthText = ""
timeRemainingText = ""
isPresent = false
batteryCount = 0
batteryList = []
primaryBattery = null
```

Components can bind directly without null checks on every property.

### Bucketed icons

`percentBucket()` maps charge to:

```text
0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100
```

`icon` then selects a Nerd Font glyph, with `critical` and `full` taking precedence over the bucket.

`iconKey` selects the matching freedesktop name, for example:

```text
battery-outline
battery-70
battery-charging-60
battery-alert
battery-charging-100
```

### Duration formatting

`formatDuration()` turns UPower seconds into:

```text
8100 -> "2h 15m"
2700 -> "45m"
0 / negative / infinite -> ""
```

`timeRemaining` already picks the right direction:

```text
charging -> timeToFull
otherwise -> timeToEmpty
```

### Battery list for single and multi-battery systems

`batteryModel` filters:

```text
UPower.devices.values
    ↓
isLaptopBattery only
```

and exposes both:

```text
batteries    -> ScriptModel for ListView
batteryList  -> plain JS array for loops
batteryCount -> array length
```

### Hotplug signals

The service watches:

```text
UPower.devices
```

and emits:

```text
deviceAdded(device)
deviceRemoved(device)
```

when UPower inserts or removes a device object.

### No polling

The service does not repeatedly query UPower on a timer.

It relies on Quickshell's reactive UPower bindings.

---

## Limitations

### Health requires a physical battery

If the system has no laptop battery, or the battery does not report health:

```text
isHealthSupported = false
health = 0
healthText = ""
```

`getStatus` then reports:

```json
{
    "health": null,
    "healthText": ""
}
```

Callers must handle the empty case.

### Time estimates can be empty

UPower reports `0` or non-finite values when it has no estimate.

The service passes that through as:

```text
""
```

A component should hide its time label when:

```qml
Battery.timeRemainingText === ""
```

### Only the first battery has dedicated properties

Top-level properties such as:

```text
health
isPresent
primaryBattery
```

describe:

```text
batteryList[0]
```

Additional batteries are only visible through:

```qml
Battery.batteryList
```

or:

```bash
qs ipc call n0ctos-battery getDevices
```

### Read-only service

Battery has no `set()`.

There is no:

```qml
Battery.set(...)
```

and no equivalent IPC write. Components cannot change charge, thresholds, or health through this service.

### Thresholds are fixed

`lowThreshold` and `criticalThreshold` are:

```qml
readonly property real lowThreshold: 20
readonly property real criticalThreshold: 10
```

They are not configurable through `Config` or IPC.

---

# 5. Example use cases

## 5.1 A panel showing charge and icon

A panel only needs two bindings:

```qml
import QtQuick
import Quickshell

import qs.services

Row {
    spacing: 6

    Text {
        text:
            Battery.icon
    }

    Text {
        text:
            Battery.percentText
    }
}
```

The component does not need to know whether the values came from:

```text
a charging laptop
a discharging laptop
a full battery
a desktop with no battery
```

It only receives the effective value.

---

## 5.2 Showing time remaining only when known

Time text is empty when UPower has no estimate:

```qml
import QtQuick

import qs.services

Text {
    visible:
        Battery.timeRemainingText !== ""

    text:
        Battery.isCharging
            ? "Full in " + Battery.timeRemainingText
            : Battery.timeRemainingText + " left"
}
```

The result is:

```text
charging, 8100s    -> "Full in 2h 15m"
discharging, 8100s -> "2h 15m left"
unknown            -> hidden
```

---

## 5.3 Low and critical warnings

Threshold logic is already resolved:

```qml
import QtQuick

import qs.services

Text {
    visible:
        Battery.isLow ||
        Battery.isCritical

    text:
        Battery.isCritical
            ? "Critical: " + Battery.percentText
            : "Low: " + Battery.percentText

    color:
        Battery.isCritical
            ? "#ff5555"
            : "#ffaa00"
}
```

No manual comparison against `20` or `10` is needed.

---

## 5.4 Listing physical batteries

`batteries` is a QML model, `batteryList` is a plain array:

```qml
import QtQuick

import qs.services

ListView {
    model:
        Battery.batteries

    delegate: Text {
        required property var modelData

        text:
            Battery.deviceInfo(
                modelData
            ).model +
            ": " +
            Battery.deviceInfo(
                modelData
            ).percent +
            "%"
    }
}
```

For imperative code, use the array form:

```qml
for (
    let i = 0;
    i < Battery.batteryList.length;
    ++i
) {
    const info =
        Battery.deviceInfo(
            Battery.batteryList[i]
        )

    console.log(
        info.model,
        info.percent
    )
}
```

---

## 5.5 Terminal workflow

Read the charge:

```bash
qs ipc call n0ctos-battery getPercent
```

Read the state:

```bash
qs ipc call n0ctos-battery getState
```

Read the remaining time:

```bash
qs ipc call n0ctos-battery getTimeRemaining
```

Read health:

```bash
qs ipc call n0ctos-battery getHealth
```

Read the icon:

```bash
qs ipc call n0ctos-battery getIcon
```

Inspect the complete service:

```bash
qs ipc call n0ctos-battery getStatus
```

Inspect every physical battery:

```bash
qs ipc call n0ctos-battery getDevices
```

---

# 6. Detailed architecture

This section is for developers working on `Battery.qml` and the services/components that consume it.

---

## 6.1 Overall architecture

The service is a normalization layer built on top of Quickshell's `UPower` service.

```text
N0ctOS Component / Service
            │
            ▼
      Battery.qml
            │
     ┌──────┼────────┐
     │      │        │
     ▼      ▼        ▼
 display physical  derived
 device  battery   text/icons
     │      │        │
     └──────┴────────┘
            │
            ▼
    Quickshell UPower
            │
            ▼
   system power hardware
```

There are effectively two responsibilities:

```text
Battery
    N0ctOS-friendly normalization

UPower
    hardware detection and raw state
```

Battery should not duplicate the hardware detection already provided by UPower.

---

## 6.2 Display device vs physical battery

Charge state and health come from different objects:

```text
displayDevice (aggregate)
    percent
    state
    timeToEmpty / timeToFull
    energy / energyCapacity / changeRate
    model / nativePath

batteryList[0] (physical)
    isPresent
    healthPercentage
    per-device info
```

The rule is:

```text
state and charge -> displayDevice
presence and health -> primaryBattery
```

This is why `isPresent` checks the physical battery while `isCharging` checks the display device.

---

## 6.3 Power-state derivation

Raw UPower state is mapped to boolean flags:

```text
Charging / PendingCharge       -> isCharging
Discharging / PendingDischarge -> isDischarging
FullyCharged or percent >= 99  -> isFull
```

Plug state is derived separately:

```text
isOnBattery = UPower.onBattery
isPluggedIn = isPresent && !isOnBattery
```

Low and critical add threshold checks:

```text
isLow      = present && !charging && percent <= 20 && !critical
isCritical = present && !charging && percent <= 10
```

A charging laptop at `5%` is therefore neither low nor critical.

---

## 6.4 Percent normalization

Quickshell exposes:

```text
UPowerDevice.percentage: 0.0 -> 1.0
```

The service exposes:

```text
Battery.percent: 0 -> 100
```

The conversion is:

```text
Number(device.percentage) * 100
    ↓
clamp 0 -> 100
    ↓
percent
    ↓
round -> percentRounded
    ↓
String + "%" -> percentText
```

When the device is not ready, `percent` is `0` and `percentText` is `"0%"`.

---

## 6.5 Health handling

Health is only read when supported:

```text
primaryBattery exists
    +
primaryBattery.ready
    +
primaryBattery.healthSupported
    ↓
isHealthSupported
```

Then:

```text
Number(primaryBattery.healthPercentage)
    ↓
clamp 0 -> 100
    ↓
health
    ↓
round -> healthRounded
    ↓
String + "%" -> healthText
```

When unsupported:

```text
health = 0
healthText = ""
getStatus.health = null
```

---

## 6.6 Time and energy handling

Time and energy are direct pass-throughs with a ready guard:

```text
ready ? Number(device.timeToEmpty) : 0
ready ? Number(device.timeToFull) : 0
ready ? Number(device.energy) : 0
ready ? Number(device.energyCapacity) : 0
ready ? Number(device.changeRate) : 0
```

Direction selection is:

```text
isCharging ? timeToFull : timeToEmpty
    ↓
timeRemaining
    ↓
formatDuration() -> timeRemainingText
```

`formatDuration()` returns `""` for missing estimates, so UI code can use visibility bindings instead of checking seconds.

---

## 6.7 Icon resolution

Icon selection has a fixed precedence:

```text
critical
    ↓
full
    ↓
charging bucket
    ↓
normal bucket
```

The bucket function is:

```text
<= 0   -> 0
< 10   -> 0
< 20   -> 10
< 30   -> 20
< 40   -> 30
< 50   -> 40
< 60   -> 50
< 70   -> 60
< 80   -> 70
< 90   -> 80
< 100  -> 90
>= 100 -> 100
```

`icon` returns a Nerd Font glyph, `iconKey` returns the equivalent freedesktop name.

Both take the same four inputs:

```qml
Battery.iconFor(
    percent,
    charging,
    critical,
    full
)
```

The `icon` and `iconKey` properties simply call those helpers with the current state.

---

## 6.8 Battery list and device info

The model only contains laptop batteries:

```text
UPower.devices.values
    ↓
filter isLaptopBattery
    ↓
batteryModel.values
```

It is exposed twice:

```text
batteries   -> ScriptModel for ListView
batteryList -> plain JS array
```

`deviceInfo()` converts one raw UPower device into plain JSON-safe data:

```json
{
    "nativePath": "",
    "model": "",
    "type": "",
    "isReady": true,
    "isPresent": true,
    "isLaptopBattery": true,
    "isHealthSupported": true,
    "percent": 72,
    "health": 91.0,
    "isCharging": false,
    "isDischarging": true,
    "state": "discharging",
    "energy": 42.5,
    "energyCapacity": 50.0,
    "changeRate": 12.3,
    "timeToEmpty": 8100,
    "timeToFull": 0
}
```

The same function backs IPC `getDevices()`.

---

## 6.9 IPC architecture

IPC is a thin read-only interface over the same service properties.

Conceptually:

```text
terminal
   │
   ▼
n0ctos-battery
   │
   ▼
Battery.qml
   │
   ▼
UPower
```

For example:

```bash
qs ipc call n0ctos-battery getPercent
```

becomes conceptually:

```qml
Battery.percentText
```

and:

```bash
qs ipc call n0ctos-battery getStatus
```

becomes conceptually:

```qml
JSON.stringify({
    percent: Battery.percentRounded,
    state: Battery.stateName,
    ...
})
```

The IPC layer serializes values as strings for terminal use.

---

## 6.10 Final architecture summary

The entire system can be viewed as:

```text
                         Component
                            │
                            │ property binding
                            ▼
                    ┌─────────────────┐
                    │     Battery     │
                    │                 │
                    │ display device  │
                    │ physical battery│
                    │ thresholds      │
                    │ text + icons    │
                    │ device info     │
                    └────────┬────────┘
                             │
                             │ UPower API
                             ▼
                    ┌─────────────────┐
                    │      UPower     │
                    │                 │
                    │ displayDevice   │
                    │ devices         │
                    │ onBattery       │
                    │ device state    │
                    └────────┬────────┘
                             │
                             ▼
                     system power hardware
```

The core rule is:

> **Components read what battery state they need; `Battery.qml` decides which UPower device it comes from and how it is normalized; `UPower` handles how hardware state is detected.**
