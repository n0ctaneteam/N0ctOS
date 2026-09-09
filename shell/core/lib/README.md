# `core/lib` — Reserved Core Library

> **Path:** `shell/core/lib/`  
> **Parent:** `shell/core/`  
> **Type:** Reserved placeholder (currently empty)

## What Is This Directory?

`core/lib` is an **intentionally empty, reserved directory** for future *core* (desktop-agnostic) QML singletons and helpers.

- **`core/ui`** holds *visual* primitives (`CutBox`, `Button`, `Slider`, `Tabs`).
- **`core/lib`** is earmarked for *non-visual* core utilities — pure logic that any layer (desktop, panels, overlays) could import without pulling in desktop-specific code.

It exists now as a **structural placeholder** so imports like `import qs.core.lib` can be added later without breaking the `qmldir` module map or requiring a shell layout migration.

---

## Children Directories

**None.**

---

## Files in This Directory

**None** — the directory is empty on the current branch (`development`). An empty directory is committed via a tracking placeholder in git (if present) but contains no runtime files.

No `qmldir` exists here yet; it will be added when the first utility is introduced.

---

## Intended Future Contents

Planned candidates (not yet implemented):

| Potential File | Purpose |
| :--- | :------ |
| `Theme.qml` / `Colors.qml` | Centralized design tokens (colors, radii, animation durations) shared by `core/ui` and `desktop` |
| `MathUtils.qml` / `StringUtils.qml` | Pure JS helpers currently duplicated inside `CutBox` / `Slider` (e.g., `clamp`, `round2`) |
| `Config.qml` | Typed wrapper around `FileView`/`JSON.parse` for `config.json` / state, replacing ad-hoc parsing in `desktop/lib` |
| `IconResolver.qml` | Nerd Font / icon theme lookup, replacing per-module hardcoded glyphs |

---

## How To Add Your First Utility

1. Create `shell/core/lib/MyHelper.qml` (e.g., `pragma Singleton` if stateless).
2. Create `shell/core/lib/qmldir` with:

   ```
   module qs.core.lib
   MyHelper MyHelper.qml
   ```

3. Ensure `QML_IMPORT_PATH` includes `shell/` (Quickshell does by default via `shellPath`).
4. Import elsewhere:

   ```qml
   import qs.core.lib
   MyHelper { ... }
   ```

Keep `core/lib` dependency-free: it must **not** import `desktop/*` — the dependency arrow is `desktop → core`, never the reverse.

---

## Related

- **Sibling:** `../ui/README.md` — visual primitives that will eventually consume tokens/helpers from this folder
- **Desktop counterpart:** `../../desktop/lib/README.md` — desktop-specific singletons (`ModuleRegistry`, `BlobManager`, etc.)
- **Shell root:** `../../README.md` — overall shell architecture

> **Status:** Empty by design. Not a bug — it signals that core non-visual extraction has not yet been prioritized. Feel free to propose the first utility via a PR.

