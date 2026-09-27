# Audio Service

`Audio.qml` is N0ctOS's centralized PipeWire audio service.

It gives every shell component one consistent place to read volume, mute, device, stream, profile, route, and priority state without touching PipeWire or configuration files directly.

The service supports output devices (sinks), input devices (sources), per-application streams, default device selection, volume/mute control, device priority lists, card profiles/routes via `wpctl`, display helpers, and JSON serialization for IPC.

The normal usage pattern is:

```text
Component
    │
    ▼
Audio
    │
    ├── outputs / inputs / streams
    ├── defaultOutput / defaultInput
    ├── volume / mute state
    └── preferred device + priority
    │
    ▼
Pipewire + Config
    │
    ├── Pipewire.nodes / defaults (live audio)
    └── homeConfig (step + priorities)
```

---

# 1. What does it do?

`Audio.qml` exposes the live PipeWire graph as reactive QML state.

A minimal configuration looks like:

```json
{
    "audio": {
        "step": 5,
        "outputPriority": [],
        "inputPriority": []
    }
}
```

or with remembered device preferences:

```json
{
    "audio": {
        "step": 5,
        "outputPriority": [
            "alsa_output.usb-Focusrite_Scarlett-00.analog-stereo",
            "alsa_output.pci-0000_00_1f.3.analog-stereo"
        ],
        "inputPriority": [
            "alsa_input.usb-Blue_Microphones_Yeti-00.analog-stereo"
        ]
    }
}
```

PipeWire itself provides the devices:

```text
Pipewire.nodes
    ├── sinks (outputs, e.g. speakers / headphones)
    ├── sources (inputs, e.g. microphones)
    └── streams (per-application audio, e.g. Firefox / mpv)
```

The service classifies those nodes:

```text
allNodes
    ├── outputs (isSink, not stream)
    ├── inputs (not sink, not stream)
    └── streams (isStream)
```

And exposes the effective state:

```text
defaultOutput (Pipewire.defaultAudioSink)
    ├── volume / percent / percentText
    ├── isMuted
    ├── outputName / outputIcon
    └── hasOutput

defaultInput (Pipewire.defaultAudioSource)
    ├── inputVolume / inputPercentText
    ├── isInputMuted
    ├── inputName / inputIcon
    └── hasInput
```

So a component can simply do:

```qml
Text {
    text: Audio.percentText
}

Text {
    text: Audio.outputName
}
```

and not care where the value came from.

If PipeWire is not ready, volume reads return `0`, mute reads return `false`, and names return `""`.

---

# 2. UI API

Import normally:

```qml
import QtQuick
import Quickshell

import qs.services
```

## Core API

| How to call | What does it do |
| --- | --- |
| `Audio.isReady` | Whether PipeWire is ready (`Pipewire.ready`). |
| `Audio.allNodes` | Raw `Pipewire.nodes` object. |
| `Audio.outputs` / `Audio.inputs` / `Audio.streams` | Filtered `ScriptModel` objects for sinks, sources, streams. |
| `Audio.outputList` / `Audio.inputList` / `Audio.streamList` | Plain `values` arrays from those models. |
| `Audio.devices` / `Audio.deviceList` | All audio nodes model / array (`audio !== null`). |
| `Audio.defaultOutput` / `Audio.defaultInput` | Native PipeWire default sink / source. |
| `Audio.preferredOutput` / `Audio.preferredInput` | First priority-list match, else first available node, else `null`. |
| `Audio.volume` / `Audio.percent` / `Audio.percentRounded` / `Audio.percentText` | Default output volume as `0-200+` real, rounded int, and `"42%"` text. |
| `Audio.isMuted` / `Audio.hasOutput` / `Audio.outputName` / `Audio.outputIcon` | Default output mute, presence, display name, icon. |
| `Audio.inputVolume` / `Audio.inputPercent` / `Audio.inputPercentText` | Default input volume equivalents. |
| `Audio.isInputMuted` / `Audio.hasInput` / `Audio.inputName` / `Audio.inputIcon` | Default input mute, presence, display name, icon. |
| `Audio.step` | Volume step (`audio.step`, default `5`, clamped `1-100`). |
| `Audio.outputPriority` / `Audio.inputPriority` | Normalized remembered device priority arrays. |
| `Audio.nodeForId(id)` | Finds a node by numeric PipeWire id, else `null`. |
| `Audio.nodeForName(name)` | Finds a node by `node.name` or `displayName()`, else `null`. |
| `Audio.resolveNode(value)` | Resolves node object, numeric id, or name string to a node, else `null`. |
| `Audio.setOutput(value)` | Sets default sink by node/id/name. Updates PipeWire preference, runs `wpctl set-default`, promotes priority. Returns `bool`. |
| `Audio.setInput(value)` | Sets default source by node/id/name. Same side effects as `setOutput()`. Returns `bool`. |
| `Audio.setOutputPriority(values)` / `Audio.setInputPriority(values)` | Normalizes and persists a priority array via `Config.set()`. |
| `Audio.setVolume(node, percent)` | Sets any node's volume, clamped `0-200`. Returns `bool`. |
| `Audio.increase(node, amount)` / `Audio.decrease(node, amount)` | Adjusts any node's volume by `amount` or `step` when invalid. Returns `bool`. |
| `Audio.setOutputVolume(percent)` / `Audio.setInputVolume(percent)` | Convenience wrappers for the current default sink / source. |
| `Audio.setMute(node, muted)` | Sets any node's mute state. Returns `bool`. |
| `Audio.toggleMute(node)` | Flips any node's mute state. Returns `bool`. |
| `Audio.toggleOutputMute()` / `Audio.toggleInputMute()` | Flips the current default sink / source mute. Returns `bool`. |
| `Audio.setProfile(node, index)` | Runs `wpctl set-profile <id> <index>` for a card. Returns `bool`. |
| `Audio.setRoute(node, index)` | Runs `wpctl set-route <id> <index>` for a card. Returns `bool`. |
| `Audio.displayName(node)` | `nickname` → `description` → `application.name` → `media.name` → `name` → `""`. |
| `Audio.applicationName(node)` / `Audio.mediaName(node)` / `Audio.mediaTitle(node)` / `Audio.mediaArtist(node)` / `Audio.applicationIconName(node)` | Reads `node.properties` fields, else `""`. |
| `Audio.icon(node)` | Nerd Font icon for sink / source / stream with mute variant. |
| `Audio.isOutput(node)` / `Audio.isInput(node)` / `Audio.isStream(node)` | Node classification predicates. |
| `Audio.isDefaultOutput(node)` / `Audio.isDefaultInput(node)` | Identity check against the current defaults. |
| `Audio.normalizeStep(value)` | Coerces to number, defaults `5`, clamps `1-100`. |
| `Audio.normalizePriority(value)` | Coerces to deduplicated string array, drops null/empty. |
| `Audio.nodeInfo(node)` | Serializes a node to a plain JSON-ready object. |

| Example | Result |
| --- | --- |
| `Audio.nodeForId(48)` | node object, or `null` when 48 is untracked |
| `Audio.nodeForName("alsa_output.pci-0000_00_1f.3.analog-stereo")` | node object, or `null` when no name matches |
| `Audio.resolveNode("48")` | node object, or `null` |
| `Audio.setOutput("Headphones")` | `true`, default sink switches (`false` when not found) |
| `Audio.setVolume(Audio.defaultOutput, 42)` | `true`, volume becomes 42 % |
| `Audio.increase(Audio.defaultOutput)` | `true`, volume rises by `step` (default 5) |
| `Audio.setOutputVolume(42)` | `true`, default sink becomes 42 % |
| `Audio.setMute(Audio.defaultOutput, true)` | `true`, default sink muted |
| `Audio.toggleOutputMute()` | `true`, mute state flips |
| `Audio.setProfile(cardNode, 1)` | `true` (`false` when the `wpctl` call fails) |
| `Audio.setRoute(cardNode, 2)` | `true` (`false` when the `wpctl` call fails) |
| `Audio.nodeInfo(node)` | `{id, name, volume, ...}` JSON-ready object |

## Node identity

Many functions accept a flexible node reference:

```text
node object (with .audio)
    → used directly

"48" / 48
    → nodeForId()

"alsa_output... " / "Headphones"
    → nodeForName()
        ├── String(node.name)
        └── displayName(node)
```

For example:

```qml
Audio.setVolume(
    Audio.defaultOutput,
    42
)
```

```qml
Audio.setVolume(
    48,
    42
)
```

```qml
Audio.setVolume(
    "Headphones",
    42
)
```

all resolve through `resolveNode()`.

The exception is the per-node IPC path (`setNodeVolume` / `setNodeMute`), which resolves by numeric id only via `nodeForId()`.

## Volume semantics

Volume is stored by PipeWire as `0.0-1.0+` and exposed by the service as percent:

```text
PipeWire audio.volume (0.42)
        │
        ▼
_nodeVolume() → 42.0
        │
        ├── volume / percent (real)
        ├── percentRounded (int)
        └── percentText ("42%")
```

`setVolume()` clamps to:

```text
0 … 200
```

Values above `100` are intentional — PipeWire permits amplification beyond `100%` and the service does not artificially force a `100` ceiling.

`increase()` / `decrease()` fall back to `Audio.step` when the amount is missing, non-numeric, or `<= 0`:

```qml
Audio.increase(
    Audio.defaultOutput
)
```

uses `Audio.step` (default `5`).

### Typical component usage

```qml
Text {
    text: Audio.percentText
}

Text {
    text:
        Audio.isMuted
            ? "Muted"
            : Audio.outputName
}

MouseArea {
    anchors.fill: parent

    onClicked:
        Audio.toggleOutputMute()
}
```

A volume slider:

```qml
Slider {
    from: 0
    to: 150
    value: Audio.volume

    onMoved:
        Audio.setOutputVolume(
            value
        )
}
```

That is the intended everyday usage.

Components normally should not need to know how PipeWire nodes, `wpctl`, or priority persistence work.

---

# 3. IPC API

IPC target:

```text
n0ctos-audio
```

## Global state

| How to call | What does it do |
| --- | --- |
| `ready` | Returns whether PipeWire is ready. |
| `get` | Returns compact JSON with output/input readiness, names, percents, and mute. |

| Example | Result |
| --- | --- |
| `qs ipc call n0ctos-audio ready` | `true` when PipeWire is ready, else `false` |
| `qs ipc call n0ctos-audio get` | JSON status object (see below) |

```bash
qs ipc call n0ctos-audio get
```

returns e.g.:

```json
{
    "isReady": true,
    "hasOutput": true,
    "output": "Built-in Audio Analog Stereo",
    "percent": 42,
    "isMuted": false,
    "hasInput": true,
    "input": "Yeti Stereo Microphone",
    "inputPercent": 70,
    "isInputMuted": false
}
```

## Output operations

| How to call | What does it do |
| --- | --- |
| `outputs` | Returns JSON array of `nodeInfo()` for every sink. |
| `setOutput <name>` | Sets default sink by id or name. |
| `setOutputVolume <percent>` | Sets default sink volume (`0-200`). |
| `increase [percent]` | Raises default sink volume by amount or configured step. |
| `decrease [percent]` | Lowers default sink volume by amount or configured step. |
| `mute <bool>` | Sets default sink mute. |
| `toggleMute` | Flips default sink mute. |

| Example | Result |
| --- | --- |
| `qs ipc call n0ctos-audio outputs` | JSON array of sink `nodeInfo()` objects |
| `qs ipc call n0ctos-audio setOutput Headphones` | `true` when the sink was found |
| `qs ipc call n0ctos-audio setOutputVolume 42` | `true`, default sink becomes 42 % |
| `qs ipc call n0ctos-audio increase 5` | `true`, volume rises by 5 |
| `qs ipc call n0ctos-audio decrease 5` | `true`, volume falls by 5 |
| `qs ipc call n0ctos-audio mute true` | `true`, default sink muted |
| `qs ipc call n0ctos-audio toggleMute` | `true`, mute state flips |

```bash
qs ipc call n0ctos-audio setOutputVolume 42
```

```bash
qs ipc call n0ctos-audio increase 5
```

```bash
qs ipc call n0ctos-audio toggleMute
```

## Input operations

| How to call | What does it do |
| --- | --- |
| `inputs` | Returns JSON array of `nodeInfo()` for every source. |
| `setInput <name>` | Sets default source by id or name. |
| `setInputVolume <percent>` | Sets default source volume (`0-200`). |
| `muteInput <bool>` | Sets default source mute. |
| `toggleInputMute` | Flips default source mute. |

| Example | Result |
| --- | --- |
| `qs ipc call n0ctos-audio inputs` | JSON array of source `nodeInfo()` objects |
| `qs ipc call n0ctos-audio setInput Yeti` | `true` when the source was found |
| `qs ipc call n0ctos-audio setInputVolume 70` | `true`, default source becomes 70 % |
| `qs ipc call n0ctos-audio muteInput true` | `true`, default source muted |
| `qs ipc call n0ctos-audio toggleInputMute` | `true`, mute state flips |

```bash
qs ipc call n0ctos-audio setInputVolume 70
```

```bash
qs ipc call n0ctos-audio toggleInputMute
```

## Stream / per-node operations

| How to call | What does it do |
| --- | --- |
| `streams` | Returns JSON array of `nodeInfo()` for every application stream. |
| `setNodeVolume <id> <percent>` | Sets any node's volume by numeric PipeWire id (`0-200`). |
| `setNodeMute <id> <bool>` | Sets any node's mute by numeric PipeWire id. |

| Example | Result |
| --- | --- |
| `qs ipc call n0ctos-audio streams` | JSON array of stream `nodeInfo()` objects |
| `qs ipc call n0ctos-audio setNodeVolume 87 50` | `true`, node 87 becomes 50 % |
| `qs ipc call n0ctos-audio setNodeMute 87 true` | `true`, node 87 muted |

`<id>` must be a numeric PipeWire node id.

For example:

```bash
qs ipc call n0ctos-audio streams
```

```bash
qs ipc call n0ctos-audio setNodeVolume 87 50
```

```bash
qs ipc call n0ctos-audio setNodeMute 87 false
```

## Profile / route operations

| How to call | What does it do |
| --- | --- |
| `setProfile <id> <index>` | Runs `wpctl set-profile` for a card node. |
| `setRoute <id> <index>` | Runs `wpctl set-route` for a card node. |

| Example | Result |
| --- | --- |
| `qs ipc call n0ctos-audio setProfile 41 1` | `true` when the `wpctl` call succeeds |
| `qs ipc call n0ctos-audio setRoute 41 2` | `true` when the `wpctl` call succeeds |

Both `<id>` and `<index>` must be integers.

```bash
qs ipc call n0ctos-audio setProfile 41 1
```

```bash
qs ipc call n0ctos-audio setRoute 41 2
```

## Priority operations

| How to call | What does it do |
| --- | --- |
| `getOutputPriority` | Returns output priority array as JSON. |
| `getInputPriority` | Returns input priority array as JSON. |
| `setOutputPriority <json>` | Replaces output priority with a JSON array. |
| `setInputPriority <json>` | Replaces input priority with a JSON array. |

| Example | Result |
| --- | --- |
| `qs ipc call n0ctos-audio getOutputPriority` | `["hdmi","analog"]`-style JSON array |
| `qs ipc call n0ctos-audio getInputPriority` | `["yeti"]`-style JSON array |
| `qs ipc call n0ctos-audio setOutputPriority '["hdmi","analog"]'` | `true`, priority list replaced |
| `qs ipc call n0ctos-audio setInputPriority '["yeti"]'` | `true`, priority list replaced |

`<json>` must be valid JSON array.

For example:

```bash
qs ipc call n0ctos-audio setOutputPriority \
    '["alsa_output.usb-Focusrite_Scarlett-00.analog-stereo"]'
```

```bash
qs ipc call n0ctos-audio getOutputPriority
```

---

# 4. Features / limitations

## Features

### Filtered PipeWire models

The service never exposes raw unfiltered PipeWire nodes to UI code directly for device lists.

Instead it builds:

```text
Pipewire.nodes
    │
    ▼
audioNodeModel (audio !== null)
    │
    ├── outputModel (isSink, not stream)
    ├── inputModel (not sink, not stream)
    └── streamModel (isStream)
```

UI code therefore binds to already-classified lists:

```qml
Audio.outputList
Audio.inputList
Audio.streamList
```

### Tracked audio objects

Only audio nodes are bound because volume, mute, channels, and properties are invalid until a node is tracked:

```qml
PwObjectTracker {
    objects: audioNodeModel.values
}
```

This is declared once in the service so consumers never need their own tracker.

### Reactive default devices

`defaultOutput` and `defaultInput` are thin aliases:

```text
defaultOutput = Pipewire.defaultAudioSink
defaultInput  = Pipewire.defaultAudioSource
```

All derived state reevaluates automatically:

```text
defaultOutput changes
        │
        ▼
volume / isMuted / outputName / outputIcon change
        │
        ▼
component bindings reevaluate
```

### Change signals

The service emits:

```text
outputChanged(node)
inputChanged(node)
streamChanged(node)
```

`outputChanged` fires when `Pipewire.defaultAudioSink` changes, `inputChanged` when `Pipewire.defaultAudioSource` changes, and `streamChanged` when a new stream node is inserted.

Components that need imperative reactions (e.g. OSD popups) can use these instead of polling volume.

### Flexible node resolution

Callers can pass a node object, numeric id, or human-readable name:

```qml
Audio.setOutput(nodeObject)
Audio.setOutput(48)
Audio.setOutput("Headphones")
```

Name matching checks both `node.name` and `displayName(node)`, so UI-visible names work as input.

### Dual default switching

`setOutput()` / `setInput()` perform three actions at once:

```text
1. Pipewire.preferredDefaultAudioSink/Source = node
2. wpctl set-default <id> (immediate WirePlumber default)
3. promote node.name to front of audio.*Priority (N0ctOS memory)
```

This covers both the native PipeWire preference and the immediate default, plus N0ctOS's own remembered ordering.

### Priority memory

`audio.outputPriority` / `audio.inputPriority` remember previously selected devices:

```json
{
    "outputPriority": [
        "alsa_output.usb-Focusrite_Scarlett-00.analog-stereo"
    ]
}
```

`preferredOutput` / `preferredInput` resolve the first currently-available priority entry, else the first available node, else `null`:

```text
priority[0] available → use it
priority[1] available → use it
...
none available → nodes[0]
no nodes → null
```

Selecting a device promotes it to the front and deduplicates the list automatically.

### Step configuration

`audio.step` controls the default `increase()` / `decrease()` amount:

```json
{
    "audio": {
        "step": 5
    }
}
```

It is normalized to `1-100` and defaults to `5` when missing or invalid.

### Volume beyond 100%

The service intentionally allows `0-200`:

```qml
Audio.setVolume(node, 150)
```

PipeWire amplification above `100%` is valid, so the service does not clamp to `100`.

### Display helpers

`displayName()` implements the standard N0ctOS fallback chain:

```text
nickname
    ↓
description
    ↓
application.name
    ↓
media.name
    ↓
name
    ↓
""
```

`icon()` returns mute-aware Nerd Font glyphs:

```text
stream / sink muted   → muted speaker
stream / sink unmuted → speaker
source muted          → muted mic
source unmuted        → mic
null node             → placeholder
```

Per-stream metadata helpers (`applicationName`, `mediaTitle`, `mediaArtist`, `applicationIconName`) read `node.properties` safely and return `""` when absent.

### Classification predicates

UI delegates can branch without reimplementing PipeWire checks:

```qml
Audio.isOutput(node)
Audio.isInput(node)
Audio.isStream(node)
Audio.isDefaultOutput(node)
Audio.isDefaultInput(node)
```

### JSON serialization

`nodeInfo()` converts a live PipeWire node into plain data:

```json
{
    "id": 48,
    "name": "alsa_output.pci-0000_00_1f.3.analog-stereo",
    "displayName": "Built-in Audio Analog Stereo",
    "description": "Built-in Audio Analog Stereo",
    "nickname": "",
    "type": "Audio/Sink",
    "isStream": false,
    "isSink": true,
    "isOutput": true,
    "isInput": false,
    "isDefaultOutput": true,
    "isDefaultInput": false,
    "isMuted": false,
    "percent": 42,
    "applicationName": "",
    "mediaName": "",
    "mediaTitle": "",
    "mediaArtist": "",
    "applicationIconName": "",
    "icon": "󰕾"
}
```

This is what `outputs` / `inputs` / `streams` IPC calls return, and it is safe to pass to JSON views or external scripts.

### Config integration

The service does not implement its own JSON persistence.

All remembered state is handled through `Config`:

```text
audio.step
audio.outputPriority
audio.inputPriority
```

which live in:

```text
homeConfig
```

which is the normal N0ctOS user configuration file.

### Reactive configuration

Changing step or priority updates the service's reactive state.

`step`, `outputPriority`, and `inputPriority` are bindings over `Config.get()`, so external config edits propagate without an explicit reload call.

### No polling

The service does not repeatedly query PipeWire.

It relies on:

```text
Pipewire reactive nodes/defaults
+
Config reactive document
```

Volume sliders and device lists therefore update on events, not timers.

---

## Limitations

### Requires PipeWire / WirePlumber

When `Pipewire.ready` is `false`:

```text
volume → 0
isMuted → false
names → ""
hasOutput / hasInput → false
```

The service does not synthesize fake devices or queue volume changes for later.

### Removed nodes are not retained

`onObjectRemovedPost` intentionally does nothing:

```text
PipeWire owns node lifetimes.
We intentionally don't retain removed nodes.
```

Holding a reference to a removed node will not keep it usable.

### `wpctl` dependency for defaults/profiles/routes

Immediate default switching, profile switching, and route switching shell out to `wpctl`:

```text
wpctl set-default <id>
wpctl set-profile <id> <index>
wpctl set-route <id> <index>
```

These are fire-and-forget `execDetached()` actions. The service returns `true` when the arguments resolve, not when `wpctl` confirms success.

### Profile/route indices are opaque integers

The service does not enumerate available profiles or routes:

```qml
Audio.setProfile(node, index)
Audio.setRoute(node, index)
```

Callers must already know the valid integer index (e.g. from `wpctl inspect` or `wpctl status`). Non-integer indices return `false`.

### `setOutput` / `setInput` validate direction

`setOutput()` rejects non-sinks and streams:

```text
!node || !node.isSink || node.isStream → false
```

`setInput()` rejects sinks and streams:

```text
!node || node.isSink || node.isStream → false
```

Passing a stream node to either function always fails. Use `setVolume()` / `setMute()` for streams.

### Per-node IPC is id-only

QML `setVolume()` / `setMute()` accept objects, ids, or names via `resolveNode()`.

IPC `setNodeVolume` / `setNodeMute` accept only numeric ids via `nodeForId()`:

```bash
qs ipc call n0ctos-audio setNodeVolume 87 50
```

Name-based per-stream control from the terminal requires resolving the id first via `streams`.

### Volume writes need a tracked audio object

If `node.audio === null`, the helpers return safe defaults and writes return `false`:

```text
_nodeAudio() → null
_nodeVolume() → 0
_nodeMuted() → false
setVolume() → false
setMute() → false
```

This normally only happens for nodes that have not been tracked yet or are not audio nodes.

### Priority matches by name or id string

`_preferred()` compares `String(node.name)` and `String(node.id)` against priority entries.

Renamed devices (e.g. after a driver or USB port change) will not match an old priority entry and will fall back to the first available node.

### Priority stores names, not full objects

Only `String(node.name)` is promoted to the priority list, not the full node. Display names, ids, and metadata are resolved live on each evaluation.

---

# 5. Example use cases

## 5.1 A panel volume readout

A panel widget should expose volume as text and icon:

```qml
import QtQuick
import Quickshell

import qs.services

Row {
    spacing: 8

    Text {
        text: Audio.outputIcon
    }

    Text {
        text:
            !Audio.isReady
                ? "No audio"
                : Audio.isMuted
                    ? "Muted"
                    : Audio.percentText
    }
}
```

The widget does not need to know whether the value came from:

```text
a sink volume change
a default-sink switch
a mute toggle
PipeWire becoming ready
```

It only receives the effective value.

---

## 5.2 A clickable mute button

Toggle the default output on click:

```qml
MouseArea {
    onClicked:
        Audio.toggleOutputMute()
}
```

Explicit set:

```qml
Audio.setMute(
    Audio.defaultOutput,
    true
)
```

From IPC:

```bash
qs ipc call n0ctos-audio toggleMute
```

```bash
qs ipc call n0ctos-audio mute true
```

```bash
qs ipc call n0ctos-audio mute false
```

---

## 5.3 Volume keys with the configured step

Bind media keys to `increase()` / `decrease()` without hardcoding the step:

```qml
Audio.increase(
    Audio.defaultOutput
)

Audio.decrease(
    Audio.defaultOutput
)
```

When `amount` is omitted or invalid, `Audio.step` (`audio.step`, default `5`) is used.

Explicit amount:

```qml
Audio.increase(
    Audio.defaultOutput,
    10
)
```

From IPC:

```bash
qs ipc call n0ctos-audio increase 5
```

```bash
qs ipc call n0ctos-audio decrease 5
```

---

## 5.4 An output device switcher

List all sinks and highlight the default:

```qml
import QtQuick
import Quickshell

import qs.services

Column {
    Repeater {
        model: Audio.outputList

        delegate: Row {
            required property var modelData

            spacing: 8

            Text {
                text:
                    Audio.isDefaultOutput(
                        modelData
                    )
                        ? "●"
                        : "○"
            }

            Text {
                text:
                    Audio.displayName(
                        modelData
                    )
            }

            Text {
                text:
                    Math.round(
                        Audio.nodeInfo(
                            modelData
                        ).percent
                    ) + "%"
            }

            MouseArea {
                anchors.fill: parent

                onClicked:
                    Audio.setOutput(
                        modelData
                    )
            }
        }
    }
}
```

`setOutput()` accepts the node object directly. Strings and ids also work:

```qml
Audio.setOutput(
    "Headphones"
)
```

```qml
Audio.setOutput(48)
```

---

## 5.5 An input / microphone switcher

The same pattern applies to sources:

```qml
Repeater {
    model: Audio.inputList

    delegate: Text {
        required property var modelData

        text:
            Audio.displayName(
                modelData
            )

        MouseArea {
            anchors.fill: parent

            onClicked:
                Audio.setInput(
                    parent.modelData
                )
        }
    }
}
```

Mute the microphone:

```qml
Audio.toggleInputMute()
```

```bash
qs ipc call n0ctos-audio toggleInputMute
```

---

## 5.6 A per-application volume mixer

List live streams with individual sliders:

```qml
Column {
    Repeater {
        model: Audio.streamList

        delegate: Row {
            required property var modelData

            spacing: 8

            Text {
                text:
                    Audio.displayName(
                        modelData
                    )
            }

            Text {
                text:
                    Audio.mediaTitle(
                        modelData
                    )
            }

            Slider {
                from: 0
                to: 150

                value:
                    Audio.nodeInfo(
                        modelData
                    ).percent

                onMoved:
                    Audio.setVolume(
                        modelData,
                        value
                    )
            }

            MouseArea {
                onClicked:
                    Audio.toggleMute(
                        modelData
                    )
            }
        }
    }
}
```

Per-stream identity helpers are useful here:

```qml
Audio.applicationName(node)
Audio.mediaName(node)
Audio.mediaTitle(node)
Audio.mediaArtist(node)
Audio.applicationIconName(node)
```

---

## 5.7 Remembering device order with priorities

Persist an explicit ordering:

```qml
Audio.setOutputPriority(
    [
        "alsa_output.usb-Focusrite_Scarlett-00.analog-stereo",
        "alsa_output.pci-0000_00_1f.3.analog-stereo"
    ]
)
```

Read it back:

```qml
Audio.outputPriority
Audio.preferredOutput
```

From IPC (note the JSON-string argument):

```bash
qs ipc call n0ctos-audio setOutputPriority \
    '["alsa_output.usb-Focusrite_Scarlett-00.analog-stereo","alsa_output.pci-0000_00_1f.3.analog-stereo"]'
```

```bash
qs ipc call n0ctos-audio getOutputPriority
```

Selecting a device via `setOutput()` automatically promotes it to the front of the stored list, so manual priority editing is only needed for explicit ordering.

---

## 5.8 Switching card profiles and routes

For Bluetooth / HDMI cards that expose multiple profiles:

```qml
Audio.setProfile(cardNode, 1)
Audio.setRoute(cardNode, 2)
```

By id:

```qml
Audio.setProfile(41, 1)
```

From IPC:

```bash
qs ipc call n0ctos-audio setProfile 41 1
```

```bash
qs ipc call n0ctos-audio setRoute 41 2
```

These run `wpctl set-profile` / `wpctl set-route` detached. They return `true` when the node and integer index resolve, not when the card confirms the switch.

---

## 5.9 Reacting to device changes

Use the signals for OSDs or notifications:

```qml
Connections {
    target: Audio

    function onOutputChanged(node) {
        console.log(
            "Output →",
            Audio.displayName(node)
        )
    }

    function onInputChanged(node) {
        console.log(
            "Input →",
            Audio.displayName(node)
        )
    }

    function onStreamChanged(node) {
        console.log(
            "New stream →",
            Audio.displayName(node)
        )
    }
}
```

`streamChanged` fires when a new application stream appears. There is intentionally no retained callback for removed nodes because PipeWire owns those lifetimes.

---

## 5.10 Debugging with serialized node data

Inspect one node:

```qml
Text {
    text:
        JSON.stringify(
            Audio.nodeInfo(
                Audio.defaultOutput
            ),
            null,
            2
        )
}
```

This is useful when debugging name/icon/percent behavior because it shows exactly what the service derived from the live node.

---

## 5.11 Terminal workflow

Check readiness and summary state:

```bash
qs ipc call n0ctos-audio ready
qs ipc call n0ctos-audio get
```

List devices and streams:

```bash
qs ipc call n0ctos-audio outputs
qs ipc call n0ctos-audio inputs
qs ipc call n0ctos-audio streams
```

Adjust the default sink:

```bash
qs ipc call n0ctos-audio setOutputVolume 42
qs ipc call n0ctos-audio increase 5
qs ipc call n0ctos-audio decrease 5
qs ipc call n0ctos-audio toggleMute
```

Switch defaults:

```bash
qs ipc call n0ctos-audio setOutput Headphones
qs ipc call n0ctos-audio setInput Yeti
```

Control one application by id:

```bash
qs ipc call n0ctos-audio setNodeVolume 87 50
qs ipc call n0ctos-audio setNodeMute 87 true
```

Manage remembered order:

```bash
qs ipc call n0ctos-audio getOutputPriority
qs ipc call n0ctos-audio getInputPriority
```

---

# 6. Detailed architecture

This section is for developers working on `Audio.qml` and the services/components that consume it.

---

## 6.1 Overall architecture

The service is a reactive adapter over PipeWire with a small Config-backed preference layer.

```text
N0ctOS Component / Service
            │
            ▼
       Audio.qml
            │
     ┌──────┼──────────┐
     │      │          │
     ▼      ▼          ▼
  Models  Defaults  Helpers
     │      │          │
     │      │     displayName/icon
     │      │     classification
     │      │     nodeInfo
     │      │
     ▼      ▼
  Pipewire Config
     │      │
     ▼      ▼
 live graph homeConfig
```

There are effectively three responsibilities:

```text
Audio
    PipeWire classification and control

Pipewire (Quickshell)
    live node graph and native defaults

Config
    step + priority persistence and reactivity
```

Audio should not duplicate functionality already provided by PipeWire or Config.

---

## 6.2 Configuration structure

The service owns the `audio` section of `homeConfig`.

The structure is:

```json
{
    "audio": {
        "step": 5,
        "outputPriority": [],
        "inputPriority": []
    }
}
```

A real configuration might look like:

```json
{
    "audio": {
        "step": 5,

        "outputPriority": [
            "alsa_output.usb-Focusrite_Scarlett-00.analog-stereo",
            "alsa_output.pci-0000_00_1f.3.analog-stereo"
        ],

        "inputPriority": [
            "alsa_input.usb-Blue_Microphones_Yeti-00.analog-stereo"
        ]
    }
}
```

Everything else (volumes, mutes, defaults, streams) is live PipeWire state, not stored configuration.

---

## 6.3 The three node layers

PipeWire nodes are split once, then reused everywhere:

```text
Pipewire.nodes
    │
    ▼
audioNodeModel (node && node.audio !== null)
    │
    ├── outputModel (!isStream && isSink)
    ├── inputModel (!isStream && !isSink)
    └── streamModel (isStream)
```

The exposed aliases are:

```text
outputs / outputList → sinks
inputs / inputList   → sources
streams / streamList → application streams
devices / deviceList → everything audio-capable
allNodes             → raw Pipewire.nodes
```

`outputList`, `inputList`, `streamList`, and `deviceList` are the `.values` arrays; `outputs`, `inputs`, `streams`, and `devices` are the `ScriptModel` objects themselves (useful as QML view models).

---

## 6.4 Why only audio nodes are tracked

Volume, mute, channels, and properties are invalid until a node is tracked:

```qml
PwObjectTracker {
    objects: audioNodeModel.values
}
```

Binding the tracker to the filtered audio model (not raw `Pipewire.nodes`) avoids tracking non-audio PipeWire objects.

Consumers must not create their own duplicate trackers for the same nodes.

---

## 6.5 Default devices

```text
defaultOutput = Pipewire.defaultAudioSink
defaultInput  = Pipewire.defaultAudioSource
```

These are aliases, not copies. When PipeWire changes the default, every derived property reevaluates:

```text
Pipewire.defaultAudioSink changes
        │
        ▼
defaultOutput changes
        │
        ▼
volume / isMuted / outputName / outputIcon change
        │
        ▼
outputChanged(node) emitted
```

`hasOutput` / `hasInput` are `!!defaultOutput` / `!!defaultInput` guards so UI code can handle the no-device case.

---

## 6.6 Preferred devices vs. default devices

These are different concepts:

```text
defaultOutput / defaultInput
    PipeWire's live default
    (what audio actually uses now)

preferredOutput / preferredInput
    N0ctOS's remembered preference
    (first available priority entry, else first node)
```

`_preferred()` performs:

```text
for each wanted in priority:
    for each node in nodes:
        String(node.name) === wanted → return node
        String(node.id) === wanted   → return node

no match → nodes[0]
no nodes → null
```

A settings UI can show `preferredOutput` as the remembered choice while the panel shows `defaultOutput` as the live choice.

---

## 6.7 Resolution order for node references

For a value such as:

```text
"Headphones" / "48" / <node object>
```

`resolveNode()` checks:

```text
1. falsy → null

2. object with .audio !== undefined → node itself
   object without .audio → null

3. /^\d+$/ → nodeForId(Number(value))

4. otherwise → nodeForName(String(value))
```

`nodeForId()` linearly scans `deviceList` for `Number(node.id) === Number(id)` and returns `null` for non-finite input.

`nodeForName()` matches:

```text
String(node.name) === value
    OR
displayName(node) === value
```

This is why UI-visible names can be passed back into setters.

---

## 6.8 `setOutput()` / `setInput()` semantics

Both are validated actions, not raw assignments.

`setOutput()`:

```text
resolveNode(value)
    │
    ├── null → false
    ├── !isSink → false
    ├── isStream → false
    │
    ▼
Pipewire.preferredDefaultAudioSink = node
wpctl set-default <id> (detached)
_promotePriority("audio.outputPriority", node)
    │
    ▼
true
```

`setInput()` mirrors it with `preferredDefaultAudioSource`, `audio.inputPriority`, and the inverted sink check.

Stream nodes are rejected by both. This prevents accidentally routing the default sink to an application stream.

---

## 6.9 Why defaults use both PipeWire preference and `wpctl`

Setting `Pipewire.preferredDefaultAudioSink` records the native preference, but WirePlumber may not switch the current default immediately.

Therefore the service also runs:

```text
wpctl set-default <node.id>
```

via:

```qml
Quickshell.execDetached({
    command: [
        "wpctl",
        "set-default",
        String(node.id)
    ]
})
```

Conceptually:

```text
preferredDefault (native, persistent intent)
        +
wpctl set-default (immediate action)
        ↓
audible switch now + correct preference later
```

This is an action, not a polling mechanism. No output is captured.

---

## 6.10 Priority promotion

Every successful `setOutput()` / `setInput()` promotes the chosen device:

```text
current = outputPriority / inputPriority
identity = String(node.name)

updated = [identity] + current.filter(x => x !== identity)
    │
    ▼
Config.set(path, updated)
```

The selected device moves to the front; existing order is otherwise preserved; duplicates are removed.

Direct list replacement is also supported:

```qml
Audio.setOutputPriority([...])
Audio.setInputPriority([...])
```

which normalizes first (see `6.20`).

---

## 6.11 Volume read path

```text
node
 │
 ▼
_nodeAudio(node)
    ├── null node → null
    ├── node.audio === null → null
    └── else → node.audio
 │
 ▼
_nodeVolume(node)
    ├── no audio → 0
    └── Number(audio.volume) * 100, floored at 0
```

Derived output bindings:

```text
volume (real, e.g. 42.3)
    ├── percent (= volume)
    ├── percentRounded (Math.round)
    └── percentText ("42%")
```

Input bindings mirror this with `inputVolume` / `inputPercent` / `inputPercentText`.

When no default exists, volume is `0` rather than `undefined`, so sliders and text never bind to a missing value.

---

## 6.12 Volume write path

`setVolume(node, percent)`:

```text
resolveNode(node)
    │
    ├── null → false
    │
    ▼
_nodeAudio(target)
    │
    ├── null → false
    │
    ▼
value = Number(percent)
    ├── not finite → false
    └── clamp 0 … 200
    │
    ▼
audio.volume = value / 100
    │
    ▼
true
```

The write targets `node.audio.volume` directly. PipeWire propagates the change; the service does not need to refresh or poll.

---

## 6.13 `increase()` / `decrease()` semantics

```text
increase(node, amount)
    ├── resolve fails → false
    ├── amount invalid or <= 0 → step
    └── setVolume(target, _nodeVolume(target) + delta)

decrease(node, amount)
    ├── resolve fails → false
    ├── amount invalid or <= 0 → step
    └── setVolume(target, _nodeVolume(target) - delta)
```

`setOutputVolume()` / `setInputVolume()` are thin wrappers that pass the current default:

```qml
setOutputVolume(p) = setVolume(defaultOutput, p)
setInputVolume(p)  = setVolume(defaultInput, p)
```

IPC `increase` / `decrease` always operate on `defaultOutput`; there is no IPC equivalent for adjusting an arbitrary node by delta (use `setNodeVolume` with an explicit value).

---

## 6.14 Mute read/write path

```text
_nodeMuted(node)
    ├── no audio → false
    └── !!audio.muted
```

`setMute(node, muted)`:

```text
resolve → audio → audio.muted = !!muted → true
```

`toggleMute(node)`:

```text
setMute(target, !_nodeMuted(target))
```

`toggleOutputMute()` / `toggleInputMute()` pass the current defaults.

Any failure to resolve or to find `audio` returns `false`.

---

## 6.15 Profile / route architecture

Quickshell exposes the live node model, but profile/route mutation is handled through `wpctl`:

```text
setProfile(node, index)
    ├── resolve fails → false
    ├── index not integer → false
    └── execDetached(["wpctl", "set-profile", id, index]) → true

setRoute(node, index)
    ├── resolve fails → false
    ├── index not integer → false
    └── execDetached(["wpctl", "set-route", id, index]) → true
```

Conceptually:

```text
Audio.qml
    │
    ▼
wpctl (WirePlumber CLI)
    │
    ▼
card profile / route changes
    │
    ▼
PipeWire graph updates
    │
    ▼
Audio models reevaluate
```

The service never parses `wpctl` output. Confirmation arrives implicitly when PipeWire emits the updated graph.

---

## 6.16 Display-name fallback chain

`displayName(node)`:

```text
node === null → ""

node.nickname (non-empty) → nickname

node.description (non-empty) → description

properties["application.name"] (non-empty) → app name
    (covers streams like "Firefox")

properties["media.name"] (non-empty) → media name

else → String(node.name || "")
```

This single helper is why device lists, stream lists, and `nodeForName()` share the same human-readable naming.

---

## 6.17 Stream metadata helpers

Streams carry PipeWire properties; hardware nodes often do not.

Each helper guards on `node.properties` and returns `""` when absent:

```text
applicationName(node)     → properties["application.name"]
mediaName(node)           → properties["media.name"]
mediaTitle(node)          → properties["media.title"]
mediaArtist(node)         → properties["media.artist"]
applicationIconName(node) → properties["application.icon-name"]
```

A mixer row can therefore combine them safely:

```qml
Audio.applicationName(node) // "Firefox"
Audio.mediaTitle(node)      // "Some Video Title"
```

without checking for `properties` first.

---

## 6.18 Icon and classification model

`icon(node)`:

```text
null → placeholder

isStream:
    muted → muted speaker
    else  → speaker

isSink (output hardware):
    muted → muted speaker
    else  → speaker

source (input hardware):
    muted → muted mic
    else  → mic
```

Classification:

```text
isOutput(node) = audio && !isStream && isSink
isInput(node)  = audio && !isStream && !isSink
isStream(node) = audio && isStream
```

Default checks are identity comparisons:

```text
isDefaultOutput(node) = !!node && node === defaultOutput
isDefaultInput(node)  = !!node && node === defaultInput
```

Delegates should use these predicates rather than reimplementing `isSink` / `isStream` logic.

---

## 6.19 `nodeInfo()` serialization

`nodeInfo(null)` returns `{}`.

Otherwise it returns a detached plain object:

```text
identity:    id, name, displayName, description, nickname, type
topology:    isStream, isSink, isOutput, isInput
defaults:    isDefaultOutput, isDefaultInput
state:       isMuted, percent
stream meta: applicationName, mediaName, mediaTitle,
             mediaArtist, applicationIconName
ui:          icon
```

It intentionally omits the live `audio` object and raw `properties` map so the result is JSON-safe for IPC (`outputs` / `inputs` / `streams`) and for `JSON.stringify()` debugging.

To change state, use `setVolume()` / `setMute()`, not mutation of the `nodeInfo()` result.

---

## 6.20 Normalization

`normalizeStep(value)`:

```text
Number(value)
    ├── not finite → 5
    └── clamp 1 … 100
```

`normalizePriority(value)`:

```text
not an array → []

for each entry:
    null / undefined → skip
    "" → skip
    duplicate → skip
    else → String(entry)
```

Both `setOutputPriority()` / `setInputPriority()` normalize before `Config.set()`, and the `outputPriority` / `inputPriority` properties expose the normalized form. IPC priority setters additionally `JSON.parse()` the argument and return `false` on parse failure.

---

## 6.21 Signals and model-change flow

```text
Pipewire.nodes.onObjectInsertedPost(node)
    ├── null → ignore
    ├── isStream → streamChanged(node)
    └── hardware → no signal (bindings update implicitly)

Pipewire.onDefaultAudioSinkChanged
    → outputChanged(defaultAudioSink)

Pipewire.onDefaultAudioSourceChanged
    → inputChanged(defaultAudioSource)

Pipewire.nodes.onObjectRemovedPost
    → no-op (PipeWire owns lifetimes)
```

Reactive bindings (volume text, device lists) do not need these signals — they update through the model properties. The signals exist for imperative consumers such as OSDs, notifications, or logging.

---

## 6.22 Config integration

`Audio.qml` uses the existing `Config` service.

It should not create its own:

```qml
FileView
```

and should not directly write:

```text
~/.config/N0ctOS/config.json
```

Instead it operates through:

```qml
Config.get(...)
Config.set(...)
```

The normal target is:

```text
homeConfig
```

which is N0ctOS's primary configuration document. `Config` already handles document state, watching, saving, atomic writes, and write queuing.

`Config.onExternalReload` is observed but requires no explicit reload action because `step` and priorities are binding-driven.

---

## 6.23 Reactive state

The service consumes two reactive sources:

```text
PipeWire changes
        │
        ▼
Pipewire.nodes / defaults change
        │
        ▼
ScriptModels + derived props reevaluate
        │
        ▼
component bindings reevaluate
```

```text
config file changes
        │
        ▼
Config document changes
        │
        ▼
step / priorities reevaluate
        │
        ▼
preferredOutput / preferredInput reevaluate
```

A component does not need to manually reload audio state.

For example:

```qml
readonly property string label: Audio.percentText
```

can react to PipeWire, default-switch, and config changes through the service.

---

## 6.24 Persistence

Only preferences persist; live audio does not:

```text
setOutputPriority() / setInputPriority() / _promotePriority()
        │
        ▼
Config.set()
        │
        ▼
configuration document changes
        │
        ▼
Config save queue
        │
        ▼
homeConfig written
```

Volume, mute, defaults, streams, profiles, and routes are never written to `homeConfig`. They are requested live from PipeWire on each startup.

---

## 6.25 IPC architecture

IPC is a thin external interface over the same service API.

Conceptually:

```text
terminal
   │
   ▼
n0ctos-audio
   │
   ▼
Audio.qml
   │
   ├── Pipewire (live control)
   └── Config (priority persistence)
```

For example:

```bash
qs ipc call n0ctos-audio setOutputVolume 42
```

becomes conceptually:

```qml
Audio.setOutputVolume(42)
```

and:

```bash
qs ipc call n0ctos-audio setNodeVolume 87 50
```

becomes conceptually:

```qml
Audio.setVolume(
    Audio.nodeForId(87),
    50
)
```

The IPC layer serializes node data with `nodeInfo()` + `JSON.stringify()` for terminal use.

---

## 6.26 Why IPC stays high-level

IPC should expose useful audio operations, not the internal implementation.

External callers do not need to know about:

```text
ScriptModel filtering
PwObjectTracker binding
_nodeAudio / _nodeVolume helpers
_promotePriority internals
Pipewire preferred-default properties
Config document internals
```

They only need:

```text
get / ready
outputs / inputs / streams
setOutput / setInput
setOutputVolume / setInputVolume
increase / decrease
mute / toggleMute / muteInput / toggleInputMute
setNodeVolume / setNodeMute
setProfile / setRoute
getOutputPriority / setOutputPriority
getInputPriority / setInputPriority
```

This keeps the IPC interface stable even if the internal implementation changes.

---

## 6.27 Performance model

Audio is intended to be cheap during normal UI operation.

A component read such as:

```qml
Audio.percentText
```

does not perform filesystem I/O or spawn processes.

Normal runtime work is therefore:

```text
QML binding
    ↓
Audio
    ↓
in-memory PipeWire object lookup
```

rather than:

```text
QML binding
    ↓
process spawn
    ↓
wpctl/pactl parsing
    ↓
lookup
```

Processes are only spawned for explicit actions (`set-default`, `set-profile`, `set-route`), never for reads.

---

## 6.28 No polling

Audio does not use a polling timer to detect changes.

There is no:

```qml
Timer {
    interval: 1000
    repeat: true

    onTriggered:
        reloadAudio()
}
```

Changes propagate through PipeWire's reactive node/default signals and Config's watch infrastructure.

This avoids unnecessary CPU activity and volume flicker.

---

## 6.29 Service boundaries

The responsibilities are intentionally divided:

```text
Audio
    node classification
    default-device aliases
    volume / mute control
    default switching + priority memory
    profile / route actions
    display names, icons, predicates
    node serialization

Pipewire (Quickshell)
    node graph
    native defaults
    audio.volume / audio.muted storage

Config
    configuration documents
    file watching
    persistence
    atomic writes
    save queue
    external reloads

wpctl (external)
    immediate default switch
    card profile switch
    card route switch
```

Audio should not duplicate PipeWire's graph management or Config's file-management responsibilities.

---

## 6.30 Data ownership

Audio owns no persisted audio state except:

```text
audio.step
audio.outputPriority
audio.inputPriority
```

Everything else is derived live:

```text
volumes ← Pipewire nodes
mutes ← Pipewire nodes
defaults ← Pipewire defaults
streams ← Pipewire nodes
profiles/routes ← WirePlumber via wpctl
```

Inside `nodeInfo()`, the serialized fields are a snapshot for reading. The live node remains owned by PipeWire.

---

## 6.31 Recommended component patterns

A volume indicator keeps lookup separate from visual logic:

```qml
Item {
    readonly property real level: Audio.volume
    readonly property bool muted: Audio.isMuted
    readonly property string label: Audio.percentText
    readonly property string device: Audio.outputName
    readonly property string glyph: Audio.outputIcon
}
```

A device list uses the classified lists plus predicates:

```qml
Repeater {
    model: Audio.outputList

    delegate: Row {
        required property var modelData

        Text {
            text: Audio.displayName(modelData)
        }

        Text {
            visible: Audio.isDefaultOutput(modelData)
            text: "(default)"
        }
    }
}
```

A mixer uses per-stream metadata plus direct node writes:

```qml
Repeater {
    model: Audio.streamList

    delegate: Row {
        required property var modelData

        Text {
            text: Audio.applicationName(modelData)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Audio.toggleMute(modelData)
        }
    }
}
```

---

## 6.32 Complete volume lifecycle

```text
User presses volume key
        │
        ▼
Audio.increase(defaultOutput)
        │
        ▼
resolveNode → _nodeVolume → setVolume
        │
        ▼
node.audio.volume = value / 100
        │
        ▼
PipeWire updates node
        │
        ▼
volume / percentText reevaluate
        │
        ▼
component bindings reevaluate
```

No config write occurs. No process spawns.

---

## 6.33 Complete default-switch lifecycle

When:

```qml
Audio.setOutput("Headphones")
```

is called:

```text
resolveNode("Headphones")
        │
        ▼
validate isSink && !isStream
        │
        ├── invalid → false
        │
        ▼
Pipewire.preferredDefaultAudioSink = node
        │
        ▼
wpctl set-default <id> (detached)
        │
        ▼
_promotePriority → Config.set(audio.outputPriority)
        │
        ▼
Config document changes → save queue → homeConfig
        │
        ▼
PipeWire emits new defaultAudioSink
        │
        ▼
defaultOutput + derived props change
        │
        ▼
outputChanged(node)
        │
        ▼
component bindings reevaluate
```

---

## 6.34 Complete stream lifecycle

```text
Application starts playing audio
        │
        ▼
PipeWire adds stream node
        │
        ▼
audioNodeModel gains value
        │
        ▼
streamModel gains value
        │
        ├── streamList changes
        ├── streamChanged(node) emitted
        └── PwObjectTracker tracks node
                │
                ▼
        volume/mute/name bindings available
```

When the application stops:

```text
PipeWire removes node
        │
        ▼
models shrink
        │
        ▼
(service retains nothing)
```

---

## 6.35 Example final configuration

A realistic configuration is small because live state is not stored:

```json
{
    "audio": {
        "step": 5,

        "outputPriority": [
            "alsa_output.usb-Focusrite_Scarlett-00.analog-stereo",
            "alsa_output.pci-0000_00_1f.3.analog-stereo"
        ],

        "inputPriority": [
            "alsa_input.usb-Blue_Microphones_Yeti-00.analog-stereo"
        ]
    }
}
```

The resulting runtime state might be:

```text
isReady: true

defaultOutput:
    name = alsa_output.usb-Focusrite_Scarlett-00.analog-stereo
    volume = 42%
    muted = false

preferredOutput:
    first available outputPriority entry

defaultInput:
    name = alsa_input.usb-Blue_Microphones_Yeti-00.analog-stereo
    volume = 70%
    muted = false

streams:
    Firefox (50%, unmuted)
    mpv (100%, unmuted)
```

---

## 6.36 What UI / service code should not do

Components should not:

```text
query Pipewire.nodes directly for device lists

create PwObjectTracker objects for audio nodes

parse wpctl/pactl output

implement device-priority persistence

poll volume with a Timer

store volume/mute in config.json

mutate nodeInfo() results expecting live changes

assume node ids are stable across reboots

pass stream nodes to setOutput()/setInput()
```

Instead:

```qml
Audio.outputList
Audio.inputList
Audio.streamList
Audio.percentText
Audio.setOutputVolume(...)
Audio.toggleOutputMute(...)
Audio.setOutput(...) / Audio.setInput(...)
Audio.displayName(...) / Audio.icon(...)
Audio.nodeInfo(...)
```

should be the normal interface.

---

## 6.37 Final architecture summary

The entire system can be viewed as:

```text
                         Component
                            │
                            │ volume / mute / devices
                            ▼
                    ┌─────────────────┐
                    │      Audio      │
                    │                 │
                    │ models          │
                    │ defaults        │
                    │ volume / mute   │
                    │ priorities      │
                    │ profiles/routes │
                    │ display helpers │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              │ PipeWire API │ Config API   │ wpctl actions
              ▼              ▼              ▼
    ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
    │    Pipewire     │ │     Config      │ │      wpctl      │
    │                 │ │                 │ │                 │
    │ live nodes      │ │ reactive data   │ │ set-default     │
    │ native defaults │ │ file watching   │ │ set-profile     │
    │ volume storage  │ │ persistence     │ │ set-route       │
    │ mute storage    │ │ write queue     │ │ (detached)      │
    └────────┬────────┘ └────────┬────────┘ └────────┬────────┘
             │                   │                   │
             ▼                   ▼                   ▼
        live graph          homeConfig         WirePlumber
```

The core rule is:

> **Components describe what audio state they need; `Audio.qml` classifies the live PipeWire graph, resolves names to nodes, and controls volume/mute/defaults; `Config` persists only step and device priorities while `wpctl` executes immediate default, profile, and route actions.**
