# Brightness Service

`Brightness.qml` is N0ctOS's centralized backlight and LED brightness service.

It gives every shell component one consistent place to read and control display and keyboard brightness without touching `brightnessctl` or `sysfs` directly.

The service supports automatic device discovery, per-device `sysfs` tracking, active-device selection, percent normalization, clamped absolute sets, stepwise increase/decrease, per-device convenience controls, and a read/write IPC interface.

The normal usage pattern is:

```text
Component
    │
    ▼
Brightness
    │
    ├── active device
    ├── device list
    └── resolved percent + text
    │
    ▼
brightnessctl / sysfs
    │
    ▼
backlight + LED hardware
```

---

# 1. What does it do?

`Brightness.qml` exposes the current brightness for the shell.

A component can read a simple value:

```qml
Brightness.percentText
```

or a simple state flag:

```qml
Brightness.hasDevice
```

or drive the active display:

```qml
Brightness.increase(
    Brightness.device,
    5
)
```

More detailed state is also available:

```json
{
    "key": "backlight:intel_backlight",
    "name": "intel_backlight",
    "type": "backlight",
    "value": 1200,
    "max": 4800,
    "percent": 25,
    "percentText": "25%",
    "sysfsPath": "/sys/class/backlight/intel_backlight",
    "selected": true
}
```

The effective percent is resolved in this order:

```text
sysfs brightness / sysfs max_brightness
    ↓
clamp 0 -> 100
    ↓
device.percent / percentRounded / percentText
    ↓
Brightness.percent / percentRounded / percentText (active device)
```

So a component can simply do:

```qml
Text {
    text:
        Brightness.percentText
}
```

and not care which backlight or LED the value came from.

If no brightness hardware exists, the service returns safe fallbacks (`0`, `""`, `false`, `null`) instead of failing.

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
| `Brightness.isAvailable` | `true` once `brightnessctl` discovery has succeeded. `false` before discovery or when discovery fails. |
| `Brightness.isDiscovering` | `true` while the discovery `Process` is running. |
| `Brightness.devices` | Copy of all discovered devices (`_devices.slice()`). |
| `Brightness.backlights` | Devices whose class is `backlight`. |
| `Brightness.leds` | Devices whose class is `leds`. |
| `Brightness.count` | Number of discovered devices. |
| `Brightness.backlightCount` | Number of backlight devices. |
| `Brightness.ledCount` | Number of LED devices. |
| `Brightness.defaultDevice` | First backlight, otherwise first device, otherwise `null`. |
| `Brightness.device` | Active device: selected device when it still exists, otherwise `defaultDevice`. |
| `Brightness.hasDevice` | `true` when an active device exists. |
| `Brightness.value` | Raw `brightness` integer of the active device, `0` when none. |
| `Brightness.max` | Raw `max_brightness` integer of the active device, `0` when none. |
| `Brightness.percent` | Active-device percent `0 -> 100`, clamped, `0` when none or `max <= 0`. |
| `Brightness.percentRounded` | `Math.round(percent)`. |
| `Brightness.percentText` | `"25%"` style text. |
| `Brightness.deviceName` | Active-device `name` (`deviceId`), `""` when none. |
| `Brightness.deviceKey` | Active-device `key` (`"class:id"`), `""` when none. |

Each entry in `devices`, `backlights`, `leds`, `device`, and `defaultDevice` is a device object with:

| How to read | What does it do |
| ----------- | --------------- |
| `device.key` | `"class:id"`, for example `"backlight:intel_backlight"`. |
| `device.deviceId` | Kernel device id, for example `"intel_backlight"`. |
| `device.deviceClass` | Kernel class, `"backlight"` or `"leds"`. |
| `device.sysfsPath` | `"/sys/class/<class>/<id>"`. |
| `device.name` | Same as `deviceId`. |
| `device.className` | Same as `deviceClass`. |
| `device.displayName` | Same as `deviceId`. |
| `device.type` | `"backlight"` or `"led"`. |
| `device.isBacklight` | `true` when `deviceClass === "backlight"`. |
| `device.isLed` | `true` when `deviceClass === "leds"`. |
| `device.value` | Raw `brightness` integer, `0` initially. |
| `device.max` | Raw `max_brightness` integer, `0` initially. |
| `device.isPresent` | `true` when the `brightness` `FileView` exists and is loaded. |
| `device.percent` | `value * 100 / max`, clamped `0 -> 100`, `0` when `max <= 0`. |
| `device.percentRounded` | `Math.round(device.percent)`. |
| `device.percentText` | `"25%"` style text for that device. |

## Helpers

| How to call | What does it do |
| ----------- | --------------- |
| `Brightness.refresh()` | Re-runs `brightnessctl --list --machine-readable` unless discovery is already running. |
| `Brightness.deviceForKey(key)` | Returns the device with `"class:id"` key, or `null` when missing, empty, or null. |
| `Brightness.deviceFor(className, deviceId)` | Convenience for `deviceForKey(className + ":" + deviceId)`. |
| `Brightness.findDefaultDevice()` | First backlight, otherwise first device, otherwise `null`. |
| `Brightness.resolveDevice(value)` | Accepts a service device object or a `"class:id"` string and returns the live service device, or `null`. Rejects foreign objects. |
| `Brightness.set(device, value)` | Clamps `value` to `0 -> 100` and runs `brightnessctl set <percent>%`. Returns `true` when the operation starts, `false` when there is no target or `value` is non-finite. |
| `Brightness.increase(device, amount)` | Runs `brightnessctl set +<step>%`. `step` defaults to `5` when `amount` is missing, non-finite, or `<= 0`. Returns `true`/`false` like `set()`. |
| `Brightness.decrease(device, amount)` | Runs `brightnessctl set -<step>%`. Same defaulting and return rules as `increase()`. |
| `Brightness.setDevice(key)` | Selects the active device by key. Returns `true` and stores `_selectedKey`, `false` when the key is unknown. |
| `Brightness.resetDevice()` | Clears the selection so the active device falls back to `defaultDevice`. Always returns `true`. |
| `Brightness.deviceInfo(device)` | Returns a plain JSON-safe info object for one device, `{}` when null. `percent` is the rounded integer. |
| `Brightness.readInteger(value)` | Parses a `sysfs` string with `parseInt`, `0` when non-finite, clamped to `>= 0`. |
| `Brightness.clearDevices()` | Destroys all device objects, empties the list, and clears the selection. |
| `Brightness.applyDiscovery(lines)` | Parses discovery lines and creates, retains, or destroys device objects. |
| `Brightness.runOperation(device, value)` | Spawns one short-lived `brightnessctl set` process for `device`. Returns `true` when started, `false` when there is no device or the process cannot be created. |

Per-device convenience wrappers call back into the service with that device:

| How to call | What does it do |
| ----------- | --------------- |
| `device.set(value)` | Same as `Brightness.set(device, value)`. |
| `device.increase(amount)` | Same as `Brightness.increase(device, amount)`. |
| `device.decrease(amount)` | Same as `Brightness.decrease(device, amount)`. |
| `device.refresh()` | Reloads that device's `brightness` and `max_brightness` `FileView` objects when loaded. |

| Example | Result |
| ------- | ------ |
| `Brightness.set(Brightness.device, 70)` | `true`, starts `brightnessctl set 70%` on the active device |
| `Brightness.set("backlight:intel_backlight", 70)` | `true` when that device exists, `false` when it does not |
| `Brightness.set(Brightness.device, 150)` | `true`, clamped to `100%`, starts `brightnessctl set 100%` |
| `Brightness.increase(Brightness.device, 5)` | `true`, starts `brightnessctl set +5%` |
| `Brightness.decrease(Brightness.device, 5)` | `true`, starts `brightnessctl set -5%` |
| `Brightness.increase(Brightness.device, 0)` | `true`, invalid step falls back to `5`, starts `brightnessctl set +5%` |
| `Brightness.deviceForKey("backlight:intel_backlight")` | Live device object, or `null` when missing or empty |
| `Brightness.deviceFor("backlight", "intel_backlight")` | Live device object, or `null` when missing |
| `Brightness.resolveDevice(Brightness.device)` | The same live service device, or `null` when it no longer exists |
| `Brightness.setDevice("backlight:intel_backlight")` | `true` and the active device changes, or `false` when the key is unknown |
| `Brightness.deviceInfo(Brightness.device)` | `{key, value, max, percent, ...}` info object, `{}` when null |

### Typical component usage

```qml
Text {
    text:
        Brightness.percentText
}

Text {
    visible:
        Brightness.hasDevice

    text:
        Brightness.deviceName +
        ": " +
        Brightness.percentText
}

MouseArea {
    onWheel: (wheel) => {
        if (wheel.angleDelta.y > 0)
            Brightness.increase(
                Brightness.device,
                5
            )
        else
            Brightness.decrease(
                Brightness.device,
                5
            )
    }
}
```

That is the intended everyday usage.

Components normally should not need to know how `brightnessctl` discovery, `sysfs` watchers, keys, or default-device selection work.

---

# 3. IPC API

IPC target:

```text
n0ctos-brightness
```

## State reads

| How to call | What does it do |
| ----------- | --------------- |
| `isAvailable` | Returns `isAvailable`. |
| `isDiscovering` | Returns `isDiscovering`. |
| `hasDevice` | Returns `hasDevice`. |
| `count` | Returns `count`. |
| `get` | Returns `percentText`, e.g. `"25%"`. |
| `getValue` | Returns raw `value` of the active device. |
| `getMax` | Returns raw `max` of the active device. |
| `getDeviceName` | Returns `deviceName`, e.g. `"intel_backlight"`, or `""`. |
| `getDeviceKey` | Returns `deviceKey`, e.g. `"backlight:intel_backlight"`, or `""`. |
| `getDefault` | Returns the default-device key, or `""` when none. |
| `getDevice` | Returns the active device as a JSON string, or `""` when none. |

| Example | Result |
| ------- | ------ |
| `qs ipc call n0ctos-brightness isAvailable` | `true` when discovery has succeeded, `false` otherwise |
| `qs ipc call n0ctos-brightness hasDevice` | `true` when an active device exists |
| `qs ipc call n0ctos-brightness count` | `2`, the number of discovered devices |
| `qs ipc call n0ctos-brightness get` | `"25%"`, the active-device text |
| `qs ipc call n0ctos-brightness getValue` | `1200`, the raw `brightness` integer |
| `qs ipc call n0ctos-brightness getMax` | `4800`, the raw `max_brightness` integer |
| `qs ipc call n0ctos-brightness getDeviceName` | `"intel_backlight"`, or `""` when none |
| `qs ipc call n0ctos-brightness getDeviceKey` | `"backlight:intel_backlight"`, or `""` when none |
| `qs ipc call n0ctos-brightness getDefault` | `"backlight:intel_backlight"`, or `""` when none |
| `qs ipc call n0ctos-brightness getDevice` | JSON info object for the active device, or `""` when none |

For example:

```bash
qs ipc call n0ctos-brightness get
```

returns:

```text
25%
```

```bash
qs ipc call n0ctos-brightness getDeviceKey
```

returns:

```text
backlight:intel_backlight
```

```bash
qs ipc call n0ctos-brightness getValue
```

returns:

```text
1200
```

## Device lists

| How to call | What does it do |
| ----------- | --------------- |
| `list` | Returns one info object per discovered device as a JSON string. |
| `backlights` | Returns only backlight devices as a JSON string. |
| `leds` | Returns only LED devices as a JSON string. |

| Example | Result |
| ------- | ------ |
| `qs ipc call n0ctos-brightness list` | JSON array with one info object per device |
| `qs ipc call n0ctos-brightness backlights` | JSON array with only backlight devices |
| `qs ipc call n0ctos-brightness leds` | JSON array with only LED devices |

`list` returns:

```json
[
    {
        "key": "backlight:intel_backlight",
        "id": "intel_backlight",
        "class": "backlight",
        "name": "intel_backlight",
        "displayName": "intel_backlight",
        "type": "backlight",
        "isBacklight": true,
        "isLed": false,
        "isPresent": true,
        "value": 1200,
        "max": 4800,
        "percent": 25,
        "percentText": "25%",
        "sysfsPath": "/sys/class/backlight/intel_backlight",
        "selected": true
    }
]
```

With no devices, `list` returns:

```json
[]
```

## Current-device writes

These act on the active device:

| How to call | What does it do |
| ----------- | --------------- |
| `set <percent>` | Sets the active device to `<percent>`, clamped `0 -> 100`. Returns `true`/`false`. |
| `increase <percent>` | Increases the active device by `<percent>`, default `5`. Returns `true`/`false`. |
| `decrease <percent>` | Decreases the active device by `<percent>`, default `5`. Returns `true`/`false`. |

| Example | Result |
| ------- | ------ |
| `qs ipc call n0ctos-brightness set 70` | `true`, starts `brightnessctl set 70%` on the active device |
| `qs ipc call n0ctos-brightness increase 5` | `true`, starts `brightnessctl set +5%` |
| `qs ipc call n0ctos-brightness decrease 5` | `true`, starts `brightnessctl set -5%` |

For example:

```bash
qs ipc call n0ctos-brightness set 70
```

```bash
qs ipc call n0ctos-brightness increase 5
```

```bash
qs ipc call n0ctos-brightness decrease 5
```

A missing or invalid step falls back to `5`:

```bash
qs ipc call n0ctos-brightness increase 0
```

still steps by `5%` and returns `true` when a device exists.

## Specific-device writes and selection

| How to call | What does it do |
| ----------- | --------------- |
| `setDevice <key>` | Selects the active device by `"class:id"` key. Returns `true` on success, `false` when unknown. |
| `resetDevice` | Clears the selection so the active device falls back to the default. Always returns `true`. |
| `setDeviceValue <key> <percent>` | Sets one device by key, clamped `0 -> 100`. Returns `true`/`false`. |
| `increaseDevice <key> <percent>` | Increases one device by key, default `5`. Returns `true`/`false`. |
| `decreaseDevice <key> <percent>` | Decreases one device by key, default `5`. Returns `true`/`false`. |

| Example | Result |
| ------- | ------ |
| `qs ipc call n0ctos-brightness setDevice backlight:intel_backlight` | `true` and the active device changes, `false` when the key is unknown |
| `qs ipc call n0ctos-brightness resetDevice` | `true`, selection cleared, active device falls back to default |
| `qs ipc call n0ctos-brightness setDeviceValue backlight:intel_backlight 70` | `true` when that device exists, `false` otherwise |
| `qs ipc call n0ctos-brightness increaseDevice backlight:intel_backlight 5` | `true` when that device exists, `false` otherwise |
| `qs ipc call n0ctos-brightness decreaseDevice backlight:intel_backlight 5` | `true` when that device exists, `false` otherwise |

For example:

```bash
qs ipc call n0ctos-brightness setDevice backlight:intel_backlight
```

```bash
qs ipc call n0ctos-brightness setDeviceValue backlight:intel_backlight 70
```

```bash
qs ipc call n0ctos-brightness resetDevice
```

## Discovery

| How to call | What does it do |
| ----------- | --------------- |
| `refresh` | Re-runs discovery unless it is already running. Returns nothing. |

| Example | Result |
| ------- | ------ |
| `qs ipc call n0ctos-brightness refresh` | No return value, discovery restarts when idle |

For example:

```bash
qs ipc call n0ctos-brightness refresh
```

---

# 4. Features / limitations

## Features

### Automatic discovery through `brightnessctl`

Discovery runs:

```text
brightnessctl --list --machine-readable
```

Each output line has the form:

```text
DEVICE,CLASS,CURRENT,PERCENT,MAX
```

For example:

```text
intel_backlight,backlight,1200,25%,4800
```

`applyDiscovery()` splits each line on commas, requires at least 5 parts with a non-empty device id and class, deduplicates by `"class:id"`, and then creates, retains, or destroys device objects.

Malformed and blank lines are skipped.

### Backlight and LED separation

The full list is split by class:

```text
_devices
    ↓
isBacklight -> backlights
isLed       -> leds
```

A panel can therefore bind to only real displays:

```qml
Brightness.backlights
```

or only keyboard/status LEDs:

```qml
Brightness.leds
```

### Active and default device

The default prefers a real display:

```text
first backlight
    ↓
otherwise first brightness device
    ↓
otherwise null
```

The active device prefers an explicit selection:

```text
selected key still exists -> selected device
otherwise                 -> default device
```

This gives sliders and keys stable bindings without tracking hotplug manually.

### `sysfs` tracking without polling

Each device owns two `FileView` objects:

```text
/sys/class/<class>/<id>/brightness (watched)
/sys/class/<class>/<id>/max_brightness (unwatched)
```

The current-brightness file uses:

```qml
watchChanges: true
```

and reloads on `fileChanged()`, because `FileView` does not reload automatically.

The max-brightness file uses:

```qml
watchChanges: false
```

because the maximum rarely changes.

External changes through keys, `brightnessctl`, or desktop controls therefore appear through file notifications, not a timer.

### Percent normalization

Raw `sysfs` integers become UI-ready percent:

```text
max > 0 ? clamp(value * 100 / max, 0, 100) : 0
    ↓
percent
    ↓
round -> percentRounded
    ↓
String + "%" -> percentText
```

`deviceInfo().percent` is the rounded integer, matching `percentRounded`.

### Clamped absolute sets

`set()` converts its argument with `Number()`, rejects non-finite input with `false`, and clamps:

```text
clamp(value, 0, 100)
    ↓
brightnessctl set <percent>%
```

So:

```qml
Brightness.set(
    Brightness.device,
    150
)
```

targets `100%`, and a negative value targets `0%`.

### Stepwise control with a safe default

`increase()` and `decrease()` convert `amount` with `Number()` and fall back:

```text
missing / non-finite / <= 0
    ↓
step = 5
```

They then run:

```text
brightnessctl set +<step>%
brightnessctl set -<step>%
```

Key bindings can therefore omit the step or pass `0` safely.

### Per-device convenience

A device object forwards to the service:

```qml
device.set(70)
device.increase(5)
device.decrease(5)
```

These are the same operations as:

```qml
Brightness.set(device, 70)
Brightness.increase(device, 5)
Brightness.decrease(device, 5)
```

but read naturally inside delegates and loops.

### Immediate refresh after control

Each `set`, `increase`, and `decrease` spawns its own short-lived `Process`:

```text
brightnessctl --quiet --class <class> --device <id> set <value>
```

On exit the target device calls:

```qml
device.refresh()
```

so the `sysfs` value is reloaded immediately without waiting for the next file notification.

### Safe empty-hardware fallbacks

With no devices:

```text
hasDevice = false
device = null
defaultDevice = null
value = 0
max = 0
percent = 0
percentRounded = 0
percentText = "0%"
deviceName = ""
deviceKey = ""
count = 0
devices = []
```

Components can bind directly without null checks on every property.

### JSON-safe device info

`deviceInfo()` converts one live device into plain data with:

```text
key / id / class / name / displayName
type / isBacklight / isLed / isPresent
value / max / percent / percentText
sysfsPath / selected
```

The same function backs IPC `list`, `backlights`, `leds`, and `getDevice()`.

---

## Limitations

### `brightnessctl` is required

If:

```text
brightnessctl --list --machine-readable
```

exits non-zero, the service sets:

```text
_available = false
```

and logs:

```text
[Brightness] brightnessctl discovery failed
```

No devices are committed in that case. The shell must have `brightnessctl` installed and permission to access backlight devices.

### Device selection is runtime-only

`_selectedKey` is intentionally not persisted yet:

```qml
property string _selectedKey: ""
```

Restarting the shell clears the selection. If the selected key disappears during a later discovery, it is cleared automatically and the active device falls back to the default.

### Writes are asynchronous

`set()`, `increase()`, and `decrease()` return:

```text
true  -> process started
false -> no target / bad input / process creation failed
```

`true` does not mean the hardware already changed. The `sysfs` value updates when `brightnessctl` exits and the device refreshes, or when the file watcher fires.

### `resolveDevice()` only accepts service devices

An object is accepted only when it has a usable `key` that matches a live device:

```text
foreign {key: "..."} -> null
removed device       -> null
unknown string       -> null
empty string         -> null
null / undefined     -> null
```

This prevents an arbitrary QML object with a `key` property from being sent to `brightnessctl`.

### `FileView` failures are warnings, not fatal

A missing `sysfs` file logs:

```text
[Brightness] failed to load brightness file
[Brightness] failed to load max-brightness file
```

The device still exists in the list, but:

```text
isPresent = false
value may stay 0
max may stay 0
percent = 0
```

Callers should check `hasDevice` or `isPresent` when accuracy matters.

### `percent` in `deviceInfo()` is rounded

The info object reports:

```qml
percent: device.percentRounded
```

not the raw float. A device at `24.6%` reports:

```json
{
    "percent": 25,
    "percentText": "25%"
}
```

Use `device.percent` directly in QML when the unrounded value is needed.

---

# 5. Example use cases

## 5.1 A panel showing brightness

A panel only needs two bindings:

```qml
import QtQuick
import Quickshell

import qs.services

Row {
    spacing: 6

    Text {
        visible:
            Brightness.hasDevice

        text:
            Brightness.percentText
    }

    Text {
        visible:
            !Brightness.hasDevice

        text:
            "No backlight"
    }
}
```

The component does not need to know whether the value came from:

```text
a laptop display backlight
a fallback first device
an explicitly selected LED
no hardware at all
```

It only receives the effective value.

---

## 5.2 A slider setting absolute brightness

`set()` takes the active device plus a percent:

```qml
import QtQuick

import qs.services

Slider {
    enabled:
        Brightness.hasDevice

    from: 0
    to: 100

    value:
        Brightness.percent

    onMoved: {
        Brightness.set(
            Brightness.device,
            value
        )
    }
}
```

Out-of-range slider values are clamped by the service, so no manual `Math.max`/`Math.min` is needed.

The same works through a key string:

```qml
Brightness.set(
    "backlight:intel_backlight",
    70
)
```

which returns `false` when that device does not exist.

---

## 5.3 Brightness keys stepping up and down

Step functions default to `5` when the amount is missing or invalid:

```qml
import QtQuick

import qs.services

Item {
    focus: true

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_MonBrightnessUp) {
            Brightness.increase(
                Brightness.device,
                5
            )

            event.accepted = true
        } else if (event.key === Qt.Key_MonBrightnessDown) {
            Brightness.decrease(
                Brightness.device,
                5
            )

            event.accepted = true
        }
    }
}
```

The result is:

```text
increase 5 -> brightnessctl set +5%
decrease 5 -> brightnessctl set -5%
missing / 0 / negative -> +5% / -5%
```

---

## 5.4 Listing devices and selecting one

`devices` is a plain array copy, so it works with `Repeater` and loops:

```qml
import QtQuick

import qs.services

Column {
    spacing: 8

    Repeater {
        model:
            Brightness.devices

        delegate: Text {
            required property var modelData

            text:
                Brightness.deviceInfo(
                    modelData
                ).key +
                ": " +
                Brightness.deviceInfo(
                    modelData
                ).percentText

            color:
                Brightness.deviceInfo(
                    modelData
                ).selected
                    ? "#2acfff"
                    : "#ffffff"

            MouseArea {
                anchors.fill:
                    parent

                onClicked:
                    Brightness.setDevice(
                        parent.modelData.key
                    )
            }
        }
    }
}
```

For imperative code, use the lookup helpers:

```qml
const panel =
    Brightness.deviceFor(
        "backlight",
        "intel_backlight"
    )

if (panel)
    Brightness.setDevice(
        panel.key
    )
else
    Brightness.resetDevice()
```

`setDevice()` returns `false` for an unknown key and leaves the selection unchanged.

---

## 5.5 Terminal workflow

Read the active brightness:

```bash
qs ipc call n0ctos-brightness get
```

Read the active key:

```bash
qs ipc call n0ctos-brightness getDeviceKey
```

List every device:

```bash
qs ipc call n0ctos-brightness list
```

List only backlights:

```bash
qs ipc call n0ctos-brightness backlights
```

Set the active device:

```bash
qs ipc call n0ctos-brightness set 70
```

Step the active device:

```bash
qs ipc call n0ctos-brightness increase 5
qs ipc call n0ctos-brightness decrease 5
```

Target one device:

```bash
qs ipc call n0ctos-brightness setDeviceValue backlight:intel_backlight 70
```

Select that device for subsequent `set` calls:

```bash
qs ipc call n0ctos-brightness setDevice backlight:intel_backlight
```

Return to the default device:

```bash
qs ipc call n0ctos-brightness resetDevice
```

Re-run discovery:

```bash
qs ipc call n0ctos-brightness refresh
```

Inspect the complete service:

```bash
qs ipc call n0ctos-brightness getDevice
```

---

# 6. Detailed architecture

This section is for developers working on `Brightness.qml` and the services/components that consume it.

---

## 6.1 Overall architecture

The service is a normalization and control layer built on top of `brightnessctl` and `sysfs` file watching.

```text
N0ctOS Component / Service
            │
            ▼
      Brightness.qml
            │
     ┌──────┼────────┐
     │      │        │
     ▼      ▼        ▼
 discovery sysfs   control
  list    FileView process
     │      │        │
     └──────┴────────┘
            │
            ▼
  brightnessctl / sysfs
            │
            ▼
 backlight + LED hardware
```

There are effectively two responsibilities:

```text
Brightness
    N0ctOS-friendly discovery, normalization, and selection

brightnessctl / sysfs
    hardware enumeration and actual brightness changes
```

Brightness should not duplicate the hardware access already provided by those layers.

---

## 6.2 Configuration structure

The service owns no `Config` section.

There is no:

```json
{
    "brightness": {
        "device": "...",
        "percent": 70
    }
}
```

Device selection lives only in memory:

```qml
property string _selectedKey: ""
```

Device values live in `sysfs`, not in N0ctOS configuration files.

---

## 6.3 Discovery input

Discovery runs:

```text
brightnessctl --list --machine-readable
```

The expected line format is:

```text
DEVICE,CLASS,CURRENT,PERCENT,MAX
```

For example:

```text
intel_backlight,backlight,1200,25%,4800
asus::kbd_backlight,leds,1,33%,3
```

Only `DEVICE` and `CLASS` are used for identity. `CURRENT` and `MAX` are read later through `sysfs`, so discovery stays stable even if the values change between listing and watching.

---

## 6.4 Discovery parsing

`applyDiscovery()` performs:

```text
trim line
    ↓
skip empty
    ↓
split on ","
    ↓
require >= 5 parts
    ↓
require non-empty id + class
    ↓
key = class + ":" + id
    ↓
deduplicate by key
```

Deduplication uses a plain object as a set:

```text
seen[key] = true
```

so a duplicated `brightnessctl` line cannot create two device objects.

---

## 6.5 Create and retain

Existing devices are indexed by key:

```text
existing[device.key] = device
```

Each discovered entry then either:

```text
exists -> retain object
missing -> createObject + two FileViews
```

Retained objects keep their:

```text
FileView instances
value / max
bindings
```

so a periodic `refresh()` does not destroy and recreate stable devices.

---

## 6.6 Removal

Devices absent from the new discovery are destroyed:

```text
old device not in nextDevices
    ↓
oldDevice.destroy()
    ↓
FileView children destroyed too
```

because the `FileView` objects are QObject children of the device.

The service logs:

```text
[Brightness] removed: <key>
```

If the removed device was selected, `_selectedKey` is cleared so the active device falls back to the default.

---

## 6.7 `sysfs` file layer

Each new device gets:

```text
<sysfsPath>/brightness (watched)
<sysfsPath>/max_brightness (unwatched)
```

For example:

```text
/sys/class/backlight/intel_backlight/brightness
/sys/class/backlight/intel_backlight/max_brightness
```

The current file reloads on change:

```qml
onFileChanged: {
    reload()
}
```

and pushes its content through:

```qml
ownerDevice.updateCurrentValue()
```

The max file pushes through:

```qml
ownerDevice.updateMaxValue()
```

only when it loads.

---

## 6.8 Integer parsing

`sysfs` content is text, so both updates go through:

```qml
Brightness.readInteger(value)
```

which performs:

```text
String(value).trim()
    ↓
parseInt(..., 10)
    ↓
non-finite -> 0
    ↓
max(0, result)
```

Negative or garbage content therefore becomes `0` rather than `NaN`.

---

## 6.9 Percent normalization

Each device computes:

```text
max > 0 ? clamp(value * 100 / max, 0, 100) : 0
```

The service-level properties then forward the active device:

```text
device.percent -> Brightness.percent
round          -> percentRounded
String + "%"  -> percentText
```

When there is no active device, or `max <= 0`:

```text
percent = 0
percentText = "0%"
```

---

## 6.10 Default and active device

The default is:

```qml
Brightness.findDefaultDevice()
```

which performs:

```text
first isBacklight -> return it
otherwise         -> return _devices[0]
otherwise         -> null
```

The active device is:

```qml
Brightness.device
```

which performs:

```text
_selectedKey non-empty
    ↓
deviceForKey(_selectedKey) or defaultDevice
otherwise
    ↓
defaultDevice
```

All service-level `value`, `max`, `percent`, `deviceName`, and `deviceKey` bindings follow this one property.

---

## 6.11 Device lookup

`deviceForKey()` is the single lookup primitive:

```text
undefined / null / "" -> null
otherwise              -> linear scan by key
```

`deviceFor()` only builds the key:

```qml
Brightness.deviceFor(
    className,
    deviceId
)
```

becomes conceptually:

```text
deviceForKey(className + ":" + deviceId)
```

`resolveDevice()` adds polymorphism:

```text
null / undefined            -> null
object with usable key      -> deviceForKey(object.key)
object without usable key   -> null
string                      -> deviceForKey(String(value))
```

A removed device resolves to `null`, so stale object references fail safely instead of addressing the wrong hardware.

---

## 6.12 `set()` semantics

`set()` is the single absolute-write primitive.

It performs:

```text
resolveDevice(device)
    ↓
missing -> false
    ↓
Number(value)
    ↓
non-finite -> false
    ↓
clamp 0 -> 100
    ↓
runOperation(target, "<percent>%")
```

For example:

```qml
Brightness.set(device, 70)
```

runs conceptually:

```text
brightnessctl --quiet --class backlight --device intel_backlight set 70%
```

and returns `true` when that process starts.

---

## 6.13 `increase()` and `decrease()` semantics

Both are relative-write primitives.

They perform:

```text
resolveDevice(device)
    ↓
missing -> false
    ↓
Number(amount)
    ↓
non-finite or <= 0 -> step = 5
    ↓
runOperation(target, "+<step>%")
runOperation(target, "-<step>%")
```

For example:

```qml
Brightness.increase(device, 5)
```

runs conceptually:

```text
brightnessctl set +5%
```

The `5` default keeps brightness keys and scroll handlers working when the caller omits the step.

---

## 6.14 Control process lifecycle

Each operation creates its own `Process`:

```text
runOperation()
    ↓
createObject(controlProcessComponent)
    ↓
failed -> warn + false
    ↓
process.running = true
    ↓
return true
```

On exit:

```text
non-zero + target -> warn with key + exit code
target exists     -> target.refresh()
destroy process
```

The refresh reloads both `FileView` objects when loaded, so QML state converges without polling.

---

## 6.15 Selection lifecycle

Selecting performs:

```text
Brightness.setDevice(key)
    ↓
deviceForKey(key)
    ↓
missing -> false, selection unchanged
    ↓
_selectedKey = target.key
    ↓
return true
```

Resetting performs:

```text
Brightness.resetDevice()
    ↓
_selectedKey = ""
    ↓
return true
```

The complete active-device lifecycle is therefore:

```text
discovery commits _devices
        │
        ▼
defaultDevice reevaluates
        │
        ▼
device reevaluates (selected or default)
        │
        ▼
value / max / percent bindings reevaluate
```

---

## 6.16 `deviceInfo()` serialization

`deviceInfo()` converts one live device into plain JSON-safe data:

```json
{
    "key": "backlight:intel_backlight",
    "id": "intel_backlight",
    "class": "backlight",
    "name": "intel_backlight",
    "displayName": "intel_backlight",
    "type": "backlight",
    "isBacklight": true,
    "isLed": false,
    "isPresent": true,
    "value": 1200,
    "max": 4800,
    "percent": 25,
    "percentText": "25%",
    "sysfsPath": "/sys/class/backlight/intel_backlight",
    "selected": true
}
```

`selected` compares object identity:

```qml
root.device === device
```

When the argument is null, the function returns:

```json
{}
```

---

## 6.17 IPC architecture

IPC is a thin external interface over the same service API.

Conceptually:

```text
terminal
   │
   ▼
n0ctos-brightness
   │
   ▼
Brightness.qml
   │
   ▼
brightnessctl / sysfs
```

For example:

```bash
qs ipc call n0ctos-brightness set 70
```

becomes conceptually:

```qml
Brightness.set(
    Brightness.device,
    70
)
```

and:

```bash
qs ipc call n0ctos-brightness list
```

becomes conceptually:

```qml
JSON.stringify(
    Brightness.devices.map(Brightness.deviceInfo)
)
```

The IPC layer serializes values as strings and booleans for terminal use.

---

## 6.18 No polling

Brightness does not use a polling timer to detect changes.

There is no:

```qml
Timer {
    interval: 1000
    repeat: true

    onTriggered:
        reloadBrightness()
}
```

Changes arrive through:

```text
FileView fileChanged -> reload -> update value
control exit        -> device.refresh()
discovery exit      -> applyDiscovery()
```

This avoids unnecessary CPU activity.

---

## 6.19 Service boundaries

The responsibilities are intentionally divided:

```text
Brightness
    device discovery parsing
    device objects and selection
    percent normalization
    control operations
    device info API

brightnessctl
    hardware enumeration
    actual brightness changes

sysfs FileView
    current and maximum value tracking
    external change notification
```

Brightness should not reimplement hardware enumeration or bypass `brightnessctl` with direct `sysfs` writes.

---

## 6.20 What UI / service code should not do

Components should not:

```text
spawn brightnessctl directly

create FileView objects for brightness files

parse brightnessctl --list output

assume one fixed backlight name

assume devices never change

mutate Brightness.devices in place

send foreign objects to set/increase/decrease
```

Instead:

```qml
Brightness.percentText
Brightness.device
Brightness.set(...)
Brightness.increase(...)
Brightness.decrease(...)
Brightness.setDevice(...)
```

should be the normal interface.

---

## 6.21 Final architecture summary

The entire system can be viewed as:

```text
                         Component
                            │
                            │ property binding / set()
                            ▼
                    ┌─────────────────┐
                    │   Brightness    │
                    │                 │
                    │ discovery       │
                    │ devices         │
                    │ active device   │
                    │ percent         │
                    │ control         │
                    └────────┬────────┘
                             │
                             │ brightnessctl + sysfs API
                             ▼
                    ┌─────────────────┐
                    │ brightnessctl / │
                    │     sysfs       │
                    │                 │
                    │ device list     │
                    │ brightness file │
                    │ max file        │
                    │ set operation   │
                    └────────┬────────┘
                             │
                             ▼
                    backlight + LED hardware
```

The core rule is:

> **Components read what brightness they need; `Brightness.qml` decides which device it comes from and how percent is normalized; `brightnessctl` and `sysfs` handle how hardware state is enumerated and changed.**
