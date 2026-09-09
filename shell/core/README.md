# `core` — Shell Core Toolkit

> **Path:** `shell/core/`  
> **Parent:** `shell/` (the shell root, see `shell/README.md`)  
> **Type:** Framework layer (reusable, desktop-agnostic)

## What Is This Directory?

`core` is the **foundation layer** of the N0ctOS Quickshell desktop shell. It holds primitives and (reserved) utilities that are deliberately **agnostic of the desktop concept** — they know nothing about blobs, modules, or window management. The desktop layer (`desktop/`) depends *on* `core`, never the reverse. This separation keeps the visual system reusable for future panels, overlays, lock screens, or notification toasts without duplication.

Currently `core` contributes:

- **`core/ui`** — a complete visual design system (`CutBox`, `Button`, `Slider`, `Tabs`) with shadows, borders, per-corner cut/round, and polished interaction. It is the only populated subtree.
- **`core/lib`** — a *reserved* empty placeholder for future non-visual helpers (theme tokens, pure-JS utilities, config wrappers).

```
shell/
  core/
    ui/   ← visual primitives  (CutBox, Button, Slider, Tabs)   ACTIVE
    lib/  ← non-visual helpers (reserved empty)                PLACEHOLDER
  desktop/
    components/  → uses core/ui
    lib/         → uses core (future) + Quickshell.Io
    modules/     → uses core/ui + desktop/components
```

---

## Children Directories

| Directory | Status | Purpose | External Docs |
| :-------- | :----- | :------ | :------------ |
| **`ui/`** | ✅ Active | Visual primitives: `CutBox`, `Button`, `Slider`, `Tabs` + `qmldir` (`qs.core.ui`). Heavily documented (~5,000+ lines). | See `ui/README.md` for deep API docs |
| **`lib/`** | ⏳ Reserved | Future non-visual utilities: color tokens, `clamp`/`round2` helpers, typed config wrapper, icon resolver. Currently empty by design. | See `lib/README.md` |

---

## Files in This Directory

**None at the top level.** This container directory exists solely to group `ui/` and `lib/`. The only artifacts are the README files inside each child and the `qmldir` within `ui/`.

An explicit top-level `qmldir` is **not** created here — submodules are imported separately:

```qml
import qs.core.ui   // from core/ui/qmldir
// import qs.core.lib // will exist when lib/ is populated
```

---

## Design Principles

1. **No desktop dependency.** Files in `core/` must never `import qs.desktop.*` or reference `blobId`, `moduleId`, `ModuleRegistry`, etc. Desktop concepts belong in `desktop/`.

2. **Self-contained visuals.** `CutBox` is the single source of truth for geometry (svg path, corner math) and effects (shadows, border glow). `Button`, `Slider`, `Tabs` compose it rather than re-implementing shape logic.

3. **Composable by `default property alias`.** `CutBox` exposes `default property alias contentData: content.data`, so callers can nest children directly:

   ```qml
   CutBox { Text { text: "Hi" } }
   ```

4. **Animation-aware.** Every color/border/shadow property animates via `animationDuration` and `Behavior`/`Easing.OutCubic`, so toggles (active/hover) interpolate rather than snap.

5. **Reserved lib.** `core/lib` is empty today to signal that non-visual extraction is pending but planned. Proposals should start there — not by adding helpers ad-hoc inside `ui/`.

---

## When To Put Code Here vs `desktop/`

| Question | Put in `core/` | Put in `desktop/` |
| :------- | :------------- | :---------------- |
| Is it reusable for a lock screen, panel, or notification? | ✅ | |
| Does it import `Quickshell.Wayland` / `PanelWindow`? | | ✅ |
| Does it read `manifest.json` or `config.json` blobs? | | ✅ |
| Is it a pure shape/button/slider? | ✅ | |
| Is it `Blob.qml`, `ScreenFrame.qml`, or a module? | | ✅ |

Rule of thumb: **if it mentions `blob` or `module`, it belongs in `desktop/`.**

---

## Related

- **Visual primitives:** `ui/README.md` — full API for `CutBox`, `Button`, `Slider`, `Tabs`
- **Reserved helpers:** `lib/README.md` — future `Theme.qml`, `MathUtils.qml`, etc.
- **Consumer:** `../desktop/components/` — `Blob.qml` and module UIs compose `core/ui` components
- **Shell root:** `../README.md` — overall architecture and config (`shell/config.json`)
- **Example usage:**
  ```qml
  import qs.core.ui
  CutBox { cut:{ topLeft:12 } bgColor:"#10151d"; Text{text:"core example"} }
  ```

> **Roadmap:** The next item for `core/lib` is likely a token singleton (e.g., `Tokens.qml`) that centralizes radii, glow intensities, and palette colors now hardcoded across `CutBox` presets and `Button` styles. See `lib/README.md` for the tracking list.

