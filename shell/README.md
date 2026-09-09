# `shell` — N0ctOS Quickshell Desktop Shell

> **Path:** `shell/` — documentation root (`/usr/share/N0ctOS/shell`)  
> **Runtime:** [Quickshell](https://quickshell.outfoxxed.me/) (Qt 6 + QML) on Hyprland/Wayland  
> **Entry point:** `shell.qml` → `desktop/Desktop.qml` → `desktop/components/ScreenFrame.qml`

## What Is This Directory?

`sell` is the complete N0ctOS desktop shell — a Quickshell-powered frame with animating blob islands that host plug-in modules. Every visual and behavioral aspect is declarative QML with `Quickshell.Io` (`FileView`, `Process`, `IpcHandler`) for persistence, discovery, and IPC. Configuration lives in `shell/config.json` (skeleton) mirrored to `~/.config/N0ctOS/config.json` (user state) via `desktop/lib/BlobManager.qml`.

```text
shell/
  shell.qml              ← ShellRoot { Desktop{} }
  config.json            ← skeleton: blobs + blobSwitch keybind
  core/                  ← reusable, desktop-agnostic toolkit
  desktop/               ← desktop layer (frame + blobs + modules)
```

Quickshell is launched as `quickshell -c /usr/share/N0ctOS/shell` (or via Hyprland `exec-once`). `shell.qml` is the only file the compositor looks for as entry; everything else is imported.

---

## Children Directories

| Directory | Type | Purpose | README |
| :-------- | :--- | :------ | :----- |
| **`core/`** | Framework layer | Desktop-agnostic primitives and reserved helpers. Does not import desktop. | `core/README.md` |
| `core/ui/` | Active | Visual design system: `CutBox` (shape atom), `Button` (presets), `Slider`, `Tabs`. Used by every blob and module. | `core/ui/README.md` |
| `core/lib/` | Placeholder | Reserved for future token and utility singletons. Keeps import path `qs.core.lib` stable. | `core/lib/README.md` |
| **`desktop/`** | Desktop layer | Frame, blob islands, and plug-in system. Depends on `core/ui`. | `desktop/README.md` |
| `desktop/components/` | View | `ScreenFrame.qml` (frame and geometry engine), `Blob.qml` (per-blob controller), `Module.qml` and `Service.qml` base types, `qmldir`. | `desktop/components/README.md` |
| `desktop/lib/` | Control plane | Singletons inside `ScreenFrame`: `ModuleRegistry`, `BlobManager`, `ServiceManager`, `BlobIPCHandler`. | `desktop/lib/README.md` |
| `desktop/modules/` | Plug-ins | Discovery root. Each subfolder is a built-in module that follows the `manifest.json` contract. Canonical example is documented in `desktop/modules/README.md`. | `desktop/modules/README.md` |

**Dependency is strictly `desktop → core`**; `core` never imports `desktop`. This keeps the visual toolkit reusable for panels, overlays, or lock screens.

---

## Files in This Directory

| File | Lines | Role |
| :--- | :---: | :--- |
| **`shell.qml`** | 11 | Quickshell entry. `import "desktop/lib"; import "desktop"; ShellRoot { Desktop{} }`. Mounts the desktop layer. For multi-screen or conditional shells, branch here. |
| **`config.json`** | 27 | Skeleton config. Persisted via `BlobManager` to `~/.config/N0ctOS/config.json` (`Quickshell.statePath`). Contains `theme.name`, `blobs` (mapping of blob position to `string[]` of module IDs), `blobSwitch` keybind, and placeholder `otherStuff`. Copied on first run if user config is missing. |

---

## Architecture — How the Shell Fits Together

```
Quickshell  ──►  shell.qml (ShellRoot)
                   └─► desktop/Desktop.qml  (Scope { ScreenFrame{ cut, frameWidth, border, shadows } })
                         └─► desktop/components/ScreenFrame.qml
                               ├─ core/ui (CutBox, Button)  ← reused in selector and modules
                               ├─ desktop/lib/ModuleRegistry  ──┐
                               ├─ desktop/lib/BlobManager       ├─► control plane (no visuals)
                               ├─ desktop/lib/ServiceManager    │
                               ├─ desktop/lib/BlobIPCHandler  ──┘
                               └─ 8× desktop/components/Blob.qml
                                     └─► Loader → desktop/modules/<module-id>/<Module>.qml (extends Module.qml)
                                            └─► desktop/components/Service.qml (if manifest.service)

Local System Wide ──► /usr/share/N0ctOS/local/[shell.json , /plugins]

Local User config ──► ~/.config/N0ctOS/[shell.json , /plugins]
```

**Invariants:**

- The canonical frame lives in `desktop/components/ScreenFrame.qml`.
- `core/lib` is intentionally empty today; do not add desktop logic there.
- Configuration flows only through `BlobManager` (`config.json` → `blobs`); direct `FileView` usage elsewhere should reuse it.

See `desktop/README.md` for the runtime startup sequence and `core/README.md` for layering rationale.

---

## Running & Developing

**Run (from installed path)**

```bash
quickshell -c /usr/share/N0ctOS/shell
# or Hyprland exec-once: exec-once = quickshell -c /usr/share/N0ctOS/shell
```

**Develop**

```bash
# edit a module (canonical example)
$EDITOR shell/desktop/modules/<module-id>/<Module>.qml   # e.g. launcher/Launcher.qml
# restart shell
qs kill; qs -c shell/   # QS = quickshell
# watch logs
qs -d -c shell/ 2>&1 | grep -E "\[ModuleRegistry\]|\[BlobManager\]|\[Blob\]"
```

**IPC**

```bash
qs ipc call n0ctos-blob activate <module-id>
qs ipc call n0ctos-blob toggle <module-id>
qs ipc call n0ctos-blob focus <blob-id>
```

**Add a module**

1. Create `desktop/modules/<module-id>/` with `manifest.json` + `<Module>.qml` + `Settings.qml` (`Service.qml` optional).
2. Add `"<module-id>"` to a `blobs` array in `config.json`.
3. Restart the shell — `ModuleRegistry` discovers the manifest automatically.

Full contract and walkthrough in `desktop/modules/README.md`.

---

## File-Count & Depth Summary

- **Total QML files in shell:** Core UI primitives, desktop frame and blob controllers, control-plane singletons, and built-in module components.
- **Deepest leaves:** `desktop/modules/<module-id>/` (depth 3 from `shell/`).
- **READMEs:** One per directory in `shell/` plus this file; leaf module folders rely on the structure documented in `desktop/modules/README.md`.

---

## Related & Next Steps

- **Start here:** `desktop/README.md` → `desktop/components/README.md` + `desktop/lib/README.md` for frame and registry internals
- **UI toolkit:** `core/ui/README.md` — `CutBox` and `Button` API
- **Modules:** `desktop/modules/README.md` — manifest structure and how modules are made (canonical `launcher` example)
- **Config shape:** `config.json` + `desktop/lib/BlobManager.qml`

---

> **Structure:** Every README in this tree follows the same layout: *what the directory is → what each child contains → what each file does → additional context as needed*. See `AGENT.md` for the authoring guide.
