pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string configPath: Quickshell.shellPath("config.json")
    property var configData: ({})
    property var monitors: ({})
    property bool configLoaded: false
    property bool saving: false
    property var transitionConfig: ({
        id: "none",
        duration: 500,
        parameters: {}
    })

    signal wallpaperChanged(string monitorName)
    signal transitionChanged()

    FileView {
        id: configFile

        path: root.configPath
        watchChanges: true
        blockLoading: true
        atomicWrites: true
        printErrors: true

        onLoaded: root.load()

        onFileChanged: {
            if (!root.saving)
                root.load()
        }

        onSaved: {
            root.saving = false

            console.log(
                "[WallpaperManager] config saved"
            )
        }

        onSaveFailed: {
            root.saving = false

            console.warn(
                "[WallpaperManager] config save failed:",
                error
            )
        }
    }

    IpcHandler {
        target: "n0ctos-wall"

        function set(screen: string, path: string): bool {
            return root.setWallpaper(screen, path)
        }

        function setAll(path: string): bool {
            return root.setAll(path)
        }

        function clear(screen: string): bool {
            return root.clearWallpaper(screen)
        }

        function get(screen: string): string {
            return root.getWallpaper(screen)
        }

        function list(): string {
            return root.listWallpapers()
        }
    }

    function expandPath(path) {
        if (!path)
            return ""

        var value = String(path).trim()

        if (value.startsWith("file://") ||
            value.startsWith("http://") ||
            value.startsWith("https://"))
            return value

        if (value === "~")
            return Quickshell.env("HOME") || value

        if (value.startsWith("~/")) {
            var home = Quickshell.env("HOME") || ""
            return home + value.slice(1)
        }

        return value
    }

    function toUrl(path) {
        if (!path)
            return ""

        var value = root.expandPath(path)

        if (value.startsWith("file://") ||
            value.startsWith("http://") ||
            value.startsWith("https://"))
            return value

        if (value.startsWith("/"))
            return "file://" + value

        return value
    }

    function detectType(path) {
        var value = root.expandPath(path).toLowerCase()

        if (value.endsWith(".gif"))
            return "gif"

        if (value.endsWith(".mp4") ||
            value.endsWith(".mkv") ||
            value.endsWith(".webm") ||
            value.endsWith(".avi") ||
            value.endsWith(".mov") ||
            value.endsWith(".m4v") ||
            value.endsWith(".mpg") ||
            value.endsWith(".mpeg") ||
            value.endsWith(".ogv"))
            return "video"

        return "image"
    }

    function load() {
        try {
            var rawText = configFile.text().trim()
            var data = rawText ? JSON.parse(rawText) : {}

            if (!data ||
                typeof data !== "object" ||
                Array.isArray(data))
                data = {}

            if (!data.wallpaper ||
                typeof data.wallpaper !== "object" ||
                Array.isArray(data.wallpaper))
                data.wallpaper = {}

            var stored = data.wallpaper.monitors

            root.monitors =
                stored &&
                typeof stored === "object" &&
                !Array.isArray(stored)
                    ? Object.assign({}, stored)
                    : {}

            var transition =
                data.wallpaper.transition

            if (transition &&
                typeof transition === "object" &&
                !Array.isArray(transition)) {
                root.transitionConfig = {
                    id: String(
                        transition.id || "none"
                    ),

                    duration: Math.max(
                        0,
                        Number(
                            transition.duration ?? 500
                        )
                    ),

                    parameters:
                        transition.parameters &&
                        typeof transition.parameters === "object" &&
                        !Array.isArray(transition.parameters)
                            ? Object.assign(
                                {},
                                transition.parameters
                            )
                            : {}
                }
            } else {
                root.transitionConfig = {
                    id: "none",
                    duration: 500,
                    parameters: {}
                }
            }

            root.configData = data
            root.configLoaded = true

            console.log(
                "[WallpaperManager] loaded"
            )

            console.log(
                "[WallpaperManager] monitors:",
                JSON.stringify(root.monitors)
            )

            console.log(
                "[WallpaperManager] transition:",
                JSON.stringify(root.transitionConfig)
            )
        } catch (e) {
            console.warn(
                "[WallpaperManager] load failed:",
                e
            )

            root.configData = {}
            root.monitors = {}

            root.transitionConfig = {
                id: "none",
                duration: 500,
                parameters: {}
            }

            root.configLoaded = false
        }
    }

    function definitionFor(screen) {
        if (!screen)
            return {}

        return root.definitionForName(
            screen.name
        )
    }

    function definitionForName(name) {
        if (!name)
            return {}

        return root.monitors[name] || {}
    }

    function sourceFor(screen) {
        return root.definitionFor(screen).source || ""
    }

    function typeFor(screen) {
        return root.definitionFor(screen).type || "image"
    }

    function fittingFor(screen) {
        return root.definitionFor(screen).fitting || "crop"
    }

    function setWallpaper(name, source) {
        if (!name || !source) {
            console.warn(
                "[WallpaperManager] set: invalid arguments"
            )
            return false
        }

        if (!root.configLoaded) {
            console.warn(
                "[WallpaperManager] set: config not loaded"
            )
            return false
        }

        var updated =
            Object.assign({}, root.monitors)

        updated[name] = {
            source: String(source),
            type: root.detectType(source),
            fitting: "crop"
        }

        root.monitors = updated
        root.commit()

        console.log(
            "[WallpaperManager] SET",
            name,
            "->",
            source,
            "(" + updated[name].type + ")"
        )

        root.wallpaperChanged(name)

        return true
    }

    function setAll(source) {
        if (!source) {
            console.warn(
                "[WallpaperManager] set-all: missing source"
            )
            return false
        }

        if (!root.configLoaded) {
            console.warn(
                "[WallpaperManager] set-all: config not loaded"
            )
            return false
        }

        var updated =
            Object.assign({}, root.monitors)

        var type =
            root.detectType(source)

        var changedScreens = []

        for (var i = 0;
             i < Quickshell.screens.length;
             ++i) {

            var screen =
                Quickshell.screens[i]

            if (!screen || !screen.name)
                continue

            updated[screen.name] = {
                source: String(source),
                type: type,
                fitting: "crop"
            }

            changedScreens.push(
                screen.name
            )
        }

        root.monitors = updated
        root.commit()

        for (var j = 0;
             j < changedScreens.length;
             ++j) {

            root.wallpaperChanged(
                changedScreens[j]
            )

            console.log(
                "[WallpaperManager] SET-ALL",
                changedScreens[j],
                "->",
                source,
                "(" + type + ")"
            )
        }

        return true
    }

    function updateWallpaper(name, data) {
        if (!name || !data)
            return false

        if (!root.configLoaded)
            return false

        var updated =
            Object.assign({}, root.monitors)

        var current =
            Object.assign(
                {},
                updated[name] || {}
            )

        for (var key in data)
            current[key] = data[key]

        if (!current.source)
            return false

        if (!current.type)
            current.type =
                root.detectType(current.source)

        if (!current.fitting)
            current.fitting = "crop"

        updated[name] = current

        root.monitors = updated
        root.commit()
        root.wallpaperChanged(name)

        return true
    }

    function clearWallpaper(name) {
        if (!name)
            return false

        if (!root.configLoaded)
            return false

        var updated =
            Object.assign({}, root.monitors)

        if (!Object.prototype.hasOwnProperty.call(
                updated,
                name
            )) {

            console.log(
                "[WallpaperManager] CLEAR:",
                name,
                "(nothing configured)"
            )

            return true
        }

        delete updated[name]

        root.monitors = updated
        root.commit()
        root.wallpaperChanged(name)

        console.log(
            "[WallpaperManager] CLEAR:",
            name
        )

        return true
    }

    function getWallpaper(name) {
        if (!name)
            return ""

        var definition =
            root.definitionForName(name)

        if (!definition.source)
            return (
                "screen=" +
                name +
                "\nwallpaper=(none)"
            )

        return (
            "screen=" + name + "\n" +
            "source=" + definition.source + "\n" +
            "resolved=" +
                root.expandPath(
                    definition.source
                ) +
                "\n" +
            "type=" +
                (definition.type || "image") +
                "\n" +
            "fitting=" +
                (definition.fitting || "crop")
        )
    }

    function listWallpapers() {
        var lines = []

        for (var i = 0;
             i < Quickshell.screens.length;
             ++i) {

            var screen =
                Quickshell.screens[i]

            if (!screen || !screen.name)
                continue

            var definition =
                root.definitionForName(
                    screen.name
                )

            if (!definition.source) {
                lines.push(
                    screen.name +
                    " : (none)"
                )

                continue
            }

            lines.push(
                screen.name +
                " : " +
                definition.source +
                " [" +
                (definition.type || "image") +
                ", " +
                (definition.fitting || "crop") +
                "]"
            )
        }

        return lines.length
            ? lines.join("\n")
            : "(no connected screens)"
    }

    function setTransitionConfig(
        id,
        duration,
        parameters
    ) {
        if (!root.configLoaded) {
            console.warn(
                "[WallpaperManager] transition: config not loaded"
            )

            return false
        }

        var data =
            root.configData

        if (!data ||
            typeof data !== "object" ||
            Array.isArray(data))
            data = {}

        if (!data.wallpaper ||
            typeof data.wallpaper !== "object" ||
            Array.isArray(data.wallpaper))
            data.wallpaper = {}

        var next = {
            id: String(id || "none"),

            duration: Math.max(
                0,
                Number(duration ?? 500)
            ),

            parameters:
                parameters &&
                typeof parameters === "object" &&
                !Array.isArray(parameters)
                    ? Object.assign(
                        {},
                        parameters
                    )
                    : {}
        }

        data.wallpaper.transition = next

        root.configData = data
        root.transitionConfig = next

        root.commit()
        root.transitionChanged()

        console.log(
            "[WallpaperManager] TRANSITION:",
            JSON.stringify(next)
        )

        return true
    }

    function commit() {
        if (!root.configLoaded) {
            console.warn(
                "[WallpaperManager] refusing to write before load"
            )

            return false
        }

        try {
            var data =
                root.configData

            if (!data ||
                typeof data !== "object" ||
                Array.isArray(data))
                data = {}

            if (!data.wallpaper ||
                typeof data.wallpaper !== "object" ||
                Array.isArray(data.wallpaper))
                data.wallpaper = {}

            data.wallpaper.monitors =
                Object.assign(
                    {},
                    root.monitors
                )

            data.wallpaper.transition = {
                id:
                    root.transitionConfig.id ||
                    "none",

                duration:
                    Number(
                        root.transitionConfig.duration ??
                        500
                    ),

                parameters:
                    Object.assign(
                        {},
                        root.transitionConfig.parameters || {}
                    )
            }

            root.configData = data
            root.saving = true

            configFile.setText(
                JSON.stringify(
                    data,
                    null,
                    4
                )
            )

            return true
        } catch (e) {
            root.saving = false

            console.warn(
                "[WallpaperManager] commit failed:",
                e
            )

            return false
        }
    }

    Component.onCompleted: {
        console.log(
            "[WallpaperManager] START"
        )

        console.log(
            "[WallpaperManager] config:",
            root.configPath
        )
    }
}