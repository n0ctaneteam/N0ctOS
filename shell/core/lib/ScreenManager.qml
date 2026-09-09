pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string configPath: Quickshell.shellPath("config.json")

    property var configData: {}
    property var screenNames: []
    property var primaryScreen: null
    property string primaryScreenName: ""

    property bool configLoaded: false
    property bool saving: false

    signal screensChanged()
    signal primaryScreenResolved(var screen)
    signal screenDiscovered(string name)

    FileView {
        id: configFile
        path: root.configPath
        watchChanges: true
        blockLoading: true

        onLoaded: root.load()
        onFileChanged: {
            if (!root.saving)
                root.load()
        }

        onSaved: {
            root.saving = false
        }

        onSaveFailed: {
            root.saving = false
            console.warn("[ScreenManager] config save failed:", error)
        }
    }

    function load() {
        try {
            var rawText = configFile.text().trim()
            var data = rawText ? JSON.parse(rawText) : {}

            if (!data || typeof data !== "object" || Array.isArray(data))
                data = {}

            root.configData = data

            var stored = data.screens

            root.screenNames = Array.isArray(stored)
                    ? stored.slice()
                    : []

            root.configLoaded = true

            console.log(
                "[ScreenManager] loaded index:",
                JSON.stringify(root.screenNames)
            )
        } catch (e) {
            console.warn("[ScreenManager] config load failed:", e)

            root.configData = {}
            root.screenNames = []
            root.configLoaded = false
        }

        refresh()
    }

    function refresh() {
        if (!root.configLoaded)
            return

        var screens = Quickshell.screens
        var names = root.screenNames.slice()
        var changed = false

        console.log(
            "[ScreenManager] refresh; connected:",
            screens.length
        )

        for (var i = 0; i < screens.length; ++i) {
            var screen = screens[i]

            if (!screen || !screen.name)
                continue

            console.log(
                "[ScreenManager] detected:",
                screen.name
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
            root.primaryScreenName || "(none)"
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
            // Keep the ENTIRE existing JSON document.
            var data = root.configData

            if (!data || typeof data !== "object" || Array.isArray(data))
                data = {}

            // Modify ONLY screens.
            data.screens = root.screenNames.slice()

            root.configData = data
            root.saving = true

            configFile.setText(
                JSON.stringify(data, null, 4)
            )

            console.log(
                "[ScreenManager] saved screens:",
                JSON.stringify(root.screenNames)
            )
        } catch (e) {
            root.saving = false

            console.warn(
                "[ScreenManager] config save failed:",
                e
            )
        }
    }

    Connections {
        target: Quickshell

        function onScreensChanged() {
            console.log("[ScreenManager] Quickshell screens changed")
            root.refresh()
        }
    }

    Component.onCompleted: {
        console.log("[ScreenManager] START")
        refresh()
    }
}