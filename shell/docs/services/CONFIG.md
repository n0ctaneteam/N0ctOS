# Config Service

`Config.qml` is N0ctOS's centralized configuration interface.

`ConfigStore.qml` is the underlying configuration engine responsible for loading, tracking, modifying, saving, watching, and managing configuration files. It stays covered inside this document; there is no separate file.

It gives every shell component and service one consistent place to read and write JSON configuration without touching files directly, creating `FileView` objects, or implementing persistence logic.

The service supports multiple registered configuration files, reactive documents, per-file state, file watching with debounced reloads, atomic writes with a save queue, a path registry with CRUD, and a high-level IPC interface.

The normal usage pattern is:

```text
Component / Service
    │
    ▼
Config
    │
    ├── reactive documents
    ├── per-file state
    └── path registry
    │
    ▼
ConfigStore
    │
    ▼
JSON configuration files
```

---

# 1. What does it do?

`Config.qml` sits between N0ctOS services/UI and configuration files.

A service can read:

```qml
Config.get(
    "notifications.isDnd",
    false
)
```

or write:

```qml
Config.set(
    "notifications.isDnd",
    true
)
```

A configuration document can contain simple values:

```json
{
    "notifications": {
        "isDnd": true
    }
}
```

or nested sections:

```json
{
    "notifications": {
        "popup": {
            "timeout": {
                "normal": 5
            }
        }
    }
}
```

A secondary file can be selected with a file key:

```json
{
    "wifi": {
        "enabled": true
    }
}
```

read as:

```qml
Config.get(
    "wifi.enabled",
    true,
    "networkConfig"
)
```

The effective file is resolved in this order:

```text
requested fileKey
    ↓
registered?
    ↓
yes -> requested file
no  -> homeConfig
```

So a component can simply do:

```qml
Config.get(
    "audio.volume",
    100
)
```

and not care where the file lives, how it is watched, or how it is written.

If that property does not exist, the fallback is returned.

If an unknown file key is supplied to a normal configuration operation, `homeConfig` is used instead:

```qml
Config.get(
    "some.value",
    false,
    "doesNotExist"
)
```

resolves to:

```text
~/.config/N0ctOS/config.json
```

Path-registry operations are different. They use exact key matching and do not fall back:

```qml
Config.hasPath(
    "doesNotExist"
)
```

returns `false` instead of operating on `homeConfig`.

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
| `Config.data` | Current document of the default file (`homeConfig`). Equivalent to `documentFor("homeConfig")`. Reactive. |
| `Config.documents` | Currently loaded documents indexed by file key. Reactive. |
| `Config.ready` | `true` when the default document has been loaded and initialized. |
| `Config.writing` | `true` when the default file has an active write operation. |
| `Config.dirty` | `true` when the default document has unsaved changes. |
| `Config.revision` | Revision number of the default document. Increases when the in-memory document changes. |
| `Config.configPath` | Resolved physical path of `homeConfig`, e.g. `/home/user/.config/N0ctOS/config.json`. |
| `Config.paths` | Registered file-key table (`key -> resolved physical path`). Reactive. |
| `Config.pathKeys` | List of registered configuration keys. Reactive. |
| `Config.defaultFileKey` | Default file key (`"homeConfig"`). |
| `Config.debugLogging` | Read-only mirror of `ConfigStore.debugLogging`. Set via `ConfigStore.debugLogging`. |

## Reads

| How to call | What does it do |
| ----------- | --------------- |
| `Config.get(path, fallbackValue, fileKey)` | Reads a value at a dotted path. Returns `fallbackValue` when missing. Unknown `fileKey` falls back to `homeConfig`. |
| `Config.has(path, fileKey)` | Checks whether a property exists. Returns `true` when it exists, `false` when it does not. Unknown `fileKey` falls back to `homeConfig`. |
| `Config.section(path, fallbackValue, fileKey)` | Convenience wrapper around `get()` for sections. Defaults `fallbackValue` to `{}` when omitted. Unknown `fileKey` falls back to `homeConfig`. |
| `Config.documentFor(fileKey)` | Returns the complete document for a file key. Unknown `fileKey` falls back to `homeConfig`. Returns `{}` when no document exists. |
| `Config.readyFor(fileKey)` | `true` when the given file is ready. Unknown `fileKey` falls back to `homeConfig`. |
| `Config.writingFor(fileKey)` | `true` when the given file has an active write. Unknown `fileKey` falls back to `homeConfig`. |
| `Config.dirtyFor(fileKey)` | `true` when the given file has unsaved changes. Unknown `fileKey` falls back to `homeConfig`. |
| `Config.revisionFor(fileKey)` | Revision number for the given file, `0` when unknown. Unknown `fileKey` falls back to `homeConfig`. |

| Example | Result |
| ------- | ------ |
| `Config.get("notifications.isDnd", false)` | Stored value, or `false` when missing |
| `Config.get("wifi.enabled", true, "networkConfig")` | Stored value from `networkConfig`, or `true` when missing; `homeConfig` value when key is unknown |
| `Config.has("notifications.isDnd")` | `true` when the property exists, `false` when it does not |
| `Config.has("wifi.enabled", "networkConfig")` | `true` when the property exists in `networkConfig`, `false` when it does not |
| `Config.section("notifications", {})` | Section object, or `{}` when missing |
| `Config.section("wifi", {}, "networkConfig")` | Section object from `networkConfig`, or `{}` when missing |
| `Config.documentFor("networkConfig")` | Full document object for `networkConfig` (`homeConfig` document when key is unknown) |
| `Config.readyFor("networkConfig")` | `true` when ready, `false` otherwise |
| `Config.writingFor("networkConfig")` | `true` while writing, `false` otherwise |
| `Config.dirtyFor("networkConfig")` | `true` when unsaved changes exist, `false` otherwise |
| `Config.revisionFor("networkConfig")` | Revision number, `0` when no state exists |

## Writes

| How to call | What does it do |
| ----------- | --------------- |
| `Config.set(path, value, fileKey)` | Creates or updates one value. Missing intermediate objects are created automatically. Queues a save. Rejects empty paths and `undefined` values. Unknown `fileKey` falls back to `homeConfig`. |
| `Config.update(section, patch, fileKey)` | Deep-merges an object patch into a section, then persists through the normal `set()` path. Requires a non-empty section and an object patch. Unknown `fileKey` falls back to `homeConfig`. |
| `Config.remove(path, fileKey)` | Deletes a nested property. Returns `false` and changes nothing when the path does not exist. Unknown `fileKey` falls back to `homeConfig`. |

| Example | Result |
| ------- | ------ |
| `Config.set("notifications.isDnd", true)` | `true` and document changed plus save queued; `true` with no write when already equal; `false` on empty path or `undefined` value |
| `Config.set("wifi.enabled", false, "networkConfig")` | `true` and `networkConfig` document changed plus save queued (`homeConfig` when key is unknown); `false` when rejected |
| `Config.update("notifications", {"isDnd": true})` | `true` and section deep-merged plus save queued; `false` when section is empty or patch is not an object |
| `Config.update("wifi", {"enabled": true}, "networkConfig")` | `true` and `networkConfig` section deep-merged plus save queued; `false` when rejected |
| `Config.remove("notifications.isDnd")` | `true` and property deleted plus save queued; `false` when the path does not exist |
| `Config.remove("wifi.enabled", "networkConfig")` | `true` and property deleted from `networkConfig` plus save queued; `false` when the path does not exist |

## File control

| How to call | What does it do |
| ----------- | --------------- |
| `Config.save(fileKey)` | Explicitly requests a save of the current document. Defaults to `homeConfig`. Normal `set()`/`update()`/`remove()` already queue saves. |
| `Config.reload(fileKey)` | Explicitly reloads one file from disk. Discards unsaved local state for that file. Defaults to `homeConfig`. Rejected while writing. |
| `Config.reloadAll()` | Reloads every registered file. Skips files currently being written. |

| Example | Result |
| ------- | ------ |
| `Config.save()` | `true` and save queued for `homeConfig`; `false` when no controller exists or the file is neither ready nor dirty |
| `Config.save("networkConfig")` | `true` and save queued for `networkConfig`; `false` when no controller exists or the file is neither ready nor dirty |
| `Config.reload()` | `true` and `homeConfig` reloaded (local dirty state discarded); `false` while writing or when no controller exists |
| `Config.reload("networkConfig")` | `true` and `networkConfig` reloaded (local dirty state discarded); `false` while writing or when no controller exists |
| `Config.reloadAll()` | `true` when every file reloaded; `false` when one or more files were skipped or failed |

## Path registry

| How to call | What does it do |
| ----------- | --------------- |
| `Config.registerPath(fileKey, path)` | Registers one logical file key. Same key plus same path is idempotent. Rejects empty keys/paths, same key with a different path, and duplicate physical paths. |
| `Config.registerPaths(pathTable)` | Registers multiple files at once. Requires an object. Returns `false` when one or more entries fail. |
| `Config.hasPath(fileKey)` | Registry lookup. Returns `true` when the key is registered, `false` otherwise. Does not fall back to `homeConfig`. |
| `Config.pathFor(fileKey)` | Returns the resolved physical path for a key. Unknown keys fall back to the `homeConfig` path. |
| `Config.updatePath(fileKey, path)` | Changes the physical path of an existing non-default key, discards its old document, and loads the new file. Rejects `homeConfig`, unregistered keys, empty paths, dirty/writing files, and duplicate physical paths. |
| `Config.removePath(fileKey)` | Removes a non-default key plus its document, state, and watcher. Leaves the physical file untouched. Rejects `homeConfig`, unregistered keys, and dirty/writing files. |

| Example | Result |
| ------- | ------ |
| `Config.registerPath("networkConfig", "~/.config/N0ctOS/network.json")` | `true` and key registered plus controller created; `true` when already registered with the same path; `false` on empty key/path, conflicting path, or duplicate physical path |
| `Config.registerPaths({networkConfig: "~/.config/N0ctOS/network.json"})` | `true` when every entry registered; `false` when one or more entries failed or the table is not an object |
| `Config.hasPath("networkConfig")` | `true` when registered, `false` otherwise (no fallback) |
| `Config.pathFor("networkConfig")` | Resolved path, e.g. `"/home/user/.config/N0ctOS/network.json"`; `homeConfig` path when the key is unknown |
| `Config.updatePath("networkConfig", "~/.config/N0ctOS/network-v2.json")` | `true` and mapping replaced plus old document discarded plus new file loaded; `false` for `homeConfig`, unregistered keys, dirty/writing files, or duplicate physical paths |
| `Config.removePath("networkConfig")` | `true` and registry entry, document, state, and watcher removed (physical file remains); `false` for `homeConfig`, unregistered keys, or dirty/writing files |

Path expansion understands:

```text
~
$HOME
${HOME}
$XDG_CONFIG_HOME
${XDG_CONFIG_HOME}
```

Relative paths resolve relative to the home directory.

## Signals

| How to listen | What does it do |
| ------------- | --------------- |
| `Config.documentChanged(fileKey)` | Emitted when a document is replaced (local write or external reload). |
| `Config.externalReload()` | Emitted when any file finishes an external reload. |
| `Config.externalReloadFor(fileKey)` | Emitted when the given file finishes an external reload. |
| `Config.saveError(reason)` | Emitted when any file fails to save or create its directory. |
| `Config.saveErrorFor(fileKey, reason)` | Emitted when the given file fails to save or create its directory. |

### Typical component usage

```qml
readonly property bool isDnd:
    Config.get(
        "notifications.isDnd",
        false
    )

readonly property int volume:
    Config.get(
        "audio.volume",
        100
    )

readonly property var wifiEnabled:
    Config.get(
        "wifi.enabled",
        true,
        "networkConfig"
    )
```

That is the intended everyday usage.

Components normally should not need to know how documents, file keys, watchers, or the save queue work.

---

# 3. IPC API

IPC target:

```text
n0ctos-config
```

The IPC layer exposes high-level configuration operations. A terminal command does not need to know about `FileView`, JSON parsing, watchers, write queues, atomic writes, or document objects.

## Core CRUD

| How to call | What does it do |
| ----------- | --------------- |
| `get <path>` | Reads a value from `homeConfig` as JSON. Returns `""` when missing. |
| `has <path>` | Checks whether a value exists in `homeConfig`. |
| `setJson <path> <json>` | Parses `<json>` and writes it to `homeConfig`. |
| `updateJson <section> <json-object>` | Deep-merges a JSON object patch into a `homeConfig` section. Rejects non-object patches. |
| `remove <path>` | Deletes a value from `homeConfig`. |

| Example | Result |
| ------- | ------ |
| `qs ipc call n0ctos-config get notifications.isDnd` | `"true"` (JSON value), or `""` when missing |
| `qs ipc call n0ctos-config has notifications.isDnd` | `"true"` when it exists, `"false"` when it does not |
| `qs ipc call n0ctos-config setJson notifications.isDnd true` | `"true"` and value written plus save queued; `"false"` on invalid JSON or rejected write |
| `qs ipc call n0ctos-config updateJson notifications '{"isDnd":true}'` | `"true"` and section merged plus save queued; `"false"` on invalid JSON or non-object patch |
| `qs ipc call n0ctos-config remove notifications.isDnd` | `"true"` and property deleted plus save queued; `"false"` when the path does not exist |

`<json>` must be valid JSON.

For example:

```bash
qs ipc call n0ctos-config setJson \
    notifications \
    '{"isDnd":true,"timeout":5}'
```

Boolean:

```bash
qs ipc call n0ctos-config setJson \
    notifications.isDnd \
    true
```

Number:

```bash
qs ipc call n0ctos-config setJson \
    audio.volume \
    80
```

String:

```bash
qs ipc call n0ctos-config setJson \
    wallpaper.mode \
    '"random"'
```

Object patch:

```bash
qs ipc call n0ctos-config updateJson \
    notifications \
    '{"isDnd":true,"timeout":5}'
```

Read a value:

```bash
qs ipc call n0ctos-config get \
    notifications.isDnd
```

returns:

```text
true
```

or an empty string when the property does not exist.

Check existence:

```bash
qs ipc call n0ctos-config has \
    notifications.isDnd
```

returns:

```text
true
```

or:

```text
false
```

## State and paths

| How to call | What does it do |
| ----------- | --------------- |
| `isReady` | Returns whether `homeConfig` is ready. |
| `isWriting` | Returns whether `homeConfig` is writing. |
| `isDirty` | Returns whether `homeConfig` has unsaved changes. |
| `getPath` | Returns the resolved `homeConfig` path. |
| `getRevision` | Returns the `homeConfig` revision number. |

| Example | Result |
| ------- | ------ |
| `qs ipc call n0ctos-config isReady` | `"true"` when ready, `"false"` otherwise |
| `qs ipc call n0ctos-config isWriting` | `"true"` while writing, `"false"` otherwise |
| `qs ipc call n0ctos-config isDirty` | `"true"` when unsaved changes exist, `"false"` otherwise |
| `qs ipc call n0ctos-config getPath` | `"/home/user/.config/N0ctOS/config.json"` |
| `qs ipc call n0ctos-config getRevision` | `"3"` (current revision number) |

For example:

```bash
qs ipc call n0ctos-config isReady
```

returns:

```text
true
```

or:

```text
false
```

```bash
qs ipc call n0ctos-config getPath
```

returns:

```text
/home/user/.config/N0ctOS/config.json
```

```bash
qs ipc call n0ctos-config getRevision
```

returns:

```text
3
```

## File control

| How to call | What does it do |
| ----------- | --------------- |
| `save` | Saves `homeConfig`. |
| `reload` | Reloads `homeConfig`, discarding unsaved state. Rejected while writing. |
| `reloadAll` | Reloads every registered file. Skips files currently being written. |

| Example | Result |
| ------- | ------ |
| `qs ipc call n0ctos-config save` | `"true"` and save queued; `"false"` when no controller exists or the file is neither ready nor dirty |
| `qs ipc call n0ctos-config reload` | `"true"` and file reloaded; `"false"` while writing or when no controller exists |
| `qs ipc call n0ctos-config reloadAll` | `"true"` when every file reloaded; `"false"` when one or more files were skipped or failed |

For example:

```bash
qs ipc call n0ctos-config save
```

```bash
qs ipc call n0ctos-config reload
```

```bash
qs ipc call n0ctos-config reloadAll
```

## Registry

| How to call | What does it do |
| ----------- | --------------- |
| `hasPath <fileKey>` | Checks whether a file key is registered. No fallback. |
| `getPaths` | Returns all registered paths as a JSON string. Returns `""` on serialization failure. |
| `registerPath <fileKey> <path>` | Registers one logical file key. |
| `updatePath <fileKey> <path>` | Redirects an existing non-default key to a new physical path. |
| `removePath <fileKey>` | Removes a non-default key. Leaves the physical file untouched. |

| Example | Result |
| ------- | ------ |
| `qs ipc call n0ctos-config hasPath networkConfig` | `"true"` when registered, `"false"` otherwise |
| `qs ipc call n0ctos-config getPaths` | `'{"homeConfig":"/home/user/.config/N0ctOS/config.json",...}'`, or `""` on failure |
| `qs ipc call n0ctos-config registerPath networkConfig '~/.config/N0ctOS/network.json'` | `"true"` and key registered; `"false"` when rejected |
| `qs ipc call n0ctos-config updatePath networkConfig '~/.config/N0ctOS/network-v2.json'` | `"true"` and path replaced plus new file loaded; `"false"` when rejected |
| `qs ipc call n0ctos-config removePath networkConfig` | `"true"` and registry entry removed (file remains); `"false"` when rejected |

For example:

```bash
qs ipc call \
    n0ctos-config \
    hasPath \
    networkConfig
```

returns:

```text
true
```

when the key is registered.

```bash
qs ipc call \
    n0ctos-config \
    getPaths
```

returns:

```json
{
    "homeConfig": "/home/user/.config/N0ctOS/config.json",
    "networkConfig": "/home/user/.config/N0ctOS/network.json"
}
```

```bash
qs ipc call \
    n0ctos-config \
    registerPath \
    networkConfig \
    '~/.config/N0ctOS/network.json'
```

```bash
qs ipc call \
    n0ctos-config \
    updatePath \
    networkConfig \
    '~/.config/N0ctOS/network-v2.json'
```

This changes the physical path associated with `networkConfig`. It does not move or copy the old file.

```bash
qs ipc call \
    n0ctos-config \
    removePath \
    networkConfig
```

This removes the logical registry entry and its watcher. It does not delete the physical file.

## File-specific operations

| How to call | What does it do |
| ----------- | --------------- |
| `isReadyAt <fileKey>` | Returns whether the given file is ready. Unknown keys fall back to `homeConfig`. |
| `isWritingAt <fileKey>` | Returns whether the given file is writing. Unknown keys fall back to `homeConfig`. |
| `isDirtyAt <fileKey>` | Returns whether the given file is dirty. Unknown keys fall back to `homeConfig`. |
| `getPathAt <fileKey>` | Returns the resolved path for the given key. Unknown keys fall back to the `homeConfig` path. |
| `getRevisionAt <fileKey>` | Returns the revision for the given key. Unknown keys fall back to `homeConfig`. |
| `getAt <path> <fileKey>` | Reads a value from the given file as JSON. Returns `""` when missing. Unknown keys fall back to `homeConfig`. |
| `hasAt <path> <fileKey>` | Checks existence in the given file. Unknown keys fall back to `homeConfig`. |
| `setJsonAt <path> <json> <fileKey>` | Writes parsed JSON to the given file. Unknown keys fall back to `homeConfig`. |
| `updateJsonAt <section> <json-object> <fileKey>` | Merges an object patch into the given file. Unknown keys fall back to `homeConfig`. |
| `removeAt <path> <fileKey>` | Deletes a value from the given file. Unknown keys fall back to `homeConfig`. |
| `saveAt <fileKey>` | Saves the given file. |
| `reloadAt <fileKey>` | Reloads the given file, discarding unsaved state. Rejected while writing. |

| Example | Result |
| ------- | ------ |
| `qs ipc call n0ctos-config isReadyAt networkConfig` | `"true"` when ready, `"false"` otherwise |
| `qs ipc call n0ctos-config isWritingAt networkConfig` | `"true"` while writing, `"false"` otherwise |
| `qs ipc call n0ctos-config isDirtyAt networkConfig` | `"true"` when dirty, `"false"` otherwise |
| `qs ipc call n0ctos-config getPathAt networkConfig` | `"/home/user/.config/N0ctOS/network.json"` (`homeConfig` path when unknown) |
| `qs ipc call n0ctos-config getRevisionAt networkConfig` | `"3"` (revision for that file) |
| `qs ipc call n0ctos-config getAt wifi.enabled networkConfig` | `"true"` (JSON value), or `""` when missing |
| `qs ipc call n0ctos-config hasAt wifi.enabled networkConfig` | `"true"` when it exists, `"false"` when it does not |
| `qs ipc call n0ctos-config setJsonAt wifi.enabled false networkConfig` | `"true"` and value written plus save queued; `"false"` when rejected |
| `qs ipc call n0ctos-config updateJsonAt wifi '{"enabled":true}' networkConfig` | `"true"` and section merged plus save queued; `"false"` on invalid or non-object patch |
| `qs ipc call n0ctos-config removeAt wifi.enabled networkConfig` | `"true"` and property deleted plus save queued; `"false"` when missing |
| `qs ipc call n0ctos-config saveAt networkConfig` | `"true"` and save queued; `"false"` when no controller exists or the file is neither ready nor dirty |
| `qs ipc call n0ctos-config reloadAt networkConfig` | `"true"` and file reloaded; `"false"` while writing or when no controller exists |

For example, read from another file:

```bash
qs ipc call \
    n0ctos-config \
    getAt \
    wifi.enabled \
    networkConfig
```

Write to another file:

```bash
qs ipc call \
    n0ctos-config \
    setJsonAt \
    wifi.enabled \
    false \
    networkConfig
```

Update another file:

```bash
qs ipc call \
    n0ctos-config \
    updateJsonAt \
    wifi \
    '{"enabled":true}' \
    networkConfig
```

Remove from another file:

```bash
qs ipc call \
    n0ctos-config \
    removeAt \
    wifi.enabled \
    networkConfig
```

Save and reload:

```bash
qs ipc call \
    n0ctos-config \
    saveAt \
    networkConfig
```

```bash
qs ipc call \
    n0ctos-config \
    reloadAt \
    networkConfig
```

---

# 4. Features / limitations

## Features

### Centralized configuration ownership

Configuration file handling is centralized in:

```text
ConfigStore.qml
```

UI and services consume:

```text
Config.qml
```

rather than implementing their own persistence mechanisms.

### Reactive documents

Configuration changes propagate through QML property bindings.

For example:

```qml
property bool isDnd:
    Config.get(
        "notifications.isDnd",
        false
    )
```

When the document is replaced, the binding reevaluates.

### Multiple configuration files

The service supports registered file keys such as:

```text
homeConfig
networkConfig
wallpaperConfig
themeConfig
```

Each file behaves as an independent reactive document while sharing one public API:

```text
ConfigStore
    │
    ├── homeConfig document + state
    ├── networkConfig document + state
    └── wallpaperConfig document + state
```

### Per-file state

Every configuration file has its own:

```text
document
ready
writing
dirty
revision
```

observed through:

```qml
Config.readyFor(
    "networkConfig"
)
```

or the default-file shortcuts:

```qml
Config.ready
Config.writing
Config.dirty
Config.revision
```

### Event-driven file watching

Files use:

```qml
watchChanges: true
```

instead of a periodic polling loop.

The intended behavior is:

```text
file changes
     │
     ▼
watcher event
     │
     ▼
short debounce
     │
     ▼
reload
     │
     ▼
parse JSON
     │
     ▼
update document
```

The debounce exists only to coalesce rapid filesystem event bursts. It is not a polling mechanism.

### Debounced reloads

Filesystem operations may produce several rapid events:

```text
temporary file created
temporary file renamed
target replaced
metadata changed
```

A single short single-shot timer coalesces them:

```text
fileChanged
    │
    ▼
restart debounce timer
    │
    ▼
more events?
   /      \
 yes       no
  │          │
  ▼          ▼
restart    reload
```

The timer only runs after a filesystem event.

### Atomic writes

Configuration files use:

```qml
atomicWrites: true
```

### Write queue

Multiple changes occurring while a write is already in progress are collapsed into the latest serialized state:

```text
current write
     │
     ▼
onSaved
     │
     ▼
queued latest state?
   /        \
 yes         no
  │            │
  ▼            ▼
write it    complete
```

Only the latest queued document needs to be written.

For example:

```text
set A
   │
   ├── write starts
   │
set B
   │
   ├── write already active
   │
   └── latest state queued
```

The service does not start several writes simultaneously.

### Automatic directory creation

Parent directories are created automatically before the first write:

```text
first write
    │
    ▼
mkdir -p parent
    │
    ▼
FileView.setText()
```

### JSON validation

The service validates loaded configuration and rejects invalid JSON.

Empty files are interpreted as:

```json
{}
```

### Corruption protection

Malformed configuration files are not automatically replaced with `{}` when a valid document is already available.

When JSON parsing fails:

```text
file
 │
 ▼
JSON.parse()
 │
 ✗
 │
 ▼
warning/error log
```

The service preserves the existing valid in-memory document.

### Path abstraction

Services use logical keys rather than repeating physical filesystem paths:

```text
networkConfig
```

instead of:

```text
/home/user/.config/N0ctOS/network.json
```

### Path expansion

The service understands:

```text
~
$HOME
${HOME}
$XDG_CONFIG_HOME
${XDG_CONFIG_HOME}
```

Relative paths resolve relative to the home directory.

### Path registry CRUD

The registry supports:

```text
Create
Read
Update
Delete
```

for non-default configuration paths:

```text
CREATE
    Config.registerPath()
    Config.registerPaths()

READ
    Config.hasPath()
    Config.pathFor()
    Config.paths
    Config.pathKeys

UPDATE
    Config.updatePath()

DELETE
    Config.removePath()
```

### Registry safety

The service prevents:

```text
duplicate physical paths
removing homeConfig
updating homeConfig
updating an unregistered key
removing an unregistered key
changing a dirty/writing path
```

### Deep object updates

`update()` performs a recursive object merge.

Current:

```json
{
    "popup": {
        "enabled": true,
        "timeout": {
            "normal": 5,
            "critical": 0
        }
    }
}
```

Patch:

```json
{
    "popup": {
        "timeout": {
            "normal": 8
        }
    }
}
```

Result:

```json
{
    "popup": {
        "enabled": true,
        "timeout": {
            "normal": 8,
            "critical": 0
        }
    }
}
```

Existing nested properties not present in the patch remain unchanged.

### Revision tracking

Each document has a revision number:

```text
revision 1
    │
external reload
    ▼
revision 2
    │
set()
    ▼
revision 3
```

The revision is useful as a reactive change marker.

### Debug logging

The service provides explicit debug logging for:

```text
path registration
file loading
file watching
document updates
writes
save failures
IPC operations
```

`ConfigStore` exposes:

```qml
ConfigStore.debugLogging
```

The default value is:

```text
true
```

When enabled, lifecycle operations emit messages such as:

```text
[N0ctOS Config] LOAD File loaded: homeConfig -> /home/user/.config/N0ctOS/config.json

[N0ctOS Config] WRITE set(): homeConfig -> audio.volume revision: 4

[N0ctOS Config] WRITE Writing config: homeConfig -> /home/user/.config/N0ctOS/config.json

[N0ctOS Config] WRITE Write completed: homeConfig -> /home/user/.config/N0ctOS/config.json

[N0ctOS Config] PATH Path registered: networkConfig -> /home/user/.config/N0ctOS/network.json
```

Debug logging does not intentionally print configuration values. Warnings and errors remain enabled even when debug logging is disabled.

To disable normal debug output:

```qml
ConfigStore.debugLogging = false
```

`Config.debugLogging` is a read-only mirror and cannot be assigned directly.

### IPC control

Configuration and path registry operations can be controlled from the terminal through:

```text
n0ctos-config
```

---

## Limitations

### JSON only

The configuration format is JSON.

The service does not provide YAML, TOML, INI, or arbitrary binary configuration support.

### Root must be an object

Configuration documents are expected to have:

```json
{}
```

as their root structure.

Root arrays and primitive root values are not accepted:

```json
[]
```

```json
"hello"
```

```json
42
```

When the root is invalid, the service does not intentionally overwrite the file.

### File keys must be registered

A secondary configuration file must be registered before it can be intentionally addressed.

Unknown keys fall back to:

```text
homeConfig
```

for normal configuration operations.

### Registry CRUD does not fallback

Registry operations require exact keys.

For example:

```qml
Config.removePath(
    "notRegistered"
)
```

does not remove or modify `homeConfig`. It returns `false`.

### A file key identifies one physical file

A registered key cannot be silently redirected.

Path changes must use:

```qml
Config.updatePath()
```

### Duplicate physical paths are rejected

The same physical file cannot be registered under multiple logical keys. That would create two watchers for one file.

### `homeConfig` is permanent

The default file key cannot be removed or redirected through the registry API:

```qml
Config.updatePath(
    "homeConfig",
    "/somewhere/config.json"
)
```

is rejected, and:

```qml
Config.removePath(
    "homeConfig"
)
```

is rejected.

### Dirty files cannot change registry ownership

A file key cannot be updated or removed while it has unsaved local changes or an active write:

```text
dirty
```

or:

```text
writing
```

This prevents pending local changes from being detached from their file.

### No arbitrary path writes through normal API

The normal configuration API works through logical file keys. There is no:

```qml
Config.setAtAbsolutePath(...)
```

### Invalid external JSON is not silently repaired

When a file contains malformed JSON, the service logs the error and preserves the last known valid in-memory document.

### Registry removal does not delete files

Removing a key from the registry does not delete its physical JSON file:

```qml
Config.removePath(
    "networkConfig"
)
```

does **not** execute:

```text
rm ~/.config/N0ctOS/network.json
```

The operation only removes N0ctOS's ownership of that logical path.

### `undefined` is not storable

JSON has no `undefined` value.

Therefore:

```qml
Config.set(
    "some.value",
    undefined
)
```

returns `false`.

`null` is valid because it is a valid JSON value.

### Explicit reload discards local state

An explicit:

```qml
Config.reload()
```

intentionally discards unsaved local changes for that file.

---

# 5. Example use cases

## 5.1 Basic service configuration

A service only needs a reactive read:

```qml
import QtQuick

import qs.services

Item {
    readonly property bool isDnd:
        Config.get(
            "notifications.isDnd",
            false
        )

    readonly property int volume:
        Config.get(
            "audio.volume",
            100
        )
}
```

When the configuration changes:

```json
{
    "audio": {
        "volume": 80
    }
}
```

the binding reevaluates.

The component does not need to know whether the value came from:

```text
a local write
an external editor
an IPC call
the initial file load
```

It only receives the effective value.

---

## 5.2 Writing configuration from a UI

Toggle a setting without touching files:

```qml
import QtQuick

import qs.services

MouseArea {
    anchors.fill: parent

    onClicked: {
        Config.set(
            "notifications.isDnd",
            !Config.get(
                "notifications.isDnd",
                false
            )
        )
    }
}
```

The service:

```text
changes document
      ↓
marks dirty
      ↓
queues save
      ↓
writes JSON
```

The UI does not perform file operations itself.

---

## 5.3 Registering a service-specific file

A service defines its path table locally:

```qml
import QtQuick

import qs.services

Item {
    readonly property var configPaths: ({
        networkConfig:
            "~/.config/N0ctOS/network.json"
    })

    Component.onCompleted: {
        Config.registerPaths(
            configPaths
        )
    }
}
```

Then:

```qml
readonly property bool wifiEnabled:
    Config.get(
        "wifi.enabled",
        true,
        "networkConfig"
    )
```

If the key is already registered with the same path, registration is idempotent and returns `true`.

---

## 5.4 Updating several values

Use `update()` when multiple properties inside the same section should change together:

```qml
Config.update(
    "wallpaper",
    {
        mode: "random",
        interval: 600,
        transition: "fade"
    }
)
```

This deep-merges instead of replacing the whole section.

For another file:

```qml
Config.update(
    "wifi",
    {
        enabled: true,
        autoConnect: true
    },
    "networkConfig"
)
```

A non-object patch returns `false`.

---

## 5.5 Removing an optional setting

```qml
Config.remove(
    "wallpaper.transition"
)
```

Afterwards:

```qml
Config.has(
    "wallpaper.transition"
)
```

returns:

```text
false
```

`remove()` itself returns `true` on success and `false` when the path did not exist.

---

## 5.6 Watching a configuration value reactively

```qml
import QtQuick

import qs.services

Item {
    property bool isDnd:
        Config.get(
            "notifications.isDnd",
            false
        )

    Text {
        text:
            parent.isDnd
                ? "DND"
                : "Notifications"
    }
}
```

When another process modifies the file:

```text
JSON file
    ↓
FileView watcher
    ↓
reload
    ↓
document replacement
    ↓
Config.get() changes
    ↓
isDnd changes
    ↓
Text updates
```

No polling timer is required.

---

## 5.7 Displaying configuration state

```qml
import QtQuick

import qs.services

Column {
    Text {
        text:
            "Ready: " +
            Config.ready
    }

    Text {
        text:
            "Writing: " +
            Config.writing
    }

    Text {
        text:
            "Dirty: " +
            Config.dirty
    }

    Text {
        text:
            "Revision: " +
            Config.revision
    }

    Text {
        text:
            Config.configPath
    }
}
```

For another file, use:

```qml
Config.readyFor(
    "networkConfig"
)
```

---

## 5.8 Manual reload button

```qml
import QtQuick

import qs.services

Rectangle {
    width: 120
    height: 36

    Text {
        anchors.centerIn: parent
        text: "Reload"
    }

    MouseArea {
        anchors.fill: parent

        onClicked:
            Config.reload()
    }
}
```

Explicit reload discards unsaved local state for that file. While a write is active it returns `false`.

---

## 5.9 Reload every registered file

```qml
MouseArea {
    anchors.fill: parent

    onClicked:
        Config.reloadAll()
}
```

Files currently being written are skipped. The call returns `false` when any file was skipped or failed.

---

## 5.10 File-specific configuration

```qml
readonly property bool ethernetEnabled:
    Config.get(
        "ethernet.enabled",
        true,
        "networkConfig"
    )

readonly property int volume:
    Config.get(
        "audio.volume",
        100,
        "homeConfig"
    )
```

Both values are reactive even though they belong to different files.

---

## 5.11 Path registry workflow

A service can create a dedicated file:

```qml
Config.registerPath(
    "networkConfig",
    "~/.config/N0ctOS/network.json"
)
```

Check it:

```qml
Config.hasPath(
    "networkConfig"
)
```

Inspect it:

```qml
Config.pathFor(
    "networkConfig"
)
```

Redirect it:

```qml
Config.updatePath(
    "networkConfig",
    "~/.config/N0ctOS/network-v2.json"
)
```

Remove the logical registration:

```qml
Config.removePath(
    "networkConfig"
)
```

The physical JSON file remains untouched by `removePath()`.

---

## 5.12 Debugging configuration

Enable:

```qml
ConfigStore.debugLogging = true
```

Then perform:

```qml
Config.set(
    "audio.volume",
    75
)
```

The log flow is approximately:

```text
[N0ctOS Config] WRITE set(): homeConfig -> audio.volume revision: 4

[N0ctOS Config] WRITE Writing config:
homeConfig
->
/home/user/.config/N0ctOS/config.json

[N0ctOS Config] WRITE Write completed:
homeConfig
->
/home/user/.config/N0ctOS/config.json
```

For an external change:

```text
[N0ctOS Config] WATCH Filesystem change detected:
homeConfig
->
/home/user/.config/N0ctOS/config.json

[N0ctOS Config] WATCH Reloading changed file:
homeConfig
->
/home/user/.config/N0ctOS/config.json

[N0ctOS Config] LOAD File loaded:
homeConfig
->
/home/user/.config/N0ctOS/config.json
```

This makes watcher and write problems much easier to diagnose.

---

## 5.13 Terminal workflow

Read a value:

```bash
qs ipc call n0ctos-config get \
    notifications.isDnd
```

Check existence:

```bash
qs ipc call n0ctos-config has \
    notifications.isDnd
```

Write JSON:

```bash
qs ipc call n0ctos-config setJson \
    audio.volume \
    80
```

Update a section:

```bash
qs ipc call n0ctos-config updateJson \
    notifications \
    '{"isDnd":true,"timeout":5}'
```

Remove a value:

```bash
qs ipc call n0ctos-config remove \
    notifications.isDnd
```

Inspect service state:

```bash
qs ipc call n0ctos-config isReady
```

```bash
qs ipc call n0ctos-config getPath
```

```bash
qs ipc call n0ctos-config getRevision
```

Manage the registry:

```bash
qs ipc call n0ctos-config registerPath \
    networkConfig \
    '~/.config/N0ctOS/network.json'
```

```bash
qs ipc call n0ctos-config getPaths
```

Work with another file:

```bash
qs ipc call n0ctos-config getAt \
    wifi.enabled \
    networkConfig
```

```bash
qs ipc call n0ctos-config setJsonAt \
    wifi.enabled \
    false \
    networkConfig
```

```bash
qs ipc call n0ctos-config saveAt \
    networkConfig
```

---

# 6. Detailed architecture

This section is for developers working on `Config.qml`, `ConfigStore.qml`, and the services/components that consume them.

---

## 6.1 Overall architecture

The architecture is:

```text
N0ctOS UI / Services
        │
        ▼
    Config.qml
        │
        ▼
 ConfigStore.qml
        │
        ├── Path registry
        │
        ├── File controllers
        │
        ├── Reactive documents
        │
        ├── FileView watchers
        │
        ├── JSON parser
        │
        ├── Write queue
        │
        ├── Reload debounce
        │
        └── IPC
        │
        ▼
Configuration files
```

There are two layers:

```text
Config.qml
    public / convenient API

ConfigStore.qml
    actual implementation
```

The UI normally interacts only with `Config`.

---

## 6.2 `Config.qml`

`Config.qml` is the public service facade.

It exposes:

```text
state
read API
write API
file control
path registry
signals
debug state
```

It does not own the actual files.

For example:

```qml
function get(
    path,
    fallbackValue,
    fileKey
) {
    return ConfigStore.get(
        path,
        fallbackValue,
        fileKey
    )
}
```

`Config.qml` also forwards store signals and adds debug context to writes, path operations, saves, and reloads.

---

## 6.3 `ConfigStore.qml`

`ConfigStore.qml` owns:

```text
configuration documents
file paths
FileView instances
directory creation
JSON parsing
saving
watching
reloading
write queues
path registry
IPC
```

It is the only component that directly manages configuration files.

---

## 6.4 The file registry

The store maintains a logical path table:

```qml
{
    homeConfig:
        "/home/user/.config/N0ctOS/config.json",

    networkConfig:
        "/home/user/.config/N0ctOS/network.json"
}
```

The keys are logical identifiers. The values are resolved physical paths.

Consumers therefore operate on:

```text
networkConfig
```

instead of:

```text
/home/user/.config/N0ctOS/network.json
```

---

## 6.5 `homeConfig`

`homeConfig` is the default configuration key.

Its path is based on:

```text
$XDG_CONFIG_HOME
```

when available. Otherwise:

```text
$HOME/.config
```

is used.

The resulting default path is:

```text
$XDG_CONFIG_HOME/N0ctOS/config.json
```

or:

```text
$HOME/.config/N0ctOS/config.json
```

`homeConfig` is always present and cannot be removed or redirected.

---

## 6.6 Why services own path registration

Individual services know which configuration files they need.

For example:

```text
Network service
    → networkConfig

Wallpaper service
    → wallpaperConfig

User-wide shell configuration
    → homeConfig
```

This prevents `ConfigStore` from becoming a giant hard-coded list of every N0ctOS service. The service registers its own path table.

---

## 6.7 One controller per registered file

Each registered configuration file has one controller.

The controller contains the I/O-specific state:

```text
directoryReady
writeText
queuedWriteText
reload debounce
FileView
directory creation Process
```

The reactive document and state are owned by the root store:

```text
documents
fileStates
```

Conceptually:

```text
homeConfig
    │
    ├── reactive document
    ├── reactive state
    └── FileView controller

networkConfig
    │
    ├── reactive document
    ├── reactive state
    └── FileView controller

wallpaperConfig
    │
    ├── reactive document
    ├── reactive state
    └── FileView controller
```

This separates:

```text
reactive state
```

from:

```text
filesystem mechanics
```

---

## 6.8 Why the controller uses `Item`

The dynamic `Instantiator` delegate is an invisible:

```qml
Item
```

rather than a `QtObject`.

It contains:

```qml
Timer
Process
FileView
```

as child objects.

`Item` provides the required child-object container behavior. The controllers themselves are invisible and have:

```qml
visible: false
width: 0
height: 0
```

so they do not create visible UI.

---

## 6.9 Why there is no polling loop

The service does not do:

```qml
Timer {
    interval: 1000
    repeat: true
}
```

just to check whether a configuration file changed.

Instead:

```qml
FileView {
    watchChanges: true
}
```

lets the filesystem notify the service. This keeps configuration monitoring event-driven.

---

## 6.10 Reload debounce

Filesystem operations may result in multiple rapid change events.

For example:

```text
temporary file created
temporary file renamed
target replaced
metadata changed
```

The service uses one short single-shot timer:

```text
fileChanged
    │
    ▼
restart debounce timer
    │
    ▼
more events?
   /      \
 yes       no
  │          │
  ▼          ▼
restart    reload
```

The interval is `80ms`. The timer only runs after a filesystem event. It is not a continuously running polling loop.

While `writing` is true, watcher-triggered reloads are suppressed.

---

## 6.11 Configuration loading

Loading follows:

```text
FileView.onLoaded
        │
        ▼
read text
        │
        ▼
empty file?
  /      \
yes       no
 │         │
{}      JSON.parse()
           │
           ▼
       validate root
           │
           ▼
       compare document
           │
           ▼
       replace document
```

Empty configuration files are interpreted as:

```json
{}
```

If local state is already dirty when the initial load completes, the disk copy does not overwrite it. The store marks the file ready and queues a save of the local state instead.

---

## 6.12 Configuration root validation

The configuration root must be an object.

Valid:

```json
{}
```

```json
{
    "audio": {}
}
```

Invalid:

```json
[]
```

```json
"hello"
```

```json
42
```

When the root is invalid, the service does not intentionally overwrite the file.

---

## 6.13 Invalid JSON handling

When JSON parsing fails:

```text
file
 │
 ▼
JSON.parse()
 │
 ✗
 │
 ▼
warning/error log
```

The service preserves the existing valid in-memory document when one already exists. This avoids replacing known-good state with:

```json
{}
```

just because an editor temporarily wrote malformed JSON.

When no valid document exists yet, the store initializes that file to `{}`.

---

## 6.14 Reactive document ownership

The root store owns:

```qml
property var _documents
```

rather than each controller owning the public configuration document.

This matters because the store can replace the complete document object:

```text
old document
     │
     ▼
clone / parse
     │
     ▼
new document
     │
     ▼
_documents replaced
     │
     ▼
QML bindings reevaluate
```

Nested objects are therefore not mutated directly as the normal state-transition mechanism.

`Config.data` and `Config.documents` are read-only views of that store state.

---

## 6.15 Revision tracking

Each file has a state object:

```qml
{
    ready: false,
    writing: false,
    dirty: false,
    revision: 0
}
```

The revision increases when the in-memory document changes.

Conceptually:

```text
revision 1
    │
external reload
    ▼
revision 2
    │
set()
    ▼
revision 3
```

A `set()` that leaves the document unchanged is a no-op and does not increment the revision or start a write.

---

## 6.16 Read path resolution

A path such as:

```text
notifications.popup.timeout
```

is split into:

```text
notifications
popup
timeout
```

The store walks the selected document:

```text
document
   │
   ▼
notifications
   │
   ▼
popup
   │
   ▼
timeout
```

If any part does not exist, the fallback value is returned.

An empty path also returns the fallback.

`has()` implements existence by reading with a unique sentinel object:

```text
get(path, sentinel) !== sentinel
    → true
otherwise
    → false
```

---

## 6.17 Write path resolution

For:

```qml
Config.set(
    "audio.output.volume",
    80
)
```

the store clones the current document and walks to:

```text
audio
    │
    ▼
output
```

Missing or invalid intermediate objects are replaced with objects. The final property becomes:

```text
volume = 80
```

The complete updated document is then replaced into the store.

Null, non-object, and array intermediates are replaced. Values are cloned so later caller-side mutation cannot affect stored state.

---

## 6.18 Why documents are cloned

The store avoids directly mutating nested members of the public reactive document.

Instead:

```text
old document
     │
     ▼
clone
     │
     ▼
modify clone
     │
     ▼
replace document
```

This makes the reactive state transition explicit and prevents consumers from holding references that change without a document replacement.

Returned documents and values that are cloned include `set()` inputs and internal merge results. IPC results are serialized with `JSON.stringify()` rather than exposing live objects.

---

## 6.19 Deep merge

`update()` uses a recursive object merge.

Current:

```json
{
    "popup": {
        "enabled": true,
        "timeout": {
            "normal": 5,
            "critical": 0
        }
    }
}
```

Patch:

```json
{
    "popup": {
        "timeout": {
            "normal": 8
        }
    }
}
```

Result:

```json
{
    "popup": {
        "enabled": true,
        "timeout": {
            "normal": 8,
            "critical": 0
        }
    }
}
```

Objects merge recursively. Primitive values, arrays, and `null` replace the previous value.

---

## 6.20 `set()` and `update()`

The relationship is:

```text
set()
    │
    └── replace one path

update()
    │
    └── deep-merge one section
```

`update()` eventually uses the normal `set()` path for persistence:

```text
update(section, patch)
    ↓
get(section, {})
    ↓
deepMerge(clone(current), patch)
    ↓
set(section, merged)
    ↓
queueSave()
```

---

## 6.21 Write lifecycle

A normal configuration write follows:

```text
Config.set()
      │
      ▼
document replaced
      │
      ▼
dirty = true
      │
      ▼
queueSave()
      │
      ▼
serialize
      │
      ▼
FileView.setText()
      │
      ▼
atomic write
      │
      ▼
onSaved
      │
      ▼
dirty = false
```

`set()`, `update()`, and `remove()` all queue saves through the file's controller. If the controller does not exist yet, the dirty state remains in the store and `onObjectAdded()` queues the save once the controller appears.

---

## 6.22 Overlapping writes

Suppose:

```text
set A
```

starts a write and then:

```text
set B
set C
set D
```

happen before the first write finishes.

The service keeps only the latest serialized state in:

```text
queuedWriteText
```

The lifecycle becomes:

```text
write A
   │
   ├── state B
   ├── state C
   └── state D
          │
          ▼
 latest queued state
```

When A completes, the latest state is written.

---

## 6.23 Why the latest state wins

Configuration represents current state.

Therefore:

```text
volume = 30
volume = 40
volume = 50
```

does not require three simultaneous or sequential disk writes when the state can safely be collapsed to:

```text
volume = 50
```

---

## 6.24 Directory creation

Before writing a file, the service ensures its parent directory exists.

Conceptually:

```text
first write
    │
    ▼
mkdir -p parent
    │
    ▼
FileView.setText()
```

This runs through a `Process` (`mkdir -p`). While the directory is missing, writes are queued as `dirty`. On failure the pending state is preserved, `dirty` remains `true`, and `saveError` is emitted.

---

## 6.25 Missing files

A missing `homeConfig` file is treated as:

```json
{}
```

and automatically saved, so the default file is created on first run.

Other registered files can remain absent until they are explicitly written.

A previously loaded file that disappears externally is reset to `{}` with an external-reload notification, unless local state is dirty. Dirty local state is preserved.

---

## 6.26 External reload

A normal external modification follows:

```text
editor modifies file
        │
        ▼
FileView.fileChanged
        │
        ▼
debounce
        │
        ▼
FileView.reload()
        │
        ▼
FileView.onLoaded
        │
        ▼
parse JSON
        │
        ▼
compare with document
        │
        ▼
replace document when changed
        │
        ▼
documentUpdated
        │
        ▼
externalReload
```

Only changed documents bump the revision and emit `documentUpdated`.

---

## 6.27 Own writes versus external writes

A watcher can also report changes caused by the service's own atomic write.

Therefore the service tracks:

```text
writing
```

When:

```text
writing = true
```

watcher-triggered reloads are ignored:

```text
write
  ↓
watch event
  ↓
reload
  ↓
duplicate parse
```

is prevented for normal internal writes. Debounced reloads also check `writing` before calling `FileView.reload()`.

---

## 6.28 Save completion

When `FileView` reports:

```text
onSaved
```

the service:

```text
writing = false
writeText = ""
```

Then it checks:

```text
queuedWriteText
```

If another state is queued:

```text
queued state exists
       │
       ▼
start another write
```

otherwise:

```text
dirty = false
```

---

## 6.29 Save failure

If writing fails:

```text
onSaveFailed
      │
      ▼
writing = false
      │
      ▼
preserve latest pending state
      │
      ▼
dirty = true
      │
      ▼
saveError
```

The older state being written never overwrites a newer queued state.

A later explicit:

```qml
Config.save()
```

can retry the operation.

---

## 6.30 Signals

`ConfigStore` exposes:

```qml
signal externalReload(
    string fileKey
)

signal saveError(
    string fileKey,
    string reason
)

signal documentUpdated(
    string fileKey
)
```

`Config.qml` forwards these through its public API:

```qml
signal externalReload()
signal saveError(string reason)

signal externalReloadFor(string fileKey)
signal saveErrorFor(string fileKey, string reason)

signal documentChanged(string fileKey)
```

### Important signal naming

The store intentionally does **not** define:

```qml
signal documentChanged(...)
```

because `document` is already a QML property.

QML automatically provides the property's generated:

```text
documentChanged()
```

notification.

The custom store signal is therefore:

```text
documentUpdated
```

This avoids a signal-name collision.

`Config.qml` can still expose its own:

```qml
signal documentChanged(string fileKey)
```

because that public signal belongs to the facade rather than the store's `document` property.

---

## 6.31 Reactive state model

Each file has:

```text
document
ready
writing
dirty
revision
```

The main lifecycle is:

```text
                  ┌──────────────┐
                  │   not ready  │
                  └──────┬───────┘
                         │ load
                         ▼
                  ┌──────────────┐
                  │    ready     │
                  └──────┬───────┘
                         │ set/update/remove
                         ▼
                  ┌──────────────┐
                  │    dirty     │
                  └──────┬───────┘
                         │ save
                         ▼
                  ┌──────────────┐
                  │   writing    │
                  └──────┬───────┘
                         │
                 ┌───────┴───────┐
                 │               │
              success          failure
                 │               │
                 ▼               ▼
              clean           dirty/error
```

Default-file properties (`Config.ready`, `Config.writing`, `Config.dirty`, `Config.revision`) are shortcuts for the `homeConfig` entry. Per-file functions (`readyFor()`, `writingFor()`, `dirtyFor()`, `revisionFor()`) observe any registered file.

---

## 6.32 Path registry architecture

The path registry has its own lifecycle:

```text
registerPath()
      │
      ▼
_paths updated
      │
      ▼
_pathKeys updated
      │
      ▼
Instantiator creates controller
      │
      ▼
FileView begins loading
```

Updating:

```text
updatePath()
      │
      ▼
path mapping replaced
      │
      ▼
document/state reset
      │
      ▼
FileView points to new path
      │
      ▼
new document loaded
```

Removing:

```text
removePath()
      │
      ▼
registry entry removed
      │
      ▼
document/state removed
      │
      ▼
Instantiator removes controller
      │
      ▼
FileView/watcher destroyed
```

A `_registryRevision` counter gives `pathFor()`, `documentFor()`, state accessors, and controller lookups an explicit reactive dependency on registry changes.

---

## 6.33 Why registry CRUD is separate from config CRUD

These are fundamentally different operations.

Configuration CRUD:

```text
Config.set()
Config.update()
Config.remove()
```

changes data **inside a configuration document**.

Registry CRUD:

```text
Config.registerPath()
Config.updatePath()
Config.removePath()
```

changes **which files exist in the N0ctOS configuration system**.

They therefore have different fallback rules and safety constraints.

---

## 6.34 Path update lifecycle

A path update:

```qml
Config.updatePath(
    "networkConfig",
    "~/.config/N0ctOS/network-v2.json"
)
```

performs:

```text
validate key
      │
      ▼
validate path
      │
      ▼
reject homeConfig
      │
      ▼
reject dirty/writing state
      │
      ▼
reject duplicate physical path
      │
      ▼
replace registry entry
      │
      ▼
reset document
      │
      ▼
reset state
      │
      ▼
update FileView path
      │
      ▼
reload new file
```

The old JSON file is not migrated automatically. A same-path update is a no-op returning `true`.

---

## 6.35 Path removal lifecycle

A path removal:

```qml
Config.removePath(
    "networkConfig"
)
```

performs:

```text
validate key
      │
      ▼
reject homeConfig
      │
      ▼
reject dirty/writing state
      │
      ▼
remove registry key
      │
      ▼
remove document/state
      │
      ▼
remove controller from Instantiator
```

The physical file remains.

---

## 6.36 Controller lifecycle

Controllers are dynamically created through `Instantiator`.

When a new path is registered:

```text
_pathKeys
    │
    ▼
Instantiator
    │
    ▼
objectAdded
    │
    ▼
_controller map
    │
    ▼
FileView active
```

When a path is removed:

```text
_pathKeys
    │
    ▼
Instantiator
    │
    ▼
objectRemoved
    │
    ▼
_controller removed
    │
    ▼
FileView destroyed
```

The store uses the supported dynamic-object callbacks rather than relying on an `instances` collection.

A write that happens before its controller exists stays dirty in the store; `onObjectAdded()` queues the save once the controller appears.

---

## 6.37 Configuration fallback architecture

Normal configuration operations resolve file keys like this:

```text
requested fileKey
        │
        ▼
is key registered?
      /     \
    yes      no
     │        │
     ▼        ▼
requested   homeConfig
     │        │
     └────┬───┘
          ▼
    physical path
```

This applies to reads, writes, saves, reloads, state accessors, and file-specific IPC.

Registry operations intentionally do not follow this flow. They use exact key matching:

```text
requested fileKey
        │
        ▼
is key registered?
      /     \
    yes      no
     │        │
     ▼        ▼
operation    false
```

---

## 6.38 Debug architecture

Debug logging is centralized in the store.

The main log categories are:

```text
LOAD
    file loads
    parse failures
    reloads

WATCH
    filesystem events
    debounce/reload actions

WRITE
    set/update/remove
    queued saves
    directory creation
    actual writes
    write completion/failure

PATH
    registration
    controller lifecycle
    path updates
    path removal

DATA
    document replacement

IPC
    IPC parsing/serialization problems
```

Debug output is deliberately about state transitions and paths rather than configuration secrets.

---

## 6.39 IPC architecture

IPC does not manipulate the filesystem directly.

Instead:

```text
terminal
   │
   ▼
n0ctos-config
   │
   ▼
ConfigStore API
   │
   ▼
document / registry
   │
   ▼
write queue / FileView
```

For example:

```bash
qs ipc call n0ctos-config setJson audio.volume 80
```

is routed through:

```text
setJson
   ↓
JSON.parse()
   ↓
ConfigStore.set()
   ↓
document update
   ↓
queueSave()
```

`get`/`getAt` serialize through `JSON.stringify()` and return `""` when the value is missing. `setJson`/`updateJson` parse their JSON argument and return `false` on invalid input.

---

## 6.40 Why IPC stays high-level

IPC callers should not need to understand:

```text
FileView
atomicWrites
queuedWriteText
debounce timers
JSON parsing implementation
document cloning
controller objects
```

The IPC layer therefore exposes operations such as:

```text
get
has
setJson
updateJson
remove
save
reload
```

and separate registry operations:

```text
hasPath
getPaths
registerPath
updatePath
removePath
```

plus file-specific variants:

```text
getAt
hasAt
setJsonAt
updateJsonAt
removeAt
saveAt
reloadAt
isReadyAt
isWritingAt
isDirtyAt
getPathAt
getRevisionAt
```

rather than low-level filesystem operations. This keeps the IPC interface stable even if the internal implementation changes.

---

## 6.41 Complete configuration lifecycle

A normal runtime configuration change looks like:

```text
                    CONFIGURATION
                         │
                         ▼
              ┌────────────────────┐
              │   service / UI     │
              └─────────┬──────────┘
                        │
                        ▼
                  Config.set()
                        │
                        ▼
                ConfigStore.set()
                        │
                        ▼
                clone document
                        │
                        ▼
                update property
                        │
                        ▼
              document replaced
                        │
                        ▼
                  dirty = true
                        │
                        ▼
                  queueSave()
                        │
                        ▼
                   serialize
                        │
                        ▼
                  FileView.setText
                        │
                        ▼
                  atomic write
                        │
                        ▼
                    onSaved
                        │
                        ▼
                  dirty = false
```

An external change instead follows:

```text
filesystem
    │
    ▼
FileView.fileChanged
    │
    ▼
debounce
    │
    ▼
reload
    │
    ▼
JSON parse
    │
    ▼
document comparison
    │
    ▼
document replacement
    │
    ▼
revision++
    │
    ▼
documentUpdated
    │
    ▼
QML bindings update
```

---

## 6.42 The multi-file design

The architecture is intentionally based on one store with multiple independent documents:

```text
ConfigStore
    │
    ├── homeConfig
    │       ├── document
    │       ├── state
    │       └── FileView/controller
    │
    ├── networkConfig
    │       ├── document
    │       ├── state
    │       └── FileView/controller
    │
    └── wallpaperConfig
            ├── document
            ├── state
            └── FileView/controller
```

Each file behaves as an independent reactive configuration document while still sharing one public API.

---

## 6.43 Design principles

### One owner

`ConfigStore` owns configuration files.

UI components do not create their own `FileView` instances for normal configuration.

### Config is the public API

Consumers use:

```text
Config
```

rather than depending directly on store internals.

### Documents are reactive

Configuration changes replace document state so QML bindings can react naturally.

### I/O and state are separated

Controllers handle:

```text
FileView
directory creation
watching
write queue
```

while the root store owns:

```text
documents
file states
registry
```

### One controller per registered file

Each registered file gets one watcher/controller.

### No polling

Configuration changes are detected through filesystem events.

### Watchers are debounced

Rapid filesystem event bursts are coalesced before parsing.

### Writes are atomic

Configuration writes use `FileView.atomicWrites`.

### Latest state wins

Concurrent mutations are collapsed into the latest queued document.

### Invalid JSON is not silently destroyed

Malformed files are reported rather than automatically replacing known-good configuration.

### Logical keys hide filesystem details

Services work with:

```text
homeConfig
networkConfig
wallpaperConfig
```

instead of repeating physical paths.

### Unknown configuration keys fallback safely

Normal config reads/writes use:

```text
unknown key → homeConfig
```

### Registry keys do not fallback

Registry CRUD requires exact keys.

### `homeConfig` is protected

The permanent default key cannot be updated or removed through registry CRUD.

### One physical file gets one logical key

Duplicate physical registrations are rejected.

### Services own their path definitions

A service registers the files it needs.

### Registry deletion does not delete data

Removing a logical registration only removes N0ctOS's reference to the file. The physical JSON remains.

### Debug output avoids configuration values

Logs describe lifecycle operations without intentionally dumping configuration contents.

### UI stays simple

UI code should care about:

```text
what configuration value it needs
```

not:

```text
where the file is
how it is watched
how JSON is parsed
how writes are queued
how directories are created
```

---

## 6.44 What UI / service code should not do

UI and normal service code should not:

```text
create a second FileView for the same configuration
read config.json directly
write JSON manually
poll configuration files with Timer
implement its own save queue
implement its own JSON parser
hard-code duplicated absolute config paths
replace the complete document when one property changes
manually watch files that Config already owns
delete configuration files when removing a registry key
```

Instead of:

```qml
FileView {
    path:
        "/home/user/.config/N0ctOS/config.json"

    watchChanges:
        true
}
```

use:

```qml
Config.get(
    "some.value",
    defaultValue
)
```

Instead of manually writing JSON, use:

```qml
Config.set(...)
```

or:

```qml
Config.update(...)
```

Instead of polling:

```qml
Timer {
    interval: 1000
    repeat: true
}
```

rely on the reactive Config service.

Instead of directly changing the registry object:

```qml
Config.paths.foo = "/some/path"
```

use:

```qml
Config.registerPath(...)
```

or:

```qml
Config.updatePath(...)
```

or:

```qml
Config.removePath(...)
```

depending on the intended operation.

Instead of assigning the read-only facade property:

```qml
Config.debugLogging = false
```

use:

```qml
ConfigStore.debugLogging = false
```

---

## 6.45 Final architecture summary

The Config service is designed around one simple rule:

```text
Configuration is shared reactive state,
not a collection of files that every component
has to manage independently.
```

The complete architecture is:

```text
                    N0ctOS
                       │
        ┌──────────────┴──────────────┐
        │                             │
     UI / Services                 IPC
        │                             │
        └──────────────┬──────────────┘
                       ▼
                  Config.qml
                       │
                       ▼
                ConfigStore.qml
                       │
        ┌──────────────┼────────────────┐
        │              │                │
        ▼              ▼                ▼
   homeConfig    networkConfig    other configs
        │              │                │
        ▼              ▼                ▼
     FileView       FileView         FileView
        │              │                │
        └──────────────┼────────────────┘
                       ▼
                filesystem events
                       │
                       ▼
                   debounce
                       │
                       ▼
                    reload
                       │
                       ▼
              reactive documents
                       │
                       ▼
                 N0ctOS UI
```

The intended data flow is therefore:

```text
READ

file
 ↓
FileView
 ↓
JSON
 ↓
document
 ↓
Config
 ↓
service / UI


WRITE

service / UI
 ↓
Config.set/update/remove
 ↓
document
 ↓
dirty
 ↓
save queue
 ↓
FileView
 ↓
atomic write
 ↓
filesystem


EXTERNAL CHANGE

filesystem
 ↓
FileView watcher
 ↓
debounce
 ↓
reload
 ↓
JSON
 ↓
document
 ↓
revision++
 ↓
documentUpdated
 ↓
reactive QML updates


PATH REGISTRY

service
 ↓
Config.registerPath()
 ↓
registry
 ↓
controller
 ↓
FileView


PATH UPDATE

Config.updatePath()
 ↓
validate
 ↓
replace mapping
 ↓
reset document/state
 ↓
reload new file


PATH DELETE

Config.removePath()
 ↓
validate
 ↓
remove mapping
 ↓
remove document/state
 ↓
destroy controller
 ↓
physical file remains
```

The core rule is:

> **Components declare what configuration value they need; `Config.qml` decides which registered document it comes from and how it is read or written; `ConfigStore.qml` handles how files are watched, parsed, queued, and persisted.**
