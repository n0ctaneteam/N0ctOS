# N0ctOS Modular Blob Prototype

This is the first architecture pass for the N0ctOS modular Blob system.

## Runtime structure

- `core/ModuleRegistry.qml`: scans configured module roots for `manifest.json`, preserves all manifest keys, resolves the sibling QML file to an absolute path, and applies scan-path precedence.
- `core/LayoutConfig.qml`: reads the user Blob layout JSON as an untyped object so adding configuration fields does not require parser changes.
- `core/Module.qml`: reusable runtime host/contract for a dynamically loaded module. It owns activation, focus, lifecycle, and loading.
- `core/ModuleManager.qml`: resolves module IDs to their owning Blob and handles activation/deactivation.
- `core/ModuleIPC.qml`: exposes a stable Quickshell IPC API under target `n0ctos`.
- `components/Blob.qml`: reusable Blob with selector, module host, hover handling, and direct activation support.
- `components/ModuleSelector.qml`: renders manifest metadata for selector choices.
- `config/blobs.json`: user layout/configuration. It only stores module IDs, never paths or manifest metadata.

## Module search precedence

The array in `shell.qml` is ordered high-to-low priority. The default is:

1. `~/.config/N0ctOS/addons/modules`
2. `/usr/share/N0ctOS/local/addons/modules`
3. `/usr/share/N0ctOS/shell/modules`

Change `moduleScanPaths` to scale the installation layout without touching the crawler.

## Manifest extensibility

The registry copies every JSON key from the manifest into the runtime descriptor. The required manifest field list is itself configurable through `requiredManifestFields`; the default requires `id`, `name`, `version`, `author`, and `module`. Optional/new keys are preserved automatically. Runtime fields added by the registry are `manifestPath`, `moduleDir`, and `modulePath`. The `module` value must be a sibling `.qml` filename.

Example:

```json
{
    "id": "launcher",
    "name": "Launcher",
    "version": "1.0.0",
    "author": "N0ctOS",
    "module": "Launcher.qml",
    "category": "utility",
    "permissions": [],
    "futureField": {"anything": true}
}
```

`category`, `permissions`, `futureField`, etc. require no parser changes.

## IPC

```sh
qs ipc call n0ctos activate launcher
qs ipc call n0ctos deactivate launcher
qs ipc call n0ctos toggle launcher
qs ipc call n0ctos focus launcher
qs ipc call n0ctos activateIn launcher blob3
qs ipc call n0ctos reloadModules
qs ipc call n0ctos listModules
qs ipc call n0ctos info launcher
```

Hyprland can keep the keybind and simply execute one of those commands, e.g. conceptually:

```text
SUPER, SPACE, exec, qs ipc call n0ctos activate launcher
```

## Important prototype note

`Blob.qml` uses a generic rounded-rectangle surface only to make the prototype runnable. Replace that visual layer with your existing eight-Blob geometry/morph implementation later; the registry, manager, IPC, manifest, and layout architecture do not depend on it.
