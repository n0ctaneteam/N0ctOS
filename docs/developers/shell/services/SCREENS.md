# Screens Service

`Screens.qml` is N0ctOS's centralized screen tracking and primary-screen service.

It gives every shell component one consistent place to read the remembered screen order, the live Quickshell screens, the connected names, and the resolved primary screen without touching `Config` or `Quickshell.screens` directly.

The service supports remembered priority order, live screen indexing, primary resolution, new-screen discovery, primary reassignment, Config persistence, and a mostly read-only IPC interface with two control operations.

The normal usage pattern is:

```text
Component
    │
    ▼
Screens
    │
    ├── remembered order
    ├── live screens
    └── resolved primary
    │
    ├──────┼────────┐
    ▼      ▼        ▼
 Config Quickshell Config
           │       homeConfig
           ▼
    system screens
```

---

# 1. What does it do?

`Screens.qml` remembers screen priority and resolves which connected screen is primary.

A component can read a simple value:

```qml
Screens.primaryScreenName
```

or a simple count:

```qml
Screens.count
```

or the full live object:

```qml
Screens.primaryScreen
```

The remembered order is persisted as a plain string array:

```json
{
    "screens": [
        "DP-1",
        "HDMI-A-1"
    ]
}
```

Disconnected screens intentionally stay in that array so their priority is preserved when they are reconnected later.

The effective primary is resolved in this order:

```text
remembered names in order
    ↓
first currently connected
    ↓
first live screen (fallback)
```

So a component can simply do:

```qml
Text {
    text:
        Screens.primaryScreenName
}
```

and not care where the value came from.

If no screen is connected, the service returns safe fallbacks (`null`, `""`, `0`, `[]`) instead of failing.

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
| `Screens.isReady` | `Config.isReady`. `false` until configuration is loaded. |
| `Screens.names` | Remembered priority order, copy of `_screenNames`. Disconnected names are kept. |
| `Screens.screens` | Live `Quickshell.screens` array of `ShellScreen` objects. |
| `Screens.connectedNames` | Names of currently connected screens, copy of `_connectedNames`. |
| `Screens.count` | `Quickshell.screens.length`. |
| `Screens.primaryScreen` | Resolved primary `ShellScreen`, or `null`. Always selected from live screens. |
| `Screens.primaryScreenName` | `String(primaryScreen.name \|\| "")`, or `""` when none. |

## Functions and signals

| How to call | What does it do |
| ----------- | --------------- |
| `Screens.syncFromConfig()` | Reloads `_screenNames` from `Config.get("screens", [])` with normalization. Returns `true` when the order changed, `false` otherwise. |
| `Screens.saveNames(names)` | Writes `names.slice()` to `Config.set("screens", ...)`. Returns `false` when not ready, otherwise the `Config.set()` result. |
| `Screens.refresh()` | Rebuilds the connected index, appends new screens to the remembered order, persists them, emits discovery signals, and re-resolves primary. |
| `Screens.resolvePrimary()` | Re-resolves `primaryScreen` from remembered order plus live screens. |
| `Screens.screenForName(name)` | Returns the connected `ShellScreen` for `name`, or `null` when missing or empty. |
| `Screens.isConnected(name)` | `true` when `screenForName(name)` is not `null`. |
| `Screens.setPrimary(name)` | Moves a connected, remembered screen to the front of the order, persists it, and re-resolves primary. Returns `true` when it is primary afterwards, `false` otherwise. |
| `Screens.screenDiscovered(name)` | Signal emitted once per newly discovered screen, after public state is updated. |
| `Screens.configurationChanged()` | Signal emitted when the remembered order changes. |
| `Screens.refreshed()` | Signal emitted at the end of every `refresh()`. |

### Typical component usage

```qml
Text {
    text:
        Screens.primaryScreenName
}

Text {
    text:
        Screens.count > 1
            ? Screens.count + " screens"
            : "single screen"
}

Repeater {
    model:
        Screens.screens

    delegate: Text {
        required property var modelData

        text:
            modelData.name
    }
}
```

That is the intended everyday usage.

Components normally should not need to know how remembered order, connected indexing, or `Config` persistence work.

---

# 3. IPC API

IPC target:

```text
n0ctos-screens
```

## Core reads

| How to call | What does it do |
| ----------- | --------------- |
| `count` | Returns `Screens.count` as an integer. |
| `primary` | Returns `Screens.primaryScreenName` as a string. |
| `names` | Returns the remembered order as a JSON array string. |
| `connected` | Returns the connected names as a JSON array string. |
| `isConnected <name>` | Returns `true` when the named screen is connected. |
| `list` | Returns one info object per live screen as a JSON array string. |
| `get <name>` | Returns the info object for one connected screen as a JSON string, or `""` when unknown. |
| `getPrimary` | Returns the info object for the primary screen as a JSON string, or `""` when none. |

| Example | Result |
| ------- | ------ |
| `qs ipc call n0ctos-screens count` | `2` |
| `qs ipc call n0ctos-screens primary` | `"DP-1"` |
| `qs ipc call n0ctos-screens names` | `["DP-1","HDMI-A-1"]` |
| `qs ipc call n0ctos-screens connected` | `["DP-1","HDMI-A-1"]` |
| `qs ipc call n0ctos-screens isConnected DP-1` | `true` |
| `qs ipc call n0ctos-screens list` | JSON array of screen info objects (see below) |
| `qs ipc call n0ctos-screens get DP-1` | JSON info object for `DP-1` (see below), or `""` when unknown |
| `qs ipc call n0ctos-screens getPrimary` | JSON info object for the primary screen, or `""` when none |

For example:

```bash
qs ipc call n0ctos-screens count
```

returns:

```text
2
```

```bash
qs ipc call n0ctos-screens primary
```

returns:

```text
DP-1
```

```bash
qs ipc call n0ctos-screens names
```

returns:

```text
["DP-1","HDMI-A-1"]
```

```bash
qs ipc call n0ctos-screens isConnected DP-1
```

returns:

```text
true
```

`list` returns:

```json
[
    {
        "name": "DP-1",
        "model": "PA278QV",
        "serialNumber": "NCLM123456",
        "x": 0,
        "y": 0,
        "width": 2560,
        "height": 1440,
        "devicePixelRatio": 1,
        "logicalPixelDensity": 4.2,
        "physicalPixelDensity": 4.2
    },
    {
        "name": "HDMI-A-1",
        "model": "VP249",
        "serialNumber": "",
        "x": 2560,
        "y": 0,
        "width": 1920,
        "height": 1080,
        "devicePixelRatio": 1,
        "logicalPixelDensity": 3.8,
        "physicalPixelDensity": 3.8
    }
]
```

`get` returns one object with the same shape:

```json
{
    "name": "DP-1",
    "model": "PA278QV",
    "serialNumber": "NCLM123456",
    "x": 0,
    "y": 0,
    "width": 2560,
    "height": 1440,
    "devicePixelRatio": 1,
    "logicalPixelDensity": 4.2,
    "physicalPixelDensity": 4.2
}
```

When the name is unknown, `get` returns an empty string.

When no primary exists, `getPrimary` returns an empty string.

## Control operations

| How to call | What does it do |
| ----------- | --------------- |
| `setPrimary <name>` | Moves a connected, remembered screen to the front and re-resolves primary. Returns `true` when it is primary afterwards, `false` otherwise. |
| `refresh` | Re-runs `Screens.refresh()`. Returns nothing. |

| Example | Result |
| ------- | ------ |
| `qs ipc call n0ctos-screens setPrimary HDMI-A-1` | `true` when `HDMI-A-1` is connected and becomes primary, `false` otherwise |
| `qs ipc call n0ctos-screens refresh` | no output |

For example:

```bash
qs ipc call n0ctos-screens setPrimary HDMI-A-1
```

returns:

```text
true
```

when `HDMI-A-1` is connected, and:

```text
false
```

when the name is empty, not connected, or not in the remembered order.

```bash
qs ipc call n0ctos-screens refresh
```

produces no output. It only rebuilds the index and re-resolves primary.

---

# 4. Features / limitations

## Features

### Remembered priority order

The service keeps:

```text
_screenNames
```

as the priority list. It is loaded from:

```json
{
    "screens": [
        "DP-1",
        "HDMI-A-1"
    ]
}
```

and returned as:

```qml
Screens.names
```

Disconnected names are intentionally kept so reconnecting a monitor restores its position.

### Live screens stay live

Live objects always come from:

```text
Quickshell.screens
```

and are exposed directly as:

```qml
Screens.screens
```

The service never caches or clones `ShellScreen` objects. `primaryScreen` is always one of the current live objects.

### Primary resolution

`resolvePrimary()` walks the remembered order and picks the first currently connected screen:

```text
_screenNames[0] -> connected? -> primary
_screenNames[1] -> connected? -> primary
...
none connected -> Quickshell.screens[0]
none live      -> null
```

`primaryScreenName` is then:

```text
primaryScreen ? String(primaryScreen.name || "") : ""
```

### Automatic discovery

`refresh()` appends unknown connected names to the remembered order:

```text
connected not in _screenNames
    ↓
append to order
    ↓
saveNames()
    ↓
configurationChanged()
    ↓
screenDiscovered(name) per screen
```

The discovery signal fires only after public state is updated, so handlers can safely read `Screens.names` and `Screens.screens`.

### Config integration

The service does not implement its own JSON persistence.

Screen order is stored in:

```text
homeConfig
```

under the `screens` key through:

```qml
Config.get("screens", [])
Config.set("screens", names.slice())
```

`Config` already handles document state, watching, saving, and external reloads.

### No polling

The service does not repeatedly query screens on a timer.

It reacts to:

```text
Quickshell.onScreensChanged -> refresh()
Config.onExternalReload    -> syncFromConfig() + refresh()
Config.onRevisionChanged   -> syncFromConfig() + resolvePrimary()
Component.onCompleted      -> syncFromConfig() + refresh()
ready changes              -> syncFromConfig() + refresh()
```

---

## Limitations

### Names are connector strings

Screens are identified by connector names such as:

```text
DP-1
HDMI-A-1
eDP-1
```

There is no stable serial-based identity or user-visible label. Renaming a connector at the compositor level looks like a new screen.

### Primary is always a live screen

`primaryScreen` is never a disconnected object. If the remembered first screen is unplugged, primary moves to the next connected screen or to `Quickshell.screens[0]`.

A component must handle:

```qml
Screens.primaryScreen === null
```

and:

```qml
Screens.primaryScreenName === ""
```

on a system with no live screens.

### `setPrimary` is constrained

`setPrimary(name)` returns `false` when:

```text
name is empty
name is not connected
name is not in the remembered order
```

It does not add unknown names. The screen must already be discovered through `refresh()`.

### No per-screen settings

The service only stores order:

```json
{
    "screens": [
        "DP-1",
        "HDMI-A-1"
    ]
}
```

It does not store per-screen brightness, scale, position, wallpaper, or panel placement. Geometry comes from the live `ShellScreen` object, not from `Config`.

### Gated on `Config.isReady`

`syncFromConfig()`, `saveNames()`, and `refresh()` all return early when `Config.isReady` is `false`. Early `Quickshell.screens` changes before config load do not create persisted order until `isReady` fires.

---

# 5. Example use cases

## 5.1 A bar showing the primary screen

A bar only needs two bindings:

```qml
import QtQuick
import Quickshell

import qs.services

Row {
    spacing: 6

    Text {
        text:
            Screens.primaryScreenName
    }

    Text {
        text:
            Screens.count > 1
                ? Screens.count + " screens"
                : "single screen"
    }
}
```

The component does not need to know whether the primary came from:

```text
the first remembered screen
a fallback live screen
a recent setPrimary() call
a reconnection
```

It only receives the effective value.

---

## 5.2 One panel instance per screen

Live screens can drive per-screen windows directly:

```qml
import QtQuick
import Quickshell

import qs.services

Repeater {
    model:
        Screens.screens

    delegate: PanelWindow {
        required property var modelData

        screen:
            modelData

        Text {
            anchors.centerIn:
                parent

            text:
                modelData.name +
                (modelData.name === Screens.primaryScreenName
                    ? " (primary)"
                    : "")
        }
    }
}
```

When a monitor is plugged in or removed, `Quickshell.screens` changes, `refresh()` runs, and the repeater updates.

---

## 5.3 Reacting to new screens

Discovery is explicit:

```qml
import QtQuick

import qs.services

Connections {
    target:
        Screens

    function onScreenDiscovered(name) {
        console.info(
            "new screen:",
            name,
            Screens.isConnected(name)
        )
    }

    function onConfigurationChanged() {
        console.info(
            JSON.stringify(
                Screens.names
            )
        )
    }
}
```

`screenDiscovered` fires once per new name. `configurationChanged` fires whenever the remembered order array itself changes.

---

## 5.4 A primary-screen switcher

`setPrimary()` only reorders, so the UI is a simple list:

```qml
import QtQuick

import qs.services

Column {
    spacing: 8

    Repeater {
        model:
            Screens.connectedNames

        delegate: Rectangle {
            required property string modelData

            width: 180
            height: 34

            radius: 8

            color:
                Screens.primaryScreenName ===
                    modelData
                    ? "#2acfff"
                    : "#141d26"

            Text {
                anchors.centerIn:
                    parent

                text:
                    parent.modelData

                color:
                    Screens.primaryScreenName ===
                        parent.modelData
                        ? "#061018"
                        : "#ffffff"
            }

            MouseArea {
                anchors.fill:
                    parent

                onClicked:
                    Screens.setPrimary(
                        parent.modelData
                    )
            }
        }
    }
}
```

`setPrimary()` returns:

```text
true  -> the clicked screen is now primary
false -> it was not connected or not remembered
```

---

## 5.5 Terminal workflow

Read how many screens exist:

```bash
qs ipc call n0ctos-screens count
```

Read the primary name:

```bash
qs ipc call n0ctos-screens primary
```

Read the remembered order:

```bash
qs ipc call n0ctos-screens names
```

Read only connected names:

```bash
qs ipc call n0ctos-screens connected
```

Check one screen:

```bash
qs ipc call n0ctos-screens isConnected DP-1
```

Inspect every live screen:

```bash
qs ipc call n0ctos-screens list
```

Inspect one screen:

```bash
qs ipc call n0ctos-screens get DP-1
```

Inspect the primary screen:

```bash
qs ipc call n0ctos-screens getPrimary
```

Change the primary:

```bash
qs ipc call n0ctos-screens setPrimary HDMI-A-1
```

Force a re-scan:

```bash
qs ipc call n0ctos-screens refresh
```

---

# 6. Detailed architecture

This section is for developers working on `Screens.qml` and the services/components that consume it.

---

## 6.1 Overall architecture

The service is an index and priority layer between `Quickshell.screens` and `Config`.

```text
N0ctOS Component / Service
            │
            ▼
      Screens.qml
            │
     ┌──────┼────────┐
     │      │        │
     ▼      ▼        ▼
 remembered live   primary
  order   screens  resolution
     │      │        │
     └──────┴────────┘
            │
     ┌──────┴──────┐
     ▼             ▼
   Config      Quickshell
     │          screens
     ▼
 homeConfig
```

There are effectively two responsibilities:

```text
Screens
    screen identity, order, and primary selection

Config + Quickshell
    persistence and hardware detection
```

Screens should not duplicate the file management already provided by Config, or the topology detection already provided by Quickshell.

---

## 6.2 Remembered vs connected vs live

Three related but different lists exist:

```text
names
    remembered priority, includes disconnected
    _screenNames.slice()

connectedNames
    currently connected names only
    _connectedNames.slice()

screens
    live ShellScreen objects
    Quickshell.screens
```

The rule is:

```text
order     -> names
presence  -> connectedNames
objects   -> screens
selection -> primaryScreen
```

`screenForName()` bridges names and objects through the internal `_connectedByName` map.

---

## 6.3 Configuration structure

The service owns the `screens` key of `homeConfig`.

The structure is:

```json
{
    "screens": [
        "DP-1",
        "HDMI-A-1"
    ]
}
```

A single-monitor system might look like:

```json
{
    "screens": [
        "eDP-1"
    ]
}
```

The service itself does not require every name to be currently connected. Disconnected entries are valid data.

---

## 6.4 Normalization

`syncFromConfig()` normalizes the stored array:

```text
Config.get("screens", [])
    ↓
skip null / undefined
    ↓
String(value)
    ↓
skip "" and duplicates
    ↓
normalized array
```

It then compares element by element against `_screenNames`. If nothing changed it returns `false` without emitting `configurationChanged()`. Otherwise it replaces `_screenNames`, emits the signal, and returns `true`.

---

## 6.5 Refresh lifecycle

`refresh()` is the single topology ingest:

```text
guard Config.isReady and _refreshing
        │
        ▼
index Quickshell.screens by String(screen.name)
        │
        ▼
_connectedByName = prototype-less map
_connectedNames = connectedNames
        │
        ▼
new names? ── yes ──► append, saveNames(),
                       configurationChanged(),
                       screenDiscovered(name) per name
              │
              no
              │
              ▼
resolvePrimary()
        │
        ▼
_refreshing = false
        │
        ▼
refreshed()
```

The map uses `Object.create(null)` because connector names are arbitrary strings and must not collide with `Object.prototype` keys.

The `_refreshing` flag prevents reentrant refreshes when `saveNames()` triggers `onRevisionChanged()` mid-refresh.

---

## 6.6 Primary resolution

`resolvePrimary()` performs:

```text
walk _screenNames in order
    ↓
first name present in _connectedByName wins
    ↓
none matched + live screens exist -> Quickshell.screens[0]
    ↓
none live -> null
```

It then logs only when the name actually changed:

```text
[Screens] primary: DP-1
[Screens] primary: (none)
```

`setPrimary()` reuses this by moving the target to index `0` first:

```text
setPrimary("HDMI-A-1")
    │
    ▼
["DP-1","HDMI-A-1"] -> ["HDMI-A-1","DP-1"]
    │
    ▼
saveNames() + configurationChanged()
    │
    ▼
resolvePrimary()
    │
    ▼
primaryScreenName === "HDMI-A-1" ?
```

---

## 6.7 Config reactivity

External and local config changes take different paths on purpose:

```text
editor changes config file
        │
        ▼
Config.onExternalReload
        │
        ▼
syncFromConfig() + refresh()
```

because physical topology may also have changed, while:

```text
local Config.set("screens", ...)
        │
        ▼
Config.onRevisionChanged
        │
        ▼
syncFromConfig() + resolvePrimary()
```

because a revision bump alone does not mean new hardware appeared. Only primary selection needs updating.

Startup covers both cold paths:

```text
Component.onCompleted -> syncFromConfig() + refresh()
ready changes to true -> syncFromConfig() + refresh()
```

---

## 6.8 IPC architecture

IPC is a thin external interface over the same service state.

Conceptually:

```text
terminal
   │
   ▼
n0ctos-screens
   │
   ▼
Screens.qml
   │
   ├────▼────┐
   ▼         ▼
 Config   Quickshell
```

For example:

```bash
qs ipc call n0ctos-screens primary
```

becomes conceptually:

```qml
Screens.primaryScreenName
```

and:

```bash
qs ipc call n0ctos-screens get DP-1
```

becomes conceptually:

```qml
JSON.stringify(
    Screens._screenInfo(
        Screens.screenForName("DP-1")
    )
)
```

The IPC layer serializes screen objects as JSON strings for terminal use because raw `ShellScreen` objects cannot cross IPC.

---

## 6.9 Final architecture summary

The entire system can be viewed as:

```text
                          Component
                             │
                             │ property binding / function call
                             ▼
                     ┌─────────────────┐
                     │     Screens     │
                     │                 │
                     │ remembered order│
                     │ live index      │
                     │ primary         │
                     │ discovery       │
                     └────────┬────────┘
                              │
                              │ Config API + Quickshell API
                              ▼
                     ┌─────────────────┐
                     │ Config +        │
                     │ Quickshell      │
                     │                 │
                     │ homeConfig      │
                     │ screens         │
                     │ topology        │
                     └────────┬────────┘
                              │
                              ▼
                      config file + hardware
```

The core rule is:

> **Components read what screen state they need; `Screens.qml` decides remembered order and which connected screen is primary; `Config` handles how order is persisted and `Quickshell` handles how hardware topology is detected.**
