pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string configPath: Quickshell.shellPath("config.json")
    property list<string> configPaths: [
        Quickshell.shellPath("config.json"),
        Quickshell.statePath("config.json")
    ]

    property var configData: {}
    property var screenNames: []
    property var primaryScreen: null
    property string primaryScreenName: ""

    property bool configLoaded: false
    property bool saving: false
    property string _activePath: ""
    property var _jobs: []

    signal screensChanged()
    signal primaryScreenResolved(var screen)
    signal screenDiscovered(string name)

    // Watchers — hot reload without reboot for both possible locations
    FileView {
        id: configFile
        path: root.configPath
        watchChanges: true
        blockLoading: true

        onLoaded: root.loadConfig()
        onFileChanged: {
            if (!root.saving)
                root.loadConfig()
        }

        onSaved: {
            root.saving = false
        }

        onSaveFailed: {
            root.saving = false
            console.warn("[ScreenManager] config save failed:", error)
        }
    }

    FileView {
        id: stateWatcher
        path: Quickshell.statePath("config.json")
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: {
            if (root.saving) return
            console.log("[ScreenManager] state config changed, reloading")
            root.loadConfig()
        }
    }

    function load() {
        loadConfig()
    }

    function loadConfig() {
        console.log("[ScreenManager] loadConfig()")
        // Clear stale pending readers (avoid destroy WARN on already-destroyed)
        _jobs = []
        if (!_activePath) configData = {}
        _tryConfig(0)
    }

    function _tryConfig(index) {
        if (index >= configPaths.length) {
            console.warn("[ScreenManager] no valid config found")
            return
        }
        var path = configPaths[index]
        if (!path) {
            _tryConfig(index + 1)
            return
        }
        console.log("[ScreenManager] checking:", path)
        var comp = configReader.createObject(root, { configIndex: index, configPath: path, path: path })
        if (!comp) {
            console.warn("[ScreenManager] failed to create reader:", path)
            _tryConfig(index + 1)
            return
        }
        _jobs.push(comp)
    }

    function _configLoaded(file) {
        if (_jobs.indexOf(file) === -1) {
            file.destroy()
            return
        }
        var idx = _jobs.indexOf(file)
        if (idx !== -1) _jobs.splice(idx, 1)

        var path = file.configPath
        try {
            var rawText = file.text().trim()
            var data = rawText ? JSON.parse(rawText) : {}
            if (!data || typeof data !== "object" || Array.isArray(data))
                data = {}
            root.configData = data
            var stored = data.screens
            root.screenNames = Array.isArray(stored) ? stored.slice() : []
            root._activePath = path
            root.configLoaded = true
            console.log("[ScreenManager] loaded index:", JSON.stringify(root.screenNames), "from", path)
            file.destroy()
        } catch (e) {
            console.warn("[ScreenManager] config load failed:", path, e)
            file.destroy()
            _tryConfig(file.configIndex + 1)
            return
        }
        refresh()
    }

    function _configFailed(file, error) {
        if (_jobs.indexOf(file) === -1) {
            file.destroy()
            return
        }
        var idx = _jobs.indexOf(file)
        if (idx !== -1) _jobs.splice(idx, 1)
        console.warn("[ScreenManager] config read failed:", file.configPath, error)
        var next = file.configIndex + 1
        file.destroy()
        _tryConfig(next)
    }

    Component {
        id: configReader
        FileView {
            property int configIndex: -1
            property string configPath: ""
            blockLoading: true
            printErrors: false
            watchChanges: false
            onLoadedChanged: {
                if (loaded) root._configLoaded(this)
            }
            onLoadFailed: function(err) { root._configFailed(this, err) }
        }
    }

    function refresh() {
        if (!root.configLoaded)
            return

        var screens = Quickshell.screens
        var names = root.screenNames.slice()
        var changed = false

        console.log(
            "[ScreenManager] refresh; connected:",
            screens.length,
            "index:", JSON.stringify(names)
        )

        for (var i = 0; i < screens.length; ++i) {
            var screen = screens[i]

            if (!screen || !screen.name)
                continue

            console.log(
                "[ScreenManager] detected:",
                screen.name,
                "at", screen.x, screen.y, screen.width + "x" + screen.height
            )

            if (names.indexOf(screen.name) === -1) {
                names.push(screen.name)
                changed = true

                console.log(
                    "[ScreenManager] new screen:",
                    screen.name
                )

                root.screenDiscovered(screen.name)
            }
        }

        if (changed) {
            root.screenNames = names
            save()
            root.screensChanged()

            console.log(
                "[ScreenManager] index updated:",
                JSON.stringify(root.screenNames)
            )
        } else {
            console.log("[ScreenManager] index unchanged, re-resolving primary")
        }

        resolvePrimary()
    }

    function resolvePrimary() {
        var oldName = root.primaryScreenName
        var resolved = null

        for (var i = 0; i < root.screenNames.length; ++i) {
            var name = root.screenNames[i]

            for (var j = 0; j < Quickshell.screens.length; ++j) {
                var screen = Quickshell.screens[j]

                if (screen && screen.name === name) {
                    resolved = screen
                    break
                }
            }

            if (resolved)
                break
        }

        if (!resolved && Quickshell.screens.length > 0)
            resolved = Quickshell.screens[0]

        root.primaryScreen = resolved
        root.primaryScreenName = resolved ? resolved.name : ""

        console.log(
            "[ScreenManager] primary:",
            root.primaryScreenName || "(none)",
            "from index", JSON.stringify(root.screenNames),
            "connected", Quickshell.screens.length
        )

        if (oldName !== root.primaryScreenName)
            root.primaryScreenResolved(root.primaryScreen)
    }

    function screenForName(name) {
        if (!name)
            return null

        for (var i = 0; i < Quickshell.screens.length; ++i) {
            var screen = Quickshell.screens[i]

            if (screen && screen.name === name)
                return screen
        }

        return null
    }

    function isConnected(name) {
        return screenForName(name) !== null
    }

    function setPrimary(name) {
        if (!name)
            return false

        var index = root.screenNames.indexOf(name)

        if (index === -1) {
            console.warn(
                "[ScreenManager] unknown screen:",
                name
            )
            return false
        }

        if (!isConnected(name)) {
            console.warn(
                "[ScreenManager] screen is not connected:",
                name
            )
            return false
        }

        if (index > 0) {
            var updated = root.screenNames.slice()

            updated.splice(index, 1)
            updated.unshift(name)

            root.screenNames = updated

            save()
            root.screensChanged()
        }

        resolvePrimary()
        return true
    }

    function save() {
        if (!root.configLoaded) {
            console.warn(
                "[ScreenManager] refusing to save before config is loaded"
            )
            return
        }

        try {
            var data = root.configData
            if (!data || typeof data !== "object" || Array.isArray(data))
                data = {}
            data.screens = root.screenNames.slice()
            root.configData = data
            root.saving = true

            var targetPath = root._activePath || root.configPath
            // Use configFile if target is shellPath, otherwise create writer for statePath
            if (targetPath === root.configPath) {
                configFile.setText(JSON.stringify(data, null, 4))
            } else {
                var writer = saveWriter.createObject(root, { path: targetPath })
                if (writer) writer.setText(JSON.stringify(data, null, 4))
                else {
                    console.warn("[ScreenManager] failed to create writer for", targetPath)
                    root.saving = false
                }
            }

            console.log(
                "[ScreenManager] saved screens:",
                JSON.stringify(root.screenNames),
                "to", targetPath
            )
        } catch (e) {
            root.saving = false
            console.warn(
                "[ScreenManager] config save failed:",
                e
            )
        }
    }

    Component {
        id: saveWriter
        FileView {
            atomicWrites: true
            printErrors: true
            onSaved: {
                console.log("[ScreenManager] saved to", path)
                root.saving = false
                destroy()
            }
            onSaveFailed: function(err) {
                console.warn("[ScreenManager] save failed:", path, err)
                root.saving = false
                destroy()
            }
        }
    }

    onScreenNamesChanged: {
        console.log("[ScreenManager] screenNames changed:", JSON.stringify(screenNames))
        resolvePrimary()
    }

    Connections {
        target: Quickshell

        function onScreensChanged() {
            console.log("[ScreenManager] Quickshell screens changed — refreshing")
            root.refresh()
        }
    }

    Component.onCompleted: {
        console.log("[ScreenManager] START — watching", configPath, "and", Quickshell.statePath("config.json"))
        loadConfig()
    }
}
