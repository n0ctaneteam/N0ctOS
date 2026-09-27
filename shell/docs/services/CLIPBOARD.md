# Clipboard Service

`Clipboard.qml` is N0ctOS's centralized Wayland clipboard history service.

It gives every shell component one consistent place to read clipboard history, restore entries, and configure retention without touching the filesystem or `wl-clipboard` directly.

The service supports automatic capture via `wl-paste --watch`, file-backed history, per-entry MIME kinds, bounded retention, reactive history-size configuration, and restore via `wl-copy`.

The normal usage pattern is:

```text
Wayland clipboard
    │
    ▼
Clipboard watcher (wl-paste --watch)
    │
    ▼
Clipboard
    │
    ├── items (newest first)
    ├── current (items[0])
    └── historySize
    │
    ├── items/ + history.json
    └── Config (historySize only)
```

---

# 1. What does it do?

`Clipboard.qml` captures every Wayland clipboard change and keeps a bounded, persistent history.

A history entry looks like this:

```json
{
    "id": "1759000000000-3",
    "path": "/home/user/.local/share/N0ctOS/clipboard/items/entry-AbCdEfGh",
    "mime": "text/plain;charset=utf-8",
    "kind": "text",
    "size": 42,
    "timestamp": 1759000000000
}
```

The entry bytes live in a separate file under `items/`. `history.json` stores only this metadata array, newest first:

```json
[
    {
        "id": "1759000000000-3",
        "path": ".../items/entry-AbCdEfGh",
        "mime": "text/plain;charset=utf-8",
        "kind": "text",
        "size": 42,
        "timestamp": 1759000000000
    },
    {
        "id": "1759000000000-2",
        "path": ".../items/entry-XyZ12345",
        "mime": "image/png",
        "kind": "image",
        "size": 18344,
        "timestamp": 1758999990000
    }
]
```

Retention is configured through `Config`:

```json
{
    "clipboard": {
        "historySize": 50
    }
}
```

The effective history order is always:

```text
index 0 = newest (current)
    ↓
index 1 = previous
    ↓
index N = oldest (trimmed beyond historySize)
```

So a component can simply do:

```qml
Clipboard.current
```

or restore an older entry with:

```qml
Clipboard.copy(2)
```

and not care where the bytes are stored, what MIME type they use, or how retention works.

If `wl-clipboard` is missing, the service reports `available === false` and **never starts the watcher**.

---

# 2. UI API

Import normally:

```qml
import QtQuick
import Quickshell

import qs.services
```

## Core API

| How to call                            | What does it do                                                                                     |
| -------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `Clipboard.items`                      | History array, newest first. Read-only view of `_history`.                                          |
| `Clipboard.count`                      | Number of history entries.                                                                          |
| `Clipboard.current`                    | Newest entry (`items[0]`), or `null` when empty.                                                    |
| `Clipboard.available`                  | `true` when `wl-paste` and `wl-copy` were found.                                                    |
| `Clipboard.watching`                   | `true` when the `wl-paste --watch` process is running.                                              |
| `Clipboard.historySize`                | Normalized retention limit (1..500, default 50) from `Config`.                                      |
| `Clipboard.copy(index)`                | Restores `items[index]` to the live clipboard via `wl-copy`. Returns `bool`.                        |
| `Clipboard.copyFile(path, mime)`       | Restores an arbitrary stored file with an explicit MIME type. Returns `bool`.                       |
| `Clipboard.copyText(value)`            | Copies a string as `text/plain`. Returns `bool`.                                                    |
| `Clipboard.remove(index)`              | Deletes one entry, removes its file, emits `itemRemoved`. Returns `bool`.                           |
| `Clipboard.clear()`                    | Deletes all entries and their files, emits `historyCleared`. Returns `bool`.                        |
| `Clipboard.trimHistory()`              | Drops entries beyond `historySize`, deleting their files. No-op before history is loaded.           |
| `Clipboard.scheduleHistorySave()`      | Marks history dirty and debounces a `history.json` write (50 ms). No-op before history is loaded.   |
| `Clipboard.normalizeHistorySize(value)`| Normalizes any value to `1..500` (`NaN` → `50`, floored, clamped).                                  |
| `Clipboard.setHistorySize(value)`      | Normalizes `value` and writes it via `Config.set("clipboard.historySize", …)`. Returns `bool`.      |

|Example                                              |Result                                                   |
|-----------------------------------------------------|---------------------------------------------------------|
|`Clipboard.copy(0)`                                  |`true`, `items[0]` restored to the live clipboard        |
|`Clipboard.copyFile("/path/to/entry", "image/png")`  |`true`, file restored with MIME `image/png`              |
|`Clipboard.copyText("hello")`                        |`true`, `"hello"` on the live clipboard as `text/plain`  |
|`Clipboard.remove(2)`                                |`true`, entry and its `items/entry-*` file deleted       |
|`Clipboard.setHistorySize(100)`                      |`true`, `historySize` becomes `100`                      |

Signals:

| Signal                              | When it fires                                                              |
| ----------------------------------- | -------------------------------------------------------------------------- |
| `itemAdded(item)`                   | A new clipboard capture was prepended to `items`.                          |
| `itemRemoved(item)`                 | One entry was removed by `remove()` or `trimHistory()`.                    |
| `historyCleared()`                  | All entries were removed by `clear()`.                                     |
| `availabilityChangedExternally()`   | Declared on the singleton; never emitted by the current implementation.    |

Storage paths (read-only):

| Property              | Value                                                          |
| --------------------- | -------------------------------------------------------------- |
| `Clipboard.homeDir`   | `$HOME`.                                                       |
| `Clipboard.dataBase`  | `$XDG_DATA_HOME`, or `$HOME/.local/share` as fallback.         |
| `Clipboard.dataDir`   | `<dataBase>/N0ctOS/clipboard`.                                 |
| `Clipboard.itemsDir`  | `<dataDir>/items`.                                             |
| `Clipboard.historyPath` | `<dataDir>/history.json`.                                    |

## History model

History is an index-addressed array, newest first.

| Concept       | Meaning                                                                                          |
| ------------- | ------------------------------------------------------------------------------------------------ |
| `index 0`     | Newest entry. Same object as `Clipboard.current`.                                                |
| `index N`     | Older entries in capture order.                                                                  |
| `out of range`| `copy()` / `remove()` return `false` and do nothing.                                             |
| `empty`       | `count === 0`, `items` is `[]`, `current` is `null`.                                              |

For example:

```qml
Clipboard.copy(0)
```

restores:

```text
items[0] → wl-copy → live Wayland clipboard
```

while:

```qml
Clipboard.remove(0)
```

deletes:

```text
items[0] + its items/entry-* file
```

## Entry kinds

The watcher classifies every capture into one `kind`:

| Kind     | Meaning                                                        | Typical MIME                          |
| -------- | -------------------------------------------------------------- | ------------------------------------- |
| `text`   | Plain or generic text.                                         | `text/plain`, `text/*`                |
| `image`  | Any `image/*` type offered by the clipboard.                   | `image/png`                           |
| `files`  | File list copied from a file manager.                          | `text/uri-list`                       |
| `binary` | Fallback when no known type matched.                           | First offered type, or `application/octet-stream` |

MIME selection priority inside the watch script is:

```text
text/uri-list
    ↓
x-special/gnome-copied-files
    ↓
first ^image/
    ↓
first ^text/plain
    ↓
first ^text/
    ↓
first offered type
    ↓
application/octet-stream
```

A file-manager copy therefore becomes `kind: "files"` even when the clipboard also offers text.

### Typical component usage

```qml
readonly property var latest:
    Clipboard.current

readonly property int entryCount:
    Clipboard.count

readonly property bool canPaste:
    Clipboard.available &&
    Clipboard.count > 0
```

That is the intended everyday usage.

Components normally should not need to know how the watcher, `items/` files, or `history.json` persistence work.

---

# 3. IPC API

IPC target:

```text
n0ctos-clipboard
```

## Core reads

| How to call | What does it do                                      |
| ----------- | ---------------------------------------------------- |
| `count`     | Returns the number of history entries.               |
| `list`      | Returns all entries as a JSON string.                |
| `current`   | Returns the newest entry as a JSON string, or `""`.  |

| Example                                     | Result                                              |
| ------------------------------------------- | --------------------------------------------------- |
| `qs ipc call n0ctos-clipboard count`        | entry count, e.g. `3`                               |
| `qs ipc call n0ctos-clipboard list`         | JSON array of history entries (see below)           |
| `qs ipc call n0ctos-clipboard current`      | JSON object of the newest entry, or `""` when empty |

`list` returns a JSON array:

```bash
qs ipc call n0ctos-clipboard list
```

`current` returns one JSON object, or an empty string when history is empty:

```bash
qs ipc call n0ctos-clipboard current
```

## Other operations

| How to call            | What does it do                                                              |
| ---------------------- | ---------------------------------------------------------------------------- |
| `copy <index>`         | Restores `items[index]` to the live clipboard. Returns `bool`.               |
| `remove <index>`       | Deletes one entry and its file. Returns `bool`.                              |
| `clear`                | Deletes all entries and their files. Returns `bool`.                         |
| `copyText <value>`     | Copies a string as `text/plain`. Returns `bool`.                             |
| `watching`             | Returns whether the `wl-paste --watch` process is running.                   |
| `historySize`          | Returns the normalized retention limit.                                      |
| `setHistorySize <n>`   | Normalizes `n` to `1..500` and stores it via `Config`. Returns `bool`.       |

| Example                                              | Result                                              |
| ---------------------------------------------------- | --------------------------------------------------- |
| `qs ipc call n0ctos-clipboard copy 0`                | `true`, `items[0]` restored                         |
| `qs ipc call n0ctos-clipboard remove 2`              | `true`, entry 2 deleted                             |
| `qs ipc call n0ctos-clipboard clear`                 | `true`, all entries deleted                         |
| `qs ipc call n0ctos-clipboard copyText hello`        | `true`, `"hello"` copied as `text/plain`            |
| `qs ipc call n0ctos-clipboard watching`              | `true` while the `wl-paste --watch` process runs    |
| `qs ipc call n0ctos-clipboard historySize`           | retention limit, e.g. `50`                          |
| `qs ipc call n0ctos-clipboard setHistorySize 100`    | `true`, retention limit becomes `100`               |

Index arguments are integers:

```bash
qs ipc call n0ctos-clipboard copy 0
```

```bash
qs ipc call n0ctos-clipboard remove 2
```

Text:

```bash
qs ipc call n0ctos-clipboard copyText \
    "hello from the terminal"
```

Retention:

```bash
qs ipc call n0ctos-clipboard setHistorySize 100
```

Values outside `1..500` are clamped, not rejected. `NaN` becomes `50`.

---

# 4. Features / limitations

## Features

### Automatic Wayland capture

The service spawns one long-lived process:

```text
wl-paste --watch sh -c <watchScript>
```

Every clipboard change produces one watch record:

```text
path <TAB> mime <TAB> kind <TAB> size
```

The service parses that line, validates it, and prepends a history entry. No polling is involved.

### File-backed entry bytes

Clipboard bytes are never embedded in `history.json`.

Instead:

```text
items/entry-XXXXXXXX  ← raw bytes
history.json          ← metadata array
```

This keeps the JSON small and allows images and file lists to share the same history mechanism.

### MIME-aware kinds

Each entry records both the selected MIME type and a coarse `kind`:

```json
{
    "mime": "image/png",
    "kind": "image"
}
```

UI code can switch on `kind` without parsing MIME strings:

```qml
visible: modelData.kind === "image"
```

### Bounded history

`historySize` bounds the array:

```text
entries beyond historySize
        ↓
popped + file deleted + itemRemoved emitted
```

Trimming runs after every capture, after every `Config` revision change, and after every `historySize` change.

### Persistent history

History survives shell restarts:

```text
capture → _history → history.json → reload on next launch
```

Writes are debounced (50 ms), atomic, and guarded against overlapping saves and self-triggered reloads.

### Reactive retention

`historySize` is read from `Config`:

```qml
Config.get(
    "clipboard.historySize",
    50
)
```

Changing it anywhere (UI, IPC, external config edit) re-trims history and re-saves.

### Watcher self-healing

If the watcher exits while dependencies and storage are healthy, it restarts after 1500 ms.

```text
watcher exits
    ↓
warn + 1500 ms timer
    ↓
start again when ready
```

### Restore without exposing internals

Consumers never invoke `wl-copy` themselves:

```qml
Clipboard.copy(0)
Clipboard.copyText("hello")
```

The service builds the correct `wl-copy --type <mime>` command internally.

---

## Limitations

### `wl-clipboard` is required

Both binaries must exist:

```text
wl-paste
wl-copy
```

If either is missing, the service logs an install hint, sets `available` to `false`, and never starts the watcher:

```bash
sudo pacman -S wl-clipboard
```

History from a previous session is still loaded, but no new captures occur.

### History stores paths, not inline text

`list` and `items` return metadata with a `path` field.

To read the actual text, the consumer must read that file:

```text
items[i].path → file bytes
```

There is no `getText(index)` helper in the current implementation.

### Index-based access shifts

Entries are addressed by position:

```qml
Clipboard.copy(0)
Clipboard.remove(2)
```

A new capture prepends at index `0` and shifts every existing index by one. Holding an index across captures is therefore unsafe; hold the entry `id` instead.

### Restoring re-captures

`copy()` and `copyText()` place data on the live Wayland clipboard, which the watcher observes like any other change.

Expect:

```text
copy(2)
    ↓
same bytes re-captured as new items[0]
```

This is inherent to a `wl-paste --watch` design, not a bug.

### No deduplication

Consecutive copies of identical content create separate entries with distinct `id` values.

The service never compares bytes or skips a capture.

### No per-kind or per-size filtering

Every accepted watch record enters history, whether it is:

```text
12 bytes of text
a 40 MB image
a file list
```

Only `historySize` bounds growth. There is no maximum-bytes or kind-exclusion setting.

### `availabilityChangedExternally` is currently unused

The signal is declared:

```qml
signal availabilityChangedExternally()
```

but nothing in the current implementation emits it. Availability changes are observable through the `available` property instead.

---

# 5. Example use cases

## 5.1 Showing history in a list

Bind directly to the reactive history array:

```qml
import QtQuick
import Quickshell

import qs.services

ListView {
    model: Clipboard.items

    delegate: Text {
        required property var modelData
        required property int index

        text: "#" + index + " " + modelData.kind + " (" + modelData.size + " B)"
    }
}
```

New captures, removals, and clears update the view automatically because `items` is a reactive alias of the internal history.

An empty state can use:

```qml
visible: Clipboard.count === 0
```

---

## 5.2 Restoring an entry on click

The newest entry is index `0`:

```qml
MouseArea {
    anchors.fill: parent

    onClicked: Clipboard.copy(0)
}
```

An older entry uses its delegate index:

```qml
delegate: MouseArea {
    required property int index

    anchors.fill: parent

    onClicked: Clipboard.copy(index)
}
```

Out-of-range indices safely return `false`.

---

## 5.3 Copying new text from the UI

A text field can push text without touching `wl-copy`:

```qml
Row {
    spacing: 8

    TextInput {
        id: input
        width: 200
    }

    Rectangle {
        width: 80
        height: 32

        MouseArea {
            anchors.fill: parent

            onClicked: Clipboard.copyText(input.text)
        }
    }
}
```

The new text appears on the live clipboard and is then re-captured as the newest history entry.

---

## 5.4 Removing one entry or clearing all

Remove a single row:

```qml
Clipboard.remove(2)
```

Clear everything:

```qml
Clipboard.clear()
```

The backing `items/entry-*` files are deleted with `rm -f` in the background, and the UI updates through:

```text
remove → itemRemoved
clear  → historyCleared
```

---

## 5.5 Configuring retention from the UI

Read the normalized limit:

```qml
Text {
    text: "Keep " + Clipboard.historySize + " entries"
}
```

Write a new limit:

```qml
Clipboard.setHistorySize(100)
```

The value is clamped to `1..500`, persisted through `Config`, and immediately trims history if it shrank.

---

## 5.6 Reacting to captures and removals

Connect to the history signals:

```qml
Connections {
    target: Clipboard

    function onItemAdded(item) {
        console.log("captured", item.kind, item.size)
    }

    function onItemRemoved(item) {
        console.log("removed", item.id)
    }

    function onHistoryCleared() {
        console.log("history cleared")
    }
}
```

This is the right place for toasts, badges, or refreshing a popover.

---

## 5.7 Terminal workflow

List everything:

```bash
qs ipc call n0ctos-clipboard list
```

Show the newest entry:

```bash
qs ipc call n0ctos-clipboard current
```

Restore the newest entry:

```bash
qs ipc call n0ctos-clipboard copy 0
```

Push text from the terminal:

```bash
qs ipc call n0ctos-clipboard copyText \
    "deploy at 18:00"
```

Delete one entry:

```bash
qs ipc call n0ctos-clipboard remove 2
```

Clear all history:

```bash
qs ipc call n0ctos-clipboard clear
```

Check watcher health and retention:

```bash
qs ipc call n0ctos-clipboard watching
qs ipc call n0ctos-clipboard historySize
qs ipc call n0ctos-clipboard setHistorySize 100
```

---

# 6. Detailed architecture

This section is for developers working on `Clipboard.qml` and the services/components that consume it.

---

## 6.1 Overall architecture

The service sits between Wayland, the filesystem, and `Config`:

```text
Wayland clipboard
        │
        ▼
wl-paste --watch + watchScript
        │
        ▼
  Clipboard.qml
        │
   ┌────┼─────────┐
   │    │         │
   ▼    ▼         ▼
 items/ history  Config
 files  .json    (historySize)
```

There are effectively three responsibilities:

```text
wl-clipboard
    live clipboard capture and restore

Clipboard.qml
    history capture, retention, restore API

Config + history.json
    small-setting persistence + history persistence
```

Clipboard should not duplicate the file-watching and write-queue logic already provided by `Config` and `FileView`.

---

## 6.2 Storage layout

Paths derive from the environment:

```text
$XDG_DATA_HOME (or $HOME/.local/share)
        │
        ▼
N0ctOS/clipboard/
        │
        ├── items/
        │     └── entry-XXXXXXXX (raw bytes)
        │
        └── history.json (metadata array)
```

Concretely:

```qml
readonly property string dataDir: root.dataBase + "/N0ctOS/clipboard"
readonly property string itemsDir: root.dataDir + "/items"
readonly property string historyPath: root.dataDir + "/history.json"
```

The directory is created once at startup with `mkdir -p`.

---

## 6.3 History entry shape

Every entry has the same six fields:

```json
{
    "id": "<Date.now>-<sequence>",
    "path": "<itemsDir>/entry-XXXXXXXX",
    "mime": "text/plain;charset=utf-8",
    "kind": "text",
    "size": 42,
    "timestamp": 1759000000000
}
```

Semantics:

```text
id         unique per capture (millis + monotonic sequence)
path       backing file inside itemsDir
mime       MIME type selected by the watch script
kind       text | image | files | binary
size       byte count, clamped to >= 0
timestamp  Date.now() at capture time
```

`id` ordering is capture order; array position is recency order.

---

## 6.4 Watch pipeline

One capture flows through four stages:

```text
wl-paste --watch fires
        │
        ▼
watchScript stores stdin → temp file
        │
        ▼
watchScript prints: path TAB mime TAB kind TAB size
        │
        ▼
SplitParser splits on \n → _handleWatchRecord(line)
        │
        ▼
validate → prepend → trim → itemAdded → save
```

The watcher process is declared as:

```text
wl-paste --watch sh -c <watchScript> n0ctos-clipboard <itemsDir>
```

`stdout` uses a `SplitParser` with `\n` as the split marker, so each record arrives as one trimmed line.

---

## 6.5 Watch-script MIME selection

The script stores bytes first, then asks what types are offered:

```text
cat stdin → mktemp file
    ↓
wc -c → size
    ↓
wl-paste --list-types → selection
```

Selection priority is:

```text
1. text/uri-list → kind files
2. x-special/gnome-copied-files → kind files
3. first ^image/ → kind image
4. first ^text/plain(;…) → kind text
5. first ^text/ → kind text
6. first offered type → kind binary
7. empty → application/octet-stream → kind binary
```

The script never interprets file contents. It only ranks the offered type list.

---

## 6.6 Record validation

`_handleWatchRecord()` rejects anything unexpected:

```text
empty line → ignore
    ↓
fewer than 4 TAB fields → warn + ignore
    ↓
path outside itemsDir + "/" → warn + ignore
    ↓
otherwise → accept
```

The path-prefix check is a security boundary:

```text
allowed: <itemsDir>/entry-XXXXXXXX
rejected: /tmp/evil, /home/user/other, <itemsDir> itself
```

Only files the watch script just created inside `items/` can enter history.

---

## 6.7 Startup lifecycle

Startup has three parallel prerequisites:

```text
Component.onCompleted
    ├── mkdir -p itemsDir → _storageReady → reload history file
    └── check wl-paste + wl-copy → _available → maybe start watcher
```

History loading then decides:

```text
FileNotFound + storage ready
    → [] → save → watcher may start

parse error / corrupt JSON
    → log → [] → watcher may start (no overwrite)

valid array
    → keep entries with path + mime → trim → watcher may start
```

A corrupt file is deliberately not overwritten automatically, so a bad write cannot silently erase history on the next launch.

The watcher starts only when all of these hold:

```text
_available
_storageReady
_historyLoaded
not already started
```

---

## 6.8 History load filtering

Load keeps the file format forgiving:

```text
empty file → []
non-array root → invalid, reset to []
non-object row → skipped
object without path or mime → skipped
```

Surviving rows are kept verbatim, including any extra fields a future version might add. No migration step rewrites them.

---

## 6.9 Save lifecycle (debounced)

Saves are debounced through a 50 ms single-shot timer:

```text
capture / remove / clear / trim-request / config change
        │
        ▼
scheduleHistorySave() → _historyWritePending = true → restart timer
        │
        ▼ (50 ms quiet)
_writeHistory() → FileView.setText(JSON + "\n")
        │
        ▼
onSaved → _historySaving = false → flush pending if any
onSaveFailed → _historySaving = false → keep pending = true
```

Guards:

```text
not loaded → never schedule or write
already saving → skip; pending flag retries after onSaved
storage not ready → skip write
```

External edits are detected but self-writes are ignored:

```text
onFileChanged while _historySaving → ignore (own write)
otherwise → reload from disk
```

---

## 6.10 Trim semantics

`trimHistory()` enforces `historySize`:

```text
while history.length > limit
    pop oldest
        ↓
    rm -f its file (detached)
        ↓
    emit itemRemoved
```

Notes:

```text
no-op before history is loaded
files are deleted best-effort via execDetached
trim itself does not save; callers schedule the save
```

Trim is invoked from capture handling, `historySize` changes, and `Config.revision` changes.

---

## 6.11 Copy semantics

`copy(index)` is bounds-checked restoration:

```text
index < 0 or >= length → false
entry without path/mime → false
otherwise → copyFile(path, mime)
```

`copyFile(path, mime)` runs detached:

```text
sh -c 'exec wl-copy --type "$1" < "$2"' … <mime> <path>
```

`copyText(value)` runs detached:

```text
printf "%s" <value> | wl-copy --type text/plain
```

All three return `true` once the process is spawned, not once `wl-copy` completes. Failure of the detached process is not propagated back.

---

## 6.12 Remove and clear semantics

`remove(index)`:

```text
bounds check
    ↓
splice one row → assign new array (keeps bindings reactive)
    ↓
rm -f its file
    ↓
emit itemRemoved → schedule save → true
```

`clear()`:

```text
rm -f every entry file
    ↓
_history = []
    ↓
emit historyCleared → schedule save → true
```

Both keep the in-memory array as the source of truth; the file write follows asynchronously.

---

## 6.13 Config integration

Only one setting flows through `Config`:

```json
{
    "clipboard": {
        "historySize": 50
    }
}
```

Read path:

```qml
Config.get("clipboard.historySize", 50)
```

Write path:

```qml
Config.set("clipboard.historySize", normalized)
```

History bytes and `history.json` deliberately bypass `Config` and use a dedicated `FileView`, because they are a growing data store, not a small user setting.

---

## 6.14 Normalization

`normalizeHistorySize()` makes any input safe:

```text
Number(value)
    ↓
not finite → 50
    ↓
floor
    ↓
clamp 1..500
```

So:

```text
100 → 100
0 → 1
9999 → 500
"abc" → 50
12.9 → 12
```

IPC and UI callers share this one function, so both surfaces behave identically.

---

## 6.15 Reactive state

The service consumes the reactive `Config` document:

```text
config file changes
        │
        ▼
Config.revision changes
        │
        ▼
historySize reevaluates → trimHistory() → schedule save
        │
        ▼
component bindings (items / count / current) reevaluate
```

Consumers never reload manually:

```qml
readonly property int entryCount: Clipboard.count
```

reevaluates whenever the underlying `_history` array is reassigned.

---

## 6.16 Watcher supervision

The watcher is supervised, not fire-and-forget:

```text
started → _watchStarted = true + log
    ↓
exited → _watchStarted = false + warn
    ↓
available && storageReady → restart after 1500 ms
```

A restart storm is avoided by the single-shot 1500 ms timer and the `_startWatcherIfReady()` guard, which refuses to start twice.

---

## 6.17 IPC architecture

IPC is a thin external interface over the same service API.

Conceptually:

```text
terminal
   │
   ▼
n0ctos-clipboard
   │
   ▼
Clipboard.qml
   │
   ├── items/ + history.json
   └── Config (historySize)
```

For example:

```bash
qs ipc call n0ctos-clipboard copy 0
```

becomes conceptually:

```qml
Clipboard.copy(0)
```

The IPC layer serializes history as JSON strings because `qs ipc` transports strings most conveniently.

---

## 6.18 Performance model

Normal UI operation is cheap:

```text
QML binding
    ↓
Clipboard
    ↓
in-memory array lookup
```

There is no filesystem read per binding evaluation. Filesystem work happens only on:

```text
watcher capture (one small file + one debounced JSON write)
copy / remove / clear (one detached process per file)
startup load (one JSON parse)
```

`history.json` is pretty-printed with 2-space indent plus a trailing newline, so external inspection stays readable without affecting runtime cost.

---

## 6.19 What UI / service code should not do

Components should not:

```text
invoke wl-paste / wl-copy directly

create FileView objects for clipboard history

read or write items/ or history.json directly

implement clipboard polling timers

cache Clipboard.items and assume indices stay valid

mutate Clipboard.items array elements in place

assume availabilityChangedExternally() will fire
```

Instead:

```qml
Clipboard.items
Clipboard.current
Clipboard.copy(...)
Clipboard.copyText(...)
Clipboard.remove(...)
Clipboard.clear(...)
Clipboard.setHistorySize(...)
```

should be the normal interface.

---

## 6.20 Final architecture summary

The entire system can be viewed as:

```text
                     Wayland clipboard
                             │
                    capture / restore
                             │
                     ┌─────────────────┐
                     │    Clipboard    │
                     │                 │
                     │ items (newest   │
                     │   first)        │
                     │ current         │
                     │ historySize     │
                     │ watcher         │
                     │ trim + save     │
                     └────────┬────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               ▼
       ┌────────────┐  ┌────────────┐  ┌────────────┐
       │   items/   │  │ history    │  │   Config   │
       │            │  │  .json     │  │            │
       │ raw bytes  │  │ metadata   │  │ historySize│
       │ per entry  │  │ array      │  │ only       │
       └────────────┘  └────────────┘  └────────────┘
```

The core rule is:

> **Wayland owns the live clipboard; `Clipboard.qml` owns capture, history, and restore; `history.json` + `items/` own persistence; `Config` owns only `clipboard.historySize`.**
