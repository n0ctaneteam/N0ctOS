# `desktop/lib` — Desktop Support Singletons

> **Path:** `shell/desktop/lib/`  
> **Parent:** `shell/desktop/`  
> **Type:** Internal library (Quickshell singleton helpers used only by `ScreenFrame`)

## What Is This Directory?

`desktop/lib` is the **control plane** for the N0ctOS desktop shell. It contains four singleton-style QML `Item`s that together implement:

1. **Module discovery** — crawling `desktop/modules/` for valid `manifest.json` files.
2. **Blob persistence** — reading/writing `shell/config.json` → `blobs` (which modules live in which blob island).
3. **Service lifecycle** — keeping long-running per-module background objects alive.
4. **IPC orchestration** — exposing `qs ipc call n0ctos-blob …` to activate/deactivate/focus blobs from scripts or keybinds.

All four are instantiated *once* inside `desktop/components/ScreenFrame.qml` and never used elsewhere directly; `ScreenFrame` wires them together.

---

## Children Directories

**None.** Flat collection of four QML singleton components.

---

## Files in This Directory

| File | Lines | Role |
| :--- | :---: | :--- |
| **`ModuleRegistry.qml`** | 232 | Crawls filesystem for `manifest.json` manifests and builds a map `registry[id] → { name, icon, modulePath, settingsPath, servicePath }`. |
| **`BlobManager.qml`** | 253 | Loads, validates, mutates, and persists the `blobs` object in `config.json` (user or skeleton path). Exposes `modules(blobId)`, `blobOf(moduleId)`, `setBlob()` and `save()`. |
| **`BlobIPCHandler.qml`** | 103 | QML `IpcHandler` (`target: "n0ctos-blob"`) bridging CLI → `Blob.qml` operations. Calls `openModule / deactivateModule / toggleModule / focusBlob` on the appropriate blob. |
| **`ServiceManager.qml`** | 253 | Watches the set of *selected* module IDs (union of all blob lists) and lazily creates/destroys `Service.qml` instances per module. |

---

### `ModuleRegistry.qml` — Discovery Engine

**Public API**

```qml
property list<string> searchPaths       // e.g. [Quickshell.shellPath("desktop/modules")]
readonly property var registry         // { [id]: { id, name, icon, modulePath, settingsPath, servicePath, fullPath, manifestPath } }
readonly property int moduleCount
function get(id) -> entry | null
function has(id) -> bool
function discoverModules()             // re-scan
signal registryChanged                 // observed by ServiceManager + Blob
```

**How it works**

1. For each `searchPath`, spawns `Process { command: ["find", path, "-mindepth", "2", "-maxdepth", "2", "-name", "manifest.json"] }`.
2. For every returned `manifest.json`, creates a `FileView` that reads & `JSON.parse`s the file.
3. Validates required fields: `id`, `name`, `module`, `settings` (throws if missing).
4. Resolves relative paths: `base = manifestDir; modulePath = base + "/" + data.module`.
5. Inserts into `_registry` via `Object.assign({}, _registry)` (immutable update to trigger bindings). Duplicate `id` is warned and ignored.
6. Emits `registryChanged`.

Required manifest shape (canonical example — see `../modules/README.md`):

```json
{
  "id": "<module-id>",
  "name": "Human Name",
  "icon": "󰀻",
  "module": "<Module>.qml",
  "settings": "Settings.qml",
  "service": "Service.qml"
}
```

**Diagnostics:** verbose `console.log("[ModuleRegistry] ...")` for every step — useful with `qs -d`.

---

### `BlobManager.qml` — Config Persistence

**Public API**

```qml
property list<string> configPaths // [shellPath("config.json"), statePath("config.json")]
property var blobs: { tr:[], tl:[], tc:[], br:[], bl:[], bc:[], left:[], right:[] }
readonly property string activeConfigPath
function modules(blobId) -> string[]
function blobOf(moduleId) -> blobId | ""
function setBlob(blobId, moduleIds)
function save()
function loadConfig()
```

**Load path**

1. `_tryConfig(index)` tries `configPaths[0]` then `configPaths[1]`.
2. `FileView` (blockLoading) reads file; on success `_configLoaded` validates JSON and that `data.blobs` is an object.
3. Normalizes each `blobId` to `string[]` filtering non-strings, updates `blobs` immutably, saves `activeConfigPath` and original `_configData`.
4. On parse error or missing file, tries next path. If none succeed → `warn: no valid config found`, blobs stay empty.

**Save path**

- `setBlob` mutates a single blob entry then calls `save()`.
- `save()` deep-clones `_configData`, replaces `data.blobs` with current `blobs`, writes via `FileView { atomicWrites: true; setText(JSON.stringify(data,null,4)) }`.

**Blob IDs** (must match `ScreenFrame` + `config.json`):

`tr` (top-right corner), `tl`, `tc` (top-center), `br`, `bl`, `bc` (bottom-center), `left`, `right`.

---

### `BlobIPCHandler.qml` — CLI Bridge

```qml
IpcHandler { target: "n0ctos-blob"
  function activate(moduleId)
  function deactivate(moduleId)
  function toggle(moduleId)
  function focus(blobId)
}
```

- `activate/deactivate/toggle` resolve `blobId = blobManager.blobOf(moduleId)` (reverse lookup) then delegate to that `Blob` instance: `blobs[blobId].openModule / deactivateModule / toggleModule`.
- `focus(blobId)` directly focuses the blob: `blobs[blobId].focusBlob()`.
- Invalid IDs are warned but not fatal.

**CLI examples**

```bash
qs ipc call n0ctos-blob activate <module-id>
qs ipc call n0ctos-blob toggle <module-id>
qs ipc call n0ctos-blob focus <blob-id>   # e.g. bc
```

---

### `ServiceManager.qml` — Long-Lived Services

**Public API**

```qml
required property var moduleRegistry
property string configPath // shellPath("config.json")
readonly property var services        // { [moduleId]: Service instance }
readonly property var loadedModuleIds // Object.keys(services)
function get(moduleId)
function has(moduleId)
```

**Lifecycle**

1. Reads `config.json` → unions all `blobs[blobId][]` into `_selectedModuleIds` (selected = belongs to *any* blob).
2. `_syncServices()` for every selected `moduleId`:
   - Skip if already has service.
   - `info = moduleRegistry.get(moduleId)` — wait if not yet registered.
   - Skip if `info.servicePath == ""` (no `service` in manifest).
   - `Qt.createComponent(info.servicePath)` → `component.createObject(root, { moduleId, moduleInfo, serviceManager })`, store in `_services`, call `service.start()`.
3. For every `moduleId` in `_services` that is no longer selected → call `service.stop()`, `destroy()`, remove from map.
4. Listens to `moduleRegistry.registryChanged` to lazily create services once manifests arrive.

Handles async `Component.Loading` case with `_pendingComponents` and `statusChanged`.

---

## Data Flow Diagram

```
ModuleRegistry  ---- registryChanged --->  BlobManager (icon lookup)
       \                                / ServiceManager (create Service.qml)
        \                            /
         \                        /
          v                      v
                  ScreenFrame desktop/components/ScreenFrame.qml
                    instantiates all 4 singletons
                    creates 8 Blob.qml instances (tr/tl/tc/br/bl/bc/left/right)
                    routes IPC through BlobIPCHandler
```

---

## Adding a New Singleton Here

Rare — only for shell-wide concerns. If you add a new `.qml` here:

1. Ensure it imports `Quickshell.Io` if it does file/process work.
2. Expose a clean QML property/method API; avoid direct `Qt.resolvedUrl` hacks — use `Quickshell.shellPath()` for portability.
3. Instantiate it in `../components/ScreenFrame.qml` alongside the other four.

---

## Related

- **Consumer:** `../components/ScreenFrame.qml` — sole instantiation site
- **Config:** `../../config.json` — blobs mapping persisted by `BlobManager`
- **Discovery targets:** `../modules/*/manifest.json`
- **Hosted content:** `../components/Blob.qml` — per-blob container
- **Service base:** `../components/Service.qml` — class instantiated by `ServiceManager`

