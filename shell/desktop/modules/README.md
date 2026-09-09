# `desktop/modules` — Desktop Module Registry

> **Path:** `shell/desktop/modules/`  
> **Parent:** `shell/desktop/`  
> **Type:** Plug-in discovery root (each subfolder is an independent module)

## What Is This Directory?

`desktop/modules` is the plug-in folder for the desktop shell. Every immediate child directory is a self-contained module — a feature unit assigned to a blob island (corner, edge, or center) defined in `shell/config.json` → `blobs`.

Discovery is automatic: `desktop/lib/ModuleRegistry.qml` searches this directory for `manifest.json` files

```bash
find desktop/modules -mindepth 2 -maxdepth 2 -type f -name manifest.json
```

for every configured `searchPaths` entry, parses each manifest, and builds the in-memory registry `registry[id] → { name, icon, modulePath, settingsPath, servicePath }`. No shell rebuild is required to add a module — add a compliant folder and a manifest.

This directory itself contains no runtime code; it is purely a container.

---

## Children Directories

This directory contains built-in module folders. Each child is an independent module that follows the standard layout documented below.

| Directory | Type | Contains |
| :-------- | :--- | :------- |
| `*/` | Built-in plug-in | One folder per module. Each folder contains a `manifest.json` descriptor and its QML components. Folder name is conventionally the same as the module `id`. |

> Built-in modules are not documented individually. Their structure is defined by the `manifest.json` contract and the canonical example below. For a complete file list, see the filesystem.

---

## Files in This Directory

**None at the top level.** All files live inside the module subdirectories. A compliant module contains at minimum:

- `manifest.json` — required descriptor
- `<Module>.qml` — entry QML component referenced by `manifest.json` → `module`
- `Settings.qml` — required settings panel, even if placeholder

Optionally:

- `Service.qml` — persistent background service (see `desktop/components/Service.qml`)
- Additional variant or helper QML files private to the module

---

## Manifest Structure

`manifest.json` is the only file the registry reads. It must be valid JSON.

### Canonical Example

The following is the accurate reference manifest (from the `launcher` built-in):

```json
{
  "id": "launcher",
  "name": "Launcher",
  "icon": "󰀻",
  "module": "Launcher.qml",
  "settings": "Settings.qml",
  "service": "Service.qml"
}
```

### Field Reference

| Field | Required | Type | Description |
| :---- | :------: | :--- | :---------- |
| `id` | Yes | `string` | Stable, unique identifier. Used as key in `config.json` → `blobs` and in the registry. Must match the main component's `moduleId` property. Lowercase, no spaces. |
| `name` | Yes | `string` | Human-readable display name shown in tooling and logs. |
| `icon` | No | `string` | Single Nerd Font glyph rendered in the blob switcher. Empty string allowed. |
| `module` | Yes | `string` | Filename of the entry QML component relative to the module folder (e.g., `Launcher.qml`). |
| `settings` | Yes | `string` | Filename of the settings panel component relative to the module folder (e.g., `Settings.qml`). Must export an `Item`, even if placeholder. |
| `service` | No | `string` | Filename of the optional persistent service relative to the module folder (e.g., `Service.qml`). If omitted or empty, no service is created. |

### Validation Rules

- `id`, `name`, `module`, `settings` must be present and non-empty — otherwise the registry logs a warning and skips the entry.
- Paths are resolved as `<manifest-folder>/` + `field-value`. No absolute paths, no `../`.
- Duplicate `id` values are warned and the first registration wins.

---

## Module Anatomy — Canonical Example (`launcher`)

`launcher` is the reference implementation for a complete module. Its layout:

```
launcher/
  manifest.json   → id: launcher, module: Launcher.qml, settings: Settings.qml, service: Service.qml
  Launcher.qml    → Module { moduleId: launcher; focusTarget: searchField; ... }
  Settings.qml    → Item { implicitWidth: 500; implicitHeight: 400; ... }  (placeholder)
  Service.qml     → Service { }  (minimal stub)
```

#### `Launcher.qml` — Contract

```qml
import "../../components"

Module {
    id: root
    moduleId: "launcher"          // must match manifest id
    implicitWidth: 620
    implicitHeight: 430
    focusTarget: searchField      // Item to focus when blob gains focus

    // optional lifecycle
    // function activate() { }
    // function deactivate() { }

    // internal state + UI (search, filtering, ListView, etc.)
}
```

- Extends `desktop/components/Module.qml` — provides `moduleId`, `focusTarget`, `variant` loading, and `activate`/`deactivate` plus focus delegation via `focusModule()`.
- `implicitWidth`/`implicitHeight` feed `Blob.qml` sizing (`moduleWidth` / `moduleHeight`).
- `focusTarget` tells the host `Blob` where to place keyboard focus.
- `activate` / `deactivate` are called by `Blob.qml` on load/unload.

#### `Settings.qml` — Contract

```qml
import QtQuick
Item {
    implicitWidth: 500
    implicitHeight: 400
    // settings UI
}
```

Must be an `Item`. Loaded by settings tooling; keep it self-contained.

#### `Service.qml` — Contract

```qml
import qs.desktop.components
Service {
    function start() { /* background work — indexing, watchers */ }
    function stop()  { /* cleanup */ }
}
```

Base class is `desktop/components/Service.qml` (`QtObject` with `moduleId`, `moduleInfo`, `serviceManager` and `start`/`stop`). Only created if `manifest.json` declares `service` and the module is listed in any `blobs` array. Created once per selected module by `ServiceManager`.

---

## Module Contract

A valid module must:

1. Reside in a folder directly under `desktop/modules/` — no deeper nesting.
2. Contain `manifest.json` with `id`, `name`, `module`, `settings`.
3. Provide the entry QML component referenced by `module`:
   - `property string moduleId` matching manifest `id`
   - Optional `function activate()` / `function deactivate()`
   - Optional `property Item focusTarget` when extending `Module`
4. Provide `Settings.qml` exporting an `Item`.
5. If declaring `service`, provide `Service.qml` extending `Service` and overriding `start()` / `stop()`.
6. Use a unique `id`. Duplicates are rejected.

---

## Configuration — Assigning Modules to Blobs

Modules are assigned in `shell/config.json` (or the user state copy at `~/.config/N0ctOS/config.json` managed by `BlobManager`):

```json
{
  "blobs": {
    "br": ["<module-id>"],
    "bl": ["<module-id>", "<module-id>"],
    "bc": ["<module-id>", "<module-id>"],
    "tr": ["<module-id>"],
    "tl": ["<module-id>", "<module-id>"],
    "tc": ["<module-id>"],
    "left": ["<module-id>"],
    "right": ["<module-id>"]
  },
  "blobSwitch": { "modifier": "Super", "next": "J", "previous": "K" }
}
```

- Keys are blob positions: `tr`, `tl`, `tc`, `br`, `bl`, `bc`, `left`, `right`.
- Values are ordered `string[]` of module IDs — order determines switcher order.
- `BlobManager.blobs` is persisted to the active config path (`configPaths[0]` that succeeded).
- An empty array means the blob island exists but hosts no content (still animates on hover).
- An unknown ID is logged as `waiting for registry` by `ServiceManager` until its manifest is discovered.

**IPC control (generic):**

```bash
qs ipc call n0ctos-blob activate <module-id>
qs ipc call n0ctos-blob toggle <module-id>
qs ipc call n0ctos-blob focus <blob-id>
```

Module-specific IPC, if any, is defined by the module itself.

---

## How a Module Loads at Runtime

```
ModuleRegistry: find → FileView → JSON.parse → registry[id]
       ↓ (registryChanged)
ServiceManager: union(config.blobs[*]) → Qt.createComponent(Service.qml) → service.start()
BlobManager: loadConfig() → blobs property
       ↓
ScreenFrame: creates 8× Blob { blobId, moduleRegistry, moduleIds: blobManager.blobs[blobId] }
       ↓
Blob: Loader { source: registry[activeModule].modulePath } → module.activate() / focusModule()
```

---

## Creating a New Module

1. **Scaffold**

   ```bash
   mkdir -p shell/desktop/modules/<module-id>
   cat > shell/desktop/modules/<module-id>/manifest.json <<'JSON'
   {
     "id": "<module-id>",
     "name": "Human Name",
     "icon": "󰀻",
     "module": "<Module>.qml",
     "settings": "Settings.qml",
     "service": "Service.qml"
   }
   JSON
   ```

2. **Implement entry component**

   ```qml
   import "../../components"
   Module {
       id: root
       moduleId: "<module-id>"
       implicitWidth: 620
       implicitHeight: 430
       focusTarget: null
       // UI + logic
   }
   ```

3. **Add `Settings.qml`**

   ```qml
   import QtQuick
   Item { implicitWidth: 500; implicitHeight: 400; /* settings UI */ }
   ```

4. **Add optional `Service.qml`**

   ```qml
   import qs.desktop.components
   Service {
       function start() { }
       function stop() { }
   }
   ```

5. **Register in config** — add `"<module-id>"` to a `blobs` array in `shell/config.json`.

6. **Restart shell** — `qs kill; qs -c shell/` or `pkill quickshell`. The registry discovers the new manifest automatically.

Refer to the `launcher` folder in this directory as the complete, accurate reference for a production module.

---

## Related

- **Registry:** `../lib/ModuleRegistry.qml` — discovers these manifests
- **Persistence:** `../lib/BlobManager.qml` — owns the `blobs` mapping
- **Lifecycle:** `../lib/ServiceManager.qml` — manages `Service.qml` instances
- **Hosts:** `../components/Blob.qml` — loads the main QML; `../components/ScreenFrame.qml` — creates the blobs
- **Config:** `../../config.json` — top-level blob assignments
- **Module QML API:** `../components/Module.qml` + `../components/Service.qml`
