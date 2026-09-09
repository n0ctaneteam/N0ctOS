pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property var registry:
        TransitionRegistry

    readonly property string id:
        WallpaperManager.transitionConfig.id ||
        "none"

    readonly property var definition:
        root.registry.get(root.id)

    readonly property int duration:
        Math.max(
            0,
            Number(
                WallpaperManager.transitionConfig.duration ??
                500
            )
        )

    /*
     * Manifest defaults + config overrides.
     * Config always wins.
     */
    readonly property var parameters:
        mergedParameters()

    signal changed()

    IpcHandler {
        target: "n0ctos-transition"

        function set(id: string): bool {
            return root.setTransition(id)
        }

        function duration(ms: int): bool {
            return root.setDuration(ms)
        }

        function reset(): bool {
            return root.reset()
        }

        function get(): string {
            return root.get()
        }

        function list(): string {
            return root.list()
        }
    }

    function mergedParameters() {
        var defaults = {}

        if (root.definition &&
            root.definition.parameters &&
            typeof root.definition.parameters === "object") {

            var definitions =
                root.definition.parameters

            for (var key in definitions) {
                var parameter =
                    definitions[key]

                if (parameter &&
                    parameter.default !== undefined) {

                    defaults[key] =
                        parameter.default
                }
            }
        }

        var overrides =
            WallpaperManager
                .transitionConfig
                .parameters

        if (overrides &&
            typeof overrides === "object" &&
            !Array.isArray(overrides)) {

            for (var overrideKey in overrides)
                defaults[overrideKey] =
                    overrides[overrideKey]
        }

        return defaults
    }

    function has(id) {
        if (!id || id === "none")
            return id === "none"

        return root.registry.has(id)
    }

    function setTransition(id) {
        id =
            String(id || "").trim()

        if (!id)
            return false

        if (id !== "none" &&
            !root.registry.has(id)) {

            console.warn(
                "[TransitionManager] unknown transition:",
                id
            )

            return false
        }

        var current =
            WallpaperManager.transitionConfig

        return WallpaperManager.setTransitionConfig(
            id,
            Number(
                current.duration ?? 500
            ),
            current.parameters || {}
        )
    }

    function setDuration(ms) {
        var current =
            WallpaperManager.transitionConfig

        return WallpaperManager.setTransitionConfig(
            current.id || "none",
            Math.max(
                0,
                Number(ms)
            ),
            current.parameters || {}
        )
    }

    function setParameters(parameters) {
        if (!parameters ||
            typeof parameters !== "object" ||
            Array.isArray(parameters))
            parameters = {}

        var current =
            WallpaperManager.transitionConfig

        return WallpaperManager.setTransitionConfig(
            current.id || "none",
            Number(
                current.duration ?? 500
            ),
            parameters
        )
    }

    function reset() {
        return WallpaperManager.setTransitionConfig(
            "none",
            500,
            {}
        )
    }

    function get() {
        return JSON.stringify({
            id: root.id,
            duration: root.duration,
            parameters: root.parameters,

            definition:
                root.definition
                    ? {
                        id:
                            root.definition.id,

                        name:
                            root.definition.name,

                        author:
                            root.definition.author,

                        version:
                            root.definition.version,

                        type:
                            root.definition.type,

                        component:
                            root.definition.componentPath
                    }
                    : null
        }, null, 4)
    }

    function list() {
        var ids =
            root.registry.ids()

        var lines = [
            "none : built-in instant switch"
        ]

        for (var i = 0;
             i < ids.length;
             ++i) {

            var entry =
                root.registry.get(ids[i])

            lines.push(
                entry.id +
                " : " +
                entry.name +
                " [" +
                entry.type +
                "] by " +
                entry.author
            )
        }

        return lines.join("\n")
    }

    Connections {
        target: WallpaperManager

        function onTransitionChanged() {
            root.changed()
        }
    }

    Component.onCompleted: {
        console.log(
            "[TransitionManager] START"
        )

        console.log(
            "[TransitionManager] current:",
            root.id
        )
    }
}