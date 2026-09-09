# `desktop/components` — Reusable Desktop Building Blocks

> **Path:** `shell/desktop/components/`  
> **Parent:** `shell/desktop/`  
> **Type:** QML component library (instantiated by the desktop shell)

## What Is This Directory?

`desktop/components` provides the **primitive QML types** that compose the N0ctOS desktop experience: the frame that draws the animated border + blob islands (`ScreenFrame`), the per-blob container (`Blob`), the base class for all modules (`Module`), and the base class for persistent services (`Service`). Together with `desktop/lib` (control-plane) and `core/ui` (visual primitives like `CutBox`), this folder is the *view layer* of the desktop shell.

`desktop/Desktop.qml` merely configures and places a single `ScreenFrame`; all visual behavior lives here.

---

## Children Directories

**None.** Flat set of 5 QML components + a `qmldir` module declaration.

---

## Files in This Directory

| File | Lines | Kind | Summary |
| :--- | :---: | :--- | :------ |
| **`ScreenFrame.qml`** | ~2380 (actual) | `Scope` (root `PanelWindow`) | **The desktop frame.** Draws the full-screen border ring with holes, 8 animating blob islands, corner cut/round math, reservation windows, shadows, and instantiates `Blob` per position. Owns all `desktop/lib` singletons. |
| **`Blob.qml`** | 1200 | `FocusScope` | **Per-blob container.** Handles module selection, focus management, switching (Super+J/K), hover enter/leave, mouse selector, keyboard shortcuts, and dynamic `Loader` for the active module. |
| **`Module.qml`** | 78 | `FocusScope` | **Base class for every module.** Provides `moduleId`, `focusTarget`, variant loading, and `activate`/`deactivate` + focus delegation. |
| **`Service.qml`** | 16 | `QtObject` | **Base class for per-module background services.** Minimal `moduleId`/`moduleInfo`/`serviceManager` + `start()`/`stop()` hooks overridden by `desktop/modules/*/Service.qml`. |
| **`qmldir`** | 6 | Module map | Declares `module qs.desktop.components` and maps `Blob`, `Module`, `Service`, `ScreenFrame` to their files for `import qs.desktop.components`. |

---

### `ScreenFrame.qml` — The Frame & Blob Host

**Inheritance:** `Scope` → creates multiple `PanelWindow`s (frame + 4 reservation windows + layer management).

**Public API (selected)**

```qml
property var frameWidth: 5
property var cut: 30          // or { topLeft: 12, ... }
property var round: {}        // overrides cut if present
property color frameColor: "#01080c"
property int borderWidth: 2
property color borderColor: "#2acfff"
property var shadows: { intensity, color, blur, opacity }
property real blobWidth: 300
property real blobHeight: 100
property real blobAnimationDuration: 3000
property var blobAnimationEasing: Easing.InOutExpo
```

**Blob State (repeated 8×, one per position)**

Positions: `br` (bottom-right), `bc` (bottom-center), `bl` (bottom-left), `tr`, `tc`, `tl`, `left`, `right`.

For each:
- `is*BlobActive` (readonly, `blob.isBlobFocused || blob.hovered`)
- `*BlobProgress: 0→1` (driven by `Behavior on *BlobProgress { NumberAnimation duration: blobAnimationDuration }`)
- `is*BlobAlwaysActive`, `is*BlobOpened`, `should*BlobReserveSpace`
- Signals `hovered*Blob` / `exited*Blob` → delegated to `Blob.enterHover()` / `leaveHover()`

**Singletons owned**

```qml
ModuleRegistry { searchPaths: [shellPath("desktop/modules")] }
BlobManager    { configPaths: [shellPath("config.json"), statePath("config.json")] }
ServiceManager { moduleRegistry: moduleRegistry }
BlobIPCHandler { blobManager: blobManager, blobs: { tr: trBlobContent, ... } }
focusManager   { property var focusedBlob }
```

Each blob is a `Blob.qml` instance with `moduleIds` bound to `blobManager.blobs[blobId]` and `moduleRegistry` injected.

**Geometry Engine**

- `sideValue(value, side)` / `frameSide(side)` — normalizes `frameWidth` scalar vs object.
- `cornerExists / cornerType / cornerSize` — `round` overrides `cut`.
- `innerGeometry()` — computes inset rect `(x, y, width, height, tl/tr/br/bl)` with overlap prevention.
- `innerPath()` — builds SVG path string for the *hole* in the frame, including per-blob bulges (`brBlobProgress` etc.) with `l` / `a` arc commands, blob-size-aware corner radii.
- `framePath()` — `outerRect + " " + innerPath()` with `OddEvenFill` to create ring.
- `borderPath()` (Top/Right/Bottom/Left) variants for border-only glow.

**Reservation Windows**

Four transparent `PanelWindow`s (`topReservation`, `bottomReservation`, `leftReservation`, `rightReservation`) with `exclusiveZone` equal to frame thickness (or blob height for top), telling Hyprland/compositor to keep tiled windows away from decorated edges.

**Visual Layers**

- `frameShape` (`Shape` + `ShapePath` fill `#101820` or configured `frameColor`, `OddEvenFill`, `MultiEffect` shadow).
- `innerBorder` (optional stroke `borderWidth`/`borderColor` following `innerPath()`).
- Hover `MouseArea`s per edge/corner (expand when blob progressed, include side extensions).



---

### `Blob.qml` — Per-Blob Controller (1200 lines)

**Properties**

```qml
required property string blobId
required property var moduleRegistry
required property var moduleIds           // from BlobManager
property string activeModule, selectionModule
property bool blobFocused, hovered
readonly bool isBlobFocused, moduleSpecified, showHoverSelector, selectorOpen, showSelector
property bool switching, mouseSelector, modifierHeld, switchImmediate
property bool isVertical
property real switcherSize: 56
property int animationDuration: 180
property string switchModifierName: "Super"  // resolved via FileView to blobSwitch.modifier
```

**Key Methods**

| Method | Description |
| :--- | :---------- |
| `enterHover()` / `leaveHover()` | Open/close hover selector (only when not already `moduleSpecified`). |
| `focusBlob()` | Claim logical focus, steal from previous `focusManager.focusedBlob`, `forceActiveFocus()`, then `focusModule()`. |
| `closeBlob()` | Reset all flags, deactivate current module, clear `Loader`. |
| `activateModule(id)` | Validate `moduleIds`, get `registry.get(id)`, deactivate previous `item`, set `Loader.source = info.modulePath`. |
| `openModule(id)` | `activateModule` + `focusBlob`. |
| `toggleModule(id)` / `deactivateModule(id)` | Toggle lifecycle. |
| `beginSwitch()` / `cycle(dir)` / `commitSwitch()` / `cancelSwitch()` | Keyboard-driven switcher (Super + J/K by default). |
| `openMouseSelector()` / `mouseSelect(id)` | Right-click selector. |
| `focusModule()` / `focusInsideBlob(backward)` / `rebuildFocusChain()` | Tab navigation inside module. |

**Loader**

```qml
Loader {
  source: activeInfo ? activeInfo.modulePath : ""
  onLoaded: { item.moduleId = activeModule; item.activate?.(); rebuildFocusChain() }
}
```

`implicitWidth/Height` driven by `moduleWidth/moduleHeight` or switcher size, with `Behavior OutCubic`.

**Selector UI**

- Horizontal `Row` (default) or vertical `Column` of `CutBox` delegates per `moduleIds`, highlighting `selectionModule` in cyan `#2acfff`.
- `Repeater model: moduleIds` → `CutBox { bgColor: selected ? switcherActiveBG : transparent }` + centered Nerd Font `icon` + `MouseArea` → `mouseSelect`.
- Overlaid `FocusScope selector` with margins 5, visible when `showSelector || switching || mouseSelector`.

**Input**

- `Shortcut { sequence: switchModifierName+"+J" }` → `cycleNext()`, similarly `K`.
- `Tab` / `Shift+Tab` shortcuts → `focusInsideBlob`.
- `Escape` cancels switch.
- `Keys.onReleased` commits switch when modifier released.
- `TapHandler` (Left) → `focusBlob()`, `MouseArea` (Right) → `openMouseSelector()`.
- `FileView { path: configPath }` → `applyKeybindConfig` parsing `blobSwitch { modifier, next, previous }`.

---

### `Module.qml` — Module Base Class

```qml
FocusScope {
  property string moduleId
  property Item focusTarget      // where focus goes on activate
  property var variant           // dynamic variant slot
  signal activated, deactivated
  function focusModule() { focusTarget?.forceActiveFocus() ?? forceActiveFocus() }
  function activate() { activated(); callLater(focusModule) }
  function deactivate() { deactivated() }
  function loadVariant(value, component)
}
```

- `parentBlob` computed by walking parent chain looking for `blobId` property (to detect vertical blobs).
- `implicitWidth/Height` sourced from `variantLoader.item` or `childrenRect`.
- Example: `Module { moduleId: "<module-id>"; focusTarget: searchField }` — see the canonical module structure in `../modules/README.md`.

---

### `Service.qml` — Service Base

```qml
QtObject {
  required property string moduleId
  required property var moduleInfo
  required property var serviceManager
  function start() { console.log("started") }
  function stop()  { console.log("stopped") }
}
```

Created once per selected module by `ServiceManager`. Override `start/stop` to add watchers, timers, DBus. Keep it lightweight; visual work belongs in the `Module`.

---

### `qmldir`

```
module qs.desktop.components
Blob Blob.qml
Module Module.qml
Service Service.qml
ScreenFrame ScreenFrame.qml
```

Enables:

```qml
import qs.desktop.components
Blob { } // or Module { } / Service { }
```

Requires `QML_IMPORT_PATH` to include `shell/`, configured by Quickshell's `shellPath` helper.

---

## Visual Stack

```
core/ui (CutBox, Button)  ← used by Blob selector + Modules
        ↓
desktop/components (Module, Service, Blob, ScreenFrame)
        ↓
desktop/lib (ModuleRegistry, BlobManager, ServiceManager, BlobIPCHandler) ← data / lifecycle
        ↓
desktop/Desktop.qml ← single ScreenFrame { frameWidth:5, cut:30, ... }
```

---

## Related

- **Config:** `../../config.json` / `../lib/BlobManager.qml`
- **Discovery:** `../lib/ModuleRegistry.qml` → `../modules/*/manifest.json`
- **Host:** `../Desktop.qml` — instantiates `ScreenFrame`
- **Modules:** `../modules/README.md` — manifest structure and creation guide
- **Primitives:** `../../core/ui/README.md` — `CutBox`, `Button`, `Tabs`, `Slider`

