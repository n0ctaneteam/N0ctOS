# `core/ui` — Core Visual Primitives

> **Path:** `shell/core/ui/`  
> **Parent:** `shell/core/`  
> **Type:** Reusable QML UI toolkit (no desktop dependencies)

## What Is This Directory?

`core/ui` is the **design-system layer** of N0ctOS. It provides four high-quality, heavily documented QML primitives that every other layer (desktop blobs, modules, panels, future settings) builds upon. Unlike `desktop/components` (which are desktop-specific), these components are generic, theme-agnostic, and have no dependency on `ModuleRegistry` or `BlobManager`.

The crown jewel is `CutBox.qml` (~2,200 lines): a shape with chamfered/rounded corners, configurable borders, outer/inner shadows, and interaction signals — the visual atom of the entire shell.

---

## Children Directories

**None.** Flat collection of 5 QML files + module declaration.

---

## Files in This Directory

| File | Lines | Role |
| :--- | :---: | :--- |
| **`CutBox.qml`** | ~2234 | **Core shape primitive.** Renders a rectangle with per-corner `cut` (chamfer) or `round` (fillet), border segments with glow, outer/inner shadows, and interaction (`clicked`, `scroll`, `pressed`, etc.). All other components delegate rendering to it. |
| **`Button.qml`** | 442 | **Styled button.** Preset-driven wrapper around `CutBox` + centered `Text`. Resolves 5 `Style` enums (`Default`, `CutGlow`, `Rounded`, `Outline`, `Flat`) into `CutBox` props with priority: explicit prop > `button:{}` > active preset > base preset. |
| **`Slider.qml`** | ~2230 | **Rich slider.** Horizontal/vertical, range/step/clamp, drag/touch/scroll/hold-to-repeat, gradient fill, masked fill geometry, `CutBox` bar + control. |
| **`Tabs.qml`** | 666 | **Tab container.** Row of `Button` tabs + underline + dual-`Loader` slide transition + scroll-to-switch. Content set via `tabs: [{label, content: Component{}}]`. |
| **`qmldir`** | 6 | Declares `module qs.core.ui` → maps `Button`, `CutBox`, `Slider`, `Tabs` for `import qs.core.ui`. |
| **`ScreenFrame copy.qml`** | — | Historical duplicate. Not part of the documented shell — see filesystem directly if needed. |

---

### `CutBox.qml` — The Atom (Deep Dive)

#### Public API

```qml
property var cut: ({})        // { topLeft:12, topRight:8, ... }  chamfer size per corner
property var round: ({})      // { topLeft:10, ... } fillet radius; overrides cut
property color bgColor
property int borderWidth
property color borderColor
property int borderGlow       // glow blur intensity (via MultiEffect)
property var disableBorder    // string | array | object  e.g. "top" or { top:true }
property var shadow: ({       // { out:{color,intensity,opacity}, in:{...} }
  out:{ color:"#00eaff", intensity:18, opacity:0.5 },
  in: { color:"#fff", intensity:12, opacity:0.35 }
})
property int animationDuration: 180  // color/glow/shadow transitions
default property alias contentData: content.data
```

**Signals**

`clicked(mouse)`, `rightClicked(mouse)`, `doubleClicked(mouse)`, `hovered()`, `exited()`, `pressed(mouse)`, `released(mouse)`, `scroll(int)`, `positionChanged(mouse)`.

**Corner Model**

- `hasCut(corner)` / `hasRound(corner)` / `cornerType(corner) -> "cut"|"round"|"none"` (round wins).
- `cornerSize(corner)` → clamped non-negative number.
- `geometry()` → `{tl,tr,br,bl}` each clamped to `width/2` / `height/2`, with sibling-shrink if `tl+tr>width` etc.
- `cornerTransition(corner, g)` → SVG snippet (`L` for cut, `A` arc for round) used by border path.
- `ownsCorner(side, corner)` — a corner belongs to exactly one active side (priority order prevents double-draw when `disableBorder` disables adjacent side).
- `borderPath(side)` → SVG path for that side’s border alone (important for inner shadow source).
- `makePath(offsetX, offsetY)` → full closed SVG path (`M ... L ... A ... Z`) for main shape.
- `makeExpandedPath(pad)` → same shape grown outward by `pad` for shadow sources.

**Rendering Stack (bottom → top)**

1. `outerShadow` — `Shape{ ShapePath fill:bgColor }` with `MultiEffect { shadowEnabled: shadow.out.* }`.
2. `shape` — main `Shape` with `ShapePath fill:bgColor` + `PathSvg path: makePath()`.
3. `innerShadow` — invisible 1 px border `innerShadowSource` (`Shape` 4 `ShapePath` stroke `#fff` per side via `borderPath`) → `MultiEffect { shadowEnabled: shadow.in.* }` masked by `shape`.
4. `borderGlowShape` — 4 `ShapePath` strokes (`borderWidth`, `borderColor`) per side, `MultiEffect` blurred by `borderGlow`.
5. `content` Item (default property) overlays.

**Interaction**

Single `MouseArea` + `HoverHandler` per instance, respecting `interactive` flag and `scrollThreshold` rate limiting. Hover state drives no visual change directly — parent (e.g., `Button`) decides.

---

### `Button.qml` — Preset-Driven Button

```qml
enum Style { Default, CutGlow, Rounded, Outline, Flat }
property string text
property var textColor, fontPixelSize
property int padding: 12
property bool active             // highlights with style's active preset
property int style
property var button: ({})        // complete config object (lower priority than explicit props)
property var cut, round, bgColor, borderWidth, borderColor, borderGlow, shadow
```

**Style Table (`_styles[5]`)**

| Style | Shape | Colors | Usage |
| :--- | :---- | :----- | :---- |
| `Default` | `round 10` | `#10151d` bg, `#2a3342` border | General panel buttons |
| `CutGlow` | `cut 12` | `#081018` bg, cyan `#00eaff` borderGlow 14, outer+inner cyan shadow | Primary / tabs active |
| `Rounded` | `round 22` | `#14101f` bg, purple `#7c5cff` | Accent / rounded chips |
| `Outline` | `round 8` | transparent bg, `#5a6b7c` border | Ghost buttons |
| `Flat` | `round 6` | `#0c1118` bg, no border | Dense lists |

Each entry has optional `active: { bgColor, borderColor, borderGlow, textColor, shadow }`.

**Resolution (`_from(key)`)**

```
explicit prop  →  button[key]  →  active preset  →  base preset  →  CutBox default
```

**Composition**

```qml
CutBox { cut: _resolvedCut; round: _resolvedRound; bgColor: _resolvedBg; ... 
  onClicked: root.clicked(mouse) // etc.
}
Text { text: root.text; color: _resolvedTextColor }  // centered
implicitWidth: label.implicitWidth + padding*2
```

Signals forwarded: `clicked`, `hovered`, `exited`, `pressed`, `released` (scroll intentionally not forwarded).

---

### `Slider.qml` — Full-Featured Slider

**Configuration**

```qml
property string orientation: "horizontal" | "vertical"
property var range: { min:0, max:100, default:50, step:1 }
property real value                // clamped, stepped, rounded to 2dp
property var formatValue: v => v+"%"   // + numeric 2dp enforcement
property bool interactive: true
property bool btnsEnabled: false    // show +/- buttons
property var bar: { background, border:{color,width,glow}, fill:[colors] }  // gradient array
property var button: {}   // mapped into +/- Button.qml
property var control: { bgColor, borderColor, borderWidth, borderGlow, textColor }
property int animationDuration: 140
```

**Geometry**

- `barThickness = root.(height|width)*0.5`
- `barLength = root.(width|height) - 2*buttonSize -2*spacing` (0 when `!btnsEnabled`)
- `controlWidth/Height` swapped for orientation.
- `controlX/Y` = `bar + normalizedValue * controlTravel`.
- `fillLength` = distance from bar start to control center (masked gradient length).

**Value Logic**

`setValue(next)` clamps to `[min,max]` (swapping if `max<min`), snaps to `step`, rounds to 2 decimals, only assigns if `|delta|>1e-6` (prevents jitter). `normalizedValue = clamp((value-min)/(max-min))`.

**Interaction**

- **Bar drag:** `_beginBarDrag` / `_dragBar` → `_valueFromMouse` (maps mouse to item local to `barBox`, computes t via `controlTravel`).
- **Control drag:** `_beginControlDrag` stores `dragOffset`, `_dragControl` uses `controlBox.mapToItem(barBox, ...)`.
- **Scroll:** `_scrollValue(step*scrollStrength)` via `CutBox.onScroll`.
- **Buttons:** `_buttonPressed(dir)` → immediate `_buttonStep(dir)` then hold `Timer threshold(1000ms) → repeat(200ms)`.
- `_stopInteraction()` clears all drag/hold states; triggered on `interactive` → false.

**Visuals**

- `barBox: CutBox` (cut `topLeft` + `bottomRight` chamfer, `bgColor` from `_barBackground`, border via `_bar*` helpers).
- `fillLayer` → invisible `gradientSource` (two rects with `Gradient.Horizontal/Vertical` 3-stop gradient from `bar.fill[]` colors) masked by `fillMask` (white `Shape` hexagon path via `fillLength`) through `MultiEffect { maskEnabled:true, maskSource:fillMask }`.
- `controlBox: CutBox` (asymmetrical chamfer, `bgColor`/`border*` from `_control*`), centered `Text { text: _formattedValue(), rotation: vertical?-90:0 }` with `fontSizeOverride` max + `Text.Fit`.

---

### `Tabs.qml` — Tab Switcher

**API**

```qml
property var tabs: [{ label:"Overview", content: Component{...} }]
property int currentIndex
property var tabStyle: Button.Style.Default | { style:..., cut:..., ... }
property int barHeight:44, buttonSpacing:8, buttonInset:6, contentPadding:12, contentGap:8
property bool barLineVisible; color barLineColor; int barLineHeight
property int slideDuration:300, slideFadeDuration:260, scrollThreshold:500
property var cut, round, bgColor, borderWidth, borderColor, borderGlow, shadow  // container CutBox props
signal tabActivated(int index)
```

**Composition**

- `container: CutBox` fills parent (`bgColor #070b10`, borderGlow 8), scroll → `_switchOnScroll`.
- `bar: Item (height: barHeight)` → `Row { Repeater model: tabs → Button { text: label, active: index==currentIndex, width = (rowWidth - spacing*(n-1))/n; onClicked: switchTo(index) } }`.
- `barScroll: MouseArea (NoButton)` overlay captures wheel over buttons (otherwise buttons would eat wheel). Rate-limited via `lastScrollTime`.
- `barLine: Rectangle` underline.
- `contentArea: Item (clip)` → two `Loader`s (`contentA`, `contentB`) with `Behavior on x/opacity`; `_present(direction)` alternates show/hide loaders, sliding incoming from `+width`/`-width`, outgoing opposite, `Timer (slideDuration+40)` cleans old loader.

**Navigation**

`switchTo(index)` wraps around; `_switchOnScroll(step)` maps `+1 (up) → previous`, `-1 (down) → next`.

**Styling**

`_applyTabStyle(btn)` spreads `tabStyle` object onto each `Button` or sets `btn.style`. Reacts to `tabStyleChanged`.

---

### `qmldir`

- `qmldir` enables `import qs.core.ui`. Must be in QML import path; Quickshell sets this via `QML_IMPORT_PATH=/usr/share/N0ctOS/shell`.

---

## Usage Cheat Sheet

```qml
import qs.core.ui

CutBox {
  cut: { topLeft: 12, bottomRight: 8 }
  round: { topRight: 10 }
  bgColor: "#10151d"
  borderWidth: 1
  borderColor: "#2acfff"
  borderGlow: 12
  shadow: { out:{ color:"#00eaff", intensity:18, opacity:0.5 } }
  Text { text:"Hello" }
}

Button {
  text: "Launch"
  style: Button.Style.CutGlow
  onClicked: console.log("go")
}

Slider {
  orientation: "horizontal"
  range: { min:0, max:100, default:50, step:1 }
  bar: { fill: ["#00eaff", "#7c5cff"] }
  onValueChanged: console.log(value)
}

Tabs {
  tabs: [
    { label:"A", content: Component{ Text{text:"Pane A"} } },
    { label:"B", content: Component{ Text{text:"Pane B"} } }
  ]
}
```

---

## Related

- **Parent:** `../README.md` — all of `shell/core`
- **Consumers:** `../../desktop/components/Blob.qml`, internal `Tabs.qml` composition, and module components
- **Sibling:** `../lib/README.md` — currently empty (`core/lib` is reserved, no files yet)
- **Desktop host:** `../../desktop/components/ScreenFrame.qml` → desktop frame that pulls `core/ui` primitives

