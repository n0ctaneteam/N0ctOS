# `desktop` — N0ctOS Desktop Shell Layer

> **Path:** `shell/desktop/`  
> **Parent:** `shell/` (see `shell/README.md`)  
> **Type:** Desktop shell layer (frame + islands + plug-in system)

## What Is This Directory?

`desktop` is the desktop shell layer — the Quickshell-based UI that runs as `shell.qml` → `Desktop.qml`. It:

- Draws the full-screen frame ring with chamfered and rounded corners, animated blob islands, borders, and shadows (`components/ScreenFrame.qml`).
- Hosts 8 blob islands (`tr`, `tl`, `tc`, `br`, `bl`, `bc`, `left`, `right`) that morph the frame edge and host modules.
- Discovers and manages built-in modules under `modules/` (each a folder with `manifest.json`).
- Provides the control plane (`lib/`) that persists blob assignments, indexes modules, keeps services alive, and exposes IPC.

```
desktop/
  Desktop.qml              ← single ScreenFrame{} instance (configured frame: width 5, cut 30, cyan glow)
  components/              ← view layer: ScreenFrame, Blob, Module, Service + qmldir
  lib/                     ← control plane: ModuleRegistry, BlobManager, ServiceManager, BlobIPCHandler
  modules/                 ← plug-ins: built-in module folders (each with manifest.json)
```

`Desktop.qml` is intentionally minimal — it configures and places a single `ScreenFrame`. All behavior lives in `components/` + `lib/` + `modules/`.

---

## Children Directories

| Directory | Purpose | Key Files |
| :-------- | :------ | :-------- |
| **`components/`** | Reusable desktop building blocks: the frame, the per-blob container, and base types for modules and services. | `ScreenFrame.qml` (frame + geometry engine), `Blob.qml` (per-blob controller), `Module.qml` (module base), `Service.qml` (service base), `qmldir` |
| **`lib/`** | Control-plane singletons instantiated once inside `ScreenFrame`. No visual output; they manage discovery, persistence, lifecycle, and IPC. | `ModuleRegistry.qml`, `BlobManager.qml`, `ServiceManager.qml`, `BlobIPCHandler.qml` |
| **`modules/`** | Plug-in discovery root. Each child is a built-in module that follows the `manifest.json` contract. Structure is documented in `modules/README.md` using the canonical example. | Built-in module folders (`manifest.json` + module QML) |

---

## Files in This Directory

| File | Lines | Role |
| :--- | :---: | :--- |
| **`Desktop.qml`** | 44 | Entry point for the desktop layer. A `Scope` containing a single `ScreenFrame` configured with `frameLayer: WlrLayer.Bottom`, `frameWidth: 5`, `frameColor: "#01080c"`, `borderWidth: 2`, `borderColor: "#2acfff"`, `blobAnimationDuration: 200`, `cut: 30`, and cyan shadows. The only file `shell.qml` → `Desktop {}` instantiates. |

No other files sit at `desktop/` root; every feature is below `components/`, `lib/`, or `modules/`.

---

### `Desktop.qml` — The Configuration Anchor

```qml
import "components"
import "lib"
Scope {
  ScreenFrame {
    frameLayer: WlrLayer.Bottom
    frameWidth: 5
    frameColor: "#01080c"
    borderWidth: 2
    borderColor: "#2acfff"
    blobAnimationDuration: 200
    cut: 30
    shadows: { intensity:30, color:"#2acfff", blur:1.0, opacity:1 }
  }
}
```

`Desktop.qml` is declarative config, not logic. Adjusting `frameWidth`, `cut` vs `round`, `frameColor`, `shadows`, or `blobAnimationDuration` here propagates through the entire frame via the geometry engine. Per-monitor or state-dependent overrides would be added here.

---

## How the Pieces Fit (Runtime Data Flow)

```
┌──────────────────────────────────────────────────────────────────────┐
│  shell.qml  (ShellRoot)                                             │
│    └─ Desktop.qml  ──►  ScreenFrame.qml (components/)               │
│                          ├─ ModuleRegistry (lib/) ──► find manifests──► modules/*/manifest.json
│                          ├─ BlobManager    (lib/) ◄──► config.json (shell/ + state)
│                          ├─ ServiceManager (lib/) ──► Service.qml per selected module
│                          ├─ BlobIPCHandler (lib/) ──► QS IPC: n0ctos-blob
│                          └─ 8× Blob.qml (components/) ──► Loader{ <module>.qml (extends Module) }
└──────────────────────────────────────────────────────────────────────┘
         ▲
         │  core/ui (CutBox, Button) reused inside blob selector and modules
```

**Startup sequence inside `ScreenFrame`:**

1. Instantiate `ModuleRegistry`, `BlobManager`, `ServiceManager`, `BlobIPCHandler`, and a focus manager.
2. `ModuleRegistry.discoverModules()` → `find` → load each `manifest.json` → registry.
3. `BlobManager.loadConfig()` → `blobs` property; on parse error tries the fallback config path.
4. `ServiceManager` unions blob lists → `selectedModuleIds` → waits for registry → instantiates each `Service.qml`.
5. `ScreenFrame` creates `Blob { blobId, moduleRegistry, moduleIds: blobManager.blobs[blobId] }` for each position.

---

## Blob Positions & Configuration

Positions exposed by `ScreenFrame`, `BlobManager`, and `config.json`:

| ID | Meaning | Reservation? |
| :--- | :------ | :----------- |
| `tr` | Top-right corner island | ✅ |
| `tl` | Top-left corner island | ✅ |
| `tc` | Top-center edge island | ❌ |
| `br` | Bottom-right corner island | ❌ |
| `bl` | Bottom-left corner island | ❌ |
| `bc` | Bottom-center edge island | ❌ |
| `left` | Left edge vertical island | ❌ |
| `right` | Right edge vertical island | ❌ |

Reservation drives `exclusiveZone` on transparent `PanelWindow`s so the compositor keeps tiling away from decorated edges.

Example `shell/config.json`:

```json
{
  "blobs": {
    "br": ["<module-id>"],
    "bl": ["<module-id>", "<module-id>"],
    "bc": ["<module-id>"]
  },
  "blobSwitch": { "modifier": "Super", "next": "J", "previous": "K" }
}
```

See `modules/README.md` for the full module contract and creation guide, and `lib/README.md` for control-plane APIs.

---

## Related

- **Shell root:** `../README.md` — overall entry (`shell.qml`), config (`config.json`), and layer diagram
- **Visual primitives:** `../core/ui/README.md` — `CutBox`, `Button`, `Slider`, `Tabs` used by `Blob` and modules
- **Control plane:** `lib/README.md` — `ModuleRegistry`, `BlobManager`, `ServiceManager`, `BlobIPCHandler`
- **Building blocks:** `components/README.md` — `ScreenFrame`, `Blob`, `Module`, `Service` internals
- **Plug-ins:** `modules/README.md` — manifest structure and how modules are made
- **Entry:** `../shell.qml` — `ShellRoot { Desktop{} }`
- **Config:** `../config.json` — `blobs` and `blobSwitch` bindings

## Contributor Tips

- **Adding a module:** see `modules/README.md` (add folder + manifest, assign to a blob, restart).
- **Tweaking the frame:** edit `Desktop.qml` → `ScreenFrame` props (`frameWidth`, `cut`/`round`, `frameColor`, `shadows`, `blobAnimationDuration`).
- **Debugging:** `qs -d` shows verbose logs from `lib/` and `Blob.qml`; filter with `grep "\[ModuleRegistry\]\|\[BlobManager\]\|\[Blob\]"`.
