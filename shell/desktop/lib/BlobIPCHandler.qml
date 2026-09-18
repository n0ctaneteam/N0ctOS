pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import qs.core.lib

Singleton {
    id: root

    // Singleton-safe defaults — ScreenFrame registers per-screen blob maps.
    // `blobManager` defaults to the BlobManager singleton; assignment kept for compat.
    property var blobManager: BlobManager
    // Compat: flat map of last-registered screen (deprecated). Prefer blobsByScreen.
    property var blobs: ({})
    // Per-screen registry: { [screenName]: { tr: Blob, tl: Blob, ... } }
    property var blobsByScreen: ({})

    // Cached cursor screen (updated via hyprctl polling when targetScreen === "cursor")
    property string _cursorScreenName: ""

    // ———————————————————————————————————————————
    // Registration API — called by ScreenFrame per-screen
    // ———————————————————————————————————————————

    function registerScreen(screenName: string, map) {
        if (!screenName || !map) {
            console.warn("[BlobIPC] registerScreen: invalid args", screenName)
            return
        }
        const next = Object.assign({}, root.blobsByScreen)
        next[screenName] = map
        root.blobsByScreen = next
        // Keep compat `blobs` pointing at primary or last registered for old callers
        root._syncCompatBlobs()
        console.log("[BlobIPC] registerScreen:", screenName, "screens:", Object.keys(next).join(","))
        // Trigger cursor poll if needed
        if ((root.blobManager || BlobManager).targetScreen === "cursor")
            root._pollCursor()
    }

    function unregisterScreen(screenName: string) {
        if (!screenName) return
        if (!root.blobsByScreen.hasOwnProperty(screenName)) return
        const next = Object.assign({}, root.blobsByScreen)
        delete next[screenName]
        root.blobsByScreen = next
        root._syncCompatBlobs()
        console.log("[BlobIPC] unregisterScreen:", screenName, "remaining:", Object.keys(next).join(","))
        if (root._cursorScreenName === screenName)
            root._cursorScreenName = ""
    }

    function _syncCompatBlobs() {
        const target = root.resolveTargetScreenName()
        const bucket = root.blobsByScreen[target]
        if (bucket) {
            root.blobs = bucket
        } else {
            // fallback: last registered or empty
            const keys = Object.keys(root.blobsByScreen)
            if (keys.length) root.blobs = root.blobsByScreen[keys[keys.length - 1]]
            else root.blobs = ({})
        }
    }

    // ———————————————————————————————————————————
    // Screen resolution
    // ———————————————————————————————————————————

    function _isConnected(name: string): bool {
        if (!name) return false
        for (let i = 0; i < Quickshell.screens.length; ++i) {
            const s = Quickshell.screens[i]
            if (s && s.name === name) return true
        }
        return false
    }

    function _screenForPos(x: int, y: int): string {
        for (let i = 0; i < Quickshell.screens.length; ++i) {
            const s = Quickshell.screens[i]
            if (!s) continue
            if (x >= s.x && x < s.x + s.width && y >= s.y && y < s.y + s.height)
                return s.name
        }
        return ""
    }

    function resolveTargetScreenName(): string {
        const mgr = root.blobManager || BlobManager
        const mode = mgr ? mgr.targetScreen : "primary"
        return root._resolveForMode(mode)
    }

    function _resolveForMode(mode: string): string {
        // Ensure ScreenManager is fresh for screen index reloads + monitor connection updates (via quickshell)
        // No reboot needed — refresh is cheap and re-resolves primary from current Quickshell.screens
        try { ScreenManager.refresh() } catch(e) {}
        try { ScreenManager.resolvePrimary() } catch(e) {}

        if (mode === "cursor") {
            const cached = root._cursorScreenName
            if (cached && root._isConnected(cached))
                return cached
            // fallback to primary if cursor unknown/disconnected
            const primary = ScreenManager.primaryScreenName
            if (primary && root._isConnected(primary)) return primary
            if (Quickshell.screens.length > 0 && Quickshell.screens[0].name)
                return Quickshell.screens[0].name
            return ""
        }

        // "primary" (default)
        const primary = ScreenManager.primaryScreenName
        if (primary && root._isConnected(primary)) return primary
        if (Quickshell.screens.length > 0 && Quickshell.screens[0].name)
            return Quickshell.screens[0].name
        return ""
    }

    function targetBlob(blobId: string) {
        if (!blobId) return null
        const name = root.resolveTargetScreenName()
        const bucket = root.blobsByScreen[name]
        if (!bucket) {
            console.warn("[BlobIPC] no bucket for screen:", name, "available:", Object.keys(root.blobsByScreen).join(","))
            return null
        }
        return bucket[blobId] || null
    }

    function _targetBlobForMode(blobId: string, mode: string) {
        if (!blobId) return null
        const name = root._resolveForMode(mode)
        const bucket = root.blobsByScreen[name]
        if (!bucket) {
            console.warn("[BlobIPC] no bucket for screen:", name, "mode:", mode, "available:", Object.keys(root.blobsByScreen).join(","))
            return null
        }
        return bucket[blobId] || null
    }

    // Fresh read — IPC always reads blobs.targetScreen from disk, no reboot needed
    function _fetchFreshTarget(callback) {
        const reader = freshReaderComponent.createObject(root, { callback: callback })
        if (!reader) {
            console.warn("[BlobIPC] failed to create fresh reader, fallback to cached")
            const mgr = root.blobManager || BlobManager
            callback(mgr ? mgr.targetScreen : "primary")
            return
        }
        reader.running = true
    }

    // ———————————————————————————————————————————
    // Cursor polling (hyprctl -j cursorpos → map to screen)
    // ———————————————————————————————————————————

    function _pollCursor() {
        if (cursorProc.running) return
        cursorProc.running = true
    }

    function _handleCursorOutput(text: string) {
        const raw = text.trim()
        if (!raw) return
        let x = -1, y = -1
        try {
            const data = JSON.parse(raw)
            if (data && typeof data.x === "number" && typeof data.y === "number") {
                x = Math.round(data.x)
                y = Math.round(data.y)
            }
        } catch (e) {
            // fallback: "762, 437" plain format
            const parts = raw.split(",")
            if (parts.length === 2) {
                x = parseInt(parts[0].trim(), 10)
                y = parseInt(parts[1].trim(), 10)
            }
        }
        if (x < 0 || y < 0 || isNaN(x) || isNaN(y)) {
            // hyprctl failed or not on hyprland — keep previous or fallback
            return
        }
        const name = root._screenForPos(x, y)
        if (name && name !== root._cursorScreenName) {
            root._cursorScreenName = name
            console.log("[BlobIPC] cursorScreen:", name, "pos:", x, y)
            root._syncCompatBlobs()
        } else if (!name) {
            // cursor outside known screens (should not happen)
            console.warn("[BlobIPC] cursor pos not on any screen:", x, y)
        }
    }

    // Timer drives polling only when mode === "cursor"
    Timer {
        id: cursorTimer
        interval: 250
        repeat: true
        running: (root.blobManager || BlobManager).targetScreen === "cursor"
        triggeredOnStart: true
        onTriggered: root._pollCursor()
    }

    Process {
        id: cursorProc
        command: ["hyprctl", "-j", "cursorpos"]
        stdout: StdioCollector { id: cursorOut }
        stderr: StdioCollector { id: cursorErr }
        onExited: function(exitCode, exitStatus) {
            if (cursorErr.text.trim()) {
                // hyprctl not available — fallback silently to primary
            }
            if (cursorOut.text.trim()) {
                root._handleCursorOutput(cursorOut.text)
            } else if (exitCode !== 0) {
                // fallback: keep primary
            }
        }
    }

    Component {
        id: freshReaderComponent

        Process {
            property var callback

            // Read shellPath first, fallback to statePath — no assumption, fresh every IPC
            command: ["sh", "-c", "cat \"$1\" 2>/dev/null || cat \"$2\" 2>/dev/null", "dummy", Quickshell.shellPath("config.json"), Quickshell.statePath("config.json")]

            stdout: StdioCollector { id: freshOut }
            stderr: StdioCollector { id: freshErr }

            onExited: function(exitCode, exitStatus) {
                let mode = "primary"
                const raw = freshOut.text.trim()
                if (raw) {
                    try {
                        const data = JSON.parse(raw)
                        const v = data && data.blobs && typeof data.blobs.targetScreen === "string"
                            ? data.blobs.targetScreen.trim().toLowerCase()
                            : ""
                        if (v === "cursor" || v === "primary") mode = v
                        else if (v) console.warn("[BlobIPC] fresh read unknown targetScreen:", v, "-> primary")
                    } catch (e) {
                        console.warn("[BlobIPC] fresh read parse failed:", e)
                    }
                } else {
                    // No file or empty -> fallback to cached BlobManager value
                    const mgr = root.blobManager || BlobManager
                    const cached = mgr ? mgr.targetScreen : "primary"
                    if (cached === "cursor" || cached === "primary") mode = cached
                }
                if (callback) {
                    try { callback(mode) } catch (e) { console.warn("[BlobIPC] fresh callback failed:", e) }
                }
                destroy()
            }
        }
    }

    // React to mode changes — start/stop polling and resync compat
    Connections {
        target: BlobManager
        function onTargetScreenChanged() {
            console.log("[BlobIPC] targetScreen changed:", BlobManager.targetScreen, "-> target screen:", root.resolveTargetScreenName())
            root._syncCompatBlobs()
            if (BlobManager.targetScreen === "cursor") {
                root._cursorScreenName = ""
                root._pollCursor()
            }
        }
    }

    Connections {
        target: ScreenManager
        function onPrimaryScreenResolved(screen) {
            // primary changed -> update compat if in primary mode
            if ((root.blobManager || BlobManager).targetScreen !== "cursor") {
                console.log("[BlobIPC] primary resolved:", ScreenManager.primaryScreenName)
                root._syncCompatBlobs()
            }
        }
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            // prune disconnected cursor cache
            if (root._cursorScreenName && !root._isConnected(root._cursorScreenName)) {
                console.log("[BlobIPC] cursor screen disconnected:", root._cursorScreenName)
                root._cursorScreenName = ""
            }
            root._syncCompatBlobs()
        }
    }

    IpcHandler {
        target: "n0ctos-blob"

        function activate(moduleId: string): void {
            const mgr = root.blobManager || BlobManager
            const blobId = mgr.blobOf(moduleId)
            if (!blobId) {
                console.warn("[BlobIPC] no blob for:", moduleId)
                return
            }

            // Fresh read every IPC — no assumption, no reboot needed
            root._fetchFreshTarget(function(mode) {
                console.log("[BlobIPC] activate:", moduleId, "mode:", mode, "target:", root._resolveForMode(mode))

                const target = root._targetBlobForMode(blobId, mode)
                if (!target) {
                    console.warn("[BlobIPC] no blob for:", moduleId, "blobId:", blobId, "on screen:", root._resolveForMode(mode), "mode:", mode)
                    return
                }

                console.log(
                    "[BlobIPC] ->",
                    blobId,
                    "on",
                    root._resolveForMode(mode),
                    "openModule",
                    moduleId
                )

                target.openModule(moduleId)
            })
        }

        function deactivate(moduleId: string): void {
            const mgr = root.blobManager || BlobManager
            const blobId = mgr.blobOf(moduleId)
            if (!blobId) {
                console.warn("[BlobIPC] no blob for:", moduleId)
                return
            }

            root._fetchFreshTarget(function(mode) {
                console.log("[BlobIPC] deactivate:", moduleId, "mode:", mode, "target:", root._resolveForMode(mode))

                const target = root._targetBlobForMode(blobId, mode)
                if (!target) {
                    console.warn("[BlobIPC] no blob for:", moduleId, "blobId:", blobId, "on screen:", root._resolveForMode(mode), "mode:", mode)
                    return
                }

                console.log(
                    "[BlobIPC] ->",
                    blobId,
                    "on",
                    root._resolveForMode(mode),
                    "deactivateModule",
                    moduleId
                )

                target.deactivateModule(moduleId)
            })
        }

        function toggle(moduleId: string): void {
            const mgr = root.blobManager || BlobManager
            const blobId = mgr.blobOf(moduleId)
            if (!blobId) {
                console.warn("[BlobIPC] no blob for:", moduleId)
                return
            }

            root._fetchFreshTarget(function(mode) {
                console.log("[BlobIPC] toggle:", moduleId, "mode:", mode, "target:", root._resolveForMode(mode))

                const target = root._targetBlobForMode(blobId, mode)
                if (!target) {
                    console.warn("[BlobIPC] no blob for:", moduleId, "blobId:", blobId, "on screen:", root._resolveForMode(mode), "mode:", mode)
                    return
                }

                console.log(
                    "[BlobIPC] ->",
                    blobId,
                    "on",
                    root._resolveForMode(mode),
                    "toggleModule",
                    moduleId
                )

                target.toggleModule(moduleId)
            })
        }

        function focus(blobId: string): void {
            root._fetchFreshTarget(function(mode) {
                console.log("[BlobIPC] focus:", blobId, "mode:", mode, "target:", root._resolveForMode(mode))

                const target = root._targetBlobForMode(blobId, mode)
                if (!target) {
                    console.warn(
                        "[BlobIPC] invalid blob:",
                        blobId,
                        "on screen:",
                        root._resolveForMode(mode),
                        "mode:", mode
                    )
                    return
                }

                console.log(
                    "[BlobIPC] ->",
                    blobId,
                    "on",
                    root._resolveForMode(mode),
                    "focusBlob"
                )

                target.focusBlob()
            })
        }

        // Future UI / settings app — configure routing
        function getTargetScreen(): string {
            const mgr = root.blobManager || BlobManager
            return mgr ? mgr.targetScreen : "primary"
        }

        function setTargetScreen(mode: string): bool {
            const mgr = root.blobManager || BlobManager
            if (!mgr) return false
            console.log("[BlobIPC] setTargetScreen:", mode)
            return mgr.setTargetScreen(mode)
        }

        function getCursorScreen(): string {
            return root._cursorScreenName || ""
        }

        function getPrimaryScreen(): string {
            return ScreenManager.primaryScreenName || ""
        }

        function listScreens(): string {
            const names = []
            for (let i = 0; i < Quickshell.screens.length; ++i) {
                const s = Quickshell.screens[i]
                if (s && s.name) names.push(s.name)
            }
            return names.join("\n")
        }
    }

    Component.onCompleted: {
        console.log(
            "[BlobIPC] registered: n0ctos-blob"
        )
        // Initial cursor poll if needed
        if ((root.blobManager || BlobManager).targetScreen === "cursor")
            root._pollCursor()
    }
}
